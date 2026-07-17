# SocialHeadmap — Projektstatus

**Stand:** 2026-07-17 · **Version:** `2.2.0+5` · **Branch:** `redesign-v2` (aktiv; Merge → main offen)

> Maßgebliche Übergabe zwischen Sessions und Mac ↔ Workstation. Am Phasenende aktualisieren + pushen.
> Achtung: Repo ist PUBLIC — keine Secrets/IPs/Zugangsdaten hier eintragen.

## Aktueller Stand
- **Redesign v2 komplett umgesetzt und verteilt:** neues Design-System (Light+Dark), alle Screens neu, Statistik als Sheet in der Karte (questions/stats-Screens entfernt), zentraler ApiService.
- **Live:** Backend deployt und verifiziert (Docker auf dem Board-Server). **Android** v2.2 via Firebase App Distribution (läuft über das Gamodi-Firebase-Projekt). **iOS** Build 3 in TestFlight (Bundle `de.socialheadmap.socialheadmap`, App-Record 6792025736).
- **Login komplett:** Magic-Link, Google, **Sign in with Apple** (nur iOS-Button, Backend-JWKS-Verify), anonym per Device-Token.
- **Regeln live:** QUORUM=1 (Ergebnisse ab erster Stimme), Fair-Play serverseitig (alle `/stats/map*` verlangen device_token mit eigener Stimme → sonst 403 `vote_required`), `GET /votes/mine` für Server-Sync.
- **Admin-Tool live (2026-07-17):** Seite im Sprint-Board unter `/shm` (hinter Board-Login+TOTP), Proxy auf neue Backend-Routen: Zeitfenster (starts_at/ends_at), PATCH-Edit, Top-10 (`GET /questions/top`), Feinauswertung + CSV (`routers/admin_stats.py`, ohne Quorum). App zeigt Top-10-Strip im Feed.

## Offene Punkte
1. **PR/Merge `redesign-v2` → `main`** (main ist Stand ~Mai 2026).
2. Board-JWT_SECRET-Default beheben (braucht Container-Neuanlage mit .env — bewusst verschoben).
3. Repo public trotz Infra-Details in deploy.sh — entscheiden: Repo privat stellen oder Infra-Details entfernen.
4. Deploy-Drift: Images sauber bauen statt `docker cp` in laufende Container.

## Build & Deploy
- **`deploy.sh web|android|backend`** — läuft auf der **Workstation** (Mac hat keine Android-Toolchain). Backend-Deploy braucht dort den SSH-Key für den Board-Server via ssh-agent (Hinweis: die `.pem`-Variante des Keys ist leer/0 Bytes — den Key OHNE `.pem` nehmen).
- **deploy.sh-Falle (behoben):** deploy_backend kopiert jetzt das ganze `app/`-Paket per rsync — früher feste Dateiliste, wodurch Änderungen (z.B. QUORUM=1) nie live gingen.
- **iOS/TestFlight:** Manual-Signing in der Runner-Release-Config (Profil „SocialHeadmap AppStore", aktuell v3 mit SIWA); Signing-Kette + ASC-API-Ablauf wie bei Gamodi (Claude-Memory `gamodi-ios-signing`). SIWA-Capability: erst Capability setzen, dann Profil erzeugen; bei „Anmeldung nicht abgeschlossen" → IDMS-Portal-Re-Toggle.
- **Admin-Key:** gemeinsamer Key liegt als Datei auf dem Server (Datei hat Vorrang vor ENV, rotierbar ohne Container-Neuanlage) — Pfade siehe Claude-Memory `socialheadmap-projekt`.

## Architektur-Notizen
- Votes nur am Device-Token; Server kennt keine Vote↔User-Verknüpfung.
- Zeitfenster-Migration liegt in `database.py` (additive Migration).
- Basis-URL der App per `--dart-define=SHM_BASE_URL` überschreibbar (Default = Prod).

## Wissens-Verweise
- Detail-Historie: Claude-Memory `socialheadmap-projekt` (+ `gamodi-ios-signing`, `onager-ai-web-infra`)
