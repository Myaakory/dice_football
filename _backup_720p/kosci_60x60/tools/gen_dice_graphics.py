"""Generuje grafiki kości (1080p) do assets/graphics/dice (uruchom: python tools/gen_dice_graphics.py [katalog_podglądu]).

- die_icons.png / die_icon_masks.png : 9 ikonek cech 20x20 w komórkach 22x22 (kolejność DieGraphics.ATTRIBUTE_ORDER).
      Maska = sylwetka ikonki rozlana o 0..2 px w prawo/w dół (cień i "wycięcie" na ściance).
      Kolory wg systemu jasności (grafiki_brudnopis/propozycje_ikon/system_jasnosci): w każdej kości jedna ikonka
      jasna, jedna ciemna i jedna w kolorze sygnaturowym kości.
- die_bodies.png      : korpusy 60x60 (physical, technical, defensive).
- die_max_rim.png     : złota obwódka ścianki "6" (nakładana na korpus).
- die_roll_<typ>.png  : animacja rzutu, 9 klatek 96x96 (6 koziołkowania w pętli + 3 lądowania).
- die_shadow.png      : cień kości pod animacją (96x96).
Wersje 720p (ikonki 14 px, kości 40x40) są w _backup_720p/assets/graphics/dice.
"""

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
DICE_DIR = ROOT / "assets" / "graphics" / "dice"

FACE = 60
LIP = 7  # wysokość "przodu" kości pod ścianką (dolny pas)
ROLL_FRAME = 96
ICON = 20
ICON_CELL = 22

TYPES = ["physical", "technical", "defensive"]
ORDER = ["strength", "speed", "jump", "pass", "shot", "control", "tackle", "pressing", "reading"]


