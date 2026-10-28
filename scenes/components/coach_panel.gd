class_name CoachPanel
extends VBoxContainer
## Trener drużyny i jego perki (W15). Pełny (compact = false): „Trener: imię nazwisko”, pod spodem każdy perk –
## nazwa i opis. Zwięzły (compact = true, ekran składu): jedna linia „Trener: … · Perki:” i perki jako etykiety
## z opisem w podpowiedzi.

const TEXT := Color(0.91, 0.937, 0.878)
const DIM_TEXT := Color(0.91, 0.937, 0.878, 0.6)
const PERK_COLOR := Color("#f2cf4a")
const PERK_BG := Color(0.95, 0.81, 0.29, 0.14)


static func create(coach: CoachData, compact := false) -> CoachPanel:
	var panel := CoachPanel.new()
	panel._build(coach, compact)
	return panel


## Tekst do podpowiedzi (np. nazwa drużyny na ekranie meczu): trener i perki z opisami.
static func describe(coach: CoachData) -> String:
	if coach == null:
		return ""
	var lines := PackedStringArray([TranslationServer.translate("COACH_LABEL") % coach.get_full_name()])
	for perk in coach.perks:
		lines.append("• %s: %s" % [TranslationServer.translate(perk.name_key),
				TranslationServer.translate(perk.description_key)])
	return "\n".join(lines)


func _build(coach: CoachData, compact: bool) -> void:
	add_theme_constant_override(&"separation", 4)
	if coach == null:
		add_child(_label(tr("COACH_NONE"), 14, DIM_TEXT))
		return
	if compact:
		var row := HFlowContainer.new()
		row.add_theme_constant_override(&"h_separation", 8)
		row.add_theme_constant_override(&"v_separation", 4)
		add_child(row)
		row.add_child(_label(tr("COACH_LABEL") % coach.get_full_name(), 14, TEXT))
		row.add_child(_label(tr("COACH_PERKS") if not coach.perks.is_empty() else tr("COACH_NO_PERKS"), 14, DIM_TEXT))
		for perk in coach.perks:
			row.add_child(_perk_chip(perk))
		return
	add_child(_label(tr("COACH_LABEL") % coach.get_full_name(), 16, TEXT))
	if coach.perks.is_empty():
		add_child(_label(tr("COACH_NO_PERKS"), 13, DIM_TEXT))
	for perk in coach.perks:
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", 0)
		add_child(box)
		box.add_child(_label(tr(perk.name_key), 14, PERK_COLOR))
		var description := _label(tr(perk.description_key), 13, DIM_TEXT)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(description)


## Perk w zwięzłym widoku: nazwa na złotawym tle, opis w podpowiedzi.
func _perk_chip(perk: PerkData) -> Control:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PERK_BG
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	chip.add_theme_stylebox_override(&"panel", style)
	chip.tooltip_text = tr(perk.description_key)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	var label := _label(tr(perk.name_key), 13, PERK_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)
	return chip


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label
