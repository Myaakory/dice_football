# Generator części portretów zawodników

To narzędzie deweloperskie (Python + Pillow): rysuje części portretów w **32×32** (boisko) i **64×64**
(karta zawodnika) i eksportuje je jako szablony PNG do wgrania do gry. Gra nie rysuje twarzy sama. Składa
portret z gotowych części i podmienia w nich kolory na kolory zawodnika i drużyny.

```
python tools/portraits/portrait_tool.py demo                 # podglądy -> grafiki_brudnopis/portrety/
python tools/portraits/portrait_tool.py random --region west_africa --count 12 --seed 7 --style retro
python tools/portraits/portrait_tool.py export              # zatwierdzone szablony + manifest -> assets/graphics/portraits/retro/
python tools/portraits/portrait_review.py                    # katalog do artefaktu "Przegląd portretów"
python tools/sync_sheets.py --portraits                      # wagi losowania z arkusza -> data/portrait_weights.csv
```

## Pliki

| Plik | Zawartość |
|---|---|
| `portrait_parts.py` | pule części (`POOLS`) i ich rysowanie, kolejność warstw (`LAYER_ORDER`) |
| `portrait_core.py` | rampy kolorów, **style** (`STYLES`), kontur, składanie, PNG ↔ mapa ról |
| `palettes.json` | pule kolorów: skóra, włosy, oczy, dodatki; `default` = kolory szablonów |
| `data/portrait_weights.csv` | wagi losowania i status przeglądu każdego elementu (z arkusza, nie edytować ręcznie) |
| `portrait_review.py`, `review/` | katalog do przeglądu, strona artefaktu, wersje i historia elementów |
| `test_players.json` | testowi zawodnicy (wygląd podany ręcznie) |
| `overrides/<styl>/…` | ręcznie poprawione części (opcjonalne, patrz niżej) |

## Jak to działa

- **Wygląd zawodnika** to kilka kluczy: `head, eyes, brows, nose, mouth, hair, facial_hair, marks` (warianty
  z pul) oraz `skin, hair_color, eye_color, accessory` (klucze z palet). W zapisie gry wystarczą indeksy
  (kilka bajtów na zawodnika), a obrazków per zawodnik nie trzeba trzymać (`docs/architecture/world_scale.md`).
- **Koszulka nie należy do wyglądu.** Zawodnik zabiera ze sobą tylko swój wygląd; koszulkę (warstwa `shirt`)
  koloruje się przy rysowaniu barwami klubu, w którym aktualnie gra (`primary_color` / `secondary_color` drużyny).
  Po transferze ten sam zawodnik od razu wygląda tak samo, tylko w nowej koszulce. Koszulka ma dwa warianty:
  `field` (dekolt w serek) i `goalkeeper` (okrągły kołnierz + pas na piersi, jak koszulka bramkarza na boisku).
  Bramkarz dostaje `goalkeeper` w **bramkarskich barwach klubu** (`render(..., team={"shirt", "trim",
  "kit": "goalkeeper"})`; w grze `TeamData.gk_primary_color` / `gk_secondary_color`).
- **Warstwy** w kolejności rysowania: `hair_back, head, shirt, eyes, brows, nose, facial_hair, mouth, hair,
  marks`. Każda warstwa to osobny PNG, a składanie to zwykłe nakładanie (alpha).
- **Części dopasowane do głowy** (`hair`, `hair_back`, `facial_hair`, `marks`) istnieją w wersji dla każdego
  kształtu głowy: plik `hair/short@square_32.png`. Oczy, brwi, nos i usta leżą zawsze w tym samym miejscu.
- **Kolory przez role.** Szablony są narysowane kolorami palety domyślnej. Każdy kolor oznacza rolę
  (`skin.shade`, `hair.base`, `shirt.light`…). Gra podmienia role na rampę zawodnika. Gotowe rampy każdego
  koloru skóry, włosów, oczu i dodatków są w `manifest.json`. Rampę koszulki liczy się z koloru drużyny
  (parametry w `team_ramp`), a role mieszane (`mix.stubble` itd.) liczy się wzorami z `derived_roles`.
