class_name PlayerDetailsScreen
extends Control
## Pełnoekranowa karta zawodnika: twarz, numer, pozycja, wiek, miejsce w składzie, sumy cech
## mapa pozycji (gdzie gra naturalnie / może zagrać) i wszystkie kości rozłożone na siatkę w naturalnym rozmiarze.
## Kliknięcie kości aktywuje ją w składzie, najechanie na ściankę pokazuje jej opis.
## Otwierana jako nakładka na ekranie przygotowania meczu – "Wróć" emituje back_requested.

signal back_requested

const SCENE_PATH := "res://scenes/player_details/player_details_screen.tscn"
const PORTRAIT_SCALE := 4
const DIE_NET_SCALE := 1
const INFO_KEY_COLOR := Color(0.91, 0.937, 0.878, 0.6)
const DIE_CARD_PADDING := 10.0

@onready var _back_button: Button = %BackButton
@onready var _name_label: Label = %NameLabel
@onready var _team_label: Label = %TeamLabel
@onready var _portrait: TextureRect = %Portrait
@onready var _portrait_panel: PanelContainer = %PortraitPanel
@onready var _number_label: Label = %NumberLabel
@onready var _info_grid: GridContainer = %InfoGrid
@onready var _attributes_grid: GridContainer = %AttributesGrid
@onready var _position_panel: PanelContainer = %PositionPanel
@onready var _position_map: PositionMap = %PositionMap
@onready var _dice_title: Label = %DiceTitle
@onready var _dice_row: HBoxContainer = %DiceRow

var _lineup: Lineup
var _player: PlayerData
## Tylko podgląd (np. w trakcie meczu) – kliknięcie kości nie zmienia aktywnych kości w składzie.
var _read_only := false


static func create(lineup: Lineup, player: PlayerData, read_only := false) -> PlayerDetailsScreen:
	var screen: PlayerDetailsScreen = load(SCENE_PATH).instantiate()
	screen._lineup = lineup
	screen._player = player
	screen._read_only = read_only
	return screen


func _ready() -> void:
	PixelArt.apply(_portrait)
	_back_button.pressed.connect(back_requested.emit)
	_portrait_panel.add_theme_stylebox_override(&"panel", UiFrames.make_stylebox(UiFrames.Style.PITCH, 12.0))
	_position_panel.add_theme_stylebox_override(&"panel", UiFrames.make_stylebox(UiFrames.Style.PITCH, 6.0))
	_lineup.changed.connect(_refresh)
	_back_button.grab_focus()
	_refresh()


func _exit_tree() -> void:
	if _lineup != null and _lineup.changed.is_connected(_refresh):
		_lineup.changed.disconnect(_refresh)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


func _refresh() -> void:
	var team := _lineup.team
	_name_label.text = _player.get_full_name()
	_team_label.text = team.name
	_team_label.add_theme_color_override(&"font_color", team.primary_color.lightened(0.35))
	var image := PortraitGenerator.make_image(String(_player.id), team.primary_color, team.secondary_color)
	image.resize(image.get_width() * PORTRAIT_SCALE, image.get_height() * PORTRAIT_SCALE, Image.INTERPOLATE_NEAREST)
	_portrait.texture = ImageTexture.create_from_image(image)
	_number_label.text = "#%d" % _player.number
	_position_map.setup(_player)
	_refresh_info()
	_refresh_attributes()
	_refresh_dice()


func _refresh_info() -> void:
	_clear(_info_grid)
	var player_position := GameData.get_position(_player.position_id)
	_add_info_row("PLAYER_NUMBER", str(_player.number))
	_add_info_row("PLAYER_POSITION", tr(player_position.name_key) if player_position != null else str(_player.position_id))
	_add_info_row("PLAYER_AGE", str(_player.age) if _player.age > 0 else "—")
	_add_info_row("PLAYER_TEAM", _lineup.team.name)
	var slot_index := _lineup.get_player_slot(_player)
	if slot_index != -1:
		var slot := _lineup.tactic.slots[slot_index]
		var role := GameData.get_role(slot.role_id)
		_add_info_row("PLAYER_LINEUP", tr("PLAYER_LINEUP_STARTER") % [tr(role.name_key) if role != null else "?", slot.lane])
	else:
		_add_info_row("PLAYER_LINEUP", tr("PLAYER_LINEUP_BENCH") % (_lineup.get_bench_index(_player) + 1))
	var active_total := 0
	for die in _lineup.get_active_dice(_player):
		active_total += die.get_total()
	_add_info_row("PLAYER_DICE_POWER", str(active_total))


