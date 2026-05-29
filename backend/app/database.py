import sqlite3
import os
from contextlib import contextmanager

DB_PATH = os.getenv("DB_PATH", "/app/data/socialheadmap.db")


def get_connection():
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


@contextmanager
def get_db():
    conn = get_connection()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def init_db():
    with get_db() as conn:
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS questions (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                description TEXT,
                category TEXT NOT NULL,
                answer_type TEXT NOT NULL CHECK(answer_type IN ('binary','scale','multiple_choice')),
                options TEXT,
                status TEXT DEFAULT 'draft' CHECK(status IN ('draft','active','archived')),
                created_at TEXT DEFAULT (datetime('now')),
                activated_at TEXT
            );

            CREATE TABLE IF NOT EXISTS user_auth (
                id TEXT PRIMARY KEY,
                device_token TEXT UNIQUE NOT NULL,
                email_hash TEXT UNIQUE,
                created_at TEXT DEFAULT (datetime('now'))
            );

            -- Bewusst KEIN FK zu user_auth — kein JOIN möglich (Privacy by Design)
            CREATE TABLE IF NOT EXISTS votes (
                id TEXT PRIMARY KEY,
                device_token TEXT NOT NULL,
                question_id TEXT NOT NULL,
                answer TEXT NOT NULL,
                landkreis_id TEXT NOT NULL,
                age_group TEXT NOT NULL CHECK(age_group IN ('A','B','C','D','E')),
                created_at TEXT DEFAULT (datetime('now')),
                UNIQUE(device_token, question_id)
            );

            CREATE TABLE IF NOT EXISTS landkreise (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                bundesland TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_votes_question ON votes(question_id);
            CREATE INDEX IF NOT EXISTS idx_votes_landkreis ON votes(landkreis_id, question_id);

            -- Social/Email-basierte Identitaet (getrennt von device_token, Privacy by Design)
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                provider TEXT NOT NULL,
                provider_hash TEXT UNIQUE NOT NULL,
                username TEXT UNIQUE NOT NULL,
                created_at TEXT DEFAULT (datetime('now'))
            );

            -- Magic Link Tokens (einmalig, 15 Minuten gueltig)
            CREATE TABLE IF NOT EXISTS magic_tokens (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                token TEXT UNIQUE NOT NULL,
                expires_at TEXT NOT NULL,
                used_at TEXT,
                FOREIGN KEY (user_id) REFERENCES users(id)
            );

            -- JWT Sessions fuer Logout / Invalidierung
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                jti TEXT UNIQUE NOT NULL,
                created_at TEXT DEFAULT (datetime('now')),
                invalidated_at TEXT,
                FOREIGN KEY (user_id) REFERENCES users(id)
            );

            CREATE INDEX IF NOT EXISTS idx_sessions_jti ON sessions(jti);
            CREATE INDEX IF NOT EXISTS idx_magic_tokens_token ON magic_tokens(token);
        """)
