extends Control
## Edytor zagrań (narzędzie deweloperskie w grze): lista kart, boisko ze strefami zagrania i podglądem pola akcji,
## podgląd karty tak jak w meczu z szansami testów (do ręcznego strojenia progów) oraz panel właściwości (model v4 –
## PlayCard). Dane wczytuje i zapisuje PlayLibrary (res://data/plays/plays.json)
## – scena tylko ją wywołuje.
##
## Boisko: LPM (pole albo numer strefy po lewej) przełącza strefę, z której można zagrać kartę; PPM wybiera strefę
## podglądu (pole piłki w kanale celu, pole akcji, przelot i mnożniki udziału).
## Podgląd karty: domyślne składy drużyny gracza i rywala (Lineup.create_default), atakująca drużyna do przełączenia;
## szanse jednym rzutem, bez przesunięć i przerzutów (DiceOdds – te same, z których korzysta AI).
## Ctrl+S zapisuje, Esc wraca do menu (z pytaniem o niezapisane zmiany).

const SECTION_COLOR := Color("#f0e6a8")
const DIM_TEXT := Color(0.91, 0.937, 0.878, 0.6)
const ERROR_TEXT := Color("#ff9a7a")
const LEFT_WIDTH := 236.0
## Kolumna podglądu karty (karta jak w ręce w meczu i szanse testów).
const PREVIEW_WIDTH := 330.0
const ATTACK_TEXT := Color("#b8f08a")
const DEFENSE_TEXT := Color("#ffb070")
const KEEPER_TEXT := Color("#c8b6ff")
## Test bramkarza dodawany przyciskiem (jak w talii v4 po kalibracji B4).
const DEFAULT_KEEPER_ATTRIBUTES: Array[StringName] = [&"jump", &"catching"]
const DEFAULT_KEEPER_POINTS := 3.0
const DEFAULT_KEEPER_DICE := 2
const MAX_LISTED_ERRORS := 12
## Kolumny checkboxów taktyk (panel właściwości musi się zmieścić obok boiska).
const TACTIC_COLUMNS := 3
## Litery korytarzy w opisach pól (np. „3Ś”).
const CHANNEL_LETTER_KEYS: Array[String] = ["EDITOR_CHANNEL_LETTER_LEFT", "EDITOR_CHANNEL_LETTER_CENTER",
		"EDITOR_CHANNEL_LETTER_RIGHT"]

var _library: PlayLibrary
## Tekst pliku po ostatnim wczytaniu / zapisie i podpis każdej karty z tej chwili (wykrywanie zmian).
var _saved_text := ""
var _saved_cards: Dictionary = {}
var _card: PlayCard
## Strefa piłki w podglądzie na boisku (0 = brak).
var _preview_zone := 0
## Taktyka filtra listy (pusta = wszystkie).
var _tactic_filter: StringName = &""
var _visible_cards: Array[PlayCard] = []
var _attribute_icons: Dictionary[StringName, Texture2D] = {}

var _list: ItemList
var _filter_option: OptionButton
var _count_label: Label
var _status_label: Label
var _delete_button: Button
var _duplicate_button: Button
var _pitch: PlayPitch
var _scroll: ScrollContainer
var _props: VBoxContainer
var _active_label: Label
var _preview_box: VBoxContainer
var _attacker_button: Button
## Drużyny podglądu (domyślne składy) i indeks atakującej; zasady meczu jak w grze.
var _preview_teams: Array[MatchTeam] = []
var _preview_attacker := 0
var _preview_rules := MatchRules.new()
var _dialog: ModalDialog
var _toast: ToastMessage


func _ready() -> void:
	for attribute_id in DieGraphics.ATTRIBUTE_ORDER:
		var attribute := GameData.get_attribute(attribute_id)
		var type_id := attribute.die_type_id if attribute != null else &""
		_attribute_icons[attribute_id] = DieGraphics.make_attribute_icon(attribute_id, type_id)
	var home := Lineup.create_default(GameState.get_player_team())
	var away := Lineup.create_default(GameState.get_opponent_team(home.team))
	var no_deck: Array[PlayCard] = []
	for lineup in [home, away]:
		_preview_teams.append(MatchTeam.create(lineup, no_deck, _preview_rules))
	_build_layout()
	_load_library()


func _shortcut_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S \
			and (event.ctrl_pressed or event.meta_pressed) and not _dialog.visible:
		get_viewport().set_input_as_handled()
		_save()


func _unhandled_input(event: InputEvent) -> void:
	if _dialog.visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_request_exit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _library != null:
		# Teksty liczone przez tr() (licznik, status, opis aktywnego pola) trzeba przeliczyć.
		_count_label.text = tr("EDITOR_PLAY_COUNT") % [_visible_cards.size(), _library.plays.size()]
		_update_status()
		_rebuild_properties()
		_pitch.queue_redraw()


# --- Układ ekranu ---

