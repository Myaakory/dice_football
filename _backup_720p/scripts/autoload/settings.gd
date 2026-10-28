extends Node
## Ustawienia gracza (język, pełny ekran, głośność, wygląd interfejsu) zapisywane w user://settings.cfg.
## Argument uruchomienia `-- --windowed` wymusza okno (przydatne przy testach).

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const SUPPORTED_LOCALES: Array[String] = ["en", "pl"]
## Nazwy języków zawsze w ich własnym języku – nie tłumaczymy ich.
const LOCALE_NAMES := {"en": "English", "pl": "Polski"}

var locale: String = "en"
var fullscreen: bool = true
var master_volume: float = 1.0
## Ramka tooltipów (UiFrames.Style).
var tooltip_style: int = UiFrames.Style.PITCH
## Wariant zaznaczenia strefy boiska (indeks w PitchView.ZONE_HIGHLIGHTS).
var zone_highlight_style: int = 0
## Przyciemnienie murawy (0 = brak, PitchDimmer.MAX_DIM = najciemniej); domyślnie średnie.
var pitch_dim: float = 0.4
## Styl kropek na mapie pozycji zawodnika (PositionMap.DotStyle).
var position_dot_style: int = 0
## Siła poświaty w kolorze drużyny wokół kości na boisku meczu (0 = brak, 1 = najmocniejsza).
var dice_glow: float = 0.6


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		set_fullscreen(not fullscreen)
		get_viewport().set_input_as_handled()


func set_locale(value: String) -> void:
	locale = value if value in SUPPORTED_LOCALES else SUPPORTED_LOCALES[0]
	_apply_and_save()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_and_save()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_and_save()


func set_tooltip_style(value: int) -> void:
	tooltip_style = clampi(value, 0, UiFrames.Style.size() - 1)
	_apply_and_save()


func set_zone_highlight_style(value: int) -> void:
	zone_highlight_style = clampi(value, 0, PitchView.ZONE_HIGHLIGHTS.size() - 1)
	_apply_and_save()


func set_pitch_dim(value: float) -> void:
	pitch_dim = clampf(value, 0.0, PitchDimmer.MAX_DIM)
	_apply_and_save()


func set_dice_glow(value: float) -> void:
	dice_glow = clampf(value, 0.0, 1.0)
	_apply_and_save()


func set_position_dot_style(value: int) -> void:
	position_dot_style = clampi(value, 0, PositionMap.DotStyle.size() - 1)
	_apply_and_save()


func load_settings() -> void:
	locale = _get_system_locale()
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		locale = str(config.get_value("general", "locale", locale))
		fullscreen = bool(config.get_value("video", "fullscreen", fullscreen))
		master_volume = clampf(float(config.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
		tooltip_style = clampi(int(config.get_value("interface", "tooltip_style", tooltip_style)),
				0, UiFrames.Style.size() - 1)
		zone_highlight_style = clampi(int(config.get_value("interface", "zone_highlight_style", zone_highlight_style)),
				0, PitchView.ZONE_HIGHLIGHTS.size() - 1)
		pitch_dim = clampf(float(config.get_value("interface", "pitch_dim", pitch_dim)), 0.0, PitchDimmer.MAX_DIM)
		position_dot_style = clampi(int(config.get_value("interface", "position_dot_style", position_dot_style)),
				0, PositionMap.DotStyle.size() - 1)
		dice_glow = clampf(float(config.get_value("interface", "dice_glow", dice_glow)), 0.0, 1.0)
	if locale not in SUPPORTED_LOCALES:
		locale = SUPPORTED_LOCALES[0]


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "locale", locale)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("interface", "tooltip_style", tooltip_style)
	config.set_value("interface", "zone_highlight_style", zone_highlight_style)
	config.set_value("interface", "pitch_dim", pitch_dim)
	config.set_value("interface", "position_dot_style", position_dot_style)
	config.set_value("interface", "dice_glow", dice_glow)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_error("Settings: cannot save settings (%s)" % error_string(error))


func apply() -> void:
	TranslationServer.set_locale(locale)
	_apply_window_mode()
	var bus := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(bus, master_volume <= 0.0)
	UiFrames.apply_tooltip_style(tooltip_style as UiFrames.Style)
	settings_changed.emit()


func _apply_and_save() -> void:
	apply()
	save_settings()


func _apply_window_mode() -> void:
	# Okno gry osadzone w edytorze nie obsługuje zmiany trybu.
	if Engine.is_embedded_in_editor() or DisplayServer.get_name() == "headless":
		return
	var use_fullscreen := fullscreen and not OS.get_cmdline_user_args().has("--windowed")
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if use_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() == mode:
		return
	DisplayServer.window_set_mode(mode)
	if mode == DisplayServer.WINDOW_MODE_WINDOWED:
		# Po wyjściu z pełnego ekranu: okno w rozdzielczości bazowej, wyśrodkowane.
		var window_size := Vector2i(
				ProjectSettings.get_setting("display/window/size/viewport_width"),
				ProjectSettings.get_setting("display/window/size/viewport_height"))
		var screen_rect := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		DisplayServer.window_set_size(window_size)
		DisplayServer.window_set_position(screen_rect.position + (screen_rect.size - window_size) / 2)


func _get_system_locale() -> String:
	var language := OS.get_locale_language()
	return language if language in SUPPORTED_LOCALES else SUPPORTED_LOCALES[0]
