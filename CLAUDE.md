# SocialHeadmap — Arbeitsanweisungen für Claude

**Zuerst lesen: [`PROJECT_STATUS.md`](PROJECT_STATUS.md)** — aktueller Stand, offene Punkte, Deploy-Hinweise.

## Was ist das
Anonyme Abstimmungs-App mit interaktiver Deutschland-Karte (Landkreis-Heatmap). Flutter-App (`app/`, iOS + Android + Web) + FastAPI/SQLite-Backend (`backend/`). Votes hängen ausschließlich am Device-Token (Privacy by Design, kein FK auf User).

## Struktur & Kommandos
- `app/` — Flutter; Design-System in `theme.dart` (Light+Dark, ShmColors), zentraler `ApiService` (Base-URL per `--dart-define=SHM_BASE_URL`)
- `backend/` — FastAPI + SQLite; Admin-Statistik in `routers/admin_stats.py`
- `deploy.sh web|android|backend` — läuft auf der **Workstation**, nicht auf dem Mac

```bash
cd app && flutter analyze && flutter test
cd backend && pytest
```

## Harte Regeln / Fallen
- **Repo ist PUBLIC** — niemals Secrets, Keys, interne IPs oder Zugangsdaten committen.
- Aktiver Branch ist **`redesign-v2`** (main ist alt); Merge nach main steht aus.
- Auth: Magic-Link, Google/Apple/Facebook (JWT) oder anonym per Device-Token; Fair-Play: Karten-Stats erst nach eigener Stimme (403 `vote_required`).
- iOS-Signing läuft über die Gamodi-Signing-Kette (Claude-Memory `gamodi-ios-signing`); Manual-Signing gehört in die Runner-Release-Config, NICHT als xcodebuild-CLI-Override (bricht an Pods).
- Simulator-Screenshots vor dem Einlesen verkleinern: `sips -Z 800 <bild.png>`.
- Nach jeder Arbeitsphase: `PROJECT_STATUS.md` aktualisieren und pushen (Mac ↔ Workstation teilen den Stand über Git).
