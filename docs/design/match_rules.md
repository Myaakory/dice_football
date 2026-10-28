# Zasady meczu: zagrania taktyczne, kości i energia

> **⚠ PROTOTYP: założenia robocze, nie ostateczne zasady.**
> Dokument opisuje mechanikę do testów (silnik w `scripts/match_sim/`, symulacja w `scenes/dev/match_sim.tscn`,
> ekran w `scenes/match/`). Wszystkie liczby (progi kart, mnożniki, energia, liczba tur) to wartości robocze do
> strojenia. Parametry są w kodzie (`MatchRules`, `scripts/match_sim/match_rules.gd`), po ustabilizowaniu trafią do
> arkusza Google (zakładka `match_params`). **Karty** żyją w `data/plays/plays.json` i edytuje się je w grze
> (Edytor zagrań).

Status: 2026-10-28 – **v2 „Drabina”** (plan i historia zmian: [match_v2_plan.md](match_v2_plan.md), kroki K1–K7
i B1–B6). Poprzednie zasady (v1: siatka pól, wagi 100 / 60 / 30%, karty z odnogami i łańcuchami) i pierwsze
symulacje: [archive/match_rules_v1.md](archive/match_rules_v1.md); kod i dane ostatniej wersji kart v3:
`_archive/match_v1_cards/v3_final/`.

## Cel projektowy

System ma być **zgrabny**: kilka dobrze przeplatających się mechanik, które dają ciekawe wybory w meczu
i miejsce na rozwój drużyny poza boiskiem (trenerzy, trening, transfery). Przeciwnik komputerowy musi
umieć podejmować sensowne decyzje prostymi regułami. Gra jest o **dojściu do strefy 5 i strzale**, a nie
o przerzucaniu piłki między skrzydłami.

**Zasada czterech dźwigni.** Każdy nowy pomysł musi działać przez jedną z nich. Jeśli nie pasuje do
żadnej, odpada albo czeka:

| Dźwignia | Pytanie | Źródła |
|---|---|---|
| **Karty** | Co gramy? | taktyka, znajomość taktyki, trener |
| **Pozycja** | Czyje kości liczą się ×2, a czyje ×1? | formacja, przesunięcia za energię, perki trenera |
| **Skuteczność** | Ile wart jest każdy punkt zawodnika? | rola, forma, zmęczenie, murawa |
| **Energia** | Ile razy mogę nagiąć los? | przerzuty, przesunięcia, zmiana taktyki |

## Boisko i piłka

- **5 stref w długości** (`lane` 1–5 z `tactic_slots.csv`), liczonych od własnej bramki drużyny.
- **3 kanały w szerokości**: lewy (`x` < 25), środek (25–75) i prawy (`x` > 75), patrząc w kierunku ataku.
  Zawodnicy stoją w polach siatki 3 × 5 według formacji.
- Rywal widzi boisko odwrotnie: jego strefa `s` to nasza `6 − s`, a jego lewy kanał to nasz prawy.
- **Piłka ma tylko strefę** i należy do jednej drużyny. Kanał ma dopiero zagranie: **pole akcji** = strefa piłki
  + awans karty, w kanale karty (środek albo wybrane skrzydło). **Pole piłki** w zagraniu to strefa piłki w kanale
  pola akcji (`PlayCard.get_origin`): stąd liczą się testy startu, podający i przelot.
- Kanały sprawiają, że strona boiska ma znaczenie: akcja skrzydłem rozgrywa się tam, gdzie stoją boczni obrońcy
  i skrzydłowi, ale piłka nie „wędruje” po korytarzach.

## Czas meczu

- Jedna tura to jedno zagranie. Mecz: 2 połowy × 16 tur (`turns_per_half`).
- Minuta na zegarze to początek tury: 1. połowa 0', 3', … 45', 2. połowa 45', 48', … 90' (co 3 minuty).
- Pierwszą połowę rozpoczyna gospodarz, drugą gość, w strefie 3. Po golu wznawia drużyna, która straciła bramkę,
  w strefie 3.

## Tura

1. **Wybór zagrania**: drużyna z piłką dostaje **3 losowe karty** ze swojej talii pasujące do strefy piłki
   (`hand_size`) i wybiera jedną (przy karcie skrzydłowej – także skrzydło).
