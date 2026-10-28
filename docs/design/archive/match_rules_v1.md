# Zasady meczu: zagrania taktyczne, kości i energia

> **⚠ PROTOTYP: założenia robocze, nie ostateczne zasady.**
> Ten dokument opisuje wersję mechaniki do testów (prototyp w `scripts/match_sim/`, symulacja w
> `scenes/dev/match_sim.tscn`). Wszystkie liczby (progi kart, mnożniki, energia, liczba tur) to wartości
> startowe do strojenia symulacją. Zasady mogą się zmienić po testach.
> Parametry są na razie w kodzie (`match_rules.gd`), po ustabilizowaniu trafią do arkusza Google (zakładka
> `match_params`). **Karty** żyją w `data/plays/plays.json` i edytuje się je w grze (Edytor zagrań), patrz
> „Karty w pliku i Edytor zagrań” niżej.

Status: 2026-10-27, wersja robocza po dyskusji projektowej.

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
- Piłka zawsze leży w jednym polu (strefa + kanał) i należy do jednej drużyny.

Kanały sprawiają, że strona boiska ma znaczenie. Akcja skrzydłem rozgrywa się tam, gdzie stoją boczni
obrońcy i skrzydłowi.

## Udział zawodników w akcji

Każda akcja toczy się w **polu docelowym** karty (tam, dokąd idzie piłka).

| Gdzie stoi zawodnik | Waga udziału (start) |
|---|---|
| Pole docelowe | 100% |
| Pole sąsiednie (bok albo przód/tył) | 60% (`support_weight`) |
| Pole po drugiej stronie boiska w tej samej strefie (np. lewe skrzydło przy akcji prawym) | 30% (`far_side_weight`) |
| Pole skośne (sąsiednia strefa i sąsiedni korytarz) | 30% (`diagonal_weight`) |
| Pole, z którego zagrywamy (tylko atakujący, podający) | co najmniej 60% |
| Pole, nad którym leci długie podanie (tylko obrońcy) | co najmniej 50% (`flyover_weight`) |
| Bramkarz przy kartach strzału | 100% |
| Dalej (dwie strefy i więcej, albo sąsiednia strefa po drugiej stronie boiska) | 0% |

Wagi 30% dodano (2026-10-27), żeby akcja skrzydłem nie była z góry słabsza od akcji środkiem: pole
środkowe ma dwóch sąsiadów z boku, a skrzydło tylko jednego.

Zawodnik rzuca **tylko aktywne kości** (2 z 3, jak w składzie) i tylko kości tego typu, który ma
cechę wymaganą przez kartę po jego stronie. Domyślne aktywne kości wynikają z pozycji zawodnika, a rola
może je nadpisać (kolumna `preferred_dice` w zakładce roles arkusza): **DM gra kośćmi fizyczną
i defensywną** (decyzja 2026-10-27 po symulacjach wariantów).

**Limit kości**: rzucają wszystkie uczestniczące kości, ale w każdym teście karty liczą się tylko
najlepsze kości do jego limitu (`max_dice` testu, domyślnie 3, 0 = wszystkie; ustawia się w Edytorze
zagrań). Ścianka trafia tylko do jednego testu, więc testy wybierają kości niezależnie. Przerzucać można
każdą kość, także spoza liczących się. `MatchRules.max_dice_used` (domyślnie −1 = według testów) nadpisuje
limit wszystkich testów w eksperymentach. *Do 2026-10-27 limit 3 był wspólny dla całej strony karty.*

## Skuteczność zawodnika (jedna liczba w %)

Punkty z kości mnoży się przez skuteczność, a ta jest iloczynem składników:

| Składnik | Wartości startowe |
|---|---|
| Waga udziału (pole) | 100% / 60% / 50% / 30% / 0% |
| Dopasowanie do roli | naturalna 100%, drugorzędna 85%, poza pozycją 65% |
| Forma | −15% … +15% (w prototypie 0) |
| Wyczerpanie (energia = 0) | 70% |
| Murawa (tylko kości techniczne) | 100% dobra … 80% zła |

