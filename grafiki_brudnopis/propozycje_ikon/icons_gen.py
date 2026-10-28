"""Generator propozycji ikonek cech (14x14 w komórce 16x16, styl jak assets/graphics/dice/die_icons.png).

Legenda siatek:
  .  puste            o  kontur (wnętrze)        #  baza (dolna krawędź auto-cień -> d)
  h  jasny            d  cień                    B  baza bez auto-cienia
  w  biały/kremowy (dolna krawędź auto -> W)     W  cień bieli
  g, x, y, k, n  dodatkowe kolory z palety ikonki
Kontur zewnętrzny dodawany automatycznie (4-sąsiedztwo), maska = sylwetka przesunięta o (0..2, 0..2).
"""
import math
import sys
from PIL import Image

N = 14
CELL = 16
OUTLINE = "#241a26"

SKILL_PAL = {
    "strength": dict(b="#ffce9c", h="#ffe8d2", d="#e28850"),
    "speed": dict(b="#ffe254", h="#fff1b2", d="#d2a022"),
    "jump": dict(b="#ffb2cc", h="#ffdce8", d="#d66e96"),
    "pass": dict(b="#84f2c6", h="#c7f9e5", d="#42ba8c"),
    "shot": dict(b="#f8f1dc", h="#ffffff", d="#c4b8a0", x="#c0f462", y="#e2fab8"),
    "control": dict(b="#92e8ff", h="#cdf4ff", d="#40a4ce"),
    "tackle": dict(b="#cc9eff", h="#e8d3ff", d="#865acc"),
    "pressing": dict(b="#ff8888", h="#ffc9c9", d="#c84656"),
    "reading": dict(b="#a6bcff", h="#d6e0ff", d="#6072d6"),
}
COMMON = dict(o=OUTLINE, w="#fbf6e9", W="#c9bea6")


