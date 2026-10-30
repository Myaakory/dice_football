"""Rdzeń generatora portretów: kolory i rampy, style, warstwy jako mapy ról, kontur, składanie.

Warstwa (część portretu) to słownik {(x, y): rola}. Rola to nazwa koloru w palecie, np. "skin.shade",
"hair.base", "fix.outline". Kolor podstawia się dopiero przy składaniu (resolve_palette), więc ta sama część
pasuje do każdego koloru skóry / włosów / koszulki. Szablony eksportowane do gry mają kolory palety domyślnej
(palettes.json → default); gra podmienia je na kolory zawodnika tak samo jak resolve_palette.
"""

import colorsys
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
SIZES = (32, 64)


# ───────────────────────── kolory ─────────────────────────

def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgb_to_hex(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(v))) for v in c)


def mix(a, b, t):
    ca, cb = hex_to_rgb(a), hex_to_rgb(b)
    return rgb_to_hex([ca[i] + (cb[i] - ca[i]) * t for i in range(3)])


def shift(hex_color, dl=0.0, dh=0.0, ds=0.0):
    """Jaśniej/ciemniej w HSV: przyciemnianie mnoży jasność (ciemne kolory zmieniają się mniej),
    rozjaśnianie zbliża do bieli (mniej nasycenia). dh przesuwa odcień (cienie w stronę czerwieni,
    światła w stronę żółci), ds zmienia nasycenie."""
    r, g, b = [v / 255 for v in hex_to_rgb(hex_color)]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if dl < 0:
        v = v * (1 + dl * 2.0)
    else:
        v = v + (1 - v) * dl * 1.6
        s = s * (1 - dl * 1.1)
    h = (h + dh) % 1.0
    v = min(1.0, max(0.03, v))
    s = min(1.0, max(0.0, s + ds))
    return rgb_to_hex([c * 255 for c in colorsys.hsv_to_rgb(h, s, v)])


# Odcienie rampy: (zmiana jasności, przesunięcie odcienia, zmiana nasycenia); styl skaluje je swoim kontrastem.
RAMPS = {
    "skin": {"hi": (0.30, 0.012, 0.0), "light": (0.14, 0.006, 0.0), "base": (0, 0, 0),
             "shade": (-0.08, -0.012, 0.04), "deep": (-0.16, -0.022, 0.06)},
    "hair": {"hi": (0.13, 0.012, -0.02), "base": (0, 0, 0), "shade": (-0.11, -0.012, 0.02),
             "deep": (-0.20, -0.02, 0.02)},
    "eye": {"iris": (0, 0, 0), "dark": (-0.17, 0, 0.02)},
    "shirt": {"light": (0.20, 0.01, -0.05), "base": (0, 0, 0), "shade": (-0.10, -0.015, 0.03),
              "deep": (-0.19, -0.025, 0.03)},
    "trim": {"base": (0, 0, 0), "shade": (-0.10, -0.01, 0.0)},
    "acc": {"hi": (0.45, 0.01, -0.1), "base": (0, 0, 0), "shade": (-0.14, -0.015, 0.02)},
}


def make_ramp(group, entry, style):
    if isinstance(entry, dict):
        base, overrides = entry["base"], entry
    else:
        base, overrides = entry, {}
    base = shift(base, ds=style["saturation"])
    ramp = {}
    for name, (dl, dh, ds) in RAMPS[group].items():
        ramp[name] = overrides.get(name) or shift(base, dl * style["contrast"], dh * style["hue_shift"], ds)
    return ramp


# ───────────────────────── style ─────────────────────────
# outline: black = ciemny kontur, selout = kontur w najciemniejszym odcieniu sąsiedniej plamy koloru.
# shading: band = pas cienia po stronie przeciwnej do światła, soft = więcej odcieni + blask, cel = twardy cień.
# collapse: role, których styl nie używa (mniej odcieni), wskazują na inną rolę.