Ułamki nie przeszkadzają, bo karty wymagają **sumy punktów**, a nie konkretnych symboli. Gracz widzi
jedną liczbę („Kowalski: 72%”) z rozbiciem w podpowiedzi.

Zrezygnowaliśmy z pustych ścianek jako modyfikatora (zbyt mocno osłabiały jedną cechę i nie było
jasne, którą ściankę wybrać) i z „jednej kości wsparcia” (albo za mocna, albo bezużyteczna).

## Karty zagrań

- Karta ma **testy ataku** i **testy obrony** (dawniej „wymagania”). Test to próg punktów i lista cech,
  np. „podanie lub kontrola: 3”. Punkty z kilku cech jednego testu się sumują (każda cecha z wagą).
- Karta ma **pola, z których można ją zagrać** (dowolny zbiór pól siatki). Fazy to zwykle strefy:
  rozegranie (1–2), środek (3), atak (4–5).
- Karta określa **ruch piłki**: o ile stref do przodu i kierunek (przed siebie, na boki, do środka, ręcznie).
  Pełny opis modelu: „Karty w pliku i Edytor zagrań”.
- **Ręka**: z talii drużyny dobierasz 3 karty pasujące do pola piłki i wybierasz jedną.
- **Talia** pochodzi z taktyki. Znajomość taktyki odblokowuje kolejne karty i ich ulepszone wersje „+”.
  Między meczami wybierasz, które z odblokowanych kart trafią do talii (budowanie talii).
  *Prototyp: obie drużyny mają wszystkie karty.*

### Karty w pliku i Edytor zagrań

Karty są w `data/plays/plays.json` (`{"version": 3, "events": [...], "plays": [...]}`; wersje 1–2 też się wczytują), a edytuje się je w grze: menu główne →
**Edytor zagrań** (`scenes/play_editor/`). To **wyjątek od zasady „arkusz Google = źródło prawdy”**: dla kart
źródłem prawdy jest ten plik (edytor uruchomiony z projektu zapisuje go bezpośrednio do `res://`). Wczytanie,
zapis, walidację i talie obsługuje `PlayLibrary` (`scripts/match_sim/play_library.gd`), model karty to
`PlayCard` + `PlayRequirement` + `OutcomeBranch`, lista zdarzeń to `PlayEvents`, zdarzenia łańcuchów to `ChainEvent`.

Pola karty:
- `id` (snake_case, unikalne), `name`, `description` (na razie zwykły tekst).
- `tactics`: taktyki, które mają kartę w talii. **Talia drużyny = karty, których `tactics` zawiera taktykę
  składu** (kolejność jak w pliku).
- `triggers`: warunki dobierania łączone przez „lub”: karta trafia do puli, gdy wcześniej wydarzyło się
  któreś z tych zdarzeń. Domyślnie `possession` (zwykłe posiadanie piłki). Pula drużyny z piłką = karty
  z `possession` + karty z warunkiem równym zdarzeniu, które dało jej obecną sytuację (np. `turnover` po
  odbiorze → karty kontrataku). Po **stałym fragmencie** (`foul`, `corner`, `penalty`, `offside`) losują
  się tylko karty z tym zdarzeniem w warunkach; jeśli żadnej nie ma, gra toczy się kartami posiadania.
