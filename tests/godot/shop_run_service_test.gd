extends RefCounted

const ShopRunServiceScript := preload("res://src/services/shop_run_service.gd")

var _failures: Array[String] = []
var _count := 0

func run() -> Dictionary:
	_failures.clear()
	_count = 0
	var service = ShopRunServiceScript.new()
	_test_generate_shop_state(service)
	_test_buy_card(service)
	_test_buy_card_rejects_invalid_purchase(service)
	_test_buy_relic(service)
	_test_buy_relic_rejects_second_purchase(service)
	_test_begin_remove(service)
	_test_buy_heal(service)
	_test_buy_heal_at_full_hp_fails(service)
	return {"count": _count, "failures": _failures}

func _test_generate_shop_state(service) -> void:
	var state: Dictionary = service.generate_shop_state({
		"roll_card_choices": Callable(self, "_stub_roll_cards"),
		"random_relic": Callable(self, "_stub_random_relic"),
		"relic_ids": [],
	})
	_assert_eq((state.get("cards", []) as Array).size(), 3, "generate_shop_state creates 3 cards")
	_assert_eq(String(Dictionary(state.get("relic", {})).get("id", "")), "relic_a", "generate_shop_state includes relic")

func _test_buy_card(service) -> void:
	var run_data: Dictionary = {"gold": 100, "deck_ids": [], "pending_shop": {"cards": ["card_a"], "purchased_cards": []}}
	var result: Dictionary = service.buy_card(run_data, "card_a")
	_assert_true(bool(result.get("ok", false)), "buy_card succeeds with enough gold")
	_assert_eq(int(run_data.get("gold", 0)), 65, "buy_card subtracts gold")
	_assert_eq(String((run_data.get("deck_ids", []) as Array)[0]), "card_a", "buy_card appends deck id")

func _test_buy_card_rejects_invalid_purchase(service) -> void:
	var duplicate_run_data: Dictionary = {"gold": 100, "deck_ids": [], "pending_shop": {"cards": ["card_a"], "purchased_cards": ["card_a"]}}
	var duplicate_result: Dictionary = service.buy_card(duplicate_run_data, "card_a")
	_assert_true(not bool(duplicate_result.get("ok", false)), "buy_card rejects already purchased card")
	var missing_run_data: Dictionary = {"gold": 100, "deck_ids": [], "pending_shop": {"cards": ["card_a"], "purchased_cards": []}}
	var missing_result: Dictionary = service.buy_card(missing_run_data, "card_b")
	_assert_true(not bool(missing_result.get("ok", false)), "buy_card rejects card outside shop offer")

func _test_buy_relic(service) -> void:
	var applied: Array = []
	var run_data: Dictionary = {"gold": 200, "relic_ids": [], "pending_shop": {"relic": {"id": "relic_a"}, "relic_bought": false}}
	var result: Dictionary = service.buy_relic(run_data, func(data, relic_id): applied.append(relic_id))
	_assert_true(bool(result.get("ok", false)), "buy_relic succeeds with enough gold")
	_assert_eq(int(run_data.get("gold", 0)), 90, "buy_relic subtracts gold")
	_assert_eq(String((run_data.get("relic_ids", []) as Array)[0]), "relic_a", "buy_relic appends relic id")
	_assert_eq(String(applied[0]), "relic_a", "buy_relic calls apply_relic")

func _test_buy_relic_rejects_second_purchase(service) -> void:
	var run_data: Dictionary = {"gold": 200, "relic_ids": [], "pending_shop": {"relic": {"id": "relic_a"}, "relic_bought": true}}
	var result: Dictionary = service.buy_relic(run_data, func(_data, _relic_id): pass)
	_assert_true(not bool(result.get("ok", false)), "buy_relic rejects second purchase")
	_assert_eq(int(run_data.get("gold", 0)), 200, "buy_relic second purchase keeps gold")

func _test_begin_remove(service) -> void:
	var run_data: Dictionary = {"gold": 100, "pending_shop": {"remove_count": 0}}
	var result: Dictionary = service.begin_remove(run_data)
	_assert_true(bool(result.get("ok", false)), "begin_remove succeeds with enough gold")
	_assert_eq(int(run_data.get("gold", 0)), 100, "begin_remove does not subtract gold before confirm")
	result = service.confirm_remove(run_data)
	_assert_true(bool(result.get("ok", false)), "confirm_remove succeeds with enough gold")
	_assert_eq(int(run_data.get("gold", 0)), 55, "confirm_remove subtracts first remove cost")
	_assert_eq(int(Dictionary(run_data.get("pending_shop", {})).get("remove_count", 0)), 1, "confirm_remove increments remove_count")

func _test_buy_heal(service) -> void:
	var run_data: Dictionary = {"gold": 100, "hp": 10, "max_hp": 25}
	var result: Dictionary = service.buy_heal(run_data)
	_assert_true(bool(result.get("ok", false)), "buy_heal succeeds with enough gold")
	_assert_eq(int(run_data.get("gold", 0)), 55, "buy_heal subtracts gold")
	_assert_eq(int(run_data.get("hp", 0)), 25, "buy_heal clamps to max hp")

func _test_buy_heal_at_full_hp_fails(service) -> void:
	var run_data: Dictionary = {"gold": 100, "hp": 25, "max_hp": 25}
	var result: Dictionary = service.buy_heal(run_data)
	_assert_true(not bool(result.get("ok", false)), "buy_heal fails at full hp")
	_assert_eq(int(run_data.get("gold", 0)), 100, "buy_heal at full hp keeps gold")

func _stub_roll_cards(count: int) -> Array:
	return ["a", "b", "c"].slice(0, count)

func _stub_random_relic(_excluded: Array) -> Dictionary:
	return {"id": "relic_a"}

func _assert_true(value: bool, message: String) -> void:
	_count += 1
	if not value:
		_failures.append(message)

func _assert_eq(actual, expected, message: String) -> void:
	_count += 1
	if actual != expected:
		_failures.append("%s | expected=%s actual=%s" % [message, str(expected), str(actual)])
