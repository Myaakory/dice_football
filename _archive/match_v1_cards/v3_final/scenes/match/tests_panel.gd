class_name TestsPanel
extends Control
## Rozwinięte zagranie (W16, W17): trzy kolumny – z lewej testy strony gracza (najbliżej boiska, gdzie losują się
## kości), w środku miejsce na kartę zagrania (`center`), z prawej testy strony komputera. Prawa część ekranu jest
## podzielona na 5 pasów na wysokości stref boiska (lekkie przerywane linie przez obie kolumny, pod kartą), a każdy
## test stoi w pasie strefy, której dotyczy: test przy polu startowym – na wysokości startu, przy polu docelowym –
## na wysokości celu (set_zone_rows). Testy jednej strony w tej samej strefie dzielą ramkę.
## Gracz przeciąga swoje kości do miejsc (albo klika kość – trafia do pierwszego pasującego miejsca), AI układa
## swoje (show_placement). Liczą się tylko kości w miejscach. Pod testem: suma punktów, próg i pasek.
## Strzał z testem interwencji bramkarza: ramka bramkarza (fiolet) stoi w środkowej kolumnie, w pasie strefy bramki
## broniących – u góry, gdy strzela gracz (karta zsuwa się wtedy o pas w dół), na dole, gdy strzela komputer.
## Karta w środku mieści się w 4 pasach (ok. 2,5 pasa przy 1080p), więc piąty zostaje dla bramkarza. Ramka pojawia się
## w etapie obrony (show_keeper).

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
## Ramka interwencji bramkarza: fiolet, żeby nie myliła się z zawodnikami z pola.
const KEEPER_BG := Color("#251f3f")
const KEEPER_BORDER := Color("#8b74d8")
const KEEPER_COLOR := Color("#c8b6ff")
const SLOT_EMPTY := Color(0.91, 0.93, 0.87, 0.28)
const SLOT_HOVER := Color("#f2cf4a")
const SLOT_SIZE := Vector2(56, 56)
## Linie granic stref (przez obie kolumny, pod kartą).
const ZONE_LINE := Color(0.91, 0.93, 0.87, 0.16)
## Ile miejsc pokazać przy teście bez limitu kości (max_dice = 0).
const UNLIMITED_SLOTS := 4
## Szerokość środkowej kolumny (karta zagrania).
const CENTER_WIDTH := 360.0
const COLUMN_GAP := 12.0
const FRAME_GAP := 4.0
## Czas zsunięcia karty i pojawienia się ramki bramkarza.
const KEEPER_SLIDE_TIME := 0.35


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
## Podpisy stron: „Ty” / „Komputer” – [obrona, atak].
var owners: Array[String] = ["", ""]
## Strona gracza, którą może teraz układać (-1 = żadna, 0 = obrona, 1 = atak).
var editable_side := -1
## Robocze rozmieszczenie kości obu stron (ContestDie -> indeks testu); indeks = int(attacking).
var placements: Array[Dictionary] = [{}, {}]
## Środkowa kolumna – tu ekran meczu wkłada kartę zagrania.
var center: VBoxContainer

