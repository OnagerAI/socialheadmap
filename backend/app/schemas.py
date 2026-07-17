from pydantic import BaseModel, Field
from typing import Optional, List
from enum import Enum


class AgeGroup(str, Enum):
    A = "A"  # 18-29
    B = "B"  # 30-39
    C = "C"  # 40-49
    D = "D"  # 50-59
    E = "E"  # 60+


class AnswerType(str, Enum):
    binary = "binary"
    scale = "scale"
    multiple_choice = "multiple_choice"


class QuestionStatus(str, Enum):
    draft = "draft"
    active = "active"
    archived = "archived"


# Auth — Device Token (legacy, Voting)
class RegisterRequest(BaseModel):
    device_token: str = Field(..., min_length=36, max_length=36)
    email_hash: Optional[str] = None


class RegisterResponse(BaseModel):
    registered: bool
    device_token: str


# Auth — Social / Magic Link
class SocialLoginRequest(BaseModel):
    provider: str  # "google" | "facebook"
    access_token: str


class MagicLinkRequest(BaseModel):
    email: str = Field(..., min_length=5, max_length=254)


class MagicLinkVerifyRequest(BaseModel):
    token: str = Field(..., min_length=64, max_length=64)


class AuthResponse(BaseModel):
    jwt: str
    username: str
    provider: str


class UserProfile(BaseModel):
    user_id: str
    username: str
    provider: str


# Votes
class VoteRequest(BaseModel):
    device_token: str
    question_id: str
    answer: str
    plz: str = Field(..., min_length=5, max_length=5)  # wird serverseitig gemappt + verworfen
    age_group: AgeGroup


class VoteResponse(BaseModel):
    success: bool
    vote_id: str


# Questions
class QuestionCreate(BaseModel):
    title: str
    description: Optional[str] = None
    category: str
    answer_type: AnswerType
    options: Optional[List[str]] = None
    starts_at: Optional[str] = None   # ISO-8601, UTC
    ends_at: Optional[str] = None


class QuestionPatch(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    options: Optional[List[str]] = None
    starts_at: Optional[str] = None   # "" löscht das Datum
    ends_at: Optional[str] = None


class QuestionOut(BaseModel):
    id: str
    title: str
    description: Optional[str]
    category: str
    answer_type: str
    options: Optional[List[str]]
    status: str
    created_at: str
    starts_at: Optional[str] = None
    ends_at: Optional[str] = None


class TopQuestionOut(BaseModel):
    rank: int
    question: QuestionOut
    votes_7d: int
    total_votes: int


# Stats
class LandkreisResult(BaseModel):
    landkreis_id: str
    landkreis_name: str
    total_votes: int
    results: dict  # answer -> count
    has_quorum: bool  # True wenn >= 10 Stimmen


class MapSnapshot(BaseModel):
    question_id: str
    landkreise: List[LandkreisResult]


class BundeslandResult(BaseModel):
    name: str
    total_votes: int


class BundeslandSnapshot(BaseModel):
    question_id: str
    bundeslaender: List[BundeslandResult]


class AgeGroupAnswers(BaseModel):
    total: int = 0
    answers: dict = {}   # answer -> count, e.g. {"ja": 5, "nein": 3}


class BundeslandDetail(BaseModel):
    bundesland: str
    question_id: str
    total_votes: int
    total_answers: dict = {}          # answer -> count across all age groups
    age_groups: dict = {}             # age_key -> AgeGroupAnswers as dict


class LandkreisDetail(BaseModel):
    landkreis_id: str
    landkreis_name: str
    question_id: str
    total_votes: int
    has_quorum: bool
    total_answers: dict = {}
    age_groups: dict = {}