- **32 i 64 px przedstawiają tę samą osobę.** Duże kształty (głowa, włosy, zarost, koszulka) są opisane raz,
  w przestrzeni 32×32, i próbkowane w obu rozdzielczościach. Drobne rysy (oczy, brwi, nos, usta) to ręczne
  siatki znaków osobno dla 32 i 64 px (`FEATURES` w `portrait_parts.py`).

## Style

| Id | Opis |
|---|---|
| `retro` | A – klasyczny 16-bit: czarny kontur, 3 odcienie, białka oczu |
| `soft` | B – miękki: kontur w ciemniejszym odcieniu sąsiedniego koloru, 5 odcieni, blask |
| `bold` | C – graficzny: gruby kontur (2 px w 64), 2 odcienie, twardy cień na pół twarzy, oczy-kropki |

**Wybrany styl: `retro`** (domyślny we wszystkich komendach). Nowe części powstają i są sprawdzane tylko w nim;
`soft` i `bold` zostają w kodzie do porównań i mogą z czasem się rozjechać.

Styl to zestaw parametrów (kontrast i przesunięcie odcienia ramp, rodzaj konturu, sposób cieniowania, rozmiar
głowy, własne siatki oczu). Ten sam wygląd można więc wyrenderować w każdym stylu: `porownanie_stylow.png`.

## Dodawanie i poprawianie części

- **Nowy wariant:** dopisz nazwę do `POOLS` i obsłuż ją w funkcji rysującej (kształty) albo w `FEATURES`
  (siatki 32 i 64 px). Potem dodaj wiersz w arkuszu wag (status `pending`) i wygeneruj katalog przeglądu.
- **Nowy kolor:** dopisz wpis w `palettes.json`. Odcienie liczy styl. Gdy wyliczone odcienie nie pasują,
  podaj je ręcznie: `{"base": "#…", "shade": "#…"}`.
- **Ręczne poprawki w Aseprite:** weź plik z eksportu, popraw go **tylko kolorami z tego pliku / palety
  szablonów** i zapisz jako `tools/portraits/overrides/<styl>/<warstwa>/<nazwa>.png`. Podglądy i kolejne
  eksporty użyją wersji ręcznej zamiast rysowanej kodem. Nieznany kolor kończy się błędem z pozycją piksela.

## Przegląd i zatwierdzanie elementów

