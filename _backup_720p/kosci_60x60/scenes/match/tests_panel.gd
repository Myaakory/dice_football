class_name TestsPanel
extends VBoxContainer
## Testy zagranej karty z miejscami na kości: ramka ataku i ramka obrony (każda do 2 testów, test do 3 miejsc).
## Gracz przeciąga swoje kości do miejsc (albo klika kość – trafia do pierwszego pasującego miejsca), AI układa
## swoje (show_placement). Liczą się tylko kości w miejscach. Pod testem: suma punktów, próg i pasek.

## Zmieniło się rozmieszczenie kości strony gracza.
signal placement_changed

## Ramki stron: atak w zieleni, obrona w brązie/pomarańczu (tło i obrzeże).
const ATTACK_BG := Color("#18331f")
const ATTACK_BORDER := Color("#4d8a45")
const DEFENSE_BG := Color("#36261a")
const DEFENSE_BORDER := Color("#a8693a")
const TEXT := Color("#e9eedf")
const MUTED := Color("#a9b7a4")
const ATTACK_COLOR := Color("#9fe07a")
const DEFENSE_COLOR := Color("#ffb070")
const SLOT_EMPTY := Color(0.91, 0.93, 0.87, 0.28)
const SLOT_HOVER := Color("#f2cf4a")
const SLOT_SIZE := Vector2(64, 64)
## Ile miejsc pokazać przy teście bez limitu kości (max_dice = 0).
const UNLIMITED_SLOTS := 4


## Miejsce na jedną kość w teście (cel upuszczania).
class TestSlot:
	extends Control

	var panel: TestsPanel
	var attacking := true
	var test_index := 0
	var die_view: MatchDie
	var drop_hover := false

	func _init() -> void:
		custom_minimum_size = SLOT_SIZE
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		var ok: bool = data is Dictionary and data.has("contest_die") \
				and panel.can_place(data["contest_die"], attacking, test_index)
		if ok != drop_hover:
			drop_hover = ok
			queue_redraw()
		return ok

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		drop_hover = false
		panel.place(data["contest_die"], test_index)

	func _notification(what: int) -> void:
		if what in [NOTIFICATION_MOUSE_EXIT, NOTIFICATION_DRAG_END] and drop_hover:
			drop_hover = false
			queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ONE, size - Vector2(2, 2))
		if die_view == null:
			var color := SLOT_HOVER if drop_hover else SLOT_EMPTY
			for i in 4:
				var a: Vector2 = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)][i]
				var b: Vector2 = [Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position][i]
				draw_dashed_line(a, b, color, 1.0, 4.0)
		elif drop_hover:
			draw_rect(rect, SLOT_HOVER, false, 2.0)


var card: PlayCard
var contest: PlayContest
var team_names: Array[String] = ["", ""]  # [obrona, atak]
## Strona gracza, którą może teraz układać (-1 = żadna, 0 = obrona, 1 = atak).
var editable_side := -1
## Robocze rozmieszczenie kości obu stron (ContestDie -> indeks testu); indeks = int(attacking).
var placements: Array[Dictionary] = [{}, {}]

var _slots: Array[Array] = [[], []]  # [strona] -> [test] -> Array[TestSlot]
var _totals: Array[Array] = [[], []]  # [strona] -> Array[Label]
var _bars: Array[Array] = [[], []]  # [strona] -> Array[Control]


func _init() -> void:
	add_theme_constant_override(&"separation", 8)


func setup(p_card: PlayCard, attackers_name: String, defenders_name: String) -> void:
	card = p_card
	contest = null
	team_names = [defenders_name, attackers_name]
	placements = [{}, {}]
	editable_side = -1
	for child in get_children():
		child.queue_free()
	_slots = [[], []]
	_totals = [[], []]
	_bars = [[], []]
	for attacking: bool in [true, false]:
		add_child(_build_frame(attacking))
	refresh()


func set_contest(p_contest: PlayContest) -> void:
	contest = p_contest
	placements = [{}, {}]
	refresh()


## Rozmieszczenie AI (albo zatwierdzone gracza) – pokazujemy je w miejscach.
func show_placement(attacking: bool, placement: Dictionary) -> void:
	placements[int(attacking)] = placement.duplicate()
	refresh()


func get_placement(attacking: bool) -> Dictionary:
	return placements[int(attacking)].duplicate()


func is_placed(contest_die: PlayContest.ContestDie) -> bool:
	return placements[int(contest_die.attacking)].has(contest_die)


