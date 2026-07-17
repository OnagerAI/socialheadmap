import uuid
import json
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, Header, Depends
from typing import Optional
from app.database import get_db
from app.schemas import QuestionCreate, QuestionPatch, QuestionOut, TopQuestionOut
import os

router = APIRouter(prefix="/questions", tags=["questions"])

def _load_admin_key() -> str:
    """Key-Datei im data-Volume hat Vorrang (rotierbar ohne Container-Neuanlage);
    ENV bleibt als Fallback."""
    key_file = os.path.join(
        os.path.dirname(os.getenv("DB_PATH", "/app/data/x")), "admin_key")
    try:
        with open(key_file) as f:
            key = f.read().strip()
            if key:
                return key
    except OSError:
        pass
    return os.getenv("ADMIN_KEY", "")


ADMIN_KEY = _load_admin_key()

# SQL-Bedingung: Frage ist aktiv UND im Zeitfenster
ACTIVE_WINDOW_SQL = (
    "status = 'active' "
    "AND (starts_at IS NULL OR starts_at <= datetime('now')) "
    "AND (ends_at IS NULL OR ends_at > datetime('now'))"
)


def require_admin(x_admin_key: Optional[str] = Header(None)):
    if not ADMIN_KEY or x_admin_key != ADMIN_KEY:
        raise HTTPException(status_code=403, detail="forbidden")


def _norm_dt(value: Optional[str], field: str) -> Optional[str]:
    """ISO-Eingabe → SQLite-Format 'YYYY-MM-DD HH:MM:SS' (UTC). '' → None."""
    if value is None or value == "":
        return None
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        raise HTTPException(status_code=422, detail=f"invalid_{field}")
    if dt.tzinfo is not None:
        dt = dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt.strftime("%Y-%m-%d %H:%M:%S")


@router.get("/admin/verify", dependencies=[Depends(require_admin)])
def verify_admin_key():
    """Admin-Key validieren ohne Seiteneffekte."""
    return {"valid": True}


@router.get("/admin/all", response_model=list[QuestionOut], dependencies=[Depends(require_admin)])
def list_all_questions():
    """Alle Fragen (inkl. Draft/Archived) für Admin-Panel."""
    with get_db() as conn:
        rows = conn.execute(
            "SELECT * FROM questions ORDER BY created_at DESC"
        ).fetchall()
        return [_row_to_out(r) for r in rows]


@router.get("/top", response_model=list[TopQuestionOut])
def top_questions(limit: int = 10):
    """Top-Fragen nach Beteiligung der letzten 7 Tage (über alle Kategorien)."""
    limit = max(1, min(limit, 25))
    with get_db() as conn:
        rows = conn.execute(
            f"""SELECT q.*,
                       COALESCE(v7.cnt, 0)  AS votes_7d,
                       COALESCE(vt.cnt, 0)  AS total_votes
                FROM questions q
                LEFT JOIN (SELECT question_id, COUNT(*) cnt FROM votes
                           WHERE created_at >= datetime('now', '-7 days')
                           GROUP BY question_id) v7 ON v7.question_id = q.id
                LEFT JOIN (SELECT question_id, COUNT(*) cnt FROM votes
                           GROUP BY question_id) vt ON vt.question_id = q.id
                WHERE {ACTIVE_WINDOW_SQL}
                ORDER BY votes_7d DESC, total_votes DESC, q.activated_at DESC
                LIMIT ?""",
            (limit,),
        ).fetchall()
        return [
            TopQuestionOut(
                rank=i + 1,
                question=_row_to_out(r),
                votes_7d=r["votes_7d"],
                total_votes=r["total_votes"],
            )
            for i, r in enumerate(rows)
        ]


@router.get("/", response_model=list[QuestionOut])
def list_active_questions():
    with get_db() as conn:
        rows = conn.execute(
            f"SELECT * FROM questions WHERE {ACTIVE_WINDOW_SQL} "
            "ORDER BY activated_at DESC"
        ).fetchall()
        return [_row_to_out(r) for r in rows]


@router.post("/", response_model=QuestionOut, dependencies=[Depends(require_admin)])
def create_question(q: QuestionCreate):
    with get_db() as conn:
        qid = str(uuid.uuid4())
        options_json = json.dumps(q.options) if q.options else None
        conn.execute(
            """INSERT INTO questions
               (id, title, description, category, answer_type, options, starts_at, ends_at)
               VALUES (?,?,?,?,?,?,?,?)""",
            (qid, q.title, q.description, q.category, q.answer_type.value,
             options_json, _norm_dt(q.starts_at, "starts_at"),
             _norm_dt(q.ends_at, "ends_at")),
        )
        row = conn.execute("SELECT * FROM questions WHERE id = ?", (qid,)).fetchone()
        return _row_to_out(row)


@router.patch("/{qid}", response_model=QuestionOut, dependencies=[Depends(require_admin)])
def update_question(qid: str, patch: QuestionPatch):
    """Frage bearbeiten (Titel, Beschreibung, Kategorie, Optionen, Zeitfenster)."""
    with get_db() as conn:
        row = conn.execute("SELECT * FROM questions WHERE id = ?", (qid,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="question_not_found")

        fields, values = [], []
        for col in ("title", "description", "category"):
            val = getattr(patch, col)
            if val is not None:
                fields.append(f"{col} = ?")
                values.append(val)
        if patch.options is not None:
            fields.append("options = ?")
            values.append(json.dumps(patch.options) if patch.options else None)
        # Leerstring = Datum entfernen, None = unverändert
        if patch.starts_at is not None:
            fields.append("starts_at = ?")
            values.append(_norm_dt(patch.starts_at, "starts_at"))
        if patch.ends_at is not None:
            fields.append("ends_at = ?")
            values.append(_norm_dt(patch.ends_at, "ends_at"))

        if fields:
            values.append(qid)
            conn.execute(f"UPDATE questions SET {', '.join(fields)} WHERE id = ?", values)
        row = conn.execute("SELECT * FROM questions WHERE id = ?", (qid,)).fetchone()
        return _row_to_out(row)


@router.patch("/{qid}/activate", dependencies=[Depends(require_admin)])
def activate_question(qid: str):
    with get_db() as conn:
        conn.execute(
            "UPDATE questions SET status='active', activated_at=datetime('now') WHERE id=?",
            (qid,),
        )
        return {"activated": qid}


@router.patch("/{qid}/archive", dependencies=[Depends(require_admin)])
def archive_question(qid: str):
    with get_db() as conn:
        conn.execute("UPDATE questions SET status='archived' WHERE id=?", (qid,))
        return {"archived": qid}


def _row_to_out(row) -> QuestionOut:
    keys = row.keys()
    return QuestionOut(
        id=row["id"],
        title=row["title"],
        description=row["description"],
        category=row["category"],
        answer_type=row["answer_type"],
        options=json.loads(row["options"]) if row["options"] else None,
        status=row["status"],
        created_at=row["created_at"],
        starts_at=row["starts_at"] if "starts_at" in keys else None,
        ends_at=row["ends_at"] if "ends_at" in keys else None,
    )
