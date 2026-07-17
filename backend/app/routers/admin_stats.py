"""Admin-Feinauswertung — nur mit Admin-Key erreichbar (Board-Proxy).

Anders als die öffentlichen /stats-Endpoints gilt hier KEIN Quorum und
KEIN Fair-Play-Gating: der Admin sieht alles, auch Einzelstimmen-Regionen.
"""
import csv
import io
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse

from app.database import get_db
from app.routers.questions import require_admin

router = APIRouter(prefix="/stats/admin", tags=["admin-stats"],
                   dependencies=[Depends(require_admin)])


@router.get("/overview")
def overview():
    """Alle Fragen mit Kernzahlen für das Dashboard."""
    with get_db() as conn:
        rows = conn.execute(
            """SELECT q.id, q.title, q.category, q.answer_type, q.status,
                      q.created_at, q.activated_at, q.starts_at, q.ends_at,
                      COALESCE(vt.cnt, 0)  AS total_votes,
                      COALESCE(v7.cnt, 0)  AS votes_7d,
                      COALESCE(v1.cnt, 0)  AS votes_24h,
                      vt.last_vote
               FROM questions q
               LEFT JOIN (SELECT question_id, COUNT(*) cnt, MAX(created_at) last_vote
                          FROM votes GROUP BY question_id) vt ON vt.question_id = q.id
               LEFT JOIN (SELECT question_id, COUNT(*) cnt FROM votes
                          WHERE created_at >= datetime('now', '-7 days')
                          GROUP BY question_id) v7 ON v7.question_id = q.id
               LEFT JOIN (SELECT question_id, COUNT(*) cnt FROM votes
                          WHERE created_at >= datetime('now', '-1 day')
                          GROUP BY question_id) v1 ON v1.question_id = q.id
               ORDER BY total_votes DESC, q.created_at DESC"""
        ).fetchall()
        total_votes = conn.execute("SELECT COUNT(*) c FROM votes").fetchone()["c"]
        devices = conn.execute("SELECT COUNT(*) c FROM user_auth").fetchone()["c"]
        accounts = conn.execute("SELECT COUNT(*) c FROM users").fetchone()["c"]

    return {
        "total_votes": total_votes,
        "registered_devices": devices,
        "accounts": accounts,
        "questions": [dict(r) for r in rows],
    }


def _question_or_404(conn, qid: str):
    q = conn.execute("SELECT * FROM questions WHERE id = ?", (qid,)).fetchone()
    if not q:
        raise HTTPException(status_code=404, detail="question_not_found")
    return q


@router.get("/{qid}/detail")
def question_detail(qid: str):
    """Volle Aufschlüsselung einer Frage — Zeitverlauf, Region, Alter."""
    with get_db() as conn:
        q = _question_or_404(conn, qid)

        answers = conn.execute(
            "SELECT answer, COUNT(*) cnt FROM votes WHERE question_id=? "
            "GROUP BY answer ORDER BY cnt DESC", (qid,)
        ).fetchall()

        timeline = conn.execute(
            "SELECT date(created_at) day, COUNT(*) cnt FROM votes "
            "WHERE question_id=? GROUP BY day ORDER BY day", (qid,)
        ).fetchall()

        by_bundesland = conn.execute(
            """SELECT COALESCE(l.bundesland,'Unbekannt') bundesland,
                      v.answer, COUNT(*) cnt
               FROM votes v LEFT JOIN landkreise l ON l.id = v.landkreis_id
               WHERE v.question_id=?
               GROUP BY l.bundesland, v.answer""", (qid,)
        ).fetchall()

        by_landkreis = conn.execute(
            """SELECT v.landkreis_id, COALESCE(l.name, v.landkreis_id) name,
                      COALESCE(l.bundesland,'') bundesland,
                      v.answer, COUNT(*) cnt
               FROM votes v LEFT JOIN landkreise l ON l.id = v.landkreis_id
               WHERE v.question_id=?
               GROUP BY v.landkreis_id, v.answer""", (qid,)
        ).fetchall()

        by_age = conn.execute(
            "SELECT age_group, answer, COUNT(*) cnt FROM votes "
            "WHERE question_id=? GROUP BY age_group, answer", (qid,)
        ).fetchall()

    def nest(rows, key):
        out: dict = {}
        for r in rows:
            k = r[key]
            entry = out.setdefault(k, {"total": 0, "answers": {}})
            entry["answers"][r["answer"]] = r["cnt"]
            entry["total"] += r["cnt"]
        return out

    landkreise: dict = {}
    for r in by_landkreis:
        e = landkreise.setdefault(r["landkreis_id"], {
            "name": r["name"], "bundesland": r["bundesland"],
            "total": 0, "answers": {}})
        e["answers"][r["answer"]] = r["cnt"]
        e["total"] += r["cnt"]

    return {
        "question": dict(q),
        "total_votes": sum(r["cnt"] for r in answers),
        "answers": {r["answer"]: r["cnt"] for r in answers},
        "timeline": [{"day": r["day"], "votes": r["cnt"]} for r in timeline],
        "by_bundesland": nest(by_bundesland, "bundesland"),
        "by_landkreis": landkreise,
        "by_age": nest(by_age, "age_group"),
    }


@router.get("/{qid}/export.csv")
def export_csv(qid: str):
    """Aggregierter Roh-Export: Landkreis × Altersgruppe × Antwort."""
    with get_db() as conn:
        q = _question_or_404(conn, qid)
        rows = conn.execute(
            """SELECT v.landkreis_id, COALESCE(l.name,'') landkreis,
                      COALESCE(l.bundesland,'') bundesland,
                      v.age_group, v.answer, COUNT(*) cnt
               FROM votes v LEFT JOIN landkreise l ON l.id = v.landkreis_id
               WHERE v.question_id=?
               GROUP BY v.landkreis_id, v.age_group, v.answer
               ORDER BY bundesland, landkreis, v.age_group""", (qid,)
        ).fetchall()

    buf = io.StringIO()
    w = csv.writer(buf, delimiter=";")
    w.writerow(["landkreis_id", "landkreis", "bundesland",
                "altersgruppe", "antwort", "stimmen"])
    for r in rows:
        w.writerow([r["landkreis_id"], r["landkreis"], r["bundesland"],
                    r["age_group"], r["answer"], r["cnt"]])
    buf.seek(0)
    fname = f"shm_{q['title'][:30].replace(' ', '_')}.csv"
    return StreamingResponse(
        iter([buf.getvalue()]), media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{fname}"'})
