class_name KitColors
extends RefCounted
## Kolory strojów. Bramkarz dostaje strój z palety, który odróżnia się od koszulek obu drużyn
## (i od bramkarza rywala). PROTOTYP: paleta w kodzie; docelowo kolory bramkarzy w arkuszu (zakładka teams).

## [kolor główny, kolor dodatkowy] – kolejność = pierwszeństwo wyboru.
const GOALKEEPER_KITS: Array[Array] = [
	[Color("#2b3036"), Color("#d4ec5a")],
	[Color("#e07b24"), Color("#2b3036")],
	[Color("#7d4fb8"), Color("#f2efe6")],
	[Color("#f2c94c"), Color("#2b3036")],
	[Color("#d94f8c"), Color("#2b3036")],
]
## Minimalna odległość kolorów (RGB 0..1), żeby stroje się nie myliły.
const MIN_DISTANCE := 0.35


## Strój bramkarza drużyny [główny, dodatkowy]; `avoid` = kolory, od których ma się odróżniać
## (koszulka rywala, strój jego bramkarza).
static func get_goalkeeper_kit(team: TeamData, avoid: Array[Color] = []) -> Array[Color]:
	var others: Array[Color] = [team.primary_color]
	others.append_array(avoid)
	for kit in GOALKEEPER_KITS:
		if others.all(func(color: Color) -> bool: return _distance(kit[0], color) >= MIN_DISTANCE):
			return [kit[0], kit[1]]
	return [GOALKEEPER_KITS[0][0], GOALKEEPER_KITS[0][1]]


## Stroje bramkarzy obu drużyn meczu: [gospodarze, goście], każdy [główny, dodatkowy].
static func get_match_goalkeeper_kits(home: TeamData, away: TeamData) -> Array[Array]:
	var home_kit := get_goalkeeper_kit(home, [away.primary_color])
	var away_kit := get_goalkeeper_kit(away, [home.primary_color, home_kit[0]])
	return [home_kit, away_kit]


static func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
