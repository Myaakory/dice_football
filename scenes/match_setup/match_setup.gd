extends Control
## Ekran przygotowania do meczu: wybór taktyki, pierwszej jedenastki i aktywnych kości zawodników.
## Gracz prowadzi drużynę GameState.PLAYER_TEAM_ID, rywala prowadzi komputer.
##
## Kliknięcie zawodnika (na boisku lub na liście) pokazuje jego szczegóły w panelu,
## kliknięcie nazwiska na liście otwiera pełną kartę zawodnika.
## Kliknięcie strefy boiska zamienia listę kadry na panel strefy (zagrania taktyczne i kości zawodników).
## Przeciągnięcie zawodnika na innego zamienia ich miejscami (boisko ↔ boisko ↔ ławka).
## Lista kadry nie zmienia kolejności po zamianach – przestawia ją dopiero sortowanie.

## Strefa przy krawędzi listy, w której przeciąganie przewija listę (px) i prędkość przewijania (px/s).
const DRAG_SCROLL_EDGE := 28.0
const DRAG_SCROLL_SPEED := 420.0

@onready var _pitch_view: PitchView = %PitchView
@onready var _team_name_label: Label = %TeamNameLabel
@onready var _opponent_button: LinkButton = %OpponentButton
@onready var _tactic_option: OptionButton = %TacticOption
@onready var _tactic_description: Label = %TacticDescription
@onready var _content: Control = %Content
@onready var _zone_scroll: ScrollContainer = %ZoneScroll
@onready var _zone_panel: ZonePanel = %ZonePanel
@onready var _margin: Control = $Margin
@onready var _squad_header: SquadHeader = %SquadHeader
@onready var _squad_scroll: ScrollContainer = %SquadScroll
@onready var _squad_list: VBoxContainer = %SquadList
@onready var _player_details: VBoxContainer = %PlayerDetails
@onready var _back_button: Button = %BackButton
@onready var _auto_pick_button: Button = %AutoPickButton
@onready var _start_button: Button = %StartButton

var _lineup: Lineup
## Zawodnik, którego szczegóły są pokazane w panelu (i który jest podświetlony).
var _detail_player: PlayerData
var _rows: Dictionary[StringName, SquadRow] = {}
var _sort_mode := SquadHeader.SortMode.PITCH
var _sort_descending := false
## Zaznaczona strefa boiska (0 = brak, widoczna lista kadry).
var _selected_zone := 0
## Otwarty pełnoekranowy widok (karta zawodnika / podgląd rywala) albo null.
var _overlay: Control
var _toast: ToastMessage


func _ready() -> void:
	for tactic in GameData.get_tactic_list():
		_tactic_option.add_item(tactic.name)

	_tactic_option.item_selected.connect(_on_tactic_selected)
	_pitch_view.slot_pressed.connect(_on_pitch_slot_pressed)
	_pitch_view.player_dropped.connect(_on_pitch_player_dropped)
	_pitch_view.zone_pressed.connect(_on_zone_pressed)
	_zone_panel.close_requested.connect(_select_zone.bind(0))
	_opponent_button.pressed.connect(_on_opponent_pressed)
	_squad_header.sort_requested.connect(_on_sort_requested)
	_back_button.pressed.connect(_on_back_pressed)
	_auto_pick_button.pressed.connect(_on_auto_pick_pressed)
	_start_button.pressed.connect(_on_start_pressed)

	_toast = ToastMessage.new()
	add_child(_toast)

	# Po powrocie z meczu przywracamy poprzednio ustawiony skład.
	if GameState.player_lineup != null:
		_set_lineup(GameState.player_lineup)
	else:
		_set_lineup(Lineup.create_default(GameState.get_player_team()))


