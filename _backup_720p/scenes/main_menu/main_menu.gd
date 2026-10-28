extends Control
## Menu główne: Rozegraj mecz / Edytor zagrań / Opcje / Wyjście.

@onready var _play_button: Button = %PlayButton
@onready var _play_editor_button: Button = %PlayEditorButton
@onready var _options_button: Button = %OptionsButton
@onready var _exit_button: Button = %ExitButton
@onready var _options_menu: OptionsMenu = %OptionsMenu
@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_play_editor_button.pressed.connect(_on_play_editor_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_options_menu.closed.connect(_on_options_closed)
	# W przeglądarce nie da się zamknąć gry – chowamy przycisk.
	_exit_button.visible = not OS.has_feature("web")
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	_play_button.grab_focus()


func _on_play_pressed() -> void:
	SceneManager.change_scene(SceneManager.MATCH_SETUP)


func _on_play_editor_pressed() -> void:
	SceneManager.change_scene(SceneManager.PLAY_EDITOR)


func _on_options_pressed() -> void:
	_options_menu.open()


func _on_options_closed() -> void:
	_options_button.grab_focus()


func _on_exit_pressed() -> void:
	get_tree().quit()
