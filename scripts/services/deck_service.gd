extends RefCounted
class_name DeckService

func make_owned_starter_deck(card_defs: Array, owned_cards: Dictionary, deck_size: int, max_copies: int) -> Array:
	var deck: Array = []
	for card in card_defs:
		var id := String(card["id"])
		var count: int = min(int(owned_cards.get(id, 0)), max_copies)
		for i in range(count):
			if deck.size() < deck_size:
				deck.append(id)
	if deck.size() < deck_size:
		for card in card_defs:
			var id := String(card["id"])
			while deck.size() < deck_size and count_in_array(deck, id) < max_copies:
				deck.append(id)
	return deck

func is_deck_valid(deck_ids: Array, cards_by_id: Dictionary, owned_cards: Dictionary, deck_size: int, max_copies: int) -> bool:
	if deck_ids.size() != deck_size:
		return false
	var counts := {}
	for raw_id in deck_ids:
		var id := String(raw_id)
		if not cards_by_id.has(id):
			return false
		counts[id] = int(counts.get(id, 0)) + 1
	for id in counts.keys():
		if int(counts[id]) > max_copies:
			return false
		if int(counts[id]) > int(owned_cards.get(id, 0)):
			return false
	return true

func validation_message(deck_ids: Array, cards_by_id: Dictionary, owned_cards: Dictionary, deck_size: int, max_copies: int) -> String:
	if deck_ids.size() != deck_size:
		return "30장이 필요합니다"
	var counts := {}
	for raw_id in deck_ids:
		var id := String(raw_id)
		counts[id] = int(counts.get(id, 0)) + 1
		if not cards_by_id.has(id):
			return "알 수 없는 카드가 있습니다"
		if int(counts[id]) > max_copies:
			return "동일 카드는 최대 3장입니다"
		if int(counts[id]) > int(owned_cards.get(id, 0)):
			return "보유 수량을 초과했습니다"
	return "저장 가능"

func deck_summary_from_cards(deck: Array) -> String:
	var counts := {}
	var source_cards := {}
	for card in deck:
		var id := String(card["id"])
		counts[id] = int(counts.get(id, 0)) + 1
		source_cards[id] = card
	return deck_summary_from_counts(counts, source_cards)

func deck_summary_text(deck_ids: Array, cards_by_id: Dictionary) -> String:
	var counts := {}
	for raw_id in deck_ids:
		var id := String(raw_id)
		counts[id] = int(counts.get(id, 0)) + 1
	return deck_summary_from_counts(counts, cards_by_id)

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

func total_owned_cards(owned_cards: Dictionary) -> int:
	var total := 0
	for value in owned_cards.values():
		total += int(value)
	return total

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
