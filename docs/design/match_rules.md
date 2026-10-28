# Zasady meczu: zagrania taktyczne, kości i energia

> **⚠ PROTOTYP: założenia robocze, nie ostateczne zasady.**
> Ten dokument opisuje wersję mechaniki do testów (prototyp w `scripts/match_sim/`, symulacja w
> `scenes/dev/match_sim.tscn`). Wszystkie liczby (progi kart, mnożniki, energia, liczba tur) to wartości
> startowe do strojenia symulacją. Zasady mogą się zmienić po testach.
> Parametry są na razie w kodzie (`match_rules.gd`), po ustabilizowaniu trafią do arkusza Google (zakładka
> `match_params`). **Karty** żyją w `data/plays/plays.json` i edytuje się je w grze (Edytor zagrań), patrz
> „Karty w pliku i Edytor zagrań” niżej.

Status: 2026-10-28, model kart v4 i silnik „Drabiny” (kroki B1–B2 planu `match_v2_plan.md`).

## Cel projektowy

System ma być **zgrabny**: kilka dobrze przeplatających się mechanik, które dają ciekawe wybory w meczu
i miejsce na rozwój drużyny poza boiskiem (trenerzy, trening, transfery). Przeciwnik komputerowy musi
umieć podejmować sensowne decyzje prostymi regułami.

**Zasada czterech dźwigni.** Każdy nowy pomysł musi działać przez jedną z nich. Jeśli nie pasuje do
żadnej, odpada albo czeka:

| Dźwignia | Pytanie | Źródła |
|---|---|---|
| **Karty** | Co gramy? | taktyka, znajomość taktyki, trener |
| **Pozycja** | Czyje kości liczą się w pełni, a czyje częściowo? | formacja, przesunięcia za energię |
| **Skuteczność** | Ile wart jest każdy punkt zawodnika? | rola, forma, zmęczenie, murawa |
| **Energia** | Ile razy mogę nagiąć los? | przerzuty, przesunięcia, zmiana taktyki |

## Boisko: siatka 3 × 5

- **5 stref w długości** (`lane` 1–5 z `tactic_slots.csv`), liczonych od własnej bramki drużyny.
- **3 kanały w szerokości**: lewy (`x` < 25), środek (25–75) i prawy (`x` > 75), patrząc w kierunku ataku.
- Rywal widzi boisko odwrotnie: jego strefa `s` to nasza `6 − s`, a jego lewy kanał to nasz prawy.
- Piłka ma tylko **strefę** (od B2) i należy do jednej drużyny. Kanał ma pole akcji zagrania; pole piłki
  w zagraniu to strefa piłki w kanale pola akcji (`PlayCard.get_origin` – start testów startu, podający,
  początek przelotu). *Do B2 piłka leżała w polu (strefa + kanał).*

Kanały sprawiają, że strona boiska ma znaczenie. Akcja skrzydłem rozgrywa się tam, gdzie stoją boczni
obrońcy i skrzydłowi.

## Udział zawodników w akcji

**Od 2026-10-28 (krok B1, `match_v2_plan.md` W14):** każda akcja toczy się w **polu akcji** – strefa piłki + awans
karty, w kanale karty (środek albo wybrane skrzydło). Mnożnik udziału mnoży punkty kości:

| Gdzie stoi zawodnik | Mnożnik (`MatchRules`) |
|---|---|
| Pole akcji | ×2 (`action_weight`) |
| Pole sąsiednie (przód, tył, bok – bez skosów) | ×1 (`support_weight`) |
| Pole piłki (podający), gdy strona nie ma testu przy polu startowym | co najmniej ×1 (`passer_weight`) |
| Pole, nad którym leci podanie o 2 strefy (tylko obrońcy) | co najmniej ×1 (`flyover_weight`) |
| Bramkarz przy strzale (test bramkarza; bez niego w testach obrony) | ×2 |
| Dalej (skos, druga strona boiska w tej samej strefie, dwie strefy i więcej) | 0 (`diagonal_weight`, `far_side_weight`) |

Progi kart są w tej samej skali (liczby całkowite).

**Modyfikatory udziału (od B2, `ParticipationModifier`).** Mnożnik zawodnika = największy z pasujących
modyfikatorów. Modyfikator: relacja do pola testu (`ACTION` – pole testu, `SUPPORT` – pole sąsiednie bez skosów,
`PASSER` – pole piłki, tylko atak, `FLYOVER` – pole przelotu, tylko obrona), mnożnik i warunki: strona (atak /
obrona / obie), role zawodnika, strefy pola testu w perspektywie drużyny zawodnika (obrońca: 1 = własne pole
karne), kanał zagrania (środek / skrzydło). Zasady z tabeli to domyślna lista `MatchRules.get_participation_modifiers`
(budowana z `action_weight`, `support_weight`, `passer_weight`, `flyover_weight`); drużyna dokłada własne
(`MatchTeam.participation_modifiers` – perki trenera, B5a; na razie puste), np. „DM w akcjach obronnych w polu karnym
×2” = `SUPPORT`, obrona, role [DM], strefy [1], ×2. Podgląd pola bez zawodnika (boisko, rysunek, edytor) liczy tylko
modyfikatory bez warunku roli; kropki i żetony zawodników – z ich rolą.
*Do 2026-10-28 (v1): 100% / 60% / 30% (skos i druga strona) / podający 60% / przelot 50%.*

Zawodnik rzuca **tylko aktywne kości** (2 z 3, jak w składzie) i tylko kości tego typu, który ma
cechę wymaganą przez kartę po jego stronie. Domyślne aktywne kości wynikają z pozycji zawodnika, a rola
może je nadpisać (kolumna `preferred_dice` w zakładce roles arkusza): **DM gra kośćmi fizyczną
i defensywną** (decyzja 2026-10-27 po symulacjach wariantów).