func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = Color(0.078, 0.129, 0.102, 1)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 12)
	margin.add_child(columns)

	columns.add_child(_build_list_column())
	columns.add_child(_build_pitch_column())
	columns.add_child(_build_preview_column())

	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_scroll)
	var props_margin := MarginContainer.new()
	props_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		props_margin.add_theme_constant_override("margin_" + side, 10)
	props_margin.add_theme_constant_override(&"margin_right", 16)
	_scroll.add_child(props_margin)
	_props = VBoxContainer.new()
	_props.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_props.add_theme_constant_override(&"separation", 8)
	props_margin.add_child(_props)

	_toast = ToastMessage.new()
	add_child(_toast)
	_dialog = ModalDialog.new()
	add_child(_dialog)


func _build_list_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(LEFT_WIDTH, 0.0)
	column.add_theme_constant_override(&"separation", 8)
	var title := _make_label("EDITOR_TITLE", 24, SECTION_COLOR)
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	column.add_child(title)

	_filter_option = OptionButton.new()
	_filter_option.add_item("EDITOR_FILTER_ALL_TACTICS")
	_filter_option.set_item_metadata(0, &"")
	for tactic in GameData.get_tactic_list():
		_filter_option.add_item(tactic.name)
		_filter_option.set_item_metadata(_filter_option.item_count - 1, tactic.id)
	_filter_option.item_selected.connect(_on_filter_selected)
	column.add_child(_filter_option)
	_count_label = _make_label("", 13, DIM_TEXT)
	column.add_child(_count_label)

	_list = ItemList.new()
	_list.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_size_override(&"font_size", 15)
	_list.item_selected.connect(_on_list_item_selected)
	column.add_child(_list)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	column.add_child(row)
	var new_button := _make_button("EDITOR_NEW", _on_new_pressed, 14)
	new_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(new_button)
	_duplicate_button = _make_button("EDITOR_DUPLICATE", _on_duplicate_pressed, 14)
	_duplicate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_duplicate_button)
	_delete_button = _make_button("EDITOR_DELETE", _on_delete_pressed, 14)
	_delete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_delete_button)

	var save_button := _make_button("EDITOR_SAVE", _save, 18)
	save_button.custom_minimum_size = Vector2(0.0, 42.0)
	save_button.tooltip_text = "EDITOR_SAVE_TOOLTIP"
	column.add_child(save_button)
	column.add_child(_make_button("EDITOR_BACK_TO_MENU", _request_exit, 16))
	_status_label = _make_label("", 13, DIM_TEXT)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status_label)
	return column