func get_test_capacity(attacking: bool, test_index: int) -> int:
	var cap := card.get_requirements(attacking)[test_index].max_dice
	return cap if cap > 0 else UNLIMITED_SLOTS


func can_place(contest_die: PlayContest.ContestDie, attacking: bool, test_index: int) -> bool:
	if contest == null or editable_side != int(attacking) or contest_die.attacking != attacking:
		return false
	if not contest.can_place(contest_die, test_index):
		return false
	var placement := placements[int(attacking)]
	if placement.get(contest_die, -1) == test_index:
		return false
	return _count_in_test(placement, test_index) < get_test_capacity(attacking, test_index)


## Kładzie kość gracza w teście (-1 = pierwszy pasujący test z wolnym miejscem). Zwraca, czy się udało.
func place(contest_die: PlayContest.ContestDie, test_index := -1) -> bool:
	var attacking := contest_die.attacking
	if test_index == -1:
		for i in card.get_requirements(attacking).size():
			if can_place(contest_die, attacking, i):
				test_index = i
				break
	if test_index == -1 or not can_place(contest_die, attacking, test_index):
		return false
	placements[int(attacking)][contest_die] = test_index
	refresh()
	placement_changed.emit()
	return true


func remove(contest_die: PlayContest.ContestDie) -> void:
	if editable_side != int(contest_die.attacking):
		return
	if placements[int(contest_die.attacking)].erase(contest_die):
		refresh()
		placement_changed.emit()


## Najlepsze rozmieszczenie (jak automat AI) dla strony gracza.
func auto_place(attacking: bool) -> void:
	if contest == null:
		return
	placements[int(attacking)] = contest.get_auto_placement(attacking)
	refresh()
	placement_changed.emit()


## Punkty strony w każdym teście z bieżącego rozmieszczenia.
func get_points(attacking: bool) -> PackedFloat64Array:
	var points := PackedFloat64Array()
	points.resize(card.get_requirements(attacking).size())
	if contest == null:
		return points
	var placement := placements[int(attacking)]
	for contest_die: PlayContest.ContestDie in placement:
		points[placement[contest_die]] += contest.get_die_points_in_test(contest_die, placement[contest_die])
	return points


## Widok kości w miejscu testu (null = kość nie leży w teście) – do animacji lotu kości.
func get_slot_view(contest_die: PlayContest.ContestDie) -> MatchDie:
	for test_slots: Array in _slots[int(contest_die.attacking)]:
		for slot: TestSlot in test_slots:
			if slot.die_view != null and slot.die_view.contest_die == contest_die:
				return slot.die_view
	return null


func refresh() -> void:
	for attacking: bool in [true, false]:
		var side := int(attacking)
		var requirements := card.get_requirements(attacking)
		var points := get_points(attacking)
		for test_index in _slots[side].size():
			var in_test: Array = []
			for contest_die: PlayContest.ContestDie in placements[side]:
				if placements[side][contest_die] == test_index:
					in_test.append(contest_die)
			in_test.sort_custom(func(a: PlayContest.ContestDie, b: PlayContest.ContestDie) -> bool:
				return contest.get_die_points_in_test(a, test_index) > contest.get_die_points_in_test(b, test_index))
			var test_slots: Array = _slots[side][test_index]
			for i in test_slots.size():
				_fill_slot(test_slots[i], in_test[i] if i < in_test.size() else null, attacking)
			var label: Label = _totals[side][test_index]
			var needed := requirements[test_index].points
			label.text = "%s / %s" % [MatchDie.format_points(points[test_index]), MatchDie.format_points(needed)]
			var color := ATTACK_COLOR if attacking else DEFENSE_COLOR
			label.add_theme_color_override(&"font_color", color if points[test_index] >= needed - 0.0001 else TEXT)
			var bar: Control = _bars[side][test_index]
			bar.set_meta(&"points", points[test_index])
			bar.set_meta(&"needed", needed)
			bar.queue_redraw()