**Limit kości**: rzucają wszystkie uczestniczące kości, ale w każdym teście karty liczą się tylko
najlepsze kości do jego limitu (`max_dice` testu, domyślnie 3, 0 = wszystkie; ustawia się w Edytorze
zagrań). Ścianka trafia tylko do jednego testu, więc testy wybierają kości niezależnie. Przerzucać można
każdą kość, także spoza liczących się. `MatchRules.max_dice_used` (domyślnie −1 = według testów) nadpisuje
limit wszystkich testów w eksperymentach. *Do 2026-10-27 limit 3 był wspólny dla całej strony karty.*

## Skuteczność zawodnika

Punkty z kości mnoży się przez mnożnik udziału i skuteczność:

| Składnik | Wartości startowe |
|---|---|
| Mnożnik udziału (pole) | ×2 / ×1 / 0 |
| Dopasowanie do roli | naturalna 100%, drugorzędna 85%, poza pozycją 65% |
| Forma | −15% … +15% (w prototypie 0) |
| Wyczerpanie (energia = 0) | 70% |
| Murawa (tylko kości techniczne) | 100% dobra … 80% zła |

Dopasowanie do roli, wyczerpanie i murawa dają jeszcze ułamki – w v2 mają zniknąć z ekranu (propozycja: wyczerpanie
obniża mnożnik o stopień, ×2 → ×1 → 0; decyzja w B2). Całe liczby ekran pokazuje bez części ułamkowej.

Zrezygnowaliśmy z pustych ścianek jako modyfikatora (zbyt mocno osłabiały jedną cechę i nie było
jasne, którą ściankę wybrać) i z „jednej kości wsparcia” (albo za mocna, albo bezużyteczna).

## Karty zagrań (model v4, „Drabina”)

- Karta ma **strefy piłki**, z których można ją zagrać (`zones`), **kanał** (`lane`: środek albo skrzydło – na
  skrzydle atakujący wybiera lewe albo prawe) i **awans** (`advance`, 0–2 stref). Pole akcji = strefa piłki + awans
  (przycięta do 1–5) w kanale karty. Kanał piłki nie decyduje o tym, co można zagrać – liczy się tylko strefa (W4).
- Karta ma **testy ataku** i **testy obrony**: próg (liczba całkowita) i cechy łączone przez „lub”, bez wag.
- **Ręka**: z talii drużyny dobierasz 3 karty pasujące do strefy piłki i wybierasz jedną.
- **Talia** pochodzi z taktyki. Znajomość taktyki odblokowuje kolejne karty i ich ulepszone wersje „+”.
  Między meczami wybierasz, które z odblokowanych kart trafią do talii (budowanie talii).
  *Prototyp: obie drużyny mają wszystkie karty.*
- *Model v3 (pola wyjścia, kierunki, cele ręczne, odnogi wyników, łańcuchy zdarzeń, przejście zawodnika na pole
  docelowe, wagi składników) jest w archiwum: `_archive/match_v1_cards/v3_final/` (kod, `plays_v3.json`, wynik
  symulacji).*

### Karty w pliku i Edytor zagrań

Karty są w `data/plays/plays.json` (`{"version": 4, "plays": [...]}`; starsze wersje się nie wczytują), a edytuje
się je w grze: menu główne → **Edytor zagrań** (`scenes/play_editor/`). To **wyjątek od zasady „arkusz Google =
źródło prawdy”**: dla kart źródłem prawdy jest ten plik (edytor uruchomiony z projektu zapisuje go bezpośrednio do
`res://`). Wczytanie, zapis, walidację i talie obsługuje `PlayLibrary` (`scripts/match_sim/play_library.gd`), model
karty to `PlayCard` + `PlayRequirement`, lista zdarzeń to `PlayEvents`.

Pola karty:
- `id` (snake_case, unikalne), `name`, `description` (na razie zwykły tekst).
- `tactics`: taktyki, które mają kartę w talii. **Talia drużyny = karty, których `tactics` zawiera taktykę
  składu** (kolejność jak w pliku).
- `triggers`: warunki dobierania łączone przez „lub”: karta trafia do puli, gdy wcześniej wydarzyło się
  któreś z tych zdarzeń. Domyślnie `possession` (zwykłe posiadanie piłki). Pula drużyny z piłką = karty
  z `possession` + karty z warunkiem równym zdarzeniu, które dało jej obecną sytuację (np. `turnover` po
  odbiorze → karty kontrataku). Po **stałym fragmencie** (`foul`, `corner`, `penalty`, `offside`) losują
  się tylko karty z tym zdarzeniem w warunkach; jeśli żadnej nie ma, gra toczy się kartami posiadania.
- `zones`: strefy piłki 1–5, `lane`: `center` / `wing`, `advance`: 0–2.
- `is_shot`: karta strzałowa (sukces = gol; bramkarz gra w teście interwencji, a bez niego w obronie ×2).
- `attack`, `defense`: **testy łączone przez „i”** (każdy musi zostać zapełniony). Test = `points` (próg, liczba
  całkowita ≥ 1) + `attributes` (cechy łączone przez „lub”) + `max_dice` (ile najlepszych kości liczy się w teście,
  0 = wszystkie) + opcjonalnie `location`. Punkty testu = suma punktów kości trafiających w jego cechy. Ścianka
  trafia do pierwszego testu, który ma jej cechę.
