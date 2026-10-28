extends Control
## Edytor zagrań (narzędzie deweloperskie w grze): lista kart, boisko z polami wyjścia / celami i panel
## właściwości. Dane wczytuje i zapisuje PlayLibrary (res://data/plays/plays.json) – scena tylko ją wywołuje.
##
## Boisko: LPM przełącza pole wyjścia, PPM wybiera aktywne pole wyjścia, Ctrl+LPM (albo tryb „Klik: cele”)
## przełącza cel aktywnego pola, Shift+LPM – cel wszystkich pól wyjścia. Edycja celów przełącza kartę na
## kierunek „Ręcznie” (cele startują od dotychczasowych). Numer strefy po lewej = cała strefa.
## Wyniki: każdy slot ma efekt i odnogi (OutcomeBranch – inne zdarzenie z szansą), a zdarzenia łańcuchów
## (ChainEvent) łączą efekt jednej karty z warunkiem dobierania kolejnej.
## Ctrl+S zapisuje, Esc wraca do menu (z pytaniem o niezapisane zmiany).

const SECTION_COLOR := Color("#f0e6a8")
const DIM_TEXT := Color(0.91, 0.937, 0.878, 0.6)
const ERROR_TEXT := Color("#ff9a7a")
const LEFT_WIDTH := 236.0
const NO_CELL := Vector2i(-1, -1)
const MAX_LISTED_ERRORS := 12
## Kolumny checkboxów taktyk (panel właściwości musi się zmieścić obok boiska).
const TACTIC_COLUMNS := 3
const POINTS_MAX := 20.0
const WEIGHT_MIN := 0.1
const WEIGHT_MAX := 5.0
const WEIGHT_STEP := 0.1
## Litery korytarzy w opisach pól (np. „3Ś”).
const CHANNEL_LETTER_KEYS: Array[String] = ["EDITOR_CHANNEL_LETTER_LEFT", "EDITOR_CHANNEL_LETTER_CENTER",
		"EDITOR_CHANNEL_LETTER_RIGHT"]
## Pozycja list zdarzeń „+ nowe zdarzenie łańcucha”.
const NEW_CHAIN_EVENT := &"__new_chain_event__"
## Znaczek zdarzeń łańcuchów na listach.
const CHAIN_MARK := "⛓ "
const PERCENT_STEP := 1.0
const BRANCH_STEP_MIN := 0.1
const BRANCH_STEP_MAX := 10.0
## Wartości miary w podglądzie szansy odnogi.
const BRANCH_PREVIEW_VALUES: Array[float] = [0.5, 1.0, 2.0]

var _library: PlayLibrary
## Tekst pliku po ostatnim wczytaniu / zapisie i podpis każdej karty z tej chwili (wykrywanie zmian).
var _saved_text := ""
var _saved_cards: Dictionary = {}
var _card: PlayCard
var _active_origin := NO_CELL
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
var _origin_mode_button: Button
var _target_mode_button: Button
var _scroll: ScrollContainer
var _props: VBoxContainer
var _active_label: Label
var _dialog: ModalDialog
var _toast: ToastMessage


