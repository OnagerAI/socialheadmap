import json
import asyncio
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from app.database import get_db
from app.schemas import MapSnapshot, LandkreisResult, BundeslandSnapshot, BundeslandResult, BundeslandDetail, LandkreisDetail
from app.plz_mapping import QUORUM

router = APIRouter(prefix="/stats", tags=["stats"])


def _require_own_vote(conn, question_id: str, device_token: str | None) -> None:
    """Fair Play serverseitig: Ergebnisse gibt es erst nach eigener Stimme."""
    if not device_token:
        raise HTTPException(status_code=403, detail="vote_required")
    row = conn.execute(
        "SELECT 1 FROM votes WHERE device_token = ? AND question_id = ?",
        (device_token, question_id),
    ).fetchone()
    if not row:
        raise HTTPException(status_code=403, detail="vote_required")


@router.get("/map/{question_id}", response_model=MapSnapshot)
def get_map_snapshot(question_id: str, device_token: str | None = None):
    with get_db() as conn:
        q = conn.execute(
            "SELECT id FROM questions WHERE id = ? AND status IN ('active','archived')", (question_id,)
        ).fetchone()
        if not q:
            raise HTTPException(status_code=404, detail="question_not_found")
        _require_own_vote(conn, question_id, device_token)

        rows = conn.execute(
            """SELECT v.landkreis_id, l.name, v.answer, COUNT(*) as cnt
               FROM votes v
               LEFT JOIN landkreise l ON l.id = v.landkreis_id
               WHERE v.question_id = ?
               GROUP BY v.landkreis_id, v.answer""",
            (question_id,),
        ).fetchall()

    # Aggregieren pro Landkreis
    lk_data: dict[str, dict] = {}
    for row in rows:
        lid = row["landkreis_id"]
        if lid not in lk_data:
            lk_data[lid] = {"name": row["name"] or lid, "results": {}, "total": 0}
        lk_data[lid]["results"][row["answer"]] = row["cnt"]
        lk_data[lid]["total"] += row["cnt"]

    results = []
    for lid, data in lk_data.items():
        has_quorum = data["total"] >= QUORUM
        results.append(LandkreisResult(
            landkreis_id=lid,
            landkreis_name=data["name"],
            total_votes=data["total"],
            results=data["results"] if has_quorum else {},  # ohne Quorum: leere Daten
            has_quorum=has_quorum,
        ))

    return MapSnapshot(question_id=question_id, landkreise=results)


@router.get("/map/{question_id}/total")
def get_total_votes(question_id: str):
    """Leichter Zähler für den Live-Modus der App (Polling)."""
    with get_db() as conn:
        total = conn.execute(
            "SELECT COUNT(*) as c FROM votes WHERE question_id = ?", (question_id,)
        ).fetchone()["c"]
    return {"question_id": question_id, "total_votes": total}


@router.get("/map/{question_id}/live")
async def live_updates(question_id: str):
    """SSE-Stream: sendet alle 10s die aktuelle Gesamtstimmenzahl.

    Deprecated — die App pollt stattdessen /total. Bleibt für alte Clients.
    """
    async def event_generator():
        while True:
            with get_db() as conn:
                total = conn.execute(
                    "SELECT COUNT(*) as c FROM votes WHERE question_id = ?", (question_id,)
                ).fetchone()["c"]
            yield f"data: {json.dumps({'total_votes': total})}\n\n"
            await asyncio.sleep(10)

    return StreamingResponse(event_generator(), media_type="text/event-stream")


@router.get("/map/{question_id}/bundeslaender", response_model=BundeslandSnapshot)
def get_bundesland_snapshot(question_id: str, device_token: str | None = None):
    with get_db() as conn:
        q = conn.execute(
            "SELECT id FROM questions WHERE id = ? AND status IN ('active','archived')", (question_id,)
        ).fetchone()
        if not q:
            raise HTTPException(status_code=404, detail="question_not_found")
        _require_own_vote(conn, question_id, device_token)

        rows = conn.execute(
            """SELECT l.bundesland, COUNT(*) as total_votes
               FROM votes v
               LEFT JOIN landkreise l ON l.id = v.landkreis_id
               WHERE v.question_id = ?
               GROUP BY l.bundesland""",
            (question_id,),
        ).fetchall()

    results = [
        BundeslandResult(name=row["bundesland"] or "Unbekannt", total_votes=row["total_votes"])
        for row in rows
    ]
    return BundeslandSnapshot(question_id=question_id, bundeslaender=results)


