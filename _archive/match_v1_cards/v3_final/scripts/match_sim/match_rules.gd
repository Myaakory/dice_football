class_name MatchRules
extends RefCounted
## Parametry silnika meczu. PROTOTYP – opis zasad: res://docs/design/match_rules.md.
## Po ustabilizowaniu wartości trafią do arkusza (zakładka match_params), na razie są tutaj,
## a symulacja może je nadpisać argumentami (np. support_weight=0.7).

const ZONE_COUNT := 5
const CHANNEL_COUNT := 3
const CHANNEL_LEFT := 0
const CHANNEL_CENTER := 1
const CHANNEL_RIGHT := 2

# --- Czas ---
## Tur w połowie; pierwsza tura połowy zaczyna się w 0' / 45', ostatnia w 45' / 90' (MatchEngine.get_minute).
var turns_per_half: int = 16

# --- Udział zawodników (waga w skuteczności) ---
## Pole sąsiadujące z polem akcji (bok albo przód/tył).
var support_weight: float = 0.6
## Pole po drugiej stronie boiska w tej samej strefie (np. lewe skrzydło przy akcji prawym).
var far_side_weight: float = 0.3
## Pole skośne (sąsiednia strefa i sąsiedni korytarz).
var diagonal_weight: float = 0.3
## Atakujący stojący w polu, z którego zagrywana jest piłka (podający).
var passer_weight: float = 0.6
## Obrońca w polu, nad którym leci dłuższe podanie.
var flyover_weight: float = 0.5

# --- Skuteczność ---
var role_fit_natural: float = 1.0
var role_fit_secondary: float = 0.85
var role_fit_none: float = 0.65
var exhausted_efficiency: float = 0.7
## Mnożnik kości technicznych zależny od murawy (1.0 = dobra, 0.8 = zła).
var pitch_technical: float = 1.0

## Ile najlepszych kości liczy się w każdym teście: -1 = według testu (PlayRequirement.max_dice),
## 0 = wszystkie, n = n w każdym teście (nadpisanie do eksperymentów).
var max_dice_used: int = -1

# --- Efekty wyników ---
## O ile stref (z perspektywy broniących) obronny wykop wyrzuca piłkę od miejsca akcji.
var clearance_distance: int = 2
## Wartość rzutu karnego dla AI jako ułamek wartości gola.
var penalty_value: float = 0.6

# --- Energia ---
var start_energy: int = 6
var halftime_energy: int = 2
var reroll_cost: int = 1
var shift_cost: int = 2
## Ile rund przerzutów ma każda strona w jednej akcji.
var reroll_rounds: int = 1

# --- Karty ---
var hand_size: int = 3

# --- Granice kanałów (x formacji 0..1) ---
var channel_left_max: float = 0.25
var channel_right_min: float = 0.75

# --- AI ---
## Wartość posiadania piłki w strefie 1..5 (perspektywa posiadającego), w „golach”.
var possession_value: Array[float] = [0.01, 0.03, 0.06, 0.12, 0.25]
## Mnożnik tempa wydawania energii (1.0 = równo rozłożona na pozostałe tury).
var reroll_pacing: float = 1.5
## Typowa stawka akcji – stawki większe od niej pozwalają wydać więcej energii.
var reference_stake: float = 0.15
## Minimalny wzrost szansy zapełnienia wymagań, przy którym AI przesuwa zawodnika.
var min_shift_gain: float = 0.08


func get_total_turns() -> int:
	return turns_per_half * 2


func get_possession_value(zone: int) -> float:
	return possession_value[clampi(zone, 1, ZONE_COUNT) - 1]


func get_channel(x: float) -> int:
	if x < channel_left_max:
		return CHANNEL_LEFT
	if x > channel_right_min:
		return CHANNEL_RIGHT
	return CHANNEL_CENTER


## Nadpisuje parametry wartościami tekstowymi (np. z argumentów symulacji). Zwraca nieznane klucze.
func apply_overrides(overrides: Dictionary) -> Array[String]:
	var unknown: Array[String] = []
	for key: String in overrides:
		if not key in self:
			unknown.append(key)
			continue
		var text: String = overrides[key]
		match typeof(get(key)):
			TYPE_INT:
				set(key, text.to_int())
			TYPE_FLOAT:
				set(key, text.to_float())
			_:
				unknown.append(key)
	return unknown


static func channel_letter(channel: int) -> String:
	return ["L", "C", "R"][channel]
