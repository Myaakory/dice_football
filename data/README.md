# Dane gry (CSV)

Każdy plik to eksport jednej zakładki arkusza Google Sheets `dice_football_database`.
Nazwa zakładki = nazwa pliku bez `.csv`. **Arkusz jest źródłem prawdy – nie edytuj tych plików ręcznie.**
Wyjątek: `plays/plays.json` (karty zagrań) nie pochodzi z arkusza – edytuje się go w grze (Edytor zagrań).

Synchronizacja (arkusz → `data/`): dwuklik `tools/sync_sheets.bat` albo `python tools/sync_sheets.py`
(`--dry-run` pokazuje tylko, co się zmieni). Mapowanie zakładek na pliki jest w `tools/sheets_config.json`
(nowa zakładka = nowy wpis `"nazwa_pliku": gid`, gid to liczba po `#gid=` w adresie zakładki).
Ręcznie: **Plik → Pobierz → CSV** dla każdej zakładki i zmiana nazwy pliku na `<zakładka>.csv`. Pierwszy wiersz to nagłówki kolumn (nie zmieniać nazw).
Wiersze zaczynające się od `#` oraz puste wiersze są pomijane.

Pliki `*.csv.import` (importer `keep`) muszą zostać obok – bez nich Godot potraktuje CSV jako plik tłumaczeń.
Liczby ułamkowe zapisujemy jako liczby całkowite (procenty), żeby polski format `0,5` nie psuł eksportu.
Listy w jednej komórce oddzielamy znakiem `|`, np. `physical|defensive`.

| Plik | Kolumny | Opis |
|---|---|---|
| `attributes.csv` | `id, die_type, name_key, short_key` | Cechy na ściankach kości (siła, podanie, odbiór…). |
| `die_types.csv` | `id, name_key, color, face_1..face_6` | Typy kości; `face_N` = id cechy na ściance N. |
| `positions.csv` | `id, name_key, short_key, preferred_dice` | Pozycje kadrowe (GK/DF/MF/FW) i domyślnie aktywne typy kości. |
| `roles.csv` | `id, name_key, short_key, position` | Role na boisku w taktyce (LB, CB, DM, LW, ST…) i pasująca pozycja kadrowa. |
| `tactics.csv` | `id, name, description_key` | Lista taktyk. |
| `tactic_slots.csv` | `tactic_id, slot, role, lane, x, depth` | 11 pozycji taktyki. `lane` 1–5 (1 = bramkarz i obrońcy, 5 = napastnicy), `x` 0–100 (lewo→prawo), `depth` 0–100 (0 = krawędź pasa bliżej własnej bramki). |
| `teams.csv` | `id, name, short_name, primary_color, secondary_color, default_tactic` | Drużyny. Kolory w formacie `#rrggbb`. |
| `players.csv` | `id, team_id, number, first_name, last_name, position[, nationality, age, natural_roles, secondary_roles]` | Zawodnicy. Kolumny opcjonalne: `nationality` (id z `nationalities.csv`, decyduje też o wyglądzie portretu; brak = nieznana, portret z kolumny `any`), `age` (wiek; brak = „—”), `natural_roles` / `secondary_roles` – role z `roles.csv` oddzielone `\|`, na których zawodnik gra naturalnie / umie zagrać (zielona / żółta kropka na mapie pozycji; brak = naturalne wszystkie role jego `position`). Role wpływają na mecz: `role_fit_natural` / `role_fit_secondary` / `role_fit_none` w `MatchRules`. Skład automatyczny (`Lineup`) dobiera zawodników po `position` w kolejności z tego pliku, więc pierwsi zawodnicy pozycji powinni mieć naturalne role z domyślnej taktyki drużyny. |
| `player_dice.csv` | `player_id, slot, die_type, face_1..face_6` | Kości zawodników (zwykle 3 na zawodnika); `face_N` = liczba punktów na ściance N. |
| `coaches.csv` | `id, team_id, first_name, last_name, risk_percent, perks` | Trenerzy (jeden na drużynę). `risk_percent` – skłonność AI do ryzyka w procentach (100 = neutralny, więcej = ostrożny), `perks` – id perków oddzielone `\|`. |
| `nationalities.csv` | `id, name_key, origins, _notes[, flag]` | Narodowości (`id` = kod FIFA, np. `POL`; nazwa w kluczu `NATION_<ID>`). `origins` – pochodzenie wyglądu portretu z wagami, np. `western_europe:5\|west_africa:3` (`tools/portraits/README.md`). Opcjonalna `flag` – flaga z pasów o równej szerokości: `h:#rrggbb\|#rrggbb\|…` (poziome, od góry) albo `v:#rrggbb\|…` (pionowe, od lewej); powtórzony kolor daje szerszy pas (`h:#d0282e\|#f2c230\|#f2c230\|#d0282e` = Hiszpania 1:2:1); puste = brak flagi. Flagi z krzyżem, godłem lub tarczą są uproszczone do dwóch–trzech pasów w ich kolorach. |
| `perks.csv` | `id, name_key, description_key, relation, side, roles, zones, lane, weight` | Perki trenerów – modyfikatory udziału w meczu (`docs/design/match_rules.md`). `relation`: `action` (pole testu) / `support` (pole sąsiednie) / `passer` / `flyover`; `side`: `attack` / `defense` / puste = obie; `roles` i `zones` (strefy pola testu w perspektywie drużyny trenera, 1 = własne pole karne) – listy `\|`, puste = wszystkie; `lane`: `center` / `wing` / puste = każdy; `weight` – mnożnik (liczba całkowita). |

Teksty widoczne dla gracza są kluczami tłumaczeń (`*_key`) z `res://localization/translations.csv` (kolumny `keys, en, pl`).
Tłumaczenia pochodzą z osobnego arkusza tekstów – patrz `localization/README.md`.
