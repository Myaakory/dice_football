"""Narzędzie deweloperskie: części portretów zawodników (32×32 i 64×64) do wgrania do gry.

Uruchom z katalogu projektu:
  python tools/portraits/portrait_tool.py demo [--out KATALOG]
      testowi zawodnicy (test_players.json) z podziałem na części, porównanie stylów, arkusze pul części
      i losowi zawodnicy wg regionów. Domyślnie do grafiki_brudnopis/portrety/.
  python tools/portraits/portrait_tool.py random --region west_africa --count 12 --seed 7 [--style retro]
      podgląd losowego wyglądu z wag regionu (data/portrait_weights.csv z arkusza; --approved = tylko
      elementy zatwierdzone w przeglądzie).
  python tools/portraits/portrait_tool.py random --nationality POL --nationality BRA --count 10
      to samo wg narodowości (data/nationalities.csv): najpierw pochodzenie z wag narodowości, potem wygląd.
  python tools/portraits/portrait_tool.py export --style retro [--out assets/graphics/portraits]
      szablony zatwierdzonych części (PNG w kolorach palety domyślnej) + manifest.json dla gry.

Ręczne poprawki: plik PNG z eksportu (w kolorach palety domyślnej) wrzucony do
tools/portraits/overrides/<styl>/<warstwa>/<nazwa>.png zastępuje część rysowaną kodem – przy kolejnych
eksportach i podglądach używana jest wersja ręczna. Opis: tools/portraits/README.md.
"""

import argparse
import csv
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import portrait_core as core
import portrait_parts as parts

ROOT = core.HERE.parent.parent
DEFAULT_PREVIEW_DIR = ROOT / "grafiki_brudnopis" / "portrety"
DEFAULT_EXPORT_DIR = ROOT / "assets" / "graphics" / "portraits"
OVERRIDES_DIR = core.HERE / "overrides"
WEIGHTS_CSV = ROOT / "data" / "portrait_weights.csv"
NATIONS_CSV = ROOT / "data" / "nationalities.csv"
DEFAULT_STYLE = "retro"  # wybrany styl (2026-10-30); "soft" i "bold" zostają tylko do porównań, bez nowych części

BG = (30, 33, 39)
TILE = (52, 58, 66)
TEXT = (232, 228, 218)
MUTED = (150, 156, 166)


def font(size, bold=False):
    name = "arialbd.ttf" if bold else "arial.ttf"
    try:
        return ImageFont.truetype(name, size)
    except OSError:
        return ImageFont.load_default()


# ───────────────────────── części i warstwy ─────────────────────────

def part_file(layer, variant, head, n):
    fitted = layer in parts.FITTED
    return f"{layer}/{variant}{'@' + head if fitted else ''}_{n}.png"


def build_layers(look, style_id, n, palettes):
    """Warstwy portretu w kolejności rysowania; części z overrides/ mają pierwszeństwo przed kodem."""
    layers = parts.build_layers(look, style_id, n)
    default = None
    out = []
    for name, layer in layers:
        override = OVERRIDES_DIR / style_id / part_file(name, parts.layer_variant(look, name), look["head"], n)
        if override.exists():
            default = default or core.default_palette(style_id, palettes)
            layer = core.from_image(Image.open(override), default)
        out.append((name, layer))
    return out


def player_palette(style_id, palettes, look, team):
    return core.resolve_palette(style_id, palettes, look["skin"], look["hair_color"], look["eye_color"],
                                look["accessory"], team["shirt"], team["trim"])


def render(look, style_id, n, palettes, team):
    """team = {"shirt", "trim"} barwy klubu; "kit": "goalkeeper" = koszulka bramkarska (wtedy bramkarskie barwy)."""
    look = dict(look, kit=team.get("kit", "field"))
    pal = player_palette(style_id, palettes, look, team)
    layers = build_layers(look, style_id, n, palettes)
    return core.to_image(core.compose(layers), n, pal), [(name, core.to_image(l, n, pal)) for name, l in layers]


