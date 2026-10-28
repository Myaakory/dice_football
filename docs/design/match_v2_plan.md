# Mecz v2: uproszczenie systemu zagrań – propozycje i plan wdrożenia

Stan: 2026-10-28. Poprzedni system (v1, karty na siatce 3 × 5) jest zarchiwizowany:
[archive/match_v1_cards.md](archive/match_v1_cards.md) (kod w `_archive/match_v1_cards/`).
Makiety propozycji (interaktywne): `docs/design/mockups/match_v2_proposals.html`, opublikowane jako artefakt
https://claude.ai/artifact/8qHZvxQ4DW3uSNorMn83YC.

## Dla agenta, który przejmuje pracę

1. Przeczytaj ten plik, [match_rules.md](match_rules.md) i [../architecture/world_scale.md](../architecture/world_scale.md).
2. Znajdź w tabeli **Status** pierwszy krok `[ ]` w wybranej ścieżce. Jeden krok = jedna sesja pracy; po kroku gra
   musi się uruchamiać, a symulacja przechodzić.
3. Po kroku: zaznacz `[x]`, dopisz datę i jedno zdanie, co zrobiono / co zostało (kolumna „Notatka”).
4. Kontrola po każdym kroku:
   - `Godot_v4.7.2-stable_win64_console.exe --headless --path . --import` (po nowych `class_name` i tłumaczeniach),
   - `... --headless --path . res://scenes/dev/match_sim.tscn -- matches=200 seed=1` – zapisz gole / strzały / wyniki
     w notatce kroku (od kroku K1 wyniki świadomie różnią się od archiwum v1),
   - zrzut ekranu meczu: `Godot_v4.7.2-stable_win64_console.exe --path . -s res://tools/match_screenshot.gd -- --windowed turns=6 stage=roll out=<plik>.png`
     (`stage=choose` – wybór zagrania; skrypt sam rozgrywa tury za gracza). Wygląd oceniamy na zrzutach z gry (W11).
5. Teksty dla gracza tylko przez `localization/translations.csv` (en + pl). Identyfikatory po angielsku.

## Wymagania użytkownika (2026-10-28)

| # | Wymaganie |
|---|---|
| W1 | Na boisku nie klika się nic w związku z zagraniem. Zagranie wybiera się na jego kafelku: 1. klik = zaznaczenie i podgląd na boisku, 2. klik w zaznaczony kafelek = potwierdzenie. |
| W2 | Zagranie z wyborem strony („którym skrzydłem”): po zaznaczeniu na kafelku pojawiają się przyciski **◀ Lewym / Prawym ▶**; potwierdza się klikiem w przycisk (nie w resztę kafelka). Najechanie na przycisk pokazuje podgląd tej strony na boisku. |
| W3 | Na boisku myszą tylko: przesunięcie zawodnika (jeśli gracz chce) i branie kości / wkładanie jej do miejsca w zagraniu. |
| W4 | Rozważany kierunek: więcej losowości – gracz wybiera zagranie z 3 losowych dla danej wysokości (strefy); gra ma być o dojściu do strefy 5 i strzale, a nie o przerzucaniu piłki z lewej na prawą. |
| W5 | Interfejs dopasowany do 1920 × 1080: 3 kafelki zagrań **pionowe, obok siebie**. |
| W6 | Wyraźnie oddzielone punkty potrzebne do sukcesu **ataku** i do sukcesu **obrony**. |
| W7 | ~~Kości AI na boisku wyraźnie wyblakłe~~ – **zmienione 2026-10-28**: kości obu stron są normalne, ale na boisku leżą naraz kości tylko jednej strony (etapy tury, W12). |
| W8 | Rysunek zagrania schematyczny, ale przyjemniejszy i pokazujący, co się stanie. |
| W9 | Na kafelku lista sukcesów i porażek (co się dzieje przy każdym wyniku). |
| W10 | Oś meczu: pierwsza akcja w 0', o jedną turę więcej w połowie (2 × 16), kafelki kwadratowe (prawie), większa i delikatnie wyróżniona przerwa. |

Uwagi po makietach (2026-10-28, druga runda) – mają pierwszeństwo przed tym, co niżej się z nimi kłóci:

