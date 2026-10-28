class_name PitchLayout
extends RefCounted
## Układ boiska: rozmiar grafiki, pole gry (prostokąt między zewnętrznymi krawędziami linii bocznych i końcowych)
## i wysokość pasa murawy. Pole gry to zawsze 10 pasów murawy = 5 stref taktycznych po 2 pasy. Wszystkie widoki
## boiska (mecz, ustawienie, edytor zagrań, opcje, menu) biorą geometrię stąd, a grafikę składa PitchBuilder.
## Linie, pola karne, koła i bramki mają stałe rozmiary w pikselach – zmienia się tylko pole gry.

## Pasy murawy na polu gry (po 2 na strefę taktyczną).
const STRIPE_COUNT := 10

static var _default: PitchLayout

## Rozmiar grafiki boiska (z trawą za liniami).
var size: Vector2i
## Pole gry w pikselach grafiki.
var field: Rect2i
var stripe_height: int


static func create(pitch_size: Vector2i, field_rect: Rect2i, stripe: int) -> PitchLayout:
	var layout := PitchLayout.new()
	layout.size = pitch_size
	layout.field = field_rect
	layout.stripe_height = stripe
	assert(field_rect.size.y == stripe * STRIPE_COUNT, "PitchLayout: field height must be STRIPE_COUNT stripes")
	return layout


## Boisko gry: trawa 128 × 128 położona 4 × 7 razy (512 × 896), pole gry 512 × 820 (strefa 164 px),
## za liniami końcowymi 38 px trawy.
static func get_default() -> PitchLayout:
	if _default == null:
		_default = create(Vector2i(512, 896), Rect2i(0, 38, 512, 820), 82)
	return _default


## Wysokość strefy taktycznej (2 pasy murawy).
func get_zone_height() -> float:
	return field.size.y / float(MatchRules.ZONE_COUNT)


## Prostokąt strefy (1–5, strefa 1 na dole) w pikselach grafiki.
func get_zone_rect(zone: int) -> Rect2:
	var height := get_zone_height()
	return Rect2(field.position.x, field.end.y - zone * height, field.size.x, height)


## Pas murawy pod wierszem y grafiki: indeks pasa pola gry (0 = najbliżej górnej linii końcowej). Za liniami
## końcowymi – najbliższy pas pola gry, więc trawa za bramką ma kolor pasa przy linii końcowej.
func get_stripe_index(y: int) -> int:
	return clampi(floori(float(y - field.position.y) / stripe_height), 0, STRIPE_COUNT - 1)


## Pasy od górnej linii końcowej: ciemny, jasny, ... (jak w pitch.aseprite).
func is_dark_stripe(stripe_index: int) -> bool:
	return stripe_index % 2 == 0