- **Miejsce testu** (`location`): brak = pole akcji (np. przyjęcie piłki), `"origin"` = pole piłki (np. zagranie
  długiej piłki – udział liczy się od pola piłki, bez przelotu; w testach celu podający nie dostaje wtedy premii
  podającego), `"keeper"` = interwencja bramkarza (tylko obrona kart strzału, niżej „Strzał i bramkarz”). Kość można
  włożyć tylko do testu, przy którego polu zawodnik bierze udział.
- `outcomes`: zdarzenie dla 4 wyników: `success` (zapełnił tylko atak), `duel_won` / `duel_lost` (pojedynek:
  obie strony zapełniły albo żadna), `defense` (zapełniła tylko obrona).

**Edytor** (model v4, B1 + B6): LPM na boisku albo numer strefy przełącza strefę piłki, PPM wybiera strefę podglądu
(pole piłki w kanale celu, strzałki do pól akcji, przelot, mnożniki A / O ×2 / ×1). Sekcja „Zagranie”: strefy,
kanał, stref do przodu. Testy: próg (liczba całkowita), limit kości, miejsce (cel / start, a przy strzale – bramkarz),
cechy; przy karcie strzału bez testu bramkarza przycisk „+ test bramkarza” (skok / czytanie 3, maks. 2 kości). Wyniki:
zdarzenie dla 4 wyników (bez „posiadania” – to tylko warunek dobierania). **Podgląd karty** (kolumna obok boiska, od
B6): karta tak, jak w ręce w meczu, i szanse dla strefy podglądu (pierwszy cel) na domyślnych składach drużyny gracza
i rywala – każdy test (średnie punkty, próg, szansa jednym rzutem), pojedynek; przycisk zmienia atakującą drużynę.
Szanse liczy `DiceOdds` (te same, z których korzysta AI), bez przesunięć i przerzutów – do ręcznego strojenia progów.

Zdarzenia (wspólne dla efektów i warunków): `possession`, `advance`, `goal`, `keep`, `turnover`,
`clearance`, `interception`, `goalkeeper_save`, `foul`, `corner`, `penalty`, `offside`.

### Talia v4 (2026-10-28, 14 zagrań, wszystkie taktyki)

Progi po kalibracji B4 (`A` = testy ataku, `O` = testy obrony; `@start` – test przy polu piłki, `@GK` – bramkarz):

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

Test bramkarza we wszystkich strzałach: „skok lub czytanie gry” 3 (maks. 2 kości; w B1 – 4, w K7 – 2,0 w skali v1).
Usunięte względem v3: „Rozegranie na drugą stronę”, „Długa zmiana strony” (bez zmiany strony – W4) i „Header”;
nowe: „Podłączenie bocznego”, „Wycofanie i strzał” (zamiast wycofania bez strzału), „Rajd w polu karnym”.

**Kalibracja B4 (2026-10-28)** – `python tools/sim_batch.py` (11 par: domyślna, każda taktyka z samą sobą, 4-4-2 –
4-5-1, 3-5-2 AM – 4-3-3; po 150 meczów, seed 1):

| Para | Gole | Strzały | Strefa 5 | Skrzydła L / P | Wyczerpani | Obrony GK |
|---|---|---|---|---|---|---|
| domyślna (RRV 4-4-2 – BCU 4-3-3) | 3,28 | 8,2 | 36% | 8% / 12% | 30% | 2,6 |
| 4-4-2 × 2 | 2,83 | 7,2 | 34% | 4% / 10% | 32% | 2,3 |
| 4-5-1 × 2 | 1,11 | 5,0 | 20% | 18% / 26% | 42% | 1,1 |
| 4-3-3 × 2 | 3,47 | 8,8 | 36% | 16% / 21% | 30% | 2,8 |
| 3-5-2 × 2 | 1,65 | 5,6 | 29% | 19% / 20% | 39% | 1,6 |
| 4-5-1 AM × 2 | 2,93 | 7,5 | 31% | 13% / 17% | 37% | 2,2 |
| 3-5-2 AM × 2 | 3,10 | 7,7 | 33% | 14% / 16% | 27% | 2,3 |
| 4-3-3 DM × 2 | 1,97 | 8,1 | 28% | 14% / 25% | 33% | 1,9 |
| 4-3-3 AM × 2 | 4,97 | 10,1 | 33% | 10% / 18% | 33% | 3,3 |
| 4-4-2 – 4-5-1 | 2,39 | 6,5 | 31% | 9% / 16% | 38% | 1,7 |
| 3-5-2 AM – 4-3-3 | 3,07 | 7,8 | 34% | 11% / 16% | 30% | 2,4 |
| **średnio** | **2,80** | **7,5** | **31%** | | | |

Wnioski:
- Gole (2,80) i strefa 5 (20–36% posiadań) w celu planu. **Strzałów mniej niż w celu (7,5 zamiast 8–10)**: AI
  strzela prawie zawsze, gdy posiadanie dojdzie do strefy 4–5 (ok. 60–70% z ok. 13–15 posiadań na mecz), więc
  więcej strzałów wymagałoby szybszego postępu albo więcej posiadań, a nie łatwiejszych strzałów (próbowane:
  łatwiejszy strzał z dystansu i słabszy bramkarz zmieniają gole, liczba strzałów stoi).
- Skrzydła: progi ataku 2 → 1 – teraz 10–25% akcji (przed B4 1–15%; 0% w 4-4-2 i 3-5-2).
- „Wybicie” z 3/4 dominowało (5,3 zagrania na mecz), z 4/4 zniknęło – teraz 3/3, grane głównie przez taktyki z DM.
- W strefie 5 AI wybiera zawsze najlepszy z trzech wylosowanych strzałów, więc karty strefy 5 „przeciągają linę”:
  teraz Strzał z pola karnego 1,4, Wycofanie 0,4, Rajd w polu karnym 0,1 zagrania na mecz.
