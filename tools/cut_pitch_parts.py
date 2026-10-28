"""Tnie grafikę boiska na elementy, z których gra składa boisko (PitchBuilder).
Uruchom: python tools/cut_pitch_parts.py

Źródła (grafiki_brudnopis/):
- pitch_grass_color1.png : bezszwowa trawa 128x128 -> grass.png (gra kładzie ją na całe boisko).
  Ciemne pasy gra liczy filtrem (PitchBuilder.DARK_GRASS): podmiana kolorów odczytana z warstwy Grass
  w pitch.aseprite (jasny i ciemny pas w tym samym miejscu trawy) – narzędzie wypisuje tę mapę.
- pitch.aseprite : warstwy Lines (krycie warstwy -> LINE_OPACITY w PitchBuilder), Goal Shadow, Goals.
  Proste linie (boczne, końcowe, środkowa, pola karne, pola bramkowe) gra rysuje sama; tu wycinamy tylko
  elementy krzywe i bramki – każdy osobno, bo są rysowane ręcznie (drobne asymetrie).

Wynik: assets/graphics/pitch/parts/*.png + pieces.json (dla każdego elementu: kotwica na polu gry w ułamkach
prostokąta między liniami i przesunięcie lewego górnego rogu w pikselach).
"""

import json
import struct
import zlib
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = ROOT / "grafiki_brudnopis"
OUT_DIR = ROOT / "assets" / "graphics" / "pitch" / "parts"

# Pole gry w pitch.aseprite (prostokąt między zewnętrznymi krawędziami linii).
FIELD = (0, 32, 448, 640)
LINE_WIDTH = 2
# Grass w pitch.aseprite: wiersz y odpowiada wierszowi (y + GRASS_OFFSET_Y) % 128 kafelka trawy.
GRASS_OFFSET_Y = 96
# Kotwice elementów (ułamki pola gry) i okna wycinania w pikselach pitch.aseprite (x0, y0, x1, y1 – bez końca).
PIECES = {
    "line_corner_tl": ((0.0, 0.0), (0, 32, 24, 56)),
    "line_corner_tr": ((1.0, 0.0), (424, 32, 448, 56)),
    "line_corner_bl": ((0.0, 1.0), (0, 648, 24, 672)),
    "line_corner_br": ((1.0, 1.0), (424, 648, 448, 672)),
    "line_spot_top": ((0.5, 0.0), (208, 90, 240, 116)),
    "line_spot_bottom": ((0.5, 1.0), (208, 588, 240, 614)),
    "line_penalty_arc_top": ((0.5, 0.0), (140, 132, 308, 180)),
    "line_penalty_arc_bottom": ((0.5, 1.0), (140, 524, 308, 572)),
    "line_center_circle": ((0.5, 0.5), (140, 280, 308, 424)),
}
GOALS = {
    "goal_top": ((0.5, 0.0), (180, 0, 280, 60)),
    "goal_bottom": ((0.5, 1.0), (180, 644, 280, 704)),
}


# --- Aseprite ---

def read_aseprite(path):
    """Warstwy pierwszej klatki: {nazwa: (Image RGBA w rozmiarze płótna, krycie warstwy 0-255)}. Tylko RGBA."""
    data = path.read_bytes()
    _, magic, frames, width, height, depth = struct.unpack_from("<IHHHHH", data, 0)
    assert magic == 0xA5E0 and depth == 32, "oczekiwany plik Aseprite RGBA"
    layers, cels = [], []
    frame_bytes, _, old_chunks, _ = struct.unpack_from("<IHHH", data, 128)
    new_chunks = struct.unpack_from("<I", data, 128 + 12)[0]
    pos = 128 + 16
    for _ in range(new_chunks or old_chunks):
        size, kind = struct.unpack_from("<IH", data, pos)
        body = data[pos + 6:pos + size]
        if kind == 0x2004:
            opacity = body[12]
            name_len = struct.unpack_from("<H", body, 16)[0]
            layers.append((body[18:18 + name_len].decode("utf8"), opacity))
        elif kind == 0x2005:
            layer, x, y, _, cel_type = struct.unpack_from("<HhhBH", body, 0)
            if cel_type in (0, 2):
                w, h = struct.unpack_from("<HH", body, 16)
                pixels = body[20:]
                if cel_type == 2:
                    pixels = zlib.decompress(pixels)
                cels.append((layer, x, y, Image.frombytes("RGBA", (w, h), pixels)))
        pos += size
    result = {}
    for layer, x, y, image in cels:
        canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        canvas.paste(image, (x, y))
        name, opacity = layers[layer]
        result[name] = (canvas, opacity)
    return result


# --- Trawa ---

