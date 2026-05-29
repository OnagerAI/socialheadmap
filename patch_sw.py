#!/usr/bin/env python3
"""
Entfernt den Service Worker aus flutter_bootstrap.js nach dem Build.
Dadurch lädt der Browser nach jedem Deploy sofort den neuen Code —
kein Inkognito-Tab, kein manuelles Cache-Leeren notwendig.
"""
import re
import sys

path = "app/build/web/flutter_bootstrap.js"

try:
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
except FileNotFoundError:
    print(f"ERROR: {path} nicht gefunden — erst 'flutter build web' ausführen")
    sys.exit(1)

before = content

# Entferne serviceWorkerSettings-Block aus _flutter.loader.load({...})
content = re.sub(
    r"serviceWorkerSettings\s*:\s*\{[^}]*\},?\s*",
    "",
    content,
)

if content == before:
    print("WARN: serviceWorkerSettings nicht gefunden — möglicherweise bereits entfernt")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"OK: Service Worker deaktiviert in {path}")
