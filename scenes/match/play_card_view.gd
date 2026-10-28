class_name PlayCardView
extends PanelContainer
## Karta zagrania na ekranie meczu, wyglądem jak papierowa karta:
## - PORTRAIT (ręka, 3 karty obok siebie): nazwa i ruch, rysunek zagrania (PlayDiagram), osobne bloki ATAK
##   i OBRONA (kto gra, cechy, progi), lista wyników (co się dzieje przy każdym rozstrzygnięciu), szanse;
## - FULL (środek rozwiniętego zagrania): rysunek z wybranym celem, opis, wyniki; po rozstrzygnięciu podświetla
##   wynik (highlight_outcome).
## Wybór w ręce: klik = zaznaczenie (pressed), na zaznaczonej karcie pojawiają się przyciski potwierdzenia
## (show_choice): „Zagraj” albo – przy kilku celach – przycisk dla każdej strony / celu (target_chosen);
## najechanie na przycisk celu zgłasza podgląd (target_hovered) i pokazuje ten cel na rysunku.

signal pressed(card: PlayCard)
## Potwierdzono zagranie z wybranym celem (perspektywa atakujących).
signal target_chosen(card: PlayCard, target: Vector2i)
## Kursor wszedł na przycisk celu (entered) albo z niego zszedł.
signal target_hovered(card: PlayCard, target: Vector2i, entered: bool)

enum Mode { PORTRAIT, FULL }

const PAPER := Color("#efe6cf")
const INK := Color("#2a2219")
const MUTED := Color("#6b5a44")
const ATTACK_INK := Color("#2f6b2a")
const DEFENSE_INK := Color("#a2531a")
const ATTACK_TINT := Color("#dfe8c6")
const DEFENSE_TINT := Color("#f3dcc0")
## Interwencja bramkarza – fiolet jak ramka bramkarza w TestsPanel.
const KEEPER_INK := Color("#5b45a8")
const KEEPER_TINT := Color("#e4dcf2")
const LOSS_INK := Color("#a8321f")
const KEEP_INK := Color("#5d5040")
const SELECTED_BORDER := Color("#f2cf4a")
const HOVER_BORDER := Color("#fff1b8")
const ODDS_ATTACK := Color("#5c9a45")
const ODDS_DEFENSE := Color("#d0782f")
## Wyniki pokazywane na karcie (wszystkie wyniki modelu v4).
const SHOWN_SLOTS: Array[StringName] = [&"success", &"duel_won", &"duel_lost", &"defense"]
## Nazwy korytarzy (indeks = korytarz w perspektywie atakujących).
const CHANNEL_KEYS: Array[String] = ["MATCH_CHANNEL_LEFT", "MATCH_CHANNEL_CENTER", "MATCH_CHANNEL_RIGHT"]
## Przyciski wyboru strony (indeks = korytarz).
const SIDE_KEYS: Array[String] = ["MATCH_SIDE_LEFT", "MATCH_SIDE_CENTER", "MATCH_SIDE_RIGHT"]
const SLOT_KEYS: Dictionary[StringName, String] = {
	&"success": "MATCH_SLOT_SUCCESS",
	&"duel_won": "MATCH_SLOT_DUEL_WON",
	&"duel_lost": "MATCH_SLOT_DUEL_LOST",
	&"defense": "MATCH_SLOT_DEFENSE",
}

var card: PlayCard
var mode: Mode = Mode.PORTRAIT
## Strefa piłki i cele (perspektywa atakujących) – do rysunku i opisu ruchu.
var ball_zone := 3
var targets: Array[Vector2i] = []
## Szanse zapełnienia testów [atak, obrona] w % (ujemne = nie pokazujemy).
var odds := Vector2(-1, -1)
## Kontekst meczu do rysunku i podpisów stron: {"attackers", "defenders": MatchTeam, "rules": MatchRules,
## "owners": [obrona, atak] – np. „Ty” / „Komputer”, "flipped": rysunek odwrócony jak boisko, gdy atakują goście}.
var context: Dictionary = {}
var clickable := false
var selected := false:
	set(value):
		selected = value
		_update_style()

var _hovered := false
var _box: VBoxContainer
var _choice: Control
var _diagram: PlayDiagram
## Wiersze wyników (slot -> PanelContainer z meta „value” = etykieta zdarzenia).
var _outcome_list: Container
var _outcome_cells: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


static func create(p_card: PlayCard, p_mode: Mode, p_ball_zone: int, p_targets: Array[Vector2i],
		p_odds := Vector2(-1, -1), p_context := {}) -> PlayCardView:
	var view := PlayCardView.new()
	view.card = p_card
	view.mode = p_mode
	view.ball_zone = p_ball_zone
	view.targets = p_targets
	view.odds = p_odds
	view.context = p_context
	view._build()
	return view