func _add_info_row(key: String, value: String) -> void:
	var key_label := _make_label(tr(key), 15, INFO_KEY_COLOR)
	key_label.custom_minimum_size.x = 150.0
	_info_grid.add_child(key_label)
	_info_grid.add_child(_make_label(value, 16))


## Suma symboli każdej cechy na aktywnych kościach, w kolorze typu kości.
func _refresh_attributes() -> void:
	_clear(_attributes_grid)
	var totals: Dictionary[StringName, int] = {}
	for die in _lineup.get_active_dice(_player):
		for i in die.get_face_count():
			var attribute := die.get_face_attribute(i)
			totals[attribute] = totals.get(attribute, 0) + die.get_face_value(i)
	for attribute_id in DieGraphics.ATTRIBUTE_ORDER:
		var attribute := GameData.get_attribute(attribute_id)
		if attribute == null:
			continue
		var die_type := GameData.get_die_type(attribute.die_type_id)
		var color := die_type.color.lightened(0.45) if die_type != null else Color.WHITE
		var value: int = totals.get(attribute_id, 0)
		if value == 0:
			color = Color(color, 0.35)
		_attributes_grid.add_child(_make_label(tr(attribute.name_key), 14, color))
		var value_label := _make_label(str(value), 14, color)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.custom_minimum_size.x = 28.0
		_attributes_grid.add_child(value_label)


func _refresh_dice() -> void:
	_clear(_dice_row)
	var title_key := "PLAYER_DICE_TITLE_READ_ONLY" if _read_only else "PLAYER_DICE_TITLE"
	_dice_title.text = tr(title_key) % [Lineup.ACTIVE_DICE_COUNT, _player.dice.size()]
	for die_index in _player.dice.size():
		_dice_row.add_child(_make_die_card(die_index))


func _make_die_card(die_index: int) -> Control:
	var die := _player.dice[die_index]
	var active := _lineup.is_die_active(_player, die_index)
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override(&"panel", _make_die_card_style(die, active))
	card.gui_input.connect(_on_die_card_input.bind(die_index))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 8)
	card.add_child(box)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var type_label := _make_label(tr(die.type.name_key), 16, Color.WHITE if active else Color(0.6, 0.63, 0.6))
	type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(type_label)
	var state_label := _make_label(tr("PLAYER_DIE_ACTIVE") if active else tr("PLAYER_DIE_INACTIVE"), 13,
			die.type.color.lightened(0.5) if active else Color(0.6, 0.63, 0.6))
	header.add_child(state_label)
	box.add_child(header)

	var net := DieNetView.new()
	net.setup(die, DIE_NET_SCALE, &"", not active)
	net.face_tooltips = true
	box.add_child(net)

	var summary: Array[String] = []
	for attribute_id in _get_die_attributes(die):
		var attribute := GameData.get_attribute(attribute_id)
		summary.append("%s %d" % [tr(attribute.name_key) if attribute != null else attribute_id,
				die.get_attribute_total(attribute_id)])
	box.add_child(_make_label("  ·  ".join(summary), 13, Color(1, 1, 1, 0.8 if active else 0.45)))
	return card


func _make_die_card_style(die: DieData, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = die.type.color.darkened(0.7) if active else Color(0.1, 0.12, 0.11)
	style.border_color = die.type.color if active else Color(0.3, 0.33, 0.31)
	style.set_border_width_all(2)
	style.set_content_margin_all(DIE_CARD_PADDING)
	return style


func _on_die_card_input(event: InputEvent, die_index: int) -> void:
	if _read_only:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Odroczone: odświeżenie przebudowuje karty, a ta karta właśnie obsługuje zdarzenie.
		_lineup.activate_die.call_deferred(_player, die_index)


static func _get_die_attributes(die: DieData) -> Array[StringName]:
	var result: Array[StringName] = []
	for i in die.get_face_count():
		if die.get_face_attribute(i) not in result:
			result.append(die.get_face_attribute(i))
	return result


func _make_label(text: String, font_size: int, color := Color(0.91, 0.937, 0.878)) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


static func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