2. **Etap ataku**: przesunięcie jednego zawodnika o jedno pole na tę turę albo nie (2 energii) → rzut kości ataku →
   przerzuty (1 runda, `reroll_rounds`, 1 energii za kość, płaci właściciel kości) → ułożenie kości w miejscach
   testów → zatwierdzenie. Wynik ataku jest od tej chwili znany obu stronom.
3. **Etap obrony**: to samo dla obrony (kości obrony liczą się z pól po jej przesunięciu – `MatchEngine.roll_side`).
   Obrońca zna wynik ataku, więc sam decyduje, czy warto wydać energię.
4. **Rozstrzygnięcie** (macierz wyników niżej) i efekt z karty.

**Układanie kości**: strona wkłada wyrzucone kości do miejsc w testach. Test ma tyle miejsc, ile wynosi jego limit
(`max_dice`), kość trafia do jednego testu, a ścianka musi mieć cechę testu i zawodnik musi brać udział przy polu
tego testu. **Liczą się tylko kości w miejscach.** AI układa najlepsze kości każdego testu
(`PlayContest.get_auto_placement`) i tak samo liczy symulacja; gracz może ułożyć inaczej (np. ściankę pasującą do
dwóch testów do drugiego).

Kroki tury w silniku (te same na ekranie i w symulacji AI kontra AI, `MatchEngine._play_turn`): `begin_turn` →
`set_play` / `choose_ai_play` → dla ataku, potem obrony: `apply_shift` / `ai_shift` → `roll_side` → `reroll` /
`ai_rerolls` → rozmieszczenie kości → `finish_turn`.

## Udział zawodników w akcji

Punkty kości zawodnika mnoży się przez **mnożnik udziału** (zależny od pola, w którym stoi) i skuteczność:

| Gdzie stoi zawodnik (względem pola testu) | Mnożnik (`MatchRules`) |
|---|---|
| Pole testu (pole akcji albo – dla testu startu – pole piłki) | ×2 (`action_weight`) |
| Pole sąsiednie: przód, tył, bok – bez skosów | ×1 (`support_weight`) |
| Pole piłki (podający), gdy strona nie ma testu startu | co najmniej ×1 (`passer_weight`) |
| Pole, nad którym leci podanie o 2 strefy (tylko obrońcy) | co najmniej ×1 (`flyover_weight`) |
| Bramkarz broniących przy strzale (w teście bramkarza; bez niego – w testach obrony) | ×2 |
| Dalej (skos, druga strona boiska, dwie strefy i więcej) | 0 |

Progi kart są w tej samej skali (liczby całkowite).

**Modyfikatory udziału** (`ParticipationModifier`). Mnożnik zawodnika = największy z pasujących modyfikatorów.
Modyfikator: relacja do pola testu (`ACTION` – pole testu, `SUPPORT` – pole sąsiednie, `PASSER` – pole piłki, tylko
atak, `FLYOVER` – pole przelotu, tylko obrona), mnożnik i warunki: strona (atak / obrona / obie), role zawodnika,
strefy pola testu w perspektywie drużyny zawodnika (obrońca: 1 = własne pole karne), kanał zagrania. Zasady z tabeli
to domyślna lista `MatchRules.get_participation_modifiers()`; drużyna dokłada **perki swojego trenera**
(`MatchTeam.participation_modifiers`, niżej), np. „DM w akcjach obronnych w polu karnym ×2” = `SUPPORT`, obrona,
role [DM], strefy [1], ×2. Podgląd pola bez zawodnika (boisko, rysunek karty, edytor) liczy
tylko modyfikatory bez warunku roli; plakietki i kropki zawodników – z ich rolą.

**Perki trenera** (W15, oś progresji): dane w arkuszu – zakładki `perks` (relacja, strona, role, strefy, kanał,
mnożnik; nazwa i opis przez klucze tłumaczeń) i `coaches` (trener drużyny, profil ryzyka AI, lista perków) –
`PerkData`, `CoachData`, `TeamData.coach`. `MatchTeam.create` dokłada perki trenera do modyfikatorów drużyny,
a AI bez podanego profilu bierze `risk_aversion` trenera. Przykładowe perki:

| Perk | Trener | Działanie |
|---|---|---|
| Skrzydłowi do ataku | Stanisław Grabowski (RRV) | atak skrzydłem: LM / RM / LW / RW z pola sąsiedniego ×2 zamiast ×1 |
| Lis pola karnego | Stanisław Grabowski (RRV) | atak: napastnik (ST) w polu akcji w polu karnym rywala (strefa 5) ×3 zamiast ×2 |
| Twierdza | Henrik Dahl (BCU) | obrona własnego pola karnego: CB / DM z pola sąsiedniego ×2 zamiast ×1 |

Trener i perki są na ekranie składu (pod taktyką, opisy w podpowiedziach), w podglądzie rywala (pełne opisy)
i w podpowiedzi nazwy drużyny na ekranie meczu; Edytor zagrań liczy szanse z perkami drużyn podglądu. Docelowo:
szukanie trenera pod taktykę jako decyzja menedżerska, 1–3 perki na trenera.

**Aktywne kości**: zawodnik rzuca tylko aktywne kości (2 z 3, jak w składzie) i tylko kości typu, który ma cechę
wymaganą przez kartę po jego stronie. Domyślne aktywne kości wynikają z pozycji zawodnika, a rola może je nadpisać
(kolumna `preferred_dice` w zakładce roles arkusza): **DM gra kośćmi fizyczną i defensywną**.

**Limit kości**: rzucają wszystkie uczestniczące kości, ale w każdym teście liczą się najwyżej `max_dice` kości
(domyślnie 3, 0 = wszystkie). Przerzucać można każdą kość. `MatchRules.max_dice_used` (domyślnie −1 = według testów)
nadpisuje limit wszystkich testów w eksperymentach.

## Skuteczność zawodnika

| Składnik | Wartości robocze |
|---|---|
| Dopasowanie do roli | naturalna 100%, drugorzędna 85%, poza pozycją 65% |
| Forma | −15% … +15% (w prototypie 0) |
| Wyczerpanie (energia = 0) | 70% (`exhausted_efficiency`) |
| Murawa (tylko kości techniczne) | 100% dobra … 80% zła (`pitch_technical`) |

Te składniki dają jeszcze ułamki punktów (ekran pokazuje je z jedną cyfrą po przecinku, całe liczby – bez części
ułamkowej). Docelowo v2 ma mieć na ekranie tylko liczby całkowite – sposób do decyzji (otwarte pytania).

## Karty zagrań

- Karta ma **strefy piłki**, z których można ją zagrać (`zones`), **kanał** (`lane`: środek albo skrzydło – na
  skrzydle atakujący wybiera lewe albo prawe) i **awans** (`advance`, 0–2 stref; strefa pola akcji przycinana do
  1–5).
- Karta ma **testy ataku** i **testy obrony** (każdy test strony musi zostać zapełniony): próg (liczba całkowita)
  i cechy łączone przez „lub”, bez wag.
- **Talia** pochodzi z taktyki. Docelowo znajomość taktyki odblokowuje karty i ich wersje „+”, a między meczami
  wybiera się karty do talii. *Prototyp: obie drużyny mają wszystkie karty.*

### Plik kart i Edytor zagrań

Karty są w `data/plays/plays.json` (`{"version": 4, "plays": [...]}`; starsze wersje się nie wczytują), a edytuje
się je w grze: menu główne → **Edytor zagrań** (`scenes/play_editor/`). To **wyjątek od zasady „arkusz Google =
źródło prawdy”**: dla kart źródłem prawdy jest ten plik (edytor uruchomiony z projektu zapisuje go do `res://`).
Wczytanie, zapis, walidację i talie obsługuje `PlayLibrary`, model karty to `PlayCard` + `PlayRequirement`, lista
zdarzeń to `PlayEvents`.

Pola karty:
- `id` (snake_case, unikalne), `name`, `description` (na razie zwykły tekst).
- `tactics`: taktyki, które mają kartę w talii (**talia drużyny = karty, których `tactics` zawiera taktykę składu**,
  kolejność jak w pliku).