func _build() -> void:
	_update_style()
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8 if mode == Mode.PORTRAIT else 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_box = box
	if mode == Mode.PORTRAIT:
		_build_portrait(box)
	else:
		_build_full(box)


func _build_portrait(box: VBoxContainer) -> void:
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override(&"separation", -1)
	box.add_child(titles)
	titles.add_child(_label(card.name, 19, INK))
	titles.add_child(_label(_describe_move(), 12, MUTED))
	_diagram = PlayDiagram.new()
	_diagram.setup(card, ball_zone, targets, context.get("attackers"), context.get("defenders"), context.get("rules"),
			context.get("flipped", false))
	box.add_child(_diagram)
	var owners: Array = context.get("owners", ["", ""])
	for attacking: bool in [true, false]:
		box.add_child(_build_side_block(attacking, owners[int(attacking)]))
	if card.has_keeper_test():
		box.add_child(_build_side_block(false, owners[0], true))
	var outcomes := VBoxContainer.new()
	outcomes.add_theme_constant_override(&"separation", 1)
	box.add_child(outcomes)
	_outcome_list = outcomes
	for slot in SHOWN_SLOTS:
		_add_outcome_cell(slot)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	if odds.x >= 0.0:
		box.add_child(_build_odds())


## Karta wybranego zagrania (środek rozwiniętego zagrania): nazwa i ruch, rysunek z wybranym celem, opis
## i lista wyników (po rozstrzygnięciu podświetlony wynik). Testy i progi są w ramkach stron obok (TestsPanel).
func _build_full(box: VBoxContainer) -> void:
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override(&"separation", -1)
	box.add_child(titles)
	titles.add_child(_label(card.name, 19, INK))
	titles.add_child(_label(_describe_move(), 12, MUTED))
	_diagram = PlayDiagram.new()
	_diagram.setup(card, ball_zone, targets, context.get("attackers"), context.get("defenders"), context.get("rules"),
			context.get("flipped", false))
	box.add_child(_diagram)
	if not card.description.is_empty():
		var description := _label(card.description, 12, KEEP_INK)
		description.clip_text = false
		description.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(description)
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 1)
	box.add_child(list)
	_outcome_list = list
	for slot in SHOWN_SLOTS:
		_add_outcome_cell(slot)


## Rysunek od nowa (np. po przesunięciu zawodnika).
func refresh_diagram() -> void:
	if _diagram != null:
		_diagram.queue_redraw()


## Blok strony na karcie PORTRAIT: nagłówek „ATAK · Ty”, pod nim każdy test – ikony cech, nazwy i próg punktów.
## keeper: blok interwencji bramkarza (testy obrony z miejscem keeper) zamiast zwykłych testów strony.
func _build_side_block(attacking: bool, owner: String, keeper := false) -> Control:
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = KEEPER_TINT if keeper else (ATTACK_TINT if attacking else DEFENSE_TINT)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	frame.add_theme_stylebox_override(&"panel", style)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 2)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(rows)
	var ink := KEEPER_INK if keeper else (ATTACK_INK if attacking else DEFENSE_INK)
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 6)
	rows.add_child(header)
	var title := tr("MATCH_KEEPER_SHORT") if keeper else (tr("MATCH_ATTACK") if attacking else tr("MATCH_DEFENSE"))
	header.add_child(_fixed_label(title.to_upper(), 14, ink))
	if not owner.is_empty():
		header.add_child(_fixed_label("· " + owner, 12, MUTED))
	var show_location := card.has_origin_tests(true) or card.has_origin_tests(false)
	for requirement in card.get_requirements(attacking):
		if requirement.is_keeper() != keeper:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 4)
		rows.add_child(row)
		if show_location and not keeper:
			row.add_child(_fixed_label(tr("MATCH_TEST_AT_ORIGIN") if requirement.is_at_origin()
					else tr("MATCH_TEST_AT_TARGET"), 11, MUTED))
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
		row.add_child(text)
		row.add_child(_fixed_label(tr("MATCH_POINTS_NEEDED") % MatchDie.format_points(requirement.points), 20, ink))
	return frame


## Szanse: dwa paski – zapełnienie testów ataku i obrony.
func _build_odds() -> Control:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 3)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(_label(tr("MATCH_ODDS") % [roundi(odds.x), roundi(odds.y)], 11, MUTED))
	var bars := Control.new()
	bars.custom_minimum_size = Vector2(0, 11)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.draw.connect(func() -> void:
		for i in 2:
			var y := i * 6.0
			bars.draw_rect(Rect2(0, y, bars.size.x, 4), Color(INK, 0.12))
			bars.draw_rect(Rect2(0, y, bars.size.x * clampf((odds.x if i == 0 else odds.y) / 100.0, 0.0, 1.0), 4),
					ODDS_ATTACK if i == 0 else ODDS_DEFENSE))
	rows.add_child(bars)
	return rows


