class_name ZonePanel
extends VBoxContainer
## Panel boczny zaznaczonej strefy boiska: zagrania taktyczne możliwe do wylosowania, gdy piłka jest w strefie
## (na razie puste miejsca), oraz kości zawodników ustawionych w tej strefie.

signal close_requested

## Rozmiar karty zagrania; karty układane po dwie w rzędzie.
const PLAY_CARD_SIZE := Vector2(300, 96)
const PLAY_COLUMNS := 2
## Liczba pustych miejsc na zagrania, dopóki zagrania nie trafią do danych (docelowo 5–8 na strefę).
const PLACEHOLDER_PLAY_COUNT := 6
const SECTION_COLOR := Color("#f0e6a8")
const DIM_TEXT := Color(0.91, 0.937, 0.878, 0.55)
const NAME_COLUMN_WIDTH := 170.0

var _lineup: Lineup
var _zone := 0

var _title: Label
var _plays_grid: GridContainer
var _totals_row: HBoxContainer
var _players_box: VBoxContainer


func _init() -> void:
	add_theme_constant_override(&"separation", 6)

	var header := HBoxContainer.new()
	_title = _make_label("", 20)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close_button := Button.new()
	close_button.text = "ZONE_BACK_TO_SQUAD"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close_requested.emit)
	header.add_child(close_button)
	add_child(header)

	add_child(_make_section_label("ZONE_PLAYS", "ZONE_PLAYS_HINT"))
	_plays_grid = GridContainer.new()
	_plays_grid.columns = PLAY_COLUMNS
	_plays_grid.add_theme_constant_override(&"h_separation", 10)
	_plays_grid.add_theme_constant_override(&"v_separation", 10)
	add_child(_plays_grid)

	add_child(HSeparator.new())
	add_child(_make_section_label("ZONE_DICE", "ZONE_DICE_HINT"))
	_totals_row = HBoxContainer.new()
	_totals_row.add_theme_constant_override(&"separation", 8)
	add_child(_totals_row)
	_players_box = VBoxContainer.new()
	_players_box.add_theme_constant_override(&"separation", 4)
	add_child(_players_box)


func show_zone(lineup: Lineup, zone: int) -> void:
	_lineup = lineup
	_zone = zone
	refresh()


func refresh() -> void:
	if _lineup == null or _zone == 0:
		return
	_title.text = tr("ZONE_TITLE") % [_zone, tr("ZONE_NAME_%d" % _zone)]
	_rebuild_plays()
	_rebuild_dice()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _lineup != null:
		refresh()


func _rebuild_plays() -> void:
	_clear(_plays_grid)
	for i in PLACEHOLDER_PLAY_COUNT:
		var card := PanelContainer.new()
		card.custom_minimum_size = PLAY_CARD_SIZE
		card.add_theme_stylebox_override(&"panel", UiFrames.make_stylebox(UiFrames.Style.SLATE, 10.0))
		card.modulate.a = 0.75
		var label := _make_label(tr("ZONE_PLAY_EMPTY") % (i + 1), 13, DIM_TEXT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(label)
		_plays_grid.add_child(card)


func _rebuild_dice() -> void:
	_clear(_totals_row)
	_clear(_players_box)
	var players := _get_zone_players()
	if players.is_empty():
		_players_box.add_child(_make_label("ZONE_NO_PLAYERS", 13, DIM_TEXT, true))
		return

	# Suma symboli każdej cechy na aktywnych kościach wszystkich zawodników w strefie.
	var totals: Dictionary[StringName, int] = {}
	for player in players:
		for die in _lineup.get_active_dice(player):
			for i in die.get_face_count():
				var attribute := die.get_face_attribute(i)
				totals[attribute] = totals.get(attribute, 0) + die.get_face_value(i)
	_totals_row.add_child(_make_label("ZONE_TOTALS", 13, DIM_TEXT, true))
	for attribute_id in DieGraphics.ATTRIBUTE_ORDER:
		if totals.has(attribute_id):
			var attribute := GameData.get_attribute(attribute_id)
			var label := _make_label("%s %d" % [tr(attribute.short_key) if attribute != null else attribute_id,
					totals[attribute_id]], 13)
			label.tooltip_text = tr(attribute.name_key) if attribute != null else ""
			label.mouse_filter = Control.MOUSE_FILTER_STOP
			_totals_row.add_child(label)

	for player in players:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 6)
		var role := GameData.get_role(_lineup.tactic.slots[_lineup.get_player_slot(player)].role_id)
		var name_label := _make_label("%d  %s  (%s)" % [player.number, player.get_short_name(),
				tr(role.short_key) if role != null else "?"], 14)
		name_label.custom_minimum_size.x = NAME_COLUMN_WIDTH
		name_label.clip_text = true
		row.add_child(name_label)
		for die_index in player.dice.size():
			var chip := DieChip.new()
			chip.setup(player.dice[die_index], _lineup.is_die_active(player, die_index))
			row.add_child(chip)
		_players_box.add_child(row)


## Zawodnicy pierwszej jedenastki w strefie, od lewej do prawej strony boiska.
func _get_zone_players() -> Array[PlayerData]:
	var slots := _lineup.tactic.slots.filter(func(slot: FormationSlot) -> bool: return slot.lane == _zone)
	slots.sort_custom(func(a: FormationSlot, b: FormationSlot) -> bool: return a.x < b.x)
	var result: Array[PlayerData] = []
	for slot: FormationSlot in slots:
		var player := _lineup.get_player_at(slot.index)
		if player != null:
			result.append(player)
	return result


## Nagłówek sekcji z opisem w tooltipie (kursor pomocy sugeruje podpowiedź).
func _make_section_label(text_key: String, hint_key: String) -> Label:
	var label := _make_label(text_key, 15, SECTION_COLOR, true)
	label.tooltip_text = hint_key
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.mouse_default_cursor_shape = Control.CURSOR_HELP
	return label


func _make_label(text: String, font_size: int, color := Color(0.91, 0.937, 0.878), translate := false) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


static func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
