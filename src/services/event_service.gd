extends RefCounted
class_name EventService

const EVENTS_PATH := "res://data/events.json"

var events: Array[Dictionary] = []

func load_events() -> bool:
	var json_text := FileAccess.get_file_as_string(EVENTS_PATH)
	if json_text.is_empty():
		return false
	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_ARRAY:
		return false
	events.clear()
	for raw_event in parsed:
		if typeof(raw_event) == TYPE_DICTIONARY:
			events.append((raw_event as Dictionary).duplicate(true))
	return not events.is_empty()

func roll_event() -> Dictionary:
	if events.is_empty():
		return {}
	return events[randi() % events.size()].duplicate(true)
