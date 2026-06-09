extends RefCounted
class_name CardDatabase

var card_defs: Array[Dictionary] = []
var cards_by_id := {}

func load_cards(path: String) -> bool:
	var json_text := FileAccess.get_file_as_string(path)
	if json_text.is_empty():
		push_error("Card data file is empty or missing: %s" % path)
		return false

	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Card data must be a JSON array: %s" % path)
		return false

	card_defs.clear()
	cards_by_id.clear()
	for index in range(parsed.size()):
		var raw_card: Variant = parsed[index]
		if typeof(raw_card) != TYPE_DICTIONARY:
			push_error("Card at index %d is not an object." % index)
			return false
		var card: Dictionary = raw_card
		if not _is_valid_card_def(card, index):
			return false
		card_defs.append(card.duplicate(true))
		cards_by_id[String(card["id"])] = card.duplicate(true)
	return not card_defs.is_empty()

func build_starter_deck(deck_size: int) -> Array:
	var deck: Array = []
	while deck.size() < deck_size:
		for card in card_defs:
			if deck.size() >= deck_size:
				break
			deck.append(card.duplicate(true))
	return deck

func build_deck_from_ids(ids: Array) -> Array:
	var deck: Array = []
	for raw_id in ids:
		var id := String(raw_id)
		if cards_by_id.has(id):
			deck.append(cards_by_id[id].duplicate(true))
	return deck

func _is_valid_card_def(card: Dictionary, index: int) -> bool:
	var required_fields := ["id", "name", "type", "race", "attr", "cost", "art", "text"]
	for field in required_fields:
		if not card.has(field):
			push_error("Card at index %d is missing required field: %s" % [index, field])
			return false
	if card["type"] == "unit" and (not card.has("attack") or not card.has("health")):
		push_error("Unit card at index %d needs attack and health." % index)
		return false
	return true