- `origins`: pola `[strefa, korytarz]`, z których można zagrać kartę (korytarz 0 = L, 1 = Ś, 2 = P).
- `movement`: `advance` (−1…4, strefa celu przycinana do 1–5) i `direction`:
  `forward` (przed siebie, ten sam korytarz), `sides` (na boki: lewy albo prawy korytarz do wyboru
  atakującego, zawsze oba), `center` (do środka), `manual` (ręcznie: `manual_targets` = `"strefa,korytarz"` →
  lista pól docelowych; `advance` to wtedy tylko domyślny cel nowego pola w edytorze).
  **W edytorze** cele ustawia się klikając: Ctrl+LPM (albo tryb „Klik: cele”) przełącza cel aktywnego pola
  wyjścia (PPM wybiera pole), Shift+LPM – cel wszystkich pól wyjścia naraz (np. dośrodkowanie z 4L/4P/5L/5P
  w 5Ś). Edycja celów karty z kierunkiem automatycznym przełącza ją na `manual`, a cele startują od
  dotychczasowych. *Do 2026-10-27 tryb celów był nieaktywny bez ręcznego wyboru kierunku „Ręcznie”.*
- `is_shot`: karta strzałowa (sukces = gol, bramkarz broni z wagą 1,0).
- `attack`, `defense`: **testy łączone przez „i”** (każdy musi zostać zapełniony). Test = `points` (próg,
  krok 0,5) + `terms`: **składniki łączone przez „lub”**, każdy to `attribute` + `weight`. Punkty testu =
  suma punktów kości trafiających w cechy składników × ich wagi (waga mnoży punkty także w szacunkach AI
  i przy przerzutach). Ścianka trafia do pierwszego testu, który ma jej cechę. `max_dice`: ile najlepszych
  kości liczy się w teście (0 = wszystkie).
- `outcomes`: dla 6 slotów wyniku `{"event", "move_player"}`: `success` (zapełnił tylko atak), `duel_won` /
  `duel_lost` (obie strony zapełniły, atak wygrał / przegrał pojedynek), `defense` (zapełniła tylko obrona),
  `none_won` / `none_lost` (nikt nie zapełnił, atak wygrał / przegrał pojedynek). `move_player`: po efekcie
  jeden zawodnik atakujących (najskuteczniejszy, nie bramkarz) przechodzi z pola wyjścia na pole docelowe
  i zostaje tam, dopóki drużyna ma piłkę (po stracie, golu i w przerwie wraca na pozycję z formacji).
  Nie działa przy efektach oddających piłkę rywalowi. Opcjonalnie `branches`: odnogi wyniku (niżej).

Zdarzenia (wspólne dla efektów i warunków): `possession`, `advance`, `goal`, `keep`, `turnover`,
`clearance`, `interception`, `goalkeeper_save`, `foul`, `corner`, `penalty`, `offside` oraz zdarzenia
łańcuchów z listy `events` pliku (niżej).

### Odnogi wyników (2026-10-27)

Każdy slot wyniku może mieć **odnogi** (`OutcomeBranch`): inne zdarzenie, które z pewną szansą zastępuje
efekt slotu. Pola odnogi: `event`, `move_player`, `measure`, `base`, `per_step`, `step`, `max`, `cells`.

- **Szansa** (w %) = `base` + `per_step` × (miara / `step`), przycięta do 0…`max`. Pomiędzy krokami rośnie
  proporcjonalnie (np. 10% za każde 0,5 → przy 0,7 pkt 14%).
- **Miara** z rzutu tej akcji: `none` (stała szansa), `defense_deficit` / `attack_deficit` (ile punktów
  zabrakło stronie do progów, suma testów), `defense_surplus` / `attack_surplus` (nadwyżka najlepszego
  testu, ≥ 0), `duel_margin` (różnica nadwyżek, czyli o ile rozstrzygnął się pojedynek).
- **Warunek**: `cells` = pola akcji (miejsce efektu: pole docelowe, a przy bezpańskiej piłce pole wyjścia);
  puste = wszędzie. Np. pole karne = 5Ś.
- **Jeden rzut na slot**: odnogi po kolei, szanse się sumują (łącznie maks. 100%); gdy żadna nie wypadnie,
  działa zwykły efekt slotu. Kolejność ma znaczenie tylko wtedy, gdy suma przekracza 100%.
