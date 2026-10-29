# Dice Football: instrukcje dla agentów

Taktyczna gra piłkarska (Godot 4.7.2, GDScript). Użytkownik pisze po polsku, więc odpowiadaj po polsku.

## Skala świata: obowiązkowa lektura

Gra docelowo ma ~50 lig × 16 drużyn × 25 graczy (~20 000 graczy), generowanych losowo i śledzonych przez wiele sezonów.
**Przed dodaniem lub zmianą jakiegokolwiek systemu gry przeczytaj [docs/architecture/world_scale.md](docs/architecture/world_scale.md)**
i trzymaj się jego zasad (dane po ID, bez Node'ów per gracz, indeksy zamiast skanowania, binarny zapis z wersją,
poziomy szczegółowości symulacji, agregacja historii) oraz checklisty na końcu.

## Zasady meczu (prototyp)

Robocze zasady meczu v2 („Drabina”: piłka w strefach 1–5, udział ×2 / ×1, tura w dwóch etapach):
[docs/design/match_rules.md](docs/design/match_rules.md). Plan, wymagania użytkownika (W1–W18) i tabela statusu
kroków: [docs/design/match_v2_plan.md](docs/design/match_v2_plan.md) – kroki K1–K7, B1–B6, B5a (perki trenerów) i B8 zrobione, opcjonalne
B7; przed pracą nad meczem sprawdź status i aktualizuj go po kroku. Stary system v1 jest
zarchiwizowany: [docs/design/archive/match_v1_cards.md](docs/design/archive/match_v1_cards.md). Balans (progi kart)
użytkownik stroi ręcznie – Edytor zagrań pokazuje szanse, seria symulacji: `python tools/sim_batch.py`.
Silnik: `scripts/match_sim/` (czyste dane, bez Node'ów). Symulacja AI kontra AI: `scenes/dev/match_sim.tscn`
(instrukcja uruchomienia w dokumencie). Ekran meczu gracz kontra komputer: `scenes/match/` (te same kroki
tury silnika co symulacja – zmiana w `MatchEngine` musi zostawić wyniki symulacji bez zmian albo świadomie je zmienić).
Karty zagrań: `data/plays/plays.json` (wyjątek od zasady arkusza), edytowane w grze: menu główne → Edytor zagrań
(`scenes/play_editor/`); dane obsługuje `PlayLibrary` (`scripts/match_sim/play_library.gd`).

## Rozdzielczość i pixel art

Ekran bazowy 1920×1080, `stretch/mode="canvas_items"`, `aspect="keep"` (stały kadr: inne proporcje = pasy, nie
więcej miejsca). UI i tekst renderują się w natywnej rozdzielczości monitora. Pixel art (boisko, koszulki, kości,
portrety) ma zawsze skalę 1 piksel grafiki = 1 jednostka – nie skaluj sprite'ów niecałkowicie. Każdy węzeł, który
sam rysuje pixel art, wywołuje `PixelArt.apply(self)` (`scripts/utils/pixel_art.gd`, shader „sharp bilinear” dla
skali ×1,33 na 1440p). Steam Deck (1280×800) – później, osobna decyzja.
Boiska nie ma jako jednego PNG: `PitchBuilder` składa je w grze z elementów w `assets/graphics/pitch/parts/`
(jedna trawa 128×128 – pasy to filtr z maską wzoru, krzywe linii, bramki; tnie je `python tools/cut_pitch_parts.py` z
`grafiki_brudnopis/pitch.aseprite`). Geometria (rozmiar, pole gry, strefy) jest w `PitchLayout` – widoki boiska
nie mają własnych stałych rozmiaru; nakładki stref liczy `PitchOverlays`.

## Konwencje

- Identyfikatory i stringi w kodzie po angielsku; tekst dla gracza przez klucze tłumaczeń
  (`localization/translations.csv`, en + pl). Komentarze mogą być po polsku. Tłumaczenia też mają arkusz Google
  jako źródło prawdy (osobny arkusz tekstów, `python tools/sync_sheets.py --translations`) – nie edytuj
  `translations.csv` ręcznie, nowe klucze dopisuj w arkuszu: [localization/README.md](localization/README.md).
- Dane definicji gry: Google Sheet jest źródłem prawdy, a `data/*.csv` się z niego synchronizuje
  (`python tools/sync_sheets.py`, konfiguracja w `tools/sheets_config.json`). Nie edytuj `data/*.csv` ręcznie.
