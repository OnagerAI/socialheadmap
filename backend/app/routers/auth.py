import uuid
import hashlib
import secrets
import random
import smtplib
import logging
import os
from datetime import datetime, timedelta, timezone
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

import httpx
from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError

from app.database import get_db
from app.schemas import (
    RegisterRequest, RegisterResponse,
    SocialLoginRequest, MagicLinkRequest, MagicLinkVerifyRequest,
    AuthResponse, UserProfile,
)

log = logging.getLogger(__name__)
router = APIRouter(prefix="/auth", tags=["auth"])
security = HTTPBearer(auto_error=False)

# ── Konfiguration ─────────────────────────────────────────────────────────────
JWT_SECRET      = os.getenv("JWT_SECRET", "shm-dev-secret-change-in-prod-2026")
JWT_ALGORITHM   = "HS256"
JWT_EXPIRY_DAYS = 30

GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")
APP_BASE_URL     = os.getenv("APP_BASE_URL", "https://shm.13-61-179-136.nip.io")

SMTP_HOST  = os.getenv("SMTP_HOST", "")
SMTP_PORT  = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER  = os.getenv("SMTP_USER", "")
SMTP_PASS  = os.getenv("SMTP_PASS", "")
FROM_EMAIL = os.getenv("FROM_EMAIL", "noreply@socialheadmap.de")

DEBUG = os.getenv("DEBUG", "false").lower() == "true"

# ── Wortlisten fuer anonyme Usernamen ─────────────────────────────────────────
_ADJEKTIVE = [
    "stiller", "bunter", "freier", "wilder", "kluger", "schneller", "ruhiger",
    "tapferer", "stolzer", "sanfter", "starker", "heller", "dunkler", "frischer",
    "froher", "listiger", "treuer", "edler", "weiser", "kecker", "mutiger",
    "flinker", "wacher", "fleissiger", "kuehner", "sicherer", "leichter",
    "kraeftiger", "froehlicher", "ehrlicher", "beherzter", "aufrechter",
    "guetiger", "geduldiger", "lebhafter", "gewandter", "schlichter",
    "stattlicher", "wackerer", "wendiger", "tuechtiger", "beharrlicher",
    "feiner", "flotter", "rascher", "kuehler", "hurtiger", "zaeher", "fixer",
]

_TIERE = [
    "luchs", "adler", "wolf", "baer", "fuchs", "hirsch", "elch", "dachs",
    "falke", "otter", "biber", "storch", "igel", "rabe", "marder", "uhu",
    "specht", "hase", "eisvogel", "kranich", "seeadler", "habicht", "dohle",
    "meise", "amsel", "drossel", "star", "rotkehlchen", "kleiber", "zaunkoenig",
    "bachstelze", "bussard", "steinbock", "waschbaer", "iltis", "wiesel",
    "hermelin", "wanderfalke", "rotmilan", "auerhahn", "fischotter", "nerz",
    "graureiher", "moewe", "kormoran", "kolkrabe", "turmfalke", "wiedehopf",
    "pirol", "kiebitz",
]


# ── Hilfsfunktionen ───────────────────────────────────────────────────────────

def _sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _generate_username(conn) -> str:
    for _ in range(100):
        adj  = random.choice(_ADJEKTIVE)
        tier = random.choice(_TIERE)
        num  = random.randint(1000, 9999)
        name = f"{adj}-{tier}-{num}"
        if not conn.execute("SELECT id FROM users WHERE username = ?", (name,)).fetchone():
            return name
    raise HTTPException(500, "username_generation_failed")


def _issue_jwt(user_id: str, username: str, conn) -> str:
    jti = str(uuid.uuid4())
    now = datetime.now(timezone.utc)
    payload = {
        "sub": user_id,
        "username": username,
        "jti": jti,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(days=JWT_EXPIRY_DAYS)).timestamp()),
    }
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    conn.execute(
        "INSERT INTO sessions (id, user_id, jti) VALUES (?,?,?)",
        (str(uuid.uuid4()), user_id, jti),
    )
    return token


def _verify_jwt_payload(token: str) -> dict:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except JWTError:
        raise HTTPException(401, "invalid_token")