func _build_pitch_column() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_pitch = PlayPitch.new()
	_pitch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pitch.cell_clicked.connect(_on_cell_clicked)
	_pitch.zone_clicked.connect(_on_zone_clicked)
	column.add_child(_pitch)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override(&"separation", 6)
	column.add_child(toolbar)
	var hint := _make_label("EDITOR_PITCH_HINT", 13, DIM_TEXT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(hint)
	var all_button := _make_button("EDITOR_ALL_ZONES", _on_all_zones_pressed, 14)
	all_button.tooltip_text = "EDITOR_ALL_ZONES_TOOLTIP"
	toolbar.add_child(all_button)
	var clear_button := _make_button("EDITOR_CLEAR", _on_clear_pressed, 14)
	clear_button.tooltip_text = "EDITOR_CLEAR_TOOLTIP"
	toolbar.add_child(clear_button)
	return column


## Podgląd karty: nagłówek z przełącznikiem atakującej drużyny, karta (PlayCardView jak w ręce) i szanse testów.
func _build_preview_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(PREVIEW_WIDTH, 0.0)
	column.add_theme_constant_override(&"separation", 6)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _make_label("EDITOR_PREVIEW_TITLE", 16, SECTION_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_attacker_button = _make_button("", func() -> void:
		_preview_attacker = 1 - _preview_attacker
		_update_card_preview(), 13)
	_attacker_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_attacker_button.tooltip_text = "EDITOR_PREVIEW_ATTACKER_TOOLTIP"
	header.add_child(_attacker_button)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_preview_box = VBoxContainer.new()
	_preview_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_box.add_theme_constant_override(&"separation", 3)
	scroll.add_child(_preview_box)
	return column


# --- Dane ---

func _load_library() -> void:
	_library = PlayLibrary.load_default()
	if not _library.load_error.is_empty():
		push_error("PlayEditor: %s" % _library.load_error)
		_dialog.open(tr("EDITOR_LOAD_FAILED_TITLE"), tr("EDITOR_LOAD_FAILED") % _library.load_error,
				["COMMON_OK"])
	_remember_saved_state()
	_rebuild_list()
	_select_card(_visible_cards[0] if not _visible_cards.is_empty() else null)


func _remember_saved_state() -> void:
	_saved_text = _library.to_json_text()
	_saved_cards.clear()
	for card in _library.plays:
		_saved_cards[card] = _card_signature(card)


func _card_signature(card: PlayCard) -> String:
	return JSON.stringify(card.to_dict(), "", false)


func _is_dirty() -> bool:
	return _library.to_json_text() != _saved_text


func _is_card_dirty(card: PlayCard) -> bool:
	return _saved_cards.get(card, "") != _card_signature(card)


func _get_tactic_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for tactic in GameData.get_tactic_list():
		ids.append(tactic.id)
	return ids


func _get_attribute_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(GameData.attributes.keys())
	return ids


## Wywoływane po każdej zmianie danych karty (bez przebudowy panelu, żeby nie gubić fokusu).
func _on_card_changed() -> void:
	_update_list_texts()
	_update_status()
	_update_preview_label()
	_update_card_preview()
	_pitch.queue_redraw()


func _save() -> void:
	if not _library.load_error.is_empty():
		# Plik nie wczytał się poprawnie – nie nadpisujemy go niepełnymi danymi.
		_dialog.open(tr("EDITOR_SAVE_FAILED_TITLE"), tr("EDITOR_LOAD_FAILED") % _library.load_error, ["COMMON_OK"])
		return
	var errors := _library.validate(_get_attribute_ids(), _get_tactic_ids())
	if not errors.is_empty():
		_show_errors(errors)
		return
	var error := _library.save_file()
	if error != OK:
		_dialog.open(tr("EDITOR_SAVE_FAILED_TITLE"), tr("EDITOR_SAVE_FAILED") % error_string(error),
				["COMMON_OK"])
		return
	_remember_saved_state()
	_on_card_changed()
	_toast.show_message(tr("EDITOR_SAVED") % _library.plays.size(), 2.0)


func _show_errors(errors: Array[Dictionary]) -> void:
	var lines := PackedStringArray()
	for i in mini(errors.size(), MAX_LISTED_ERRORS):
		var card := _library.plays[errors[i]["play"]]
		var label := card.name if not card.name.strip_edges().is_empty() else String(card.id)
		lines.append("• %s: %s" % [label, PlayLibrary.format_error(errors[i])])
	if errors.size() > MAX_LISTED_ERRORS:
		lines.append(tr("EDITOR_MORE_ERRORS") % (errors.size() - MAX_LISTED_ERRORS))
	# Od razu pokazujemy pierwszą kartę z błędem.
	var first: PlayCard = _library.plays[errors[0]["play"]]
	if first != _card:
		if not first in _visible_cards:
			_filter_option.select(0)
			_on_filter_selected(0)
		_select_card(first)
	_dialog.open(tr("EDITOR_VALIDATION_TITLE"), "\n".join(lines), ["COMMON_OK"])


# --- Lista ---

func _rebuild_list() -> void:
	_visible_cards.clear()
	for card in _library.plays:
		if _tactic_filter == &"" or card.is_in_tactic(_tactic_filter):
			_visible_cards.append(card)
	_list.clear()
	for card in _visible_cards:
		_list.add_item("")
	_update_list_texts()
	_count_label.text = tr("EDITOR_PLAY_COUNT") % [_visible_cards.size(), _library.plays.size()]


func _update_list_texts() -> void:
	for i in _visible_cards.size():
		var card := _visible_cards[i]
		var label := card.name if not card.name.strip_edges().is_empty() else String(card.id)
		_list.set_item_text(i, ("* " if _is_card_dirty(card) else "") + label)
		_list.set_item_tooltip(i, String(card.id))
		if card == _card:
			_list.select(i)
	_update_status()


func _update_status() -> void:
	var dirty := _is_dirty()
	_status_label.text = tr("EDITOR_UNSAVED") if dirty else tr("EDITOR_ALL_SAVED")
	_status_label.add_theme_color_override(&"font_color", ERROR_TEXT if dirty else DIM_TEXT)


func _select_card(card: PlayCard) -> void:
	_card = card
	_preview_zone = card.zones[0] if card != null and not card.zones.is_empty() else 0
	_list.deselect_all()
	var index := _visible_cards.find(card)
	if index != -1:
		_list.select(index)
		_list.ensure_current_is_visible()
	_duplicate_button.disabled = card == null
	_delete_button.disabled = card == null
	_pitch.set_card(card, _preview_zone)
	_rebuild_properties()
	_update_card_preview()
	_scroll.scroll_vertical = 0


func _on_list_item_selected(index: int) -> void:
	if index >= 0 and index < _visible_cards.size() and _visible_cards[index] != _card:
		_select_card(_visible_cards[index])


func _on_filter_selected(index: int) -> void:
	_tactic_filter = _filter_option.get_item_metadata(index)
	_rebuild_list()
	if not _card in _visible_cards:
		_select_card(_visible_cards[0] if not _visible_cards.is_empty() else null)
	else:
		_update_list_texts()


func _on_new_pressed() -> void:
	var card := PlayCard.create_default(_library.make_unique_id("new_play"), _get_tactic_ids())
	card.name = tr("EDITOR_NEW_PLAY_NAME")
	_insert_card(card)


func _on_duplicate_pressed() -> void:
	if _card == null:
		return
	var copy := _card.duplicate_card(_library.make_unique_id(String(_card.id) + "_copy"))
	copy.name = _card.name + tr("EDITOR_COPY_SUFFIX")
	_insert_card(copy)


func _insert_card(card: PlayCard) -> void:
	var index := _library.plays.find(_card)
	_library.plays.insert(index + 1 if index != -1 else _library.plays.size(), card)
	if _tactic_filter != &"" and not card.is_in_tactic(_tactic_filter):
		_filter_option.select(0)
		_tactic_filter = &""
	_rebuild_list()
	_select_card(card)


func _on_delete_pressed() -> void:
	if _card == null:
		return
	var label := _card.name if not _card.name.is_empty() else String(_card.id)
	_dialog.closed.connect(_on_delete_confirmed, CONNECT_ONE_SHOT)
	_dialog.open(tr("EDITOR_CONFIRM_DELETE_TITLE"), tr("EDITOR_CONFIRM_DELETE") % label,
			["EDITOR_DELETE", "COMMON_CANCEL"])


func _on_delete_confirmed(choice: int) -> void:
	if choice != 0 or _card == null:
		return
	var visible_index := _visible_cards.find(_card)
	_library.plays.erase(_card)
	_rebuild_list()
	var next: PlayCard = null
	if not _visible_cards.is_empty():
		next = _visible_cards[clampi(visible_index, 0, _visible_cards.size() - 1)]
	_select_card(next)


func _request_exit() -> void:
	if not _is_dirty():
		SceneManager.change_scene(SceneManager.MAIN_MENU)
		return
	_dialog.closed.connect(_on_exit_choice, CONNECT_ONE_SHOT)
	_dialog.open(tr("EDITOR_CONFIRM_EXIT_TITLE"), tr("EDITOR_CONFIRM_EXIT"),
			["EDITOR_SAVE_AND_EXIT", "EDITOR_EXIT_WITHOUT_SAVING", "COMMON_CANCEL"])


func _on_exit_choice(choice: int) -> void:
	match choice:
		0:
			_save()
			if not _is_dirty():
				SceneManager.change_scene(SceneManager.MAIN_MENU)
		1:
			SceneManager.change_scene(SceneManager.MAIN_MENU)


# --- Boisko ---

## LPM przełącza strefę zagrania (pole albo numer strefy), PPM wybiera strefę podglądu.
func _on_cell_clicked(cell: Vector2i, button: int, _ctrl: bool, _shift: bool) -> void:
	if _card == null:
		return
	if button == MOUSE_BUTTON_RIGHT:
		if _card.can_play_zone(cell.x):
			_set_preview_zone(cell.x)
		return
	_toggle_zone(cell.x)


func _on_zone_clicked(zone: int) -> void:
	if _card != null:
		_toggle_zone(zone)


func _on_all_zones_pressed() -> void:
	if _card == null:
		return
	_card.zones.clear()
	for zone in range(1, MatchRules.ZONE_COUNT + 1):
		_card.zones.append(zone)
	if _preview_zone == 0:
		_set_preview_zone(1, false)
	_after_zones_changed()


func _on_clear_pressed() -> void:
	if _card == null:
		return
	_card.zones.clear()
	_set_preview_zone(0, false)
	_after_zones_changed()


func _toggle_zone(zone: int) -> void:
	if _card.can_play_zone(zone):
		_card.zones.erase(zone)
		if _preview_zone == zone:
			_set_preview_zone(_card.zones[0] if not _card.zones.is_empty() else 0, false)
	else:
		_card.zones.append(zone)
		_card.zones.sort()
		_set_preview_zone(zone, false)
	_after_zones_changed()


## Po zmianie stref: dane, podgląd i pola wyboru stref w panelu.
func _after_zones_changed() -> void:
	_on_card_changed()
	_rebuild_properties_keep_scroll.call_deferred()


func _set_preview_zone(zone: int, notify := true) -> void:
	_preview_zone = zone
	_pitch.preview_zone = zone
	if notify:
		_update_preview_label()
		_update_card_preview()
		_pitch.queue_redraw()


## Opis podglądu: piłka w strefie podglądu i pola akcji (cele).
func _update_preview_label() -> void:
	if _active_label == null or not is_instance_valid(_active_label) or _card == null:
		return
	if not _card.can_play_zone(_preview_zone):
		_active_label.text = tr("EDITOR_NO_PREVIEW_ZONE")
		return
	var targets := PackedStringArray()
	for target in _card.get_targets(_preview_zone):
		targets.append(_cell_name(target))
	_active_label.text = tr("EDITOR_PREVIEW_ZONE") % [_preview_zone, ", ".join(targets)]


## Karta w podglądzie (jak w ręce w meczu) i szanse testów dla strefy podglądu i pierwszego celu.
func _update_card_preview() -> void:
	if _preview_box == null:
		return
	for child in _preview_box.get_children():
		_preview_box.remove_child(child)
		child.queue_free()
	var attackers := _preview_teams[_preview_attacker]
	var defenders := _preview_teams[1 - _preview_attacker]
	_attacker_button.text = tr("EDITOR_PREVIEW_ATTACKER") % attackers.get_short_name()
	if _card == null:
		return
	if not _card.can_play_zone(_preview_zone):
		var none := _make_label("EDITOR_NO_PREVIEW_ZONE", 13, DIM_TEXT)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_preview_box.add_child(none)
		return
	var targets := _card.get_targets(_preview_zone)
	var target := targets[0]
	var contest := PlayContest.create(_card, PlayCard.get_origin(_preview_zone, target), target, attackers, defenders,
			_preview_rules)
	var chances := Vector2(DiceOdds.fill_probability(contest, true), DiceOdds.fill_probability(contest, false))
	var context := {"attackers": attackers, "defenders": defenders, "rules": _preview_rules,
			"owners": [defenders.get_short_name(), attackers.get_short_name()], "flipped": false}
	var view := PlayCardView.create(_card, PlayCardView.Mode.PORTRAIT, _preview_zone, targets, chances * 100.0, context)
	view.custom_minimum_size = Vector2(PREVIEW_WIDTH, 0.0)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_box.add_child(view)

	var title := _make_label("", 14, SECTION_COLOR)
	title.text = tr("EDITOR_ODDS_TITLE") % [_preview_zone, _cell_name(target)]
	_preview_box.add_child(title)
	for attacking: bool in [true, false]:
		var tests := _card.get_requirements(attacking)
		for i in tests.size():
			var odds := DiceOdds.test_odds(contest, attacking, i)
			var side := tr("MATCH_KEEPER_SHORT") if tests[i].is_keeper() else \
					tr("EDITOR_SIDE_ATTACK" if attacking else "EDITOR_SIDE_DEFENSE")
			var color := KEEPER_TEXT if tests[i].is_keeper() else (ATTACK_TEXT if attacking else DEFENSE_TEXT)
			var line := _make_label("", 13, color)
			line.text = tr("EDITOR_ODDS_TEST") % [side, i + 1, MatchDie.format_points(snappedf(odds.x, 0.1)),
					MatchDie.format_points(tests[i].points), roundi(odds.y * 100.0)]
			var names := PackedStringArray()
			for attribute_id in tests[i].attributes:
				var attribute := GameData.get_attribute(attribute_id)
				names.append(tr(attribute.name_key) if attribute != null else String(attribute_id))
			line.tooltip_text = tr("MATCH_OR").join(names)
			line.mouse_filter = Control.MOUSE_FILTER_PASS
			_preview_box.add_child(line)
	var duel := _make_label("", 13, DIM_TEXT)
	duel.text = tr("EDITOR_ODDS_DUEL") % roundi(DiceOdds.duel_probability(contest) * 100.0)
	_preview_box.add_child(duel)
	var note := _make_label("EDITOR_ODDS_NOTE", 12, DIM_TEXT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_box.add_child(note)


func _cell_name(cell: Vector2i) -> String:
	return "%d%s" % [cell.x, tr(CHANNEL_LETTER_KEYS[cell.y])]


# --- Panel właściwości ---

func _rebuild_properties() -> void:
	for child in _props.get_children():
		_props.remove_child(child)
		child.queue_free()
	_active_label = null
	# Usunięte pola wyboru taktyk nie wyślą już mouse_exited.
	_pitch.set_preview_tactic(null)
	if _card == null:
		_props.add_child(_make_label("EDITOR_NO_PLAY", 16, DIM_TEXT))
		return
	_build_general_section()
	_build_tactics_section()
	_build_triggers_section()
	_build_movement_section()
	_build_tests_section(true)
	_build_tests_section(false)
	_build_outcomes_section()


## Przebudowa panelu po zmianie struktury (dodanie / usunięcie testu itp.) z zachowaniem przewinięcia.
func _rebuild_properties_keep_scroll() -> void:
	var scroll := _scroll.scroll_vertical
	_rebuild_properties()
	_on_card_changed()
	await get_tree().process_frame
	_scroll.scroll_vertical = scroll


func _build_general_section() -> void:
	var box := _add_section("EDITOR_SECTION_GENERAL")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 6)
	box.add_child(grid)

	grid.add_child(_make_label("EDITOR_FIELD_ID", 14))
	var id_edit := LineEdit.new()
	id_edit.text = String(_card.id)
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_edit.tooltip_text = "EDITOR_FIELD_ID_TOOLTIP"
	id_edit.text_changed.connect(func(text: String) -> void:
		_card.id = StringName(text.strip_edges())
		_on_card_changed())
	grid.add_child(id_edit)

	grid.add_child(_make_label("EDITOR_FIELD_NAME", 14))
	var name_edit := LineEdit.new()
	name_edit.text = _card.name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(text: String) -> void:
		_card.name = text
		_on_card_changed())
	grid.add_child(name_edit)

	var description_label := _make_label("EDITOR_FIELD_DESCRIPTION", 14)
	description_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid.add_child(description_label)
	var description_edit := TextEdit.new()
	description_edit.text = _card.description
	description_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	description_edit.custom_minimum_size = Vector2(0.0, 86.0)
	description_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_edit.add_theme_font_size_override(&"font_size", 14)
	description_edit.text_changed.connect(func() -> void:
		_card.description = description_edit.text
		_on_card_changed())
	grid.add_child(description_edit)

	grid.add_child(Control.new())
	var shot_check := CheckBox.new()
	shot_check.text = "EDITOR_FIELD_SHOT"
	shot_check.tooltip_text = "EDITOR_FIELD_SHOT_TOOLTIP"
	shot_check.button_pressed = _card.is_shot
	shot_check.toggled.connect(_on_shot_toggled)
	grid.add_child(shot_check)


func _on_shot_toggled(pressed: bool) -> void:
	_card.is_shot = pressed
	# Wygodna zamiana efektów sukcesu: awans <-> gol.
	for slot: StringName in [&"success", &"duel_won"]:
		if pressed and _card.get_outcome(slot) == PlayEvents.ADVANCE:
			_card.outcomes[slot] = PlayEvents.GOAL
		elif not pressed and _card.get_outcome(slot) == PlayEvents.GOAL:
			_card.outcomes[slot] = PlayEvents.ADVANCE
	_rebuild_properties_keep_scroll.call_deferred()


func _build_tactics_section() -> void:
	var box := _add_section("EDITOR_SECTION_TACTICS", "EDITOR_SECTION_TACTICS_HINT")
	var grid := GridContainer.new()
	grid.columns = TACTIC_COLUMNS
	grid.add_theme_constant_override(&"h_separation", 4)
	box.add_child(grid)
	var all_ids := _get_tactic_ids()
	for tactic in GameData.get_tactic_list():
		var check := CheckBox.new()
		check.text = tactic.name
		check.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		check.add_theme_font_size_override(&"font_size", 13)
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.button_pressed = _card.is_in_tactic(tactic.id)
		# Najechanie pokazuje na boisku ustawienie zawodników tej taktyki.
		check.mouse_entered.connect(func() -> void: _pitch.set_preview_tactic(tactic))
		check.mouse_exited.connect(func() -> void: _pitch.set_preview_tactic(null))
		check.toggled.connect(func(pressed: bool) -> void:
			var ids: Array[StringName] = []
			for id in all_ids:
				if (id == tactic.id and pressed) or (id != tactic.id and _card.is_in_tactic(id)):
					ids.append(id)
			# Nieznane taktyki (spoza GameData) zostają na końcu – walidacja je zgłosi.
			for id in _card.tactics:
				if not id in all_ids:
					ids.append(id)
			_card.tactics = ids
			_on_card_changed())
		grid.add_child(check)


func _build_triggers_section() -> void:
	var box := _add_section("EDITOR_SECTION_TRIGGERS", "EDITOR_SECTION_TRIGGERS_HINT")
	for i in _card.triggers.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 6)
		box.add_child(row)
		row.add_child(_make_connector_label("EDITOR_OR" if i > 0 else ""))
		var option := _make_event_option(_card.triggers[i])
		option.item_selected.connect(func(index: int) -> void:
			_card.triggers[i] = option.get_item_metadata(index)
			_on_card_changed())
		row.add_child(option)
		var remove := _make_remove_button(func() -> void:
			_card.triggers.remove_at(i)
			_rebuild_properties_keep_scroll.call_deferred())
		remove.disabled = _card.triggers.size() <= 1
		row.add_child(remove)
	var add_trigger := func() -> void:
		_card.triggers.append(PlayEvents.POSSESSION)
		_rebuild_properties_keep_scroll.call_deferred()
	var add := _make_button("EDITOR_ADD_OR", add_trigger, 14)
	add.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(add)