| # | Wymaganie |
|---|---|
| W11 | Makiety i podglądy robimy **na prawdziwym boisku z gry** (układ D, koszulki, nazwiska, kości zawodników, pasek wytrzymałości). Informacje o zawodnikach, ich kościach i dostępnej energii muszą być widoczne – artefakt HTML z 2026-10-28 pokazuje tylko przebieg klikania, nie wygląd. |
| W12 | **Tura w dwóch etapach**. Atakujący: 1) wybiera zagranie, 2) przesuwa zawodnika albo nie, 3) rzuca, 4) przerzuca albo nie, 5) układa kości w miejscach (albo „Ułóż najlepiej”), 6) zatwierdza. Potem obrońca: 1) przesunięcie, 2) rzut, 3) przerzuty, 4) ułożenie, 5) zatwierdzenie. Potem rozstrzygnięcie – na razie podświetla się na karcie wynik, który wszedł w życie. **Na boisku leżą naraz kości tylko jednej strony.** Gdy etap prowadzi komputer, gracz widzi jego kolejne kroki. |
| W13 | Po wyborze zagrania prawa strona ekranu się zmienia: znikają 3 kafelki, zostaje **jedno wybrane zagranie w rozwiniętej formie** (miejsca na kości, progi, wyniki). Później dołożymy tam inne przydatne informacje. |
| W14 | **Sąsiednie pola zostają** jako niezbędny system: kości zawodników z pola akcji liczą się **×2**, z pól sąsiednich (przód, tył, boki – **bez skosów**) **×1**, dalej 0. Wszystkie progi rosną odpowiednio (mniej więcej ×2). Żadnych ułamków. |
| W15 | Mnożniki udziału to **oś progresji**: na teraz jako **perki trenera** (np. „defensywny pomocnik w akcjach obronnych w polu karnym liczy się ×2”), później może znajomość taktyki albo losowo odblokowywane umiejętności zawodników (jak w Football, Tactics & Glory). Szukanie idealnego trenera ma być częścią gry (inspiracje: Golden Lap, Motorsport Manager). |
| W17 | **Test ma miejsce: pole startowe albo docelowe.** Trudność zagrania z pola startowego i trudność odbioru w polu docelowym to osobne testy (nie każde zagranie je ma). Przykład: Laga – przy starcie „siła lub podanie”, przy celu „siła” oraz „przyjęcie”. Udział zawodników w teście liczy się od jego pola. Na ekranie prawa część jest podzielona na 5 pasów na wysokości stref boiska (lekkie przerywane linie przez kolumnę gracza i komputera, pod kartą), a każdy test stoi w pasie strefy, której dotyczy. |
| W18 | (2026-10-28) **Interwencja bramkarza**: każdy strzał ma testy ataku i obrony oraz osobny test bramkarza. Środkowa kolumna ma najwyżej 4 pasy wysokości; ramka bramkarza (inny kolor niż atak i obrona) stoi w środkowym pasie na wysokości obrony: gdy strzela gracz, karta zagrania lekko zsuwa się w dół, a test bramkarza pojawia się u góry; gdy strzela komputer – na dole, na wysokości testów strefy 1. Na razie bramkarz rzuca zwykłymi kośćmi (kości bramkarzy będą przemodelowane). |
| W16 | Rozwinięte zagranie (po wyborze) w trzech kolumnach: **z lewej zawsze miejsca na kości gracza** (najbliżej boiska, gdzie kości się losują – krótka droga wzrokiem), **w środku** karta zagrania (nazwa, rysunek, opis, lista możliwych wyników), **z prawej miejsca na kości komputera** – niezależnie od tego, czy gracz atakuje, czy broni. |

## Wspólny fundament (wszystkie propozycje)

Zasady upraszczające, które proponuję niezależnie od wybranej ścieżki:

- **Liczby całkowite na ekranie.** Znikają procenty udziału (60% / 30% / 50%) i mnożniki skuteczności w punktach.
  Udział (W14): zawodnik w polu akcji – punkty jego kości **×2**, w polu sąsiednim (przód / tył / bok, bez skosów)
  – **×1**, dalej 0. Kość pokazuje już przemnożone punkty (plakietka „×2”). Progi są odpowiednio wyższe.
  Mnożniki może zmieniać perk trenera (W15). Wyczerpanie: do ustalenia (propozycja: kości liczą się o stopień
  niżej, ×2 → ×1 → 0). Rola decyduje, które kości są aktywne.
- **Jedna decyzja główna na turę** (wybór zagrania), reszta to opcjonalne dźwignie: przesunięcie (energia),
  przerzut (energia), ułożenie kości (z przyciskiem „Ułóż najlepiej”).
- **Trzy rodzaje wyniku** zamiast sześciu slotów: ✔ sukces, ⚔ pojedynek (wygrany / przegrany), ✖ odbiór.
  Odnogi i łańcuchy zdarzeń znikają z v2 (są w archiwum); stałe fragmenty wracają później jako zwykłe zagrania
  z warunkiem `triggers`.
- **Strata piłki = kontra w lustrzanej strefie** (strata w mojej strefie 4 → rywal startuje w swojej 2).

### Przebieg tury v2 (W12, W13)

1. **Wybór zagrania** (strona z piłką): 3 kafelki, klik = podgląd, drugi klik / ◀ ▶ = potwierdzenie.
   Prawa strona zmienia się w **rozwinięte zagranie** (jeden duży kafelek: rysunek, miejsca na kości ATAK i OBRONA,
   progi, lista wyników).
2. **Etap ataku**: przesunięcie zawodnika (opcja, energia) → rzut kości ataku → przerzuty (energia) → ułożenie
   kości w miejscach ataku → „Atakuję” (zatwierdzenie). Suma ataku jest od tej chwili znana obu stronom.
3. **Etap obrony**: przesunięcie zawodnika (opcja) → rzut kości obrony → przerzuty → ułożenie → zatwierdzenie.
   Obrońca wie, ile musi zrobić, więc sam decyduje, czy warto wydać energię.
4. **Rozstrzygnięcie** i wynik z listy zagrania.

Gdy etap prowadzi komputer, każdy jego krok (przesunięcie, rzut, przerzut, ułożenie) jest pokazany z krótką pauzą.
**Decyzja odłożona przez użytkownika (2026-10-28): „mocniejszy atak / obrona” ustali sam później** – do tego czasu etap ma tylko przesunięcie, przerzuty i ułożenie. Pomysły do rozważenia: czym jest „jak mocno atakuję” poza przerzutami i przesunięciem (pomysł: dodatkowa energia
= dołożenie kości zawodnika z pola sąsiedniego albo podbicie mnożnika jednego zawodnika na tę akcję).
Skutek dla AI: obrońca zna wynik ataku, więc liczy szansę warunkową (prościej niż teraz); atakujący musi zakładać
rozkład obrony jak dotąd.

### Kierunek progresji: perki trenera (W15, poza prototypem kroków B)