func _ready() -> void:
	for attribute_id in DieGraphics.ATTRIBUTE_ORDER:
		var attribute := GameData.get_attribute(attribute_id)
		var type_id := attribute.die_type_id if attribute != null else &""
		_attribute_icons[attribute_id] = DieGraphics.make_attribute_icon(attribute_id, type_id)
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
	var group := ButtonGroup.new()
	_origin_mode_button = _make_button("EDITOR_MODE_ORIGINS", _on_mode_changed, 14)
	_origin_mode_button.toggle_mode = true
	_origin_mode_button.button_group = group
	_origin_mode_button.button_pressed = true
	_origin_mode_button.tooltip_text = "EDITOR_MODE_ORIGINS_TOOLTIP"
	toolbar.add_child(_origin_mode_button)
	_target_mode_button = _make_button("EDITOR_MODE_TARGETS", _on_mode_changed, 14)
	_target_mode_button.toggle_mode = true
	_target_mode_button.button_group = group
	_target_mode_button.tooltip_text = "EDITOR_MODE_TARGETS_TOOLTIP"
	toolbar.add_child(_target_mode_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	var all_button := _make_button("EDITOR_ALL_CELLS", _on_all_cells_pressed, 14)
	all_button.tooltip_text = "EDITOR_ALL_CELLS_TOOLTIP"
	toolbar.add_child(all_button)
	var clear_button := _make_button("EDITOR_CLEAR", _on_clear_pressed, 14)
	clear_button.tooltip_text = "EDITOR_CLEAR_TOOLTIP"
	toolbar.add_child(clear_button)
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
	_update_active_label()
	_pitch.queue_redraw()


func _save() -> void:
	if not _library.load_error.is_empty():
		# Plik nie wczytał się poprawnie – nie nadpisujemy go niepełnymi danymi.
		_dialog.open(tr("EDITOR_SAVE_FAILED_TITLE"), tr("EDITOR_LOAD_FAILED") % _library.load_error, ["COMMON_OK"])
		return
	# Zdarzenia łańcuchów bez żadnego odwołania nie trafiają do pliku.
	_library.prune_chain_events()
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
	_active_origin = card.origins[0] if card != null and not card.origins.is_empty() else NO_CELL
	_list.deselect_all()
	var index := _visible_cards.find(card)
	if index != -1:
		_list.select(index)
		_list.ensure_current_is_visible()
	_duplicate_button.disabled = card == null
	_delete_button.disabled = card == null
	if card == null or card.direction != PlayCard.Direction.MANUAL:
		_origin_mode_button.button_pressed = true
	_on_mode_changed()
	_pitch.set_card(card, _active_origin)
	_rebuild_properties()
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

func _is_target_mode() -> bool:
	return _card != null and _card.direction == PlayCard.Direction.MANUAL and _target_mode_button.button_pressed


func _on_mode_changed() -> void:
	_target_mode_button.disabled = _card == null
	if _card != null and _target_mode_button.button_pressed and _card.direction != PlayCard.Direction.MANUAL:
		_switch_to_manual()
	_pitch.target_mode = _is_target_mode()
	_pitch.queue_redraw()


## Edycja celów przy kierunku automatycznym: karta przechodzi na kierunek ręczny, a cele każdego pola wyjścia
## startują od tych, które były widoczne.
func _switch_to_manual() -> void:
	for origin in _card.origins:
		_card.manual_targets[origin] = _card.get_targets(origin)
	_card.direction = PlayCard.Direction.MANUAL
	_toast.show_message(tr("EDITOR_SWITCHED_TO_MANUAL"), 2.5)
	_on_card_changed()
	_rebuild_properties_keep_scroll.call_deferred()


func _on_cell_clicked(cell: Vector2i, button: int, ctrl: bool, shift: bool) -> void:
	if _card == null:
		return
	if button == MOUSE_BUTTON_RIGHT:
		if cell in _card.origins:
			_set_active_origin(cell)
		return
	if ctrl or shift or _is_target_mode():
		if _card.origins.is_empty():
			_toast.show_message(tr("EDITOR_NO_ORIGIN_FOR_TARGET"), 2.5)
			return
		if _card.direction != PlayCard.Direction.MANUAL:
			_switch_to_manual()
		if shift:
			_toggle_target_everywhere(cell)
		elif _active_origin in _card.origins:
			_toggle_targets([cell])
		return
	_toggle_origins([cell])


func _on_zone_clicked(zone: int) -> void:
	if _card == null:
		return
	var cells: Array[Vector2i] = []
	for channel in MatchRules.CHANNEL_COUNT:
		cells.append(Vector2i(zone, channel))
	if _is_target_mode():
		if _active_origin in _card.origins:
			_toggle_targets(cells)
	else:
		_toggle_origins(cells)


func _on_all_cells_pressed() -> void:
	if _card == null:
		return
	var cells := _all_cells()
	if _is_target_mode():
		if _active_origin in _card.origins:
			_card.manual_targets[_active_origin] = cells
	else:
		for cell in cells:
			_add_origin(cell)
		_card.origins.sort_custom(_cell_less)
		if not _active_origin in _card.origins:
			_set_active_origin(_card.origins[0], false)
	_on_card_changed()


func _on_clear_pressed() -> void:
	if _card == null:
		return
	if _is_target_mode():
		if _active_origin in _card.origins:
			_card.manual_targets[_active_origin] = []
	else:
		_card.origins.clear()
		_set_active_origin(NO_CELL, false)
	_on_card_changed()


## Przełącza grupę pól jako pola wyjścia: jeśli wszystkie są zaznaczone – odznacza, inaczej dodaje brakujące.
func _toggle_origins(cells: Array[Vector2i]) -> void:
	var all_present := true
	for cell in cells:
		if not cell in _card.origins:
			all_present = false
	if all_present:
		for cell in cells:
			_card.origins.erase(cell)
		if not _active_origin in _card.origins:
			_set_active_origin(_card.origins[0] if not _card.origins.is_empty() else NO_CELL, false)
	else:
		for cell in cells:
			_add_origin(cell)
		_card.origins.sort_custom(_cell_less)
		_set_active_origin(cells[0], false)
	_on_card_changed()


func _add_origin(cell: Vector2i) -> void:
	if cell in _card.origins:
		return
	_card.origins.append(cell)
	# Przy kierunku ręcznym nowe pole dostaje cel „przed siebie” o advance stref (pomoc, do zmiany).
	if _card.direction == PlayCard.Direction.MANUAL and _card.manual_targets.get(cell, []).is_empty():
		_card.manual_targets[cell] = [Vector2i(_card.get_advance_zone(cell), cell.y)]


func _toggle_targets(cells: Array[Vector2i]) -> void:
	var targets: Array = _card.manual_targets.get(_active_origin, []).duplicate()
	var all_present := true
	for cell in cells:
		if not cell in targets:
			all_present = false
	for cell in cells:
		if all_present:
			targets.erase(cell)
		elif not cell in targets:
			targets.append(cell)
	targets.sort_custom(_cell_less)
	_card.manual_targets[_active_origin] = targets
	_on_card_changed()


## Shift+LPM: cel dla wszystkich pól wyjścia naraz (np. dośrodkowanie ze skrzydeł w pole karne).
## Jeśli każde pole wyjścia ma ten cel – usuwa go wszędzie, inaczej dodaje brakujące.
func _toggle_target_everywhere(cell: Vector2i) -> void:
	var everywhere := true
	for origin in _card.origins:
		if not cell in _card.manual_targets.get(origin, []):
			everywhere = false
	for origin in _card.origins:
		var targets: Array = _card.manual_targets.get(origin, []).duplicate()
		if everywhere:
			targets.erase(cell)
		elif not cell in targets:
			targets.append(cell)
		targets.sort_custom(_cell_less)
		_card.manual_targets[origin] = targets
	_on_card_changed()


func _set_active_origin(cell: Vector2i, notify := true) -> void:
	_active_origin = cell
	_pitch.active_origin = cell
	if notify:
		_update_active_label()
		_pitch.queue_redraw()


func _update_active_label() -> void:
	if _active_label == null or not is_instance_valid(_active_label) or _card == null:
		return
	if not _active_origin in _card.origins:
		_active_label.text = tr("EDITOR_NO_ACTIVE_ORIGIN")
		return
	var targets := PackedStringArray()
	for target in _card.get_targets(_active_origin):
		targets.append(_cell_name(target))
	_active_label.text = tr("EDITOR_ACTIVE_ORIGIN") % [_cell_name(_active_origin),
			", ".join(targets) if not targets.is_empty() else tr("EDITOR_NO_TARGETS")]


func _cell_name(cell: Vector2i) -> String:
	return "%d%s" % [cell.x, tr(CHANNEL_LETTER_KEYS[cell.y])]


static func _cell_less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)


