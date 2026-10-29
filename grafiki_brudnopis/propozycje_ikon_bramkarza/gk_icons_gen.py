"""Propozycje kości bramkarza: grafitowy korpus 52x52 i 3 ikonki umiejętności × 3 warianty (20x20 w komórce 22x22).

Styl i palety jak w tools/gen_dice_graphics.py (system jasności: jedna ikonka jasna, jedna ciemna, jedna w kolorze
sygnaturowym kości). Uruchom: python grafiki_brudnopis/propozycje_ikon_bramkarza/gk_icons_gen.py
Wynik w tym katalogu: gk_icons_<a|b|c>.png (+ maski), gk_body.png, podglad_*.png.
"""

import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent / "tools"))
import gen_dice_graphics as g  # noqa: E402

# ───────────────────────── korpus: grafit (ołówek) ─────────────────────────
# Średni grafit z lekkim chłodnym (niebieskawym) połyskiem; E = kolor ścianki.
GK_BODY = dict(A="#191a1f", F="#34373d", G="#43464e", C="#50545c", E="#5e626b", B="#757a84", D="#a8adb6")
g.BODY_PAL["goalkeeper"] = GK_BODY
FACE_COLOR = GK_BODY["E"]

# Kolor sygnaturowy ikonek bramkarza: turkus (nie ma go na innych kościach, dobrze odcina się od grafitu).
GK_SIG = dict(b="#4fd2c6", h="#b9f6ee", d="#24958f")
# Akcent (mankiet rękawicy, siatka bramki itp.).
ACCENT = dict(k=GK_SIG["b"], K=GK_SIG["d"])

def palette(role, extra=None):
    if role == "light":
        pal = dict(g.LIGHT)
    elif role == "dark":
        pal = dict(g.DARK)
    else:
        pal = dict(GK_SIG, w=GK_SIG["h"], W=GK_SIG["b"])
    pal.setdefault("x", pal["d"])
    pal.setdefault("y", pal["h"])
    pal["o"] = g.OUTLINE
    pal.update(ACCENT)
    pal.update(extra or {})
    return pal


def compose(base, *layers):
    """Nakłada kształty (wiersze, x, y) na siatkę; wokół kształtu na już wypełnionych pikselach dodaje kontur 'o'."""
    grid = g.Grid(base) if base else g.Grid()
    for rows, ox, oy in layers:
        cells = {(ox + x, oy + y): c for y, row in enumerate(rows) for x, c in enumerate(row) if c != "."}
        for (x, y) in cells:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n not in cells and 0 <= n[0] < g.ICON and 0 <= n[1] < g.ICON and grid.p[n[1]][n[0]] != ".":
                    grid.p[n[1]][n[0]] = "o"
        for (x, y), c in cells.items():
            if 0 <= x < g.ICON and 0 <= y < g.ICON:
                grid.p[y][x] = c
    return grid