## Przyciski potwierdzenia na zaznaczonej karcie: jeden cel – „Zagraj”, kilka – przycisk na każdy cel.
func show_choice(enabled: bool) -> void:
	if _choice != null:
		_choice.queue_free()
		_choice = null
	if _diagram != null:
		_diagram.focus_target = PlayDiagram.NO_TARGET
	if not enabled:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	_choice = row
	_box.add_child(row)
	if targets.size() <= 1:
		row.add_child(_choice_button(tr("MATCH_PLAY_BUTTON"), targets[0], false))
		return
	var same_zone := true
	for target in targets:
		same_zone = same_zone and target.x == targets[0].x
	var sorted := targets.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.x == b.x else a.x < b.x)
	for target: Vector2i in sorted:
		row.add_child(_choice_button(_get_target_label(target, same_zone), target, true))


func _get_target_label(target: Vector2i, same_zone: bool) -> String:
	if same_zone:
		return tr(SIDE_KEYS[target.y])
	return tr("MATCH_MOVE_TO") % [target.x, tr(CHANNEL_KEYS[target.y])]


func _choice_button(text: String, target: Vector2i, preview: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_color_override(&"font_color", SELECTED_BORDER)
	button.pressed.connect(func() -> void: target_chosen.emit(card, target))
	if preview:
		button.mouse_entered.connect(func() -> void:
			if _diagram != null:
				_diagram.focus_target = target
			target_hovered.emit(card, target, true))
		button.mouse_exited.connect(func() -> void:
			if _diagram != null:
				_diagram.focus_target = PlayDiagram.NO_TARGET
			target_hovered.emit(card, target, false))
	return button


## Wiersz wyniku: kolorowy znacznik (zielony – korzyść ataku, złoty – piłka zostaje, czerwony – strata),
## nazwa rozstrzygnięcia i skutek.
func _add_outcome_cell(slot: StringName) -> void:
	var cell := PanelContainer.new()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_stylebox_override(&"panel", _outcome_style(false))
	var event := card.get_outcome(slot)
	var text := PlayEvents.get_display_name(event)
	var slot_text := tr(SLOT_KEYS.get(slot, "PLAY_SLOT_" + String(slot).to_upper()))
	var value := _label(text, 12, _event_color(event))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(row)
	var marker := ColorRect.new()
	marker.custom_minimum_size = Vector2(7, 7)
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marker.color = _event_color(event)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(marker)
	row.add_child(_fixed_label(slot_text + ":", 11, MUTED))
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	cell.set_meta(&"value", value)
	_outcome_list.add_child(cell)
	_outcome_cells[slot] = cell


## Rozstrzygnięcie: wynik, który wszedł w życie, dostaje złote tło i właściwe zdarzenie (np. obronę bramkarza
## zamiast gola), pozostałe bledną.
func highlight_outcome(slot: StringName, event: StringName) -> void:
	if _outcome_list == null:
		return
	if not _outcome_cells.has(slot):
		_add_outcome_cell(slot)
	for cell_slot: StringName in _outcome_cells:
		var cell: PanelContainer = _outcome_cells[cell_slot]
		var hit := cell_slot == slot
		cell.add_theme_stylebox_override(&"panel", _outcome_style(hit))
		cell.modulate.a = 1.0 if hit else 0.4
	var value: Label = _outcome_cells[slot].get_meta(&"value")
	value.text = PlayEvents.get_display_name(event)
	value.add_theme_color_override(&"font_color", _event_color(event))


func _outcome_style(hit: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(SELECTED_BORDER, 0.55) if hit else Color(0, 0, 0, 0)
	style.border_color = INK
	style.set_border_width_all(1 if hit else 0)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(2)
	style.content_margin_left = 5
	return style


func _describe_move() -> String:
	if card.is_shot:
		return tr("MATCH_MOVE_SHOT")
	if targets.is_empty():
		return ""
	var target := targets[0]
	var channel_text := tr("MATCH_CHANNEL_CHOICE") if targets.size() > 1 else tr(CHANNEL_KEYS[target.y])
	if target.x == ball_zone:
		return tr("MATCH_MOVE_STAY") % channel_text
	return tr("MATCH_MOVE_TO") % [target.x, channel_text]


func _event_color(event: StringName) -> Color:
	if event in [PlayEvents.ADVANCE, PlayEvents.GOAL, PlayEvents.FOUL, PlayEvents.CORNER, PlayEvents.PENALTY]:
		return ATTACK_INK
	if PlayEvents.changes_possession(event):
		return LOSS_INK
	return KEEP_INK


## Krótka etykieta, której nie przycinamy (w wierszu zajmuje tyle, ile tekst).
func _fixed_label(text: String, font_size: int, color: Color) -> Label:
	var label := _label(text, font_size, color)
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	return label


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

