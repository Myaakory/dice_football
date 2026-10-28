"""System kolorystyczny: w każdej kości jedna ikonka jasna, jedna ciemna i jedna w kolorze sygnaturowym kości.
Przemalowuje obecne ikonki z gry (wariant 0) i propozycje A–D (warianty 1–4)."""
import sys
from PIL import Image

sys.path.insert(0, ".")
import icons_gen as ig

import os

# Kopia pierwotnego arkusza z gry (przed przejściem na system jasności) – źródło wariantu 0.
ORIGINAL_SHEET = os.path.join(os.path.dirname(os.path.abspath(__file__)), "die_icons_oryginal_v1.png")

LIGHT = dict(b="#f3ece0", h="#ffffff", d="#b9ab98", w="#ffffff", W="#d9cfbf")
DARK = dict(b="#3a2c3e", h="#7a6682", d="#2a1f2e", w="#8a7690", W="#6c5873")
SIG = {  # dopełnienie koloru korpusu = charakter kości
    "physical": dict(b="#7ee08c", h="#c6f7cb", d="#3a9e55"),
    "technical": dict(b="#ffa64a", h="#ffd7a6", d="#c96a22"),
    "defensive": dict(b="#a97cff", h="#d9c6ff", d="#6f47c4"),
}
TYPE_OF = {s: ("physical" if i < 3 else "technical" if i < 6 else "defensive") for i, s in enumerate(ig.ORDER)}
ROLE = {
    "strength": "light", "speed": "sig", "jump": "dark",
    "pass": "light", "shot": "sig", "control": "dark",
    "tackle": "dark", "pressing": "sig", "reading": "light",
}
# (cecha, wariant): wyjątki palety; wariant 0 = obecna ikonka z gry, 1..4 = propozycje A..D
OVERRIDES = {
    ("strength", 3): dict(x="#ffffff"),
    ("jump", 1): dict(k="#e05a4a"),
    ("control", 2): dict(k="#6c5873"),
    ("control", 4): dict(k="#6c5873"),
    ("tackle", 1): dict(n="#d6cbd8", N="#9d8ea2", m="#6c5873"),
    ("tackle", 2): dict(n="#d6cbd8", N="#9d8ea2"),
    ("tackle", 3): dict(n="#d6cbd8", N="#9d8ea2", w="#d6cbd8"),
    ("pressing", 3): dict(g="#d9c6ff", y="#6f47c4"),
    ("reading", 1): dict(g="#ddd3c3", x="#b9ab98"),
    ("reading", 2): dict(x="#b9ab98", k="#b9ab98"),
    ("reading", 3): dict(k="#f3ece0", w="#3a2c3e"),
}
# Mapowanie kolorów obecnego arkusza na litery legendy
CURRENT_MAP = [
    {"ffce9c": "B", "ffe8d2": "h", "e28850": "d"},
    {"ffe254": "B", "fff1b2": "h", "d2a022": "d"},
    {"ffb2cc": "B", "ffdce8": "h", "d66e96": "d"},
    {"84f2c6": "B", "c7f9e5": "h", "42ba8c": "d"},
    {"f8f1dc": "B", "e2fab8": "y", "c0f462": "x", "c4b8a0": "d"},
    {"cdf4ff": "h", "92e8ff": "B", "40a4ce": "d"},
    {"cc9eff": "B", "865acc": "d", "e8d3ff": "h"},
    {"ff8888": "B", "ffc9c9": "h", "c84656": "d"},
    {"a6bcff": "B", "d6e0ff": "h", "6072d6": "d"},
]


def role_palette(skill):
    role = ROLE[skill]
    if role == "light":
        pal = dict(LIGHT)
    elif role == "dark":
        pal = dict(DARK)
    else:
        s = SIG[TYPE_OF[skill]]
        pal = dict(s, w=s["h"], W=s["b"])
    pal.setdefault("x", pal["d"])
    pal.setdefault("y", pal["h"])
    return pal


def current_grid(index):
    sheet = Image.open(ORIGINAL_SHEET).convert("RGBA")
    g = ig.G()
    for y in range(ig.N):
        for x in range(ig.N):
            p = sheet.getpixel((index * ig.CELL + x, y))
            if p[3] == 0:
                continue
            hx = "%02x%02x%02x" % p[:3]
            g.p[y][x] = "o" if hx == "241a26" else CURRENT_MAP[index][hx]
    return g


def paint(grid, pal):
    img = Image.new("RGBA", (ig.CELL, ig.CELL), (0, 0, 0, 0))
    for y in range(ig.N):
        for x in range(ig.N):
            c = grid[y][x]
            if c != ".":
                img.putpixel((x, y), ig.to_rgba(pal[c]))
    return img


def render(skill, variant):
    pal = dict(ig.COMMON)
    pal.update(role_palette(skill))
    if variant == 0:
        grid = current_grid(ig.ORDER.index(skill)).finish()
    elif variant - 1 >= len(ig.ICONS[skill]):
        return Image.new("RGBA", (ig.CELL, ig.CELL), (0, 0, 0, 0))
    else:
        _, fn, extra = ig.ICONS[skill][variant - 1]
        pal.update({k: v for k, v in extra.items() if k not in ("w", "W")})
        grid = fn().finish()
    pal.update(OVERRIDES.get((skill, variant), {}))
    return paint(grid, pal)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "out"
    for v in range(5):
        sheet = Image.new("RGBA", (ig.CELL * 9, ig.CELL), (0, 0, 0, 0))
        masks = Image.new("RGBA", (ig.CELL * 9, ig.CELL), (0, 0, 0, 0))
        for i, s in enumerate(ig.ORDER):
            ic = render(s, v)
            sheet.paste(ic, (i * ig.CELL, 0))
            masks.paste(ig.mask_of(ic), (i * ig.CELL, 0))
        sheet.save(f"{out}/sys_icons_{v}.png")
        masks.save(f"{out}/sys_masks_{v}.png")
    prev = Image.new("RGBA", (5 * 18 * 6 + 6, 9 * 18 * 6), (40, 46, 40, 255))
    for i, s in enumerate(ig.ORDER):
        for v in range(5):
            ic = render(s, v).resize((96, 96), Image.NEAREST)
            prev.alpha_composite(ic, (6 + v * 108, i * 108 + 6))
    prev.save(f"{out}/sys_preview_x6.png")
    print("ok")
