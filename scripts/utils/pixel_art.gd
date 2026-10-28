class_name PixelArt
extends RefCounted
## Grafika pikselowa (boisko, koszulki, kości, portrety) ma stałą skalę: 1 piksel grafiki = 1 jednostka ekranu
## bazowego 1920×1080. Ekran jest skalowany do rozdzielczości monitora (stretch canvas_items), więc przy skali
## niecałkowitej (1440p) węzły z pixel artem używają shadera „sharp bilinear” zamiast filtra nearest.
## UI i tekst nie przechodzą przez ten shader – renderują się w natywnej rozdzielczości monitora.

const SHADER: Shader = preload("res://ui/shaders/pixel_art.gdshader")

static var _material: ShaderMaterial


## Włącza ostre skalowanie pixel artu na węźle (dotyczy tego, co węzeł rysuje sam, nie jego dzieci).
static func apply(item: CanvasItem) -> void:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	item.material = _material
	item.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
