class_name OptionsMenu
extends Control
## Okno opcji (język, pełny ekran, głośność, wygląd tooltipów, zaznaczenia strefy, przyciemnienie boiska,
## poświata kości w meczu i styl mapy pozycji).
## Wyświetlane jako nakładka nad bieżącym ekranem; podgląd stylów odświeża się na żywo.

signal closed

@onready var _language_option: OptionButton = %LanguageOption
@onready var _fullscreen_check: CheckButton = %FullscreenCheck
@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _tooltip_style_option: OptionButton = %TooltipStyleOption
@onready var _zone_style_option: OptionButton = %ZoneStyleOption
@onready var _pitch_dim_slider: HSlider = %PitchDimSlider
@onready var _dice_glow_slider: HSlider = %DiceGlowSlider
@onready var _dot_style_option: OptionButton = %DotStyleOption
@onready var _tooltip_preview: PanelContainer = %TooltipPreview
@onready var _tooltip_preview_label: Label = %TooltipPreviewLabel
@onready var _zone_preview: Control = %ZonePreview
@onready var _back_button: Button = %BackButton

const PITCH_TEXTURE: Texture2D = preload("res://assets/graphics/pitch/pitch.png")
## Fragment boiska pod podglądem zaznaczenia (strefa 3 z kołem środkowym) i skala podglądu.
const ZONE_PREVIEW_REGION := Rect2(0, 288, 448, 128)
const ZONE_PREVIEW_SCALE := 0.5


func _ready() -> void:
	hide()
	for locale in Settings.SUPPORTED_LOCALES:
		_language_option.add_item(Settings.LOCALE_NAMES[locale])
		_language_option.set_item_metadata(_language_option.item_count - 1, locale)
	_language_option.item_selected.connect(_on_language_selected)
	_fullscreen_check.toggled.connect(Settings.set_fullscreen)
	_volume_slider.value_changed.connect(Settings.set_master_volume)
	_fill_style_options()
	_tooltip_style_option.item_selected.connect(Settings.set_tooltip_style)
	_zone_style_option.item_selected.connect(Settings.set_zone_highlight_style)
	_pitch_dim_slider.value_changed.connect(Settings.set_pitch_dim)
	_dice_glow_slider.value_changed.connect(Settings.set_dice_glow)
	_dot_style_option.item_selected.connect(Settings.set_position_dot_style)
	_zone_preview.draw.connect(_draw_zone_preview)
	_back_button.pressed.connect(close)
	Settings.settings_changed.connect(_sync_from_settings)


func open() -> void:
	_sync_from_settings()
	show()
	_back_button.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _sync_from_settings() -> void:
	_language_option.select(Settings.SUPPORTED_LOCALES.find(Settings.locale))
	_fullscreen_check.set_pressed_no_signal(Settings.fullscreen)
	_volume_slider.set_value_no_signal(Settings.master_volume)
	_tooltip_style_option.select(Settings.tooltip_style)
	_zone_style_option.select(Settings.zone_highlight_style)
	_pitch_dim_slider.set_value_no_signal(Settings.pitch_dim)
	_dice_glow_slider.set_value_no_signal(Settings.dice_glow)
	_dot_style_option.select(Settings.position_dot_style)
	var style := Settings.tooltip_style as UiFrames.Style
	_tooltip_preview.add_theme_stylebox_override(&"panel", UiFrames.make_stylebox(style, UiFrames.TOOLTIP_CONTENT_MARGIN))
	_tooltip_preview_label.add_theme_color_override(&"font_color", UiFrames.get_text_color(style))
	_zone_preview.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_fill_style_options()
		_sync_from_settings()


## Listy stylów z ikonką ramki (tooltip) – teksty tłumaczone ręcznie, bo przebudowujemy je przy zmianie języka.
func _fill_style_options() -> void:
	_tooltip_style_option.clear()
	for style: UiFrames.Style in UiFrames.STYLE_NAME_KEYS:
		_tooltip_style_option.add_icon_item(UiFrames.TEXTURES[style], tr(UiFrames.STYLE_NAME_KEYS[style]), style)
	_zone_style_option.clear()
	for i in PitchView.ZONE_HIGHLIGHT_NAME_KEYS.size():
		_zone_style_option.add_item(tr(PitchView.ZONE_HIGHLIGHT_NAME_KEYS[i]), i)
	_dot_style_option.clear()
	for style: PositionMap.DotStyle in PositionMap.DOT_STYLE_NAME_KEYS:
		_dot_style_option.add_item(tr(PositionMap.DOT_STYLE_NAME_KEYS[style]), style)
	_tooltip_style_option.select(Settings.tooltip_style)
	_zone_style_option.select(Settings.zone_highlight_style)
	_dot_style_option.select(Settings.position_dot_style)


## Fragment boiska z wybranym zaznaczeniem strefy, pomniejszony o połowę.
func _draw_zone_preview() -> void:
	var rect := Rect2(Vector2.ZERO, ZONE_PREVIEW_REGION.size * ZONE_PREVIEW_SCALE)
	_zone_preview.draw_texture_rect_region(PitchDimmer.get_texture(PITCH_TEXTURE, Settings.pitch_dim), rect,
			ZONE_PREVIEW_REGION)
	var highlight := PitchView.ZONE_HIGHLIGHTS[clampi(Settings.zone_highlight_style, 0, PitchView.ZONE_HIGHLIGHTS.size() - 1)]
	_zone_preview.draw_texture_rect(highlight, rect, false)


func _on_language_selected(index: int) -> void:
	Settings.set_locale(_language_option.get_item_metadata(index))
