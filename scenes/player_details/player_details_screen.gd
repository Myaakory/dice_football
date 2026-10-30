class_name PlayerDetailsScreen
extends Control
## Pełnoekranowa karta zawodnika na tle stadionu: z lewej karta z portretem i danymi, w środku mapa pozycji z miejscem
## na perki, z prawej kości (siatka ścianek i sumy cech), na dole miejsce na kolejne moduły.
## Kliknięcie kości aktywuje ją w składzie, najechanie na ściankę pokazuje jej opis.
## Otwierana jako nakładka na ekranie przygotowania meczu – "Wróć" emituje back_requested.

signal back_requested

const SCENE_PATH := "res://scenes/player_details/player_details_screen.tscn"
const PROFILE_WIDTH := 680.0
const POSITION_WIDTH := 328.0
const HERO_HEIGHT := 392.0
## Portret karty 64 px pokazany w skali ×6 (384 px).
const PORTRAIT_SCALE := 6
const PORTRAIT_SIZE := 384.0
const HERO_TEXT_X := 400.0
const DIE_NET_SCALE := 1
const FLAG_PIXEL := 3
const FIELD_SIZE := Vector2(240, 360)
const PERK_SLOTS := 4
const PERK_SLOT_SIZE := 56.0
const TITLE_BAR_MARGIN := 14.0
const MODULE_TITLE_KEYS: Array[String] = [
	"PLAYER_MODULE_RECENT_MATCHES", "PLAYER_MODULE_TRANSFERS", "PLAYER_MODULE_SEASON_STATS"]

const GLASS := Color(0.05, 0.12, 0.19, 0.93)
const GLASS_LIGHT := Color(0.12, 0.23, 0.32, 0.92)
const GLASS_DIM := Color(0.05, 0.1, 0.15, 0.6)
const HERO_TINT := Color(0.1, 0.2, 0.28, 0.55)
const BAR := Color(0.2, 0.25, 0.3, 0.92)
const TEXT := Color("#f1f5f8")
const MUTED := Color("#9fb4c4")
const YELLOW := Color("#f3d44b")
const BUTTON_TEXT := Color("#2a2a12")
const GHOST := Color(1, 1, 1, 0.13)
const DIVIDER := Color(1, 1, 1, 0.15)

@onready var _background: ColorRect = %Background
@onready var _main_row: HBoxContainer = %MainRow
@onready var _modules_row: HBoxContainer = %ModulesRow
@onready var _back_button: Button = %BackButton

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
	_style_back_button()
	_back_button.pressed.connect(back_requested.emit)
	(_background.material as ShaderMaterial).set_shader_parameter(&"crowd_color", _lineup.team.primary_color)
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
	_clear(_main_row)
	_clear(_modules_row)
	_main_row.add_child(_make_profile_panel())
	_main_row.add_child(_make_position_panel())
	_main_row.add_child(_make_dice_panel())
	for title_key in MODULE_TITLE_KEYS:
		var module := _make_panel(tr(title_key))
		module.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_modules_row.add_child(module)


func _style_back_button() -> void:
	var hover := StyleBoxFlat.new()
	hover.bg_color = YELLOW.lightened(0.25)
	var normal := StyleBoxFlat.new()
	normal.bg_color = YELLOW
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = TEXT
	focus.set_border_width_all(2)
	_back_button.add_theme_stylebox_override(&"normal", normal)
	_back_button.add_theme_stylebox_override(&"pressed", normal)
	_back_button.add_theme_stylebox_override(&"hover", hover)
	_back_button.add_theme_stylebox_override(&"focus", focus)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		_back_button.add_theme_color_override(state, BUTTON_TEXT)
	_back_button.add_theme_font_override(&"font", UiFonts.get_variant(UiFonts.BOLD))
	_back_button.add_theme_font_size_override(&"font_size", 20)


# --- Panele ---