STYLES = {
    "retro": {
        "label": "A · klasyczny 16-bit",
        "about": "czarny kontur, 3 odcienie, białka oczu",
        "contrast": 1.0, "hue_shift": 1.0, "saturation": 0.0,
        "outline": {"mode": "black", "color": "#1e1519", "width": {32: 1, 64: 1, 128: 2}, "diagonal": False},
        "shading": "band",
        "head_grow": 0.0,
        "lid": "fix.outline",
        "collapse": {"skin.hi": "skin.light", "hair.hi": "hair.base", "acc.hi": "acc.base"},
    },
    "soft": {
        "label": "B · miękki, kontur kolorowy",
        "about": "kontur w ciemniejszym odcieniu, 5 odcieni, blask",
        "contrast": 0.9, "hue_shift": 1.8, "saturation": -0.02,
        "outline": {"mode": "selout", "width": {32: 1, 64: 1, 128: 1}, "diagonal": False},
        "shading": "soft",
        "head_grow": -0.15,
        "lid": "skin.deep",
        "collapse": {},
    },
    "bold": {
        "label": "C · graficzny, płaski",
        "about": "gruby kontur, 2 odcienie, twardy cień",
        "contrast": 1.35, "hue_shift": 0.6, "saturation": 0.08,
        "outline": {"mode": "black", "color": "#140e12", "width": {32: 1, 64: 2, 128: 3}, "diagonal": True},
        "shading": "cel",
        "head_grow": 0.35,
        "lid": "fix.outline",
        "collapse": {"skin.hi": "skin.base", "skin.light": "skin.base", "skin.deep": "skin.shade",
                     "hair.hi": "hair.base", "hair.deep": "hair.shade", "shirt.light": "shirt.base",
                     "shirt.deep": "shirt.shade", "acc.hi": "acc.base",
                     "mix.stubble_shade": "mix.stubble", "mix.buzz_shade": "mix.buzz"},
    },
}

FIXED = {"fix.white": "#f3efe6", "fix.pupil": "#151015", "fix.teeth": "#ebe4d6"}


# ───────────────────────── palety ─────────────────────────

def load_json(name):
    with open(HERE / name, encoding="utf-8") as f:
        return json.load(f)


def resolve_palette(style_id, palettes, skin, hair, eyes, accessory, shirt, trim):
    """Pełna paleta ról dla jednego zawodnika: {rola: '#rrggbb'}.
    skin/hair/eyes/accessory = klucze pul z palettes.json, shirt/trim = kolory drużyny (hex)."""
    style = STYLES[style_id]
    pal = {}
    for group, entry in (("skin", palettes["skin"][skin]), ("hair", palettes["hair"][hair]),
                         ("eye", palettes["eyes"][eyes]), ("acc", palettes["accessory"][accessory]),
                         ("shirt", shirt), ("trim", trim)):
        for name, color in make_ramp(group, entry, style).items():
            pal[f"{group}.{name}"] = color
    # Role pochodne (zależą od dwóch palet naraz) – gra liczy je tak samo.
    pal["skin.lip"] = mix(pal["skin.shade"], "#c4524c", 0.30)
    pal["skin.lip_dark"] = mix(pal["skin.deep"], "#7e2b28", 0.32)
    pal["mix.stubble"] = mix(pal["skin.base"], pal["hair.deep"], 0.24)
    pal["mix.stubble_shade"] = mix(pal["skin.shade"], pal["hair.deep"], 0.32)
    pal["mix.stubble_heavy"] = mix(pal["skin.base"], pal["hair.deep"], 0.42)
    pal["mix.stubble_heavy_shade"] = mix(pal["skin.shade"], pal["hair.deep"], 0.52)
    pal["mix.beard"] = mix(pal["skin.shade"], pal["hair.base"], 0.72)
    pal["mix.beard_shade"] = mix(pal["skin.deep"], pal["hair.deep"], 0.8)
    pal["mix.buzz"] = mix(pal["skin.base"], pal["hair.base"], 0.62)
    pal["mix.buzz_shade"] = mix(pal["skin.shade"], pal["hair.shade"], 0.68)
    pal["mix.freckle"] = mix(pal["skin.base"], "#a5532e", 0.30)
    pal.update(FIXED)
    if style["outline"]["mode"] == "black":
        pal["fix.outline"] = style["outline"]["color"]
    else:
        pal["fix.outline"] = mix(pal["skin.deep"], "#1e1519", 0.55)
    for role, target in style["collapse"].items():
        pal[role] = pal[target]
    return pal


def default_palette(style_id, palettes):
    d = palettes["default"]
    return resolve_palette(style_id, palettes, d["skin"], d["hair"], d["eyes"], d["accessory"], d["shirt"], d["trim"])


# ───────────────────────── geometria i maski ─────────────────────────

class Ctx:
    """Kontekst rysowania jednej części: rozmiar n (32/64), styl i geometria głowy.
    Kształty opisuje się w przestrzeni 32×32 (u, v); dla 64 px ten sam kształt próbkuje się gęściej."""

    def __init__(self, n, style_id, head):
        self.n = n
        self.s = n / 32
        self.style_id = style_id
        self.style = STYLES[style_id]
        self.head = head

    def px(self, length):
        """Długość z przestrzeni 32 px w pikselach tego rozmiaru (min. 1)."""
        return max(1, round(length * self.s))

    def uv(self, p):
        return (p[0] + 0.5) / self.s, (p[1] + 0.5) / self.s

    def region(self, fn):
        s = self.s
        return {(x, y) for y in range(self.n) for x in range(self.n) if fn((x + 0.5) / s, (y + 0.5) / s)}

    def mirror(self, p):
        return (self.n - 1 - p[0], p[1])


