"""Składa finalne die_icons.png i die_icon_masks.png do gry z wybranych wariantów.

Uruchom z dowolnego katalogu:  python grafiki_brudnopis/propozycje_ikon/system_jasnosci/build_final.py
Wariant 0 = pierwotna ikonka z gry (przemalowana), 1..4 = propozycje A..D z icons_gen.py.
Ikonki 14 px (720p): zapis do _backup_720p. Ikonki gry (20 px, 1080p) generuje tools/gen_dice_graphics.py.
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import icons_gen as ig  # noqa: E402
import recolor as rc  # noqa: E402

DICE_DIR = os.path.normpath(os.path.join(HERE, "..", "..", "..", "_backup_720p", "assets", "graphics", "dice"))

FINAL = {
    "strength": 2,  # B Pięść
    "speed": 0,     # obecna błyskawica
    "jump": 0,      # obecna strzałka w górę
    "pass": 4,      # D Zakręcona strzałka
    "shot": 0,      # obecna piłka
    "control": 2,   # B Podeszwa na piłce
    "tackle": 1,    # A Tarcza (herb)
    "pressing": 0,  # obecny płomień
    "reading": 0,   # obecne oko
}


def main() -> None:
    sheet = Image.new("RGBA", (ig.CELL * len(ig.ORDER), ig.CELL), (0, 0, 0, 0))
    masks = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    for i, skill in enumerate(ig.ORDER):
        icon = rc.render(skill, FINAL[skill])
        sheet.paste(icon, (i * ig.CELL, 0))
        masks.paste(ig.mask_of(icon), (i * ig.CELL, 0))
    sheet.save(os.path.join(DICE_DIR, "die_icons.png"))
    masks.save(os.path.join(DICE_DIR, "die_icon_masks.png"))
    print("zapisano do", DICE_DIR)


if __name__ == "__main__":
    main()