class G:
    def __init__(self, rows=None):
        self.p = [["."] * N for _ in range(N)]
        if rows:
            self.rows(rows)

    def rows(self, rows, ox=0, oy=0):
        for y, r in enumerate(rows):
            if len(r) != N and ox == 0:
                raise ValueError(f"row {y} len {len(r)}: {r!r}")
            for x, c in enumerate(r):
                if c != " " and c != "." or ox == 0:
                    if 0 <= x + ox < N and 0 <= y + oy < N and c != " ":
                        if c != "." or ox == 0:
                            self.p[y + oy][x + ox] = c
        return self

    def set(self, x, y, c):
        if 0 <= x < N and 0 <= y < N:
            self.p[y][x] = c

    def get(self, x, y):
        return self.p[y][x] if 0 <= x < N and 0 <= y < N else "."

    def disc(self, cx, cy, r, c, only=None):
        for y in range(N):
            for x in range(N):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                    if only is None or self.p[y][x] in only:
                        self.p[y][x] = c

    def line(self, x0, y0, x1, y1, c, w=1.0):
        steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 4) + 1
        for i in range(steps + 1):
            t = i / steps
            px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            rr = w / 2
            for y in range(N):
                for x in range(N):
                    if abs(x + 0.5 - px) <= rr and abs(y + 0.5 - py) <= rr:
                        self.p[y][x] = c

    def poly(self, pts, c):
        for y in range(N):
            for x in range(N):
                if _inside(x + 0.5, y + 0.5, pts):
                    self.p[y][x] = c

    def filled(self, x, y):
        return self.get(x, y) not in (".", "o")

    def finish(self):
        out = [r[:] for r in self.p]
        for y in range(N):
            for x in range(N):
                c = self.p[y][x]
                below_empty = not self.filled(x, y + 1)
                if c == "#":
                    out[y][x] = "d" if below_empty else "b"
                elif c == "B":
                    out[y][x] = "b"
                elif c == "w" and below_empty:
                    out[y][x] = "W"
                elif c == "." and any(self.filled(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    out[y][x] = "o"
        return out


def _inside(x, y, pts):
    ins = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            ins = not ins
        j = i
    return ins


ICONS = {}  # skill -> list of (name_pl, builder, extra_palette)


def icon(skill, name, **pal):
    def deco(fn):
        ICONS.setdefault(skill, []).append((name, fn, pal))
        return fn
    return deco


# ───────────────────────── SIŁA ─────────────────────────
@icon("strength", "Hantel")
def _():
    return G([
        "..............",
        "..............",
        "..............",
        ".h##......h##.",
        ".h##......h##.",
        ".h##......h##.",
        ".h##hhhhhhh##.",
        ".h##ddddddh##.",
        ".h##......h##.",
        ".h##......h##.",
        ".###......###.",
        "..............",
        "..............",
        "..............",
    ])


@icon("strength", "Pięść")
def _():
    return G([
        "..............",
        "..............",
        "..hh.hh.hh....",
        "..h#.h#.h#.hh.",
        "..##o##o##o#d.",
        "..##o##o##o#d.",
        ".ooooooo##o#d.",
        ".hhhhhhh#d##d.",
        ".#######d###d.",
        ".oooooooo###d.",
        "..h########d..",
        "...h######d...",
        "..............",
        "..............",
    ])


@icon("strength", "Rogi byka", x="#ffe8d2")
def _():
    return G([
        "..............",
        ".x..........x.",
        ".xx........xx.",
        ".xx........xx.",
        "..xx......xx..",
        "..hh######dd..",
        "..##########..",
        "...#o####o#...",
        "...########...",
        "...hhhhhhhh...",
        "...ho####od...",
        "....######....",
        "..............",
        "..............",
    ])


@icon("strength", "Odważnik")
def _():
    return G([
        "..............",
        "....hhhhhh....",
        "...h######d...",
        "...h#....#d...",
        "...h#....#d...",
        "..h########d..",
        ".hh#########d.",
        ".h##########d.",
        ".h##########d.",
        ".h##########d.",
        "..h########d..",
        "...########...",
        "..............",
        "..............",
    ])


# ───────────────────────── SZYBKOŚĆ ─────────────────────────
@icon("speed", "Przewijanie")
def _():
    return G([
        "..............",
        "..............",
        "..h.....h.....",
        "..hh....hh....",
        "..h##...h##...",
        "..h###..h###..",
        "..h####.h####.",
        "..h###d.h###d.",
        "..h##d..h##d..",
        "..h#d...h#d...",
        "..hd....hd....",
        "..d.....d.....",
        "..............",
        "..............",
    ])


@icon("speed", "Stoper")
def _():
    return G([
        "..............",
        ".....hhhh.....",
        "......##......",
        "....hhhhhh....",
        "...h#wwww#d...",
        "..hwwwwwwwwd..",
        "..hwwwwwwowd..",
        "..hwwwwwowwd..",
        "..hwwwoowwwd..",
        "..hwwwwwwwwd..",
        "..hwwwwwwwwd..",
        "...h#wwww#d...",
        "....######....",
        "..............",
    ])


@icon("speed", "Skrzydlaty but")
def _():
    return G([
        "..............",
        "..............",
        ".ww...........",
        ".www.hhhh.....",
        "..ww.h###.....",
        ".www.h###o#...",
        "..ww.h####o##.",
        ".....h#####o#.",
        ".....h######d.",
        "....wwwwwwwww.",
        "....wwwwwwwww.",
        "..............",
        "..............",
        "..............",
    ])


@icon("speed", "Prędkościomierz", x="#ff6b5a")
def _():
    return G([
        "..............",
        "..............",
        "..............",
        "....hhhhhh....",
        "...hwwwwwxd...",
        "..hwwwwwwoxd..",
        ".hwwwwwwowwxd.",
        ".hwwwwwowwwwd.",
        ".hwwwwoowwwwd.",
        ".h##########d.",
        "..............",
        "..............",
        "..............",
        "..............",
    ])


# ───────────────────────── SKOCZNOŚĆ ─────────────────────────
@icon("jump", "Rakieta", x="#9fe4ff", y="#ffcc4d", k="#d66e96")
def _():
    return G([
        "..............",
        "......hh......",
        ".....h##d.....",
        ".....h##d.....",
        "....h#xx#d....",
        "....h#xx#d....",
        "....h####d....",
        "....h####d....",
        "...kh####dk...",
        "..kkh####dkk..",
        "..kk.####.kk..",
        ".....yyyy.....",
        "......yy......",
        "..............",
    ])


@icon("jump", "Trampolina", w="#fbf6e9")
def _():
    return G([
        "..............",
        "......ww......",
        ".....wwww.....",
        "....wwoowW....",
        "....wwoowW....",
        ".....WWWW.....",
        "...h......h...",
        "...h......h...",
        ".hhhhhhhhhhhh.",
        ".############.",
        "..#........#..",
        "..#........#..",
        ".##........##.",
        "..............",
    ])


@icon("jump", "Podwójny szewron")
def _():
    ch = [
        "......hh......",
        ".....h##d.....",
        "....h#..#d....",
        "...h#....#d...",
        "..h#......#d..",
    ]
    return G(["............."[:0] + ".............."] + ch + [".............."] + ch + ["..............", ".............."])


@icon("jump", "Płotek", x="#fbf6e9", y="#ff6b5a")
def _():
    return G([
        "..............",
        "..............",
        ".....hhhh.....",
        "...hh....##...",
        "..h........#..",
        ".h........###.",
        ".h.........#..",
        "..............",
        "..............",
        "...xxyyxxyy...",
        "...#......#...",
        "...#......#...",
        "..##......##..",
        "..............",
    ])


# ───────────────────────── PODANIE ─────────────────────────
@icon("pass", "Klepka (podaj-oddaj)")
def _():
    return G([
        "..............",
        "........h.....",
        "........hh....",
        ".hhhhhhhh##...",
        ".#########d...",
        "........#d....",
        "........d.....",
        ".....h........",
        "....hh........",
        "...hhhhhhhhhh.",
        "...##########.",
        "....##........",
        ".....#........",
        "..............",
    ])


@icon("pass", "Samolocik")
def _():
    return G([
        "..............",
        "...........h#.",
        ".........hh#d.",
        ".......hhh#dd.",
        ".....hhhh#ddd.",
        "...hhhhh#ddd..",
        ".hhhhhh#dddd..",
        "......#ddd....",
        "......#dd.....",
        "......#d......",
        "......#.......",
        "..............",
        "..............",
        "..............",
    ])


@icon("pass", "Lob po łuku", w="#fbf6e9")
def _():
    return G([
        "..............",
        "..............",
        "......hh......",
        "...hh....hh...",
        "..............",
        "..h........#..",
        "..h........#..",
        "..............",
        "...ww....####.",
        "..wwww....##..",
        ".wwoowW.......",
        ".wwoowW.......",
        "..WWWW........",
        "..............",
    ])


@icon("pass", "Zakręcona strzałka")
def _():
    return G([
        "..............",
        "..............",
        ".....hhhh.....",
        "...hh####d....",
        "..h##....##...",
        ".h##.....##...",
        ".h#.....hhhhh.",
        ".h#......###..",
        ".##.......#...",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
    ])


# ───────────────────────── STRZAŁ ─────────────────────────
@icon("shot", "Celownik")
def _():
    return G([
        "..............",
        "......##......",
        ".....####.....",
        "...hh....##...",
        "..h........#..",
        "..h...xx...#..",
        ".hh..xxxx..##.",
        ".hh..xxxx..##.",
        "..h...xx...#..",
        "..h........#..",
        "...hh....##...",
        ".....####.....",
        "......##......",
        "..............",
    ])


@icon("shot", "Bramka z piłką")
def _():
    g = G([
        "..............",
        "..............",
        ".hhhhhhhhhhhh.",
        ".h..........d.",
        ".h..........d.",
        ".h..........d.",
        ".h..........d.",
        ".h..........d.",
        ".h..........d.",
        ".h..........d.",
        ".h..........d.",
        ".d..........d.",
        "..............",
        "..............",
    ])
    g.rows([
        "     ww     ",
        "    wwww    ",
        "   wwoowW   ",
        "   wwoowW   ",
        "    WWWW    ",
    ], ox=1, oy=6)
    return g


@icon("shot", "Kometa")
def _():
    g = G()
    g.line(7.0, 7.0, 1.6, 12.4, "x", 2.2)
    g.line(6.2, 7.8, 2.6, 11.4, "y", 1.0)
    g.line(5.4, 4.4, 1.6, 8.2, "x", 1.0)
    g.line(9.6, 8.6, 5.8, 12.4, "x", 1.0)
    g.disc(9.3, 4.7, 3.6, "w")
    g.set(9, 4, "o"); g.set(10, 4, "o"); g.set(9, 5, "o"); g.set(10, 5, "o")
    g.set(7, 3, "h"); g.set(8, 2, "h")
    return g


@icon("shot", "Uderzenie")
def _():
    g = G()
    pts = []
    for i in range(16):
        a = -math.pi / 2 + i * math.pi / 8
        r = 6.4 if i % 2 == 0 else 3.6
        pts.append((7 + r * math.cos(a), 7 + r * math.sin(a)))
    g.poly(pts, "x")
    g.disc(7, 7, 3.0, "w")
    g.set(6, 6, "o"); g.set(7, 6, "o"); g.set(6, 7, "o"); g.set(7, 7, "o")
    # przesunięcie o -0.5 px (środek komórki 6.5)
    g.p = [r[1:] + ["."] for r in g.p]
    g.p = g.p[1:] + [["."] * N]
    return g


# ───────────────────────── PROWADZENIE ─────────────────────────
@icon("control", "Piłka na orbicie")
def _():
    g = G()
    ring = []
    for i in range(240):
        t = 2 * math.pi * i / 240
        x, y = 6.0 * math.cos(t), 2.4 * math.sin(t)
        a = -0.35
        ring.append((7 + x * math.cos(a) - y * math.sin(a), 7.3 + x * math.sin(a) + y * math.cos(a), math.sin(t)))
    for x, y, s in ring:
        if s < 0:
            g.set(int(x), int(y), "#")
    g.disc(7, 7, 3.6, "w")
    for x, y, s in ring:
        if s >= 0:
            g.set(int(x), int(y), "h")
    g.set(6, 6, "o"); g.set(7, 6, "o"); g.set(6, 7, "o"); g.set(7, 7, "o")
    g.p = [r[1:] + ["."] for r in g.p]
    return g


@icon("control", "Podeszwa na piłce", w="#fbf6e9", k="#2a6f94")
def _():
    return G([
        "..............",
        "..hhh.........",
        "..h##.........",
        "..h##o........",
        "..h###o#hh....",
        "..h########d..",
        "..kkkkkkkkkk..",
        "..............",
        "......ww......",
        ".....wwww.....",
        "....wwoowW....",
        "....wwoowW....",
        ".....WWWW.....",
        "..............",
    ])


@icon("control", "Żonglerka", w="#fbf6e9")
def _():
    return G([
        ".....ww.......",
        "....wwww......",
        "...wwoowW.....",
        "...wwoowW.....",
        "....WWWW......",
        "..............",
        "..hhhh........",
        "..h###........",
        "..h###o.......",
        "..h####o#hh...",
        "..h#########d.",
        "..h#########d.",
        "..wwwwwwwwwww.",
        "..............",
    ])


@icon("control", "Joystick", w="#fbf6e9", x="#ff6b5a", y="#ffb3a8", k="#40a4ce")
def _():
    return G([
        "..............",
        "......xx......",
        ".....yxxx.....",
        ".....xxxx.....",
        "......xx......",
        "......kk......",
        "......kk......",
        "......kk......",
        "....hhhhhh.ww.",
        ".h##########d.",
        ".h##########d.",
        "..##########..",
        "..............",
        "..............",
    ])


# ───────────────────────── ODBIÓR ─────────────────────────
# Rola "ciemna": bryły ciemne, ale z jasnym detalem (n/N), żeby nie wyglądały jak czarna plama.
@icon("tackle", "Tarcza (herb)", n="#f3ecff", N="#b9a6d9", m="#e8d3ff")
def _():
    return G([
        "..............",
        "..hhhhhhhhhh..",
        "..hmmmmmmmmd..",
        "..nnmmmmmmnn..",
        "..hnnmmmmnnd..",
        "..h#nnmmnn#d..",
        "..h##nnnn##d..",
        "..h###nn###d..",
        "..h########d..",
        "...h######d...",
        "....h####d....",
        ".....h##d.....",
        "......dd......",
        "..............",
    ])


@icon("tackle", "Szlaban", n="#f3ecff", N="#b9a6d9", x="#ff6b5a")
def _():
    return G([
        "..............",
        "..xx..........",
        "..h#..........",
        "..h#nnn###nnn.",
        "..h#nnn###nnn.",
        "..h#NNN###NNN.",
        "..h#..........",
        "..h#..........",
        "..h#..........",
        "..h#..........",
        "..h#..........",
        ".h###d........",
        ".#####........",
        "..............",
    ])


@icon("tackle", "Nożyczki (przecięte podanie)", n="#f3ecff", N="#b9a6d9")
def _():
    g = G()
    g.line(6.2, 6.6, 12.6, 1.6, "n", 1.5)
    g.line(6.2, 6.4, 12.6, 11.4, "N", 1.5)
    g.line(6.4, 6.5, 3.6, 3.8, "#", 1.4)
    g.line(6.4, 6.5, 3.6, 9.2, "#", 1.4)
    g.disc(3.0, 3.2, 2.5, "#")
    g.disc(3.0, 9.8, 2.5, "#")
    g.disc(3.0, 3.2, 1.0, "o")
    g.disc(3.0, 9.8, 1.0, "o")
    g.set(2, 2, "h"); g.set(2, 8, "h")
    g.set(6, 6, "w")
    return g


# ───────────────────────── PRESSING ─────────────────────────
@icon("pressing", "Osaczenie")
def _():
    return G([
        "..............",
        "...hh....hh...",
        "...hh....hh...",
        ".hhhh....hhhh.",
        ".####....####.",
        "......ww......",
        ".....wwww.....",
        ".....wwww.....",
        "......ww......",
        ".hhhh....hhhh.",
        ".####....####.",
        "...##....##...",
        "...##....##...",
        "..............",
    ])


@icon("pressing", "Szczęki")
def _():
    return G([
        "..............",
        "..............",
        "..hhhhhhhhhh..",
        ".h##########d.",
        ".hwwwwwwwwwwd.",
        ".hwowowowowod.",
        ".hooooooooood.",
        ".howowowowowd.",
        ".hwwwwwwwwwwd.",
        ".h##########d.",
        "..##########..",
        "..............",
        "..............",
        "..............",
    ])


@icon("pressing", "Klepsydra", g="#fff3f3", y="#ffd25a")
def _():
    return G([
        "..............",
        "..hhhhhhhhhh..",
        "..dddddddddd..",
        "...gyyyyyyg...",
        "....gyyyyg....",
        ".....gyyg.....",
        "......yy......",
        ".....gyyg.....",
        "....ggyygg....",
        "...ggyyyygg...",
        "...yyyyyyyy...",
        "..hhhhhhhhhh..",
        "..dddddddddd..",
        "..............",
    ])


@icon("pressing", "Ślady pazurów")
def _():
    g = G()
    for i in range(3):
        x0 = 5.8 + 3.6 * i
        g.line(x0, 1.2, x0 - 4.4, 12.4, "#", 1.0)
        g.line(x0 - 1.0, 3.8, x0 - 3.2, 9.6, "#", 2.0)
        g.line(x0 - 0.6, 3.0, x0 - 2.0, 6.8, "h", 1.0)
    return g


# ───────────────────────── CZYTANIE GRY ─────────────────────────
@icon("reading", "Lupa", g="#e9efff", x="#6072d6")
def _():
    g = G()
    g.line(8.6, 8.6, 12.0, 12.0, "x", 2.2)
    g.disc(5.8, 5.8, 4.9, "#")
    g.disc(5.8, 5.8, 4.9, "h", only="#")
    g.disc(6.1, 6.1, 4.6, "#")
    g.disc(5.8, 5.8, 3.2, "g")
    g.set(4, 4, "w"); g.set(4, 5, "w"); g.set(5, 4, "w")
    return g


@icon("reading", "Kryształowa kula", x="#c99aff", k="#6072d6")
def _():
    g = G()
    g.disc(7, 6.2, 5.0, "#")
    g.disc(6.6, 5.8, 4.2, "B")
    g.disc(6.0, 5.2, 2.6, "h")
    g.set(4, 3, "w"); g.set(5, 3, "w"); g.set(4, 4, "w")
    g.set(7, 6, "x"); g.set(8, 7, "x"); g.set(8, 5, "x")
    g.p = [r[1:] + ["."] for r in g.p]
    g.rows([
        "...kkkkkk...",
        "..kkkkkkkk..",
    ], ox=1, oy=11)
    return g


@icon("reading", "Tablica taktyczna", k="#2f4a3a")
def _():
    return G([
        "..............",
        "..............",
        ".hhhhhhhhhhhh.",
        ".hkkkkkkkkkkd.",
        ".hkwwwkwkwkkd.",
        ".hkwkwkkkkwkd.",
        ".hkwwwkkkwwwd.",
        ".hkkkkkkkkwkd.",
        ".hkkkkkkkkkkd.",
        ".hkkkkkwkwkkd.",
        ".hkkkkkkwkkkd.",
        ".hkkkkkwkwkkd.",
        ".############.",
        "..............",
    ])


@icon("reading", "Skoczek szachowy")
def _():
    return G([
        "..............",
        ".......h.h....",
        "......h###d...",
        ".....h#####d..",
        "....h##o####d.",
        "..hh########d.",
        ".h##########d.",
        ".hddd..#####..",
        "......h####d..",
        ".....h#####d..",
        "...hhhhhhhhh..",
        "...#########..",
        "..###########.",
        "..............",
    ])


ORDER = ["strength", "speed", "jump", "pass", "shot", "control", "tackle", "pressing", "reading"]


def to_rgba(hexs):
    hexs = hexs.lstrip("#")
    return tuple(int(hexs[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def render(skill, idx):
    if idx >= len(ICONS[skill]):
        return Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    name, fn, extra = ICONS[skill][idx]
    grid = fn().finish()
    pal = dict(COMMON)
    pal.update(SKILL_PAL[skill])
    pal.update(extra)
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    for y in range(N):
        for x in range(N):
            c = grid[y][x]
            if c == ".":
                continue
            if c not in pal:
                raise KeyError(f"{skill}/{name}: color '{c}'")
            img.putpixel((x, y), to_rgba(pal[c]))
    return img


def mask_of(img):
    m = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    for y in range(CELL):
        for x in range(CELL):
            if img.getpixel((x, y))[3]:
                for dx in range(3):
                    for dy in range(3):
                        if x + dx < CELL and y + dy < CELL:
                            m.putpixel((x + dx, y + dy), (255, 255, 255, 255))
    return m


if __name__ == "__main__":
    out = sys.argv[1]
    import os
    os.makedirs(out, exist_ok=True)
    for v in range(4):
        sheet = Image.new("RGBA", (CELL * 9, CELL), (0, 0, 0, 0))
        masks = Image.new("RGBA", (CELL * 9, CELL), (0, 0, 0, 0))
        for i, s in enumerate(ORDER):
            ic = render(s, v)
            sheet.paste(ic, (i * CELL, 0))
            masks.paste(mask_of(ic), (i * CELL, 0))
        letter = "abcd"[v]
        sheet.save(f"{out}/die_icons_{letter}.png")
        masks.save(f"{out}/die_icon_masks_{letter}.png")
    # podgląd x8 z siatką
    prev = Image.new("RGBA", (CELL * 4 * 8 + 3 * 16, CELL * 9 * 8 + 8 * 8), (40, 46, 40, 255))
    for i, s in enumerate(ORDER):
        for v in range(4):
            ic = render(s, v).resize((CELL * 8, CELL * 8), Image.NEAREST)
            prev.alpha_composite(ic, (v * (CELL * 8 + 16), i * (CELL * 8 + 8)))
    prev.save(f"{out}/preview_x8.png")
    print("ok")
