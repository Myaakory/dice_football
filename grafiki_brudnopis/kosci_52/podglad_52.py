"""Podgląd kości 52x52 z obecnymi ikonkami 20 px (uruchom: python grafiki_brudnopis/kosci_52/podglad_52.py).

Zapisuje tu: die_bodies_52.png, die_max_rim_52.png, podglad_52_x1.png (rozmiar jak w grze na 1080p)
i podglad_52_x3.png (powiększenie). Układ ikonek odwzorowuje DieGraphics.draw_mixed_face.
"""
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent / "tools"))
import gen_dice_graphics as g  # noqa: E402

SIZE = 52
LIP = 6
BG = (36, 69, 47, 255)  # tło ekranu meczu
TEXT_BG = (24, 46, 31, 255)
ICON_SHADOW = (20, 10, 20, 120)  # DieGraphics.ICON_SHADOW
FACE_COLORS = {t: g.hex_rgba(g.BODY_PAL[t]["E"]) for t in g.TYPES}

CENTER_5 = (16, 12)
LAYOUTS_52 = {
    1: [(16, 12)],
    2: [(5, 3), (27, 22)],
    3: [(5, 3), (27, 3), (16, 22)],
    4: [(5, 2), (27, 2), (5, 22), (27, 22)],
    5: [(3, 2), (29, 2), (3, 23), (29, 23), CENTER_5],
}
LAYOUT_5_PAIRED_52 = [(3, 2), (29, 2), CENTER_5, (3, 23), (29, 23)]
SIX_52 = (6, 3)

# obecne 60x60 (DieGraphics) – do porównania
LAYOUTS_60 = {
    1: [(20, 16)],
    2: [(6, 5), (34, 27)],
    3: [(7, 5), (33, 5), (20, 25)],
    4: [(8, 5), (32, 5), (8, 27), (32, 27)],
    5: [(5, 3), (35, 3), (5, 29), (35, 29), (20, 16)],
}
LAYOUT_5_PAIRED_60 = [(5, 3), (35, 3), (20, 16), (5, 29), (35, 29)]
SIX_60 = (10, 6)


def tint(img, rgba):
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    src, dst = img.load(), out.load()
    for y in range(img.height):
        for x in range(img.width):
            if src[x, y][3]:
                dst[x, y] = (rgba[0], rgba[1], rgba[2], src[x, y][3] * rgba[3] // 255)
    return out


class Dice:
    def __init__(self, size, lip, layouts, paired, six):
        self.size, self.layouts, self.paired, self.six = size, layouts, paired, six
        self.bodies = g.body_sheet(size, lip)
        self.rim = g.max_rim(size, lip)
        self.icons, self.masks = g.icon_sheets()

    def face(self, type_id, groups):
        s = self.size
        ti = g.TYPES.index(type_id)
        img = self.bodies.crop((ti * s, 0, ti * s + s, s))
        total = sum(c for _, c in groups)
        if len(groups) == 1 and total >= 6:
            img.alpha_composite(self.rim)
            idx = g.ORDER.index(groups[0][0])
            icon = self.icons.crop((idx * 22, 0, idx * 22 + 20, 20)).resize((40, 40), Image.NEAREST)
            img.alpha_composite(tint(icon, ICON_SHADOW), (self.six[0] + 2, self.six[1] + 2))
            img.alpha_composite(icon, self.six)
            return img
        total = min(total, 5)
        ordered = sorted(groups, key=lambda grp: -grp[1])
        positions = self.layouts[total]
        if total == 5 and all(c != 1 for _, c in ordered):
            positions = self.paired
        placed = []
        for skill, count in ordered:
            for _ in range(count):
                if len(placed) < total:
                    placed.append([g.ORDER.index(skill), positions[len(placed)]])
        center = [p for p in placed if p[1] == CENTER_5 or (self.size == 60 and p[1] == (20, 16) and total == 5)]
        if total == 5 and center:
            placed.remove(center[0])
            placed.append(center[0])
        for idx, pos in placed:
            mask = self.masks.crop((idx * 22, 0, idx * 22 + 22, 22))
            icon = self.icons.crop((idx * 22, 0, idx * 22 + 20, 20))
            if len(placed) > 1:
                img.alpha_composite(tint(mask, FACE_COLORS[type_id]), (pos[0] - 1, pos[1] - 1))
            img.alpha_composite(tint(mask, ICON_SHADOW), pos)
            img.alpha_composite(icon, pos)
        return img


def grid(dice, rows, gap=6):
    """rows = [[(type_id, groups), ...], ...] -> obraz 1:1."""
    s = dice.size
    cols = max(len(r) for r in rows)
    img = Image.new("RGBA", (gap + cols * (s + gap), gap + len(rows) * (s + gap)), BG)
    for r, row in enumerate(rows):
        for c, (type_id, groups) in enumerate(row):
            img.alpha_composite(dice.face(type_id, groups), (gap + c * (s + gap), gap + r * (s + gap)))
    return img


def type_of(skill):
    return g.TYPES[g.ORDER.index(skill) // 3]


def main():
    d52 = Dice(SIZE, LIP, LAYOUTS_52, LAYOUT_5_PAIRED_52, SIX_52)
    d60 = Dice(g.FACE, g.LIP, LAYOUTS_60, LAYOUT_5_PAIRED_60, SIX_60)
    d52.bodies.save(HERE / "die_bodies_52.png")
    d52.rim.save(HERE / "die_max_rim_52.png")

    # A: każda cecha z wartością 1..6 (tak wyglądają ścianki w grze)
    single = [[(type_of(s), [(s, v)]) for v in range(1, 7)] for s in g.ORDER]
    # B: ścianki mieszane jednej kategorii (DieGraphics obsługuje je, dane jeszcze ich nie używają)
    mixed = []
    for t_i, t in enumerate(g.TYPES):
        a, b, c = g.ORDER[t_i * 3:t_i * 3 + 3]
        mixed.append([(t, grp) for grp in (
            [(a, 1), (b, 1)], [(a, 2), (b, 1)], [(a, 1), (b, 1), (c, 1)], [(a, 2), (c, 2)],
            [(a, 3), (b, 1)], [(b, 2), (c, 1), (a, 1)], [(a, 3), (c, 2)], [(b, 4), (a, 1)],
            [(a, 2), (b, 2), (c, 1)], [(c, 3), (a, 1), (b, 1)])])
    # C: porównanie 60 vs 52 (te same ścianki)
    compare = [(t, grp) for t, grp in (("physical", [("strength", 3)]), ("technical", [("control", 4)]),
                                       ("defensive", [("reading", 5)]), ("technical", [("shot", 2)]),
                                       ("defensive", [("tackle", 3), ("pressing", 2)]),
                                       ("physical", [("speed", 6)]))]

    a = grid(d52, single)
    b = grid(d52, mixed)
    c60 = grid(d60, [compare])
    c52 = grid(d52, [compare])
    width = max(a.width, b.width, c60.width) + 12
    sheet = Image.new("RGBA", (width, a.height + b.height + c60.height + c52.height + 4 * 10), TEXT_BG)
    y = 0
    for part in (a, b, c60, c52):
        y += 10
        sheet.alpha_composite(part, (6, y))
        y += part.height
    sheet.save(HERE / "podglad_52_x1.png")
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(HERE / "podglad_52_x3.png")
    print("zapisano w", HERE)


if __name__ == "__main__":
    main()