- `triggers`: warunki dobierania łączone przez „lub”: karta trafia do puli, gdy wcześniej wydarzyło się któreś
  z tych zdarzeń. Domyślnie `possession` (zwykłe posiadanie). Pula drużyny z piłką = karty z `possession` + karty
  z warunkiem równym zdarzeniu, które dało jej obecną sytuację (np. `turnover` po odbiorze → karty kontry). Po
  **stałym fragmencie** (`foul`, `corner`, `penalty`, `offside`) losują się tylko karty z tym zdarzeniem; jeśli
  żadnej nie ma, gra toczy się kartami posiadania.
- `zones` (1–5), `lane` (`center` / `wing`), `advance` (0–2), `is_shot` (karta strzałowa: sukces = gol).
- `attack`, `defense`: testy – `points` (próg ≥ 1), `attributes` (cechy „lub”), `max_dice` i opcjonalnie
  `location`: brak = pole akcji (np. przyjęcie piłki), `"origin"` = pole piłki (np. zagranie długiej piłki; udział
  liczy się od pola piłki, bez przelotu, a w testach celu podający nie dostaje wtedy premii), `"keeper"` = interwencja
  bramkarza (tylko obrona kart strzału). Ścianka trafia do pierwszego testu, który ma jej cechę.
- `outcomes`: zdarzenie dla 4 wyników – `success`, `duel_won`, `duel_lost`, `defense`.

Zdarzenia (wspólne dla efektów i warunków): `possession`, `advance`, `goal`, `keep`, `turnover`, `clearance`,
`interception`, `goalkeeper_save`, `foul`, `corner`, `penalty`, `offside`.

**Edytor**: lista kart (filtr taktyki, nowa / kopia / usuń, zapis Ctrl+S z walidacją), boisko (LPM albo numer
strefy przełącza strefę piłki, PPM wybiera strefę podglądu: pole piłki, strzałki do pól akcji, przelot, mnożniki
A / O), **podgląd karty** tak, jak w ręce w meczu, z szansami dla strefy podglądu na domyślnych składach drużyny
gracza i rywala (każdy test: średnie punkty, próg i szansa jednym rzutem; pojedynek; przycisk zmienia atakującą
drużynę – szanse liczy `DiceOdds`, jak AI, bez przesunięć i przerzutów) oraz panel właściwości (ogólne, taktyki,
warunki, zagranie, testy ataku i obrony z przyciskiem „+ test bramkarza” przy strzale, wyniki).

### Talia v2 (14 zagrań, wszystkie taktyki)

`A` = testy ataku, `O` = testy obrony; `@start` – test przy polu piłki, `@GK` – bramkarz. Progi po kalibracji B4
(robocze – do ręcznego strojenia).

| Zagranie | Strefy | Kanał | Awans | Testy | Przegrany pojedynek |
|---|---|---|---|---|---|
| Krótkie wyprowadzenie | 1–2 | środek | 1 | A: podanie/kontrola 3; O: pressing/odbiór 5 | utrzymanie |
| Podanie do bocznego | 1–2 | skrzydło | 1 | A: podanie/szybkość 1; O: pressing/szybkość 2 | utrzymanie |
| Wybicie | 1–2 | środek | 2 | A: siła/skok 3; O: skok/czytanie 3 | strata |
| Tiki-taka | 2–4 | środek | 1 | A: podanie/kontrola 4; O: pressing/odbiór 6 | utrzymanie |
| Gra skrzydłem | 2–4 | skrzydło | 1 | A: szybkość/kontrola 1; O: odbiór/szybkość 3 | utrzymanie |
| Laga | 2–3 | środek | 2 | A: siła/podanie 1 @start, siła 1, kontrola 1; O: skok/czytanie 5 | strata |
| Podłączenie bocznego | 3–4 | skrzydło | 1 | A: szybkość/podanie 1; O: szybkość/odbiór 3 | utrzymanie |
| Prostopadłe podanie | 3–4 | środek | 2 | A: podanie 2, szybkość 1; O: czytanie 4 | strata |
| Drybling | 3–4 | środek | 1 | A: kontrola/szybkość 2; O: odbiór 4 | strata |
| Dośrodkowanie (strzał) | 4–5 | środek | 1 | A: podanie 1 @start, skok/siła 2; O: skok/czytanie 6, @GK 3 | strata |
| Strzał z dystansu | 4 | środek | 0 | A: strzał 1; O: czytanie/skok/odbiór 6, @GK 3 | strata |
| Strzał z pola karnego | 5 | środek | 0 | A: strzał 1; O: czytanie/skok/odbiór 10, @GK 3 | strata |
| Wycofanie i strzał | 5 | środek | 0 | A: podanie/kontrola 1 @start, strzał 1; O: pressing/czytanie 8, @GK 3 | strata |
| Rajd w polu karnym | 5 | środek | 0 | A: kontrola/szybkość 1 @start, strzał 1; O: odbiór/szybkość 8, @GK 3 | strata |

