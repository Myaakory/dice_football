class_name CsvLoader
extends RefCounted
## Wczytuje plik CSV z wierszem nagłówka i zwraca tablicę słowników (nazwa kolumny -> wartość).
## Format zgodny z eksportem zakładki Google Sheets (Plik > Pobierz > CSV).
## Puste wiersze i wiersze, których pierwsza komórka zaczyna się od '#', są pomijane.


static func load_table(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CsvLoader: cannot open '%s' (%s)" % [path, error_string(FileAccess.get_open_error())])
		return rows

	var header := file.get_csv_line()
	for i in header.size():
		header[i] = header[i].strip_edges().trim_prefix("﻿")

	while not file.eof_reached():
		var line := file.get_csv_line()
		if _is_empty_line(line) or line[0].strip_edges().begins_with("#"):
			continue
		var row := {}
		for i in header.size():
			if header[i].is_empty():
				continue
			row[header[i]] = line[i].strip_edges() if i < line.size() else ""
		rows.append(row)
	return rows


static func _is_empty_line(line: PackedStringArray) -> bool:
	for cell in line:
		if not cell.strip_edges().is_empty():
			return false
	return true


## Dzieli listę zapisaną w jednej komórce, np. "physical|defensive".
static func split_list(value: String, separator := "|") -> Array[StringName]:
	var result: Array[StringName] = []
	for part in value.split(separator, false):
		var trimmed := part.strip_edges()
		if not trimmed.is_empty():
			result.append(StringName(trimmed))
	return result
