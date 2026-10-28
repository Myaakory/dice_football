class_name UiFrames
extends RefCounted
## Pikselowe ramki 9-slice (tools/gen_ui_graphics.py → assets/graphics/ui/frame_N.png) jako StyleBoxTexture.
## Tekstura 32x32: rogi FRAME_MARGIN px, środek jednolity, więc ramka skaluje się do dowolnego rozmiaru
## (mały tooltip, karta zagrania 200x96, duży panel). Prawa i dolna krawędź mają 1 px cienia.

enum Style {
	PITCH,  ## zielona z nitami – domyślny tooltip
	GOLD,   ## złota – wyróżnienie, ważne komunikaty
	SLATE,  ## tablica taktyczna – karty zagrań
	PAPER,  ## jasny papier – notatki (wymaga ciemnego tekstu)
}

const FRAME_MARGIN := 10.0
const SHADOW_SIZE := 1.0
## Nazwy stylów do wyboru w opcjach (klucze tłumaczeń).
const STYLE_NAME_KEYS: Dictionary[Style, String] = {
	Style.PITCH: "STYLE_FRAME_PITCH",
	Style.GOLD: "STYLE_FRAME_GOLD",
	Style.SLATE: "STYLE_FRAME_SLATE",
	Style.PAPER: "STYLE_FRAME_PAPER",
}
## Marginesy treści tooltipa (mniejsze niż w panelach).
const TOOLTIP_CONTENT_MARGIN := 7.0
const TEXTURES: Dictionary[Style, Texture2D] = {
	Style.PITCH: preload("res://assets/graphics/ui/frame_1.png"),
	Style.GOLD: preload("res://assets/graphics/ui/frame_2.png"),
	Style.SLATE: preload("res://assets/graphics/ui/frame_3.png"),
	Style.PAPER: preload("res://assets/graphics/ui/frame_4.png"),
}


static func make_stylebox(style: Style, content_margin := 8.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = TEXTURES[style]
	box.set_texture_margin_all(FRAME_MARGIN)
	box.content_margin_left = content_margin
	box.content_margin_top = content_margin
	box.content_margin_right = content_margin + SHADOW_SIZE
	box.content_margin_bottom = content_margin + SHADOW_SIZE
	return box


## Ustawia wygląd wszystkich tooltipów gry (motyw projektu: TooltipPanel + TooltipLabel).
static func apply_tooltip_style(style: Style) -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	theme.set_stylebox(&"panel", &"TooltipPanel", make_stylebox(style, TOOLTIP_CONTENT_MARGIN))
	theme.set_color(&"font_color", &"TooltipLabel", get_text_color(style))


## Kolor tekstu czytelny na tle danej ramki.
static func get_text_color(style: Style) -> Color:
	return Color("#3a2414") if style == Style.PAPER else Color("#e8efe0")