Test bramkarza we wszystkich strzałach: „skok lub czytanie gry” 3, maks. 2 kości. Wszystkie wyniki „sukces”
i „wygrany pojedynek” to awans (gol przy strzale), „obrona” to strata.

## Wynik akcji

| | Obrona zapełniła | Obrona nie zapełniła |
|---|---|---|
| **Atak zapełnił** | **Pojedynek**: `duel_won` albo `duel_lost` | **Sukces**: `success` |
| **Atak nie zapełnił** | **Obrona**: `defense` | **Pojedynek**: `duel_won` albo `duel_lost` |

- **Pojedynek**: wygrywa strona z większą **nadwyżką punktów** ponad próg (przy kilku testach – test z największą
  nadwyżką; test bramkarza się nie liczy). Gdy nikt nie zapełnił, nadwyżki są ujemne i wygrywa mniejszy brak. Remis
  rozstrzyga los.
- Każda karta ma **profil ryzyka**: bezpieczna tiki-taka – mały postęp i `keep` po przegranym pojedynku, Laga – duży
  postęp i strata.

**Efekty** (`MatchEngine._apply_effect`; miejsce akcji = strefa pola akcji; strata = rywal zaczyna w **lustrzanej
strefie**: strata w mojej strefie 4 → rywal w swojej 2):

| Efekt | Skutek |
|---|---|
| `advance` | piłka w strefie pola akcji |
| `goal` | gol, wznowienie rywala w strefie 3 |
| `keep` (i `possession`) | piłka zostaje w swojej strefie |
| `turnover` | rywal przejmuje piłkę w lustrzanej strefie miejsca akcji |
| `interception` | rywal przejmuje piłkę w lustrzanej strefie pierwszego pola przelotu (bez przelotu: miejsca akcji) |
| `clearance` | rywal wybija piłkę `clearance_distance` (2) stref do przodu od miejsca akcji i ją ma |
| `goalkeeper_save` | piłka u bramkarza rywala (jego strefa 1) |
| `offside` | rywal ma rzut wolny w miejscu akcji |
| `foul` | atakujący mają rzut wolny w miejscu akcji |
| `corner`, `penalty` | atakujący mają rzut rożny / karny (strefa 5) |

Zdarzenie staje się „sytuacją” drużyny, która ma piłkę po efekcie (warunki `triggers` kart).

## Strzał i bramkarz

Karty strzału przy sukcesie dają gola. **Interwencja bramkarza**: karta strzału ma w obronie osobny test bramkarza
(`"location": "keeper"`). Liczą się w nim tylko kości bramkarza broniących (na razie jego zwykłe aktywne kości:
fizyczna i defensywna, mnożnik ×2), a bramkarz nie gra wtedy w testach zawodników z pola. Testy ataku i obrony
rozstrzygają się jak zwykle; gdy wynik dałby gola, a bramkarz zapełnił swój test, gol zamienia się w **obronę
bramkarza** (`goalkeeper_save`). Karta strzału bez testu bramkarza: bramkarz bierze udział w testach obrony (×2).
Kości bramkarzy mają być przemodelowane.

## Energia i kondycja

- **Energia meczowa**: budżet zawodnika na cały mecz (`start_energy` 6). Nie odnawia się co turę, w przerwie wraca
  +2 (`halftime_energy`, do maksimum). Budżet zamiast regeneracji daje decyzję „teraz czy w końcówce”.
- Wydatki: przerzut kości (1, `reroll_cost`), przesunięcie zawodnika o pole na jedną turę (2, `shift_cost`;
  bramkarz się nie przesuwa), docelowo zmiana taktyki. *Prototyp: bez zmian taktyki i zawodników.*