@router.get("/map/{question_id}/bundesland-detail", response_model=BundeslandDetail)
def get_bundesland_detail(question_id: str, bundesland: str,
                          device_token: str | None = None):
    with get_db() as conn:
        q = conn.execute(
            "SELECT id FROM questions WHERE id = ? AND status IN ('active','archived')", (question_id,)
        ).fetchone()
        if not q:
            raise HTTPException(status_code=404, detail="question_not_found")
        _require_own_vote(conn, question_id, device_token)

        # Quorum-Schutz (Art.-9-Daten): nur Landkreise einbeziehen, die das
        # Quorum erreichen — sonst wären Einzelantworten rekonstruierbar.
        rows = conn.execute(
            """SELECT v.age_group, v.answer, COUNT(*) as cnt
               FROM votes v
               LEFT JOIN landkreise l ON l.id = v.landkreis_id
               WHERE v.question_id = ? AND l.bundesland = ?
                 AND v.landkreis_id IN (
                     SELECT landkreis_id FROM votes
                     WHERE question_id = ?
                     GROUP BY landkreis_id
                     HAVING COUNT(*) >= ?
                 )
               GROUP BY v.age_group, v.answer""",
            (question_id, bundesland, question_id, QUORUM),
        ).fetchall()

    age_groups: dict = {}
    total_answers: dict = {}
    total_votes = 0

    for row in rows:
        ag = row["age_group"]
        answer = row["answer"]
        cnt = row["cnt"]
        if ag not in age_groups:
            age_groups[ag] = {"total": 0, "answers": {}}
        age_groups[ag]["answers"][answer] = cnt
        age_groups[ag]["total"] += cnt
        total_answers[answer] = total_answers.get(answer, 0) + cnt
        total_votes += cnt

    return BundeslandDetail(
        bundesland=bundesland,
        question_id=question_id,
        total_votes=total_votes,
        total_answers=total_answers,
        age_groups=age_groups,
    )


@router.get("/map/{question_id}/landkreis-detail", response_model=LandkreisDetail)
def get_landkreis_detail(question_id: str, landkreis_id: str,
                         device_token: str | None = None):
    with get_db() as conn:
        q = conn.execute(
            "SELECT id FROM questions WHERE id = ? AND status IN ('active','archived')", (question_id,)
        ).fetchone()
        if not q:
            raise HTTPException(status_code=404, detail="question_not_found")
        _require_own_vote(conn, question_id, device_token)

        lk = conn.execute(
            "SELECT id, name FROM landkreise WHERE id = ?", (landkreis_id,)
        ).fetchone()

        rows = conn.execute(
            """SELECT v.age_group, v.answer, COUNT(*) as cnt
               FROM votes v
               WHERE v.question_id = ? AND v.landkreis_id = ?
               GROUP BY v.age_group, v.answer""",
            (question_id, landkreis_id),
        ).fetchall()

    age_groups: dict = {}
    total_answers: dict = {}
    total_votes = 0

    for row in rows:
        ag = row["age_group"]
        answer = row["answer"]
        cnt = row["cnt"]
        if ag not in age_groups:
            age_groups[ag] = {"total": 0, "answers": {}}
        age_groups[ag]["answers"][answer] = cnt
        age_groups[ag]["total"] += cnt
        total_answers[answer] = total_answers.get(answer, 0) + cnt
        total_votes += cnt

    # Quorum-Schutz: unterhalb des Quorums keine Aufschlüsselung liefern —
    # nur die Gesamtzahl (konsistent zur Karten-API).
    has_quorum = total_votes >= QUORUM
    return LandkreisDetail(
        landkreis_id=landkreis_id,
        landkreis_name=lk["name"] if lk else landkreis_id,
        question_id=question_id,
        total_votes=total_votes,
        has_quorum=has_quorum,
        total_answers=total_answers if has_quorum else {},
        age_groups=age_groups if has_quorum else {},
    )


@router.get("/geojson/landkreise")
def get_landkreise_geojson():
    import os
    from fastapi.responses import FileResponse
    path = os.path.join(os.path.dirname(__file__), '..', 'landkreise.geojson')
    path = os.path.abspath(path)
    if not os.path.exists(path):
        raise HTTPException(status_code=503, detail="geojson_not_available")
    return FileResponse(path, media_type="application/geo+json",
                       headers={"Cache-Control": "public, max-age=86400"})
