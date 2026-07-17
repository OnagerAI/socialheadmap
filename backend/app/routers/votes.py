import uuid
from fastapi import APIRouter, HTTPException
from app.database import get_db
from app.schemas import VoteRequest, VoteResponse
from app.plz_mapping import plz_to_landkreis

router = APIRouter(prefix="/votes", tags=["votes"])


@router.post("/", response_model=VoteResponse)
def submit_vote(req: VoteRequest):
    # PLZ → Landkreis-ID (PLZ wird danach nicht mehr verwendet)
    landkreis_id = plz_to_landkreis(req.plz)
    if not landkreis_id:
        raise HTTPException(status_code=422, detail="unknown_plz")

    with get_db() as conn:
        # Device-Token muss registriert sein
        row = conn.execute(
            "SELECT id FROM user_auth WHERE device_token = ?", (req.device_token,)
        ).fetchone()
        if not row:
            raise HTTPException(status_code=401, detail="device_not_registered")

        # Frage muss aktiv sein und im Zeitfenster liegen
        q = conn.execute(
            "SELECT id, answer_type, options FROM questions "
            "WHERE id = ? AND status = 'active' "
            "AND (starts_at IS NULL OR starts_at <= datetime('now'))",
            (req.question_id,),
        ).fetchone()
        if not q:
            raise HTTPException(status_code=404, detail="question_not_found")
        closed = conn.execute(
            "SELECT 1 FROM questions WHERE id = ? "
            "AND ends_at IS NOT NULL AND ends_at <= datetime('now')",
            (req.question_id,),
        ).fetchone()
        if closed:
            raise HTTPException(status_code=410, detail="question_closed")

        # Antwort validieren
        _validate_answer(req.answer, q)

        vote_id = str(uuid.uuid4())
        try:
            conn.execute(
                """INSERT INTO votes (id, device_token, question_id, answer, landkreis_id, age_group)
                   VALUES (?,?,?,?,?,?)""",
                (vote_id, req.device_token, req.question_id, req.answer,
                 landkreis_id, req.age_group.value),
            )
        except Exception:
            raise HTTPException(status_code=409, detail="already_voted")

        return VoteResponse(success=True, vote_id=vote_id)


@router.get("/mine")
def my_votes(device_token: str):
    """Eigene Votes dieses Geräts — für 'Meine Antworten' nach Neuinstallation.

    Liefert bewusst nur Frage-Metadaten und die eigene Antwort; keine
    Regionsdaten (die Landkreis-Zuordnung bleibt serverintern).
    """
    with get_db() as conn:
        row = conn.execute(
            "SELECT id FROM user_auth WHERE device_token = ?", (device_token,)
        ).fetchone()
        if not row:
            raise HTTPException(status_code=401, detail="device_not_registered")

        rows = conn.execute(
            """SELECT v.question_id, v.answer, v.created_at,
                      q.title AS question_title, q.category
               FROM votes v
               JOIN questions q ON q.id = v.question_id
               WHERE v.device_token = ?
               ORDER BY v.created_at DESC""",
            (device_token,),
        ).fetchall()

    return {
        "votes": [
            {
                "question_id": r["question_id"],
                "answer": r["answer"],
                "created_at": r["created_at"],
                "question_title": r["question_title"],
                "category": r["category"],
            }
            for r in rows
        ]
    }


def _validate_answer(answer: str, question) -> None:
    import json
    answer_type = question["answer_type"]
    if answer_type == "binary" and answer not in ("ja", "nein"):
        raise HTTPException(status_code=422, detail="invalid_answer_binary")
    if answer_type == "scale":
        if answer not in ("1", "2", "3", "4", "5"):
            raise HTTPException(status_code=422, detail="invalid_answer_scale")
    if answer_type == "multiple_choice":
        options = json.loads(question["options"] or "[]")
        if answer not in options:
            raise HTTPException(status_code=422, detail="invalid_answer_option")