- Energia 0 = wyczerpanie: skuteczność 70%.
- **Kondycja** (długoterminowa, 0–100%) wyznaczy energię startową; spada po meczu, częściowo wraca między meczami.
  *Prototyp: wszyscy mają pełną kondycję.*

## Przeciwnik komputerowy (AI)

Znamy rozkład każdej kości, więc dla każdej karty da się policzyć szanse (`DiceOdds`, przybliżenie normalne: średnia
i wariancja sumy punktów, z nich P(suma ≥ próg); bez Monte Carlo). Przy limicie kości test dostaje „sloty”: kości od
najwyższej średniej trafiają do slotów na przemian, a slot daje dokładnie policzone maksimum swoich kości (lekko
zaniża szanse).

- **Wybór karty i skrzydła** (lewe i prawe pole akcji oceniane osobno): `wartość = Σ P(wynik) · wartość stanu po
  wyniku`. Wartość stanu to „ile wart jest posiadanie piłki w strefie z” (`possession_value`), gol – 1 × (1 − szansa
  bramkarza), strata – minus wartość posiadania rywala. Pojedynek: szansa wygranej ataku z rozkładów nadwyżek obu
  stron (`DiceOdds.duel_probability`). Profil trenera (`risk_aversion`) skaluje straty; przegrywający w końcówce
  ryzykuje więcej.
- **Przerzuty**: atak (nie zna rzutu obrony) przerzuca, jeśli nie zapełnił testów – kości o największym oczekiwanym
  zysku, aż zysk pokryje brak. **Obrona zna wynik ataku** (`MatchAI.get_defense_goal`) i celuje w wygraną: jej test
  musi przekroczyć próg o więcej niż nadwyżka ataku (remis = pół punktu); przy zapełnionym ataku wszystkie testy
  obrony, przy niezapełnionym wystarczy jeden. Gdy obrona już wygrywa, nie przerzuca; kości bramkarza przerzuca tylko
  przy groźbie gola. Tempo wydawania: energia drużyny podzielona przez pozostałe tury, przemnożona przez wagę akcji.
- **Przesunięcia**: AI liczy wzrost szansy po przesunięciu każdego zawodnika, którego mnożnik rośnie (także ×1 → ×2).
  Atak – szansa zapełnienia testów, obrona – szansa wygranej przy znanym wyniku ataku
  (`DiceOdds.defense_win_probability`). Przesuwa najlepszego, gdy wzrost przekracza `min_shift_gain` i mieści się
  w budżecie.
- **Układanie kości**: najlepsze kości każdego testu (do limitu); bez sprytnego dzielenia ścianek pasujących do dwóch
  testów.

Ta sama funkcja szans posłuży do szybkiej, statystycznej symulacji meczów innych lig
([world_scale.md](../architecture/world_scale.md), poziomy szczegółowości).

## Ekran meczu: gracz kontra komputer

Menu → Rozegraj mecz → skład → mecz (`scenes/match/`). Gracz prowadzi gospodarzy, komputer gości; ekran wywołuje
kroki tury silnika, a za drużynę gracza decyduje gracz. Ruchy komputera (zagranie, przesunięcie, przerzuty,
ułożenie kości) są pokazywane z krótką pauzą. Na boisku leżą kości tylko strony, która gra etap; kości poprzedniego
etapu zostają w miejscach testów.

Decyzje gracza:
- **wybór zagrania** – ręka to 3 pionowe karty obok siebie (rysunek zagrania, bloki ATAK / OBRONA / BRAMKARZ
  z progami, lista wyników, szanse). Na boisku nie klika się nic w związku z zagraniem: najechanie na kartę pokazuje
  ją na boisku, klik zaznacza, drugi klik albo „Zagraj” potwierdza; karta skrzydłowa ma przyciski „◀ Lewym /
  Prawym ▶” (najechanie pokazuje ten cel);
- **w etapie** – przesunięcie jednego zawodnika (kliknij zawodnika, potem pole), przerzut wybranych kości, ułożenie
  kości w miejscach testów (przeciągnij albo kliknij kość; „Ułóż najlepiej” = jak AI), zatwierdzenie.

Układ:
- po lewej **stadion**: boisko między trybunami (także za bramkami); widok przesuwa się w pionie kółkiem myszy albo
  środkowym przyciskiem (dwuklik – powrót), strzałki na krawędziach pokazują, że da się przesunąć;