def _send_magic_link_email(to_email: str, link: str) -> None:
    if not SMTP_HOST:
        log.warning("SMTP nicht konfiguriert. Magic Link fuer %s: %s", to_email, link)
        return
    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = "Dein SocialHeadmap Login-Link"
        msg["From"]    = FROM_EMAIL
        msg["To"]      = to_email
        html = f"""
        <html><body style="font-family:sans-serif;max-width:500px;margin:40px auto">
          <h2 style="color:#1565C0">SocialHeadmap</h2>
          <p>Klicke den Button um dich anzumelden.<br>
             Der Link ist <strong>15 Minuten</strong> gueltig und einmalig verwendbar.</p>
          <a href="{link}"
             style="display:inline-block;padding:14px 28px;background:#1565C0;
                    color:#fff;text-decoration:none;border-radius:8px;
                    font-weight:bold;margin:16px 0">
            Jetzt anmelden
          </a>
          <p style="color:#888;font-size:12px">
            Falls du diese E-Mail nicht angefordert hast, ignoriere sie einfach.
          </p>
        </body></html>
        """
        msg.attach(MIMEText(html, "html", "utf-8"))
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as srv:
            srv.starttls()
            srv.login(SMTP_USER, SMTP_PASS)
            srv.sendmail(FROM_EMAIL, to_email, msg.as_string())
    except Exception as exc:
        log.error("E-Mail-Versand fehlgeschlagen: %s", exc)
        raise HTTPException(503, "email_send_failed")


async def _verify_google_token(id_token: str) -> str:
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            "https://oauth2.googleapis.com/tokeninfo",
            params={"id_token": id_token},
            timeout=10,
        )
    if resp.status_code != 200:
        raise HTTPException(401, "google_token_invalid")
    data = resp.json()
    if GOOGLE_CLIENT_ID and data.get("aud") != GOOGLE_CLIENT_ID:
        raise HTTPException(401, "google_token_wrong_audience")
    sub = data.get("sub")
    if not sub:
        raise HTTPException(401, "google_token_no_sub")
    return sub


async def _verify_facebook_token(access_token: str) -> str:
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            "https://graph.facebook.com/me",
            params={"access_token": access_token, "fields": "id"},
            timeout=10,
        )
    if resp.status_code != 200:
        raise HTTPException(401, "facebook_token_invalid")
    data = resp.json()
    fb_id = data.get("id")
    if not fb_id:
        raise HTTPException(401, "facebook_token_no_id")
    return fb_id


# ── Auth Dependency ────────────────────────────────────────────────────────────

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    if not credentials:
        raise HTTPException(401, "not_authenticated")
    payload = _verify_jwt_payload(credentials.credentials)
    jti = payload.get("jti")
    with get_db() as conn:
        row = conn.execute(
            "SELECT id FROM sessions WHERE jti = ? AND invalidated_at IS NULL",
            (jti,),
        ).fetchone()
        if not row:
            raise HTTPException(401, "session_invalidated")
    return payload


# ── Endpunkte ─────────────────────────────────────────────────────────────────

@router.post("/register", response_model=RegisterResponse)
def register(req: RegisterRequest):
    """Legacy Device-Token Registrierung — wird weiterhin fuer Voting genutzt."""
    with get_db() as conn:
        if req.email_hash:
            if conn.execute(
                "SELECT id FROM user_auth WHERE email_hash = ?", (req.email_hash,)
            ).fetchone():
                raise HTTPException(409, "already_registered")
        row = conn.execute(
            "SELECT device_token FROM user_auth WHERE device_token = ?",
            (req.device_token,),
        ).fetchone()
        if row:
            return RegisterResponse(registered=False, device_token=req.device_token)
        conn.execute(
            "INSERT INTO user_auth (id, device_token, email_hash) VALUES (?,?,?)",
            (str(uuid.uuid4()), req.device_token, req.email_hash),
        )
        return RegisterResponse(registered=True, device_token=req.device_token)


@router.post("/social", response_model=AuthResponse)
async def social_login(req: SocialLoginRequest):
    """Google oder Facebook OAuth-Token verifizieren, Account anlegen/finden, JWT ausgeben."""
    if req.provider == "google":
        provider_uid = await _verify_google_token(req.access_token)
    elif req.provider == "facebook":
        provider_uid = await _verify_facebook_token(req.access_token)
    else:
        raise HTTPException(400, "unsupported_provider")

    provider_hash = _sha256(f"{req.provider}:{provider_uid}")

    with get_db() as conn:
        row = conn.execute(
            "SELECT id, username FROM users WHERE provider_hash = ?",
            (provider_hash,),
        ).fetchone()
        if row:
            user_id, username = row["id"], row["username"]
        else:
            user_id  = str(uuid.uuid4())
            username = _generate_username(conn)
            conn.execute(
                "INSERT INTO users (id, provider, provider_hash, username) VALUES (?,?,?,?)",
                (user_id, req.provider, provider_hash, username),
            )
        token = _issue_jwt(user_id, username, conn)

    return AuthResponse(jwt=token, username=username, provider=req.provider)