Perk = reguła zmieniająca mnożnik udziału albo próg w określonej sytuacji, np. „DM w akcjach obronnych w polu
karnym ×2”, „skrzydłowi w polu sąsiednim ×2 przy grze skrzydłem”, „boczni obrońcy wspierają z dwóch pól”.
Model danych od początku przewiduje listę modyfikatorów udziału (`ParticipationModifier`: rola / pozycja, strona
ataku albo obrony, warunek pola, mnożnik), żeby perki dało się dołożyć bez przebudowy silnika. Trener ma 1–3 perki;
szukanie trenera pod taktykę to decyzja menedżerska między meczami.

### Układ ekranu (wspólny szkielet, prawa strona 1100 × 1080)

```
┌ wynik ──────────────────────────────────────────── minuta ┐   ~64 px
├ oś: 16 kwadratów │ PRZERWA │ 16 kwadratów ───────────────┤   ~36 px
├────────────┬────────────┬────────────┐                    │
│ zagranie 1 │ zagranie 2 │ zagranie 3 │  3 × ok. 352 × 600 │
│ (pionowe)  │            │            │                    │
├────────────┴────────────┴────────────┘                    │
├ rozstrzygnięcie: ATAK (ty/komputer) │ OBRONA ─────────────┤   ~150 px
├ pasek decyzji + przyciski ────────────────────────────────┤   ~56 px
└ warunki meczu (jedna linia) ──────────────────────────────┘   ~32 px
```

Kafelek zagrania (od góry): nazwa + ikona rodzaju (podanie, drybling, skrzydło, strzał) → **rysunek** (wycinek
boiska: 3 strefy wokół piłki, trawa w pasy, linie, piłka, łuk lotu do celu, kropki zawodników biorących udział –
swoi pełni, rywale wyblakli) → blok **ATAK** (zielony) i blok **OBRONA** (pomarańczowy), każdy z dużą liczbą
i ikonami cech → **lista wyników** (✔ / ⚔ / ✖ z opisem skutku) → szansa (pasek). Stany: zwykły, najechany,
zaznaczony (złota ramka + przycisk „Zagraj” albo „◀ Lewym / Prawym ▶”), wyszarzony (gdy inny potwierdzony).
Po potwierdzeniu dwa pozostałe kafelki się zwijają, a ich miejsce zajmuje panel miejsc na kości.

Kości na boisku: gracza – pełne kolory, rozmiar 52, poświata koloru drużyny; AI – mały rozmiar 26 (bez skalowania
niecałkowitego), odbarwione do ok. 35% nasycenia, przezroczystość ok. 55%, bez poświaty i bez interakcji.

## Cztery propozycje

### A. „Szlif” – siatka 3 × 5 zostaje, matematyka się upraszcza

- Siatka, talia, ręka 3 kart pasujących do pola piłki jak w v1; wybór strony przyciskami (W2).
- Karta: **jeden test ataku i jeden test obrony** (próg całkowity, 1–2 cechy bez wag, limit 3 kości).
- Udział: pole docelowe 2 kości, pole sąsiednie i podający 1 kość.
- Wynik: macierz v1 zwinięta do trzech wyników (pojedynek przy „oba” i „żaden”; wygrywa wyższa nadwyżka).
- **Plus:** najmniej pracy, zostaje cała geometria. **Minus:** nie rozwiązuje W4 – wciąż opłaca się przerzucać
  piłkę między skrzydłami, a gracz musi rozumieć 15 pól.

### B. „Drabina” – piłka ma tylko wysokość, cel to strefa 5 (rekomendowana)

- Piłka leży w **strefie 1–5**; korytarz przestaje być pozycją piłki.
- Tura: **3 losowe zagrania** z talii taktyki dla bieżącej strefy (W4). Brak kart „zmiana strony”.
- Zagranie ma **kanał**: środek albo skrzydło (wybór ◀ L / P ▶). Strefa docelowa + kanał = **pole akcji** na siatce
  3 × 5. Kto rzuca (W14): zawodnicy z pola akcji ×2, z pól sąsiednich (przód / tył / boki, bez skosów) ×1.
  Siatka 3 × 5 zostaje więc jako mapa udziału, ale piłka nie „wędruje” po korytarzach – zagrania losuje się
  tylko według strefy. Strona boiska ma znaczenie (gdzie moi są mocni, a rywale słabi), ale nie ma ping-ponga.
- Rozstrzygnięcie: **dwa progi** – „Atak potrzebuje X”, „Obrona potrzebuje Y” (W6) – i trzy wyniki; progi
  w skali ×2 / ×1. Tura w dwóch etapach (atak, potem obrona – „Przebieg tury v2”).
  Sukces: +1 strefa (niektóre zagrania +2 przy wyższym progu); w strefach 4–5 karty strzału.
- **Plus:** jasny cel (pasek postępu 1→5), mniej pól do rozumienia, AI prawie bez zmian (te same szanse testów).
  **Minus:** trzeba napisać nowe karty i uprościć edytor.

### C. „Przeciąganie liny” – jedna skala różnicy punktów

- Strefy i losowe zagrania jak w B.
- Obie strony sumują punkty kości pasujących do cech zagrania (do 3 kości), wynik = **atak − obrona** na jednej
  skali. Karta ma dwa progi na skali, np. „obrona wygrywa przy −1 i mniej”, „atak przy +2 i więcej”, pomiędzy
  piłka zostaje; „+5” = awans o 2 albo gol.
- **Plus:** najczytelniejszy wynik (jeden suwak z kolorowymi strefami, wynik widać w sekundę), najprostsze AI.
  **Minus:** ułożenie kości prawie nie jest decyzją (liczą się po prostu 3 najlepsze), mniej „puzzli”.

### D. „Okienka” – kości wkładane w konkretne miejsca zagrania