- Silnik rzuca tylko, gdy któraś odnoga ma dodatnią szansę, więc karty bez odnóg dają identyczne wyniki
  symulacji jak wcześniej.
- AI ocenia slot jako średnią wartości zdarzeń ważoną szansami odnóg, przyjmując miarę
  `MatchAI.BRANCH_ASSUMED_MEASURE` (1 pkt), bo przed rzutem jej nie zna.

Przykład (pomysł z 2026-10-27, nie wpisany do kart): slot `none_won` (nikt nie zapełnił, atak wygrał
pojedynek) z odnogami: 1) `penalty`, `defense_deficit`, 10% za każde 0,5, pola 5Ś; 2) `foul`, ta sama
szansa, pola wszystkie poza 5Ś.

### Łańcuchy zdarzeń (2026-10-27)

**Zdarzenie łańcucha** (`ChainEvent`, lista `events` w pliku) to własne zdarzenie: efekt albo odnoga jednej
karty i warunek dobierania (`triggers`) innych. Działa jak stały fragment: po nim losują się tylko karty
z tym zdarzeniem w warunkach (jeśli żadnej nie ma, gra toczy się kartami posiadania). Pola:
`id`, `name` (zwykły tekst, pokazywany na listach i w meczu), `ball` (`action` = miejsce akcji, `origin`,
`target`), `changes_possession` (piłkę w tym polu przejmuje rywal, np. kontra) i `hide_after_use`
(tylko edytor: gdy jedna karta ma zdarzenie w warunkach, znika ono z list warunków innych kart).

Jedno zdarzenie może łączyć wiele kart, np. „Dobitka” jako odnoga obrony bramkarza kilku kart strzału
i jedna karta dobitki. W edytorze: na liście zdarzeń pozycja „+ Nowe zdarzenie łańcucha…”, a sekcja
**Łańcuchy** karty pokazuje, kto zdarzenie wywołuje i jakie karty je kontynuują (przyciski przechodzą do
kart) oraz tworzy **kartę kontynuacji** (warunek = zdarzenie, pola wyjścia = pola, w których leży wtedy
piłka). Nieużywane zdarzenia znikają przy zapisie. AI ocenia zdarzenie łańcucha jak posiadanie (albo
stratę) w polu piłki – nie patrzy w głąb łańcucha.

### Efekty wyników

Miejsce akcji = pole docelowe, a przy bezpańskiej piłce (`none_won` / `none_lost`) pole wyjścia.
Zdarzenie staje się „sytuacją” drużyny, która ma piłkę po efekcie (warunki `triggers`).

| Efekt | Skutek (`MatchEngine._apply_effect`) |
|---|---|
| `advance` | piłka na pole docelowe |
| `goal` | gol, wznowienie rywala ze środka |
| `keep` (i `possession`) | piłka zostaje w polu wyjścia |
| `turnover` | rywal przejmuje piłkę w miejscu akcji |
| `interception` | rywal przejmuje piłkę w pierwszym polu przelotu (bez przelotu: w miejscu akcji) |
| `clearance` | rywal wybija piłkę `clearance_distance` (2) stref do przodu od miejsca akcji i ją ma |
| `goalkeeper_save` | piłka u bramkarza rywala (jego strefa 1, środek) |
| `offside` | rywal ma rzut wolny w miejscu akcji |
| `foul` | atakujący mają rzut wolny w miejscu akcji |
| `corner` | atakujący mają rzut rożny (strefa 5, skrzydło akcji; ze środka losowo L/P) |
| `penalty` | atakujący mają rzut karny (strefa 5, środek) |
| zdarzenie łańcucha | piłka w polu `ball` (atakujący albo – przy `changes_possession` – rywal) |

