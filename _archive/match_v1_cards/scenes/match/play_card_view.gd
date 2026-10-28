class_name PlayCardView
extends PanelContainer
## Karta zagrania na ekranie meczu, wyglądem jak papierowa karta: w ręce (ROW – testy i szanse, do kliknięcia)
## albo wybrana (FULL – z opisem i skutkami wyników). Testy pokazują ikonki cech i próg punktów.

signal pressed(card: PlayCard)

enum Mode { ROW, FULL }

const PAPER := Color("#efe6cf")
const INK := Color("#2a2219")
const MUTED := Color("#6b5a44")
const ATTACK_INK := Color("#2f6b2a")
const DEFENSE_INK := Color("#a2531a")
const LOSS_INK := Color("#a8321f")
const KEEP_INK := Color("#5d5040")
const SELECTED_BORDER := Color("#f2cf4a")
const HOVER_BORDER := Color("#fff1b8")
## Mini boisko 3 × 5 na karcie: pole komórki, kolory.
const MINI_CELL := Vector2(9, 8)
const MINI_GRASS := Color("#46703b")
const MINI_ORIGIN := Color("#e9eedf")
const MINI_TARGET := Color("#f2cf4a")
const MINI_FRAME := Color("#2f5228")
## Sloty wyniku pokazywane na karcie (bezpańska piłka rzadka – pomijamy).
const SHOWN_SLOTS: Array[StringName] = [&"success", &"duel_won", &"duel_lost", &"defense"]
## Nazwy korytarzy (indeks = korytarz w perspektywie atakujących).
const CHANNEL_KEYS: Array[String] = ["MATCH_CHANNEL_LEFT", "MATCH_CHANNEL_CENTER", "MATCH_CHANNEL_RIGHT"]
const SLOT_KEYS: Dictionary[StringName, String] = {
	&"success": "MATCH_SLOT_SUCCESS",
	&"duel_won": "MATCH_SLOT_DUEL_WON",
	&"duel_lost": "MATCH_SLOT_DUEL_LOST",
	&"defense": "MATCH_SLOT_DEFENSE",
}

var card: PlayCard
var mode: Mode = Mode.ROW
## Pole wyjścia i cele (perspektywa atakujących) – do mini boiska i opisu ruchu.
var origin := Vector2i.ZERO
var targets: Array[Vector2i] = []
## Szanse zapełnienia testów [atak, obrona] w % (ujemne = nie pokazujemy).
var odds := Vector2(-1, -1)
var clickable := false
var selected := false:
	set(value):
		selected = value
		_update_style()

var _hovered := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


static func create(p_card: PlayCard, p_mode: Mode, p_origin: Vector2i, p_targets: Array[Vector2i],
		p_odds := Vector2(-1, -1)) -> PlayCardView:
	var view := PlayCardView.new()
	view.card = p_card
	view.mode = p_mode
	view.origin = p_origin
	view.targets = p_targets
	view.odds = p_odds
	view._build()
	return view


