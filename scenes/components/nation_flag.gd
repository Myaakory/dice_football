class_name NationFlag
extends Control
## Flaga narodowości z pasów (NationalityData), rysowana w kratce pikseli jak reszta pixel artu.

const GRID := Vector2(16, 10)
const OUTLINE := Color(0, 0, 0, 0.35)

var _vertical := false
var _bands: PackedColorArray = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## pixel = całkowita skala kratki. Bez flagi kontrolka jest niewidoczna.
func setup(nation: NationalityData, pixel: int) -> void:
	custom_minimum_size = GRID * pixel
	_vertical = nation.is_flag_vertical()
	_bands = nation.get_flag_colors()
	visible = not _bands.is_empty()
	queue_redraw()


func _draw() -> void:
	var count := _bands.size()
	for i in count:
		var rect := Rect2(i * size.x / count, 0, size.x / count, size.y) if _vertical \
				else Rect2(0, i * size.y / count, size.x, size.y / count)
		draw_rect(rect, _bands[i])
	draw_rect(Rect2(Vector2.ZERO, size), OUTLINE, false, 1.0)
