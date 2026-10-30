"""Katalog elementów portretu do przeglądu w artefakcie "Przegląd portretów".

  python tools/portraits/portrait_review.py [--batch N]

Każdy element (wariant części albo kolor z palety) dostaje obrazek: sam element + ten sam element na 6 różnych
twarzach (różne głowy, karnacje, włosy i koszulki klubów), w 64 px i pod spodem w 32 px, w skali 1:1.
Wersja elementu rośnie sama, gdy zmienią się piksele samego elementu (skrót jego warstw we wszystkich
kształtach głowy i obu rozmiarach; dla koloru – skrót rampy), więc poprawka innej części nie zmienia wersji
już ocenionych elementów. Opis zmiany do nowej wersji wpisuje się wcześniej w review/notes.json
({"id": "co poprawiono"}) – trafia do historii elementu.

Wynik: review/catalog.json (obrazki jako data URI) + review/state.json (wersje, skróty, historia, partia).
Stan ocen (zatwierdzone / do poprawki / odrzucone + uwagi) trzyma baza artefaktu, nie ten plik.
"""

import argparse
import base64
import fnmatch
import hashlib
import io
import json
import sys
from datetime import date

from PIL import Image, ImageDraw

import portrait_core as core
import portrait_parts as parts
import portrait_tool as tool

STYLE = tool.DEFAULT_STYLE
REVIEW_DIR = core.HERE / "review"
CELL, GAP = 64, 4
TILE = (52, 58, 66, 255)

COLOR_POOLS = {"skin": "Kolor skóry", "hair_color": "Kolor włosów", "eye_color": "Kolor oczu",
               "accessory": "Kolor dodatków"}

# Twarze, na których pokazujemy każdy element (element podmienia swoje pole).
CONTEXTS = [
    dict(head="oval", skin="fair", hair_color="blond", eye_color="blue", hair="short",
         team={"shirt": "#b8322a", "trim": "#f2efe6"}),
    dict(head="square", skin="olive", hair_color="black", eye_color="brown", hair="side_part",
         team={"shirt": "#2f5fb3", "trim": "#f2efe6"}),
    dict(head="round", skin="dark", hair_color="black", eye_color="dark_brown", hair="buzz",
         team={"shirt": "#e6b422", "trim": "#1f6b3a"}),
    dict(head="long", skin="light", hair_color="ginger", eye_color="green", hair="short",
         team={"shirt": "#2e2e33", "trim": "#e04e8a"}),
    dict(head="oval", skin="tan", hair_color="dark_brown", eye_color="hazel", hair="curly",
         team={"shirt": "#f2efe6", "trim": "#2f5fb3"}),
    dict(head="square", skin="deep", hair_color="grey", eye_color="dark_brown", hair="bald",
         team={"shirt": "#2e8b57", "trim": "#f2efe6"}),
]
# Bramkarskie barwy klubów (koszulka bramkarza) – po jednej na twarz.
GK_TEAMS = [{"shirt": "#3fae49", "trim": "#1c1c1c"}, {"shirt": "#f07c22", "trim": "#1c1c1c"},
            {"shirt": "#7b4bb5", "trim": "#f2efe6"}, {"shirt": "#d7e04a", "trim": "#2e2e33"},
            {"shirt": "#2e2e33", "trim": "#e6b422"}, {"shirt": "#e04e8a", "trim": "#f2efe6"}]
BASE = dict(eyes="normal", brows="straight", nose="small", mouth="neutral", facial_hair="none", marks="none", extras="none",
            accessory="gold")


def elements(palettes):
    """Wszystkie elementy do oceny: (id, rodzaj, pula, wariant). Warianty "none" nie podlegają ocenie."""
    out = []
    for pool, variants in parts.POOLS.items():
        for v in variants:
            if v != "none":
                out.append((f"{pool}.{v}", "part", pool, v))
    for v in parts.SHIRTS:
        out.append((f"shirt.{v}", "part", "shirt", v))
    for pool in COLOR_POOLS:
        for key in palettes[parts.COLOR_POOLS[pool]]:
            out.append((f"{pool}.{key}", "color", pool, key))
    return out


def context_look(i, pool, variant):
    ctx = dict(CONTEXTS[i])
    team = ctx.pop("team")
    look = dict(BASE, **ctx)
    if pool in look or pool in parts.POOLS:
        look[pool] = variant
    if pool == "accessory":
        look["extras"] = "headband" if i % 2 == 0 else "earring"
    if pool == "shirt":
        team = dict(GK_TEAMS[i] if variant == "goalkeeper" else team, kit=variant)
    return look, team


def isolated(pool, variant, n, palettes):
    """Sam element na półprzezroczystym tle twarzy (część) albo rampa koloru (kolor)."""
    look, team = context_look(0, pool, variant)
    full, layers = tool.render(look, STYLE, n, palettes, team)
    if pool in COLOR_POOLS:
        pal = tool.player_palette(STYLE, palettes, look, team)
        prefix = {"skin": "skin.", "hair_color": "hair.", "eye_color": "eye.", "accessory": "acc."}[pool]
        colors = []
        for role, c in pal.items():
            if role.startswith(prefix) and c not in colors:
                colors.append(c)
        img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        w = n / len(colors)
        for i, c in enumerate(colors):
            d.rectangle([round(i * w), 0, round((i + 1) * w) - 1, n - 1], fill=c)
        return img
    names = {"hair": ("hair", "hair_back")}.get(pool, (pool,))
    picked = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    for name, img in layers:
        if name in names:
            picked.alpha_composite(img)
    return tool.ghost(full, picked, 70)


