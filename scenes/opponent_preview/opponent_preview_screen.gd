class_name OpponentPreviewScreen
extends Control
## Podgląd drużyny przeciwnej (wersja robocza – docelowy wygląd ekranu zostanie dopracowany).
## Pokazuje domyślny skład rywala na boisku i jego kadrę. "Wróć" emituje back_requested.

signal back_requested

const BACKGROUND_COLOR := Color(0.078, 0.129, 0.102)
const DIM_TEXT := Color(0.91, 0.937, 0.878, 0.6)

var _lineup: Lineup


static func create(team: TeamData) -> OpponentPreviewScreen:
	var screen := OpponentPreviewScreen.new()
	screen._lineup = Lineup.create_default(team)
	return screen


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override(&"separation", 20)
	margin.add_child(layout)

	var pitch := PitchView.new()
	pitch.interactive = false
	pitch.show_lane_labels = false
	pitch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	layout.add_child(pitch)
	pitch.set_lineups(_lineup)

	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override(&"separation", 10)
	layout.add_child(side)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override(&"separation", 20)
	var back_button := Button.new()
	back_button.text = "COMMON_BACK"
	back_button.custom_minimum_size = Vector2(130, 42)
	back_button.pressed.connect(back_requested.emit)
	top_bar.add_child(back_button)
	var title := _make_label(_lineup.team.name, 28, _lineup.team.primary_color.lightened(0.4))
	top_bar.add_child(title)
	side.add_child(top_bar)

	side.add_child(_make_label(tr("OPPONENT_TACTIC") % _lineup.tactic.name, 16))
	var note := _make_label(tr("OPPONENT_PREVIEW_NOTE"), 13, DIM_TEXT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(note)
	side.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	var roster := GridContainer.new()
	roster.columns = 3
	roster.add_theme_constant_override(&"h_separation", 14)
	roster.add_theme_constant_override(&"v_separation", 2)
	scroll.add_child(roster)
	for player in _lineup.team.players:
		var player_position := GameData.get_position(player.position_id)
		var color := Color.WHITE if _lineup.is_starter(player) else DIM_TEXT
		var number := _make_label(str(player.number), 14, color)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number.custom_minimum_size.x = 24.0
		roster.add_child(number)
		roster.add_child(_make_label(tr(player_position.short_key) if player_position != null else "?", 14, color))
		roster.add_child(_make_label(player.get_full_name(), 14, color))

	back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()


func _make_label(text: String, font_size: int, color := Color(0.91, 0.937, 0.878)) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label