var _slots: Array[Array] = [[], []]  # [strona] -> [test] -> Array[TestSlot]
var _totals: Array[Array] = [[], []]  # [strona] -> Array[Label]
var _bars: Array[Array] = [[], []]  # [strona] -> Array[Control]
## Czy strona gracza stoi w lewej kolumnie (gracz atakuje).
var _human_attacking := true
## Ramki testów: [strona] -> {strefa ekranu (1 = dół boiska): PanelContainer}.
var _frames: Array[Dictionary] = [{}, {}]
## Pasy stref ekranu 1..5 w globalnych współrzędnych (x = góra, y = dół); indeks = strefa − 1.
var _zone_rows: Array[Vector2] = []
var _lines: Control
## Ramka testu interwencji bramkarza (null = karta bez testu bramkarza), strefa ekranu bramki broniących
## i czy ramka jest już pokazana (show_keeper).
var _keeper_frame: PanelContainer
var _keeper_zone := 0
var _keeper_shown := false
var _keeper_name: Label
var _keeper_tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Buduje panel: strona gracza (human_attacking: czy gracz atakuje) z lewej, środek, strona komputera z prawej.
## origin / target – pola zagrania (perspektywa atakujących), attackers_index – drużyna atakująca (0 = gospodarze,
## grają w górę ekranu) – z nich wynika strefa ekranu każdego testu.
func setup(p_card: PlayCard, attackers_name: String, defenders_name: String, human_attacking: bool,
		p_owners: Array[String], origin: Vector2i, target: Vector2i, attackers_index: int) -> void:
	card = p_card
	contest = null
	team_names = [defenders_name, attackers_name]
	owners = p_owners
	placements = [{}, {}]
	editable_side = -1
	_human_attacking = human_attacking
	for child in get_children():
		child.queue_free()
	_slots = [[], []]
	_totals = [[], []]
	_bars = [[], []]
	_frames = [{}, {}]
	_keeper_frame = null
	_keeper_shown = false
	_keeper_name = null
	# Bramka broniących = strefa 5 atakujących (środek); na ekranie u góry albo na dole.
	_keeper_zone = MatchPitch.to_screen(Vector2i(MatchRules.ZONE_COUNT, MatchRules.CHANNEL_CENTER), attackers_index).x
	_lines = Control.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.draw.connect(_draw_zone_lines)
	add_child(_lines)
	var show_location := card.has_origin_tests(true) or card.has_origin_tests(false)
	for attacking: bool in [true, false]:
		var side := int(attacking)
		var requirements := card.get_requirements(attacking)
		var zones: Array[int] = []
		var counts := {}
		for test_index in requirements.size():
			var cell := origin if requirements[test_index].is_at_origin() else target
			var zone := MatchPitch.to_screen(cell, attackers_index).x
			zones.append(zone)
			if not requirements[test_index].is_keeper():
				counts[zone] = counts.get(zone, 0) + 1
		# Testy budujemy w kolejności indeksów (_slots[strona][test]), test bramkarza trafia do własnej ramki.
		for test_index in requirements.size():
			if requirements[test_index].is_keeper():
				if _keeper_frame == null:
					_keeper_frame = _build_keeper_frame()
					add_child(_keeper_frame)
				_keeper_frame.get_child(0).add_child(_build_test(attacking, test_index, false))
				continue
			var zone := zones[test_index]
			var frame: PanelContainer = _frames[side].get(zone)
			if frame == null:
				frame = _build_frame(attacking)
				_frames[side][zone] = frame
				add_child(frame)
			# Kilka testów w jednej strefie – zwinięte do jednego wiersza, żeby ramka zmieściła się w pasie strefy.
			frame.get_child(0).add_child(_build_test(attacking, test_index, show_location, counts[zone] > 1))
	center = VBoxContainer.new()
	add_child(center)
	refresh()
	_layout.call_deferred()


## Pasy stref ekranu 1..5 (indeks = strefa − 1): x = góra, y = dół w globalnych współrzędnych ekranu.
func set_zone_rows(global_rows: Array[Vector2]) -> void:
	_zone_rows = global_rows.duplicate()
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


## Kolumny i ramki: ramka stoi na środku pasa swojej strefy, ramki jednej kolumny się nie nakładają.
func _layout() -> void:
	if card == null or center == null:
		return
	var column_width := maxf((size.x - CENTER_WIDTH - COLUMN_GAP * 2.0) / 2.0, 0.0)
	var center_x := column_width + COLUMN_GAP
	if _keeper_frame != null:
		_keeper_frame.visible = _keeper_shown
		var keeper_height := _keeper_frame.get_combined_minimum_size().y
		var keeper_row := _get_zone_row(_keeper_zone)
		var keeper_y := clampf(maxf(keeper_row.x + 2.0, (keeper_row.x + keeper_row.y - keeper_height) / 2.0), 0.0,
				maxf(size.y - keeper_height, 0.0))
		_keeper_frame.position = Vector2(center_x, roundf(keeper_y))
		_keeper_frame.size = Vector2(CENTER_WIDTH, keeper_height)
	if _keeper_tween == null or not _keeper_tween.is_running():
		center.position = Vector2(center_x, _get_center_y())
	center.size = Vector2(CENTER_WIDTH, center.get_combined_minimum_size().y)
	_lines.position = Vector2.ZERO
	_lines.size = size
	_lines.queue_redraw()
	for attacking: bool in [true, false]:
		var side := int(attacking)
		var x := 0.0 if attacking == _human_attacking else size.x - column_width
		var zones: Array = _frames[side].keys()
		zones.sort_custom(func(a: int, b: int) -> bool: return a > b)  # od góry ekranu (strefa 5)
		var bottom := 0.0
		for zone: int in zones:
			var frame: PanelContainer = _frames[side][zone]
			var height := frame.get_combined_minimum_size().y
			var row := _get_zone_row(zone)
			var y := maxf(row.x + 2.0, (row.x + row.y - height) / 2.0)
			y = clampf(maxf(y, bottom), 0.0, maxf(size.y - height, 0.0))
			frame.position = Vector2(x, roundf(y))
			frame.size = Vector2(column_width, height)
			bottom = y + height + FRAME_GAP