func _fill_slot(slot: TestSlot, contest_die: PlayContest.ContestDie, attacking: bool) -> void:
	if slot.die_view != null and (contest_die == null or slot.die_view.contest_die != contest_die):
		slot.die_view.queue_free()
		slot.die_view = null
	if contest_die != null and slot.die_view == null:
		var view := MatchDie.create_for(contest_die, MatchDie.DieSize.LARGE)
		view.position = (SLOT_SIZE - DieGraphics.FACE_SIZE) / 2.0
		view.pressed.connect(func(_d: MatchDie) -> void: remove(contest_die))
		view.set_drag_forwarding(_get_slot_drag.bind(contest_die), Callable(), Callable())
		slot.add_child(view)
		slot.die_view = view
	if slot.die_view != null:
		var editable := editable_side == int(attacking)
		slot.die_view.clickable = editable
		slot.die_view.tooltip_text = "%s: %s" % [contest_die.player.data.last_name,
				MatchDie.format_points(contest.get_die_points_in_test(contest_die, slot.test_index))]
	slot.queue_redraw()


## Przeciąganie kości z miejsca (do innego miejsca albo z powrotem na boisko).
func _get_slot_drag(_at_position: Vector2, contest_die: PlayContest.ContestDie) -> Variant:
	if editable_side != int(contest_die.attacking):
		return null
	var preview := Control.new()
	var copy := MatchDie.create_for(contest_die, MatchDie.DieSize.LARGE)
	copy.modulate.a = 0.85
	copy.position = -DieGraphics.FACE_SIZE / 2.0
	preview.add_child(copy)
	set_drag_preview(preview)
	return {"contest_die": contest_die, "from_slot": true}


func _count_in_test(placement: Dictionary, test_index: int) -> int:
	var count := 0
	for contest_die: Variant in placement:
		if placement[contest_die] == test_index:
			count += 1
	return count


# --- Budowa ramek ---

func _build_frame(attacking: bool) -> Control:
	var side := int(attacking)
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = ATTACK_BG if attacking else DEFENSE_BG
	style.set_border_width_all(2)
	style.border_color = ATTACK_BORDER if attacking else DEFENSE_BORDER
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	frame.add_theme_stylebox_override(&"panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	frame.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(_label(tr("MATCH_ATTACK") if attacking else tr("MATCH_DEFENSE"), 14,
			ATTACK_COLOR if attacking else DEFENSE_COLOR))
	var team := _label(team_names[side], 12, MUTED)
	team.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(team)
	var requirements := card.get_requirements(attacking)
	for test_index in requirements.size():
		var requirement := requirements[test_index]
		# Nazwa testu i po prawej symbole cech, którymi można go wypełnić.
		var title := HBoxContainer.new()
		title.add_theme_constant_override(&"separation", 3)
		box.add_child(title)
		var names: Array[String] = []
		var icons: Array[MatchDie] = []
		for attribute_id in requirement.attributes:
			var attribute := GameData.get_attribute(attribute_id)
			names.append(tr(attribute.name_key) if attribute != null else String(attribute_id))
			if attribute != null:
				var icon := MatchDie.create_face(attribute.die_type_id, attribute_id, 1, MatchDie.DieSize.SMALL)
				icon.tooltip_text = tr(attribute.name_key)
				icons.append(icon)
		var test_name := _label(tr("MATCH_OR").join(names), 12, MUTED)
		test_name.clip_text = true
		test_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		test_name.tooltip_text = test_name.text
		test_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_child(test_name)
		for icon in icons:
			title.add_child(icon)
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 4)
		box.add_child(row)
		var test_slots: Array[TestSlot] = []
		for i in get_test_capacity(attacking, test_index):
			var slot := TestSlot.new()
			slot.panel = self
			slot.attacking = attacking
			slot.test_index = test_index
			row.add_child(slot)
			test_slots.append(slot)
		_slots[side].append(test_slots)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var total := _label("", 18, TEXT)
		total.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(total)
		_totals[side].append(total)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, 6)
		bar.draw.connect(_draw_bar.bind(bar, attacking))
		box.add_child(bar)
		_bars[side].append(bar)
	return frame


func _draw_bar(bar: Control, attacking: bool) -> void:
	var points: float = bar.get_meta(&"points", 0.0)
	var needed: float = bar.get_meta(&"needed", 1.0)
	var scale := maxf(maxf(points, needed) * 1.3, 0.1)
	bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color(TEXT, 0.1))
	var fill := ATTACK_COLOR if attacking else DEFENSE_COLOR
	bar.draw_rect(Rect2(Vector2.ZERO, Vector2(bar.size.x * points / scale, bar.size.y)), fill)
	var x := roundf(bar.size.x * needed / scale)
	bar.draw_rect(Rect2(Vector2(x - 1.0, -3.0), Vector2(2.0, bar.size.y + 6.0)), TEXT)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label
