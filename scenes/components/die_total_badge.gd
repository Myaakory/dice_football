class_name DieTotalBadge
extends Control
## Kość pokazana jako jedna liczba: suma oczek na wszystkich ściankach, w kolorze typu kości.
## Aktywna – wypełniona i obramowana, nieaktywna – wyblakła. Najechanie pokazuje całą kość (siatka ścianek).
## Ten sam wygląd rysuje lista kadry (SquadRow) przez draw_badge().

const SIZE := Vector2(25, 18)
const FONT_SIZE := 14
const INACTIVE_ALPHA := 0.3

var die: DieData
var active := true


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(p_die: DieData, p_active: bool) -> void:
	die = p_die
	active = p_active
	tooltip_text = "die"  # treść tooltipa buduje _make_custom_tooltip
	queue_redraw()


func _make_custom_tooltip(_for_text: String) -> Object:
	return DieNetView.make_tooltip(die, DieNetView.get_die_title(die)) if die != null else null


func _draw() -> void:
	if die == null:
		return
	var font := get_theme_default_font()
	var baseline := roundf((size.y + font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) / 2.0)
	draw_badge(self, Rect2(Vector2.ZERO, size), die, active, font, FONT_SIZE, baseline)


static func draw_badge(canvas: CanvasItem, rect: Rect2, p_die: DieData, p_active: bool, font: Font, font_size: int,
		baseline: float) -> void:
	var die_color := p_die.type.color
	var text_color := die_color.lightened(0.45)
	if p_active:
		canvas.draw_rect(rect, die_color.darkened(0.55))
		canvas.draw_rect(rect, die_color, false, 1.0)
	else:
		text_color = Color(die_color, INACTIVE_ALPHA)
	canvas.draw_string(font, Vector2(rect.position.x, baseline), str(p_die.get_total()), HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x, font_size, text_color)
