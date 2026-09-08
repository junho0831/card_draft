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

func get_card(id: String) -> Dictionary:
	if cards_by_id.has(id):
		return cards_by_id[id].duplicate(true)
	if not id.ends_with("_plus"):
		return {}
	return _build_upgraded_card(id)

func build_deck_from_ids(ids: Array) -> Array:
	var deck: Array = []
	for raw_id in ids:
		var card := get_card(String(raw_id))
		if not card.is_empty():
			deck.append(card)
	return deck

func _build_upgraded_card(id: String) -> Dictionary:
	var base_id := id.trim_suffix("_plus")
	if base_id.ends_with("_plus") or not cards_by_id.has(base_id):
		return {}
	var card: Dictionary = cards_by_id[base_id].duplicate(true)
	card["id"] = id
	card["name"] = "%s+" % String(card.get("name", ""))
	if String(card.get("type", "")) == "unit":
		card["attack"] = int(card.get("attack", 0)) + 1
		card["health"] = int(card.get("health", 0)) + 1
	elif String(card.get("type", "")) == "equipment":
		card["cost"] = max(0, int(card.get("cost", 0)) - 1)
	elif base_id == "captain_order":
		card["text"] = "내 모든 유닛 공격력 +2"
	elif base_id == "elven_insight":
		card["cost"] = max(0, int(card.get("cost", 0)) - 1)
	elif base_id == "dark_bargain":
		card["text"] = "내 영웅 체력 1 잃음. 카드 2장 드로우"
	elif String(card.get("type", "")) == "spell":
		if int(card.get("cost", 0)) >= 2:
			card["cost"] = int(card["cost"]) - 1
		else:
			card["effect_bonus"] = 1
			var texts := {
				"small_flame": "가장 앞의 적에게 피해 3. 처치하면 카드 1장 드로우",
				"first_aid": "내 영웅 체력 4 회복. 가장 앞의 아군 체력 +1",
				"royal_support": "카드 2장 드로우. 내 필드에 인간 유닛이 있으면 체력 +1",
				"gale_shot": "가장 앞의 적에게 피해 2. 이번 턴 카드 3장 이상 사용 시 피해 5",
				"death_mark": "적 영웅에게 저주 2스택 부여",
				"world_tree_ritual": "의식 2스택 획득. 사용 후 이번 전투에서 소멸",
				"funeral_fog": "가장 앞의 적 또는 적 영웅에게 피해 3. 저주 1스택 부여",
				"battlecry": "모든 아군 공격력 +2, 체력 +2",
			}
			card["text"] = texts.get(base_id, card.get("text", ""))
	return card

func _is_valid_card_def(card: Dictionary, index: int) -> bool:
	var required_fields := ["id", "name", "type", "race", "attr", "cost", "art", "art_id", "text"]
	for field in required_fields:
		if not card.has(field):
			push_error("Card at index %d is missing required field: %s" % [index, field])
			return false
	if card["type"] == "unit" and (not card.has("attack") or not card.has("health")):
		push_error("Unit card at index %d needs attack and health." % index)
		return false
	return true