func _process(delta: float) -> void:
	_update_drag_scroll(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if _selected_zone != 0:
			_select_zone(0)
		elif _detail_player != null:
			_detail_player = null
			_refresh()
		else:
			_on_back_pressed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _lineup != null:
		_update_team_labels()
		_refresh()


# --- Skład ---

func _set_lineup(lineup: Lineup) -> void:
	if _lineup != null:
		_lineup.changed.disconnect(_refresh)
	_lineup = lineup
	_lineup.changed.connect(_refresh)
	_detail_player = null

	_update_team_labels()
	_rebuild_squad_list()
	_sort_mode = SquadHeader.SortMode.PITCH
	_sort_descending = false
	_apply_sort()
	_refresh()


func _rebuild_squad_list() -> void:
	for child in _squad_list.get_children():
		_squad_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	for player in _lineup.team.players:
		var row := SquadRow.new()
		row.pressed.connect(_on_squad_row_pressed.bind(player))
		row.name_pressed.connect(_open_player_details.bind(player))
		row.player_dropped.connect(_on_row_player_dropped.bind(player))
		_squad_list.add_child(row)
		_rows[player.id] = row


func _refresh() -> void:
	_tactic_option.select(GameData.get_tactic_list().find(_lineup.tactic))
	_tactic_description.text = tr(_lineup.tactic.description_key)

	_pitch_view.selected_slot = _lineup.get_player_slot(_detail_player) if _detail_player != null else -1
	_pitch_view.set_lineups(_lineup)

	for player in _lineup.team.players:
		var row := _rows[player.id]
		row.setup(player, _get_pitch_label(player), _lineup.is_starter(player),
				_lineup.get_active_dice_indices(player), _lineup.team.primary_color)
		row.set_pressed_no_signal(player == _detail_player)

	_refresh_details()
	if _selected_zone != 0:
		_zone_panel.refresh()


func _update_team_labels() -> void:
	_team_name_label.text = _lineup.team.name
	_team_name_label.add_theme_color_override(&"font_color", _lineup.team.primary_color.lightened(0.35))
	_opponent_button.text = tr("SETUP_OPPONENT") % GameState.get_opponent_team(_lineup.team).name


## Skrót roli na boisku albo oznaczenie rezerwowego (R1, R2...).
func _get_pitch_label(player: PlayerData) -> String:
	var slot_index := _lineup.get_player_slot(player)
	if slot_index != -1:
		var role := GameData.get_role(_lineup.tactic.slots[slot_index].role_id)
		return tr(role.short_key) if role != null else "?"
	return tr("SETUP_RESERVE_SHORT") % (_lineup.get_bench_index(player) + 1)


func _refresh_details() -> void:
	for child in _player_details.get_children():
		_player_details.remove_child(child)
		child.queue_free()

	var player := _detail_player
	if player == null:
		var hint := _add_detail_label(tr("SETUP_NO_PLAYER_SELECTED"), 14)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return

	_add_detail_label(player.get_full_name(), 22)
	# Kości jako sumy oczek (jak na liście kadry); najechanie pokazuje całą kość.
	var dice_row := HBoxContainer.new()
	dice_row.add_theme_constant_override(&"separation", 4)
	for die_index in player.dice.size():
		var badge := DieTotalBadge.new()
		badge.setup(player.dice[die_index], _lineup.is_die_active(player, die_index))
		dice_row.add_child(badge)
	_player_details.add_child(dice_row)
	var player_position := GameData.get_position(player.position_id)
	var position_name := tr(player_position.name_key) if player_position != null else str(player.position_id)
	_add_detail_label("#%d  ·  %s" % [player.number, position_name], 14).modulate = Color(1, 1, 1, 0.75)

	var slot_index := _lineup.get_player_slot(player)
	if slot_index != -1:
		var slot := _lineup.tactic.slots[slot_index]
		var role := GameData.get_role(slot.role_id)
		_add_detail_label(tr("SETUP_ON_PITCH") % [tr(role.name_key), slot.lane], 14)
	else:
		_add_detail_label(tr("SETUP_ON_BENCH") % (_lineup.get_bench_index(player) + 1), 14)

	_player_details.add_child(HSeparator.new())
	_add_detail_label(tr("SETUP_ACTIVE_DICE") % [Lineup.ACTIVE_DICE_COUNT, player.dice.size()], 14)
	for die_index in player.dice.size():
		var die_view := DieView.new()
		die_view.setup(player.dice[die_index], _lineup.is_die_active(player, die_index))
		die_view.pressed.connect(_on_die_pressed.bind(player, die_index))
		_player_details.add_child(die_view)


func _add_detail_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	_player_details.add_child(label)
	return label


## Komunikat na środku ekranu, dlaczego mecz nie może się zacząć.
func _show_lineup_errors() -> void:
	var lines: Array[String] = [tr("SETUP_CANNOT_START"),
			tr("SETUP_STARTERS_COUNT") % [_lineup.get_starters().size(), _lineup.tactic.get_slot_count()]]
	for error_key in _lineup.validate():
		lines.append("– " + tr(error_key))
	_toast.show_message("
".join(lines))


# --- Sortowanie listy kadry ---

func _apply_sort() -> void:
	var players := _lineup.team.players.duplicate()
	var keys := {}
	for player in players:
		keys[player] = _get_sort_key(player)
	players.sort_custom(func(a: PlayerData, b: PlayerData) -> bool: return keys[a] < keys[b])
	if _sort_descending:
		players.reverse()
	for i in players.size():
		_squad_list.move_child(_rows[players[i].id], i)
	_squad_header.set_active(_sort_mode, _sort_descending)


func _get_sort_key(player: PlayerData) -> Array:
	match _sort_mode:
		SquadHeader.SortMode.NUMBER:
			return [player.number]
		SquadHeader.SortMode.POSITION:
			return [GameData.get_position_order(player.position_id), player.number]
		SquadHeader.SortMode.NAME:
			return [_collation_key(player.last_name), _collation_key(player.first_name)]
	# PITCH: pierwsza jedenastka (bramkarz, potem pasami od obrony, w pasie od prawej do lewej), potem R1, R2...
	var slot_index := _lineup.get_player_slot(player)
	if slot_index != -1:
		var slot := _lineup.tactic.slots[slot_index]
		var is_keeper := slot.role_id == PositionData.GOALKEEPER
		return [0, 0 if is_keeper else 1, slot.lane, -slot.x, slot.index]
	return [1, _lineup.get_bench_index(player)]


## Klucz sortowania alfabetycznego uwzględniający polskie litery (ą po a, ł po l itd.).
static func _collation_key(text: String) -> String:
	var key := text.to_lower()
	for letter in ["ą", "ć", "ę", "ł", "ń", "ó", "ś", "ź"]:
		key = key.replace(letter, _strip_accent(letter) + "~")
	return key.replace("ż", "z~~")


static func _strip_accent(letter: String) -> String:
	return {"ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n", "ó": "o", "ś": "s", "ź": "z"}[letter]


func _on_sort_requested(mode: SquadHeader.SortMode) -> void:
	_sort_descending = not _sort_descending if mode == _sort_mode else false
	_sort_mode = mode
	_apply_sort()


# --- Wybór i zamiany ---

func _on_pitch_slot_pressed(_lineup_clicked: Lineup, slot_index: int) -> void:
	var player := _lineup.get_player_at(slot_index)
	if player != null:
		_detail_player = player
		_select_zone(0)
		_refresh()


func _on_squad_row_pressed(player: PlayerData) -> void:
	_detail_player = player
	_refresh()


func _on_pitch_player_dropped(_lineup_dropped: Lineup, slot_index: int, dragged: PlayerData) -> void:
	_detail_player = dragged
	_lineup.move_player_to_slot(slot_index, dragged)


func _on_row_player_dropped(dragged: PlayerData, target: PlayerData) -> void:
	_detail_player = dragged
	_lineup.swap_players(dragged, target)


## Przewijanie listy kadry, gdy przeciągany zawodnik jest przy jej górnej lub dolnej krawędzi.
func _update_drag_scroll(delta: float) -> void:
	if not get_viewport().gui_is_dragging():
		return
	var rect := _squad_scroll.get_global_rect()
	var mouse := get_global_mouse_position()
	if mouse.x < rect.position.x or mouse.x > rect.end.x:
		return
	var direction := 0.0
	if mouse.y < rect.position.y + DRAG_SCROLL_EDGE and mouse.y > rect.position.y - DRAG_SCROLL_EDGE:
		direction = -1.0
	elif mouse.y > rect.end.y - DRAG_SCROLL_EDGE and mouse.y < rect.end.y + DRAG_SCROLL_EDGE:
		direction = 1.0
	if direction != 0.0:
		_squad_scroll.scroll_vertical += int(direction * DRAG_SCROLL_SPEED * delta)


# --- Strefy boiska ---

func _on_zone_pressed(zone: int) -> void:
	# Ponowne kliknięcie zaznaczonej strefy ją odznacza.
	_select_zone(0 if zone == _selected_zone else zone)


func _select_zone(zone: int) -> void:
	_selected_zone = zone
	_pitch_view.selected_zone = zone
	_content.visible = zone == 0
	_zone_scroll.visible = zone != 0
	if zone != 0:
		_zone_panel.show_zone(_lineup, zone)
		_zone_scroll.scroll_vertical = 0


# --- Widoki pełnoekranowe ---

func _open_player_details(player: PlayerData) -> void:
	_detail_player = player
	_open_overlay(PlayerDetailsScreen.create(_lineup, player))


func _on_opponent_pressed() -> void:
	_open_overlay(OpponentPreviewScreen.create(GameState.get_opponent_team(_lineup.team)))


func _open_overlay(overlay: Control) -> void:
	_close_overlay()
	_overlay = overlay
	_overlay.connect(&"back_requested", _close_overlay)
	add_child(_overlay)
	_toast.dismiss()
	_margin.visible = false


func _close_overlay() -> void:
	if _overlay == null:
		return
	_overlay.queue_free()
	_overlay = null
	_margin.visible = true
	_refresh()


func _on_die_pressed(player: PlayerData, die_index: int) -> void:
	_lineup.activate_die(player, die_index)


# --- Przyciski i listy wyboru ---

func _on_tactic_selected(index: int) -> void:
	_lineup.set_tactic(GameData.get_tactic_list()[index])
	_apply_sort()


func _on_auto_pick_pressed() -> void:
	_lineup.auto_pick()
	_apply_sort()


func _on_back_pressed() -> void:
	SceneManager.change_scene(SceneManager.MAIN_MENU)


func _on_start_pressed() -> void:
	if not _lineup.is_valid():
		_show_lineup_errors()
		return
	GameState.start_match(_lineup)
	SceneManager.change_scene(SceneManager.MATCH)