## Góra karty w środku: u góry panelu, a gdy ramka bramkarza stoi w górnym pasie – pod nią (karta zsunięta o pas).
func _get_center_y() -> float:
	if _keeper_frame == null or not _keeper_shown or _keeper_zone != MatchRules.ZONE_COUNT:
		return 0.0
	return roundf(_get_zone_row(_keeper_zone).y + FRAME_GAP)


## Pokazuje ramkę interwencji bramkarza (etap obrony przy strzale). Gdy bramkarz stoi u góry, karta zsuwa się o pas.
func show_keeper(animate := true) -> void:
	if _keeper_frame == null or _keeper_shown:
		return
	var from_y := center.position.y
	_keeper_shown = true
	_layout()
	if not animate:
		return
	var to_y := _get_center_y()
	var keeper_y := _keeper_frame.position.y
	var drop := -12.0 if _keeper_zone == MatchRules.ZONE_COUNT else 12.0
	center.position.y = from_y
	_keeper_frame.modulate.a = 0.0
	_keeper_frame.position.y = keeper_y + drop
	if _keeper_tween != null:
		_keeper_tween.kill()
	_keeper_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_keeper_tween.tween_property(center, "position:y", to_y, KEEPER_SLIDE_TIME)
	_keeper_tween.tween_property(_keeper_frame, "position:y", keeper_y, KEEPER_SLIDE_TIME)
	_keeper_tween.tween_property(_keeper_frame, "modulate:a", 1.0, KEEPER_SLIDE_TIME)
	await _keeper_tween.finished


## Pas strefy ekranu (x = góra, y = dół) – bez danych z boiska: równy podział wysokości panelu.
func _get_zone_row(zone: int) -> Vector2:
	if _zone_rows.size() == MatchRules.ZONE_COUNT:
		var top := get_global_rect().position.y
		return _zone_rows[zone - 1] - Vector2(top, top)
	var height := size.y / MatchRules.ZONE_COUNT
	var top := (MatchRules.ZONE_COUNT - zone) * height
	return Vector2(top, top + height)


## Granice stref: przerywane linie przez całą szerokość (karta w środku je przykrywa).
func _draw_zone_lines() -> void:
	var ys := {}
	for zone in range(1, MatchRules.ZONE_COUNT + 1):
		var row := _get_zone_row(zone)
		ys[roundf(row.x)] = true
		ys[roundf(row.y)] = true
	for y: float in ys:
		if y >= 0.0 and y <= size.y:
			_lines.draw_dashed_line(Vector2(0.0, y), Vector2(size.x, y), ZONE_LINE, 1.0, 6.0)


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
			var color := _get_test_color(attacking, test_index)
			label.add_theme_color_override(&"font_color", color if points[test_index] >= needed - 0.0001 else TEXT)
			var bar: Control = _bars[side][test_index]
			bar.set_meta(&"points", points[test_index])
			bar.set_meta(&"needed", needed)
			bar.queue_redraw()
	if _keeper_name != null and contest != null:
		for contest_die in contest.defense_dice:
			if contest_die.keeper_efficiency > 0.0:
				_keeper_name.text = "%s · %s" % [_keeper_name.get_meta(&"owner"), contest_die.player.data.last_name]
				break


## Kolor testu: atak zielony, obrona pomarańczowa, interwencja bramkarza fioletowa.
func _get_test_color(attacking: bool, test_index: int) -> Color:
	if attacking:
		return ATTACK_COLOR
	return KEEPER_COLOR if card.defense[test_index].is_keeper() else DEFENSE_COLOR


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

