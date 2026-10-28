# Skala świata gry i zasady wydajności

> **Obowiązuje każdego, kto dodaje nowe systemy do gry** (ludzi i agentów AI).
> Każdy nowy element (transfery, kontuzje, statystyki, historia, UI list graczy itd.)
> musi działać przy pełnej skali świata opisanej poniżej, nie tylko przy kilku drużynach z prototypu.

Status: decyzje projektowe (2026-10-26), jeszcze niezaimplementowane. Liczby wydajnościowe to szacunki,
do potwierdzenia benchmarkiem w Godot 4.7.2.

## Docelowa skala

| Element | Ilość |
|---|---|
| Ligi | do ~50 |
| Drużyny w lidze | 16 → **~800 drużyn** |
| Gracze w drużynie | ~25 → **~20 000 graczy** (+ wolni agenci, juniorzy) |
| Mecze na kolejkę | ~400 (50 × 8) |
| Horyzont rozgrywki | 10–20+ sezonów w jednym zapisie |

Świat jest **generowany losowo na starcie** (z parametrów i seeda), potem trzymany w zapisie i zmieniany przez rozgrywkę.

## 1. Dwa rodzaje danych

| | Zawartość | Gdzie |
|---|---|---|
| **Definicje** (statyczne) | typy kości, pozycje, role, taktyki, pule imion, parametry generatora (siła lig, rozkład wieku, krzywe rozwoju) | CSV w `data/` synchronizowane z Google Sheet |
| **Stan świata** (dynamiczny) | konkretni gracze, kości, kontrakty, tabele, statystyki, historia | plik zapisu (binarny), **nie CSV** |

- Nie dopisuj wygenerowanych graczy/drużyn świata do CSV ani do arkusza.
- Nowe *parametry* generatora / symulacji → arkusz/CSV. Nowe *dane stanu* → model świata + zapis.

## 2. Zapis gry

- Format docelowy: `FileAccess.open_compressed()` + `store_var()` / `var_to_bytes()` na drzewie
  `Dictionary` / `Array` / `Packed*Array`. Na etapie debugowania dopuszczalny JSON.
- Każda klasa danych ma `to_dict()` / `from_dict()`. Serializacja nie zależy od konkretnego formatu pliku.
- Zapis zawiera `save_version`. Zmiana struktury danych = podbicie wersji + migracja.
- **Nie używać `.tres`/`.res` dla stanu świata** (wolne przy tysiącach sub-resource'ów, a ładowanie cudzych `.tres` może wykonać kod).
- SQLite rozważyć dopiero, gdy rekordów będą setki tysięcy lub potrzebne będą złożone zapytania.
- Zapis/odczyt docelowo w tle (wątek), żeby nie zamrażać UI.

## 3. Model w pamięci

- **Gracze, drużyny i ligi to nie są Node'y.** To lekkie klasy `RefCounted` (lub `Dictionary`).
  Node'y tworzy się tylko dla tego, co jest akurat wyświetlane (np. widoczne wiersze listy).
- **Relacje przez int ID**, nie przez referencje obiektów:
  `World.players: Dictionary[int, PlayerData]`, drużyna ma `PackedInt32Array player_ids`.
  Brak cykli = prosta serializacja.
- Wartości liczbowe w miarę możliwości jako `int` / `Packed*Array`, nie stringi.
- Generator jest **deterministyczny** z seeda świata (`RandomNumberGenerator`), żeby dało się odtworzyć świat w testach i przy balansie.

## 4. Zapytania i indeksy

- Pełny przegląd 20 tys. graczy w GDScript to kilka ms: OK **raz** na turę/sezon, **nie** wewnątrz pętli.
  Przykład błędu: „dla każdej z 800 drużyn przeszukaj wszystkich graczy” = ~16 mln operacji.
- Częste zapytania obsługują **indeksy** utrzymywane przy zmianach, np. `free_agents`,
  `players_by_position`, `players_by_team`. Każdy system, który zmienia przynależność lub pozycję
  gracza, musi aktualizować indeksy (najlepiej przez jedną funkcję `World`, nie ręcznie).
- Listy w UI (wyszukiwarka graczy, tabele) muszą stronicować lub wirtualizować wiersze, a nie tworzyć 20 tys. kontrolek.

## 5. Symulacja meczów: poziomy szczegółowości

- **Liga gracza** (i oglądane mecze): pełna symulacja kośćmi.
- **Pozostałe ligi**: szybka symulacja statystyczna (np. Poisson na podstawie siły składów), mikrosekundy na mecz.
- Jeśli pełna symulacja ma działać wszędzie: budżet ~1 ms/mecz → ~0,4 s/kolejkę. Dopuszczalne za ekranem
  „symulowanie kolejki…”, ewentualnie `WorkerThreadPool`. Najpierw zmierz, potem optymalizuj.
- Logika symulacji meczu nie może zależeć od Node'ów/sceny. Ma działać na czystych danych (potrzebne do wątków i szybkiej symulacji).

## 6. „Życie” świata: budżet

Tanie, możliwe (liniowo po graczach, raz na turę lub sezon):
- starzenie, rozwój i regres (zmiany kości/atrybutów raz na sezon),
- kontuzje, forma, zmęczenie,
- emerytury + **generowanie juniorów** (populacja ma być stabilna, ~20 tys.),
- awanse i spadki.

Drogie, wymagają ostrożności:
- **Transfery AI**: indeksy po pozycji i sile, okna transferowe zamiast decyzji co turę, limit prób na drużynę.
- **Historia**: rośnie w nieskończoność. Trzymać **zagregowane statystyki per sezon**, nie zdarzenia z każdego meczu.
  Szczegółowe logi tylko dla bieżącego sezonu i ligi gracza. Emerytowanych graczy kompresować do krótkiego
  rekordu „legendy” albo usuwać.

Cel: zapis po 10–20 sezonach rzędu kilku MB, odczyt < 1 s.

## 7. Proponowana struktura kodu

```
data/*.csv              ← definicje z arkusza (bez zmian)
scripts/world/
  world_state.gd        ← RefCounted: players, teams, leagues, season, seed, indeksy
  player_data.gd        ← RefCounted + to_dict()/from_dict()
  world_generator.gd    ← tworzy świat z parametrów + seed
  season_sim.gd         ← kolejka: pełna / szybka symulacja, koniec sezonu
  save_system.gd        ← store_var + open_compressed, save_version
```

## Checklista dla nowego systemu

- [ ] Działa przy ~800 drużynach / ~20 000 graczy (sprawdzone lub oszacowane)?
- [ ] Brak pętli zagnieżdżonych po wszystkich graczach; częste wyszukiwania przez indeks?
- [ ] Dane stanu serializowane przez `to_dict()`/`from_dict()`, wersja zapisu podbita przy zmianie?
- [ ] Brak Node'ów per gracz/drużyna?
- [ ] Ograniczony przyrost danych w czasie (agregacja historii)?
- [ ] Parametry balansu w arkuszu/CSV, nie na sztywno w kodzie?