def scaled(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


# ───────────────────────── losowanie wyglądu ─────────────────────────

def weighted(rng, weights):
    items = [(k, w) for k, w in weights.items() if w > 0]
    total = sum(w for _, w in items)
    r = rng.uniform(0, total)
    for k, w in items:
        r -= w
        if r <= 0:
            return k
    return items[-1][0]


def load_weights(approved_only=False):
    """Wagi z data/portrait_weights.csv (arkusz portraits_weights_dice_football, tools/sync_sheets.py --portraits):
    {region: {pula: {wariant: waga}}}. Pusta komórka = brak wagi; region bez żadnej wagi w puli bierze kolumnę
    'any'. Elementy odrzucone (status rejected) nigdy nie są losowane, z approved_only – tylko zatwierdzone
    (oraz 'none', status '-')."""
    with open(WEIGHTS_CSV, encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    columns = [c for c in rows[0] if c not in ("id", "pool", "variant", "status") and not c.startswith("_")]
    weights = {c: {} for c in columns}
    allowed = weights["_allowed"] = {}  # warianty, z których wolno losować (gdy brak wag)
    for row in rows:
        status = row["status"].strip()
        if status == "rejected" or (approved_only and status not in ("approved", "-")):
            continue
        allowed.setdefault(row["pool"], []).append(row["variant"])
        for column in columns:
            cell = row[column].strip()
            if cell:
                # arkusz w polskim formacie eksportuje ułamki z przecinkiem ("3,5")
                weights[column].setdefault(row["pool"], {})[row["variant"]] = float(cell.replace(",", "."))
    return weights


def pick_weights(profile, base, key, allowed):
    for table in (profile.get(key), base.get(key)):
        if table and any(w > 0 for w in table.values()):
            return table
    if not allowed:
        raise ValueError(f"pula {key}: brak elementów do losowania (nic nie zatwierdzono?)")
    return {v: 1 for v in allowed}


def load_nationalities():
    """data/nationalities.csv (zakładka nationalities arkusza danych): {id: {pochodzenie: waga}}.
    Kolumna origins: "western_europe:5|west_africa:3" albo samo "east_asia" (waga 1)."""
    nations = {}
    with open(NATIONS_CSV, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            origins = {}
            for part in filter(None, (x.strip() for x in row["origins"].split("|"))):
                name, _, weight = part.partition(":")
                origins[name.strip()] = float(weight.replace(",", ".")) if weight else 1.0
            nations[row["id"]] = origins
    return nations


def nationality_look(nation, rng, weights, palettes, nations):
    """Wygląd zawodnika danej narodowości: losowe pochodzenie z wag narodowości, potem random_look."""
    origin = weighted(rng, nations[nation])
    if origin not in weights:
        raise ValueError(f"narodowość {nation}: pochodzenie {origin} nie ma kolumny w arkuszu wag portretów")
    return random_look(origin, rng, weights, palettes), origin


def random_look(region, rng, weights, palettes):
    """Wygląd zawodnika z wag regionu. Pula bez wag w regionie -> wagi z 'any' -> równo."""
    profile, base, allowed = weights.get(region, {}), weights["any"], weights["_allowed"]
    look = {}
    for pool in list(parts.POOLS) + list(parts.COLOR_POOLS):
        look[pool] = weighted(rng, pick_weights(profile, base, pool, allowed.get(pool)))
    return look


# ───────────────────────── arkusze podglądu ─────────────────────────

def label(draw, xy, text, size=14, color=TEXT, bold=False):
    draw.text(xy, text, fill=color, font=font(size, bold))


def tile(canvas, img, x, y, pad=4):
    ImageDraw.Draw(canvas).rectangle([x - pad, y - pad, x + img.width + pad - 1, y + img.height + pad - 1], fill=TILE)
    canvas.alpha_composite(img, (x, y))


def ghost(full, layer_img, alpha=90):
    """Warstwa na tle półprzezroczystego całego portretu (żeby było widać, gdzie leży)."""
    g = full.copy()
    g.putalpha(g.getchannel("A").point(lambda a: alpha if a else 0))
    g.alpha_composite(layer_img)
    return g


def palette_strip(draw, x, y, pal, prefixes):
    for row, (title, prefix) in enumerate(prefixes):
        label(draw, (x, y + row * 22 + 2), title, 12, MUTED)
        roles = [r for r in pal if r.startswith(prefix)]
        seen = []
        for r in roles:
            if pal[r] not in seen:
                seen.append(pal[r])
        for i, c in enumerate(seen):
            draw.rectangle([x + 70 + i * 22, y + row * 22, x + 70 + i * 22 + 18, y + row * 22 + 18], fill=c)


def player_sheet(player, style_id, palettes):
    look, team = player["look"], player["team"]
    full = {n: render(look, style_id, n, palettes, team) for n in core.SIZES}
    style = core.STYLES[style_id]
    shown = [(name, i) for i, (name, img) in enumerate(full[32][1]) if img.getbbox()]
    col_w = 150
    W = max(860, 30 + col_w * len(shown))
    H = 820
    sheet = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    label(d, (24, 16), f"{player['name']}  ·  styl {style['label']}", 24, bold=True)
    label(d, (24, 50), f"region: {player['region']}   ·   {style['about']}", 14, MUTED)

    # Całość: rozmiar 1:1 i powiększenia.
    x = 30
    for n, k in ((32, 8), (64, 4)):
        tile(sheet, scaled(full[n][0], k), x, 100)
        label(d, (x, 100 + 256 + 10), f"{n}×{n}  (×{k})", 14)
        x += 256 + 30
    # Rozmiar rzeczywisty (1:1) i ×2 – tak mniej więcej wyglądają w grze (1080p / 1440p).
    y = 100
    for n in core.SIZES:
        tile(sheet, full[n][0], x, y)
        tile(sheet, scaled(full[n][0], 2), x + n + 16, y)
        label(d, (x + 3 * n + 30, y + n - 8), f"{n} px: 1:1 i ×2", 12, MUTED)
        y += 2 * n + 16

    pal = player_palette(style_id, palettes, look, team)
    palette_strip(d, x, y + 4, pal, [("skóra", "skin."), ("włosy", "hair."), ("oczy", "eye."),
                                      ("koszulka", "shirt.")])

    # Rozbicie na części.
    y0 = 420
    label(d, (24, y0), "Części (każda to osobny szablon; tło = cały portret dla orientacji)", 16, bold=True)
    for col, (name, i) in enumerate(shown):
        cx = 30 + col * col_w
        variant = parts.layer_variant(look, name)
        label(d, (cx, y0 + 30), parts.POOL_LABELS.get(name, name), 13, bold=True)
        label(d, (cx, y0 + 48), variant + (f" @{look['head']}" if name in parts.FITTED else ""), 12, MUTED)
        tile(sheet, scaled(ghost(full[32][0], full[32][1][i][1]), 4), cx, y0 + 74)
        tile(sheet, scaled(ghost(full[64][0], full[64][1][i][1]), 2), cx, y0 + 74 + 140)
    label(d, (24, y0 + 74 + 140 + 134), "górny rząd: 32×32 (×4) · dolny rząd: 64×64 (×2)", 12, MUTED)
    return sheet


def style_matrix(players, palettes):
    styles = list(core.STYLES)
    cell_w, cell_h = 370, 190
    W, H = 220 + cell_w * len(styles), 90 + cell_h * len(players)
    sheet = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    label(d, (24, 16), "Porównanie stylów: ci sami zawodnicy, 32×32 (×4) i 64×64 (×2), obok 1:1", 20, bold=True)
    for c, sid in enumerate(styles):
        label(d, (220 + c * cell_w, 52), core.STYLES[sid]["label"], 15, bold=True)
    for r, pl in enumerate(players):
        y = 90 + r * cell_h
        label(d, (24, y + 50), pl["name"], 15, bold=True)
        label(d, (24, y + 72), pl["region"], 12, MUTED)
        label(d, (24, y + 90), f"własny styl: {pl['style']}", 12, MUTED)
        for c, sid in enumerate(styles):
            x = 220 + c * cell_w
            im32 = render(pl["look"], sid, 32, palettes, pl["team"])[0]
            im64 = render(pl["look"], sid, 64, palettes, pl["team"])[0]
            tile(sheet, scaled(im32, 4), x, y)
            tile(sheet, scaled(im64, 2), x + 140, y)
            tile(sheet, im32, x + 284, y)
            tile(sheet, im64, x + 284, y + 44)
            if sid == pl["style"]:
                d.rectangle([x - 8, y - 8, x + 356, y + 136], outline=(227, 180, 61), width=2)
    return sheet


BASE_LOOK = {"head": "oval", "eyes": "normal", "brows": "straight", "nose": "small", "mouth": "neutral",
             "hair": "short", "facial_hair": "none", "marks": "none", "extras": "none",
             "skin": "light", "hair_color": "brown", "eye_color": "blue", "accessory": "gold"}
NEUTRAL_TEAM = {"shirt": "#5d6b7a", "trim": "#d9d4c7"}


def parts_sheet(style_id, palettes):
    pools = list(parts.POOLS)
    cell_w, row_h = 214, 190
    W = 200 + cell_w * max(len(v) for v in parts.POOLS.values())
    H = 80 + row_h * len(pools)
    sheet = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    label(d, (24, 16), f"Pule części – styl {core.STYLES[style_id]['label']}", 22, bold=True)
    label(d, (24, 48), "każdy wariant na tej samej bazowej twarzy · 64×64 (×2) i 32×32 (×2)", 13, MUTED)
    for r, pool in enumerate(pools):
        y = 84 + r * row_h
        label(d, (24, y + 50), parts.POOL_LABELS[pool], 15, bold=True)
        label(d, (24, y + 72), f"{len(parts.POOLS[pool])} wariantów", 12, MUTED)
        for c, variant in enumerate(parts.POOLS[pool]):
            look = dict(BASE_LOOK, **{pool: variant})
            if pool == "extras" and variant == "headband":
                look["accessory"] = "red"
            x = 200 + c * cell_w
            tile(sheet, scaled(render(look, style_id, 64, palettes, NEUTRAL_TEAM)[0], 2), x, y)
            tile(sheet, scaled(render(look, style_id, 32, palettes, NEUTRAL_TEAM)[0], 2), x + 136, y)
            label(d, (x, y + 134), variant, 13)
    return sheet


def random_sheet(regions_list, count, seed, style_id, palettes, regions, nations=None):
    """Wiersz na region albo (z nations) na narodowość; seed + nazwa wiersza => zawsze ci sami zawodnicy."""
    cell = 140
    W, H = 220 + cell * count, 70 + 150 * len(regions_list)
    sheet = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    kind = "narodowości" if nations else "regionu"
    label(d, (24, 16), f"Losowy wygląd wg {kind} (seed {seed}) · styl {core.STYLES[style_id]['label']} · 64×64 (×2)",
          18, bold=True)
    teams = [{"shirt": "#b8322a", "trim": "#f2efe6"}, {"shirt": "#2f5fb3", "trim": "#f2efe6"},
             {"shirt": "#e6b422", "trim": "#1f6b3a"}, {"shirt": "#2e2e33", "trim": "#e04e8a"}]
    for r, region in enumerate(regions_list):
        rng = random.Random(f"{seed}:{region}")
        y = 64 + r * 150
        label(d, (24, y + 54), region, 14, bold=True)
        for i in range(count):
            if nations:
                look, origin = nationality_look(region, rng, regions, palettes, nations)
            else:
                look, origin = random_look(region, rng, regions, palettes), None
            img = render(look, style_id, 64, palettes, teams[i % len(teams)])[0]
            tile(sheet, scaled(img, 2), 220 + i * cell, y)
            if origin and len(nations[region]) > 1:
                label(d, (220 + i * cell, y + 132), origin, 10, MUTED)
    return sheet


# ───────────────────────── eksport do gry ─────────────────────────

def export(style_id, out_dir, palettes):
    """Szablony tylko zatwierdzonych elementów (status approved; 'none' = brak pliku) + obie koszulki,
    oraz manifest.json ze wszystkim, czego gra potrzebuje do losowania wyglądu i przekolorowania części.
    Stare pliki eksportu (np. element, który stracił zatwierdzenie) są usuwane."""
    import json
    out_dir = Path(out_dir) / style_id
    default = core.default_palette(style_id, palettes)
    check_template_palette(style_id, default)
    style = core.STYLES[style_id]
    weights = load_weights(approved_only=True)
    allowed = weights.pop("_allowed")
    # Warianty w kolejności POOLS (= kolejność w arkuszu nie ma znaczenia dla gry).
    variants = {pool: [v for v in options if v in allowed.get(pool, [])] for pool, options in parts.POOLS.items()}
    colors = {pool: [k for k in palettes[src] if k in allowed.get(pool, [])]
              for pool, src in parts.COLOR_POOLS.items()}
    for pool, options in list(variants.items()) + list(colors.items()):
        if not options:
            raise ValueError(f"pula {pool}: brak zatwierdzonych elementów – gra nie ma z czego losować")
    heads = variants["head"]

    written = set()
    for n in core.SIZES:
        for layer in parts.LAYER_ORDER:
            pool = "hair" if layer == "hair_back" else layer
            layer_variants = parts.SHIRTS if layer == "shirt" else variants[pool]
            layer_heads = heads if layer in parts.FITTED else heads[:1]
            for variant in layer_variants:
                for head in layer_heads:
                    look = dict(BASE_LOOK, head=head)
                    if pool in parts.POOLS:
                        look[pool] = variant
                    if layer == "shirt":
                        look["kit"] = variant
                    layers = dict(build_layers(look, style_id, n, palettes))
                    if not layers[layer]:
                        continue  # pusta część (np. brak zarostu): brak pliku = nic nie rysuj
                    img = core.to_image(layers[layer], n, default)
                    rel = part_file(layer, variant, head, n)
                    path = out_dir / rel
                    path.parent.mkdir(parents=True, exist_ok=True)
                    img.save(path)
                    written.add(rel)
    removed = 0
    if out_dir.exists():
        for old in out_dir.rglob("*.png"):
            if old.relative_to(out_dir).as_posix() not in written:
                old.unlink()
                Path(str(old) + ".import").unlink(missing_ok=True)
                removed += 1

    canon = lambda r: style["collapse"].get(r, r)
    derived = [list(d) for d in core.DERIVED]
    if style["outline"]["mode"] != "black":
        derived.append(list(core.SELOUT_OUTLINE))
    fixed = dict(core.FIXED)
    if style["outline"]["mode"] == "black":
        fixed["fix.outline"] = style["outline"]["color"]
    manifest = {
        "style": style_id,
        "sizes": list(core.SIZES),
        "layer_order": parts.LAYER_ORDER,
        "fitted_to_head": sorted(parts.FITTED),
        "file_pattern": "<layer>/<variant>[@<head>]_<size>.png (brak pliku = pusta część)",
        "files": sorted(written),
        # Pule wyglądu w kolejności losowania (random_look): części, potem kolory. Tylko zatwierdzone warianty.
        "look_pools": list(parts.POOLS) + list(parts.COLOR_POOLS),
        "pools": variants,
        "color_pools": colors,
        "shirts": parts.SHIRTS,
        # Wagi tylko zatwierdzonych elementów: {kolumna: {pula: {wariant: waga}}}; pula bez wag w kolumnie
        # bierze "any", a bez wag w "any" – równo z allowed.
        "weights": weights,
        "allowed": allowed,
        "nationalities": load_nationalities(),
        # Kolor szablonu -> rola (role zwinięte przez collapse mają ten sam kolor i ten sam kolor zawodnika).
        "template_palette": default,
        "template_colors": {color: canon(role) for role, color in reversed(list(default.items()))},
        # Rampy kolorów wyglądu przed collapse (gra stosuje collapse na końcu, jak resolve_palette).
        "palettes": {
            pool: {key: core.make_ramp(group, palettes[src][key], style) for key in colors[pool]}
            for pool, src, group in (("skin", "skin", "skin"), ("hair_color", "hair", "hair"),
                                     ("eye_color", "eyes", "eye"), ("accessory", "accessory", "acc"))
        },
        "palette_groups": {"skin": "skin", "hair_color": "hair", "eye_color": "eye", "accessory": "acc"},
        "team_ramp": {"shirt": core.RAMPS["shirt"], "trim": core.RAMPS["trim"],
                      "contrast": style["contrast"], "hue_shift": style["hue_shift"],
                      "saturation": style["saturation"]},
        # [rola, A, B, t] = mix(A, B, t), A/B = rola albo "#hex"; liczone po rampach, w tej kolejności.
        "derived_roles": derived,
        "fixed_roles": fixed,
        "collapse": style["collapse"],
    }
    with open(out_dir / "manifest.json", "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)
    return out_dir, len(written), removed


def check_template_palette(style_id, default):
    """Szablony rozpoznają role po kolorze, więc dwie role o tym samym kolorze w palecie domyślnej muszą
    być aliasami (collapse) – inaczej gra nie odróżni np. cienia skóry od koloru włosów."""
    collapse = core.STYLES[style_id]["collapse"]
    canon = lambda r: collapse.get(r, r)
    seen = {}
    for role, color in default.items():
        other = seen.setdefault(color, role)
        if canon(other) != canon(role) and default[canon(other)] == default[canon(role)]:
            if not (role.startswith("fix.") or other.startswith("fix.")):
                raise ValueError(f"styl {style_id}: role {other} i {role} mają ten sam kolor szablonu {color}"
                                 " – zmień kolory 'default' w palettes.json")


# ───────────────────────── CLI ─────────────────────────

def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd")
    p_demo = sub.add_parser("demo")
    p_demo.add_argument("--out", default=str(DEFAULT_PREVIEW_DIR))
    p_rand = sub.add_parser("random")
    p_rand.add_argument("--region", action="append")
    p_rand.add_argument("--nationality", action="append", help="kod z data/nationalities.csv, np. POL")
    p_rand.add_argument("--count", type=int, default=8)
    p_rand.add_argument("--seed", type=int, default=1)
    p_rand.add_argument("--style", default=DEFAULT_STYLE, choices=list(core.STYLES))
    p_rand.add_argument("--approved", action="store_true", help="tylko elementy zatwierdzone w przeglądzie")
    p_rand.add_argument("--out", default=str(DEFAULT_PREVIEW_DIR))
    p_exp = sub.add_parser("export")
    p_exp.add_argument("--style", default=DEFAULT_STYLE, choices=list(core.STYLES))
    p_exp.add_argument("--out", default=str(DEFAULT_EXPORT_DIR))
    args = ap.parse_args(argv)

    palettes = core.load_json("palettes.json")
    regions = load_weights(getattr(args, "approved", False))
    cmd = args.cmd or "demo"
    if cmd == "demo":
        out = Path(getattr(args, "out", DEFAULT_PREVIEW_DIR))
        out.mkdir(parents=True, exist_ok=True)
        players = core.load_json("test_players.json")["players"]
        for pl in players:
            path = out / f"zawodnik_{pl['id']}_{pl['style']}.png"
            player_sheet(pl, pl["style"], palettes).save(path)
            for n in core.SIZES:
                render(pl["look"], pl["style"], n, palettes, pl["team"])[0].save(out / f"{pl['id']}_{n}.png")
            print(path)
        style_matrix(players, palettes).save(out / "porownanie_stylow.png")
        for sid in core.STYLES:
            parts_sheet(sid, palettes).save(out / f"czesci_{sid}.png")
        all_regions = [r for r in regions if r not in ("any", "_allowed")]
        random_sheet(all_regions, 8, 1, DEFAULT_STYLE, palettes, regions).save(out / "losowi_wg_regionow.png")
        print(out)
    elif cmd == "random":
        out = Path(args.out)
        out.mkdir(parents=True, exist_ok=True)
        if args.nationality:
            path = out / f"losowi_narodowosci_seed{args.seed}.png"
            random_sheet(args.nationality, args.count, args.seed, args.style, palettes, regions,
                         load_nationalities()).save(path)
        else:
            regs = args.region or [r for r in regions if r not in ("any", "_allowed")]
            path = out / f"losowi_{args.style}_seed{args.seed}.png"
            random_sheet(regs, args.count, args.seed, args.style, palettes, regions).save(path)
        print(path)
    elif cmd == "export":
        out_dir, count, removed = export(args.style, args.out, palettes)
        print(f"templates: {count} -> {out_dir}" + (f" (removed {removed} stale)" if removed else ""))


if __name__ == "__main__":
    main(sys.argv[1:])
