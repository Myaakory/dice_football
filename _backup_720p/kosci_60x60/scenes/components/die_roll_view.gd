class_name DieRollView
extends Control
## Animowany rzut kością: szybkie koziołkowanie (wynik niewidoczny), lądowanie, potem wylosowana ścianka.
## Przesuwanie kości po ekranie robi rodzic (np. tween pozycji) – ten węzeł animuje tylko samą kość.

signal finished

const FRAME_SIZE := Vector2(96, 96)
const ROLL_FRAMES := 6
const LAND_FRAMES := 3
const ROLL_FRAME_TIME := 0.04
const LAND_FRAME_TIMES: Array[float] = [0.07, 0.08, 0.3]
## Przesunięcie kostki 60x60 w klatce 96x96 (ostatnia klatka lądowania = pusta ścianka w tym miejscu).
const FACE_OFFSET := (FRAME_SIZE - DieGraphics.FACE_SIZE) / 2.0

const ROLL_SHEETS := {
	&"physical": preload("res://assets/graphics/dice/die_roll_physical.png"),
	&"technical": preload("res://assets/graphics/dice/die_roll_technical.png"),
	&"defensive": preload("res://assets/graphics/dice/die_roll_defensive.png"),
}
const SHADOW: Texture2D = preload("res://assets/graphics/dice/die_shadow.png")

enum State { IDLE, ROLLING, LANDING, SHOWING }

## Czas koziołkowania przed lądowaniem (sekundy).
@export var spin_time := 0.9

var _die: DieData
var _face_index := -1
var _state := State.IDLE
var _frame := 0
var _frame_elapsed := 0.0
var _spin_elapsed := 0.0


func _init() -> void:
	PixelArt.apply(self)
	custom_minimum_size = FRAME_SIZE
	size = FRAME_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Rzuca kością i po animacji pokazuje ściankę face_index (np. wynik DieData.roll()).
func roll(die: DieData, face_index: int) -> void:
	_die = die
	_face_index = face_index
	_state = State.ROLLING
	_frame = 0
	_frame_elapsed = 0.0
	_spin_elapsed = 0.0
	set_process(true)
	queue_redraw()


## Pokazuje ściankę od razu, bez animacji.
func show_face(die: DieData, face_index: int) -> void:
	_die = die
	_face_index = face_index
	_state = State.SHOWING
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_frame_elapsed += delta
	match _state:
		State.ROLLING:
			_spin_elapsed += delta
			while _frame_elapsed >= ROLL_FRAME_TIME:
				_frame_elapsed -= ROLL_FRAME_TIME
				_frame = (_frame + 1) % ROLL_FRAMES
			# lądowanie zaczyna się po pełnej pętli, żeby nie było przeskoku obrotu
			if _spin_elapsed >= spin_time and _frame == 0:
				_state = State.LANDING
				_frame_elapsed = 0.0
		State.LANDING:
			if _frame_elapsed >= LAND_FRAME_TIMES[_frame]:
				_frame_elapsed = 0.0
				_frame += 1
				if _frame >= LAND_FRAMES:
					_state = State.SHOWING
					set_process(false)
					finished.emit()
	queue_redraw()


func _draw() -> void:
	if _die == null or _state == State.IDLE:
		return
	draw_texture(SHADOW, Vector2.ZERO)
	if _state == State.SHOWING:
		DieGraphics.draw_face(self, FACE_OFFSET, _die.type.id, _die.get_face_attribute(_face_index),
				_die.get_face_value(_face_index))
		return
	var sheet: Texture2D = ROLL_SHEETS.get(_die.type.id, ROLL_SHEETS[&"physical"])
	var index := _frame if _state == State.ROLLING else ROLL_FRAMES + _frame
	draw_texture_rect_region(sheet, Rect2(Vector2.ZERO, FRAME_SIZE), Rect2(Vector2(index * FRAME_SIZE.x, 0.0), FRAME_SIZE))
