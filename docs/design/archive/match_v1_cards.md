# Archiwum: system meczu v1 „Karty na siatce 3 × 5” (stan na 2026-10-28)

Ten dokument pozwala odtworzyć system meczu sprzed uproszczenia (plan nowego systemu:
[../match_v2_plan.md](../match_v2_plan.md)). Pełny opis zasad z tamtego dnia:
[match_rules_v1.md](match_rules_v1.md) (zamrożona kopia `docs/design/match_rules.md`).

## Gdzie jest kod

Pełna kopia plików jest w `_archive/match_v1_cards/` (folder z `.gdignore`, Godot go nie importuje):

| W archiwum | Skąd | Co to jest |
|---|---|---|
| `scripts/match_sim/` | `scripts/match_sim/` | silnik (czyste dane): `MatchEngine`, `PlayContest`, `MatchAI`, `DiceOdds`, `PlayCard`, `PlayRequirement`, `OutcomeBranch`, `ChainEvent`, `PlayEvents`, `PlayLibrary`, `MatchRules`, `MatchStats`, `MatchTeam`, `MatchPlayer`, `MatchConditions` |
| `scenes/match/` | `scenes/match/` | ekran meczu gracz kontra komputer (`match.gd`, `match_pitch.gd`, `play_card_view.gd`, `tests_panel.gd`, `dice_plate.gd`, `match_die.gd`, `match_timeline.gd`, `stadium_view.gd`) |
| `scenes/play_editor/` | `scenes/play_editor/` | Edytor zagrań (karty, testy, wyniki, odnogi, łańcuchy) |
| `scenes/dev/` | `scenes/dev/` | symulacja AI kontra AI z raportem |
| `data/plays/plays.json` | `data/plays/plays.json` | 15 kart, format v3 |
| `scripts/pitch_layout.gd` | `scripts/utils/pitch_layout.gd` | geometria boiska (używa `MatchRules`) |
| `localization/translations.csv` | `localization/translations.csv` | teksty (klucze `MATCH_*`, `PLAY_*`, `EDITOR_*`) |
| `docs/match_rules.md` | `docs/design/match_rules.md` | zasady |
| `baseline_sim_200_seed1.txt` | – | raport symulacji do sprawdzenia odtworzenia |

Pozostałe zależności (dane drużyn i kości, `GameData`, `GameState`, grafiki kości, `PitchBuilder`, `StadiumView`
z komponentów) nie były zmieniane przy archiwizacji – jeśli zmienią się później, przy odtwarzaniu trzeba je dopasować.

## Jak przywrócić

1. Skopiuj foldery z `_archive/match_v1_cards/` na ich miejsca (tabela wyżej). Pliki `.uid` kopiuj razem
   ze skryptami – sceny odwołują się do nich.
2. Przywróć klucze tłumaczeń (wystarczy podmienić cały `translations.csv` albo dokleić brakujące klucze).
3. `Godot_v4.7.2-stable_win64_console.exe --headless --path . --import`
4. Sprawdzenie: `... --headless --path . res://scenes/dev/match_sim.tscn -- matches=200 seed=1`
   musi dać **3,18 gola na mecz, wyniki RRV 58 / remisy 64 / BCU 78** (pełny raport w `baseline_sim_200_seed1.txt`).
   Inny wynik = zmieniły się dane drużyn / kości albo któryś plik nie wrócił.

## Rdzeń zasad w jednej stronie (do odtworzenia od zera)

1. **Boisko**: siatka 5 stref (od własnej bramki) × 3 korytarze (L, Ś, P). Rywal widzi ją lustrzanie
   (strefa `6 − s`, korytarz `2 − k`). Piłka leży w jednym polu.
2. **Tura** = jedna karta. 2 × 15 tur, 3 minuty na turę, połowę zaczyna gospodarz / gość ze strefy 3Ś.
3. **Ręka**: 3 losowe karty z talii taktyki pasujące do pola piłki (`origins`) i do ostatniego zdarzenia
   (`triggers`: posiadanie, odbiór, stałe fragmenty, zdarzenia łańcuchów).
4. **Karta**: ruch piłki (`advance` + kierunek: przed siebie / na boki z wyborem / do środka / ręczne cele),
   testy ataku i obrony (łączone „i”; test = próg punktów + cechy łączone „lub” z wagami + limit kości `max_dice`),
   6 slotów wyniku (`success`, `duel_won`, `duel_lost`, `defense`, `none_won`, `none_lost`) ze zdarzeniem,
   opcjonalnym przejściem zawodnika (`move_player`) i odnogami (szansa zależna od nadwyżki / braku punktów).
5. **Udział**: zawodnik rzuca 2 aktywne kości, jeśli stoi w polu docelowym (100%), sąsiednim (60%), skośnym albo
   po drugiej stronie (30%), w polu podającego (≥ 60%), pod przelotem długiej piłki (obrońcy ≥ 50%);
   bramkarz w strzałach 100%. Punkty ścianki × skuteczność (udział × rola 100/85/65% × wyczerpanie 70% ×
   murawa dla kości technicznych).
6. **Kolejność**: wybór karty (i celu) → przesunięcie jednego zawodnika o pole (2 energii; atak, potem obrona)
   → rzut wszystkich kości → jedna runda przerzutów (1 energii za kość; atak, potem obrona) → układanie kości
   w miejscach testów (atak, potem obrona; liczą się tylko kości w miejscach) → rozstrzygnięcie.
7. **Macierz**: atak zapełnił / obrona nie → `success`; obie → pojedynek nadwyżek (`duel_won` / `duel_lost`);
   tylko obrona → `defense`; nikt → pojedynek mniejszego braku (`none_won` / `none_lost`). Remis nadwyżek = los.
8. **Efekty**: `advance`, `goal`, `keep`, `turnover`, `interception` (pierwsze pole przelotu), `clearance`
   (+2 strefy dla rywala), `goalkeeper_save` (bramkarz rywala), `foul`, `corner`, `penalty`, `offside`,
   zdarzenia łańcuchów (własne pole piłki, opcjonalna zmiana posiadania).
9. **Energia**: 6 na mecz, +2 w przerwie, 0 = wyczerpanie (skuteczność 70%).
10. **AI**: przybliżenie normalne sumy punktów → P(zapełnienia testu); wartość karty = Σ P(wynik) × wartość stanu
    (tabela `possession_value` 0,01…0,25, gol = 1); budżet energii = energia / pozostałe tury × waga akcji;
    przesunięcie, gdy szansa rośnie o ≥ 8 pp.

## Ekran meczu v1 (dla porównania)

Stadion z boiskiem po lewej, po prawej: wynik, oś meczu (30 wąskich kafelków), ręka 3 kart w poziomych
wierszach (najechanie = podgląd na boisku, klik = wybór, potem klik pola docelowego na boisku przy kartach
„na boki”), karta + panel testów z miejscami na kości, pasek decyzji, warunki meczu. Kości po rzucie na
plakietkach zawodników (obie drużyny tak samo wyraźne).