- 4-5-1 (DM) i 3-5-2 (DM) zdobywają mało (1,1 i 1,7 gola w meczu z samą sobą) – jak w v1: jeden napastnik
  bez wsparcia w polu karnym.

### Efekty wyników

Miejsce akcji = strefa pola akcji (piłka ma tylko strefę). Strata = rywal zaczyna w lustrzanej strefie
(strata w mojej strefie 4 → rywal w swojej 2). Zdarzenie staje się „sytuacją” drużyny, która ma piłkę po efekcie
(warunki `triggers`).

| Efekt | Skutek (`MatchEngine._apply_effect`) |
|---|---|
| `advance` | piłka w strefie pola akcji |
| `goal` | gol, wznowienie rywala ze środka |
| `keep` (i `possession`) | piłka zostaje w swojej strefie |
| `turnover` | rywal przejmuje piłkę w lustrzanej strefie miejsca akcji |
| `interception` | rywal przejmuje piłkę w lustrzanej strefie pierwszego pola przelotu (bez przelotu: miejsca akcji) |
| `clearance` | rywal wybija piłkę `clearance_distance` (2) stref do przodu od miejsca akcji i ją ma |
| `goalkeeper_save` | piłka u bramkarza rywala (jego strefa 1) |
| `offside` | rywal ma rzut wolny w miejscu akcji |
| `foul` | atakujący mają rzut wolny w miejscu akcji |
| `corner` | atakujący mają rzut rożny (strefa 5) |
| `penalty` | atakujący mają rzut karny (strefa 5) |

AI ocenia kartę według efektów 4 wyników (`MatchAI.get_effect_value`; rzut karny wart `penalty_value` × gol,
gol × (1 − szansa bramkarza)). Pojedynki AI nadal liczy jako 50/50.

### Rozstrzyganie karty

1. Atakujący wybiera kartę (i skrzydło, jeśli karta gra skrzydłem).
2–5. **Etapy (od 2026-10-28, `match_v2_plan.md` W12)**: najpierw cały etap ataku, potem cały etap obrony.
   W etapie strona: przesuwa jednego zawodnika o jedno pole na tę turę albo nie (2 energii) → rzuca swoje kości
   → przerzuca (1 runda, `reroll_rounds`, 1 energii za kość, płaci właściciel kości) → układa kości w miejscach
   testów i zatwierdza. Obrońca przesuwa, rzuca i układa, znając już wynik ataku. Kości obrony liczą się
   z pól po jego przesunięciu (`MatchEngine.roll_side`).
   Układanie kości: strona wkłada wyrzucone kości do miejsc w testach. Test ma tyle miejsc, ile wynosi jego limit
   (`max_dice`), kość trafia do jednego testu, a ścianka musi mieć cechę testu. **Liczą się tylko kości
   w miejscach.** AI układa najlepsze kości każdego testu (`PlayContest.get_auto_placement`) i tak samo liczy
   symulacja. Gracz może też ułożyć gorzej albo wybrać inny test dla ścianki, która pasuje do dwóch.
6. Wynik według macierzy:

| | Obrona zapełniła | Obrona nie zapełniła |
|---|---|---|
| **Atak zapełnił** | **Pojedynek**: `duel_won` albo `duel_lost` | **Sukces**: `success` |
| **Atak nie zapełnił** | **Obrona**: `defense` | **Pojedynek**: `duel_won` albo `duel_lost` |

- **Pojedynek**: wygrywa strona z większą **nadwyżką punktów** ponad próg. Przy kilku testach („i”) liczy się
  test z największą nadwyżką. Gdy nikt nie zapełnił, nadwyżki są ujemne i wygrywa mniejszy brak. Remis
  rozstrzyga los. *Do kroku B1 „nikt nie zapełnił” miało osobne efekty (`none_won` / `none_lost`, „bezpańska piłka”
  w polu wyjścia).*
- Domyślne efekty kart: sukces i wygrany pojedynek = `advance` (`goal` przy strzale), przegrany pojedynek =
  `keep` albo `turnover`, obrona = `turnover`.

Każda karta ma więc **profil ryzyka**. Bezpieczna tiki-taka ma niskie progi, mały postęp i `keep`.
Laga ma duży postęp, trudne progi i `turnover`.

*Zmiana po symulacji (v1):* pierwotnie remis kończył się zwykłym `keep`. W gęstym środku pola obie strony
prawie zawsze zapełniały wymagania i akcje stały w miejscu (0,2–0,3 gola na mecz). Pojedynek przy
każdym remisie to naprawił.

### Strzał i bramkarz

Karty strzału przy sukcesie dają gola. Po golu wznawia drużyna, która straciła bramkę, w strefie 3, w środku.

**Interwencja bramkarza (od 2026-10-28, `match_v2_plan.md` W18, K7).** Karta strzału ma w obronie osobny test
bramkarza (`"location": "keeper"`). Liczą się w nim tylko kości bramkarza broniących (na razie jego zwykłe aktywne
kości: fizyczna i defensywna, mnożnik ×2), a bramkarz nie gra wtedy w testach zawodników z pola. Testy ataku i obrony
rozstrzygają się jak zwykle (macierz, pojedynek – test bramkarza się w nich nie liczy); gdy wynik dałby gola,
a bramkarz zapełnił swój test, gol zamienia się w **obronę bramkarza** (`goalkeeper_save`: piłka u bramkarza, strefa 1
broniących). Obecnie we wszystkich strzałach: „skok lub czytanie gry” 3 (kalibracja B4), maks. 2 kości. Karta strzału bez testu
bramkarza: bramkarz broniących bierze udział w testach obrony z mnożnikiem ×2.