Każdy element (wariant części albo kolor) przechodzi przegląd w artefakcie **Przegląd portretów**
(https://claude.ai/artifact/EUr8EdjDAz47rKVQadmmg1): element na 6 różnych twarzach w 64 i 32 px, przyciski
Zatwierdź / Do poprawki / Odrzuć i pole uwagi. Oceny trzyma baza artefaktu (kolekcja `reviews`, dokument = id
elementu, np. `hair.curly`: `status`, `comment`, `version` ocenionej wersji); `_general` to uwagi ogólne.

Cykl partii:
1. Nowe lub poprawione elementy → `python tools/portraits/portrait_review.py [--batch N]`. Wersja rośnie sama,
   gdy zmienią się piksele elementu; opis zmiany wpisuje się przedtem do `review/notes.json`.
2. Publikacja strony z nowym `catalog.json` (ten sam artefakt). Element w nowej wersji ma stan „Nowa wersja”,
   a poprzednia uwaga zostaje widoczna.
3. Claude czyta oceny z bazy (`ArtifactData list reviews`), poprawia elementy z uwagami i przepisuje stan
   (`approved` / `changes` / `rejected`) do kolumny `status` arkusza wag.
4. `python tools/sync_sheets.py --portraits` → `data/portrait_weights.csv`.

Arkusz **portraits_weights_dice_football**, zakładka `portrait_weights`: wiersz = element, kolumny `any` i regiony
= wagi losowania. Pusta komórka = brak wagi; region bez żadnej wagi w danej puli bierze kolumnę `any`.
Szansa elementu = jego waga / suma wag puli (kolumna `_chance_any` liczy ją formułą dla `any`). Pule z wariantem
`none` (zarost, znaki szczególne, dodatki) mają w nim szansę „brak”: np. waga `extras.none` decyduje, jak często
zawodnik nie ma żadnego dodatku (kolczyk, opaska). Znaki i dodatki to osobne pule – blizna nie wyklucza kolczyka.
Odrzuconych elementów generator nie losuje nigdy, a gra (i `random --approved`) – tylko zatwierdzone.
Wygodna wielkość partii: 8–12 elementów jednego rodzaju (np. 8 fryzur albo komplet oczu i nosów) – tyle da się
narysować, sprawdzić we wszystkich kształtach głowy i ocenić za jednym razem.

## Narodowości i pochodzenie

Zakładka `nationalities` arkusza danych gry (→ `data/nationalities.csv`, nazwy przez klucze `NATION_<ID>` w arkuszu
tekstów): `id` (kod FIFA, np. `POL`), `name_key`, `origins` – pochodzenie wyglądu z wagami, np.
`western_europe:5|west_africa:3|north_africa:2` (samo `east_asia` = waga 1). Każde pochodzenie to kolumna arkusza
wag portretów (`northern_europe`, `western_europe`, `eastern_europe`, `southern_europe`, `south_america`,
`west_africa`, `north_africa`, `east_asia`, `middle_east`).

Wygląd zawodnika danej narodowości: najpierw losowane jest pochodzenie (wagi narodowości), potem każda pula z wag
tego pochodzenia. Wszystko z jednego generatora liczb z seeda, więc ten sam seed daje tych samych zawodników:
`python tools/portraits/portrait_tool.py random --approved --nationality POL --nationality BRA --seed 4`.
W grze te same kroki robi `PortraitLooks` (niżej) – na tych samych wagach, ale z generatorem liczb Godota, więc
ten sam seed daje w grze inny wygląd niż w Pythonie (rozkład jest ten sam).

## Gra (integracja)

1. `python tools/portraits/portrait_tool.py export` zapisuje do `assets/graphics/portraits/retro/` **tylko zatwierdzone**
   elementy (status `approved`; warianty `none` = brak pliku) i zawsze obie koszulki; pliki, które straciły
   zatwierdzenie, usuwa. `manifest.json` zawiera: listę plików, pule i kolejność losowania (`look_pools`), wagi
   zatwierdzonych elementów per kolumna (`weights`, `allowed`), narodowości, oraz wszystko do przekolorowania:
   `template_colors` (kolor szablonu → rola), rampy kolorów wyglądu (`palettes`), `team_ramp`, `derived_roles`
   (`[rola, A, B, t]` – to samo `DERIVED` z `portrait_core.py`), `fixed_roles`, `collapse`, `layer_order`, `fitted_to_head`.
   Potem import w Godot (`--headless --path . --import`): PNG bez kompresji stratnej i bez mipmap, jak reszta pixel artu.
2. `PortraitComposer` (`scripts/portraits/portrait_composer.gd`) ładuje manifest i szablony raz, liczy paletę zawodnika
   (dokładny port `shift`/`make_ramp`/`mix`/collapse, z zaokrąglaniem jak `round()` w Pythonie), podmienia role
   i nakłada warstwy. `get_player_texture(player, team, 64, 2)` – karta; 32 = boisko. Bramkarz dostaje koszulkę
   `goalkeeper` w barwach bramkarskich klubu. Pamięć podręczna tylko wyświetlanych portretów (64 sztuki).
3. `PortraitLooks.generate(id, nationality)` – wygląd z hasha id (FNV-1a → `RandomNumberGenerator`), kolumna `any`,
   a z narodowością najpierw pochodzenie. `PlayerData.get_portrait_look()` liczy go przy pierwszym wyświetleniu.
   Wygląd zależy od manifestu: po zmianie zatwierdzeń/wag zawodnicy wylosują się inaczej, dlatego zapis gry
   (gdy powstanie) ma przechowywać `portrait_look` zawodnika.
4. Zgodność z Pythonem: portret złożony w GDScript jest identyczny piksel w piksel z `portrait_tool.render()`
   (sprawdzone na 80 obrazach 32/64 px, w tym bramkarze, i 3000 rampach kolorów drużyny).
