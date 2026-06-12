extends RefCounted

const CardDatabaseScript := preload("res://scripts/services/card_database.gd")
const CARD_DATA_PATH := "res://data/cards.json"

var _failures: Array[String] = []
var _count := 0

func run() -> Dictionary:
	_failures.clear()
	_count = 0
	var card_db = CardDatabaseScript.new()
	_assert_true(card_db.load_cards(CARD_DATA_PATH), "card database loads sample cards")
	if _failures.is_empty():
		_test_build_tags_loaded(card_db)
		_test_build_upgraded_unit(card_db)
		_test_build_upgraded_spells(card_db)
		_test_get_card_restores_upgraded_card(card_db)
		_test_upgraded_card_preserves_build_tags(card_db)
		_test_nested_upgraded_card_is_ignored(card_db)
		_test_unknown_upgraded_card_is_ignored(card_db)
	return {
		"count": _count,
		"failures": _failures,
	}

func _test_build_tags_loaded(card_db) -> void:
	var card: Dictionary = card_db.get_card("fireball")
	_assert_true((card.get("build_tags", []) as Array).has("fire"), "fireball has fire build tag")

func _test_build_upgraded_unit(card_db) -> void:
	var deck: Array = card_db.build_deck_from_ids(["militia_plus"])
	_assert_eq(deck.size(), 1, "build_deck_from_ids restores upgraded unit")
	if deck.is_empty():
		return
	var card: Dictionary = deck[0]
	_assert_eq(String(card.get("id", "")), "militia_plus", "upgraded unit keeps plus id")
	_assert_true(String(card.get("name", "")).ends_with("+"), "upgraded unit name has plus suffix")
	_assert_eq(int(card.get("attack", 0)), 2, "upgraded militia gets attack +1")
	_assert_eq(int(card.get("health", 0)), 2, "upgraded militia gets health +1")

func _test_build_upgraded_spells(card_db) -> void:
	var deck: Array = card_db.build_deck_from_ids([
		"captain_order_plus",
		"elven_insight_plus",
		"dark_bargain_plus",
	])
	_assert_eq(deck.size(), 3, "build_deck_from_ids restores upgraded spells")
	var by_id: Dictionary = {}
	for card in deck:
		by_id[String(card.get("id", ""))] = card
	_assert_eq(String(Dictionary(by_id.get("captain_order_plus", {})).get("text", "")), "내 모든 유닛 공격력 +2", "captain_order_plus text is upgraded")
	_assert_eq(int(Dictionary(by_id.get("elven_insight_plus", {})).get("cost", -1)), 2, "elven_insight_plus cost is reduced")
	_assert_eq(String(Dictionary(by_id.get("dark_bargain_plus", {})).get("text", "")), "내 영웅 체력 1 잃음. 카드 2장 드로우", "dark_bargain_plus text is upgraded")

func _test_get_card_restores_upgraded_card(card_db) -> void:
	var card: Dictionary = card_db.get_card("militia_plus")
	_assert_eq(String(card.get("id", "")), "militia_plus", "get_card restores upgraded unit")
	_assert_eq(int(card.get("attack", 0)), 2, "get_card returns upgraded attack")

func _test_upgraded_card_preserves_build_tags(card_db) -> void:
	var card: Dictionary = card_db.get_card("fireball_plus")
	_assert_true((card.get("build_tags", []) as Array).has("fire"), "upgraded card preserves build tags")

func _test_nested_upgraded_card_is_ignored(card_db) -> void:
	var deck: Array = card_db.build_deck_from_ids(["militia_plus_plus"])
	_assert_true(deck.is_empty(), "nested upgraded card id is ignored")
	_assert_true(card_db.get_card("militia_plus_plus").is_empty(), "get_card rejects nested upgraded id")

func _test_unknown_upgraded_card_is_ignored(card_db) -> void:
	var deck: Array = card_db.build_deck_from_ids(["missing_card_plus"])
	_assert_true(deck.is_empty(), "unknown upgraded card id is ignored")

func _assert_true(value: bool, message: String) -> void:
	_count += 1
	if not value:
		_failures.append(message)

func _assert_eq(actual, expected, message: String) -> void:
	_count += 1
	if actual != expected:
		_failures.append("%s | expected=%s actual=%s" % [message, str(expected), str(actual)])