- Strefy i losowe zagrania jak w B.
- Zagranie ma **2–3 okienka ataku** i **1–3 okienka obrony**; okienko = konkretna cecha i minimum
  (np. [Podanie ≥ 2] [Szybkość] [dowolna techniczna]). Kość pasuje albo nie.
- Próg = **liczba zapełnionych okienek**: „Atak: zapełnij 2 z 3”, „Obrona: zapełnij 1 z 2”. Macierz trzech wyników,
  pojedynek rozstrzyga suma punktów w okienkach.
- **Plus:** najbardziej namacalne (W3: wkładanie kości to serce tury), liczby małe i całkowite.
  **Minus:** najwięcej decyzji w każdej turze (32 tury!), większy kafelek, AI musi rozwiązywać przydział
  (przy ≤ 8 kościach wystarczy pełne przeszukanie).

### Decyzja (2026-10-28)

Użytkownik wybrał **B „Drabina”** jako podwaliny, z uwagami W11–W15 (sąsiednie pola ×2 / ×1, tura w dwóch
etapach, rozwinięte zagranie po wyborze, perki trenera). Ścieżki A, C i D zostają w dokumencie tylko jako
zapis rozważanych wariantów.

Rekomendacja z pierwszej rundy: **B** jako baza. Daje cel z W4 bez utraty sensu skrzydeł, spełnia W6 wprost (dwa progi) i używa większości
obecnego silnika (testy, układanie kości, szanse AI). Jeśli po testach ułożenie kości okaże się „puste”,
okienka z D można dołożyć jako wariant testu (krok B7).

## Plan wdrożenia

Kroki wspólne K1–K3 można robić od razu (nie zależą od wyboru). K4–K5 dotyczą kafelka i rozstrzygnięcia –
treść zależy od wybranej propozycji, więc robi się je po wyborze. Potem kroki ścieżki.

### Kroki wspólne

| Krok | Zakres | Pliki | Gotowe, gdy |
|---|---|---|---|
| K1 | Oś meczu: 2 × 16 tur, minuta = początek tury (0', 3', … 45' / 45', 48', … 90'), kwadratowe kafelki, szersza przerwa z delikatnym tłem i znakiem „P” / „HT” | `match_rules.gd` (`turns_per_half`), `match_engine.gd` (`get_minute`), `match_timeline.gd`, `match.gd` (`_refresh_header`), `match_rules.md` | zrzut pokazuje 0' w 1. turze, 32 kwadraty, wyróżnioną przerwę; sim przechodzi |
| K2 | ~~Kości AI wyblakłe~~ → zastąpione przez K2b | – | – |
| K2b | Tura w dwóch etapach (W12) w silniku i na ekranie: `MatchEngine.roll_side(attacking)`, symulacja przechodzi te same etapy; na boisku kości tylko strony w etapie; po rozstrzygnięciu podświetlony wynik na karcie (`PlayCardView.highlight_outcome`) | `match_engine.gd`, `play_contest.gd`, `match.gd` (`_play_side`), `match_pitch.gd` (`create_dice(contest, attacking)`), `play_card_view.gd` | zrzuty `stage=attack`, `defense`, `result` |
| K3 | Wybór zagrania bez klikania boiska: 1. klik = zaznacz + podgląd, 2. klik = potwierdź; przyciski strony z podglądem na najechanie; usunięcie `cell` z wyboru celu | `match.gd` (`_human_choose_play`), `play_card_view.gd`, `match_pitch.gd` | test UI: wybór karty i strony samymi kafelkami; boisko reaguje tylko na przesunięcia i kości |
| K4 | Kafelek pionowy (≈ 352 × 600), 3 obok siebie: rysunek zagrania, bloki ATAK / OBRONA, lista wyników, szansa | `play_card_view.gd` (nowy tryb `PORTRAIT`), nowy `play_diagram.gd` | zrzut z gry (prawdziwe boisko, W11) pokazuje 3 kafelki i podgląd na boisku |
| K6 | Miejsce testu (W17): `PlayRequirement.location` (`target` / `origin`), skuteczność kości osobno dla pola docelowego i startowego, testy na ekranie w pasach stref, wybór miejsca w Edytorze zagrań, Laga z testem startu | `play_requirement.gd`, `play_contest.gd`, `play_card.gd`, `dice_odds.gd`, `tests_panel.gd`, `match.gd`, `play_card_view.gd`, `play_diagram.gd`, `match_pitch.gd`, `play_editor.gd`, `play_pitch.gd`, `plays.json` | zrzut `stage=attack card=long_ball` |
| K7 | Interwencja bramkarza (W18): przy strzale osobny test bramkarza (miejsce testu `keeper`, tylko kości bramkarza broniących), zaliczony zamienia gola w obronę bramkarza; na ekranie fioletowa ramka w środkowej kolumnie w pasie bramki broniących (strzela gracz – u góry, karta zsuwa się o pas; strzela komputer – na dole, w rzędzie strefy 1) | `play_requirement.gd`, `play_card.gd`, `play_contest.gd`, `dice_odds.gd`, `match_ai.gd`, `match_engine.gd`, `tests_panel.gd`, `match.gd`, `play_card_view.gd`, `play_editor.gd`, `play_library.gd`, `plays.json` | zrzuty `stage=result card=shot`, `stage=defense card=shot seed=2`, `stage=choose card=shot` |
| K5 | Rozwinięte zagranie po potwierdzeniu (W13): jeden duży panel zamiast 3 kafelków – rysunek, miejsca na kości ATAK i OBRONA rozdzielone (kolor, podpis „Ty” / „Komputer”), progi, lista wyników; miejsce na dodatkowe informacje | `tests_panel.gd`, `play_card_view.gd`, `match.gd` (`_show_play`) | zrzut z gry z ułożonymi kośćmi obu stron |