## Strefy zagrania (pola wyboru jak przyciski stref na boisku), kanał pola akcji i awans.
func _build_movement_section() -> void:
	var box := _add_section("EDITOR_SECTION_MOVEMENT", "EDITOR_SECTION_MOVEMENT_HINT")
	var zones_row := HBoxContainer.new()
	zones_row.add_theme_constant_override(&"separation", 8)
	box.add_child(zones_row)
	zones_row.add_child(_make_label("EDITOR_FIELD_ZONES", 14))
	for zone in range(1, MatchRules.ZONE_COUNT + 1):
		var check := CheckBox.new()
		check.text = str(zone)
		check.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		check.tooltip_text = tr("EDITOR_ZONE_TOGGLE_TOOLTIP") % zone
		check.button_pressed = _card.can_play_zone(zone)
		check.toggled.connect(func(pressed: bool) -> void:
			if pressed != _card.can_play_zone(zone):
				_toggle_zone(zone))
		zones_row.add_child(check)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	box.add_child(row)
	row.add_child(_make_label("EDITOR_FIELD_LANE", 14))
	var lane := _make_option()
	for key in PlayCard.LANE_NAME_KEYS:
		lane.add_item(key)
	lane.select(_card.lane)
	lane.tooltip_text = "EDITOR_FIELD_LANE_TOOLTIP"
	lane.item_selected.connect(func(index: int) -> void:
		_card.lane = index as PlayCard.Lane
		_on_card_changed())
	row.add_child(lane)
	row.add_child(_make_label("EDITOR_FIELD_ADVANCE", 14))
	var advance := _make_spin_box(PlayCard.MIN_ADVANCE, PlayCard.MAX_ADVANCE, 1.0, _card.advance)
	advance.tooltip_text = "EDITOR_FIELD_ADVANCE_TOOLTIP"
	advance.value_changed.connect(func(value: float) -> void:
		_card.advance = roundi(value)
		_on_card_changed())
	row.add_child(advance)

	_active_label = _make_label("", 14, SECTION_COLOR)
	_active_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_active_label)
	_update_preview_label()


