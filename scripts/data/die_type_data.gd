class_name DieTypeData
extends RefCounted
## Typ kości (fizyczna / techniczna / defensywna) – określa, jaka cecha jest na której ściance.
## Liczbę punktów na ściankach definiuje dopiero konkretna kość zawodnika (DieData).

var id: StringName
var name_key: String
var color: Color = Color.WHITE
var face_attributes: Array[StringName] = []