static func _all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for zone in range(1, MatchRules.ZONE_COUNT + 1):
		for channel in MatchRules.CHANNEL_COUNT:
			cells.append(Vector2i(zone, channel))
	return cells


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
	_build_chains_section()


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
		var option := _make_event_option(_card.triggers[i], _get_hidden_trigger_events())
		option.item_selected.connect(func(index: int) -> void:
			var event_id: StringName = option.get_item_metadata(index)
			if event_id == NEW_CHAIN_EVENT:
				event_id = _library.add_chain_event("chain", tr("EDITOR_NEW_CHAIN_NAME")).id
			var rebuild := PlayEvents.is_chain(event_id) or PlayEvents.is_chain(_card.triggers[i])
			_card.triggers[i] = event_id
			_after_event_change(rebuild))
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


func _build_movement_section() -> void:
	var box := _add_section("EDITOR_SECTION_MOVEMENT")
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	box.add_child(row)
	row.add_child(_make_label("EDITOR_FIELD_ADVANCE", 14))
	var advance := _make_spin_box(PlayCard.MIN_ADVANCE, PlayCard.MAX_ADVANCE, 1.0, _card.advance)
	advance.tooltip_text = "EDITOR_FIELD_ADVANCE_TOOLTIP"
	advance.value_changed.connect(func(value: float) -> void:
		_card.advance = roundi(value)
		_on_card_changed())
	row.add_child(advance)
	row.add_child(_make_label("EDITOR_FIELD_DIRECTION", 14))
	var direction := _make_option()
	for key in PlayCard.DIRECTION_NAME_KEYS:
		direction.add_item(key)
	direction.select(_card.direction)
	direction.item_selected.connect(_on_direction_selected)
	row.add_child(direction)

	_active_label = _make_label("", 14, SECTION_COLOR)
	_active_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_active_label)
	_update_active_label()
	var hint_key := "EDITOR_PITCH_HINT_MANUAL" if _card.direction == PlayCard.Direction.MANUAL else "EDITOR_PITCH_HINT"
	var hint := _make_label(hint_key, 13, DIM_TEXT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)