@router.post("/magic-link/request")
def request_magic_link(req: MagicLinkRequest):
    """E-Mail eingeben -> Magic Link per Mail senden. E-Mail wird NIE in DB gespeichert."""
    email_normalized = req.email.strip().lower()
    # Einfache Validierung
    if "@" not in email_normalized or "." not in email_normalized.split("@")[-1]:
        raise HTTPException(400, "invalid_email")

    email_hash = _sha256(email_normalized)

    with get_db() as conn:
        row = conn.execute(
            "SELECT id, username FROM users WHERE provider_hash = ?",
            (email_hash,),
        ).fetchone()
        if row:
            user_id, username = row["id"], row["username"]
        else:
            user_id  = str(uuid.uuid4())
            username = _generate_username(conn)
            conn.execute(
                "INSERT INTO users (id, provider, provider_hash, username) VALUES (?,?,?,?)",
                (user_id, "email", email_hash, username),
            )

        magic_token = secrets.token_hex(32)  # 64 hex Zeichen
        expires_at  = (datetime.now(timezone.utc) + timedelta(minutes=15)).isoformat()
        conn.execute(
            "INSERT INTO magic_tokens (id, user_id, token, expires_at) VALUES (?,?,?,?)",
            (str(uuid.uuid4()), user_id, magic_token, expires_at),
        )

    link = f"{APP_BASE_URL}/auth/magic-link/open?t={magic_token}"
    _send_magic_link_email(email_normalized, link)

    response: dict = {"sent": True, "username": username}
    if DEBUG:
        response["debug_link"] = link
    return response


@router.post("/magic-link/verify", response_model=AuthResponse)
def verify_magic_link(req: MagicLinkVerifyRequest):
    """Token aus Magic Link einmalig einloesen -> JWT."""
    now = datetime.now(timezone.utc)
    with get_db() as conn:
        row = conn.execute(
            """SELECT mt.id, mt.user_id, mt.expires_at, mt.used_at,
                      u.username, u.provider
               FROM magic_tokens mt JOIN users u ON u.id = mt.user_id
               WHERE mt.token = ?""",
            (req.token,),
        ).fetchone()

        if not row:
            raise HTTPException(404, "token_not_found")
        if row["used_at"]:
            raise HTTPException(410, "token_already_used")

        expires = datetime.fromisoformat(row["expires_at"])
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        if now > expires:
            raise HTTPException(410, "token_expired")

        conn.execute(
            "UPDATE magic_tokens SET used_at = ? WHERE id = ?",
            (now.isoformat(), row["id"]),
        )
        token = _issue_jwt(row["user_id"], row["username"], conn)

    return AuthResponse(jwt=token, username=row["username"], provider=row["provider"])


@router.post("/logout")
def logout(current_user: dict = Depends(get_current_user)):
    """Aktuelle JWT-Session invalidieren."""
    jti = current_user.get("jti")
    with get_db() as conn:
        conn.execute(
            "UPDATE sessions SET invalidated_at = ? WHERE jti = ?",
            (datetime.now(timezone.utc).isoformat(), jti),
        )
    return {"logged_out": True}


@router.get("/magic-link/open")
def open_magic_link(t: str):
    """Deep Link: leitet vom Browser zur App weiter, oder zeigt Token zum manuellen Eingeben."""
    from fastapi.responses import HTMLResponse
    html = f"""<!DOCTYPE html>
<html lang="de">
<head><meta charset="utf-8"><title>SocialHeadmap Login</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{{font-family:sans-serif;max-width:420px;margin:60px auto;padding:20px;text-align:center}}
.token{{font-family:monospace;font-size:11px;word-break:break-all;background:#f4f4f4;
padding:12px;border-radius:8px;margin:16px 0;color:#333}}
.btn{{display:inline-block;padding:14px 28px;background:#1565C0;color:#fff;
text-decoration:none;border-radius:8px;font-weight:bold;margin:8px 0}}
</style></head>
<body>
<h2>SocialHeadmap</h2>
<p>Tippe in der App auf <strong>Token manuell eingeben</strong> und füge diesen Code ein:</p>
<div class="token">{t}</div>
<a href="socialheadmap://auth?t={t}" class="btn">App öffnen</a>
<p style="color:#888;font-size:12px;margin-top:20px">
  Dieser Link ist 15 Minuten gültig und einmalig verwendbar.
</p>
</body></html>"""
    return HTMLResponse(content=html)


@router.get("/me", response_model=UserProfile)
def get_me(current_user: dict = Depends(get_current_user)):
    """Profil des eingeloggten Users."""
    with get_db() as conn:
        row = conn.execute(
            "SELECT id, username, provider FROM users WHERE id = ?",
            (current_user["sub"],),
        ).fetchone()
        if not row:
            raise HTTPException(404, "user_not_found")
        return UserProfile(
            user_id=row["id"],
            username=row["username"],
            provider=row["provider"],
        )