Makiety nowych widoków: zrzuty z gry (scena meczu z tym samym seedem, prawdziwe boisko, koszulki, kości i energia
zawodników), nie osobne rysunki – W11. Artefakt HTML służy tylko do pokazania przebiegu klikania.

### Ścieżka A „Szlif”

| Krok | Zakres |
|---|---|
| A1 | `plays.json` v4: jeden test na stronę, bez wag, wyniki `success` / `duel_won` / `duel_lost` / `defense`; migracja 15 kart; `PlayLibrary` czyta v3 i v4 |
| A2 | Silnik: udział liczbą kości (2 / 1 / 0), wyczerpanie = −1 kość, 3 wyniki; usunięcie odnóg i łańcuchów z przebiegu tury |
| A3 | AI i `DiceOdds` na nowe zasady; kalibracja progów (`calibrate=1`) do ok. 2,5–3 gola i 8–10 strzałów na mecz |
| A4 | Edytor zagrań uproszczony do modelu v4 (usunięte wagi, odnogi, łańcuchy) |
| A5 | Aktualizacja `match_rules.md` i opisu ekranu |

### Ścieżka B „Drabina”

| Krok | Zakres |
|---|---|
| B1 | Model zagrania v4: `zones` (strefy, z których można zagrać), `lane` (`center` / `wing`), `advance` (1–2), `is_shot`, test ataku i test obrony (próg w skali ×2 / ×1 + cechy), wyniki 3 rodzajów; nowa talia 12–15 zagrań; `PlayLibrary` v4 (v3 tylko do archiwum) |
| B2 | Silnik: piłka = strefa, losowanie 3 zagrań dla strefy, pole akcji = strefa celu + kanał, udział ×2 (pole akcji) / ×1 (sąsiedzi bez skosów) przez listę modyfikatorów udziału (pod perki), strata = lustrzana strefa; **tura w dwóch etapach** (`attack_phase` → `defense_phase`); `MatchRules` bez wag 0,6 / 0,3 / 0,5 |
| B3 | AI: wybór zagrania i strony skrzydła (porównanie szans obu stron), przesunięcie do pola akcji / sąsiedniego, przerzuty: atak jak dotąd, obrona przy znanej sumie ataku (szansa warunkowa) |
| B4 | Symulacja i kalibracja: cel 2,5–3 gola, 8–10 strzałów, akcja dochodzi do strefy 5 w ok. 25–35% posiadań; raport „postęp posiadania” (do której strefy doszło) |
| B5 | Ekran: etapy ataku i obrony po kolei (kroki komputera z pauzą), rozwinięte zagranie zamiast 3 kafelków (W13), na boisku podświetlenie pola akcji (×2) i pól sąsiednich (×1), plakietki ×2 / ×1 przy kościach |
| B5a | (opcja, po kalibracji) Perki trenera: 2–3 przykładowe perki jako dane, przypisanie trenerowi drużyny, opis w profilu trenera |
| B6 | Edytor zagrań uproszczony do modelu v4 |
| B7 | (opcja) Okienka z D jako alternatywny rodzaj testu |
| B8 | Aktualizacja `match_rules.md` |

### Ścieżka C „Przeciąganie liny”

| Krok | Zakres |
|---|---|
| C1 | Model zagrania jak B1, ale zamiast progów: cechy ataku i obrony + skala `defense_at` (≤), `attack_at` (≥), `big_at` (≥) |
| C2 | Silnik jak B2, rozstrzygnięcie różnicą sum (3 najlepsze kości strony) |
| C3 | AI: rozkład różnicy (splot rozkładów kości) zamiast przybliżenia normalnego dwóch testów |
| C4 | Kalibracja jak B4 |
| C5 | Ekran: panel rozstrzygnięcia jako suwak (−6 … +6) z kolorowymi strefami i znacznikiem, animacja przesuwania po rzucie i przerzucie |
| C6 | Edytor, dokumentacja |

### Ścieżka D „Okienka”

| Krok | Zakres |
|---|---|
| D1 | Model zagrania jak B1, ale testy to listy okienek (`attribute` albo `die_type`, `min`) i liczba potrzebnych okienek na stronę |
| D2 | Silnik jak B2; rozstrzygnięcie liczbą zapełnionych okienek, pojedynek sumą punktów w okienkach |
| D3 | AI: przydział kości do okienek pełnym przeszukaniem; szanse Monte Carlo (cache per zagranie / skład) albo dokładne wyliczenie dla ≤ 3 okienek |
| D4 | Kalibracja jak B4 |
| D5 | Ekran: okienka na kafelku i w panelu rozstrzygnięcia, przeciąganie kości z boiska do okienka (W3) |
| D6 | Edytor, dokumentacja |

## Status