func _on_direction_selected(index: int) -> void:
	var new_direction := index as PlayCard.Direction
	if new_direction == _card.direction:
		return
	if new_direction == PlayCard.Direction.MANUAL:
		# Ręczne cele startują od celów dotychczasowego kierunku (pola bez zapisanych celów).
		for origin in _card.origins:
			if _card.manual_targets.get(origin, []).is_empty():
				_card.manual_targets[origin] = _card.get_targets(origin)
	_card.direction = new_direction
	if new_direction != PlayCard.Direction.MANUAL:
		_origin_mode_button.button_pressed = true
	_on_mode_changed()
	_rebuild_properties_keep_scroll.call_deferred()


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
		tests.append(PlayRequirement.create([_first_free_attribute(null)], 1.0))
		_rebuild_properties_keep_scroll.call_deferred()
	var add_test := _make_button("EDITOR_ADD_AND", append_test, 14)
	add_test.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(add_test)


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
	var points := _make_spin_box(0.0, POINTS_MAX, PlayRequirement.POINTS_STEP, test.points)
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
		row.add_child(_make_label("EDITOR_WEIGHT", 14))
		var weight := _make_spin_box(WEIGHT_MIN, WEIGHT_MAX, WEIGHT_STEP, test.weights[k])
		weight.tooltip_text = "EDITOR_WEIGHT_TOOLTIP"
		weight.value_changed.connect(func(value: float) -> void:
			test.weights[k] = value
			_on_card_changed())
		row.add_child(weight)
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


## Slot wyniku: efekt, przesunięcie zawodnika i odnogi (inne zdarzenia z szansą).
func _build_outcome_panel(slot: StringName) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UiFrames.make_stylebox(UiFrames.Style.SLATE, 8.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	panel.add_child(box)

	var label := _make_label("PLAY_SLOT_" + String(slot).to_upper(), 14, SECTION_COLOR)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	box.add_child(row)
	var branches := _card.get_branches(slot)
	if not branches.is_empty():
		row.add_child(_make_label("EDITOR_BRANCH_OTHERWISE", 13, DIM_TEXT))
	var option := _make_event_option(_card.get_outcome(slot))
	option.item_selected.connect(func(index: int) -> void:
		var event_id := _resolve_event_choice(option.get_item_metadata(index), slot)
		var rebuild := PlayEvents.is_chain(event_id) or PlayEvents.is_chain(_card.get_outcome(slot))
		_card.outcomes[slot] = event_id
		_after_event_change(rebuild))
	row.add_child(option)
	# Krótki przełącznik – pełny opis w podpowiedzi.
	var move := _make_move_check(_card.get_outcome_move(slot))
	move.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			_card.outcome_moves[slot] = true
		else:
			_card.outcome_moves.erase(slot)
		_on_card_changed())
	row.add_child(move)
	var add_branch := func() -> void:
		if not _card.outcome_branches.has(slot):
			_card.outcome_branches[slot] = []
		_card.outcome_branches[slot].append(OutcomeBranch.create(PlayEvents.FOUL))
		_rebuild_properties_keep_scroll.call_deferred()
	var add := _make_button("EDITOR_ADD_BRANCH", add_branch, 13)
	add.tooltip_text = "EDITOR_ADD_BRANCH_TOOLTIP"
	row.add_child(add)

	for b in branches.size():
		box.add_child(_build_branch_panel(slot, b))
	return panel


