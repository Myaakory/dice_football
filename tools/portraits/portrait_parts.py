"""Pule części portretu i ich rysowanie (32 i 64 px z tych samych kształtów).

Duże kształty (głowa, fryzura, zarost, koszulka) są opisane funkcjami w przestrzeni 32×32 i próbkowane w obu
rozdzielczościach – dlatego wersja 64 px pokazuje tę samą osobę. Drobne rysy (oczy, brwi, nos, usta) to ręczne
siatki znaków osobno dla 32 i 64 px (styl może mieć własne siatki).

Części "dopasowane do głowy" (FITTED) generuje się dla każdego kształtu głowy osobno – gra wybiera wariant
<część>@<głowa>. Pozostałe leżą zawsze w tym samym miejscu, niezależnie od głowy.
"""

import math

from portrait_core import Ctx, add_outline, dilate, paint, rim, stamp

LAYER_ORDER = ["hair_back", "head", "shirt", "eyes", "brows", "nose", "facial_hair", "mouth", "hair", "marks",
               "extras"]
FITTED = {"hair", "hair_back", "facial_hair", "marks", "extras"}

# Pule elementów (kolejność = indeks zapisywany w danych zawodnika).
POOLS = {
    "head": ["oval", "square", "round", "long", "standard"],
    "eyes": ["normal", "narrow", "big", "almond", "heavy_lid", "deep_set"],
    "brows": ["straight", "arched", "thick"],
    "nose": ["small", "long", "wide", "button", "aquiline", "broad"],
    "mouth": ["neutral", "smile", "thin", "full"],
    "hair": ["short", "side_part", "buzz", "curly", "long", "bald",
             "crew_cut", "quiff", "undercut", "fringe", "dreadlocks", "mohawk", "receding",
             "afro", "man_bun", "cornrows", "slicked_back", "spiky"],
    "facial_hair": ["none", "stubble", "moustache", "goatee", "full_beard", "stubble_3day", "short_beard"],
    "marks": ["none", "freckles", "scar", "mole", "scar_cheek", "scar_chin", "mole_lip", "mole_forehead"],
    # Dodatki osobno od znaków: zawodnik może mieć i bliznę, i kolczyk; szansę na brak dodatku ustawia waga "none".
    "extras": ["none", "earring", "headband"],
}
# Koszulki: nie należą do wyglądu – wariant wynika z pozycji (bramkarz), kolory z barw klubu (polowe / bramkarskie).
SHIRTS = ["field", "goalkeeper"]
# Pule kolorów: element wyglądu -> klucz w palettes.json
COLOR_POOLS = {"skin": "skin", "hair_color": "hair", "eye_color": "eyes", "accessory": "accessory"}

POOL_LABELS = {
    "head": "Kształt głowy", "eyes": "Oczy", "brows": "Brwi", "nose": "Nos", "mouth": "Usta",
    "hair": "Fryzura", "hair_back": "Fryzura (tył)", "facial_hair": "Zarost", "marks": "Znaki szczególne", "extras": "Dodatki",
    "shirt": "Koszulka",
}


