class_name MatchPlayer
extends RefCounted
## Stan zawodnika w trakcie meczu (pozycja na siatce, aktywne kości, energia, statystyki).
## Pozycja trzymana jest w perspektywie własnej drużyny: strefa 1 = przy własnej bramce, kanał 0 = lewy.

var data: PlayerData
var role_id: StringName
## Pozycja w formacji (ekran meczu ustawia żeton tak jak boisko przedmeczowe).
var formation_slot: FormationSlot
var zone: int = 1
var channel: int = MatchRules.CHANNEL_CENTER
var dice: Array[DieData] = []
var role_fit: float = 1.0
## Forma jako zmiana skuteczności (-0.15 … +0.15). Prototyp: 0.
var form: float = 0.0
var energy: int = 0
var max_energy: int = 0
## Przesunięcie na bieżącą turę (strefa, kanał) w perspektywie własnej drużyny.
var shift := Vector2i.ZERO

# --- Statystyki meczu ---
var points_attack: float = 0.0
var points_defense: float = 0.0
## Punkty z kości trafiających w wymagania, ale odciętych limitem najlepszych kości.
var points_attack_cut: float = 0.0
var points_defense_cut: float = 0.0
var energy_spent: int = 0


static func create(player: PlayerData, slot: FormationSlot, active_dice: Array[DieData], rules: MatchRules) -> MatchPlayer:
	var match_player := MatchPlayer.new()
	match_player.data = player
	match_player.role_id = slot.role_id
	match_player.formation_slot = slot
	match_player.zone = slot.lane
	match_player.channel = rules.get_channel(slot.x)
	match_player.dice = active_dice
	match match_player.data.get_role_fit(slot.role_id):
		PlayerData.RoleFit.NATURAL:
			match_player.role_fit = rules.role_fit_natural
		PlayerData.RoleFit.SECONDARY:
			match_player.role_fit = rules.role_fit_secondary
		_:
			match_player.role_fit = rules.role_fit_none
	match_player.max_energy = rules.start_energy
	match_player.energy = rules.start_energy
	return match_player


func is_goalkeeper() -> bool:
	return role_id == PositionData.GOALKEEPER


## Pole zawodnika z formacji w perspektywie własnej drużyny (bez przesunięcia na tę turę).
func get_base_cell() -> Vector2i:
	return Vector2i(zone, channel)


## Pole zawodnika w perspektywie drużyny z piłką (z uwzględnieniem przesunięcia na tę turę).
func get_cell(own_team_attacking: bool) -> Vector2i:
	var own := get_base_cell() + shift
	if own_team_attacking:
		return own
	return Vector2i(MatchRules.ZONE_COUNT + 1 - own.x, MatchRules.CHANNEL_COUNT - 1 - own.y)


## Skuteczność kości zawodnika (bez wagi udziału, która zależy od pola akcji).
func get_die_efficiency(die: DieData, rules: MatchRules) -> float:
	var efficiency := role_fit * (1.0 + form)
	if energy <= 0:
		efficiency *= rules.exhausted_efficiency
	if die.type.id == &"technical":
		efficiency *= rules.pitch_technical
	return efficiency


func spend_energy(amount: int) -> void:
	energy -= amount
	energy_spent += amount


func restore_energy(amount: int) -> void:
	energy = mini(energy + amount, max_energy)
