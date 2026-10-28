class_name MatchDie
extends Control
## Kość na ekranie meczu: mała (30 px, przy koszulce zawodnika) albo pełna ścianka (60 px, w miejscu testu
## i na karcie). Kość gracza w fazie układania można przeciągnąć do miejsca w teście albo kliknąć.

signal pressed(match_die: MatchDie)

enum DieSize { SMALL, LARGE }
## NORMAL – zwykła, PLACED – leży w miejscu testu (liczy się), USELESS – ścianka nie pasuje do żadnego testu,
## SELECTED – zaznaczona do przerzutu.
enum State { NORMAL, PLACED, USELESS, SELECTED }

const SMALL_SIZE := Vector2(30, 30)
const ICON_OFFSET := Vector2(5, 4)
const PLACED_COLOR := Color("#f2cf4a")
const SELECTED_COLOR := Color("#ffffff")
## Kość nieprzydatna w tej karcie: przyciemniona, ale nieprzezroczysta (poświata drużyny pod nią nie przebija).
const USELESS_TINT := Color(0.45, 0.45, 0.45)
const BADGE_FONT_SIZE := 10
const BADGE_BG := Color(0.063, 0.125, 0.102, 0.92)

## Kość z akcji (null = sama ścianka do podglądu, np. na karcie).
var contest_die: PlayContest.ContestDie
var type_id: StringName
var attribute_id: StringName
var value := 1
var die_size: DieSize = DieSize.SMALL
var state: State = State.NORMAL:
	set(new_state):
		state = new_state
		queue_redraw()
## Punkty kości w teście (pusty = bez plakietki).
var points_text := "":
	set(text):
		points_text = text
		queue_redraw()
var points_color := Color.WHITE
var draggable := false
var clickable := false:
	set(enabled):
		clickable = enabled
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled or draggable else Control.CURSOR_ARROW


func _init() -> void:
	PixelArt.apply(self)
	mouse_filter = Control.MOUSE_FILTER_STOP


static func create_for(p_die: PlayContest.ContestDie, p_size: DieSize) -> MatchDie:
	var match_die := MatchDie.new()
	match_die.contest_die = p_die
	match_die.die_size = p_size
	match_die.sync_face()
	return match_die


static func create_face(p_type_id: StringName, p_attribute_id: StringName, p_value: int, p_size: DieSize) -> MatchDie:
	var match_die := MatchDie.new()
	match_die.type_id = p_type_id
	match_die.attribute_id = p_attribute_id
	match_die.value = p_value
	match_die.die_size = p_size
	match_die._update_size()
	return match_die


## Odczytuje wyrzuconą ściankę z kości (po rzucie albo przerzucie).
func sync_face() -> void:
	if contest_die != null and contest_die.face >= 0:
		type_id = contest_die.die.type.id
		attribute_id = contest_die.die.get_face_attribute(contest_die.face)
		value = contest_die.die.get_face_value(contest_die.face)
	_update_size()
	queue_redraw()


func _update_size() -> void:
	var target := DieGraphics.FACE_SIZE if die_size == DieSize.LARGE else SMALL_SIZE
	custom_minimum_size = target
	size = target


## Punkty w zapisie gracza (przecinek po polsku).
static func format_points(points: float) -> String:
	var text := "%.1f" % points
	if TranslationServer.get_locale().begins_with("pl"):
		text = text.replace(".", ",")
	return text


func _gui_input(event: InputEvent) -> void:
	if clickable and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit(self)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not draggable or contest_die == null:
		return null
	var preview := Control.new()
	var copy := MatchDie.create_for(contest_die, DieSize.LARGE)
	copy.modulate.a = 0.85
	copy.position = -DieGraphics.FACE_SIZE / 2.0
	preview.add_child(copy)
	set_drag_preview(preview)
	return {"contest_die": contest_die, "source": self}


func _draw() -> void:
	if type_id == &"":
		return
	var tint := USELESS_TINT if state == State.USELESS else Color.WHITE
	if die_size == DieSize.LARGE:
		DieGraphics.draw_face(self, Vector2.ZERO, type_id, attribute_id, value, tint)
	else:
		var type_index := maxi(DieGraphics.TYPE_ORDER.find(type_id), 0)
		draw_texture_rect_region(DieGraphics.BODIES, Rect2(Vector2.ZERO, SMALL_SIZE),
				Rect2(Vector2(type_index * DieGraphics.FACE_SIZE.x, 0.0), DieGraphics.FACE_SIZE), tint)
		DieGraphics.draw_attribute_icon(self, ICON_OFFSET, attribute_id, tint)
	match state:
		State.PLACED:
			draw_rect(Rect2(Vector2(-1, -1), size + Vector2(2, 2)), PLACED_COLOR, false, 2.0)
		State.SELECTED:
			draw_rect(Rect2(Vector2(-2, -2), size + Vector2(4, 4)), SELECTED_COLOR, false, 2.0)
	if not points_text.is_empty():
		_draw_badge()


## Plakietka z punktami w prawym dolnym rogu (wystaje poza kość).
func _draw_badge() -> void:
	var font := get_theme_default_font()
	var text_width := font.get_string_size(points_text, HORIZONTAL_ALIGNMENT_LEFT, -1, BADGE_FONT_SIZE).x
	var box := Rect2(Vector2(size.x - text_width * 0.5 - 4.0, size.y - 8.0), Vector2(text_width + 4.0, 11.0))
	draw_rect(box, BADGE_BG)
	var baseline := box.position.y + (box.size.y + font.get_ascent(BADGE_FONT_SIZE) - font.get_descent(BADGE_FONT_SIZE)) / 2.0
	draw_string(font, Vector2(box.position.x + 2.0, roundf(baseline)), points_text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			BADGE_FONT_SIZE, points_color)