def smoothstep(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


# ───────────────────────── głowa ─────────────────────────

HEAD_SHAPES = {
    # a_top / a_bot = połowa szerokości czaszki / żuchwy, n_bot = wykładnik superelipsy dolnej połowy
    # (większy = kanciasta szczęka), top / chin = czubek głowy i broda (y w przestrzeni 32 px).
    "oval": dict(a_top=6.8, a_bot=6.7, n_bot=1.9, top=4.6, chin=23.6),
    "square": dict(a_top=7.0, a_bot=7.15, n_bot=3.1, top=4.7, chin=23.2),
    "round": dict(a_top=7.35, a_bot=7.45, n_bot=2.15, top=4.8, chin=22.9),
    "long": dict(a_top=6.4, a_bot=6.25, n_bot=2.5, top=4.1, chin=24.3),
    # najbardziej pospolita: między owalną a kwadratową, bez wyrazistej cechy
    "standard": dict(a_top=6.9, a_bot=6.85, n_bot=2.45, top=4.6, chin=23.4),
}


class HeadGeo:
    CX = 16.0
    CY = 14.0  # linia oczu

    def __init__(self, shape, grow=0.0):
        p = HEAD_SHAPES[shape]
        self.shape = shape
        self.a_top = p["a_top"] + grow
        self.a_bot = p["a_bot"] + grow
        self.n_bot = p["n_bot"]
        self.top = p["top"] - grow * 0.6
        self.chin = p["chin"] + grow * 0.3
        self.cy = self.CY

    def inside(self, u, v, g=0.0):
        dx = abs(u - self.CX)
        if v < self.cy:
            a, b, n = self.a_top + g, self.cy - self.top + g, 2.1
        else:
            a, b, n = self.a_bot + g, self.chin - self.cy + g, self.n_bot
        if a <= 0 or b <= 0:
            return False
        return (dx / a) ** n + (abs(v - self.cy) / b) ** n <= 1.0

    def ear_center(self, side):
        return self.CX + side * (self.a_bot + 0.25), 15.1

    def in_ear(self, u, v, side):
        ex, ey = self.ear_center(side)
        return ((u - ex) / 1.3) ** 2 + ((v - ey) / 2.0) ** 2 <= 1.0 and abs(u - self.CX) > self.a_bot - 0.6

    def hairline(self, u, depth=3.1):
        """Linia włosów: nisko na środku czoła (top + depth), na skroniach schodzi do linii oczu."""
        y_h = self.top + depth
        t = smoothstep(self.a_top - 3.6, self.a_top - 0.9, abs(u - self.CX))
        return y_h + (self.cy - 0.7 - y_h) * t


def head_masks(ctx):
    if not hasattr(ctx, "_masks"):
        hg = ctx.head
        face = ctx.region(lambda u, v: hg.inside(u, v))
        ear_l = ctx.region(lambda u, v: hg.in_ear(u, v, -1)) - face
        ear_r = ctx.region(lambda u, v: hg.in_ear(u, v, 1)) - face
        neck = ctx.region(lambda u, v: abs(u - 16) < 3.3 and hg.cy + 3 < v < 30.5) - face
        ctx._masks = face, ear_l, ear_r, neck
    return ctx._masks


def draw_head(ctx, variant):
    hg = ctx.head
    face, ear_l, ear_r, neck = head_masks(ctx)
    px, uv = ctx.px, ctx.uv
    st = ctx.style["shading"]
    L = {}
    paint(L, face | ear_l | ear_r | neck, "skin.base")
    under_chin = {p for p in neck if uv(p)[1] < hg.chin + 1.5}
    if st == "cel":
        paint(L, {p for p in face if uv(p)[0] > 18.6 + 0.12 * (uv(p)[1] - hg.cy)}, "skin.shade")
        paint(L, rim(face, 0, px(1)) & {p for p in face if uv(p)[1] > hg.cy + 2}, "skin.shade")
        paint(L, ear_r, "skin.shade")
        paint(L, {p for p in ear_l if uv(p)[0] > hg.ear_center(-1)[0] + 0.1}, "skin.shade")
        paint(L, under_chin | {p for p in neck if uv(p)[0] > 17.4}, "skin.shade")
    elif st == "band":
        paint(L, rim(face, px(2), px(1)), "skin.shade")
        paint(L, {p for p in rim(face, -px(1), -px(1)) if uv(p)[1] < 12.5}, "skin.light")
        paint(L, ear_r | {p for p in ear_l if uv(p)[0] > hg.ear_center(-1)[0] + 0.3}, "skin.shade")
        paint(L, under_chin | rim(neck, px(1), 0), "skin.shade")
    else:  # soft
        paint(L, rim(face, px(3), px(2)), "skin.shade")
        paint(L, {p for p in rim(face, px(1), px(1)) if uv(p)[0] > 17 or uv(p)[1] > hg.chin - 2.5}, "skin.deep")
        paint(L, {p for p in rim(face, -px(1), -px(1)) if uv(p)[1] < 15}, "skin.light")
        paint(L, ctx.region(lambda u, v: ((u - 13.0) / 1.5) ** 2 + ((v - 8.6) / 0.8) ** 2 <= 1) & face, "skin.hi")
        paint(L, ear_r, "skin.shade")
        paint(L, {p for p in ear_l if uv(p)[0] > hg.ear_center(-1)[0] + 0.3}, "skin.shade")
        paint(L, under_chin | rim(neck, px(1), 0), "skin.shade")
        paint(L, {p for p in neck if uv(p)[1] < hg.chin + 0.6}, "skin.deep")
    if ctx.n >= 64 and st != "cel":  # małżowina: ciemniejszy środek ucha
        for ear, side in ((ear_l, -1), (ear_r, 1)):
            ex, ey = hg.ear_center(side)
            paint(L, {p for p in ear if abs(uv(p)[0] - ex) < 0.45 and abs(uv(p)[1] - ey) < 0.9}, "skin.deep")
    add_outline(ctx, L)
    return L


# ───────────────────────── koszulka ─────────────────────────

# Dekolt koszulki: połowa szerokości przy ramionach, głębokość V (y) i nachylenie boków (o ile węższy na jednostkę
# w dół). W 64 px serek jest minimalnie szerszy od szyi (szyja: 3.3) i schodzi równo pod 45° (1 piksel na wiersz)
# – nierówne nachylenie dawało widoczne załamanie boków. Kołnierz bramkarza: COLLAR_GK (połowa szerokości).
COLLAR = {32: (3.0, 29.3, 3.0 / 3.35), 64: (4.3, 30.7, 1.0)}
COLLAR_GK = {32: 3.0, 64: 3.3}
NECK_HALF = 3.3  # połowa szerokości szyi (head_masks)


def draw_shirt(ctx, variant="field"):
    """field = koszulka polowa z dekoltem w serek; goalkeeper = bramkarska: okrągły kołnierz i pas na piersi
    (jak koszulka bramkarza na boisku)."""
    half, depth, slope = COLLAR[ctx.n] if ctx.n in COLLAR else COLLAR[64]
    S = ctx.region(lambda u, v: v >= 26.4 and abs(u - 16) <= 8.6 + (v - 26.4) * 1.7)
    if variant == "goalkeeper":
        half = COLLAR_GK[ctx.n] if ctx.n in COLLAR_GK else COLLAR_GK[64]
        drop = 1.3 if ctx.n < 64 else 1.6
        opening = ctx.region(lambda u, v: ((u - 16) / half) ** 2 + ((v - 26.2) / drop) ** 2 < 1.0)
    else:
        opening = ctx.region(lambda u, v: abs(u - 16) < half - (v - 26.4) * slope and v < depth)
    S -= opening
    # lamówka zawsze 1 px (jak w 32 px): w 64 px gruba lamówka + pas cienia tworzyły drugie, szersze V wokół dekoltu
    trim = dilate(opening, 1) & S
    if variant == "goalkeeper":
        trim |= ctx.region(lambda u, v: 28.9 <= v < 29.8) & S
    uv = ctx.uv
    L = {}
    paint(L, S, "shirt.base")
    st = ctx.style["shading"]
    if st == "cel":
        paint(L, {p for p in S if uv(p)[0] > 20.5}, "shirt.shade")
    else:
        paint(L, rim(S, 0, -ctx.px(1)), "shirt.light")
        paint(L, {p for p in S if uv(p)[0] > 21.5} | rim(S, -ctx.px(2), 0), "shirt.shade")
        if st == "soft":
            paint(L, {p for p in S if uv(p)[0] > 23.5}, "shirt.deep")
        if ctx.n < 64:
            paint(L, {p for p in dilate(trim, 1) & S if uv(p)[1] > 27.3} - trim, "shirt.shade")
    paint(L, trim, "trim.base")
    paint(L, {p for p in trim if uv(p)[0] > 16}, "trim.shade")
    add_outline(ctx, L)
    # Wycięcie szersze od szyi: skóra (obojczyki) obok szyi, w kolorach skóry zawodnika – szyja zostaje bez zmian.
    chest = {p for p in opening if uv(p)[1] >= 26.4 and abs(uv(p)[0] - 16) >= NECK_HALF} - set(L)
    paint(L, {p for p in chest if uv(p)[0] < 16}, "skin.base")
    paint(L, {p for p in chest if uv(p)[0] > 16}, "skin.shade")
    return L


# ───────────────────────── rysy twarzy (siatki) ─────────────────────────
# Znaki: L powieka/kreska (rola zależy od stylu), w białko, I tęczówka, D ciemna tęczówka, p źrenica,
# h blask, k kontur, s/d/l/H skóra cień/głęboki cień/jasna/blask, b/B brwi (włosy cień/głęboki),
# q usta, m kreska ust, t zęby.

LETTERS = {
    "w": "fix.white", "I": "eye.iris", "D": "eye.dark", "p": "fix.pupil", "h": "fix.white", "k": "fix.outline",
    "s": "skin.shade", "d": "skin.deep", "l": "skin.light", "H": "skin.hi", "b": "hair.shade", "B": "hair.deep",
    "q": "skin.lip", "m": "skin.lip_dark", "t": "fix.teeth",
}
STYLE_LETTERS = {
    "bold": {"m": "fix.outline", "d": "skin.shade"},
}

# FEATURES[pula][wariant][rozmiar] = (x, y, siatka); "styl:wariant" = wersja tylko dla stylu.
# Oczy i brwi: lewa strona, prawa to odbicie lustrzane.
FEATURES = {
    "eyes": {
        "normal": {32: (11, 13, ["LLL", "wIw"]),
                   64: (22, 25, [".LLLLL.", "LwIhIwL", ".wDpDw.", "..sss.."])},
        "narrow": {32: (11, 13, ["LLL", ".I."]),
                   64: (22, 26, ["LLLLLLL", ".wIpIw.", "..sss.."])},
        "big": {32: (11, 12, ["LLL", "wIw", ".D."]),
                64: (22, 24, [".LLLLL.", "LwIhIwL", "wwIpIww", ".wDDDw.", "..sss.."])},
        "almond": {32: (10, 13, ["LLLL", ".wIw"]),
                   64: (21, 25, ["..LLLLL.", "LLwIhIwL", "..wDpDL.", "...sss.."])},
        "heavy_lid": {32: (11, 12, ["sss", "LLL", ".I."]),
                      64: (22, 24, [".sssss.", ".LLLLLL", "LwIhIw.", "..sss.."])},
        "deep_set": {32: (11, 12, ["sss", "LLL", "wIw"]),
                     64: (22, 23, [".sssss.", "sdddds.", "LLLLLLL", "wwIhIww", ".wDpDw.", "..sss.."])},
        "bold:normal": {32: (11, 13, [".k.", ".k."]),
                        64: (22, 25, ["..kkk..", ".kkhkk.", "..kkk.."])},
        "bold:narrow": {32: (11, 13, ["kkk", ".k."]),
                        64: (22, 26, [".kkkkk.", "..khk.."])},
        "bold:big": {32: (11, 13, ["wkw", "wkw"]),
                     64: (22, 24, ["..kkk..", ".wkhkk.", ".wkkkk.", "..kkk.."])},
    },
    "brows": {
        "straight": {32: (11, 11, ["BBB"]),
                     64: (22, 22, [".bbbbbb", "BBBBBBb"])},
        "arched": {32: (11, 10, [".B.", "B.B"]),
                   64: (22, 20, ["..BBBb.", ".B...BB", "B......"])},
        "thick": {32: (11, 11, ["BBB", "bbb"]),
                  64: (22, 21, ["bBBBBBB", "BBBBBBB", ".bb...."])},
    },
    "nose": {
        "small": {32: (14, 16, ["..s.", ".ss."]),
                  64: (28, 31, ["...ls...", "...ls...", "..l..s..", ".sd..ds.", "..ssss.."])},
        "long": {32: (14, 14, ["..s.", "..s.", "..s.", ".ss."]),
                 64: (28, 27, ["...ls...", "...ls...", "...ls...", "...ls...", "...ls...", "..l..s..",
                               ".sd..ds.", "..ssss.."])},
        "wide": {32: (14, 16, ["..s.", "s.ss"]),
                 64: (28, 30, ["...ls...", "...ls...", "...ls...", ".l....s.", "sd....ds", ".ssssss."])},
        "button": {32: (14, 16, [".ls.", ".ss."]),
                   64: (28, 31, ["...ls...", "...ls...", "..lHls..", "..llss..", ".sd..ds.", "..ssss.."])},
        "aquiline": {32: (14, 14, ["..s.", "...s", "..s.", ".ss."]),
                     64: (28, 27, ["...ls...", "...ls...", "....ls..", "....ls..", "...ls...", "...ls...",
                                   "..l..s..", ".sd..ds.", "..ssss.."])},
        "broad": {32: (14, 15, ["..s.", ".ls.", "ssss"]),
                  64: (28, 29, ["...ls...", "...ls...", "..lls...", "..llss..", ".l....s.", "sd....ds",
                                "ssssssss"])},
    },
    "mouth": {
        "neutral": {32: (14, 19, ["mmmm", ".ss."]),
                    64: (27, 38, ["..qqqqqq..", ".mmmmmmmm.", "...qqqq...", "...ssss..."])},
        "smile": {32: (14, 19, ["m..m", ".mm."]),
                  64: (27, 37, ["m........m", ".mttttttm.", "..mmmmmm..", "...ssss..."])},
        "thin": {32: (14, 19, [".mm."]),
                 64: (27, 38, ["..mmmmmm..", "...ssss..."])},
        "full": {32: (14, 18, [".qq.", "mmmm", ".qq."]),
                 64: (27, 37, ["..qqqqqq..", ".qqqqqqqq.", "mmmmmmmmmm", ".qqqqqqqq.", "..qqlqqq..",
                               "...ssss..."])},
    },
}
MIRRORED = {"eyes", "brows"}


def upscale_layer(layer, k):
    """Każdy piksel -> blok k×k (szkic większego rozmiaru z siatki 64 px)."""
    return {(x * k + i, y * k + j): r for (x, y), r in layer.items() for i in range(k) for j in range(k)}


def draw_feature(ctx, pool, variant):
    table = FEATURES[pool]
    entry = table.get(f"{ctx.style_id}:{variant}") or table[variant]
    if ctx.n not in entry:  # brak siatki dla tego rozmiaru: powiększona siatka 64 px
        return upscale_layer(draw_feature(Ctx(64, ctx.style_id, ctx.head), pool, variant), ctx.n // 64)
    x, y, grid = entry[ctx.n]
    letters = dict(LETTERS)
    letters["L"] = ctx.style["lid"]
    letters.update(STYLE_LETTERS.get(ctx.style_id, {}))
    L = {}
    stamp(ctx, L, grid, x, y, letters, both=pool in MIRRORED)
    return L


# ───────────────────────── fryzury ─────────────────────────

def shade_hair(ctx, M, roles=("hair.hi", "hair.base", "hair.shade", "hair.deep")):
    hi, base, shade, deep = roles
    uv, px = ctx.uv, ctx.px
    st = ctx.style["shading"]
    L = {}
    paint(L, M, base)
    if st == "cel":
        paint(L, {p for p in M if uv(p)[0] > 18.6} | rim(M, 0, px(1)), shade)
    elif st == "band":
        paint(L, rim(M, px(2), px(1)), shade)
        paint(L, {p for p in rim(M, -px(1), -px(1)) if uv(p)[0] < 16.5}, hi)
    else:
        paint(L, rim(M, px(3), px(2)), shade)
        paint(L, {p for p in rim(M, px(1), px(1)) if uv(p)[0] > 15.5 or uv(p)[1] > 12}, deep)
        top = min(uv(p)[1] for p in M) if M else 0
        paint(L, {p for p in rim(M, -px(1), -px(1)) if uv(p)[0] < 16.5 and uv(p)[1] < top + 3.5}, hi)
    return L


def strands(ctx, L, M, role, every=3, length=2.0):
    """Pasma: krótkie pionowe kreski przy dolnym brzegu grzywki."""
    edge = rim(M, 0, ctx.px(length))
    step = every * max(1, ctx.n // 32)
    for (x, y) in edge:
        if x % step == 0 and (x, y) in L and L[(x, y)] != "fix.outline":
            L[(x, y)] = role


def cast_shadow(ctx, L, M):
    """Cień włosów na czole (tylko style z cieniowaniem pasmowym/miękkim)."""
    if ctx.style["shading"] == "cel":
        return
    face = head_masks(ctx)[0]
    blocked = set(L)
    for (x, y) in list(blocked):
        for k in range(1, ctx.px(1) + 1):
            q = (x, y + k)
            if q in face and q not in blocked:
                L[q] = "skin.shade"


def hair_mask(ctx, variant):
    hg = ctx.head
    if variant == "short":
        def fn(u, v):
            fringe = 0.55 * max(0.0, math.sin(u * 2.3))
            return hg.inside(u, v, 0.9) and v < hg.hairline(u) + fringe
        return ctx.region(fn)
    if variant == "side_part":
        def fn(u, v):
            swoop = 1.3 * max(0.0, 1 - abs(u - 18.5) / 4.5)  # grzywka zaczesana na prawo
            lift = 0.5 if u > 12.6 else 0.0  # więcej objętości po prawej od przedziałka
            return hg.inside(u, v, 0.8 + lift) and v < hg.hairline(u, 2.6) + swoop
        return ctx.region(fn)
    if variant == "buzz":
        return ctx.region(lambda u, v: hg.inside(u, v, 0.15) and v < hg.hairline(u, 2.9) + 0.2)
    if variant == "curly":
        cy0 = hg.top + 3.2
        rx, ry = hg.a_top + 2.6, 5.6

        def fn(u, v):
            th = math.atan2(v - cy0, abs(u - 16))  # abs: loki symetryczne
            blob = ((u - 16) / rx) ** 2 + ((v - cy0) / ry) ** 2 <= 1.0 + 0.10 * math.cos(th * 11)
            sides = hg.inside(u, v, 1.3) and v < hg.cy
            return (blob or sides) and not (hg.inside(u, v) and v >= hg.hairline(u, 3.3))
        return ctx.region(fn)
    if variant == "long":
        def fn(u, v):
            d = abs(u - 16)
            cap = hg.inside(u, v, 0.9) and v < hg.hairline(u, 2.8)
            curtain = hg.a_bot - 1.1 < d < hg.a_top + 1.7 and hg.cy - 3 <= v < 21.5 + 0.5 * math.sin(u * 1.7)
            return cap or curtain
        return ctx.region(fn)
    if variant == "crew_cut":
        def fn(u, v):  # krótko, płasko na czubku, wysokie czoło bez grzywki
            lift = 0.6 * smoothstep(hg.top + 3.5, hg.top + 0.5, v)
            return hg.inside(u, v, 0.45 + lift) and v < hg.hairline(u, 2.5) and v >= hg.top - 0.7
        return ctx.region(fn)
    if variant == "quiff":
        def fn(u, v):  # podniesiony przód nad czołem
            cap = hg.inside(u, v, 0.7) and v < hg.hairline(u, 2.7)
            tuft = ((u - 14.6) / 4.4) ** 2 + ((v - (hg.top + 0.3)) / 2.1) ** 2 <= 1.0
            return cap or tuft
        return ctx.region(fn)
    if variant in ("undercut", "mohawk"):  # tylko górna, dłuższa część; wygolone boki dorysowuje draw_hair
        if variant == "undercut":
            return ctx.region(lambda u, v: hg.inside(u, v, 1.0) and v < hg.top + 3.2 + 0.25 * (u - 16)
                              and abs(u - 16) < hg.a_top - 1.0)
        return ctx.region(lambda u, v: abs(u - 16) < 1.7 and v >= hg.top - 2.6 + 0.9 * (abs(u - 16) / 1.7) ** 2
                          and (v < hg.top + 3.0 or hg.inside(u, v, 0.4)) and v < hg.hairline(u, 3.0))
    if variant == "fringe":
        def fn(u, v):  # równa, gęsta grzywka do brwi
            line = 10.7 if abs(u - 16) < hg.a_top - 1.6 else 0.0
            return hg.inside(u, v, 1.0) and v < max(line, hg.hairline(u, 3.0))
        return ctx.region(fn)
    if variant == "dreadlocks":  # czapka; pasma (każde z własnym konturem) dorysowuje draw_hair
        return ctx.region(lambda u, v: hg.inside(u, v, 1.0) and v < hg.hairline(u, 2.8))
    if variant == "afro":
        cy0 = hg.top + 3.4
        rx, ry = hg.a_top + 3.5, 6.9

        def fn(u, v):
            th = math.atan2(v - cy0, abs(u - 16))
            blob = ((u - 16) / rx) ** 2 + ((v - cy0) / ry) ** 2 <= 1.0 + 0.07 * math.cos(th * 13)
            sides = hg.inside(u, v, 1.8) and v < hg.cy + 0.5
            return (blob or sides) and not (hg.inside(u, v) and v >= hg.hairline(u, 3.4))
        return ctx.region(fn)
    if variant == "man_bun":
        def fn(u, v):  # gładko zaczesane do tyłu + kok na czubku
            cap = hg.inside(u, v, 0.45) and v < hg.hairline(u, 2.7)
            bun = ((u - 16) / 2.2) ** 2 + ((v - (hg.top - 1.3)) / 1.7) ** 2 <= 1.0
            return cap or bun
        return ctx.region(fn)
    if variant == "cornrows":
        return ctx.region(lambda u, v: hg.inside(u, v, 0.25) and v < hg.hairline(u, 2.8) + 0.2)
    if variant == "slicked_back":
        def fn(u, v):  # zaczesane do tyłu, wysokie czoło, objętość z tyłu głowy
            return hg.inside(u, v, 0.75 + 0.35 * smoothstep(hg.top + 3, hg.top, v)) and v < hg.hairline(u, 2.3)
        return ctx.region(fn)
    if variant == "spiky":
        a, b = hg.a_top + 0.6, hg.cy - hg.top + 0.6

        def crown(u):  # górna krawędź czapki włosów nad danym u
            t = min(1.0, abs(u - 16) / a)
            return hg.cy - b * (1 - t ** 2.1) ** (1 / 2.1)

        def fn(u, v):
            d = abs(u - 16)
            cap = hg.inside(u, v, 0.6) and v < hg.hairline(u, 2.7) + 0.8 * max(0.0, math.sin(u * 2.0))
            # kolce: trójkąty co 3 jednostki, pochylone w prawo, najwyższe na środku
            lean = u - 0.45 * (crown(u) - v)
            tri = 1 - abs(((lean - 14.5) / 3.0) % 1.0 - 0.5) * 2
            height = 2.3 * (1 - (d / (hg.a_top + 0.5)) ** 2)
            spikes = d < hg.a_top and crown(u) - height * tri <= v < crown(u) + 1.0
            return cap or spikes
        return ctx.region(fn)
    if variant == "receding":
        def fn(u, v):  # zakola: linia włosów cofnięta na skroniach
            recess = 2.0 * max(0.0, 1 - abs(abs(u - 16) - 3.9) / 2.0)
            return hg.inside(u, v, 0.5) and v < hg.hairline(u, 3.2) - recess
        return ctx.region(fn)
    return set()


def lock_at(u):
    """Dredy: (numer pasma od środka, położenie w paśmie 0..1). Pasmo co 3 jednostki, symetrycznie."""
    t = abs(u - 16) / 3.0
    return int(t), t - int(t)


def lock_end(u, base):
    i, _ = lock_at(u)
    return base + (i * 1.7) % 2.4  # nierówne końce kolejnych pasm


def draw_locks(ctx, region_fn, roles, shift=0.0):
    """Dredy: pionowe pasma o nierównych końcach. Kontur tylko wokół całości; pasma dzieli ciemniejszy odcień
    (osobny kontur każdego pasma dawał za dużo czerni przy ciemnych włosach)."""
    base, shade, deep = roles
    M = ctx.region(region_fn)
    L = {}
    for p in M:  # jedna cienka linia cienia między pasmami, bez ciemniejszych rowków
        frac = lock_at(ctx.uv(p)[0] + shift)[1]
        L[p] = shade if frac >= 0.84 else base
    paint(L, rim(M, 0, ctx.px(1)), shade)
    add_outline(ctx, L)
    return L


def draw_hair(ctx, variant):
    M = hair_mask(ctx, variant)
    face = head_masks(ctx)[0]
    if variant == "bald":
        L = {}
        if ctx.style["shading"] != "cel":
            shine = ctx.region(lambda u, v: ((u - 13.3) / 1.6) ** 2 + ((v - 6.8) / 0.75) ** 2 <= 1) & face
            paint(L, shine, "skin.hi" if ctx.style["shading"] == "soft" else "skin.light")
        return L
    if variant == "buzz":
        L = shade_hair(ctx, M, ("mix.buzz", "mix.buzz", "mix.buzz_shade", "mix.buzz_shade"))
        if ctx.n >= 64 and ctx.style["shading"] != "cel":
            for (x, y) in M:
                if x % 2 == 0 and y % 2 == 0 and L[(x, y)] == "mix.buzz":
                    L[(x, y)] = "mix.buzz_shade"
        add_outline(ctx, L, keep_out=face)
        return L
    if variant in ("undercut", "mohawk"):
        # wygolone boki (jak buzz) pod dłuższą górą
        sides = ctx.region(lambda u, v: ctx.head.inside(u, v, 0.15) and v < ctx.head.hairline(u, 2.9) + 0.2) - M
        L = shade_hair(ctx, sides, ("mix.buzz", "mix.buzz", "mix.buzz_shade", "mix.buzz_shade"))
        add_outline(ctx, L, keep_out=face)
        top = shade_hair(ctx, M)
        strands(ctx, top, M, "hair.shade")
        add_outline(ctx, top)
        L.update(top)
        return L
    if variant == "cornrows":
        # warkoczyki przy skórze: pasy włosów z ciemnymi przedziałkami i skośnym splotem
        L = shade_hair(ctx, M)
        k = max(1, ctx.n // 32)
        for (x, y) in M:
            frac = (abs(ctx.uv((x, y))[0] - 16) / 1.5) % 1.0
            if frac >= 0.7:
                L[(x, y)] = "mix.buzz_shade"
            elif L[(x, y)] == "hair.base" and ((x // k) + (y // k)) % 3 == 0:
                L[(x, y)] = "hair.shade"
        add_outline(ctx, L, keep_out=face)
        cast_shadow(ctx, L, M)
        return L
    L = shade_hair(ctx, M)
    if variant == "slicked_back":
        k = max(1, ctx.n // 32)
        for (x, y) in M:  # połysk i poziome linie grzebienia
            u, v = ctx.uv((x, y))
            if L[(x, y)] == "hair.base" and int(v * 2) % 3 == 0 and (x // k) % 3 != 0:
                L[(x, y)] = "hair.shade"
            elif L[(x, y)] == "hair.base" and abs(v - (ctx.head.top + 1.2)) < 0.5 and u < 17:
                L[(x, y)] = "hair.hi"
    if variant == "man_bun":
        bun = ctx.region(lambda u, v: v < ctx.head.top + 0.2 and ((u - 16) / 2.2) ** 2
                         + ((v - (ctx.head.top - 1.3)) / 1.7) ** 2 <= 1.0)
        paint(L, rim(bun, 0, ctx.px(1)) & M, "hair.deep")  # cień pod kokiem
    if variant == "dreadlocks":
        hg = ctx.head
        locks = draw_locks(ctx, lambda u, v: hg.a_bot - 0.9 < abs(u - 16) < hg.a_top + 2.3
                           and hg.cy - 4 <= v < lock_end(u, 20.6), ("hair.base", "hair.shade", "hair.deep"))
        add_outline(ctx, L)
        locks.update(L)
        return locks
    if variant in ("curly", "afro"):
        k = max(1, ctx.n // 32)
        for (x, y) in M:
            cx, cy = x // k, y // k
            if (cx + 2 * cy) % 4 == 0 and L[(x, y)] == "hair.base":
                L[(x, y)] = "hair.shade"
            elif (cx + 2 * cy) % 4 == 2 and L[(x, y)] == "hair.base" and ctx.uv((x, y))[0] < 15 \
                    and ctx.style["shading"] != "cel":
                L[(x, y)] = "hair.hi"
    elif variant not in ("dreadlocks", "slicked_back", "man_bun"):
        strands(ctx, L, M, "hair.shade" if ctx.style["shading"] != "cel" else "fix.outline")
    if variant == "side_part":
        part = ctx.region(lambda u, v: 12.1 < u < 13.1 and v < ctx.head.top + 2.0) & M
        paint(L, part, "hair.deep" if ctx.style["shading"] == "soft" else "hair.shade")
    add_outline(ctx, L)
    cast_shadow(ctx, L, M)
    return L


def draw_hair_back(ctx, variant):
    if variant not in ("long", "dreadlocks"):
        return {}
    hg = ctx.head
    locks = variant == "dreadlocks"

    if locks:
        return draw_locks(ctx, lambda u, v: hg.cy - 4 <= v < lock_end(u + 1.0, 26.8)
                          and abs(u - 16) < hg.a_top + 2.0 - 0.1 * max(0.0, v - hg.cy),
                          ("hair.shade", "hair.deep", "hair.deep"), shift=1.0)

    def fn(u, v):
        if v < hg.cy:  # na czubku tył pokrywa się z grzywką – inaczej dwa kontury obok siebie
            return hg.inside(u, v, 0.9)
        ends = 27.2 + 1.3 * abs(math.sin(u * 0.9))  # nierówne końce pasm
        return abs(u - 16) < hg.a_top + 1.6 - 0.1 * (v - hg.cy) and v < ends
    M = ctx.region(fn)
    L = {}
    paint(L, M, "hair.shade")
    paint(L, rim(M, ctx.px(2), 0) | rim(M, 0, ctx.px(1)), "hair.deep")
    add_outline(ctx, L)
    return L


# ───────────────────────── zarost ─────────────────────────

def beard_top(hg, u):
    return 17.5 + (hg.cy + 0.8 - 17.5) * smoothstep(2.4, hg.a_bot - 0.6, abs(u - 16))


def draw_facial_hair(ctx, variant):
    hg = ctx.head
    face, ear_l, ear_r, neck = head_masks(ctx)
    if variant == "none":
        return {}
    if variant == "stubble":
        M = ctx.region(lambda u, v: hg.inside(u, v) and v > beard_top(hg, u)) - ear_l - ear_r
        L = {}
        paint(L, M, "mix.stubble")
        paint(L, rim(M, ctx.px(2), ctx.px(1)), "mix.stubble_shade")
        return L
    if variant == "stubble_3day":
        # kilkudniowy: ciemniejszy niż stubble, miękka (jaśniejsza) górna krawędź, w 64 px drobne kropki
        M = ctx.region(lambda u, v: hg.inside(u, v) and v > beard_top(hg, u) - 0.3) - ear_l - ear_r
        L = {}
        paint(L, M, "mix.stubble_heavy")
        paint(L, rim(M, ctx.px(2), ctx.px(1)), "mix.stubble_heavy_shade")
        if ctx.n >= 64:
            for (x, y) in M:
                if (x * 3 + y * 5) % 7 == 0:
                    L[(x, y)] = "mix.stubble_heavy_shade"
        paint(L, rim(M, 0, -ctx.px(1)), "mix.stubble")
        return L
    if variant == "short_beard":
        # tygodniowy: krótka, przylegająca broda – kolor włosów przemieszany ze skórą, miękkie przejście na policzkach
        M = ctx.region(lambda u, v: hg.inside(u, v, 0.25) and v > beard_top(hg, u) - 0.3) - ear_l - ear_r
        M -= ctx.region(lambda u, v: abs(u - 16) < 1.7 and 18.9 <= v < 20.2)  # odsłonięte usta
        L = {}
        paint(L, M, "mix.beard")
        paint(L, rim(M, ctx.px(2), ctx.px(1)), "mix.beard_shade")
        if ctx.n >= 64:
            for (x, y) in M:
                if (x * 73 + y * 151) % 11 < 3 and L[(x, y)] == "mix.beard":  # nieregularne włoski
                    L[(x, y)] = "mix.beard_shade"
        paint(L, rim(M, 0, -ctx.px(1)), "mix.stubble_heavy")
        add_outline(ctx, L, keep_out=face | neck)
        return L
    if ctx.n >= 64:
        # 64 px: łukowata góra, opadające i zwężone końce, zaokrąglona bródka (32 px zostaje prostokątne – czytelne)
        def moustache(u, v):
            d = abs(u - 16)
            top = 17.8 + 0.7 * (d / 2.9) ** 2
            bottom = 18.95 + 0.9 * smoothstep(1.7, 2.7, d)
            return d < 2.9 and top <= v < bottom and not (d > 2.35 and v < 18.7)

        def chin(u, v):
            d = abs(u - 16)
            half = 2.0 - 1.0 * smoothstep(hg.chin - 1.6, hg.chin + 0.6, v)
            return d < half and v >= 20.3 + 0.6 * (d / 2.0) ** 2 and hg.inside(u, v, 0.6)
    else:
        def moustache(u, v):
            d = abs(u - 16)
            return (d < 2.8 and 17.9 <= v < 18.9) or (2.0 <= d < 2.9 and 17.9 <= v < 19.9)

        def chin(u, v):
            return abs(u - 16) < 2.0 and 20.4 <= v and hg.inside(u, v, 0.6)
    if variant == "moustache":
        M = ctx.region(moustache)
    elif variant == "goatee":
        M = ctx.region(lambda u, v: moustache(u, v) or chin(u, v))
    else:  # full_beard
        M = ctx.region(lambda u, v: hg.inside(u, v, 0.6) and v > beard_top(hg, u) - 0.4) - ear_l - ear_r
        M -= ctx.region(lambda u, v: abs(u - 16) < 1.9 and 18.9 <= v < 20.3)  # odsłonięte usta
    L = shade_hair(ctx, M)
    if variant == "full_beard":
        k = max(1, ctx.n // 32)
        for (x, y) in M:
            if ((x // k) * 3 + (y // k) * 2) % 5 == 0 and L[(x, y)] == "hair.base":
                L[(x, y)] = "hair.shade"
    add_outline(ctx, L, keep_out=face | neck)
    return L


# ───────────────────────── znaki szczególne ─────────────────────────

def dots(ctx, points, role):
    return {(int(u * ctx.s), int(v * ctx.s)): role for u, v in points}


def draw_marks(ctx, variant):
    hg = ctx.head
    if variant == "none":
        return {}
    if variant == "freckles":
        pts = [(11.5, 16.5), (12.6, 17.4)] if ctx.n == 32 else             [(11.0, 16.2), (12.6, 16.6), (11.8, 17.6), (13.6, 15.9), (10.6, 17.9)]
        L = dots(ctx, pts, "mix.freckle")
        L.update({ctx.mirror(p): r for p, r in L.items()})
        return L
    moles = {"mole": (19.6, 17.6), "mole_lip": (13.6, 18.1), "mole_forehead": (18.6, 9.6)}
    if variant in moles:
        u, v = moles[variant]
        L = dots(ctx, [(u, v)], "skin.deep")
        if ctx.n >= 64:  # 2×2 piksele
            L.update(dots(ctx, [(u + 0.5, v), (u, v + 0.5), (u + 0.5, v + 0.5)], "skin.deep"))
        return L
    if variant == "scar_cheek":  # skośna blizna na prawym policzku
        if ctx.n == 32:
            return dots(ctx, [(19.5, 15.5), (20.5, 16.5)], "skin.light")
        L = {}
        for i in range(6):
            x, y = 38 + i, 30 + i
            L[(x, y)] = "skin.hi"
            L[(x, y + 1)] = "skin.deep"
        return L
    if variant == "scar_chin":  # krótka pionowa blizna na brodzie
        if ctx.n == 32:
            return dots(ctx, [(17.5, hg.chin - 2.4)], "skin.light")
        y0 = int((hg.chin - 3.0) * 2)
        L = {}
        for i in range(4):
            L[(34, y0 + i)] = "skin.hi"
            L[(35, y0 + i)] = "skin.deep"
        return L
    if ctx.n > 64 and variant in ("scar", "earring"):
        return upscale_layer(draw_marks(Ctx(64, ctx.style_id, hg), variant), ctx.n // 64)
    if variant == "scar":
        if ctx.n == 32:
            return dots(ctx, [(12.5, 10.5), (12.5, 11.5), (13.5, 12.4)], "skin.light")
        L = {}
        for i in range(7):
            x, y = 23 + i // 2, 19 + i
            L[(x, y)] = "skin.hi"
            L[(x + 1, y)] = "skin.deep"
        return L
    if variant == "earring":
        ex, ey = hg.ear_center(-1)
        if ctx.n == 32:
            L = dots(ctx, [(ex - 0.2, ey + 2.4)], "acc.base")
        else:
            x, y = int((ex - 0.4) * 2), int((ey + 2.0) * 2)
            L = {(x, y): "acc.hi", (x, y + 1): "acc.base", (x + 1, y + 1): "acc.shade", (x, y + 2): "acc.shade"}
        add_outline(ctx, L, keep_out=head_masks(ctx)[1])
        return L
    if variant == "headband":
        M = ctx.region(lambda u, v: hg.inside(u, v, 1.1) and hg.top + 2.0 <= v < hg.top + 3.5)
        L = shade_hair(ctx, M, ("acc.hi", "acc.base", "acc.shade", "acc.shade"))
        add_outline(ctx, L)
        return L
    raise KeyError(variant)


# ───────────────────────── składanie ─────────────────────────

def draw_part(ctx, layer_name, variant):
    if layer_name == "head":
        return draw_head(ctx, variant)
    if layer_name == "shirt":
        return draw_shirt(ctx, variant)
    if layer_name in FEATURES:
        return draw_feature(ctx, layer_name, variant)
    if layer_name == "hair":
        return draw_hair(ctx, variant)
    if layer_name == "hair_back":
        return draw_hair_back(ctx, variant)
    if layer_name == "facial_hair":
        return draw_facial_hair(ctx, variant)
    if layer_name in ("marks", "extras"):
        return draw_marks(ctx, variant)
    raise KeyError(layer_name)


def layer_variant(look, layer_name):
    """Który wariant puli rysuje daną warstwę (hair_back = tył tej samej fryzury, shirt = jedna)."""
    if layer_name == "hair_back":
        return look["hair"]
    if layer_name == "shirt":
        return look.get("kit", "field")
    return look[layer_name]


def build_layers(look, style_id, n):
    from portrait_core import STYLES
    head = HeadGeo(look["head"], STYLES[style_id]["head_grow"])
    ctx = Ctx(n, style_id, head)
    return [(name, draw_part(ctx, name, layer_variant(look, name))) for name in LAYER_ORDER]