- **boisko**: przyciemnienie z ustawień, bramkarze w osobnych strojach (`KitColors`), pod koszulką kropki w kolorach
  aktywnych kości, pod nazwiskiem pasek energii (`EnergyBar`). Podpowiedzi: koszulka – schematy kości, pasek –
  wytrzymałość; kliknięcie nazwiska otwiera profil zawodnika (tylko podgląd). **Nakładka zagrania**: pola z udziałem
  (plakietki „×2” złota – pole akcji, „×1” jasna – pole sąsiednie), pole piłki (przerywana ramka), pole akcji, strzałka,
  przelot; piłka w środku swojej strefy albo w polu piłki pokazywanego zagrania;
- po rzucie zawodnik z kośćmi to **plakietka** (`DicePlate`): kości zamiast koszulki (poświata w kolorze drużyny –
  Opcje), pod nimi plakietka mnożnika „×2 / ×1”, numer, nazwisko i pasek energii; nachodzące plakietki się rozsuwają;
- po prawej: wynik i minuta, **oś meczu** (2 × 16 kwadratowych kafelków, przerwa = złoty pas; kolor = drużyna
  z piłką, symbol = gol, strzał, awans, stały fragment, strata; szczegóły w podpowiedzi), panel zagrania, pasek
  decyzji i **warunki meczu** (murawa, pogoda, kibice – `MatchConditions`; na grę wpływa na razie tylko murawa);
- **rozwinięte zagranie** po wyborze (`TestsPanel`): trzy kolumny – z lewej testy gracza (blisko boiska, gdzie
  losują się kości), w środku karta zagrania (rysunek ustawiony jak boisko, opis, lista wyników; po rozstrzygnięciu
  wynik, który wszedł w życie, ma złote tło), z prawej testy komputera. Prawa część jest podzielona na 5 pasów na
  wysokości stref boiska (lekkie przerywane linie), a każdy test stoi w pasie strefy, której dotyczy (start / cel;
  kilka testów jednej strony w tej samej strefie dzieli zwiniętą ramkę). Ramki: atak zielona, obrona brązowa,
  **bramkarz fioletowa** – pojawia się na początku etapu obrony w środkowej kolumnie, w pasie bramki broniących
  (przy strzale gracza u góry, a karta zsuwa się o pas; przy strzale komputera na dole). Podpowiedź kości w miejscu
  testu: nazwisko, punkty i mnożnik.