func _build_tests_section(attacking: bool) -> void:
	var box := _add_section("EDITOR_SECTION_ATTACK" if attacking else "EDITOR_SECTION_DEFENSE",
			"EDITOR_SECTION_TESTS_HINT")
	var tests := _card.get_requirements(attacking)
	for t in tests.size():
		if t > 0:
			var and_label := _make_label("EDITOR_AND", 15, SECTION_COLOR)
			and_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(and_label)
		box.add_child(_build_test_panel(tests, t))
	var append_test := func() -> void:
		tests.append(PlayRequirement.create([_first_free_attribute(null)], 2.0))
		_rebuild_properties_keep_scroll.call_deferred()
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 6)
	box.add_child(buttons)
	buttons.add_child(_make_button("EDITOR_ADD_AND", append_test, 14))
	if not attacking and _card.is_shot and not _card.has_keeper_test():
		var add_keeper := _make_button("EDITOR_ADD_KEEPER_TEST", func() -> void:
			tests.append(PlayRequirement.create(DEFAULT_KEEPER_ATTRIBUTES, DEFAULT_KEEPER_POINTS,
					PlayRequirement.LOCATION_KEEPER, DEFAULT_KEEPER_DICE))
			_rebuild_properties_keep_scroll.call_deferred(), 14)
		add_keeper.tooltip_text = "EDITOR_ADD_KEEPER_TEST_TOOLTIP"
		buttons.add_child(add_keeper)


