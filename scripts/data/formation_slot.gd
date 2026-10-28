class_name FormationSlot
extends RefCounted
## Jedna pozycja w ustawieniu taktycznym.
## Pasy liczone są od własnej bramki: 1 = bramkarz i obrońcy ... 5 = napastnicy.

const LANE_COUNT := 5

var index: int = 0
var role_id: StringName
var lane: int = 1
## Pozycja w poziomie: 0.0 = lewa strona boiska, 1.0 = prawa (z perspektywy drużyny atakującej w górę).
var x: float = 0.5
## Położenie wewnątrz pasa: 0.0 = krawędź bliżej własnej bramki, 1.0 = krawędź bliżej bramki rywala.
var depth: float = 0.5
