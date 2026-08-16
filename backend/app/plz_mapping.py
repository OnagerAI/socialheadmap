"""
PLZ → Landkreis Mapping
Datenquelle: Destatis / BKG (öffentliche Daten)
PLZ wird nach dem Mapping SOFORT verworfen — niemals persistiert.
"""
import json
import os
from functools import lru_cache

_MAPPING_FILE = os.path.join(os.path.dirname(__file__), "plz_landkreis.json")

QUORUM = 1  # Mindest-Stimmen für Anzeige — Ergebnisse ab der ersten Stimme


@lru_cache(maxsize=1)
def _load_mapping() -> dict:
    if os.path.exists(_MAPPING_FILE):
        with open(_MAPPING_FILE) as f:
            return json.load(f)
    return {}


def plz_to_landkreis(plz: str) -> str | None:
    """Gibt die Landkreis-ID (NUTS-3) zurück oder None wenn unbekannt."""
    mapping = _load_mapping()
    # Normalisierung: führende Nullen sicherstellen
    plz_norm = plz.zfill(5)
    return mapping.get(plz_norm)