AI ocenia kartę według efektów wszystkich 6 slotów (`MatchAI.get_effect_value`; rzut karny wart
`penalty_value` × gol). Pojedynki AI nadal liczy jako 50/50. *Migracja 14 kart prototypu z kodu (dawne
`prototype_plays.gd`) dała identyczne wyniki symulacji; od wprowadzenia efektów, limitów testów i nowej
zasady pojedynku wyniki są już inne.*

### Rozstrzyganie karty

1. Atakujący wybiera kartę (i stronę, jeśli karta na to pozwala).
2. Przesunięcia: najpierw atakujący, potem obrońca może przesunąć jednego zawodnika o jedno pole na
   tę turę (2 energii).
3. Obie strony rzucają naraz.
4. Przerzuty: atakujący, potem obrońca (1 runda na stronę, `reroll_rounds`), 1 energii za kość.
   Płaci właściciel kości.
5. Układanie kości (od 2026-10-27, ekran meczu): najpierw atakujący, potem obrońca (widzi już ułożenie ataku)
   wkłada wyrzucone kości do miejsc w testach. Test ma tyle miejsc, ile wynosi jego limit (`max_dice`), kość
   trafia do jednego testu, a ścianka musi mieć cechę testu. **Liczą się tylko kości w miejscach.** AI układa
   najlepsze kości każdego testu (`PlayContest.get_auto_placement`) i tak samo liczy symulacja, więc dla niej
   nic się nie zmienia. Gracz może też ułożyć gorzej albo wybrać inny test dla ścianki, która pasuje do dwóch.
6. Wynik według macierzy:

| | Obrona zapełniła | Obrona nie zapełniła |
|---|---|---|
| **Atak zapełnił** | **Pojedynek**: efekt `duel_won` albo `duel_lost` | **Sukces**: efekt `success` |
| **Atak nie zapełnił** | **Obrona**: efekt `defense` | **Bezpańska piłka**: pojedynek, efekt `none_won` albo `none_lost` |

- **Pojedynek**: wygrywa strona z większą **nadwyżką punktów** ponad próg. Przy kilku testach („i”) liczy się
  test z największą nadwyżką. Przy bezpańskiej piłce nadwyżki są ujemne i wygrywa mniejszy brak. Remis
  rozstrzyga los. *Do 2026-10-27 wygrywał wyższy stosunek punktów do progu (premiował niskie progi
  podwójnie), potem przez chwilę suma nadwyżek wszystkich testów.*
- Domyślne efekty kart: sukces i wygrany pojedynek = `advance` (`goal` przy strzale), przegrany pojedynek =
  `keep` albo `turnover`, obrona = `turnover`, bezpańska piłka = `keep` / `turnover`.

Każda karta ma więc **profil ryzyka**. Bezpieczna tiki-taka ma niskie progi, mały postęp i `keep`.
Laga ma duży postęp, trudne progi i `turnover`.

*Zmiana po symulacji:* pierwotnie remis kończył się zwykłym `keep`. W gęstym środku pola obie strony
prawie zawsze zapełniały wymagania i akcje stały w miejscu (0,2–0,3 gola na mecz). Pojedynek przy
każdym remisie to naprawił.

### Strzał i bramkarz

Karty strzału (np. „Strzał”, „Dośrodkowanie”, „Strzał z dystansu”) przy sukcesie dają gola. Bramkarz
broniących zawsze bierze w nich udział w 100%. Odbiór przy strzale to obrona bramkarza (piłka dla
broniących w ich strefie 1). Po golu wznawia drużyna, która straciła bramkę, w strefie 3, w środku.

## Czas meczu

- Jedna tura to jedna rozegrana karta. Mecz: 2 połowy × 15 tur (`turns_per_half`).
- Minuta na zegarze jest wyliczana (90 / 30 = 3 minuty na turę).
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
maksimum swoich kości. Suma slotów lekko zaniża szanse. Pojedynek AI wciąż liczy jako 50/50.

