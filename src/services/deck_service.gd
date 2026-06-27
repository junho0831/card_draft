extends RefCounted
class_name DeckService

func deck_summary_from_cards(deck: Array) -> String:
	var counts := {}
	var source_cards := {}
	for card in deck:
		var id := String(card["id"])
		counts[id] = int(counts.get(id, 0)) + 1
		source_cards[id] = card
	return deck_summary_from_counts(counts, source_cards)

func deck_summary_from_counts(counts: Dictionary, source_cards: Dictionary) -> String:
	var ids := counts.keys()
	ids.sort_custom(func(a, b) -> bool:
		var card_a: Dictionary = source_cards[a]
		var card_b: Dictionary = source_cards[b]
		if int(card_a["cost"]) == int(card_b["cost"]):
			return String(card_a["name"]) < String(card_b["name"])
		return int(card_a["cost"]) < int(card_b["cost"])
	)
	var text := ""
	for id in ids:
		if not source_cards.has(id):
			continue
		var card: Dictionary = source_cards[id]
		var stat_text := ""
		if card["type"] == "unit":
			stat_text = " %d/%d" % [card["attack"], card["health"]]
		text += "%d장  [%d] %s%s  %s/%s  %s\n" % [int(counts[id]), card["cost"], card["name"], stat_text, card["race"], card["attr"], type_name(String(card["type"]))]
	if text.is_empty():
		return "남은 카드 없음"
	return text

func count_in_array(values: Array, target: String) -> int:
	var count := 0
	for value in values:
		if String(value) == target:
			count += 1
	return count

func type_name(card_type: String) -> String:
	match card_type:
		"unit":
			return "유닛"
		"spell":
			return "주문"
		"equipment":
			return "장착"
		_:
			return card_type