func _make_move_check(pressed: bool) -> CheckBox:
	var move := CheckBox.new()
	move.text = "EDITOR_MOVE_PLAYER_SHORT"
	move.tooltip_text = "EDITOR_MOVE_PLAYER_TOOLTIP"
	move.add_theme_font_size_override(&"font_size", 13)
	move.button_pressed = pressed
	return move


## Wybór z listy zdarzeń: „+ nowe zdarzenie łańcucha” tworzy zdarzenie nazwane od karty.
func _resolve_event_choice(event_id: StringName, slot: StringName) -> StringName:
	if event_id != NEW_CHAIN_EVENT:
		return event_id
	var label := _card.name if not _card.name.strip_edges().is_empty() else String(_card.id)
	return _library.add_chain_event("%s_%s" % [_card.id, slot], tr("EDITOR_CHAIN_DEFAULT_NAME") % label).id


## Odnoga slotu: zdarzenie, szansa (stała + za każdy krok miary, maks.), pola akcji i podgląd szansy.
func _build_branch_panel(slot: StringName, b: int) -> Control:
	var branches: Array = _card.outcome_branches[slot]
	var branch: OutcomeBranch = branches[b]
	var outer := HBoxContainer.new()
	outer.add_theme_constant_override(&"separation", 6)
	var marker := _make_label("", 14, SECTION_COLOR)
	marker.text = "↳ %d." % (b + 1)
	marker.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	outer.add_child(marker)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 4)
	outer.add_child(box)

	var preview := _make_label("", 13, DIM_TEXT)
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var update_preview := func() -> void: preview.text = _branch_preview_text(branch)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	box.add_child(row)
	var option := _make_event_option(branch.event)
	option.item_selected.connect(func(index: int) -> void:
		var event_id := _resolve_event_choice(option.get_item_metadata(index), slot)
		var rebuild := PlayEvents.is_chain(event_id) or PlayEvents.is_chain(branch.event)
		branch.event = event_id
		_after_event_change(rebuild))
	row.add_child(option)
	var move := _make_move_check(branch.move_player)
	move.toggled.connect(func(pressed: bool) -> void:
		branch.move_player = pressed
		_on_card_changed())
	row.add_child(move)
	var move_up := func() -> void:
		branches.remove_at(b)
		branches.insert(b - 1, branch)
		_rebuild_properties_keep_scroll.call_deferred()
	var up := _make_button("↑", move_up, 14)
	up.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	up.tooltip_text = "EDITOR_BRANCH_UP_TOOLTIP"
	up.disabled = b == 0
	row.add_child(up)
	row.add_child(_make_remove_button(func() -> void:
		branches.remove_at(b)
		if branches.is_empty():
			_card.outcome_branches.erase(slot)
		_rebuild_properties_keep_scroll.call_deferred()))

	var chance := HFlowContainer.new()
	chance.add_theme_constant_override(&"h_separation", 6)
	chance.add_theme_constant_override(&"v_separation", 4)
	box.add_child(chance)
	chance.add_child(_make_label("EDITOR_BRANCH_CHANCE", 13))
	var base := _make_spin_box(0.0, 100.0, PERCENT_STEP, branch.base_chance)
	base.suffix = "%"
	base.tooltip_text = "EDITOR_BRANCH_BASE_TOOLTIP"
	base.value_changed.connect(func(value: float) -> void:
		branch.base_chance = value
		update_preview.call()
		_on_card_changed())
	chance.add_child(base)
	chance.add_child(_make_label("+", 13))
	var per_step := _make_spin_box(0.0, 100.0, PERCENT_STEP, branch.per_step)
	per_step.suffix = "%"
	per_step.tooltip_text = "EDITOR_BRANCH_PER_STEP_TOOLTIP"
	chance.add_child(per_step)
	chance.add_child(_make_label("EDITOR_BRANCH_FOR_EVERY", 13))
	var step := _make_spin_box(BRANCH_STEP_MIN, BRANCH_STEP_MAX, BRANCH_STEP_MIN, branch.step)
	step.tooltip_text = "EDITOR_BRANCH_STEP_TOOLTIP"
	chance.add_child(step)
	var measure := _make_option()
	measure.custom_minimum_size = Vector2(170.0, 0.0)
	measure.size_flags_horizontal = Control.SIZE_FILL
	for key in OutcomeBranch.MEASURE_NAME_KEYS:
		measure.add_item(key)
	measure.select(branch.measure)
	measure.tooltip_text = "EDITOR_BRANCH_MEASURE_TOOLTIP"
	chance.add_child(measure)
	chance.add_child(_make_label("EDITOR_BRANCH_MAX", 13))
	var max_chance := _make_spin_box(PERCENT_STEP, 100.0, PERCENT_STEP, branch.max_chance)
	max_chance.suffix = "%"
	max_chance.value_changed.connect(func(value: float) -> void:
		branch.max_chance = value
		update_preview.call()
		_on_card_changed())
	chance.add_child(max_chance)
	var sync_measure := func() -> void:
		per_step.editable = branch.measure != OutcomeBranch.Measure.NONE
		step.editable = branch.measure != OutcomeBranch.Measure.NONE
	per_step.value_changed.connect(func(value: float) -> void:
		branch.per_step = value
		update_preview.call()
		_on_card_changed())
	step.value_changed.connect(func(value: float) -> void:
		branch.step = value
		update_preview.call()
		_on_card_changed())
	measure.item_selected.connect(func(index: int) -> void:
		branch.measure = index as OutcomeBranch.Measure
		sync_measure.call()
		update_preview.call()
		_on_card_changed())
	sync_measure.call()

	box.add_child(_build_cells_picker(branch))
	update_preview.call()
	box.add_child(preview)
	return outer


