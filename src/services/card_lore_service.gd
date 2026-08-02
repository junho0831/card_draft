extends RefCounted
class_name CardLoreService

var lore_by_id: Dictionary = {}

func load_lore(path: String) -> bool:
	var json_text := FileAccess.get_file_as_string(path)
	if json_text.is_empty():
		push_error("Card lore data file is empty or missing: %s" % path)
		return false

	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Card lore data must be a JSON object: %s" % path)
		return false

	lore_by_id.clear()
	for card_id_variant in Dictionary(parsed).keys():
		var card_id := String(card_id_variant)
		var raw_lore: Variant = Dictionary(parsed)[card_id_variant]
		if typeof(raw_lore) != TYPE_DICTIONARY:
			push_error("Card lore for %s is not an object." % card_id)
			return false
		var lore: Dictionary = raw_lore
		if not _is_valid_lore(card_id, lore):
			return false
		lore_by_id[card_id] = lore.duplicate(true)
	return true

func lore_for(card_id: String) -> Dictionary:
	return Dictionary(lore_by_id.get(card_id, {})).duplicate(true)

func has_lore(card_id: String) -> bool:
	return lore_by_id.has(card_id)

func missing_lore_ids(card_defs: Array) -> Array[String]:
	var missing: Array[String] = []
	for card_data in card_defs:
		var card: Dictionary = card_data
		var card_id := String(card.get("id", ""))
		if card_id.is_empty() or not lore_by_id.has(card_id):
			missing.append(card_id)
	return missing

func _is_valid_lore(card_id: String, lore: Dictionary) -> bool:
	for field in ["story", "role", "hook"]:
		if not lore.has(field) or String(lore.get(field, "")).strip_edges().is_empty():
			push_error("Card lore for %s is missing required field: %s" % [card_id, field])
			return false
	return true
