extends RefCounted

const DATA_PATH = "res://data/starting_strategies.json"

static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Array:
		for entry in parsed:
			if entry is Dictionary:
				result.append(entry.duplicate(true))
	return result

static func for_race(race_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in all():
		if String(entry.get("race_id", "")) == race_id:
			result.append(entry)
	return result

static func get_strategy(id: String) -> Dictionary:
	for entry in all():
		if String(entry.get("id", "")) == id:
			return entry
	return {}

static func is_valid(entry: Dictionary, race_id: String, card_db, relic_service) -> bool:
	if entry.is_empty() or String(entry.get("race_id", "")) != race_id:
		return false
	if not String(entry.get("primary_tag", "")) in ["fire", "buff", "summon", "draw", "death", "low_hp"]:
		return false
	var deck: Array = entry.get("deck_ids", [])
	if deck.size() != 10 or relic_service.get_relic(String(entry.get("relic_id", ""))).is_empty():
		return false
	var race_name: String = {"human": "인간", "elf": "엘프", "undead": "언데드"}.get(race_id, "")
	for id in deck:
		var card: Dictionary = card_db.get_card(String(id))
		if card.is_empty() or not String(card.get("race", "")) in [race_name, "중립"]:
			return false
	return true