def element_image(pool, variant, palettes):
    count = 1 + len(CONTEXTS)
    W = GAP + count * (CELL + GAP)
    H = GAP + 64 + GAP + 32 + GAP
    sheet = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(sheet)
    for col in range(count):
        x = GAP + col * (CELL + GAP)
        for n, y in ((64, GAP), (32, GAP + 64 + GAP)):
            d.rectangle([x, y, x + n - 1, y + n - 1], fill=TILE)
            if col == 0:
                img = isolated(pool, variant, n, palettes)
            else:
                look, team = context_look(col - 1, pool, variant)
                img = tool.render(look, STYLE, n, palettes, team)[0]
            sheet.alpha_composite(img, (x, y))
    return sheet


def signature(kind, pool, variant, palettes):
    """Skrót samego elementu: warstwy części (wszystkie głowy dla części dopasowanych, 32 i 64 px) w kolorach
    szablonu albo rampa koloru."""
    h = hashlib.sha1()
    if kind == "color":
        look, team = context_look(0, pool, variant)
        pal = tool.player_palette(STYLE, palettes, look, team)
        prefix = {"skin": "skin.", "hair_color": "hair.", "eye_color": "eye.", "accessory": "acc."}[pool]
        h.update(json.dumps({r: c for r, c in pal.items() if r.startswith(prefix)},
                            sort_keys=True).encode())
        return h.hexdigest()[:10]
    # koszulka: razem z szyją (warstwa head), bo dekolt tworzą obie
    names = {"hair": ("hair", "hair_back"), "shirt": ("shirt", "head")}.get(pool, (pool,))
    heads = parts.POOLS["head"] if pool in parts.FITTED else [tool.BASE_LOOK["head"]]
    for n in core.SIZES:
        for head in heads:
            look = dict(tool.BASE_LOOK, head=head)
            if pool == "shirt":
                look["kit"] = variant
            else:
                look[pool] = variant
            for name, layer in tool.build_layers(look, STYLE, n, palettes):
                if name in names:
                    h.update(f"{name}{n}{head}".encode())
                    h.update(json.dumps(sorted(layer.items())).encode())
    return h.hexdigest()[:10]


def png_bytes(img):
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def load(path, default):
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return default


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--batch", type=int, help="numer partii dla NOWYCH elementów (domyślnie ostatnia)")
    ap.add_argument("--accept", default="", help="wzorce id (po przecinku), których zmiana nie podbija wersji, "
                    "np. zmiana szyi w head.* zrobiona przy poprawce koszulki")
    ap.add_argument("--rename", default="", help="stare=nowe (po przecinku): zmiana id z zachowaniem historii")
    args = ap.parse_args(argv)

    palettes = core.load_json("palettes.json")
    REVIEW_DIR.mkdir(exist_ok=True)
    state_path, notes_path = REVIEW_DIR / "state.json", REVIEW_DIR / "notes.json"
    state = load(state_path, {"elements": {}})
    notes = load(notes_path, {})
    known = state["elements"]
    for pair in filter(None, args.rename.split(",")):
        old, new = pair.split("=")
        known[new] = known.pop(old)
        known[new]["hash"] = None  # przelicz bez podbijania wersji
        args.accept += "," + new
    accept = [a for a in args.accept.split(",") if a]
    batch = args.batch or max([e["batch"] for e in known.values()] or [1])
    # Przejście ze skrótu całego obrazka na skrót samego elementu: przelicz bez podbijania wersji, chyba że
    # element ma opis zmiany w notes.json (wtedy wiadomo, że się zmienił).
    migrate = state.get("hash_kind") != "element"
    state["hash_kind"] = "element"
    today = date.today().isoformat()

    catalog = []
    changed = []
    for eid, kind, pool, variant in elements(palettes):
        data = png_bytes(element_image(pool, variant, palettes))
        digest = signature(kind, pool, variant, palettes)
        entry = known.get(eid)
        if entry is not None and ((migrate and eid not in notes)
                                  or any(fnmatch.fnmatch(eid, a) for a in accept)):
            entry["hash"] = digest
        if entry is None:
            entry = known[eid] = {"batch": batch, "version": 1, "hash": digest,
                                  "history": [{"version": 1, "date": today, "note": notes.pop(eid, "nowy element")}]}
            changed.append(eid)
        elif entry["hash"] != digest:
            entry["version"] += 1
            entry["hash"] = digest
            entry["history"].append({"version": entry["version"], "date": today,
                                     "note": notes.pop(eid, "zmiana wyglądu")})
            changed.append(eid)
        label = COLOR_POOLS.get(pool) or parts.POOL_LABELS.get(pool, pool)
        catalog.append({
            "id": eid, "kind": kind, "pool": pool, "pool_label": label, "variant": variant,
            "batch": entry["batch"], "version": entry["version"], "history": entry["history"],
            "fitted": pool in parts.FITTED,
            "image": "data:image/png;base64," + base64.b64encode(data).decode("ascii"),
        })
    gone = sorted(set(known) - {e["id"] for e in catalog})
    out = {"style": STYLE, "generated": today, "contexts": len(CONTEXTS), "elements": catalog, "removed": gone}
    (REVIEW_DIR / "catalog.json").write_text(json.dumps(out, ensure_ascii=False), encoding="utf-8")
    state_path.write_text(json.dumps(state, ensure_ascii=False, indent=1), encoding="utf-8")
    notes_path.write_text(json.dumps(notes, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"elements: {len(catalog)}, new or changed: {len(changed)}")
    for eid in changed:
        print("  ", eid, "v" + str(known[eid]["version"]))
    if notes:
        print("unused notes (no visual change):", ", ".join(notes))


if __name__ == "__main__":
    main(sys.argv[1:])