## Ramka strony w jednej strefie: nagłówek „Atak · Ty · RRV”, pod nim testy tej strefy (dokłada setup).
func _build_frame(attacking: bool) -> PanelContainer:
	var side := int(attacking)
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = ATTACK_BG if attacking else DEFENSE_BG
	style.set_border_width_all(2)
	style.border_color = ATTACK_BORDER if attacking else DEFENSE_BORDER
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	style.content_margin_top = 5
	frame.add_theme_stylebox_override(&"panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	frame.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(_label(tr("MATCH_ATTACK") if attacking else tr("MATCH_DEFENSE"), 14,
			ATTACK_COLOR if attacking else DEFENSE_COLOR))
	var who := team_names[side] if owners[side].is_empty() else "%s · %s" % [owners[side], team_names[side]]
	var team := _label(who, 12, MUTED)
	team.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(team)
	return frame


## Ramka interwencji bramkarza (środkowa kolumna): nagłówek „Interwencja bramkarza · Ty · RRV · Kowal”, pod nim test.
func _build_keeper_frame() -> PanelContainer:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = KEEPER_BG
	style.set_border_width_all(2)
	style.border_color = KEEPER_BORDER
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	style.content_margin_top = 5
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_offset = Vector2(0, 3)
	style.shadow_size = 1
	frame.add_theme_stylebox_override(&"panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	frame.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(_label(tr("MATCH_KEEPER_TEST"), 14, KEEPER_COLOR))
	var owner := team_names[0] if owners[0].is_empty() else "%s · %s" % [owners[0], team_names[0]]
	_keeper_name = _label(owner, 12, MUTED)
	_keeper_name.set_meta(&"owner", owner)
	_keeper_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_keeper_name)
	frame.visible = false
	return frame


## Jeden test: [miejsce] ikony cech, nazwy | miejsca na kości, suma / próg | pasek.
## Zwinięty (compact): jeden wiersz – [miejsce nad ikonami cech] miejsca na kości, suma / próg; nazwy w podpowiedzi,
## bez paska (zaliczenie pokazuje kolor sumy).
func _build_test(attacking: bool, test_index: int, show_location: bool, compact := false) -> Control:
	var side := int(attacking)
	var requirement := card.get_requirements(attacking)[test_index]
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	var place: Label = null
	if show_location:
		place = _label(tr("MATCH_TEST_AT_ORIGIN") if requirement.is_at_origin() else tr("MATCH_TEST_AT_TARGET"),
				11, SLOT_HOVER)
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override(&"separation", 3)
	var names: Array[String] = []
	for attribute_id in requirement.attributes:
		var attribute := GameData.get_attribute(attribute_id)
		names.append(tr(attribute.name_key) if attribute != null else String(attribute_id))
		if attribute != null:
			var icon := MatchDie.create_face(attribute.die_type_id, attribute_id, 1, MatchDie.DieSize.SMALL)
			icon.tooltip_text = tr(attribute.name_key)
			icons.add_child(icon)
	var names_text := tr("MATCH_OR").join(names)
	if compact:
		var label_box := VBoxContainer.new()
		label_box.add_theme_constant_override(&"separation", 1)
		label_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label_box.tooltip_text = names_text
		if place != null:
			label_box.add_child(place)
		label_box.add_child(icons)
		row.add_child(label_box)
	else:
		var title := HBoxContainer.new()
		title.add_theme_constant_override(&"separation", 3)
		box.add_child(title)
		if place != null:
			title.add_child(place)
		title.add_child(icons)
		var test_name := _label(names_text, 12, MUTED)
		test_name.clip_text = true
		test_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		test_name.tooltip_text = names_text
		test_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_child(test_name)
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
	bar.draw.connect(_draw_bar.bind(bar, _get_test_color(attacking, test_index)))
	bar.visible = not compact
	box.add_child(bar)
	_bars[side].append(bar)
	return box


func _draw_bar(bar: Control, fill: Color) -> void:
	var points: float = bar.get_meta(&"points", 0.0)
	var needed: float = bar.get_meta(&"needed", 1.0)
	var scale := maxf(maxf(points, needed) * 1.3, 0.1)
	bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color(TEXT, 0.1))
	bar.draw_rect(Rect2(Vector2.ZERO, Vector2(bar.size.x * points / scale, bar.size.y)), fill)
	var x := roundf(bar.size.x * needed / scale)
	bar.draw_rect(Rect2(Vector2(x - 1.0, -3.0), Vector2(2.0, bar.size.y + 6.0)), TEXT)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label