func _build_test_panel(tests: Array[PlayRequirement], t: int) -> Control:
	var test := tests[t]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UiFrames.make_stylebox(UiFrames.Style.SLATE, 10.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 8)
	box.add_child(header)
	var title := _make_label("", 15, SECTION_COLOR)
	title.text = tr("EDITOR_TEST") % (t + 1)
	header.add_child(title)
	header.add_child(_make_label("EDITOR_THRESHOLD", 14))
	var points := _make_spin_box(1.0, PlayRequirement.MAX_POINTS, PlayRequirement.POINTS_STEP, test.points)
	points.tooltip_text = "EDITOR_THRESHOLD_TOOLTIP"
	points.value_changed.connect(func(value: float) -> void:
		test.points = value
		_on_card_changed())
	header.add_child(points)
	header.add_child(_make_label("EDITOR_MAX_DICE", 14))
	var max_dice := _make_spin_box(0, PlayRequirement.MAX_DICE_LIMIT, 1.0, test.max_dice)
	max_dice.custom_minimum_size = Vector2(64.0, 0.0)
	max_dice.tooltip_text = "EDITOR_MAX_DICE_TOOLTIP"
	max_dice.value_changed.connect(func(value: float) -> void:
		test.max_dice = roundi(value)
		_on_card_changed())
	header.add_child(max_dice)
	# Miejsce testu: pole docelowe (np. przyjęcie), startowe (np. zagranie długiej piłki) albo – w obronie –
	# interwencja bramkarza (tylko karty strzału; kolejność jak PlayRequirement.LOCATIONS).
	header.add_child(_make_label("EDITOR_TEST_LOCATION", 14))
	var location := OptionButton.new()
	location.add_item(tr("MATCH_TEST_AT_TARGET"))
	location.add_item(tr("MATCH_TEST_AT_ORIGIN"))
	if is_same(tests, _card.defense) and (_card.is_shot or test.is_keeper()):
		location.add_item(tr("MATCH_KEEPER_SHORT"))
	location.selected = maxi(PlayRequirement.LOCATIONS.find(test.location), 0)
	location.tooltip_text = "EDITOR_TEST_LOCATION_TOOLTIP"
	location.item_selected.connect(func(index: int) -> void:
		test.location = PlayRequirement.LOCATIONS[index]
		_on_card_changed())
	header.add_child(location)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var delete_test := func() -> void:
		tests.remove_at(t)
		_rebuild_properties_keep_scroll.call_deferred()
	var remove_test := _make_button("EDITOR_REMOVE_TEST", delete_test, 13)
	remove_test.disabled = tests.size() <= 1
	header.add_child(remove_test)

	for k in test.get_term_count():
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 6)
		box.add_child(row)
		row.add_child(_make_connector_label("EDITOR_OR" if k > 0 else ""))
		var attribute := _make_attribute_option(test.attributes[k])
		attribute.item_selected.connect(func(index: int) -> void:
			test.attributes[k] = attribute.get_item_metadata(index)
			_on_card_changed())
		row.add_child(attribute)
		var remove := _make_remove_button(func() -> void:
			test.remove_term(k)
			_rebuild_properties_keep_scroll.call_deferred())
		remove.disabled = test.get_term_count() <= 1
		row.add_child(remove)
	var append_term := func() -> void:
		test.add_term(_first_free_attribute(test))
		_rebuild_properties_keep_scroll.call_deferred()
	var add_term := _make_button("EDITOR_ADD_OR", append_term, 13)
	add_term.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_term.tooltip_text = "EDITOR_ADD_OR_TERM_TOOLTIP"
	box.add_child(add_term)
	return panel