## Czas meczu

- Jedna tura to jedna rozegrana karta. Mecz: 2 połowy × 16 tur (`turns_per_half`; do 2026-10-28 było 15).
- Minuta na zegarze to początek tury: 1. połowa 0', 3', … 45', 2. połowa 45', 48', … 90' (co 3 minuty).
- Pierwszą połowę rozpoczyna gospodarz, drugą gość, w strefie 3, w środku.

## Energia i kondycja

- **Energia meczowa**: budżet zawodnika na cały mecz (start 6). Nie odnawia się co turę, w przerwie wraca
  +2 (do maksimum). Budżet zamiast regeneracji daje prawdziwą decyzję „teraz czy w końcówce” i nie
  wymaga liczenia odnowy dla 22 zawodników.
- Wydatki: przerzut kości (1), przesunięcie zawodnika o pole na jedną turę (2), zmiana taktyki
  (1 każdemu na boisku, w przerwie meczu za darmo). *Prototyp: bez zmian taktyki.*
- Energia 0 oznacza wyczerpanie: skuteczność 70%. Daje to sens zmianom zawodników.
  *Prototyp: bez zmian zawodników.*
- **Kondycja** (długoterminowa, 0–100%): wyznacza energię startową. Spada po meczu i częściowo wraca
  między meczami. *Prototyp: wszyscy mają pełną kondycję.*

## Poza meczem (kierunek, poza prototypem)

- **Znajomość taktyki** jest per zawodnik i taktyka. Znajomość drużyny to średnia jedenastki na boisku.
  Nowy zawodnik obniża średnią i może zablokować kartę, co daje decyzję składu „gwiazda czy zgranie”.
- **Trener** szybciej rozwija znajomość taktyk, które preferuje. Może wnosić jedną firmową kartę.
- **Rozwój zawodnika** to ulepszanie ścianek kości: więcej punktów, a z czasem kilka cech na jednej
  ściance (ścianka z kilkoma cechami dokłada punkty do każdej z nich). Wiek obniża punkty.
- **Forma** zmienia skuteczność (±15%) i wynika z ostatnich meczów, minut i morale.
- **Murawa** (i później pogoda) obniża skuteczność kości technicznych. W niższych ligach sprzyja to
  futbolowi fizycznemu.

## Przeciwnik komputerowy (AI)

Znamy rozkład każdej kości, więc dla każdej karty da się policzyć szanse na wynik. Prototyp używa
przybliżenia normalnego: średnia i wariancja sumy punktów, a z nich P(suma ≥ próg). Monte Carlo nie
jest potrzebne. Przy limicie 3 kości każde wymaganie dostaje „sloty” (po jednym, reszta dla wyższych
progów); kości od najwyższej średniej trafiają do slotów na przemian, a slot daje dokładnie policzone
maksimum swoich kości. Suma slotów lekko zaniża szanse.

- **Wybór karty i strony** (przy grze skrzydłem AI ocenia lewe i prawe pole akcji osobno i bierze lepsze):
  `wartość = Σ P(wynik) · wartość_stanu_po_wyniku`. Wartość stanu to „ile wart jest posiadanie piłki w strefie z”
  (tabela `possession_value`). Gol jest wart 1 × (1 − szansa bramkarza), a strata piłki to minus wartość posiadania
  rywala. Profil trenera (`risk_aversion`) skaluje straty, więc dostajemy różnych przeciwników prawie za darmo.
  Przegrywająca drużyna w końcówce ryzykuje więcej. **Pojedynek** (od B3): szansa wygranej ataku z rozkładów
  nadwyżek obu stron (`DiceOdds.duel_probability` – różnica dwóch rozkładów normalnych, każdą stronę reprezentuje
  jej test z największą średnią nadwyżką); do B2 stałe 50/50.
- **Przerzuty**: atak (nie zna rzutu obrony) przerzuca, jeśli nie zapełnił testów – kości o największym oczekiwanym
  zysku, aż zysk pokryje brak. **Obrona zna wynik ataku** (etap obrony, W12; od B3 – `MatchAI.get_defense_goal`):
  celuje w wygraną, a nie w próg – jej test musi przekroczyć próg o więcej niż nadwyżka ataku (remis = pół punktu);
  przy zapełnionym ataku wszystkie testy obrony, przy niezapełnionym wystarczy ten z najmniejszym brakiem. Gdy obrona
  już wygrywa, nie przerzuca; kości bramkarza przerzuca tylko wtedy, gdy obrona z pola przegrywa (grozi gol). Tempo
  wydawania to energia drużyny podzielona przez pozostałe tury, przemnożona przez wagę akcji.
- **Przesunięcia**: AI liczy, o ile wzrośnie szansa po przesunięciu każdego kandydata, którego mnożnik udziału
  rośnie (także ×1 → ×2 do pola akcji – do B3 przesuwali się tylko zawodnicy spoza akcji). Atak liczy szansę
  zapełnienia testów, obrona – szansę wygranej przy znanym wyniku ataku (`DiceOdds.defense_win_probability`).
  Przesuwa najlepszego, jeśli wzrost przekracza próg (`min_shift_gain`) i mieści się w budżecie.
- **Układanie kości**: AI wkłada do każdego testu jego najlepsze kości (do limitu). Nie próbuje sprytniej
  dzielić ścianek pasujących do dwóch testów – kandydat do ulepszenia, jeśli gracze zaczną to wykorzystywać.

