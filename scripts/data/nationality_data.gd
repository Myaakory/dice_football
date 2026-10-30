class_name NationalityData
extends RefCounted
## Narodowość zawodnika (wiersz data/nationalities.csv, id = kod FIFA, np. POL).
## Pochodzenie wyglądu (kolumna "origins") czyta PortraitLooks z manifestu portretów, nie stąd.

const FLAG_HORIZONTAL_PREFIX := "h:"
const FLAG_VERTICAL_PREFIX := "v:"

var id: StringName
var name_key: String
## Opis flagi z pasów: "h:#rrggbb|#rrggbb" (poziome, od góry) albo "v:#rrggbb|…" (pionowe, od lewej). Puste = brak flagi.
var flag: String = ""


func has_flag() -> bool:
	return not get_flag_colors().is_empty()


## true = pasy pionowe (od lewej), false = poziome (od góry).
func is_flag_vertical() -> bool:
	return flag.begins_with(FLAG_VERTICAL_PREFIX)


## Kolory pasów flagi w kolejności rysowania; pusta tablica = brak flagi albo błędny zapis.
func get_flag_colors() -> PackedColorArray:
	var colors := PackedColorArray()
	if not flag.begins_with(FLAG_HORIZONTAL_PREFIX) and not flag.begins_with(FLAG_VERTICAL_PREFIX):
		return colors
	for stripe in flag.substr(2).split("|", false):
		if not Color.html_is_valid(stripe):
			return PackedColorArray()
		colors.append(Color.html(stripe))
	return colors