def rim(mask, dx, dy):
    """Piksele maski, które po przesunięciu o (dx, dy) wypadają poza maskę (brzeg od tej strony)."""
    return {p for p in mask if (p[0] + dx, p[1] + dy) not in mask}


def dilate(mask, r=1, diagonal=False):
    out = set(mask)
    for _ in range(r):
        grown = set(out)
        for x, y in out:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                grown.add((x + dx, y + dy))
            if diagonal:
                for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
                    grown.add((x + dx, y + dy))
        out = grown
    return out


def paint(layer, pixels, role):
    for p in pixels:
        layer[p] = role


def stamp(ctx, layer, grid, x0, y0, letters, both=False):
    """Wkleja siatkę znaków (wiersze tekstu) od piksela (x0, y0); letters: znak -> rola (None = pomiń).
    both = także lustrzane odbicie względem pionowej osi portretu (oczy, brwi)."""
    for dy, row in enumerate(grid):
        for dx, ch in enumerate(row):
            role = letters.get(ch)
            if not role:
                continue
            p = (x0 + dx, y0 + dy)
            layer[p] = role
            if both:
                layer[ctx.mirror(p)] = role


def group_of(role):
    g = role.split(".")[0]
    if role in ("mix.stubble", "mix.stubble_shade", "mix.stubble_heavy", "mix.stubble_heavy_shade", "mix.beard",
                "mix.beard_shade", "mix.buzz", "mix.buzz_shade"):
        return "hair"
    if g == "mix":
        return "skin"
    return g


SELOUT_DARK = {"skin": "skin.deep", "hair": "hair.deep", "shirt": "shirt.deep", "trim": "trim.shade",
               "acc": "acc.shade", "eye": "eye.dark", "fix": "fix.outline"}
SELOUT_LIGHT = {"skin": "skin.shade", "hair": "hair.shade", "shirt": "shirt.shade", "trim": "trim.shade",
                "acc": "acc.shade", "eye": "eye.dark", "fix": "fix.outline"}


def add_outline(ctx, layer, keep_out=None):
    """Kontur na zewnątrz warstwy wg stylu. keep_out = piksele, na których konturu nie rysujemy
    (np. wnętrze twarzy dla zarostu – wtedy kontur tylko na sylwetce)."""
    ol = ctx.style["outline"]
    width = ol["width"][ctx.n]
    mask = set(layer)
    ring = dilate(mask, width, ol["diagonal"]) - mask
    if keep_out:
        ring -= keep_out
    ring = {p for p in ring if 0 <= p[0] < ctx.n and 0 <= p[1] < ctx.n}
    for p in ring:
        if ol["mode"] == "black":
            layer[p] = "fix.outline"
            continue
        # selout: kolor od sąsiada; od strony światła (góra/lewo) jaśniejszy
        best = None
        for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            q = (p[0] + dx, p[1] + dy)
            if q in mask:
                lit_side = dx > 0 or dy > 0  # sąsiad jest na prawo/niżej => kontur po lewej/górze
                best = (SELOUT_LIGHT if lit_side else SELOUT_DARK)[group_of(layer[q])]
                if not lit_side:
                    break
        layer[p] = best or "fix.outline"


# ───────────────────────── składanie i obraz ─────────────────────────

def compose(layers):
    out = {}
    for _, layer in layers:
        out.update(layer)
    return out


def to_image(layer, n, palette):
    from PIL import Image
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = img.load()
    for (x, y), role in layer.items():
        if 0 <= x < n and 0 <= y < n:
            px[x, y] = hex_to_rgb(palette[role]) + (255,)
    return img


def from_image(img, palette):
    """Odwrotność to_image: obraz w kolorach palety (np. poprawiony ręcznie szablon) -> mapa ról."""
    reverse = {}
    for role, color in palette.items():
        reverse.setdefault(hex_to_rgb(color), role)
    layer = {}
    px = img.convert("RGBA").load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            if (r, g, b) not in reverse:
                raise ValueError(f"kolor #{r:02x}{g:02x}{b:02x} w ({x},{y}) nie należy do palety szablonów")
            layer[(x, y)] = reverse[(r, g, b)]
    return layer