func _build() -> void:
	_update_style()
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 10)
	box.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override(&"separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(_label(card.name, 18 if mode == Mode.FULL else 16, INK))
	titles.add_child(_label(_describe_move(), 12, MUTED))
	var mini := Control.new()
	mini.custom_minimum_size = Vector2(MINI_CELL.x * 3 + 6, MINI_CELL.y * 5 + 8)
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini.draw.connect(_draw_mini_pitch.bind(mini))
	header.add_child(mini)

	if mode == Mode.FULL and not card.description.is_empty():
		var description := _label(card.description, 12, KEEP_INK)
		description.clip_text = false
		description.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(description)

	for attacking: bool in [true, false]:
		for requirement in card.get_requirements(attacking):
			box.add_child(_build_test_row(requirement, attacking))

	if mode == Mode.FULL:
		var grid := GridContainer.new()
		grid.columns = 1
		grid.add_theme_constant_override(&"h_separation", 10)
		grid.add_theme_constant_override(&"v_separation", 2)
		box.add_child(grid)
		for slot in SHOWN_SLOTS:
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override(&"separation", -2)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.add_child(_label(tr(SLOT_KEYS[slot]), 11, MUTED))
			var event := card.get_outcome(slot)
			var text := PlayEvents.get_display_name(event)
			for branch: OutcomeBranch in card.get_branches(slot):
				text += " / " + PlayEvents.get_display_name(branch.event)
			cell.add_child(_label(text, 12, _event_color(event)))
			grid.add_child(cell)

	if odds.x >= 0.0:
		box.add_child(_label(tr("MATCH_ODDS") % [roundi(odds.x), roundi(odds.y)], 11, MUTED))


func _build_test_row(requirement: PlayRequirement, attacking: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	var side := _label(tr("MATCH_ATTACK") if attacking else tr("MATCH_DEFENSE"), 12,
			ATTACK_INK if attacking else DEFENSE_INK)
	side.custom_minimum_size.x = 50
	row.add_child(side)
	var names: Array[String] = []
	for attribute_id in requirement.attributes:
		var attribute := GameData.get_attribute(attribute_id)
		if attribute == null:
			continue
		names.append(tr(attribute.name_key))
		var icon := MatchDie.create_face(attribute.die_type_id, attribute_id, 1, MatchDie.DieSize.SMALL)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	var text := _label(tr("MATCH_OR").join(names), 12, INK)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.clip_text = true
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(text)
	var points := _label(tr("MATCH_POINTS_NEEDED") % MatchDie.format_points(requirement.points), 14, INK)
	points.clip_text = false
	row.add_child(points)
	return row


func _describe_move() -> String:
	if card.is_shot:
		return tr("MATCH_MOVE_SHOT")
	if targets.is_empty():
		return ""
	var target := targets[0]
	var channel_text := tr("MATCH_CHANNEL_CHOICE") if targets.size() > 1 else tr(CHANNEL_KEYS[target.y])
	if target == origin:
		return tr("MATCH_MOVE_STAY") % channel_text
	return tr("MATCH_MOVE_TO") % [target.x, channel_text]


func _event_color(event: StringName) -> Color:
	if event in [PlayEvents.ADVANCE, PlayEvents.GOAL, PlayEvents.FOUL, PlayEvents.CORNER, PlayEvents.PENALTY]:
		return ATTACK_INK
	if PlayEvents.changes_possession(event):
		return LOSS_INK
	return KEEP_INK


## Etykiety karty przycinamy (wielokropek, pełny tekst w podpowiedzi), żeby długie nazwy nie poszerzały panelu.
func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _update_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	style.content_margin_top = 8
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_offset = Vector2(0, 4)
	style.shadow_size = 1
	style.set_border_width_all(3 if selected or _hovered else 1)
	style.border_color = SELECTED_BORDER if selected else (HOVER_BORDER if _hovered else Color(INK, 0.3))
	add_theme_stylebox_override(&"panel", style)


func _gui_input(event: InputEvent) -> void:
	if clickable and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit(card)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			if clickable:
				_hovered = true
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				_update_style()
		NOTIFICATION_MOUSE_EXIT:
			if _hovered:
				_hovered = false
				_update_style()


## Mini boisko: pola wyjścia karty (jasnozielone), bieżące pole (białe), cele (złote). Strefa 5 u góry.
func _draw_mini_pitch(canvas: Control) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), MINI_FRAME)
	for zone in range(1, MatchRules.ZONE_COUNT + 1):
		for channel in MatchRules.CHANNEL_COUNT:
			var cell := Vector2i(zone, channel)
			var color := MINI_GRASS
			if cell in targets:
				color = MINI_TARGET
			elif cell == origin:
				color = MINI_ORIGIN
			elif cell in card.origins:
				color = MINI_GRASS.lightened(0.25)
			var pos := Vector2(3 + channel * MINI_CELL.x, 4 + (MatchRules.ZONE_COUNT - zone) * MINI_CELL.y)
			canvas.draw_rect(Rect2(pos, MINI_CELL - Vector2.ONE), color)