## Podgląd szansy odnogi: stała albo przy kilku wartościach miary.
func _branch_preview_text(branch: OutcomeBranch) -> String:
	if branch.measure == OutcomeBranch.Measure.NONE:
		return tr("EDITOR_BRANCH_PREVIEW_FIXED") % _format_percent(branch.get_chance(0.0))
	var parts := PackedStringArray()
	for value in BRANCH_PREVIEW_VALUES:
		parts.append("%s → %s" % [PlayPitch.format_weight(value), _format_percent(branch.get_chance(value))])
	return tr("EDITOR_BRANCH_PREVIEW") % [tr(OutcomeBranch.MEASURE_NAME_KEYS[branch.measure]), ", ".join(parts)]


static func _format_percent(chance: float) -> String:
	return "%d%%" % roundi(chance * 100.0)


## Pola akcji, w których odnoga działa: mała siatka 5 × 3 (strefa 5 u góry); nic nie zaznaczone = wszędzie.
func _build_cells_picker(branch: OutcomeBranch) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(_make_label("EDITOR_BRANCH_CELLS", 13))
	var state := _make_label("", 12, DIM_TEXT)
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(state)
	var update_state := func() -> void:
		var names := PackedStringArray()
		for cell in branch.cells:
			names.append(_cell_name(cell))
		state.text = tr("EDITOR_BRANCH_CELLS_ANY") if names.is_empty() else tr("EDITOR_BRANCH_CELLS_SOME") % ", ".join(names)
	update_state.call()
	var grid := GridContainer.new()
	grid.columns = MatchRules.CHANNEL_COUNT
	grid.add_theme_constant_override(&"h_separation", 2)
	grid.add_theme_constant_override(&"v_separation", 2)
	row.add_child(grid)
	for zone in range(MatchRules.ZONE_COUNT, 0, -1):
		for channel in MatchRules.CHANNEL_COUNT:
			var cell := Vector2i(zone, channel)
			var toggle := Button.new()
			toggle.toggle_mode = true
			toggle.text = _cell_name(cell)
			toggle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			toggle.custom_minimum_size = Vector2(36.0, 22.0)
			toggle.add_theme_font_size_override(&"font_size", 11)
			toggle.button_pressed = cell in branch.cells
			toggle.toggled.connect(func(pressed: bool) -> void:
				if pressed and not cell in branch.cells:
					branch.cells.append(cell)
					branch.cells.sort_custom(_cell_less)
				elif not pressed:
					branch.cells.erase(cell)
				update_state.call()
				_on_card_changed())
			grid.add_child(toggle)
	return row