def hex_rgba(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# ───────────────────────── ikonki cech ─────────────────────────
# Legenda siatek:
#   .  puste (kontur dodawany automatycznie wokół wypełnienia, 4-sąsiedztwo)
#   o  kontur wewnątrz ikonki      #  baza (piksel bez wypełnienia pod spodem -> cień d)
#   B  baza      h  jasny      d  cień      w  biały (dolna krawędź -> W)      W  cień bieli
#   k, m, n, x, y  dodatkowe kolory z palety ikonki

OUTLINE = "#241a26"
LIGHT = dict(b="#f3ece0", h="#ffffff", d="#b9ab98", w="#ffffff", W="#d9cfbf")
DARK = dict(b="#3a2c3e", h="#7a6682", d="#2a1f2e", w="#8a7690", W="#6c5873")
SIG = {
    "physical": dict(b="#7ee08c", h="#c6f7cb", d="#3a9e55"),
    "technical": dict(b="#ffa64a", h="#ffd7a6", d="#c96a22"),
    "defensive": dict(b="#a97cff", h="#d9c6ff", d="#6f47c4"),
}
ROLE = {
    "strength": "light", "speed": "sig", "jump": "dark",
    "pass": "light", "shot": "sig", "control": "dark",
    "tackle": "dark", "pressing": "sig", "reading": "light",
}
EXTRA = {
    "control": dict(k="#6c5873"),
    "tackle": dict(n="#d6cbd8", N="#9d8ea2", m="#6c5873"),
}


def icon_palette(skill):
    role = ROLE[skill]
    if role == "light":
        pal = dict(LIGHT)
    elif role == "dark":
        pal = dict(DARK)
    else:
        sig = SIG[TYPES[ORDER.index(skill) // 3]]
        pal = dict(sig, w=sig["h"], W=sig["b"])
    pal.setdefault("x", pal["d"])
    pal.setdefault("y", pal["h"])
    pal["o"] = OUTLINE
    pal.update(EXTRA.get(skill, {}))
    return pal


class Grid:
    def __init__(self, rows=None):
        self.p = [["."] * ICON for _ in range(ICON)]
        if rows:
            assert len(rows) == ICON, len(rows)
            for y, row in enumerate(rows):
                assert len(row) == ICON, f"row {y} len {len(row)}: {row!r}"
                self.p[y] = list(row)

    def get(self, x, y):
        return self.p[y][x] if 0 <= x < ICON and 0 <= y < ICON else "."

    def filled(self, x, y):
        return self.get(x, y) not in (".", "o")

    def finish(self):
        out = [r[:] for r in self.p]
        for y in range(ICON):
            for x in range(ICON):
                c = self.p[y][x]
                below_empty = not self.filled(x, y + 1)
                if c == "#":
                    out[y][x] = "d" if below_empty else "b"
                elif c == "B":
                    out[y][x] = "b"
                elif c == "w" and below_empty:
                    out[y][x] = "W"
                elif c == "." and any(self.get(x + dx, y + dy) != "." for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    out[y][x] = "o"  # kontur obejmuje też łaty "o" na brzegu (piłki)
        return out


def icon_strength():  # pięść
    return Grid([
        "....................",
        "....................",
        "...hhh.hhh.hhh......",
        "...hBB.hBB.hBB.hhh..",
        "...hBB.hBB.hBB.hBB..",
        "...BBB.BBB.BBB.hBB..",
        "...BBB.BBB.BBB.BBd..",
        "...BBB.BBB.BBB.BBd..",
        "...ddd.ddd.BBB.BBd..",
        "...........BBB.BBd..",
        ".hhhhhhhhhhBBd.BBd..",
        ".hBBBBBBBBBBBd.BBd..",
        ".ddddddddddBBd.BBd..",
        "...........BBd.BBd..",
        "..hBBBBBBBBBBBBBBd..",
        "...hBBBBBBBBBBBBd...",
        "....dddddddddddd....",
        "....................",
        "....................",
        "....................",
    ])


def icon_speed():  # błyskawica
    return Grid([
        "....................",
        ".........#######....",
        "........#hh####.....",
        ".......#hh####......",
        "......#hh####.......",
        ".....#hh####........",
        "....#hh####.........",
        "...#hh##########....",
        "...#h###########....",
        "...#############....",
        "..........######....",
        ".........######.....",
        "........######......",
        ".......######.......",
        "......#####.........",
        ".....####...........",
        "....###.............",
        "...##...............",
        "...#................",
        "....................",
    ])


def icon_jump():  # strzałka w górę na podstawie
    return Grid([
        "....................",
        ".........##.........",
        "........#hh#........",
        ".......#hh###.......",
        "......#hh#####......",
        ".....#hh#######.....",
        "....#hh#########....",
        "...#hh###########...",
        "..#h##############..",
        ".......BhBBd........",
        ".......BhBBd........",
        ".......BhBBd........",
        ".......BhBBd........",
        ".......BBBdd........",
        ".......dddddd.......",
        "....................",
        ".hBBBBBBBBBBBBBBBBd.",
        ".dddddddddddddddddd.",
        "....................",
        "....................",
    ])


def icon_pass():  # zakręcona strzałka (łuk z grotem w dół)
    g = Grid()
    cx, cy = 8.5, 12.0
    for y in range(ICON):
        for x in range(ICON):
            px, py = x + 0.5, y + 0.5
            r = math.hypot(px - cx, py - cy)
            if py <= cy and 4.5 <= r < 7.5:
                g.p[y][x] = "h" if r >= 6.5 else ("B" if r >= 5.5 else "d")
    for y in (12, 13):
        g.p[y][1:4] = list("hBd")
    g.p[14][1:4] = list("ddd")
    head = [(12, 10, 18), (13, 11, 17), (14, 12, 16), (15, 13, 15), (16, 14, 14)]
    for y, x0, x1 in head:
        for x in range(x0, x1 + 1):
            g.p[y][x] = "h" if y == 12 else "#"
    return g


def icon_shot():  # piłka z liniami pędu
    ball = [
        "...hdddB...",
        "..hhhdBBB..",
        ".hhhBdBBBB.",
        "hhBBoooBBBB",
        "ddBoooooBdd",
        "dhBoooooBBd",
        "hBBBoooBBBd",
        "BBBdBBBdBBd",
        ".BdBBBBBdd.",
        "..ddBBBdd..",
        "...ddddd...",
    ]
    lines = {2: "...yyyy.", 5: ".xxxxxx.", 8: "...yyyy."}
    rows = ["." * ICON] * 4
    rows += [lines.get(i, "." * 8) + row + "." for i, row in enumerate(ball)]
    rows += ["." * ICON] * (ICON - len(rows))
    return Grid(rows)


def icon_control():  # podeszwa buta na piłce
    return Grid([
        "....................",
        "..hhhh..............",
        "..hBBB..............",
        "..hBBB..............",
        "..hBBB.hhhh.........",
        "..hBBBBBBBBhhh......",
        "..hBBBBBBBBBBBhh....",
        "..hBBBBBBBBBBBBBBd..",
        "..kkkkkkkkkkkkkkkk..",
        "....................",
        "........wwww........",
        ".......wwwwwW.......",
        "......wwwoowwW......",
        "......Wwoooowo......",
        "......WwwoowWW......",
        "......wwwwwwWW......",
        ".......WWWWWW.......",
        "........WWWW........",
        "....................",
        "....................",
    ])


def icon_tackle():  # tarcza z szewronem
    return Grid([
        "....................",
        "..hhhhhhhhhhhhhhhh..",
        "..hmmmmmmmmmmmmmmd..",
        "..nnmmmmmmmmmmmmnn..",
        "..hnnmmmmmmmmmmnnd..",
        "..h#nnmmmmmmmmnn#d..",
        "..h##nnmmmmmmnn##d..",
        "..h###nnmmmmnn###d..",
        "..h####nnmmnn####d..",
        "..h#####nnnn#####d..",
        "..h######nn######d..",
        "..h##############d..",
        "...h############d...",
        "....h##########d....",
        ".....h########d.....",
        "......h######d......",
        ".......h####d.......",
        "........dddd........",
        "....................",
        "....................",
    ])


def icon_pressing():  # płomień
    return Grid([
        "....................",
        ".........B..........",
        "........BB..........",
        "........BBB.........",
        ".......BBBB.....B...",
        ".......BBBBB...BB...",
        "......BBBBBB...BB...",
        ".....BBBBBBBB.BBB...",
        "....BBBBBhBBBBBBB...",
        "...BBBBBhhBBBBBBBB..",
        "...BBBBhhhBBBBBBBB..",
        "..BBBBhhhhhBBBBBBB..",
        "..BBBhhhhhhhBBBBBB..",
        "..BBBhhhhhhhhBBBBd..",
        "..BBhhhhhhhhhBBBBd..",
        "..BBBhhhhhhhhBBBd...",
        "...BBhhhhhhhBBBdd...",
        "....BBBhhhhBBddd....",
        ".....dddddddddd.....",
        "....................",
    ])


def icon_reading():  # oko
    return Grid([
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
        ".......BBBBBB.......",
        ".....BBBooooBBB.....",
        "...BBBBooooooBBBB...",
        "..BBBBooooooooBBBB..",
        ".BBBBBohhoooooBBBBB.",
        ".BBBBBohhoooooBBBBd.",
        "..BBBBooooooooBBBd..",
        "...dBBBooooooBBBd...",
        ".....dddoooodddd....",
        ".......dddddd.......",
        "....................",
        "....................",
        "....................",
        "....................",
        "....................",
    ])


ICON_BUILDERS = {
    "strength": icon_strength, "speed": icon_speed, "jump": icon_jump,
    "pass": icon_pass, "shot": icon_shot, "control": icon_control,
    "tackle": icon_tackle, "pressing": icon_pressing, "reading": icon_reading,
}


def render_icon(skill):
    pal = icon_palette(skill)
    grid = ICON_BUILDERS[skill]().finish()
    img = Image.new("RGBA", (ICON_CELL, ICON_CELL), (0, 0, 0, 0))
    for y in range(ICON):
        for x in range(ICON):
            c = grid[y][x]
            if c != ".":
                img.putpixel((x, y), hex_rgba(pal[c]))
    return img


def mask_of(img):
    m = Image.new("RGBA", img.size, (0, 0, 0, 0))
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if img.getpixel((x, y))[3]:
                for dx in range(3):
                    for dy in range(3):
                        if x + dx < w and y + dy < h:
                            m.putpixel((x + dx, y + dy), (255, 255, 255, 255))
    return m


def icon_sheets():
    sheet = Image.new("RGBA", (ICON_CELL * len(ORDER), ICON_CELL), (0, 0, 0, 0))
    masks = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    for i, skill in enumerate(ORDER):
        icon = render_icon(skill)
        sheet.paste(icon, (i * ICON_CELL, 0))
        masks.paste(mask_of(icon), (i * ICON_CELL, 0))
    return sheet, masks


# ───────────────────────── korpusy ─────────────────────────
# Paleta korpusu od najciemniejszego: A kontur, F najciemniejszy (dół/prawo przodu), G przód, C cień krawędzi,
# E ścianka, B faza (jasna krawędź), D blask.
BODY_PAL = {
    "physical": dict(A="#2e1520", F="#6e2622", G="#943a2c", C="#b04a35", E="#c8553d", B="#dc7552", D="#f2a97c"),
    "technical": dict(A="#141c38", F="#223d74", G="#2d5596", C="#3569b0", E="#3d7cc8", B="#5c9ae0", D="#a2cdf4"),
    "defensive": dict(A="#2e2010", F="#70500f", G="#946c14", C="#ae8418", E="#c99a1e", B="#deb73c", D="#f6e08a"),
}
# Zaokrąglenie rogów: wcięcie kolejnych wierszy od krawędzi (symetryczne względem przekątnej).
CORNER = [7, 4, 3, 2, 1, 1, 1]
FACE_CORNER = [4, 2, 1, 1]  # dolne rogi samej ścianki (nad przodem kości)


def rounded(w, h, corner, bottom_corner=None):
    """Maska prostokąta w x h z zaokrąglonymi rogami (bool[h][w]); bottom_corner = inne dolne rogi."""
    m = np.ones((h, w), bool)
    bottom_corner = corner if bottom_corner is None else bottom_corner
    for profile, rows in ((corner, lambda i: i), (bottom_corner, lambda i: h - 1 - i)):
        for i, inset in enumerate(profile):
            for x in range(inset):
                m[rows(i), x] = False
                m[rows(i), w - 1 - x] = False
    return m


def edge_of(mask):
    h, w = mask.shape
    pad = np.pad(mask, 1)
    inner = pad[1:-1, 1:-1] & pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:]
    return mask & ~inner


def runs(mask):
    """Odległość (w pikselach) do krawędzi maski w lewo/prawo/górę/dół, liczona po wierszu/kolumnie."""
    h, w = mask.shape
    left = np.zeros((h, w), int)
    right = np.zeros((h, w), int)
    up = np.zeros((h, w), int)
    down = np.zeros((h, w), int)
    for y in range(h):
        for x in range(w):
            if mask[y, x]:
                left[y, x] = left[y, x - 1] + 1 if x > 0 else 1
                up[y, x] = up[y - 1, x] + 1 if y > 0 else 1
    for y in range(h - 1, -1, -1):
        for x in range(w - 1, -1, -1):
            if mask[y, x]:
                right[y, x] = right[y, x + 1] + 1 if x < w - 1 else 1
                down[y, x] = down[y + 1, x] + 1 if y < h - 1 else 1
    return left, right, up, down


def body_letters(w, h, lip=LIP):
    """Mapa liter palety korpusu w x h (None = przezroczysty)."""
    shape = rounded(w, h, CORNER)
    outline = edge_of(shape)
    inside = shape & ~outline
    lip_top = h - 1 - lip  # pierwszy wiersz przodu kości
    # ścianka: górne rogi wyznacza obrys, dolne rogi przechodzą łukiem w przód kości
    face_mask = np.zeros((h, w), bool)
    face_mask[1:lip_top, 1:w - 1] = rounded(w - 2, lip_top - 1, [], FACE_CORNER)
    face_mask &= inside
    l, r, u, d = runs(inside)
    out = [[None] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if outline[y, x]:
                out[y][x] = "A"
            elif not inside[y, x]:
                continue
            elif y >= lip_top:
                # przód kości
                if y == lip_top:
                    c = "F" if r[y, x] <= 4 else "C"
                elif d[y, x] == 1:
                    c = "F"
                elif l[y, x] <= 3:
                    c = "C"
                elif r[y, x] <= 4:
                    c = "F"
                else:
                    c = "G"
                out[y][x] = c
            elif not face_mask[y, x]:
                out[y][x] = "C" if x < w / 2 else "F"  # dolne zaokrąglenie ścianki
            else:
                lower = y > (lip_top - 1) * 0.8
                if u[y, x] == 1:
                    c = "C" if r[y, x] <= 2 else "B"
                elif l[y, x] == 1:
                    c = "C" if lower else "B"
                elif r[y, x] == 1:
                    c = "F" if y > (lip_top - 1) * 0.9 else "C"
                elif u[y, x] == 2 and 6 <= x <= 12:
                    c = "D"
                elif l[y, x] == 2 and 5 <= y <= 12:
                    c = "D"
                elif l[y, x] + u[y, x] <= 6 and l[y, x] <= 3 and u[y, x] <= 3:
                    c = "D"  # blask w lewym górnym rogu
                elif u[y, x] == 2 or l[y, x] == 2 and not lower:
                    c = "B"
                else:
                    c = "E"
                out[y][x] = c
    return out


def paint(letters, pal):
    h, w = len(letters), len(letters[0])
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            c = letters[y][x]
            if c is not None:
                img.putpixel((x, y), hex_rgba(pal[c]))
    return img


def body_sheet(size=FACE, lip=LIP):
    sheet = Image.new("RGBA", (size * len(TYPES), size), (0, 0, 0, 0))
    letters = body_letters(size, size, lip)
    for i, t in enumerate(TYPES):
        sheet.paste(paint(letters, BODY_PAL[t]), (i * size, 0))
    return sheet


# ───────────────────────── złota obwódka "6" ─────────────────────────
RIM_PAL = dict(A="#ffd75e", B="#fff4c2", C="#5a3a08", D="#a86e14", E="#e6a72a")


def max_rim(size=FACE, lip=LIP):
    w = h = size
    shape = rounded(w, h, CORNER)
    inside = shape & ~edge_of(shape)
    ring1 = edge_of(inside)
    inner = inside & ~ring1
    ring2 = edge_of(inner)
    lip_top = h - 1 - lip
    l, r, u, d = runs(inside)
    out = [[None] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if not inside[y, x]:
                continue
            if y >= lip_top:
                if y == lip_top:
                    c = "D" if l[y, x] <= 4 else "C"
                elif d[y, x] == 1:
                    c = "C"
                elif l[y, x] <= 1:
                    c = "D"
                elif r[y, x] <= 3:
                    c = "C"
                elif y == lip_top + 1:
                    c = "E"
                else:
                    c = "D"
                out[y][x] = c
            elif ring1[y, x]:
                right = r[y, x] <= 2 and u[y, x] > 2
                low_left = l[y, x] <= 2 and y > lip_top - 5
                out[y][x] = "D" if right or low_left else "A"
            elif ring2[y, x]:
                out[y][x] = "C"
    # dolne narożniki ścianki: ciemne przejście w przód kości
    for y in range(lip_top - 3, lip_top):
        for x in range(w):
            if inner[y, x] and (l[y, x] <= 2 + (y - lip_top + 3) or r[y, x] <= 2 + (y - lip_top + 3)):
                out[y][x] = "C"
    # błyski: krzyżyk w prawym górnym rogu, plamka w lewym
    sx, sy = w - 8, 2
    for dx, dy in ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1), (-2, 0), (2, 0)):
        out[sy + dy][sx + dx] = "B"
    out[0][sx] = "A"
    for x, y in ((7, 1), (8, 1), (6, 2), (5, 2)):
        if out[y][x] is not None:
            out[y][x] = "B"
    return paint(out, RIM_PAL)


# ───────────────────────── animacja rzutu ─────────────────────────
SHADOW_COLOR = (10, 25, 10, 80)
ROLL_FRAMES = 6
CUBE_SIDE = 60.0  # bok kostki w pikselach (jak ścianka)
LIGHT_DIR = np.array([-0.5, -0.75, 0.45])
LIGHT_DIR /= np.linalg.norm(LIGHT_DIR)
RAMP = ["F", "G", "C", "E", "B", "D"]


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def render_cube(rot, center, pal_letters_out):
    """Raymarching zaokrąglonego sześcianu (rzut prostokątny) -> mapa liter w klatce ROLL_FRAME."""
    n = ROLL_FRAME
    half = 1.0
    rad = 0.28
    scale = CUBE_SIDE / 2.0  # piksele na jednostkę
    inv = rot.T
    ys, xs = np.mgrid[0:n, 0:n]
    px = (xs + 0.5 - center[0]) / scale
    py = (ys + 0.5 - center[1]) / scale
    # promień od kamery: z rośnie do widza; start z przodu
    origin = np.stack([px, py, np.full_like(px, 4.0)], -1)
    direction = np.array([0.0, 0.0, -1.0])

    def sdf(p):
        q = np.abs(p @ inv.T) - (half - rad)
        outside = np.linalg.norm(np.maximum(q, 0), axis=-1)
        return outside + np.minimum(np.max(q, axis=-1), 0) - rad

    t = np.zeros((n, n))
    hit = np.zeros((n, n), bool)
    for _ in range(80):
        p = origin + t[..., None] * direction
        dist = sdf(p)
        hit |= dist < 1e-3
        t = np.where(hit, t, t + dist)
    p = origin + t[..., None] * direction
    eps = 1e-3
    normal = np.stack([
        sdf(p + [eps, 0, 0]) - sdf(p - [eps, 0, 0]),
        sdf(p + [0, eps, 0]) - sdf(p - [0, eps, 0]),
        sdf(p + [0, 0, eps]) - sdf(p - [0, 0, eps]),
    ], -1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True) + 1e-9
    # oświetlenie: y ekranu rośnie w dół, światło z lewej-góry-przodu
    # góra -> B, przód i lewa -> E, prawa -> G, spód -> F; D tylko na krawędziach zwróconych do światła
    lam = normal @ LIGHT_DIR
    level = np.clip(1.6 + lam * 3.5, 0, len(RAMP) - 1).astype(int)
    # symbol na ściankach: pierścień + kropka (lokalne współrzędne ścianki)
    local = p @ inv.T
    ax = np.argmax(np.abs(local), axis=-1)
    uv = np.where(ax[..., None] == 0, local[..., [1, 2]],
                  np.where(ax[..., None] == 1, local[..., [0, 2]], local[..., [0, 1]]))
    rr = np.linalg.norm(uv, axis=-1)
    on_face = np.max(np.abs(local), axis=-1) > half - 0.02
    symbol = on_face & (((rr > 0.36) & (rr < 0.52)) | (rr < 0.13))
    level = np.where(symbol, np.minimum(level + 1, len(RAMP) - 1), level)
    out = [[None] * n for _ in range(n)]
    for y in range(n):
        for x in range(n):
            if hit[y, x]:
                out[y][x] = RAMP[level[y, x]]
    mask = hit
    edge = edge_of(mask)
    for y in range(n):
        for x in range(n):
            if edge[y, x]:
                out[y][x] = "A"
    pal_letters_out.append(out)
    return out


def roll_frames_letters():
    frames = []
    tilt = rot_x(math.radians(-24)) @ rot_y(math.radians(28))
    for k in range(ROLL_FRAMES):
        a = math.radians(90.0 * k / ROLL_FRAMES)
        rot = tilt @ rot_z(a) @ rot_x(a)
        # lekkie podskakiwanie środka – kostka "wiruje" w powietrzu
        cy = 44 + round(2 * math.sin(k / ROLL_FRAMES * math.tau))
        render_cube(rot, (48, cy), frames)
    # lądowanie 1: kostka prawie płasko, ścianką do widza, przód widoczny od dołu
    render_cube(rot_x(math.radians(28)) @ rot_z(math.radians(9)), (48, 46), frames)
    # lądowanie 2: spłaszczony korpus (odbicie)
    squash = body_letters(66, 52, lip=6)
    frames.append(place(squash, (ROLL_FRAME - 66) // 2, 18 + FACE - 52))
    # lądowanie 3: korpus w miejscu docelowym (DieRollView.FACE_OFFSET)
    frames.append(place(body_letters(FACE, FACE), (ROLL_FRAME - FACE) // 2, (ROLL_FRAME - FACE) // 2))
    return frames


def place(letters, ox, oy):
    out = [[None] * ROLL_FRAME for _ in range(ROLL_FRAME)]
    for y, row in enumerate(letters):
        for x, c in enumerate(row):
            if c is not None:
                out[oy + y][ox + x] = c
    return out


def roll_sheet(type_id, frames):
    sheet = Image.new("RGBA", (ROLL_FRAME * len(frames), ROLL_FRAME), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(paint(f, BODY_PAL[type_id]), (i * ROLL_FRAME, 0))
    return sheet


def shadow():
    img = Image.new("RGBA", (ROLL_FRAME, ROLL_FRAME), (0, 0, 0, 0))
    cx, cy, rx, ry = 48.0, 76.0, 29.0, 5.5
    for y in range(ROLL_FRAME):
        for x in range(ROLL_FRAME):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                img.putpixel((x, y), SHADOW_COLOR)
    return img


def main():
    DICE_DIR.mkdir(parents=True, exist_ok=True)
    icons, masks = icon_sheets()
    icons.save(DICE_DIR / "die_icons.png")
    masks.save(DICE_DIR / "die_icon_masks.png")
    body_sheet().save(DICE_DIR / "die_bodies.png")
    max_rim().save(DICE_DIR / "die_max_rim.png")
    frames = roll_frames_letters()
    for t in TYPES:
        roll_sheet(t, frames).save(DICE_DIR / f"die_roll_{t}.png")
    shadow().save(DICE_DIR / "die_shadow.png")
    print("saved to", DICE_DIR.relative_to(ROOT))


if __name__ == "__main__":
    main()
