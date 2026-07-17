#!/usr/bin/env python3
"""Erzeugt 4 App-Icon-Konzepte für SocialHeadmap (1024px, full-bleed)."""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

S = 2048          # Arbeitsgröße (2x, wird auf 1024 verkleinert)
OUT = Path(__file__).parent / "logos"
OUT.mkdir(exist_ok=True)

GEOJSON = str(Path(__file__).resolve().parents[1] / "backend/app/landkreise.geojson")

# Markenfarben
BLUE_DARK = (13, 71, 161)     # 0D47A1
BLUE_MID = (21, 101, 192)     # 1565C0
BLUE_LIGHT = (30, 136, 229)   # 1E88E5
YES = (67, 160, 71)
NO = (211, 47, 47)
YELLOW = (255, 204, 0)
SCALE_COLORS = [(198, 40, 40), (230, 74, 25), (249, 168, 37),
                (124, 179, 66), (46, 125, 50)]


# ── Deutschland-Silhouette als Maske ─────────────────────────────────────────

def germany_mask(size, margin_frac=0.10):
    d = json.load(open(GEOJSON))
    pts_all = []
    rings = []
    for f in d["features"]:
        g = f["geometry"]
        polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        for poly in polys:
            ring = poly[0]
            rings.append(ring)
            pts_all.extend(ring)
    lat0 = 51.16
    xs = [p[0] * math.cos(math.radians(lat0)) for p in pts_all]
    ys = [p[1] for p in pts_all]
    minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
    w, h = maxx - minx, maxy - miny
    usable = size * (1 - 2 * margin_frac)
    scale = usable / max(w, h)
    ox = (size - w * scale) / 2
    oy = (size - h * scale) / 2

    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    for ring in rings:
        pts = [((p[0] * math.cos(math.radians(lat0)) - minx) * scale + ox,
                (maxy - p[1]) * scale + oy) for p in ring]
        if len(pts) >= 3:
            md.polygon(pts, fill=255)
    # Ränder minimal glätten und schließen (Landkreis-Fugen)
    mask = mask.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(1.5))
    return mask.point(lambda v: 255 if v > 120 else 0)


def gradient(size, c1, c2, diagonal=True):
    big = int(size * 1.5)
    img = Image.new("RGB", (big, big))
    dr = ImageDraw.Draw(img)
    for i in range(big):
        t = i / (big - 1)
        col = tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))
        dr.line([(0, i), (big, i)], fill=col)
    if diagonal:
        img = img.rotate(-14, resample=Image.BICUBIC)
    off = (big - size) // 2
    return img.crop((off, off, off + size, off + size))


def lerp(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def draw_gauge(draw, cx, cy, r, width, needle_angle=322, needle_color=(255, 255, 255),
               hub_color=(255, 255, 255), gap=4):
    """Halbkreis-Tacho 180°→360° (oben), 5 Farbsegmente, Nadel."""
    bbox = [cx - r, cy - r, cx + r, cy + r]
    seg = (360 - 180) / 5
    for i, col in enumerate(SCALE_COLORS):
        a0 = 180 + i * seg + (gap if i > 0 else 0) / 2
        a1 = 180 + (i + 1) * seg - (gap if i < 4 else 0) / 2
        draw.arc(bbox, a0, a1, fill=col, width=width)
    # Nadel
    ang = math.radians(needle_angle)
    tip = (cx + math.cos(ang) * (r - width * 0.25),
           cy + math.sin(ang) * (r - width * 0.25))
    back = (cx - math.cos(ang) * r * 0.16, cy - math.sin(ang) * r * 0.16)
    perp = (math.cos(ang + math.pi / 2), math.sin(ang + math.pi / 2))
    hw = max(6, r * 0.055)
    draw.polygon([
        (back[0] + perp[0] * hw, back[1] + perp[1] * hw),
        (back[0] - perp[0] * hw, back[1] - perp[1] * hw),
        tip,
    ], fill=needle_color)
    hub = r * 0.11
    draw.ellipse([cx - hub, cy - hub, cx + hub, cy + hub], fill=hub_color)


def radial_blob(layer, cx, cy, r, color, max_alpha=200):
    """Weicher Farbfleck (Heat-Spot) auf RGBA-Layer."""
    dr = ImageDraw.Draw(layer)
    steps = 40
    for i in range(steps, 0, -1):
        t = i / steps
        a = int(max_alpha * (1 - t) ** 1.6)
        rr = r * t
        dr.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=color + (a,))


def save(img, name):
    img = img.resize((1024, 1024), Image.LANCZOS)
    img.save(OUT / f"{name}.png")
    print("gespeichert:", name)


MASK = germany_mask(S)
MASK_SMALL = germany_mask(S, margin_frac=0.16)

# ── Konzept A: Stimmungsbarometer ────────────────────────────────────────────
img = gradient(S, BLUE_DARK, BLUE_LIGHT)
d = ImageDraw.Draw(img)
cx, cy, r, w = S / 2, S * 0.60, S * 0.335, int(S * 0.085)
draw_gauge(d, cx, cy, r, w, needle_angle=318)
save(img, "A_barometer")

