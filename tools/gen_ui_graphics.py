"""Generuje pikselowe grafiki UI do assets/graphics (uruchom: python tools/gen_ui_graphics.py).

- ui/frame_1..4.png      : ramki 9-slice (tło + obramowanie) do tooltipów, kart i komunikatów.
                           32x32, rogi 10 px (FRAME_MARGIN), środek jednolity -> dowolny rozmiar bez artefaktów.
                           Ostatni wiersz/kolumna to cień 1 px (prawa i dolna krawędź).
Podświetlenia stref boiska i linię między strefami liczy gra pod rozmiar strefy (scripts/utils/pitch_overlays.gd),
a boisko składa z elementów PitchBuilder (elementy tnie tools/cut_pitch_parts.py).
- players/shirt_*.png           : koszulka zawodnika 36x27 (sylwetka SHIRT_SILHOUETTE): warstwy base, trim, overlay,
                                  shadow, mask, empty (opis warstw przy shirt_layers).
- players/gk_shirt_*.png        : koszulka bramkarza (36x27, warstwy jak shirt_*.png): długi rękaw, rękawice,
                                  łaty na łokciach, pas na piersi. Sylwetka powstaje z sylwetki zwykłej koszulki.
Wersje 720p koszulek (32x25, rysowane w grafiki_brudnopis/shirt.aseprite) są w _backup_720p/assets/graphics/players.
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
UI_DIR = ROOT / "assets" / "graphics" / "ui"
PLAYERS_DIR = ROOT / "assets" / "graphics" / "players"

FRAME_SIZE = 32
FRAME_MARGIN = 10
SHADOW = (6, 10, 8, 150)


def rgba(r, g, b, a=255):
    return (r, g, b, a)


class Canvas:
    def __init__(self, w, h):
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.w, self.h = w, h

    def px(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((x, y), color)

    def rect(self, x0, y0, x1, y1, color):
        """Wypełniony prostokąt, końce włącznie."""
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.px(x, y, color)

    def outline(self, x0, y0, x1, y1, color):
        for x in range(x0, x1 + 1):
            self.px(x, y0, color)
            self.px(x, y1, color)
        for y in range(y0, y1 + 1):
            self.px(x0, y, color)
            self.px(x1, y, color)

    def blend(self, x, y, color):
        """Nakłada kolor z alfą na istniejący piksel."""
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        r, g, b, a = self.img.getpixel((x, y))
        cr, cg, cb, ca = color
        fa = ca / 255.0
        out_a = ca + a * (1 - fa)
        if out_a <= 0:
            return
        mix = lambda c, d: int((c * ca + d * a * (1 - fa)) / out_a)
        self.img.putpixel((x, y), (mix(cr, r), mix(cg, g), mix(cb, b), int(out_a)))

    def mirror_corners(self):
        """Kopiuje lewy górny róg (FRAME_MARGIN) do pozostałych rogów (lustrzanie), w obszarze bez cienia."""
        size = FRAME_SIZE - 1
        m = FRAME_MARGIN
        for y in range(m):
            for x in range(m):
                c = self.img.getpixel((x, y))
                self.px(size - 1 - x, y, c)
                self.px(x, size - 1 - y, c)
                self.px(size - 1 - x, size - 1 - y, c)

    def save(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        self.img.save(path)
        print("saved", path.relative_to(ROOT))


def frame_base(c, outer, border, inner, fill, border_width=1):
    """Obrys + obramowanie + wewnętrzna linia + wypełnienie w obszarze 0..30 (31 = cień)."""
    last = FRAME_SIZE - 2
    c.rect(0, 0, last, last, fill)
    c.outline(0, 0, last, last, outer)
    for i in range(border_width):
        c.outline(1 + i, 1 + i, last - 1 - i, last - 1 - i, border)
    c.outline(1 + border_width, 1 + border_width, last - 1 - border_width, last - 1 - border_width, inner)
    # zaokrąglone rogi: piksele narożne przezroczyste
    for x, y in [(0, 0), (last, 0), (0, last), (last, last)]:
        c.px(x, y, (0, 0, 0, 0))


def add_shadow(c):
    last = FRAME_SIZE - 1
    for i in range(1, last + 1):
        c.px(last, i, SHADOW)
        c.px(i, last, SHADOW)
    c.px(last, last, (0, 0, 0, 0))
    c.px(last, 1, (SHADOW[0], SHADOW[1], SHADOW[2], 70))
    c.px(1, last, (SHADOW[0], SHADOW[1], SHADOW[2], 70))


def frame_pitch():
    """1: zielona ramka w kolorach motywu gry, złote nity w rogach (domyślny tooltip)."""
    c = Canvas(FRAME_SIZE, FRAME_SIZE)
    frame_base(c, rgba(10, 18, 13), rgba(116, 170, 92), rgba(30, 52, 38), rgba(22, 40, 30, 245))
    # nit w lewym górnym rogu (lustrzany do pozostałych)
    gold, gold_dark, gold_light = rgba(232, 211, 106), rgba(150, 122, 48), rgba(255, 244, 190)
    c.rect(3, 3, 5, 5, gold)
    c.px(3, 3, gold_light)
    c.px(5, 5, gold_dark)
    c.px(4, 5, gold_dark)
    c.px(5, 4, gold_dark)
    c.mirror_corners()
    add_shadow(c)
    return c


def frame_gold():
    """2: ciemna ramka z podwójnym złotym obramowaniem i rombami w rogach (wyróżnienie / ważne)."""
    c = Canvas(FRAME_SIZE, FRAME_SIZE)
    frame_base(c, rgba(18, 12, 8), rgba(214, 186, 84), rgba(40, 32, 18), rgba(24, 28, 24, 248), border_width=2)
    last = FRAME_SIZE - 2
    # jasna krawędź u góry/lewej, ciemna u dołu/prawej (relief)
    for i in range(2, last - 1):
        c.px(i, 1, rgba(255, 238, 160))
        c.px(1, i, rgba(255, 238, 160))
        c.px(i, last - 1, rgba(150, 118, 46))
        c.px(last - 1, i, rgba(150, 118, 46))
    # romb w rogu: środek (4,4)
    diamond = rgba(255, 226, 120)
    edge = rgba(120, 88, 30)
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            d = abs(dx) + abs(dy)
            if d <= 3:
                c.px(4 + dx, 4 + dy, edge if d == 3 else diamond)
    c.px(4, 4, rgba(255, 252, 230))
    # tylko lewy górny róg jest wzorem; relief jest asymetryczny, więc romby kopiujemy ręcznie
    corner = [(x, y, c.img.getpixel((x, y))) for y in range(8) for x in range(8)
              if abs(x - 4) + abs(y - 4) <= 3]
    size = FRAME_SIZE - 1
    for x, y, col in corner:
        c.px(size - 1 - x, y, col)
        c.px(x, size - 1 - y, col)
        c.px(size - 1 - x, size - 1 - y, col)
    add_shadow(c)
    return c


def frame_slate():
    """3: tablica taktyczna – grafitowe tło, cienka kredowa linia i grube narożniki (karty zagrań)."""
    c = Canvas(FRAME_SIZE, FRAME_SIZE)
    last = FRAME_SIZE - 2
    chalk, chalk_dim = rgba(222, 228, 214), rgba(150, 160, 150)
    frame_base(c, rgba(12, 14, 16), chalk_dim, rgba(26, 30, 33), rgba(36, 42, 46, 245))
    # narożnik w kształcie L, 2 px grubości, 7 px długości
    for i in range(1, 8):
        c.px(i, 1, chalk)
        c.px(i, 2, chalk)
        c.px(1, i, chalk)
        c.px(2, i, chalk)
    c.px(1, 1, chalk_dim)
    c.mirror_corners()
    # delikatna faktura kredy przy krawędzi (tylko w rogach, środek musi być jednolity)
    for x, y in [(4, 4), (6, 5), (5, 7)]:
        c.px(x, y, rgba(46, 52, 56))
    c.px(last, 0, (0, 0, 0, 0))
    add_shadow(c)
    return c


def frame_paper():
    """4: jasna karta papieru z brązowym obramowaniem i zagiętym rogiem (notatki, opisy – ciemny tekst)."""
    c = Canvas(FRAME_SIZE, FRAME_SIZE)
    last = FRAME_SIZE - 2
    frame_base(c, rgba(58, 36, 20), rgba(140, 98, 58), rgba(250, 244, 222), rgba(236, 224, 192, 255), border_width=2)
    # ciemniejsze narożne kąty, symetryczne
    for i in range(3, 6):
        c.px(i, 3, rgba(214, 196, 156))
        c.px(3, i, rgba(214, 196, 156))
    c.mirror_corners()
    # zagięty prawy górny róg: odcięty trójkąt nad przekątną, pod nią ciemniejsza "klapka"
    fold = 8
    x0 = last - fold + 1
    edge, flap = rgba(58, 36, 20), rgba(204, 184, 142)
    for ly in range(fold):
        for lx in range(fold):
            x = x0 + lx
            if lx > ly:
                c.px(x, ly, (0, 0, 0, 0))
            elif lx == ly or lx == 0 or ly == fold - 1:
                c.px(x, ly, edge)
            else:
                c.px(x, ly, flap)
    add_shadow(c)
    return c


# --- Koszulki ---
# Warstwy: base (barwiony kolorem głównym), trim (kolor dodatkowy), overlay (kontur i cieniowanie, bez barwienia),
# shadow (cień na murawie), mask (sylwetka do obwódki zaznaczenia), empty (pusty slot: przerywany obrys).

GK_OUTLINE = rgba(28, 22, 32)
GK_LIGHT = rgba(255, 255, 255, 80)
GK_DARK = rgba(10, 6, 20, 70)
GK_SHADOW = rgba(10, 25, 10, 70)
SHIRT_DARKER = rgba(10, 6, 20, 120)
SHIRT_NECK = rgba(52, 40, 56)
EMPTY_DASH = rgba(235, 240, 230, 190)
EMPTY_FILL = rgba(0, 0, 0, 80)

# Sylwetka koszulki z konturem (X). Rękawy krótkie, dekolt w szpic.
SHIRT_SILHOUETTE = [
    "...........XXXXXXXXXXXXXX...........",
    ".........XXXXXXXXXXXXXXXXXX.........",
    ".......XXXXXXXXXXXXXXXXXXXXXX.......",
    ".....XXXXXXXXXXXXXXXXXXXXXXXXXX.....",
    "...XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX...",
    ".XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.",
    "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    ".XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.",
    "..XXX.XXXXXXXXXXXXXXXXXXXXXXXX.XXX..",
] + ["......XXXXXXXXXXXXXXXXXXXXXXXX......"] * 14
SHIRT_W, SHIRT_H = len(SHIRT_SILHOUETTE[0]), len(SHIRT_SILHOUETTE)
# Kołnierzyk w szpic (trim) i widoczne wnętrze koszulki nad nim: {wiersz: [(x0, x1), ...]}.
COLLAR = {1: [(11, 13), (22, 24)], 2: [(13, 15), (20, 22)], 3: [(15, 16), (19, 20)], 4: [(16, 19)]}
NECK = {1: [(14, 21)], 2: [(16, 19)], 3: [(17, 18)]}


def _spans(rows):
    return {(x, y) for y, spans in rows.items() for x0, x1 in spans for x in range(x0, x1 + 1)}


def _shirt_silhouette():
    return {(x, y) for y, row in enumerate(SHIRT_SILHOUETTE) for x, c in enumerate(row) if c == "X"}


def _inside_of(pixels):
    return {(x, y) for (x, y) in pixels
            if all((x + dx, y + dy) in pixels for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))}


def shirt_layers():
    pixels = _shirt_silhouette()
    w, h = SHIRT_W, SHIRT_H
    inside = _inside_of(pixels)
    collar, neck = _spans(COLLAR), _spans(NECK)
    base, trim, overlay, shadow, mask, empty = (Canvas(w, h) for _ in range(6))
    white = rgba(255, 255, 255)
    for (x, y) in pixels:
        mask.px(x, y, white)
        shadow.px(x + 1, y + 1, GK_SHADOW)
        if (x, y) not in inside:
            overlay.px(x, y, GK_OUTLINE)
            if (x + y) % 3 != 1:
                empty.px(x, y, EMPTY_DASH)
        else:
            empty.px(x, y, EMPTY_FILL)
    for (x, y) in inside:
        sleeve_end = (y <= 10 and (x <= 2 or x >= w - 3)) or (y == 11 and (x in (2, 3) or x in (w - 4, w - 3)))
        hem = (x, y + 1) not in inside and y > 12
        if (x, y) in collar or sleeve_end or hem:
            trim.px(x, y, white)
        elif (x, y) not in neck:
            base.px(x, y, white)
        # Światło z lewej i na lewym ramieniu, cień z prawej i na prawym ramieniu.
        top_edge = (x, y - 1) not in inside and y <= 5
        if (x, y) in neck:
            overlay.px(x, y, SHIRT_NECK)
        elif (x - 1, y) not in inside or (top_edge and x < w // 2):
            overlay.px(x, y, GK_LIGHT)
        elif (x + 1, y) not in inside or (x + 2, y) not in inside or (top_edge and x >= w // 2):
            overlay.px(x, y, GK_DARK)
    # cień pod kołnierzykiem, zagięcia pach i dół koszulki
    for x, y in [(12, 4), (23, 4)] + [(x, 5) for x in range(13, 23)] + [(5, 10), (w - 6, 10)]:
        overlay.px(x, y, GK_DARK)
    for x, y in [(5, 11), (w - 6, 11)]:
        overlay.px(x, y, GK_OUTLINE)
    for x in list(range(2, 5)) + list(range(w - 5, w - 2)):
        overlay.px(x, 11, GK_DARK)
    for x, y in [(7, 13), (w - 8, 13)]:
        overlay.px(x, y, SHIRT_DARKER)
    for x in range(7, w - 7):
        overlay.px(x, h - 2, GK_DARK)
    return {"base": base, "trim": trim, "overlay": overlay, "shadow": shadow, "mask": mask, "empty": empty}


def _gk_silhouette():
    """Zbiór pikseli sylwetki: zwykła koszulka + długie rękawy z rękawicami."""
    w, h = SHIRT_W, SHIRT_H
    pixels = _shirt_silhouette()
    for y in range(11, 24):
        for x in list(range(0, 5)) + list(range(w - 5, w)):
            pixels.add((x, y))
    return pixels, w, h


def gk_shirt_layers():
    pixels, w, h = _gk_silhouette()
    inside = _inside_of(pixels)
    base, trim, overlay, shadow, mask = (Canvas(w, h) for _ in range(5))
    white = rgba(255, 255, 255)
    for (x, y) in pixels:
        mask.px(x, y, white)
        shadow.px(x + 1, y + 1, GK_SHADOW)
        if (x, y) not in inside:
            overlay.px(x, y, GK_OUTLINE)
    for (x, y) in inside:
        base.px(x, y, white)
        sleeve = x <= 4 or x >= w - 5
        glove = sleeve and y >= 19
        elbow = sleeve and y in (14, 15)
        collar = y <= 2 and 13 <= x <= 22
        chest = not sleeve and y in (9, 10)
        hem = not sleeve and (x, y + 1) not in inside
        if glove or elbow or collar or chest or hem:
            trim.px(x, y, white)
        # Światło z lewej, cień z prawej (jak w zwykłej koszulce).
        if (x - 1, y) not in inside:
            overlay.px(x, y, GK_LIGHT)
        elif (x + 1, y) not in inside or (x + 2, y) not in inside:
            overlay.px(x, y, GK_DARK)
    for x in range(6, w - 6):
        if (x, h - 2) in inside:
            overlay.px(x, h - 2, GK_DARK)
    return {"base": base, "trim": trim, "overlay": overlay, "shadow": shadow, "mask": mask}


def main():
    for index, builder in enumerate([frame_pitch, frame_gold, frame_slate, frame_paper], start=1):
        builder().save(UI_DIR / f"frame_{index}.png")
    for layer, canvas in shirt_layers().items():
        canvas.save(PLAYERS_DIR / f"shirt_{layer}.png")
    for layer, canvas in gk_shirt_layers().items():
        canvas.save(PLAYERS_DIR / f"gk_shirt_{layer}.png")


if __name__ == "__main__":
    main()