## Szklany panel z paskiem tytułu; treść dodaje się do jego VBoxContainer (ostatnie dziecko panelu).
func _make_panel(title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", _make_flat_style(GLASS))
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	panel.add_child(box)
	var bar := PanelContainer.new()
	var bar_style := _make_flat_style(BAR)
	bar_style.content_margin_left = TITLE_BAR_MARGIN
	bar_style.content_margin_right = TITLE_BAR_MARGIN
	bar_style.content_margin_top = 7.0
	bar_style.content_margin_bottom = 7.0
	bar.add_theme_stylebox_override(&"panel", bar_style)
	bar.add_child(_make_label(title, 20, MUTED, UiFonts.get_variant(UiFonts.BOLD)))
	box.add_child(bar)
	return panel


func _get_panel_box(panel: PanelContainer) -> VBoxContainer:
	return panel.get_child(0) as VBoxContainer


func _make_profile_panel() -> Control:
	var panel := _make_panel(tr("PLAYER_CARD_TITLE"))
	panel.custom_minimum_size.x = PROFILE_WIDTH
	var box := _get_panel_box(panel)
	box.add_child(_make_hero())
	box.add_child(_make_dice_totals())
	box.add_child(_make_margin(_make_info_rows(), 20, 8))
	return panel


## Blok z portretem z lewej, napisami z prawej i wielkim skrótem pozycji w tle.
func _make_hero() -> Control:
	var player := _player
	var hero := Control.new()
	hero.custom_minimum_size = Vector2(PROFILE_WIDTH, HERO_HEIGHT)
	hero.clip_contents = true
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tint := ColorRect.new()
	tint.color = HERO_TINT
	tint.size = hero.custom_minimum_size
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(tint)

	var ghost := _make_label(_get_main_role_short(), 170, GHOST, UiFonts.get_variant(UiFonts.BOLD))
	ghost.position = Vector2(HERO_TEXT_X - 8.0, HERO_HEIGHT - 190.0)
	ghost.size.x = PROFILE_WIDTH - HERO_TEXT_X
	ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hero.add_child(ghost)

	var portrait := TextureRect.new()
	portrait.texture = PortraitComposer.get_player_texture(player, _lineup.team, PortraitComposer.CARD_SIZE, PORTRAIT_SCALE)
	portrait.position = Vector2(0, HERO_HEIGHT - PORTRAIT_SIZE)
	portrait.size = Vector2.ONE * PORTRAIT_SIZE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelArt.apply(portrait)
	hero.add_child(portrait)

	var text_width := PROFILE_WIDTH - HERO_TEXT_X - 12.0
	var column := VBoxContainer.new()
	column.position = Vector2(HERO_TEXT_X, 20)
	column.custom_minimum_size.x = text_width
	column.add_theme_constant_override(&"separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(column)
	column.add_child(_make_label(player.first_name, 28, TEXT))
	var last_name := _make_label(player.last_name, 48, TEXT, UiFonts.get_variant(UiFonts.BOLD, 87))
	last_name.clip_text = true
	last_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	last_name.custom_minimum_size.x = text_width
	column.add_child(last_name)
	column.add_child(_make_gap(8.0))

	var details := HBoxContainer.new()
	details.add_theme_constant_override(&"separation", 16)
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(_make_label("#%d" % player.number, 30, YELLOW, UiFonts.get_variant(UiFonts.BOLD)))
	var age_text := str(player.age) if player.age > 0 else "—"
	var age := _make_label("%s %s" % [tr("PLAYER_AGE"), age_text], 24, MUTED)
	age.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	details.add_child(age)
	column.add_child(details)
	column.add_child(_make_gap(4.0))
	column.add_child(_make_nation_row())
	return hero


func _make_nation_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nation := GameData.get_nationality(_player.nationality)
	if nation == null:
		row.add_child(_make_label("%s —" % tr("PLAYER_NATIONALITY"), 24, MUTED))
		return row
	var flag := NationFlag.new()
	flag.setup(nation, FLAG_PIXEL)
	flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(flag)
	row.add_child(_make_label(tr(nation.name_key), 24, TEXT))
	return row


## Suma każdej kości (przygaszona, gdy nieaktywna) i razem aktywnych, pod blokiem portretu.
func _make_dice_totals() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var active_total := 0
	for die_index in _player.dice.size():
		var die := _player.dice[die_index]
		var active := _lineup.is_die_active(_player, die_index)
		if active:
			active_total += die.get_total()
		row.add_child(_make_total_cell("DIE_%s_SHORT" % String(die.type.id).to_upper(), die.get_total(), TEXT if active else MUTED))
	row.add_child(_make_total_cell("PLAYER_ACTIVE_TOTAL", active_total, YELLOW))
	return _make_margin(row, 0, 8)


func _make_total_cell(label_key: String, value: int, color: Color) -> Control:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override(&"separation", -4)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _make_label(tr(label_key), 19, MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	cell.add_child(label)
	var number := _make_label(str(value), 48, color, UiFonts.get_variant(UiFonts.BOLD))
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(number)
	return cell


func _make_info_rows() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var player_position := GameData.get_position(_player.position_id)
	box.add_child(_make_info_row("PLAYER_TEAM", _lineup.team.name))
	box.add_child(_make_info_row("PLAYER_POSITION", tr(player_position.name_key) if player_position != null else str(_player.position_id)))
	box.add_child(_make_info_row("PLAYER_LINEUP", _get_lineup_text()))
	return box


func _make_info_row(key: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_label := _make_label(tr(key), 22, MUTED)
	key_label.custom_minimum_size.x = 170.0
	row.add_child(key_label)
	row.add_child(_make_label(value, 22, TEXT, UiFonts.get_variant(UiFonts.BOLD)))
	return row


func _get_lineup_text() -> String:
	var slot_index := _lineup.get_player_slot(_player)
	if slot_index == -1:
		return tr("PLAYER_LINEUP_BENCH") % (_lineup.get_bench_index(_player) + 1)
	var slot := _lineup.tactic.slots[slot_index]
	var role := GameData.get_role(slot.role_id)
	return tr("PLAYER_LINEUP_STARTER") % [tr(role.name_key) if role != null else "?", slot.lane]


func _get_main_role_short() -> String:
	if not _player.natural_roles.is_empty():
		var role := GameData.get_role(_player.natural_roles[0])
		if role != null:
			return tr(role.short_key)
	var player_position := GameData.get_position(_player.position_id)
	return tr(player_position.short_key) if player_position != null else ""


func _make_dice_panel() -> Control:
	var title_key := "PLAYER_DICE_TITLE_READ_ONLY" if _read_only else "PLAYER_DICE_TITLE"
	var panel := _make_panel(tr(title_key) % [Lineup.ACTIVE_DICE_COUNT, _player.dice.size()])
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cards := VBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override(&"separation", 6)
	for die_index in _player.dice.size():
		cards.add_child(_make_die_card(die_index))
	_get_panel_box(panel).add_child(_make_margin(cards, 6, 6))
	return panel


## Karta kości: siatka ścianek z lewej, nazwa, stan i sumy cech z prawej. Rozciąga się na dostępną wysokość, żeby
## bramkarz z dwiema kośćmi nie zostawiał pustego miejsca.
func _make_die_card(die_index: int) -> Control:
	var die := _player.dice[die_index]
	var active := _lineup.is_die_active(_player, die_index)
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := _make_flat_style(GLASS_LIGHT if active else GLASS_DIM)
	style.content_margin_left = 16.0
	style.content_margin_right = 20.0
	if active:
		style.border_color = YELLOW
		style.border_width_top = 3
	card.add_theme_stylebox_override(&"panel", style)
	if not _read_only:
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(_on_die_card_input.bind(die_index))

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var net := DieNetView.new()
	net.setup(die, DIE_NET_SCALE, &"", not active)
	net.face_tooltips = true
	net.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(net)

	var text_color := TEXT if active else MUTED
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override(&"separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var type_label := _make_label(tr(die.type.name_key), 22, text_color, UiFonts.get_variant(UiFonts.BOLD))
	type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(type_label)
	header.add_child(_make_label(str(die.get_total()), 30, YELLOW if active else MUTED, UiFonts.get_variant(UiFonts.BOLD)))
	column.add_child(header)
	column.add_child(_make_label(tr("PLAYER_DIE_ACTIVE") if active else tr("PLAYER_DIE_INACTIVE"), 16,
			die.type.color.lightened(0.5) if active else MUTED))
	column.add_child(_make_gap(6.0))
	for attribute_id in _get_die_attributes(die):
		var attribute := GameData.get_attribute(attribute_id)
		var attribute_row := HBoxContainer.new()
		attribute_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var attribute_name := _make_label(tr(attribute.name_key) if attribute != null else String(attribute_id), 20, text_color)
		attribute_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		attribute_row.add_child(attribute_name)
		attribute_row.add_child(_make_label(str(die.get_attribute_total(attribute_id)), 20, text_color, UiFonts.get_variant(UiFonts.BOLD)))
		column.add_child(attribute_row)
	return card


func _on_die_card_input(event: InputEvent, die_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Odroczone: odświeżenie przebudowuje karty, a ta karta właśnie obsługuje zdarzenie.
		_lineup.activate_die.call_deferred(_player, die_index)


## Boisko w pionie, opisy kolorów pod nim, a w dolnej części miejsce na perki zawodnika.
func _make_position_panel() -> Control:
	var panel := _make_panel(tr("PLAYER_POSITIONS"))
	panel.custom_minimum_size.x = POSITION_WIDTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var map := PositionMap.new()
	map.field_size = FIELD_SIZE
	map.style_override = PositionMap.DotStyle.ROLE_BADGE
	map.show_legend = false
	map.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	map.setup(_player)
	box.add_child(map)

	var legend := HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override(&"separation", 20)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_child(_make_label(tr("POSITION_NATURAL"), 16, PositionMap.GREEN[2]))
	legend.add_child(_make_label(tr("POSITION_SECONDARY"), 16, PositionMap.YELLOW[2]))
	box.add_child(legend)

	var divider := ColorRect.new()
	divider.color = DIVIDER
	divider.custom_minimum_size.y = 1.0
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)
	box.add_child(_make_label(tr("PLAYER_PERKS"), 20, MUTED, UiFonts.get_variant(UiFonts.BOLD)))
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override(&"separation", 12)
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in PERK_SLOTS:
		slots.add_child(_make_perk_slot())
	box.add_child(slots)
	var empty := _make_label(tr("PLAYER_PERKS_EMPTY"), 16, MUTED)
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(empty)
	_get_panel_box(panel).add_child(_make_margin(box, 14, 12))
	return panel


## Puste pole na perk (perki zawodników jeszcze nie istnieją).
func _make_perk_slot() -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2.ONE * PERK_SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _make_flat_style(Color(0, 0, 0, 0.3))
	style.border_color = DIVIDER
	style.set_border_width_all(1)
	slot.add_theme_stylebox_override(&"panel", style)
	return slot


# --- Pomocnicze ---

static func _get_die_attributes(die: DieData) -> Array[StringName]:
	var result: Array[StringName] = []
	for i in die.get_face_count():
		if die.get_face_attribute(i) not in result:
			result.append(die.get_face_attribute(i))
	return result


static func _make_flat_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style


func _make_margin(content: Control, horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.size_flags_vertical = content.size_flags_vertical
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override(&"margin_left", horizontal)
	margin.add_theme_constant_override(&"margin_right", horizontal)
	margin.add_theme_constant_override(&"margin_top", vertical)
	margin.add_theme_constant_override(&"margin_bottom", vertical)
	margin.add_child(content)
	return margin


func _make_gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _make_label(text: String, font_size: int, color: Color, font: Font = null) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	if font != null:
		label.add_theme_font_override(&"font", font)
	return label


static func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