# ── Konzept B: Heatmap Deutschland ───────────────────────────────────────────
img = gradient(S, BLUE_DARK, BLUE_LIGHT)
sil = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sil.paste((255, 255, 255, 255), mask=MASK)
blobs = Image.new("RGBA", (S, S), (0, 0, 0, 0))
radial_blob(blobs, S * 0.40, S * 0.30, S * 0.24, NO)
radial_blob(blobs, S * 0.62, S * 0.52, S * 0.28, YELLOW)
radial_blob(blobs, S * 0.42, S * 0.68, S * 0.26, YES)
radial_blob(blobs, S * 0.66, S * 0.24, S * 0.16, (255, 143, 0))
blobs.putalpha(Image.composite(blobs.split()[3], Image.new("L", (S, S), 0), MASK))
base = Image.new("RGBA", (S, S), (0, 0, 0, 0))
base.paste((232, 241, 251, 255), mask=MASK)
img = img.convert("RGBA")
img.alpha_composite(base)
img.alpha_composite(blobs)
save(img.convert("RGB"), "B_heatmap")

# ── Konzept C: Karte + Barometer-Badge ───────────────────────────────────────
img = gradient(S, BLUE_DARK, BLUE_LIGHT).convert("RGBA")
sil_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sil_small = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sil_small.paste((255, 255, 255, 235), mask=MASK_SMALL)
sil_layer.alpha_composite(sil_small, (int(-S * 0.05), int(-S * 0.05)))
img.alpha_composite(sil_layer)
badge_r = S * 0.24
bx, by = S * 0.68, S * 0.70
bd = ImageDraw.Draw(img)
bd.ellipse([bx - badge_r, by - badge_r, bx + badge_r, by + badge_r],
           fill=(255, 255, 255, 255))
draw_gauge(bd, bx, by + badge_r * 0.28, badge_r * 0.62, int(badge_r * 0.26),
           needle_angle=318, needle_color=BLUE_DARK, hub_color=BLUE_DARK, gap=6)
save(img.convert("RGB"), "C_karte_badge")

# ── Konzept D: Stimmungs-Split Deutschland ───────────────────────────────────
img = gradient(S, BLUE_DARK, BLUE_MID).convert("RGBA")
grad = Image.new("RGBA", (S, S))
gd = ImageDraw.Draw(grad)
g_yes = (76, 175, 80)
g_no = (229, 57, 53)
for x in range(S):
    t = x / (S - 1)
    if t < 0.42:
        col = g_yes
    elif t > 0.58:
        col = g_no
    else:
        col = lerp(g_yes, g_no, (t - 0.42) / 0.16)
    gd.line([(x, 0), (x, S)], fill=col + (255,))
grad.putalpha(MASK)
# weiße Kontur für Pop
outline = MASK.filter(ImageFilter.MaxFilter(19))
outline_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
outline_layer.paste((255, 255, 255, 255), mask=outline)
img.alpha_composite(outline_layer)
img.alpha_composite(grad)
save(img.convert("RGB"), "D_split")

# ── Konzept C2: Karte in Flaggenfarben + Barometer-Badge ─────────────────────
def concept_c2(needle=318):
    img = gradient(S, BLUE_DARK, BLUE_LIGHT).convert("RGBA")
    # Deutschland-Silhouette gefüllt mit Schwarz-Rot-Gold (horizontale Drittel)
    flag = Image.new("RGBA", (S, S))
    fd = ImageDraw.Draw(flag)
    # Streifen relativ zur Silhouetten-Bounding-Box, nicht zum Canvas
    bbox = MASK_SMALL.getbbox()
    top, bot = bbox[1], bbox[3]
    third = (bot - top) / 3
    fd.rectangle([0, 0, S, top + third], fill=(20, 20, 20, 255))
    fd.rectangle([0, top + third, S, top + 2 * third], fill=(221, 0, 0, 255))
    fd.rectangle([0, top + 2 * third, S, S], fill=(255, 204, 0, 255))
    flag.putalpha(MASK_SMALL)
    # weiße Kontur, damit die Karte auf Blau knackig bleibt
    outline = MASK_SMALL.filter(ImageFilter.MaxFilter(17))
    ol = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ol.paste((255, 255, 255, 255), mask=outline)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    layer.alpha_composite(ol)
    layer.alpha_composite(flag)
    img.alpha_composite(layer, (int(-S * 0.05), int(-S * 0.05)))
    # Barometer-Badge
    badge_r = S * 0.24
    bx, by = S * 0.68, S * 0.70
    bd = ImageDraw.Draw(img)
    bd.ellipse([bx - badge_r, by - badge_r, bx + badge_r, by + badge_r],
               fill=(255, 255, 255, 255))
    draw_gauge(bd, bx, by + badge_r * 0.28, badge_r * 0.62, int(badge_r * 0.26),
               needle_angle=needle, needle_color=BLUE_DARK, hub_color=BLUE_DARK,
               gap=6)
    return img.convert("RGB")

if __name__ == "__main__":
    save(concept_c2(), "C2_flagge")
