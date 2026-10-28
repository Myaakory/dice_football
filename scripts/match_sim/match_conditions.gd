class_name MatchConditions
extends RefCounted
## Warunki meczu pokazywane na ekranie: murawa, pogoda, kibice. PROTOTYP: wpływ na grę ma na razie tylko
## murawa (MatchRules.pitch_technical); pogoda i kibice to miejsce na przyszłe zasady (docs/design/match_rules.md).

enum PitchQuality { GOOD, WORN, POOR }

const PITCH_NAME_KEYS: Array[String] = ["MATCH_PITCH_GOOD", "MATCH_PITCH_WORN", "MATCH_PITCH_POOR"]
## Mnożnik kości technicznych dla jakości murawy (MatchRules.pitch_technical).
const PITCH_TECHNICAL: Array[float] = [1.0, 0.9, 0.8]
const WEATHER_NAME_KEYS: Dictionary[StringName, String] = {
	&"sunny": "MATCH_WEATHER_SUNNY",
	&"cloudy": "MATCH_WEATHER_CLOUDY",
	&"rain": "MATCH_WEATHER_RAIN",
}

var pitch_quality: PitchQuality = PitchQuality.GOOD
var weather: StringName = &"cloudy"
var temperature: int = 14
var attendance: int = 12400
var capacity: int = 18000


static func create_default() -> MatchConditions:
	return MatchConditions.new()


func apply_to(rules: MatchRules) -> void:
	rules.pitch_technical = PITCH_TECHNICAL[pitch_quality]


func get_attendance_ratio() -> float:
	return float(attendance) / maxf(capacity, 1.0)