def dark_palette(grass_layer, tile):
    """Mapa kolor jasnej trawy -> kolor ciemnego pasa (z pasa y 32..96 w pitch.aseprite)."""
    counts = {}
    for y in range(32, 96):
        for x in range(grass_layer.width):
            light = tile.getpixel((x % 128, (y + GRASS_OFFSET_Y) % 128))
            dark = grass_layer.getpixel((x, y))
            key = (light, dark)
            counts[key] = counts.get(key, 0) + 1
    best = {}
    for (light, dark), count in counts.items():
        if count > best.get(light, (None, 0))[1]:
            best[light] = (dark, count)
    return {light: dark for light, (dark, _) in best.items()}


def cut_grass(layers):
    tile = Image.open(SOURCE_DIR / "pitch_grass_color1.png").convert("RGBA")
    assert tile.size == (128, 128)
    print("mapa ciemnego pasa (PitchBuilder.DARK_GRASS):", dark_palette(layers["Grass"][0], tile))
    save(tile, "grass.png")


# --- Linie i bramki ---

def straight_line_mask():
    """Piksele prostych linii (rysuje je gra) – wycięte elementy ich nie zawierają."""
    fx, fy, fw, fh = FIELD
    cx = fx + fw // 2
    w = LINE_WIDTH
    rects = [(fx, fy, fw, w), (fx, fy + fh - w, fw, w), (fx, fy, w, fh), (fx + fw - w, fy, w, fh),
             (fx, fy + fh // 2 - w // 2, fw, w)]
    for box_w, box_h in [(254, 100), (104, 35)]:
        left = cx - box_w // 2
        for top in (fy, fy + fh - box_h):
            rects += [(left, top, w, box_h), (left + box_w - w, top, w, box_h)]
        rects += [(left, fy + box_h - w, box_w, w), (left, fy + fh - box_h, box_w, w)]
    mask = set()
    for x0, y0, rw, rh in rects:
        mask.update((x, y) for y in range(y0, y0 + rh) for x in range(x0, x0 + rw))
    return mask


def anchor_point(anchor):
    fx, fy, fw, fh = FIELD
    return fx + round(anchor[0] * fw), fy + round(anchor[1] * fh)


def cut_piece(image, window, skip=frozenset()):
    """Nieprzezroczyste piksele okna (poza `skip`) przycięte do ich prostokąta: (Image, lewy górny róg)."""
    x0, y0, x1, y1 = window
    pixels = {(x, y): image.getpixel((x, y)) for y in range(y0, y1) for x in range(x0, x1)
              if image.getpixel((x, y))[3] > 0 and (x, y) not in skip}
    assert pixels, f"puste okno {window}"
    left = min(x for x, _ in pixels)
    top = min(y for _, y in pixels)
    right = max(x for x, _ in pixels) + 1
    bottom = max(y for _, y in pixels) + 1
    piece = Image.new("RGBA", (right - left, bottom - top), (0, 0, 0, 0))
    for (x, y), color in pixels.items():
        piece.putpixel((x - left, y - top), color)
    return piece, (left, top)


def cut_lines(layers):
    lines, opacity = layers["Lines"]
    straight = straight_line_mask()
    colors = {lines.getpixel((x, y)) for y in range(lines.height) for x in range(lines.width)} - {(0, 0, 0, 0)}
    print("kolory linii:", colors, "krycie warstwy:", opacity)
    pieces = {}
    for name, (anchor, window) in PIECES.items():
        piece, corner = cut_piece(lines, window, straight)
        save(piece, name + ".png")
        ax, ay = anchor_point(anchor)
        pieces[name] = {"anchor": list(anchor), "offset": [corner[0] - ax, corner[1] - ay], "layer": "lines"}
    # Bramki: cień pod bramką, jeden obrazek na bramkę.
    goals = Image.alpha_composite(layers["Goal Shadow"][0], layers["Goals"][0])
    for name, (anchor, window) in GOALS.items():
        piece, corner = cut_piece(goals, window)
        save(piece, name + ".png")
        ax, ay = anchor_point(anchor)
        pieces[name] = {"anchor": list(anchor), "offset": [corner[0] - ax, corner[1] - ay], "layer": "goals"}
    covered = straight.copy()
    for name, (_, window) in PIECES.items():
        x0, y0, x1, y1 = window
        covered.update((x, y) for y in range(y0, y1) for x in range(x0, x1))
    missing = [(x, y) for y in range(lines.height) for x in range(lines.width)
               if lines.getpixel((x, y))[3] > 0 and (x, y) not in covered]
    assert not missing, f"piksele linii poza elementami: {missing[:10]}"
    (OUT_DIR / "pieces.json").write_text(json.dumps(pieces, indent="\t") + "\n", encoding="utf8")
    print("saved", (OUT_DIR / "pieces.json").relative_to(ROOT))


def save(image, name):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    image.save(OUT_DIR / name)
    print("saved", (OUT_DIR / name).relative_to(ROOT))


def main():
    layers = read_aseprite(SOURCE_DIR / "pitch.aseprite")
    cut_grass(layers)
    cut_lines(layers)


if __name__ == "__main__":
    main()
