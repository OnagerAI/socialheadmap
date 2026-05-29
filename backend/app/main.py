import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from app.database import init_db
from app.routers import auth, votes, questions, stats

app = FastAPI(title="SocialHeadmap API", version="0.1.0", docs_url=None, redoc_url=None, openapi_url=None)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST", "PATCH"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(votes.router)
app.include_router(questions.router)
app.include_router(stats.router)


@app.on_event("startup")
def startup():
    init_db()


@app.get("/health")
def health():
    return {"status": "ok", "service": "socialheadmap"}


@app.get("/admin")
def admin_panel():
    path = os.path.join(os.path.dirname(__file__), "admin.html")
    return FileResponse(path, media_type="text/html")


# Flutter Web — muss zuletzt gemountet werden (catch-all)
_web_dir = "/app/web"
if os.path.isdir(_web_dir):
    app.mount("/", StaticFiles(directory=_web_dir, html=True), name="web")
