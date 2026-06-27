extends RefCounted

const EventRunServiceScript := preload("res://src/services/event_run_service.gd")

var _failures: Array[String] = []
var _count := 0

func run() -> Dictionary:
	_failures.clear()
	_count = 0
	var service = EventRunServiceScript.new()
	_test_merchant_card(service)
	_test_merchant_relic_without_available_relic(service)
	_test_remove_card(service)
	_test_gain_random_card(service)
	return {"count": _count, "failures": _failures}

func _test_merchant_card(service) -> void:
	var run_data: Dictionary = {"hp": 20, "pending_event": {"id": "x"}, "pending_card_reward": {}, "relic_ids": []}
	var result: Dictionary = service.resolve_effect(run_data, "merchant_card", {
		"roll_high_cost_cards": Callable(self, "_stub_high_cost_cards"),
	})
	_assert_eq(String(result.get("action", "")), "show_card_reward", "merchant_card returns reward action")
	_assert_eq(int(run_data.get("hp", 0)), 15, "merchant_card reduces hp by 5")
	_assert_eq((Dictionary(run_data.get("pending_card_reward", {})).get("choices", []) as Array).size(), 3, "merchant_card creates 3 reward choices")
	_assert_true(Dictionary(run_data.get("pending_event", {})).is_empty(), "merchant_card clears pending_event")

func _test_merchant_relic_without_available_relic(service) -> void:
	var run_data: Dictionary = {"gold": 75, "relic_ids": []}
	var result: Dictionary = service.resolve_effect(run_data, "merchant_relic", {
		"random_relic": func(_excluded): return {},
	})
	_assert_eq(String(result.get("action", "")), "persisted_message", "merchant_relic without relic returns persisted message")
	_assert_eq(String(result.get("message", "")), "얻을 유물이 없습니다.", "merchant_relic without relic shows empty-pool message")
	_assert_eq(int(run_data.get("gold", 0)), 75, "merchant_relic without relic does not subtract gold")

func _test_remove_card(service) -> void:
	var result: Dictionary = service.resolve_effect({}, "remove_card", {})
	_assert_eq(String(result.get("action", "")), "show_remove_card", "remove_card requests remove subscreen")
	_assert_eq(String(result.get("source", "")), "event_complete", "remove_card source is event_complete")

func _test_gain_random_card(service) -> void:
	var run_data: Dictionary = {"deck_ids": [], "relic_ids": []}
	var result: Dictionary = service.resolve_effect(run_data, "gain_random_card", {
		"roll_card_choices": Callable(self, "_stub_single_choice"),
		"card_name": Callable(self, "_stub_card_name"),
	})
	_assert_eq(String(result.get("action", "")), "persisted_message", "gain_random_card returns persisted message")
	_assert_eq(String((run_data.get("deck_ids", []) as Array)[0]), "sample_card", "gain_random_card appends card to deck")

func _stub_high_cost_cards(count: int) -> Array:
	return ["a", "b", "c"].slice(0, count)

func _stub_single_choice(count: int) -> Array:
	return ["sample_card"]

func _stub_card_name(card_id: String) -> String:
	return "샘플 카드"

func _assert_true(value: bool, message: String) -> void:
	_count += 1
	if not value:
		_failures.append(message)

func _assert_eq(actual, expected, message: String) -> void:
	_count += 1
	if actual != expected:
		_failures.append("%s | expected=%s actual=%s" % [message, str(expected), str(actual)])
