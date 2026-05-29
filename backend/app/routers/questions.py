import uuid
import json
from fastapi import APIRouter, HTTPException, Header, Depends
from typing import Optional
from app.database import get_db
from app.schemas import QuestionCreate, QuestionOut
import os

router = APIRouter(prefix="/questions", tags=["questions"])

ADMIN_KEY = os.getenv("ADMIN_KEY", "")


def require_admin(x_admin_key: Optional[str] = Header(None)):
    if not ADMIN_KEY or x_admin_key != ADMIN_KEY:
        raise HTTPException(status_code=403, detail="forbidden")


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


@router.get("/", response_model=list[QuestionOut])
def list_active_questions():
    with get_db() as conn:
        rows = conn.execute(
            "SELECT * FROM questions WHERE status = 'active' ORDER BY activated_at DESC"
        ).fetchall()
        return [_row_to_out(r) for r in rows]


@router.post("/", response_model=QuestionOut, dependencies=[Depends(require_admin)])
def create_question(q: QuestionCreate):
    with get_db() as conn:
        qid = str(uuid.uuid4())
        options_json = json.dumps(q.options) if q.options else None
        conn.execute(
            """INSERT INTO questions (id, title, description, category, answer_type, options)
               VALUES (?,?,?,?,?,?)""",
            (qid, q.title, q.description, q.category, q.answer_type.value, options_json),
        )
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
    return QuestionOut(
        id=row["id"],
        title=row["title"],
        description=row["description"],
        category=row["category"],
        answer_type=row["answer_type"],
        options=json.loads(row["options"]) if row["options"] else None,
        status=row["status"],
        created_at=row["created_at"],
    )