Ta sama funkcja szans posłuży do szybkiej, statystycznej symulacji meczów innych lig
([world_scale.md](../architecture/world_scale.md), poziomy szczegółowości).

### Ekran meczu: gracz kontra komputer

Menu → Rozegraj mecz → skład → mecz (`scenes/match/`). Gracz prowadzi gospodarzy, komputer gości. Ekran
wywołuje kroki tury silnika (`MatchEngine.begin_turn` → `set_play` / `choose_ai_play` → dla ataku, potem obrony:
`apply_shift` / `ai_shift` → `roll_side` → `reroll` / `ai_rerolls` → rozmieszczenie kości → `finish_turn`),
a symulacja AI kontra AI przechodzi te same kroki w `_play_turn`.

Decyzje gracza w turze:
- **atak**: ręka to 3 pionowe karty obok siebie (od 2026-10-28: rysunek zagrania, bloki ATAK i OBRONA z progami,
  lista wyników, szanse); wybór karty tylko na karcie (od 2026-10-28): najechanie pokazuje zagranie na boisku, klik zaznacza,
  drugi klik albo „Zagraj” potwierdza; przy kilku celach karta ma przyciski stron („◀ Lewym / Prawym ▶”),
  najechanie na przycisk pokazuje ten cel; boiska przy wyborze się nie klika; potem jak w obronie;
- **obie strony**: przesunięcie jednego zawodnika o pole (kliknij zawodnika, potem pole), przerzut wybranych
  kości, ułożenie kości w miejscach testów (przeciągnij albo kliknij kość; „Ułóż najlepiej” = jak AI).

Ruchy komputera (karta, przesunięcie, przerzuty, ułożenie kości) są pokazywane z krótką pauzą. Na boisku leżą
kości tylko strony, która gra etap; kości poprzedniego etapu zostają w miejscach testów. Po rozstrzygnięciu
wynik, który wszedł w życie, ma na karcie złote tło (reszta blednie).

Układ (wybrany 2026-10-27 z czterech makiet, artefakt „Dice Football – układy ekranu meczu”):
- po lewej **stadion**: boisko między trybunami, także za bramkami; kontrolka rezerwuje miejsce na trybuny
  2× szersze niż obecne (`StadiumView.MAX_STAND_WIDTH`, `MAX_END_DEPTH`), kibice to na razie proste piksele.
  Stadion jest wyższy niż ekran: kółko myszy albo przeciąganie środkowym przyciskiem przesuwa widok
  w pionie (trybuny za bramkami), dwuklik środkowym przyciskiem wraca do boiska; strzałki na krawędziach
  pokazują, że widok da się przesunąć;
- boisko: przyciemnienie z ustawień, bramkarz bliżej bramki, obrońcy dalej od niego, bramkarze w osobnych
  strojach (`KitColors`, długi rękaw i rękawice), pod koszulką kropki w kolorach aktywnych kości, pod
  nazwiskiem pasek energii (`EnergyBar`: zielony / złoty / pomarańczowy, czerwona ramka = wyczerpany;
  szerokość segmentu zależy od maksimum, od 2 do 10 punktów pasek ma podobną długość). Podpowiedzi:
  koszulka – schematy kości zawodnika, pasek – „Wytrzymałość: 4 / 6”; kliknięcie nazwiska otwiera profil
  zawodnika (tylko do podglądu, `PlayerDetailsScreen` z `read_only`),
  nakładka zagrania (mnożniki udziału ×2 / ×1, pole piłki, pole akcji, przelot);
- po rzucie (wariant 7 z makiet, 2026-10-27): zawodnik z kośćmi w akcji to **plakietka** (`DicePlate`) –
  jego kości zamiast koszulki, pod nimi numer w kolorze drużyny, nazwisko i pasek energii, w ramce
  w kolorze drużyny; wokół kości poświata w kolorze koszulek (siła: Opcje → „Poświata drużyny wokół kości”).
  Nachodzące plakietki rozsuwają się, po przesunięciu zawodnika plakietka stoi w nowym polu. Przed numerem
  plakietka mnożnika udziału („×2” złota – pole akcji, „×1” jasna – pole sąsiednie; od B5), te same plakietki
  na polach nakładki zagrania. Zawodnicy bez
  kości w akcji są w tym czasie kropkami w kolorze stroju;
- kości komputera na boisku (od 2026-10-28) są małe (26 px), wyblakłe i bez poświaty, plakietka półprzezroczysta –
  gracz patrzy na swoje kości (`MatchPitch.faded_team`);
- testy w rozwiniętym zagraniu stoją na wysokości strefy boiska, której dotyczą (W17: 5 pasów stref z lekkimi
  przerywanymi liniami; test startu – przy strefie startu, test celu – przy strefie celu); test bramkarza (fioletowa
  ramka) pojawia się na początku etapu obrony w środkowej kolumnie, w pasie bramki broniących: przy strzale gracza
  u góry (karta zsuwa się o pas), przy strzale komputera na dole;
- po wyborze zagrania (od 2026-10-28, `match_v2_plan.md` W16) prawa strona to trzy kolumny: z lewej miejsca na kości
  gracza (blisko boiska, gdzie się losują), w środku karta zagrania (rysunek ustawiony jak boisko, opis, lista wyników –
  po rozstrzygnięciu podświetlony wynik), z prawej miejsca na kości komputera;
