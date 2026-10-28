extends CanvasLayer
## Przełączanie scen z krótkim zaciemnieniem ekranu.

const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const MATCH_SETUP := "res://scenes/match_setup/match_setup.tscn"
const MATCH := "res://scenes/match/match.tscn"
const PLAY_EDITOR := "res://scenes/play_editor/play_editor.tscn"

const FADE_TIME := 0.15

var _fade_rect: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.modulate.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade_rect)


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	# Blokujemy kliknięcia na czas przejścia.
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0)
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("SceneManager: cannot change scene to '%s' (%s)" % [path, error_string(error)])
	await get_tree().process_frame
	await _fade_to(0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", alpha, FADE_TIME)
	await tween.finished