| Krok | Stan | Notatka |
|---|---|---|
| Archiwum v1 | [x] | 2026-10-28: kopia w `_archive/match_v1_cards/`, wynik referencyjny 3,18 gola (200 meczów, seed 1) |
| Wybór propozycji | [x] | 2026-10-28: użytkownik wybrał **B „Drabina”** jako podwaliny; zgłosił jeszcze uwagi (do dopisania) |
| K1 | [x] | 2026-10-28: 2 × 16 tur, minuta = początek tury (0'…45', 45'…90'), kwadratowe kafelki (maks. 34 px), przerwa = złoty pas ze znakiem pauzy (`MATCH_HALF_TIME_SHORT` w podpowiedzi). Sim 200/seed 1: 3,15 gola, RRV 72 / remisy 55 / BCU 73. Zrzuty: `tools/match_screenshot.gd` |
| K2 | cofnięte | 2026-10-28: zrobione i na prośbę użytkownika cofnięte (kod jak w archiwum v1). Wcześniejsza notatka: plakietki komputera (`MatchPitch.faded_team`): kości 26 px z szarą warstwą (`MatchDie.faded`), plakietka 62% krycia, bez poświaty; numer, nazwisko i energia zostają. Animacje rzutu / przerzutu komputera przygaszone. Panel testów po prawej jeszcze bez zmian (K5). |
| K2b | [x] | 2026-10-28: etap ataku (przesunięcie → rzut → przerzuty → ułożenie → „Zatwierdź”), potem etap obrony (to samo; kości obrony liczone od nowa tylko po przesunięciu obrońcy – inaczej symulacja 2× wolniejsza). Pasek decyzji z prefiksem „Atak – RRV:” / „Obrona – BCU:”. Po `finish_turn` złote tło wyniku na karcie FULL, reszta wyblakła (bezpańska piłka dopisuje się). Sim 200/seed 1: 3,40 gola, RRV 81 / remisy 50 / BCU 69, ok. 88 ms/mecz. Animacji rozstrzygnięcia jeszcze nie ma. |
| K3 | [x] | 2026-10-28: `_human_choose_play` – najechanie bez zaznaczenia = podgląd, klik = zaznaczenie (złota ramka) + podgląd, drugi klik / „Zagraj” = potwierdzenie; kilka celów → przyciski „◀ Lewym / Prawym ▶” (albo „Do strefy X, …”) na karcie, najechanie = podgląd celu. Wejście `&"play"` {card, target}. Pola celów na boisku tylko podświetlone (`set_choice_cells(..., clickable=false)`), klik w boisko przy wyborze nic nie robi; boisko klikalne tylko przy przesunięciu i kościach. Karty wciąż poziome (pionowe w K4). |
| K4 | [x] | 2026-10-28: `PlayCardView.Mode.PORTRAIT` (zastąpił ROW): nazwa i ruch, `PlayDiagram` (nowy `scenes/match/play_diagram.gd` – całe boisko 3 × 5 rysowane kodem: pasy, linie, piłka, łuk do celu / bramki, pole akcji złote, wsparcie jasnozłote, przelot pomarańczowy, kropki zawodników – biorący udział z obwódką), bloki ATAK / OBRONA z podpisem „Ty” / „Komputer” i progami, lista 4 wyników ze znacznikami koloru, paski szans. 3 karty w `HBoxContainer`, równa szerokość i wysokość. Przy kilku celach najechanie na przycisk strony pokazuje cel na rysunku i na boisku. Karta FULL (po wyborze) bez zmian – K5. Zrzut: `stage=choose`. |
| K5 | [x] | 2026-10-28 (układ W16): `TestsPanel` jest wierszem trzech kolumn – z lewej ramka strony gracza (atak albo obrona), w środku `center` z kartą FULL (nazwa, ruch, `PlayDiagram` z wybranym celem, opis, lista wyników z podświetleniem), z prawej ramka komputera; ramki podpisane „Ty · RRV” / „Komputer · BCU”. Karta FULL bez starego mini boiska i wierszy testów (progi są w ramkach). `PlayDiagram.flipped`: rysunek ustawiony jak boisko na ekranie (atakują goście → bramka na dole); rysunek odświeża się po przesunięciu. Zrzuty: `stage=attack`, `defense`, `result`. |
| K6 | [x] | 2026-10-28: test ma `location` (w JSON `"location": "origin"`, brak = cel). `ContestDie.efficiency` (cel) + `origin_efficiency` (start: waga liczona od pola startowego, bez przelotu); podający nie dostaje premii przy celu, gdy strona ma test startu; kość trafia tylko do testów, przy których bierze udział (`PlayContest.get_test_efficiency`, `can_place`). Podgląd (boisko, rysunek, edytor) – `PlayContest.get_card_cell_weight`. Ekran: `TestsPanel` to Control z ręcznym układem – ramka strony na strefę, na wysokości pasa strefy z boiska (`match.gd._update_test_rows`, odświeżane przy przewijaniu stadionu), ramki jednej kolumny się rozsuwają; etykiety „Start” / „Cel” tylko przy kartach z testem startu. Bez kart z testem startu sim identyczny (3,40). Laga: start „siła lub podanie” 0,5, cel „siła” 0,5 i „przyjęcie (kontrola)” 0,5 → sim 200/seed 1: 3,23 gola, RRV 62 / remisy 55 / BCU 83, Laga 3,0 zagrania/mecz, atak zalicza 45% po przerzutach. Wydajność spadła do ok. 120 ms/mecz (było 88) – do optymalizacji przed szybką symulacją lig. Kilka testów jednej strony w tej samej strefie jest zwiniętych (`_build_test(..., compact)`: etykieta i ikony cech nad sobą, miejsca na kości, suma; nazwy w podpowiedzi, bez paska) – ramka z dwoma testami mieści się w pasie strefy (ok. 150 z 164 px). |
| K7 | [x] | 2026-10-28: test obrony z `"location": "keeper"` (tylko karty strzału; edytor: Miejsce → „Bramkarz”, walidacja `EDITOR_ERROR_KEEPER_TEST`). Bramkarz broniących gra wtedy tylko w nim (`ContestDie.keeper_efficiency`), nie w testach zawodników z pola; test nie wlicza się do „obrona zapełniła” ani do pojedynku. Gdy efekt wyniku to gol, a bramkarz zapełnił test → `goalkeeper_save` (`Turn.keeper_save`). AI: wartość gola × (1 − szansa bramkarza) (`DiceOdds.keeper_probability`), obrońca przerzuca kości bramkarza tylko, gdy atak zapełnił testy. Karty strzału (shot, long_shot, cross): „skok lub czytanie gry” 2,0, maks. 2 kości. Ekran: ramka pojawia się na początku etapu obrony (`TestsPanel.show_keeper`, zsunięcie 0,35 s), kości bramkarza na boisku z fioletowymi punktami, karta w ręce ma blok „Bramkarz”. Sim 200/seed 1: 2,12 gola (było 3,23), obrony bramkarza 1,8/mecz, skuteczność strzałów 28%, RRV 44 / remisy 68 / BCU 88, ok. 130 ms/mecz. Próg 2,5 dawał 3,31 gola, ale tylko 0,7 obrony/mecz. Do kalibracji w B4 (obrona z pola przy strzałach zaliczana teraz rzadko: 17–33% po pierwszym rzucie). |
| B1 | [x] | 2026-10-28: `plays.json` v4 (`zones`, `lane` center/wing, `advance` 0–2, `is_shot`, testy: całkowity próg + `attributes` bez wag + `max_dice` + `location` target/origin/keeper, 4 wyniki `success` / `duel_won` / `duel_lost` / `defense`); `PlayLibrary` czyta tylko v4, v3 (kod, plik, sim) w `_archive/match_v1_cards/v3_final/`. Usunięte: `OutcomeBranch`, `ChainEvent`, kierunki i cele ręczne, przejście zawodnika (`MatchPlayer.moved_cell` zostaje martwe do B2). „Nikt nie zapełnił” = pojedynek (macierz zwinięta do 3 rodzajów). Most do B2: silnik dalej na polach, `PlayCard.get_targets` liczy pole akcji ze strefy piłki + kanału; udział od razu ×2 / ×1 (`MatchRules.action_weight` 2, `support_weight` 1, skos i druga strona 0, podający i przelot 1) – bez listy modyfikatorów (B2). Talia 14 zagrań (tabela w `match_rules.md`): bez zmian strony, nowe Podłączenie bocznego, Wycofanie i strzał, Rajd w polu karnym; Prostopadłe +2. Edytor minimalnie pod v4 (strefy LPM / podgląd PPM, kanał, awans, testy bez wag, 4 wyniki; reszta uproszczeń w B6). Ekran: mnożniki „×2 / ×1” na boisku, całe punkty bez „,0”. Sim 200/seed 1: 2,87 gola, strzały 3,73 + 4,72 (34%), obrony bramkarza 2,6/mecz, RRV 63 / remisy 49 / BCU 88, ok. 172 ms/mecz (było 130 – do sprawdzenia w B2). Do B3/B4: AI prawie nie gra „Rajdu w polu karnym” i „Podania do bocznego”, korytarz C 80% akcji. |
| B2 | [x] | 2026-10-28: piłka = strefa (`MatchEngine.ball_zone`, `Turn.ball_zone`; `Turn.origin` = pole piłki znane po wyborze: strefa piłki w kanale celu, `PlayCard.get_origin`); ręka losowana według strefy (`MatchTeam.get_playable_cards(zone)`), `PlayCard.get_targets(ball_zone)`; strata, przechwyt, wybicie i obrona bramkarza w strefach (lustrzana strefa), rożny bez losowania strony. Udział przez listę modyfikatorów (`ParticipationModifier`: relacja ACTION / SUPPORT / PASSER / FLYOVER, strona, role, strefy w perspektywie zawodnika, kanał; mnożnik = największy pasujący); zasady podstawowe = `MatchRules.get_participation_modifiers()`, perki = `MatchTeam.participation_modifiers` (puste do B5a). `MatchRules` bez `far_side_weight` / `diagonal_weight`; usunięte `MatchPlayer.moved_cell` i `reset_moves`. Ekran: piłka w środku strefy albo w polu piłki pokazywanego zagrania, rysunek karty liczy pole piłki od celu, kropki / żetony z modyfikatorami drużyny i roli; edytor – podgląd z polem piłki w kanale celu. Test modyfikatorów (16 przypadków, w tym perk DM w polu karnym i perk skrzydłowego) – OK. Sim 200/seed 1: 2,79 gola, strzały 3,81 + 4,46 (34%), obrony bramkarza 2,4/mecz, RRV 66 / remisy 60 / BCU 74, korytarz L 5% C 87% P 8% (skrzydła rzadziej niż w B1 – B3/B4), ok. 174 ms/mecz (szybka ścieżka w `get_weight`, flagi karty liczone raz na kontest). Bez zmian: skuteczność roli / wyczerpanie / murawa (ułamki) – decyzja otwarta. |
| B3 | [x] | 2026-10-28: pojedynek w ocenie zagrania z rozkładów nadwyżek (`DiceOdds.duel_probability`) zamiast 50/50; skrzydło – AI ocenia L i P osobno (bez zmian, działało od B2). Obrona przy znanym wyniku ataku: przerzuty do wygranej, nie do progu (`MatchAI.get_defense_goal`; gdy już wygrywa – nic, bramkarz tylko przy groźbie gola), przesunięcia według szansy wygranej (`DiceOdds.defense_win_probability`, `MatchEngine.ai_shift` podaje nadwyżkę ataku). Przesunięcia także ×1 → ×2 (wcześniej tylko zawodnicy spoza akcji – pozostałość skali 1,0). Sim 200/seed 1: 2,73 gola, strzały 3,27 + 4,57 (35%), obrony bramkarza 2,0/mecz, RRV 51 / remisy 58 / BCU 91, przesunięcia 34/mecz (było 17), przerzuty 53 (było 70), wyczerpani na koniec 44% (było 24%), ok. 133 ms/mecz. Pojedynek AI B3 kontra B2 (400 meczów, seed 7, tymczasowa flaga – usunięta): RRV z nowym AI 1,33 pkt/mecz zamiast 1,19, BCU 1,58 zamiast 1,53. Do B4: skrzydła wciąż rzadkie (L 4%, P 7%), więcej wyczerpanych. |
| B4 | [x] | 2026-10-28: raport „postęp posiadania” (`MatchEngine._possession_reach` → `MatchStats.record_possession`; najdalsza strefa piłki albo pola akcji strzału; posiadanie kończy strata, gol, przerwa, koniec meczu) i narzędzie `tools/sim_batch.py` (11 par taktyk równolegle, ok. 45 s). Kalibracja talii w 5 rundach: skrzydła A 2 → 1 (Gra skrzydłem, Podłączenie bocznego, Podanie do bocznego), Wybicie A 3 / O 3, Strzał z dystansu A 1 / O 6, Drybling A 2, Strzał z pola karnego O 10, Wycofanie i Rajd O 8, bramkarz 4 → 3 we wszystkich strzałach. Średnio z 11 par (150 meczów, seed 1): **2,80 gola, 7,5 strzału, strefa 5 w 31% posiadań** (20–36%), skrzydła 10–25% akcji (przed B4 1–15%), wyczerpani 27–42%; każda karta grana (Rajd w polu karnym 0,1/mecz, Wybicie 0,6 – głównie taktyki DM). Para domyślna 200/seed 1: 3,27 gola, 8,1 strzału (40%), strefa 5 35%, RRV 46 / remisy 50 / BCU 104, ok. 133 ms/mecz. Poniżej celu: strzały (ograniczone liczbą posiadań w strefie 4–5, nie atrakcyjnością strzału); 4-5-1 i 3-5-2 (DM) mało goli. Tabela par w `match_rules.md`. |
| B5 | [x] | 2026-10-28: etapy ataku i obrony z pauzami komputera i rozwinięte zagranie były już z K2b / K5, mnożniki pól z B1. Nowe: plakietka mnożnika (`MultiplierBadge`: „×2” złota – pole akcji, „×1” jasna – pole sąsiednie) na polach nakładki zagrania (zamiast drobnego napisu) i w wierszu nazwiska na plakietce zawodnika z kośćmi (`DicePlate.multiplier` = `ContestDie.participation`, podpowiedź `MATCH_PARTICIPATION_TOOLTIP`), podpowiedź kości w miejscu testu z mnożnikiem testu (`PlayContest.get_test_weight`; `ContestDie` pamięta mnożniki celu / startu / bramkarza). Edytor używa tego samego formatu „×2”. Symulacja bez zmian (200/seed 1 identyczna z B4). Zrzuty: `stage=defense card=shot seed=2`, `stage=attack card=wing_play turns=3`. |
| B5a | [x] | 2026-10-29: zakładki arkusza `perks` (gid 111: relacja, strona, role, strefy, kanał, mnożnik, klucze nazwy i opisu) i `coaches` (gid 110: drużyna, imię i nazwisko, `risk_percent`, perki) → `data/perks.csv`, `data/coaches.csv` (`tools/sheets_config.json`, sync). `PerkData` (gotowy `ParticipationModifier`), `CoachData`, `TeamData.coach`, wczytywanie w `GameData`. `MatchTeam.create`: perki trenera → modyfikatory drużyny, AI bez podanego profilu → `risk_aversion` trenera. Perki: Skrzydłowi do ataku i Lis pola karnego (Grabowski, RRV), Twierdza (Dahl, BCU). Ekran: `CoachPanel` – zwięzły na ekranie składu (pod taktyką), pełny w podglądzie rywala, podpowiedź nazwy drużyny na ekranie meczu; edytor liczy szanse z perkami. Sim: `perks=0` = bez perków (identyczne z B4); z perkami 200/seed 1: 3,45 gola, RRV 53 / remisy 53 / BCU 94 (bez: 46 / 50 / 104), punkty ataku ST 15,3 → 19,1 na mecz. |
| B6 | [x] | 2026-10-28: edytor był pod v4 od B1 (strefy, kanał, awans, testy bez wag, 4 wyniki, bez odnóg / łańcuchów / celów ręcznych). B6: kolumna **podglądu karty** (`PlayCardView` PORTRAIT jak w ręce) z szansami dla strefy podglądu na domyślnych składach – każdy test: średnie punkty / próg → szansa (`DiceOdds.test_odds`), pojedynek (`duel_probability`), przełącznik atakującej drużyny; odświeża się przy każdej zmianie (próg, cechy, strefa). Porządki: wyniki bez „posiadania”, miejsce „Bramkarz” tylko przy strzale (albo gdy test już nim jest), przycisk „+ test bramkarza”. Zrzuty: karta `cross` i `wing_play` z drugą drużyną w ataku. Następny krok: B7 (opcja – okienka) albo B8 (dokumentacja). |
| B8 | [x] | 2026-10-28: `match_rules.md` przepisane pod v2: struktura boisko i piłka → czas → tura → udział (tabela i modyfikatory) → skuteczność → karty (pola, edytor, talia) → wynik akcji i efekty → bramkarz → energia → AI → ekran → symulacja i kalibracja → kierunek → zakres → otwarte pytania. Usunięte nieaktualne fragmenty (parametry `diagonal_weight` / `far_side_weight`, „pojedynek AI 50/50”, wyblakłe kości komputera z cofniętego K2, wyniki symulacji v1 – są w `archive/match_rules_v1.md`). `CLAUDE.md` wskazuje stan v2 i narzędzia strojenia. Zostają opcjonalne B5a (zrobione 2026-10-29) i B7. |