- po prawej: wynik i minuta, **oś meczu** w jednym wierszu (2 × 16 kwadratowych kafelków, przerwa = szerszy, delikatnie złoty pas ze znakiem pauzy; kolor =
  drużyna z piłką, symbol = gol, strzał, awans, stały fragment, strata; szczegóły w podpowiedzi), karta
  i testy z miejscami na kości (ramka ataku zielona, obrony brązowa, każda do 2 testów po maks. 3 miejsca;
  przy teście symbole cech, którymi można go wypełnić), pasek decyzji,
  **warunki meczu** (murawa, pogoda, kibice – `MatchConditions`; na grę wpływa na razie tylko murawa).

## Skala świata

- Logika meczu to czyste klasy `RefCounted` bez Node'ów i sceny, z deterministycznym RNG z seeda.
  Ten sam kod obsłuży ekran meczu, symulację w tle i testy balansu.
- Stan zawodnika potrzebny w meczu (energia, forma, kondycja, znajomość taktyk) to kilka liczb na
  zawodnika, co przy ~20 000 zawodników jest pomijalne.

## Prototyp: zakres

Jest:
- siatka 3 × 5, udział z wagami, skuteczność %, karty z wymaganiami i macierzą wyników,
- długie podania z polami przelotu, strzały z bramkarzem,
- energia: przerzuty i przesunięcia, przerwa +2,
- AI obu drużyn, symulacja wielu meczów z raportem.

- ekran meczu gracz kontra komputer (2026-10-27) z ręcznym układaniem kości w testach.

Nie ma (jeszcze):
- zmian taktyki i zawodników w meczu, formy, kondycji między meczami, znajomości taktyki
  i odblokowywania kart, kart obronnych, wpływu pogody i kibiców.

