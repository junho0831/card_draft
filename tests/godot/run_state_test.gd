extends RefCounted

const RunStateScript := preload("res://src/services/run_state.gd")
const TEMP_PATH := "user://run_state_test.json"

var _failures: Array[String] = []
var _count := 0

func run() -> Dictionary:
	_failures.clear()
	_count = 0
	var run_state = RunStateScript.new()
	_test_create_new_run(run_state)
	_test_mark_node_cleared_idempotent(run_state)
	_test_advance_after_node(run_state)
	_test_current_node_bounds(run_state)
	_test_save_load_roundtrip(run_state)
	_test_invalid_json_returns_empty(run_state)
	run_state.clear(TEMP_PATH)
	return {
		"count": _count,
		"failures": _failures,
	}

func _test_create_new_run(run_state) -> void:
	var acts: Array[Dictionary] = [
		{"name": "Act 1", "nodes": ["battle", "boss"]},
	]
	var deck: Array[String] = ["militia", "small_flame"]
	var run_data: Dictionary = run_state.create_new_run(acts, deck, 55, 120, "elf")
	_assert_eq(int(run_data.get("act", 0)), 1, "create_new_run starts at act 1")
	_assert_eq(int(run_data.get("current_node_index", -1)), 0, "create_new_run starts at node 0")
	_assert_eq(int(run_data.get("hp", 0)), 55, "create_new_run sets hp")
	_assert_eq(int(run_data.get("gold", 0)), 120, "create_new_run sets gold")
	_assert_true(run_data.has("battle_snapshot"), "create_new_run includes battle_snapshot")
	_assert_true(run_data.has("pending_message"), "create_new_run includes pending_message")
	_assert_true(run_data.has("pending_subscreen"), "create_new_run includes pending_subscreen")
	_assert_eq(String(run_data.get("race_id", "")), "elf", "create_new_run stores selected race")
	deck[0] = "changed"
	_assert_eq(String((run_data.get("deck_ids", []) as Array)[0]), "militia", "create_new_run duplicates deck ids")
	var fallback_run: Dictionary = run_state.create_new_run(acts, deck, 55, 120, "unknown")
	_assert_eq(String(fallback_run.get("race_id", "")), "human", "create_new_run falls back to human for unknown race")

func _test_mark_node_cleared_idempotent(run_state) -> void:
	var run_data: Dictionary = {"act": 2, "current_node_index": 3, "visited_nodes": []}
	run_state.mark_node_cleared(run_data)
	run_state.mark_node_cleared(run_data)
	var visited: Array = run_data.get("visited_nodes", [])
	_assert_eq(visited.size(), 1, "mark_node_cleared is idempotent")
	_assert_eq(String(visited[0]), "2:3", "mark_node_cleared stores node key")

func _test_advance_after_node(run_state) -> void:
	var run_data: Dictionary = {
		"act": 1,
		"current_node_index": 0,
		"map_nodes": [
			{"nodes": ["battle", "boss"]},
			{"nodes": ["battle"]},
		],
		"result": "",
	}
	run_state.advance_after_node(run_data)
	_assert_eq(int(run_data.get("current_node_index", -1)), 1, "advance_after_node moves within act")
	run_state.advance_after_node(run_data)
	_assert_eq(int(run_data.get("act", 0)), 2, "advance_after_node moves to next act")
	_assert_eq(int(run_data.get("current_node_index", -1)), 0, "advance_after_node resets node index on next act")
	run_state.advance_after_node(run_data)
	_assert_eq(String(run_data.get("result", "")), "win", "advance_after_node marks final win")

func _test_current_node_bounds(run_state) -> void:
	var run_data: Dictionary = {
		"act": 1,
		"current_node_index": 1,
		"map_nodes": [{"nodes": ["battle", "shop"]}],
	}
	var node: Dictionary = run_state.current_node(run_data)
	_assert_eq(String(node.get("type", "")), "shop", "current_node returns current type")
	run_data["current_node_index"] = 5
	_assert_true(run_state.current_node(run_data).is_empty(), "current_node returns empty for out-of-range index")

func _test_save_load_roundtrip(run_state) -> void:
	var run_data: Dictionary = {
		"act": 1,
		"current_node_index": 0,
		"deck_ids": ["militia_plus"],
		"pending_subscreen": {"type": "upgrade_card", "source": "rest_upgrade"},
		"battle_snapshot": {"current_player": "player"},
	}
	run_state.save(TEMP_PATH, run_data)
	var loaded: Dictionary = run_state.load_or_empty(TEMP_PATH)
	_assert_eq(String(((loaded.get("deck_ids", []) as Array)[0])), "militia_plus", "save/load preserves upgraded card ids")
	_assert_eq(String(Dictionary(loaded.get("pending_subscreen", {})).get("type", "")), "upgrade_card", "save/load preserves pending_subscreen")
	_assert_eq(String(Dictionary(loaded.get("battle_snapshot", {})).get("current_player", "")), "player", "save/load preserves battle_snapshot")

func _test_invalid_json_returns_empty(run_state) -> void:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_string("{not valid json")
	file = null
	_assert_true(run_state.load_or_empty(TEMP_PATH).is_empty(), "load_or_empty returns empty on invalid json")

func _assert_true(value: bool, message: String) -> void:
	_count += 1
	if not value:
		_failures.append(message)

func _assert_eq(actual, expected, message: String) -> void:
	_count += 1
	if actual != expected:
		_failures.append("%s | expected=%s actual=%s" % [message, str(expected), str(actual)])