# Piłka 11x11 jak w ikonce strzału (B/h/d wypełnienie, o łaty).
BALL = [
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
# Biała piłka 7x7 (n/N = biel z palety jasnej) – akcent na ikonkach niebiałych.
BALL_SMALL = [
    "..nnn..",
    ".nnoonN",
    "nnoooN.",
    "nnnoNNN",
    "nNnnNNN",
    ".NNNNN.",
    "..NNN..",
]
WHITE = dict(n=g.LIGHT["b"], N=g.LIGHT["d"])


def recolor(rows, mapping):
    return ["".join(mapping.get(c, c) for c in row) for row in rows]


# Rękawica 14x17 (palce do góry, kciuk z lewej, mankiet k/K).
GLOVE = [
    ".......hh.hh..",
    "....hh.hB.hB..",
    "....hB.hB.hB.hh",
    "....hB.hB.hB.hB",
    "....hB.hB.hB.hB",
    "....hB.hB.hB.hB",
    "hh..hB.hB.hB.hB",
    "hBd.hBBBBBBBBBd",
    "hBBdhBBBBBBBBBd",
    ".hBBBBBBBBBBBBd",
    "..hBBBBBBBBBBBd",
    "...hBBBBBBBBBBd",
    "....BBBBBBBBBBd",
    "....dddddddddd.",
    "....kkkkkkkkkk.",
    "....kkkkkkkkkk.",
    "....KKKKKKKKKK.",
]
GLOVE = [row.ljust(15, ".") for row in GLOVE]


def mirror(rows):
    """Odbicie lustrzane w poziomie; h <-> d, żeby światło dalej padało z lewej (T = jasny wierzch, bez zamiany)."""
    swap = {"h": "d", "d": "h"}
    return ["".join(swap.get(c, c) for c in reversed(row)) for row in rows]


def symmetric(half_rows):
    """Wiersze 10-znakowe lewej połowy -> pełna siatka 20x20 (prawa połowa = mirror)."""
    rows = [h + m for h, m in zip(half_rows, mirror(half_rows))]
    return rows + ["." * g.ICON] * (g.ICON - len(rows))


# Symetryczne piłki do kompozycji: a = jasna strona, b = cień, o = łaty.
BALLS = {
    8: [
        "..aaaa..",
        ".aaaaab.",
        "aaaoobbb",
        "aaoooobb",
        "aaaoobbb",
        "oaaaabbo",
        ".bbbbbb.",
        "..bbbb..",
    ],
    10: [
        "...aaaa...",
        ".aaaaaaab.",
        ".aaaoobbb.",
        "oaaoooobbo",
        "oaaoooobbo",
        "aaaaoobbbb",
        "aaaaabbbbb",
        ".aoaabbob.",
        ".bbbbbbbb.",
        "...bbbb...",
    ],
}


def ball(size, light="n", dark="N"):
    return recolor(BALLS[size], {"a": light, "b": dark})


# ───────────────────────── chwytanie (jasna) ─────────────────────────

def catching_a():  # chwyt „W”: dwie rękawice za piłką, kciuki się stykają
    half = [
        "..........",
        ".....TT...",
        "..TT.hB.TT",
        "..hB.hB.hB",
        "..hB.hB.hB",
        "..hB.hB.hB",
        "..hB.hB.hB",
        ".ThBBBBBBB",
        ".hBBBBBBBB",
        ".hBBBBBBBB",
        "..hBBBBBBB",
        "..hBBBBBBB",
        "...BBBBBBB",
        "...kkkkkkk",
        "...KKKKKKK",
    ]
    return compose(symmetric(half), (ball(10, "w", "W"), 5, 8))


def catching_b():  # piłka trzymana w dwóch rękawicach
    left = [
        "hh....",
        "hBd...",
        "hBBd..",
        "hBBBd.",
        "hBBBBd",
        "hBBBBd",
        "hBBBBd",
        ".BBBBd",
        ".ddddd",
        ".kkkkk",
        ".KKKKK",
    ]
    right = [
        "....hd",
        "...hBd",
        "..hBBd",
        ".hBBBd",
        "hBBBBd",
        "hBBBBd",
        "hBBBBd",
        "hBBBB.",
        "ddddd.",
        "kkkkk.",
        "KKKKK.",
    ]
    return compose(None, (BALL, 4, 1), (left, 1, 6), (right, 13, 6))


def catching_c():  # piłka złapana w rękawicę
    ball_rows = recolor(BALL, {"B": "w", "h": "w", "d": "W"})
    return compose(None, (GLOVE, 0, 1), (ball_rows, 8, 7))


# ───────────────────────── piąstkowanie (sygnaturowa) ─────────────────────────
# Pięść w rękawicy jak ikonka siły: palce u góry, kciuk w poprzek wystaje w lewo, biały mankiet (n).
# T = jasny wierzch, x = cień od spodu (nie zamieniają się przy odbiciu lustrzanym).
FIST = [
    "..TT.TT.TT...",
    "..hB.hB.hB.TT",
    "..hB.hB.hB.hB",
    "..BB.BB.hB.hB",
    "..xx.xx.BB.Bd",
    "TTTTTTTTBd.Bd",
    "hBBBBBBBBd.Bd",
    "xxxxxxxBBd.Bd",
    "..hBBBBBBBBBd",
    "...hBBBBBBBd.",
    "....xxxxxxx..",
    "....nnnnnnn..",
]
# Lewa pięść z pary (kciuk od strony środka) – prawa to jej odbicie; 10 kolumn = lewa połowa ikonki.
FIST_HALF = [
    ".TT.TT.TT.",
    ".hB.hB.hB.",
    ".hB.hB.hB.",
    ".hB.xx.xx.",
    ".hBTTTTTT.",
    ".hBBBBBBd.",
    ".hBxxxxxx.",
    ".hBBBBBd..",
    "..xxxxxx..",
    "..nnnnnn..",
]


def punching_a():  # pięść wybija piłkę (iskry uderzenia)
    sparks = [(["y"], 9, 5), (["y"], 8, 4), (["y"], 7, 7), (["y"], 6, 7)]
    return compose(None, (FIST, 1, 7), *sparks, (ball(8), 11, 1))


def punching_b():  # dwie pięści razem wybijają piłkę w górę
    lines = ["." * 10] * 3 + [".....y...."] * 2 + ["." * 10] * 4
    rows = symmetric(lines + FIST_HALF + ["." * 10])
    return compose(rows, (ball(8), 6, 1))


def punching_c():  # piąstkowanie nad poprzeczkę
    bar = ["n" * 18, "N" * 18]
    up = [(["y"], 4, 2), (["y"], 4, 3), (["y"], 15, 2), (["y"], 15, 3)]
    return compose(None, (bar, 1, 6), (FIST, 3, 7), *up, (ball(8), 6, 1))


# ───────────────────────── ustawianie na linii (ciemna) ─────────────────────────
# Bramka (poprzeczka, słupki, linia bramkowa) + symetryczna sylwetka bramkarza (k/K, rękawice n).

def goal_with(figure, line="x"):
    """Bramka: poprzeczka w wierszach 2-3, słupki do wiersza 14 stojące na linii bramkowej (15).
    Sylwetka wyrównana do dołu – stopy na linii, nad głową odstęp od poprzeczki."""
    rows = [
        "....................",
        "....................",
        ".hhhhhhhhhhhhhhhhhh.",
        ".hBBBBBBBBBBBBBBBBd.",
    ]
    inside = ["." * 14] * (11 - len(figure)) + figure
    for f in inside:
        rows.append(".hd" + f + "hd.")
    rows.append("." + line * 18 + ".")
    return g.Grid(rows + ["." * 20] * (20 - len(rows)))


def positioning_a():  # postawa gotowości: ręce w dół i na boki
    return goal_with([
        "......kk......",
        "......kk......",
        "....kkkkkk....",
        "...k..kk..k...",
        "..n...kk...n..",
        "......kk......",
        ".....k..k.....",
        "....k....k....",
        "....K....K....",
    ])


def positioning_b():  # ręce w górze (gwiazda)
    return goal_with([
        "..n...kk...n..",
        "...k..kk..k...",
        "....k....k....",
        ".....kkkk.....",
        "......kk......",
        "......kk......",
        ".....k..k.....",
        "....k....k....",
        "...K......K...",
    ])


def positioning_c():  # ręce gotowe do chwytu (łokcie zgięte), na turkusowej linii bramkowej
    return goal_with([
        "..n........n..",
        "..k...kk...k..",
        "..k...kk...k..",
        "..kkkkkkkkkk..",
        "......kk......",
        "......kk......",
        ".....k..k.....",
        "....k....k....",
        "....K....K....",
    ], line="k")


SKILLS = ["catching", "punching", "positioning"]  # chwytanie (jasna), piąstkowanie (sygnaturowa), ustawianie (ciemna)
ROLE = {"catching": "light", "punching": "sig", "positioning": "dark"}
BUILDERS = {
    "catching": [catching_a, catching_b, catching_c],
    "punching": [punching_a, punching_b, punching_c],
    "positioning": [positioning_a, positioning_b, positioning_c],
}


def render(builder, role):
    pal = palette(role, WHITE)
    pal["T"] = pal["h"]
    grid = builder().finish()
    img = Image.new("RGBA", (g.ICON_CELL, g.ICON_CELL), (0, 0, 0, 0))
    for y in range(g.ICON):
        for x in range(g.ICON):
            c = grid[y][x]
            if c != ".":
                img.putpixel((x, y), g.hex_rgba(pal[c]))
    return img


# ───────────────────────── podgląd ścianek (jak DieGraphics) ─────────────────────────
SHADOW = (20, 10, 20, 120)
LAYOUTS = {
    1: [(16, 12)],
    2: [(5, 3), (27, 22)],
    3: [(5, 3), (27, 3), (16, 22)],
    4: [(5, 2), (27, 2), (5, 22), (27, 22)],
    5: [(3, 2), (29, 2), (3, 23), (29, 23), (16, 12)],
}
LAYOUT_5_PAIRED = [(3, 2), (29, 2), (16, 12), (3, 23), (29, 23)]


def tinted(img, rgba):
    out = Image.new("RGBA", img.size, rgba[:3] + (0,))
    a = img.getchannel("A").point(lambda v: v * rgba[3] // 255)
    out.putalpha(a)
    return out


def face(type_id, groups):
    """groups = [(ikonka, maska, liczba), ...] – jak DieGraphics.draw_mixed_face."""
    body = g.paint(g.body_letters(g.FACE, g.FACE), g.BODY_PAL[type_id])
    img = body.copy()
    total = sum(n for _, _, n in groups)
    if len(groups) == 1 and total >= 6:
        img.alpha_composite(g.max_rim())
        icon = groups[0][0].crop((0, 0, g.ICON, g.ICON)).resize((g.ICON * 2, g.ICON * 2), Image.NEAREST)
        img.alpha_composite(tinted(icon, SHADOW), (6 + 2, 3 + 2))
        img.alpha_composite(icon, (6, 3))
        return img
    total = min(total, 5)
    groups = sorted(groups, key=lambda grp: -grp[2])
    positions = LAYOUTS[total]
    if total == 5 and all(n != 1 for _, _, n in groups):
        positions = LAYOUT_5_PAIRED
    placed = []
    for icon, mask, n in groups:
        for _ in range(n):
            if len(placed) < total:
                placed.append((icon, mask, positions[len(placed)]))
    for i, p in enumerate(placed):
        if p[2] == (16, 12) and total == 5:
            placed.append(placed.pop(i))
            break
    face_rgba = g.hex_rgba(FACE_COLOR if type_id == "goalkeeper" else g.BODY_PAL[type_id]["E"])
    for icon, mask, (x, y) in placed:
        if len(placed) > 1:
            img.alpha_composite(tinted(mask, face_rgba), (x - 1, y - 1))
        img.alpha_composite(tinted(mask, SHADOW), (x, y))
        img.alpha_composite(icon.crop((0, 0, g.ICON, g.ICON)), (x, y))
    return img


_GK_BODY = None


def gk_body():
    global _GK_BODY
    if _GK_BODY is None:
        _GK_BODY = g.paint(g.body_letters(g.FACE, g.FACE), GK_BODY)
    return _GK_BODY


def label(img, text, xy, color=(230, 230, 230, 255)):
    from PIL import ImageDraw
    ImageDraw.Draw(img).text(xy, text, fill=color)


def main():
    icons = {s: [render(b, ROLE[s]) for b in BUILDERS[s]] for s in SKILLS}
    masks = {s: [g.mask_of(i) for i in icons[s]] for s in SKILLS}
    for v, letter in enumerate("abc"):
        sheet = Image.new("RGBA", (g.ICON_CELL * 3, g.ICON_CELL), (0, 0, 0, 0))
        msheet = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
        for i, s in enumerate(SKILLS):
            sheet.paste(icons[s][v], (i * g.ICON_CELL, 0))
            msheet.paste(masks[s][v], (i * g.ICON_CELL, 0))
        sheet.save(HERE / f"gk_icons_{letter}.png")
        msheet.save(HERE / f"gk_icon_masks_{letter}.png")
    gk_body().save(HERE / "gk_body.png")

    bg = (34, 46, 36, 255)  # ciemna zieleń jak tło stołu
    gap = 6
    fw = g.FACE + gap

    # 1) kolor kości na tle pozostałych
    bodies = Image.new("RGBA", (fw * 4 + gap, g.FACE + 2 * gap), bg)
    for i, t in enumerate(g.TYPES):
        bodies.alpha_composite(g.paint(g.body_letters(g.FACE, g.FACE), g.BODY_PAL[t]), (gap + i * fw, gap))
    bodies.alpha_composite(gk_body(), (gap + 3 * fw, gap))
    bodies.save(HERE / "podglad_kolor_kosci.png")

    # 2) każda ikonka × wariant: ścianki 1, 3, 5 i 6
    counts = [1, 3, 5, 6]
    block = fw * len(counts) + 3 * gap
    sheet = Image.new("RGBA", (gap + block * 3, gap + (g.FACE + gap) * 3 + 14), bg)
    for v, letter in enumerate("ABC"):
        label(sheet, f"wariant {letter}", (gap + v * block, 2))
    for r, s in enumerate(SKILLS):
        for v in range(3):
            for c, n in enumerate(counts):
                f = face("goalkeeper", [(icons[s][v], masks[s][v], n)])
                sheet.alpha_composite(f, (gap + v * block + c * fw, 14 + r * (g.FACE + gap)))
    sheet.save(HERE / "podglad_warianty.png")

    # 3) całe zestawy A/B/C: ścianki mieszane + porównanie z kośćmi z pola
    mixes = [[(0, 2), (1, 1)], [(1, 2), (2, 2)], [(0, 2), (1, 2), (2, 1)], [(2, 3), (0, 2)], [(1, 6)]]
    sets = Image.new("RGBA", (gap + fw * len(mixes), 14 + (g.FACE + gap) * 4), bg)
    for v, letter in enumerate("ABC"):
        for c, mix in enumerate(mixes):
            groups = [(icons[SKILLS[i]][v], masks[SKILLS[i]][v], n) for i, n in mix]
            sets.alpha_composite(face("goalkeeper", groups), (gap + c * fw, 14 + v * (g.FACE + gap)))
    field_icons, field_masks = g.icon_sheets()
    cell = lambda im, i: im.crop((i * g.ICON_CELL, 0, (i + 1) * g.ICON_CELL, g.ICON_CELL))
    for c, (t, mix) in enumerate([("physical", [(0, 2), (1, 1)]), ("technical", [(3, 2), (5, 2)]),
                                  ("defensive", [(6, 2), (7, 2), (8, 1)]), ("defensive", [(8, 3), (6, 2)]),
                                  ("technical", [(4, 6)])]):
        groups = [(cell(field_icons, i), cell(field_masks, i), n) for i, n in mix]
        sets.alpha_composite(face(t, groups), (gap + c * fw, 14 + 3 * (g.FACE + gap)))
    label(sets, "zestawy A / B / C + kosci z pola", (gap, 2))
    sets.save(HERE / "podglad_zestawy.png")

    # 4) same ikonki na grafitowym kafelku, x8
    tiles = Image.new("RGBA", (gap + (g.ICON_CELL + 2) * 3, gap + (g.ICON_CELL + 2) * 3), bg)
    for r, s in enumerate(SKILLS):
        for v in range(3):
            t = Image.new("RGBA", (g.ICON_CELL, g.ICON_CELL), g.hex_rgba(FACE_COLOR))
            t.alpha_composite(tinted(masks[s][v], SHADOW))
            t.alpha_composite(icons[s][v].crop((0, 0, g.ICON, g.ICON)))
            tiles.alpha_composite(t, (gap + v * (g.ICON_CELL + 2), gap + r * (g.ICON_CELL + 2)))
    tiles.resize((tiles.width * 8, tiles.height * 8), Image.NEAREST).save(HERE / "podglad_ikonki_x8.png")

    for name in ("podglad_warianty", "podglad_zestawy", "podglad_kolor_kosci"):
        im = Image.open(HERE / f"{name}.png")
        im.resize((im.width * 3, im.height * 3), Image.NEAREST).save(HERE / f"{name}_x3.png")
    print("saved to", HERE)


if __name__ == "__main__":
    main()