## Pierwsza cecha, której jeszcze nie ma w teście (nowy składnik).
func _first_free_attribute(test: PlayRequirement) -> StringName:
	for attribute_id in DieGraphics.ATTRIBUTE_ORDER:
		if test == null or not test.accepts(attribute_id):
			return attribute_id
	return DieGraphics.ATTRIBUTE_ORDER[0]


func _build_outcomes_section() -> void:
	var box := _add_section("EDITOR_SECTION_OUTCOMES", "EDITOR_SECTION_OUTCOMES_HINT")
	for slot in PlayCard.OUTCOME_SLOTS:
		box.add_child(_build_outcome_panel(slot))
	var note := _make_label("EDITOR_ENGINE_NOTE", 13, DIM_TEXT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)


## Wynik: nazwa i zdarzenie (efekt).
func _build_outcome_panel(slot: StringName) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UiFrames.make_stylebox(UiFrames.Style.SLATE, 8.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	panel.add_child(row)
	var label := _make_label("PLAY_SLOT_" + String(slot).to_upper(), 14, SECTION_COLOR)
	label.custom_minimum_size = Vector2(220.0, 0.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var option := _make_event_option(_card.get_outcome(slot), true)
	option.item_selected.connect(func(index: int) -> void:
		_card.outcomes[slot] = option.get_item_metadata(index)
		_on_card_changed())
	row.add_child(option)
	return panel


# --- Kontrolki ---

func _add_section(title_key: String, hint_key: String = "") -> VBoxContainer:
	if _props.get_child_count() > 0:
		_props.add_child(HSeparator.new())
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	_props.add_child(box)
	box.add_child(_make_label(title_key, 18, SECTION_COLOR))
	if not hint_key.is_empty():
		var hint := _make_label(hint_key, 13, DIM_TEXT)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(hint)
	return box


func _make_label(text: String, font_size: int, color: Color = Color(0.91, 0.937, 0.878)) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


## Etykieta „lub” przed kolejnym składnikiem (stała szerokość, żeby listy były wyrównane).
func _make_connector_label(text: String) -> Label:
	var label := _make_label(text, 14, SECTION_COLOR)
	label.custom_minimum_size = Vector2(30.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label


func _make_button(text: String, callback: Callable, font_size: int = 16) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override(&"font_size", font_size)
	button.pressed.connect(callback)
	return button


func _make_remove_button(callback: Callable) -> Button:
	var button := _make_button("×", callback, 16)
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.tooltip_text = "EDITOR_REMOVE"
	button.custom_minimum_size = Vector2(34.0, 0.0)
	return button


func _make_spin_box(min_value: float, max_value: float, step: float, value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	spin.select_all_on_focus = true
	spin.custom_minimum_size = Vector2(84.0, 0.0)
	spin.add_theme_font_size_override(&"font_size", 14)
	spin.get_line_edit().add_theme_font_size_override(&"font_size", 14)
	return spin


## Lista rozwijana, która nie wymusza szerokości najdłuższej pozycji (długie teksty skracane „…”).
func _make_option() -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.fit_to_longest_item = false
	option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	option.custom_minimum_size = Vector2(120.0, 0.0)
	option.add_theme_font_size_override(&"font_size", 14)
	return option


## Lista zdarzeń (id w metadanych pozycji). Dla wyników bez „posiadania” (to tylko warunek dobierania).
func _make_event_option(selected: StringName, for_outcome := false) -> OptionButton:
	var option := _make_option()
	var index := -1
	for event_id in PlayEvents.IDS:
		if for_outcome and event_id == PlayEvents.POSSESSION and selected != event_id:
			continue
		option.add_item(PlayEvents.get_name_key(event_id))
		option.set_item_metadata(option.item_count - 1, event_id)
		if event_id == selected:
			index = option.item_count - 1
	if index == -1:
		# Nieznane zdarzenie z pliku – pokazujemy je, walidacja zgłosi błąd.
		option.add_item(String(selected))
		option.set_item_metadata(option.item_count - 1, selected)
		index = option.item_count - 1
	option.select(index)
	return option


func _make_attribute_option(selected: StringName) -> OptionButton:
	var option := _make_option()
	for attribute_id in DieGraphics.ATTRIBUTE_ORDER:
		var attribute := GameData.get_attribute(attribute_id)
		var label := attribute.name_key if attribute != null else String(attribute_id)
		option.add_icon_item(_attribute_icons[attribute_id], label)
		option.set_item_metadata(option.item_count - 1, attribute_id)
	var index := DieGraphics.ATTRIBUTE_ORDER.find(selected)
	if index == -1:
		# Nieznana cecha z pliku – pokazujemy ją, walidacja zgłosi błąd.
		option.add_item(String(selected))
		option.set_item_metadata(option.item_count - 1, selected)
		index = option.item_count - 1
	option.select(index)
	return option