## Symulacja i kalibracja

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . res://scenes/dev/match_sim.tscn -- matches=200 seed=1
```

Argumenty po `--`: `matches`, `seed`, `home`, `away`, `home_tactic` / `away_tactic` (`t_442`, `t_433`, `t_433_dm`,
`t_433_am`, `t_451`, `t_451_am`, `t_352`, `t_352_am`), `home_risk` / `away_risk` (bez nich – profil trenera), `perks=0` (bez perków trenerów), `random_dice=1` (losowe punkty
ścianek 1–3), `log=1` (przebieg jednego meczu tura po turze), `cards=1` (lista kart), `calibrate=1` (średnie punkty
i szanse każdej karty z każdej strefy), `attack_scale` / `defense_scale` (mnożnik progów wszystkich kart), `role_dice`
(aktywne kości według roli, np. `DM:physical+defensive`) oraz dowolny parametr `MatchRules`, np. `action_weight=3`,
`turns_per_half=16`.

Raport: gole, strzały, wyniki, posiadanie, rozkład goli, pole akcji (strefa i korytarz), **postęp posiadania**
(najdalsza strefa, do której doszło posiadanie – strefa piłki albo pole akcji strzału – i liczba posiadań), efekty
wyników, energia, tabela kart (przewidziana szansa AI, po pierwszym rzucie, po przerzutach, wyniki, skutki) i wkład
ról.

**Seria na 11 parach taktyk** (równolegle, ok. 45 s, zbiorcza tabela i liczba zagrań każdej karty):
`python tools/sim_batch.py [matches=150] [seed=1] [out=<katalog>]`.

Stan kalibracji (B4, średnio z 11 par po 150 meczów): **2,8 gola, 7,5 strzału na mecz, strefę 5 osiąga 31%
posiadań** (20–36%), akcje skrzydłami 10–25%, wyczerpani na koniec 27–42% zawodników. Szczegóły par i wnioski –
notatka B4 w [match_v2_plan.md](match_v2_plan.md).

## Poza meczem (kierunek, poza prototypem)

- **Znajomość taktyki** per zawodnik i taktyka; znajomość drużyny to średnia jedenastki. Nowy zawodnik obniża
  średnią i może zablokować kartę („gwiazda czy zgranie”).
- **Trener**: perki (modyfikatory udziału – mechanizm gotowy), szybszy rozwój preferowanych taktyk, może wnosić jedną
  firmową kartę. Szukanie trenera pod taktykę to decyzja menedżerska (inspiracje: Golden Lap, Motorsport Manager).
- **Rozwój zawodnika**: ulepszanie ścianek kości (więcej punktów, z czasem kilka cech na ściance); wiek obniża
  punkty. Później może też odblokowywane umiejętności zmieniające mnożniki (jak w Football, Tactics & Glory).
- **Forma** (±15% skuteczności) z ostatnich meczów, minut i morale.
- **Murawa** (i później pogoda) osłabia kości techniczne – w niższych ligach sprzyja futbolowi fizycznemu.

## Skala świata

- Logika meczu to czyste klasy `RefCounted` bez Node'ów i sceny, z deterministycznym RNG z seeda. Ten sam kod
  obsługuje ekran meczu, symulację w tle i testy balansu.
- Stan zawodnika potrzebny w meczu (energia, forma, kondycja, znajomość taktyk) to kilka liczb na zawodnika – przy
  ~20 000 zawodników pomijalne.
- Symulacja AI kontra AI: ok. 130 ms na mecz – za dużo na mecze innych lig (400 meczów kolejki), które potrzebują
  szybkiej symulacji statystycznej.

## Prototyp: zakres

Jest: piłka w strefach 1–5 i pole akcji na siatce 3 × 5, udział ×2 / ×1 przez modyfikatory, perki trenerów
(3 przykładowe), karty v2 z testami
startu / celu / bramkarza i 4 wynikami, tura w dwóch etapach, energia (przerzuty, przesunięcia, przerwa +2), AI obu
drużyn, symulacja wielu meczów z raportem i serią par taktyk, ekran meczu gracz kontra komputer z ręcznym układaniem
kości, Edytor zagrań z podglądem karty i szans.

Nie ma (jeszcze): wyboru i zmiany trenera, „mocniejszego ataku / obrony” poza przesunięciem i przerzutem
(decyzja odłożona), zmian taktyki i zawodników w meczu, formy, kondycji między meczami, znajomości taktyki
i odblokowywania kart, stałych fragmentów jako osobnych kart, kości bramkarzy po przemodelowaniu, wpływu pogody
i kibiców.

## Otwarte pytania

- **Ułamki ze skuteczności** (rola 85 / 65%, wyczerpanie 70%, murawa): jak dojść do samych liczb całkowitych?
  Propozycja z planu: wyczerpanie (i może gra poza pozycją) obniża mnożnik o stopień, ×2 → ×1 → 0.
- **„Mocniejszy atak / obrona”**: czym jest poza przesunięciem i przerzutami (pomysł: dodatkowa energia = dołożenie
  kości zawodnika z pola sąsiedniego albo podbicie mnożnika jednego zawodnika na tę akcję)?
- **Liczba strzałów** (7,5 na mecz przy celu 8–10) zależy od liczby posiadań w strefie 4–5, a nie od atrakcyjności
  strzału – szybszy postęp akcji albo więcej posiadań?
- **Strefa 5**: AI zawsze wybiera najlepszy z trzech wylosowanych strzałów, więc karty strefy 5 wypierają się
  nawzajem.
- **Taktyki z jednym napastnikiem** (4-5-1, 3-5-2 w wersji DM) zdobywają mało goli – karty dla wbiegających
  pomocników?
- **Kości bramkarzy** – do przemodelowania (teraz zwykłe: fizyczna + defensywna).
- Czy obrona ma dość decyzji? Kandydat: postawy obronne (pressing / średni / niski blok) albo krótka talia kart
  obronnych.
- Zmiana taktyki w meczu: 3 przygotowane taktyki, koszt 1 energii każdemu na boisku?