### Uruchomienie symulacji

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . res://scenes/dev/match_sim.tscn -- matches=500 seed=1
```

Argumenty po `--`: `matches`, `seed`, `home`, `away`, `home_tactic` / `away_tactic` (`t_442`, `t_433`, `t_433_dm`, `t_433_am`, `t_451`, `t_451_am`, `t_352`, `t_352_am`),
`home_risk` / `away_risk`, `random_dice=1` (losowe punkty ścianek 1–3, żeby zawodnicy się różnili),
`log=1` (przebieg jednego meczu tura po turze), `cards=1` (lista kart), `calibrate=1` (średnie punkty
i szanse każdej karty z każdego pola) oraz dowolny parametr z `MatchRules`, np. `support_weight=0.7`,
`turns_per_half=16`.

Seria symulacji na 11 parach taktyk (równolegle) ze zbiorczą tabelą – gole, strzały, posiadania do strefy 5,
skrzydła, wyczerpanie, zagrania każdej karty: `python tools/sim_batch.py [matches=150] [seed=1] [out=<katalog>]`.
Raport pojedynczej symulacji ma od B4 wiersz **„Postęp posiadania”**: najdalsza strefa, do której doszło posiadanie
(strefa piłki albo pole akcji strzału), i liczba posiadań na mecz.

## Wyniki pierwszych symulacji (2026-10-27)

Redwood (4-4-2) kontra Bluecastle (4-3-3), wszystkie kości z prototypowych danych (ścianki 1/2),
300 meczów, parametry domyślne:

| Miara | Wynik |
|---|---|
| Gole na mecz | 1,94 (rozkład 0–7, najczęściej 1–2) |
| Strzały na mecz | ok. 4,5, skuteczność ok. 40% |
| Przerzuty / przesunięcia na mecz | ok. 42 / 43 |
| Wyczerpani zawodnicy na koniec | ok. 48% |
| Czas symulacji | ok. 40 ms na mecz (GDScript, z AI) |

Wnioski:
- **Progi muszą wynikać z kalibracji**, a nie z intuicji. Przy 2 aktywnych kościach i trafieniu cechy
  1/3 ściankami pula ataku w tercji rywala to zwykle 0,5–2 pkt, a obrony 4–6 pkt. Pierwsze progi
  (2,5–3,5) dawały 0,2 gola na mecz. Do strojenia służy `calibrate=1`.
- **Obrońcy nie mają kości technicznej** wśród aktywnych (fizyczna + defensywna), więc rozegranie
  od tyłu podaniem jest bardzo słabe. Wychodzi się głównie wybiciem albo przez bocznego.
  Do decyzji: czy to zamierzone?
- **Formacja ma duże znaczenie**, nawet przy identycznych kościach. 4-4-2 wygrywa z 4-3-3 niezależnie
  od gospodarza (ok. 140 : 60 przy 100 remisach), 3-5-2 gra z 4-4-2 równo, a 4-5-1 prawie nie strzela
  (0,07 gola), bo samotny napastnik nie ma wsparcia w polu karnym. Dobrze, że taktyka coś znaczy,
  ale 4-5-1 potrzebuje kart dla wbiegających pomocników.
- **Boczni obrońcy** wnoszą ok. 60% punktów środkowego obrońcy, prawie wyłącznie w obronie
  (atak ok. 0,5 pkt na mecz). Stoją w strefie 1, a akcje skrzydłami toczą się w strefach 3–4.
  Kandydaci: karta „podłączenie bocznego” albo ustawienie wahadłowych w strefie 2.
- **Waga pola sąsiedniego** (0,5 / 0,6 / 0,7) prawie nie zmienia wyników (2,01 / 1,94 / 1,85 gola).
- **Zła murawa** (`pitch_technical=0.8`) obniża liczbę goli z 1,94 do 1,21, czyli zgodnie z zamierzeniem.
- **Przerzuty** zmieniają sporo: przy taniej energii obie strony prawie zawsze zapełniają wymagania
  i wszystko rozstrzyga pojedynek. Obecne ustawienie to 6 energii i 1 runda przerzutów.
- **Przewidywania AI** (przybliżenie normalne) zaniżają szanse o ok. 5–15 punktów procentowych
  (nie uwzględniają przesunięć i przerzutów), ale do porównywania kart wystarczają.
- **Wydajność**: 40 ms na mecz to dużo jak na 400 meczów kolejki (ok. 16 s). Mecze innych lig
  potrzebują szybkiej symulacji statystycznej (poziomy szczegółowości z world_scale.md).

## Symulacje po zmianach zasad (2026-10-27, druga runda)

Zmiany: pojedynek na nadwyżkę punktów, limit 3 najlepszych kości, wagi 0,3 (skos i druga strona
boiska), nowe warianty taktyk `t_433_dm`, `t_433_am`, `t_451_am`, `t_352_am` (stare `t_451` i `t_352`
to wersje DM). Każda para taktyk: 150 meczów, mecz taktyki z samą sobą: 200, identyczne kości.

| Taktyka | Pkt/mecz z innymi | Gole za : przeciw | Gole w meczu z samą sobą |
|---|---|---|---|
| 3-5-2 (AM) | 1,74 | 1,72 : 1,27 | 3,98 |
| 3-5-2 (DM) | 1,52 | 1,33 : 1,12 | 2,67 |
| 4-3-3 (AM) | 1,45 | 1,70 : 1,57 | 4,46 |
| 4-4-2 | 1,43 | 1,38 : 1,34 | 3,04 |
| 4-3-3 (DM) | 1,39 | 1,33 : 1,32 | 2,82 |
| 4-3-3 | 1,33 | 1,39 : 1,43 | 3,43 |
| 4-5-1 (AM) | 1,19 | 1,06 : 1,23 | 2,06 |
| 4-5-1 (DM) | 0,75 | 0,47 : 1,11 | 0,54 |

Wnioski:
- **Ofensywny pomocnik pomaga każdej taktyce**, najbardziej 4-5-1 (z 0,54 do 2,06 gola w meczu
  z samą sobą). AM w strefie 4 wspiera strzały i ataki skrzydłami (5–7 pkt ataku na mecz).
- **Defensywny pomocnik w strefie 2 broni mało** (ok. 5 pkt obrony na mecz), bo akcje rywala toczą
  się zwykle w strefach 3–4 z jego perspektywy. 4-5-1 (DM) zostaje najsłabsza.
- **4-3-3 zyskała na wagach 0,3**: 3,43 gola w meczu z samą sobą (wcześniej 1,27).
- **Szacunki AI** z limitem kości (sloty) trafiają w szanse ataku z dokładnością do ok. 15 pp. Obronę
  zaniżają o 15–25 pp, bo obrońca przesuwa zawodników dopiero po wyborze karty przez atak.
- **Wydajność**: ok. 70–95 ms na mecz (wybór 3 najlepszych kości przy każdym liczeniu punktów).
  Do optymalizacji przed szybką symulacją lig.
- Pełna macierz wyników jest w artefakcie „Talia zagrań”, zakładka Taktyki.
- **Gdzie toczą się akcje** (strefa celu z perspektywy atakującego, 4-4-2): 2: 9%, 3: 25%, 4: 24%,
  5: 43%. Strefa 4 atakującego to strefa 2 broniących, więc DM stoi tam, gdzie trzeba. Broni słabo,
  bo z dwóch aktywnych kości (techniczna + defensywna) w obronie liczy się zwykle tylko defensywna.
- **Bez limitu kości** (`max_dice_used=0`): 1,17 gola w meczu lustrzanym zamiast 2,87, 47% remisów.
  DM zyskuje ok. 1,1–1,3 pkt obrony na mecz, ale kolejność taktyk się nie zmienia, a 4-5-1 (DM)
  strzela prawie zero (0,06). Limit odcina DM tylko 1,2–2,0 pkt na mecz.
- **Progi obrony ×0,8** (`defense_scale=0.8`): 1,45 gola w meczu lustrzanym. Taktyki defensywne prawie
  nic nie zyskują (4-5-1 DM: 0,75 → 0,79 pkt/mecz), bo same strzelają jeszcze mniej. Łatwiejsza
  obrona działa na wszystkich jednakowo; żeby wzmocnić taktyki defensywne, potrzebna jest mechanika
  nagradzająca liczebność lub ustawienie w obronie albo kontry.
- **DM z kośćmi fizyczną i defensywną** (`role_dice=DM:physical+defensive`): przy limicie 3 kości
  DM zdobywa 5,9–6,8 pkt obrony zamiast 4,3–5,2, a 3-5-2 (DM) i 4-3-3 (DM) zyskują po ok. 0,12 pkt
  na mecz (1,52 → 1,64 i 1,39 → 1,51). 4-5-1 (DM) nie zyskuje (0,75 → 0,72), bo traci kość techniczną
  potrzebną do budowania ataku. Bez limitu kości efekt w obronie jest większy (do 10 pkt), ale gole
  spadają do ok. 1,1 na mecz. Wykresy: artefakt „Talia zagrań”, zakładka Warianty.

## Otwarte pytania

- Ile powinno dawać pole sąsiednie: 0,5, 0,6 czy 0,7? Czy 0,3 dla skosów to dobra wartość?
- Czy DM ma stać w strefie 2, skoro tam rzadko toczą się akcje rywala?
- Czy 32 tury dają sensowną liczbę goli i akcji?
- Czy boczni obrońcy wnoszą porównywalny wkład do środkowych (raport: punkty na rolę)?
- Czy obrona (bez piłki) ma dość decyzji? Kandydat na później: postawy obronne (pressing / średni / niski
  blok) albo krótka talia kart obronnych.
- Zmiana taktyki w meczu: 3 przygotowane taktyki, koszt 1 energii każdemu na boisku?
