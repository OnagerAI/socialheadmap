#!/usr/bin/env python3
"""
Seed-Skript: Legt 15 gesellschaftlich relevante Fragen via Admin-API an.
Story: 577b094e

Verwendung:
    ADMIN_KEY=<dein-key> python3 seed_questions.py
"""

import os
import sys
import requests

BASE_URL = "https://shm.13-61-179-136.nip.io"
ADMIN_KEY = os.environ.get("ADMIN_KEY", "shm-admin-key-change-me")

HEADERS = {
    "X-Admin-Key": ADMIN_KEY,
    "Content-Type": "application/json",
}

QUESTIONS = [
    # Politik
    {
        "title": "Sollte das Wahlalter auf 16 Jahre gesenkt werden?",
        "category": "Politik",
        "question_type": "binary",
        "options": None,
    },
    {
        "title": "Sollte Cannabis in Deutschland vollständig legalisiert werden?",
        "category": "Politik",
        "question_type": "binary",
        "options": None,
    },
    {
        "title": "Befürworten Sie ein generelles Tempolimit auf deutschen Autobahnen?",
        "category": "Politik",
        "question_type": "binary",
        "options": None,
    },
    {
        "title": "Was ist die wichtigste politische Priorität?",
        "category": "Politik",
        "question_type": "multiple_choice",
        "options": ["Wirtschaft & Arbeit", "Klimaschutz", "Bildung & Familien", "Innere Sicherheit"],
    },
    # Gesellschaft
    {
        "title": "Sollte Deutschland mehr Flüchtlinge aufnehmen?",
        "category": "Gesellschaft",
        "question_type": "binary",
        "options": None,
    },
    {
        "title": "Vertrauen Sie den deutschen Medien?",
        "category": "Gesellschaft",
        "question_type": "binary",
        "options": None,
    },
    # Bildung
    {
        "title": "Sollten Schuluniformen an deutschen Schulen eingeführt werden?",
        "category": "Bildung",
        "question_type": "binary",
        "options": None,
    },
    {
        "title": "Wie bewerten Sie die Qualität des deutschen Bildungssystems?",
        "category": "Bildung",
        "question_type": "scale",
        "options": None,
    },
    # Wirtschaft
    {
        "title": "Sollte der gesetzliche Mindestlohn auf 14 Euro erhöht werden?",
        "category": "Wirtschaft",
        "question_type": "binary",
        "options": None,
    },
    {
        "title": "Sollte die 4-Tage-Woche bei gleichem Lohn eingeführt werden?",
        "category": "Wirtschaft",
        "question_type": "binary",
        "options": None,
    },
    {
        "title": "Sollte Homeoffice gesetzlich als Recht verankert werden?",
        "category": "Wirtschaft",
        "question_type": "binary",
        "options": None,
    },
    # Umwelt
    {
        "title": "Wie dringend ist der Klimaschutz für Sie persönlich?",
        "category": "Umwelt",
        "question_type": "scale",
        "options": None,
    },
    {
        "title": "Sollte Deutschland schneller aus der Kohleverstromung aussteigen?",
        "category": "Umwelt",
        "question_type": "binary",
        "options": None,
    },
    {
        "title": "Sollten E-Autos stärker staatlich gefördert werden?",
        "category": "Umwelt",
        "question_type": "binary",
        "options": None,
    },
    # Gesundheit
    {
        "title": "Wie zufrieden sind Sie mit dem deutschen Gesundheitssystem?",
        "category": "Gesundheit",
        "question_type": "scale",
        "options": None,
    },
]


def create_question(q: dict) -> dict | None:
    payload = {
        "title": q["title"],
        "category": q["category"],
        "answer_type": q["question_type"],
    }
    if q.get("options"):
        payload["options"] = q["options"]

    resp = requests.post(f"{BASE_URL}/questions/", json=payload, headers=HEADERS, timeout=15)
    if not resp.ok:
        print(f"  FEHLER beim Erstellen: {resp.status_code} — {resp.text}")
        return None
    return resp.json()


def activate_question(question_id: int | str) -> bool:
    resp = requests.patch(
        f"{BASE_URL}/questions/{question_id}/activate",
        headers=HEADERS,
        timeout=15,
    )
    if not resp.ok:
        print(f"  FEHLER beim Aktivieren (ID {question_id}): {resp.status_code} — {resp.text}")
        return False
    return True


def main() -> None:
    print(f"Backend: {BASE_URL}")
    print(f"Admin-Key: {'(aus ENV)' if os.environ.get('ADMIN_KEY') else '(default)'}")
    print(f"Fragen gesamt: {len(QUESTIONS)}\n")

    created = 0
    activated = 0
    errors = 0

    for i, q in enumerate(QUESTIONS, start=1):
        print(f"[{i:02d}/{len(QUESTIONS)}] {q['title'][:60]}")
        result = create_question(q)
        if result is None:
            errors += 1
            continue

        question_id = result.get("id")
        status = result.get("status", "?")
        created += 1
        print(f"       → ID: {question_id} | Typ: {q['question_type']} | Kategorie: {q['category']} | Status: {status}")

        if activate_question(question_id):
            activated += 1
            print(f"       → aktiviert")
        else:
            errors += 1

    print(f"\nFertig: {created} erstellt, {activated} aktiviert, {errors} Fehler.")
    if errors > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