- **Wybór karty i strony**: `wartość = Σ P(wynik) · wartość_stanu_po_wyniku`. Wartość stanu to
  „ile wart jest posiadanie piłki w strefie z” (tabela `possession_value`). Gol jest wart 1, a strata
  piłki to minus wartość posiadania rywala. Profil trenera (`risk_aversion`) skaluje straty, więc dostajemy
  różnych przeciwników prawie za darmo. Przegrywająca drużyna w końcówce ryzykuje więcej.
- **Przerzuty**: jeśli strona nie zapełniła wymagań, przerzuca kości o największym oczekiwanym zysku,
  aż oczekiwany zysk pokryje brak. Tempo wydawania to energia drużyny podzielona przez pozostałe tury,
  przemnożona przez wagę akcji.
- **Przesunięcia**: AI liczy, o ile wzrośnie szansa zapełnienia wymagań po przesunięciu każdego
  kandydata. Przesuwa najlepszego, jeśli wzrost przekracza próg i mieści się w budżecie.
- **Układanie kości**: AI wkłada do każdego testu jego najlepsze kości (do limitu). Nie próbuje sprytniej
  dzielić ścianek pasujących do dwóch testów – kandydat do ulepszenia, jeśli gracze zaczną to wykorzystywać.

Ta sama funkcja szans posłuży do szybkiej, statystycznej symulacji meczów innych lig
([world_scale.md](../architecture/world_scale.md), poziomy szczegółowości).

### Ekran meczu: gracz kontra komputer

Menu → Rozegraj mecz → skład → mecz (`scenes/match/`). Gracz prowadzi gospodarzy, komputer gości. Ekran
wywołuje kroki tury silnika (`MatchEngine.begin_turn` → `set_play` / `choose_ai_play` → `apply_shift` /
`ai_shift` → `roll` → `reroll` / `ai_rerolls` → rozmieszczenie kości → `finish_turn`), a symulacja AI kontra
AI przechodzi te same kroki w `_play_turn` (identyczne wyniki jak przed podziałem na kroki).

Decyzje gracza w turze:
- **atak**: wybór karty z ręki (najechanie pokazuje zagranie na boisku), przy kilku celach – kliknięcie pola
  docelowego; potem jak w obronie;
- **obie strony**: przesunięcie jednego zawodnika o pole (kliknij zawodnika, potem pole), przerzut wybranych
  kości, ułożenie kości w miejscach testów (przeciągnij albo kliknij kość; „Ułóż najlepiej” = jak AI).

Ruchy komputera (karta, przesunięcie, przerzuty, ułożenie kości) są pokazywane z krótką pauzą.

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
  nakładka zagrania (udział pól w %, pole wyjścia, cel, przelot);
- po rzucie (wariant 7 z makiet, 2026-10-27): zawodnik z kośćmi w akcji to **plakietka** (`DicePlate`) –
  jego kości zamiast koszulki, pod nimi numer w kolorze drużyny, nazwisko i pasek energii, w ramce
  w kolorze drużyny; wokół kości poświata w kolorze koszulek (siła: Opcje → „Poświata drużyny wokół kości”).
  Nachodzące plakietki rozsuwają się, po przesunięciu zawodnika plakietka stoi w nowym polu. Zawodnicy bez
  kości w akcji są w tym czasie kropkami w kolorze stroju;
- po prawej: wynik i minuta, **oś meczu** w jednym wierszu (30 wąskich kafelków, przerwa = odstęp; kolor =
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
- Czy 30 tur daje sensowną liczbę goli i akcji?
- Czy boczni obrońcy wnoszą porównywalny wkład do środkowych (raport: punkty na rolę)?
- Czy obrona (bez piłki) ma dość decyzji? Kandydat na później: postawy obronne (pressing / średni / niski
  blok) albo krótka talia kart obronnych.
- Zmiana taktyki w meczu: 3 przygotowane taktyki, koszt 1 energii każdemu na boisku?