# --- Łańcuchy ---

## Zdarzenia łańcuchów, które karta wywołuje albo ma w warunkach: nazwa, piłka, powiązane karty.
func _build_chains_section() -> void:
	var chains: Array[ChainEvent] = []
	var emitted := _card.get_emitted_events()
	for chain in _library.chain_events:
		if chain.id in emitted or _card.is_triggered_by(chain.id):
			chains.append(chain)
	if chains.is_empty():
		return
	var box := _add_section("EDITOR_SECTION_CHAINS", "EDITOR_SECTION_CHAINS_HINT")
	for chain in chains:
		box.add_child(_build_chain_panel(chain))


func _build_chain_panel(chain: ChainEvent) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UiFrames.make_stylebox(UiFrames.Style.SLATE, 8.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	panel.add_child(box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	box.add_child(row)
	row.add_child(_make_label(CHAIN_MARK.strip_edges(), 15, SECTION_COLOR))
	var name_edit := LineEdit.new()
	name_edit.text = chain.name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.tooltip_text = tr("EDITOR_CHAIN_NAME_TOOLTIP") % chain.id
	name_edit.text_changed.connect(func(text: String) -> void:
		chain.name = text
		_on_card_changed())
	row.add_child(name_edit)

	var options := HFlowContainer.new()
	options.add_theme_constant_override(&"h_separation", 8)
	options.add_theme_constant_override(&"v_separation", 4)
	box.add_child(options)
	options.add_child(_make_label("EDITOR_CHAIN_BALL", 13))
	var ball := _make_option()
	ball.size_flags_horizontal = Control.SIZE_FILL
	ball.custom_minimum_size = Vector2(180.0, 0.0)
	for key in ChainEvent.BALL_NAME_KEYS:
		ball.add_item(key)
	ball.select(chain.ball)
	ball.item_selected.connect(func(index: int) -> void:
		chain.ball = index as ChainEvent.Ball
		_on_card_changed())
	options.add_child(ball)
	var turnover := CheckBox.new()
	turnover.text = "EDITOR_CHAIN_TURNOVER"
	turnover.tooltip_text = "EDITOR_CHAIN_TURNOVER_TOOLTIP"
	turnover.add_theme_font_size_override(&"font_size", 13)
	turnover.button_pressed = chain.changes_possession
	turnover.toggled.connect(func(pressed: bool) -> void:
		chain.changes_possession = pressed
		_on_card_changed())
	options.add_child(turnover)
	var hide_check := CheckBox.new()
	hide_check.text = "EDITOR_CHAIN_HIDE"
	hide_check.tooltip_text = "EDITOR_CHAIN_HIDE_TOOLTIP"
	hide_check.add_theme_font_size_override(&"font_size", 13)
	hide_check.button_pressed = chain.hide_after_use
	hide_check.toggled.connect(func(pressed: bool) -> void:
		chain.hide_after_use = pressed
		_on_card_changed())
	options.add_child(hide_check)

	var source_cards: Array[PlayCard] = []
	for source in _library.get_event_sources(chain.id):
		if not source["card"] in source_cards:
			source_cards.append(source["card"])
	box.add_child(_build_card_links("EDITOR_CHAIN_SOURCES", source_cards))
	var followers := _library.get_event_followers(chain.id)
	var links := _build_card_links("EDITOR_CHAIN_FOLLOWERS", followers)
	var create := _make_button("EDITOR_CHAIN_CREATE_FOLLOWER", func() -> void: _create_follow_up(chain), 13)
	create.tooltip_text = "EDITOR_CHAIN_CREATE_FOLLOWER_TOOLTIP"
	links.add_child(create)
	box.add_child(links)
	if followers.is_empty():
		var warning := _make_label("EDITOR_CHAIN_NO_FOLLOWERS", 12, ERROR_TEXT)
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(warning)
	return panel


## Etykieta i przyciski kart (kliknięcie przechodzi do karty).
func _build_card_links(title_key: String, cards: Array[PlayCard]) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", 6)
	flow.add_theme_constant_override(&"v_separation", 4)
	flow.add_child(_make_label(title_key, 13))
	if cards.is_empty():
		flow.add_child(_make_label("EDITOR_CHAIN_NONE", 13, DIM_TEXT))
	for linked in cards:
		var label := linked.name if not linked.name.strip_edges().is_empty() else String(linked.id)
		var button := _make_button("", func() -> void: _jump_to_card(linked), 13)
		button.text = label
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.disabled = linked == _card
		flow.add_child(button)
	return flow


func _jump_to_card(target: PlayCard) -> void:
	if not target in _visible_cards:
		_filter_option.select(0)
		_on_filter_selected(0)
	_select_card(target)


## Nowa karta z warunkiem na zdarzenie łańcucha; pola wyjścia = pola, w których po zdarzeniu leży piłka.
func _create_follow_up(chain: ChainEvent) -> void:
	var card := PlayCard.create_default(_library.make_unique_id(String(chain.id) + "_play"), _card.tactics)
	card.name = tr("EDITOR_CHAIN_FOLLOWER_NAME") % PlayEvents.get_display_name(chain.id)
	card.triggers.assign([chain.id])
	card.origins = _get_chain_cells(chain)
	_insert_card(card)


## Pola piłki po zdarzeniu łańcucha we wszystkich kartach, które je wywołują (perspektywa drużyny z piłką).
func _get_chain_cells(chain: ChainEvent) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for source in _library.get_event_sources(chain.id):
		var card: PlayCard = source["card"]
		var slot: StringName = source["slot"]
		for origin in card.origins:
			for target in card.get_targets(origin):
				var action := PlayCard.get_action_cell(slot, origin, target)
				var emits := card.get_outcome(slot) == chain.id
				for branch: OutcomeBranch in card.get_branches(slot):
					emits = emits or (branch.event == chain.id and branch.applies_at(action))
				if not emits:
					continue
				var cell := chain.get_ball_cell(action, origin, target)
				if chain.changes_possession:
					cell = Vector2i(MatchRules.ZONE_COUNT + 1 - cell.x, MatchRules.CHANNEL_COUNT - 1 - cell.y)
				if not cell in cells:
					cells.append(cell)
	cells.sort_custom(_cell_less)
	return cells


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


## Lista zdarzeń (id w metadanych pozycji): stała lista, zdarzenia łańcuchów i „+ nowe zdarzenie łańcucha”.
## hidden: zdarzenia łańcuchów pominięte na liście (ukryte po użyciu), chyba że są wybrane.
func _make_event_option(selected: StringName, hidden: Dictionary = {}) -> OptionButton:
	var option := _make_option()
	for event_id in PlayEvents.IDS:
		option.add_item(PlayEvents.get_name_key(event_id))
		option.set_item_metadata(option.item_count - 1, event_id)
	var chains: Array[ChainEvent] = []
	for chain in _library.chain_events:
		if chain.id == selected or not hidden.has(chain.id):
			chains.append(chain)
	if not chains.is_empty():
		option.add_separator(tr("EDITOR_CHAIN_EVENTS"))
	for chain in chains:
		option.add_item(CHAIN_MARK + PlayEvents.get_display_name(chain.id))
		option.set_item_metadata(option.item_count - 1, chain.id)
	option.add_item("EDITOR_NEW_CHAIN_EVENT")
	option.set_item_metadata(option.item_count - 1, NEW_CHAIN_EVENT)
	var index := -1
	for i in option.item_count:
		if not option.is_item_separator(i) and option.get_item_metadata(i) == selected:
			index = i
	if index == -1:
		# Nieznane zdarzenie z pliku – pokazujemy je, walidacja zgłosi błąd.
		option.add_item(String(selected))
		option.set_item_metadata(option.item_count - 1, selected)
		index = option.item_count - 1
	option.select(index)
	return option


## Zdarzenia łańcuchów „ukryj po użyciu”, które inna karta ma już w warunkach.
func _get_hidden_trigger_events() -> Dictionary:
	var hidden := {}
	for chain in _library.chain_events:
		if not chain.hide_after_use:
			continue
		for follower in _library.get_event_followers(chain.id):
			if follower != _card:
				hidden[chain.id] = true
	return hidden


## Po zmianie zdarzenia: przebudowa panelu, gdy zmienił się zestaw zdarzeń łańcuchów karty.
func _after_event_change(rebuild: bool) -> void:
	if rebuild:
		_rebuild_properties_keep_scroll.call_deferred()
	else:
		_on_card_changed()


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
