extends RefCounted

var _failures: Array[String] = []
var _count := 0

func run() -> Dictionary:
	_failures.clear()
	_count = 0
	_test_run_shape_targets_mid_length_run()
	_test_enemy_health_keeps_battles_short()
	return {
		"count": _count,
		"failures": _failures,
	}

func _test_run_shape_targets_mid_length_run() -> void:
	var acts: Array = _load_json_array("res://data/acts.json")
	_assert_eq(acts.size(), 1, "pacing uses a single act")
	if acts.is_empty():
		return
	var nodes: Array = (acts[0] as Dictionary).get("nodes", [])
	_assert_eq(nodes.size(), 8, "pacing keeps the launch act at eight map nodes")
	_assert_eq(String((nodes[0] as Array)[0]), "battle", "pacing starts with a normal battle")
	_assert_true((nodes[1] as Array).has("event") or (nodes[1] as Array).has("shop"), "second node offers an economic or event choice")
	_assert_eq(String((nodes[2] as Array)[0]), "battle", "third node returns to battle for early build growth")
	_assert_true((nodes[5] as Array).has("elite") or (nodes[5] as Array).has("event"), "late act includes an elite or event spike")
	_assert_eq(String((nodes[6] as Array)[0]), "rest", "run includes a rest node before boss")
	_assert_eq(String((nodes[nodes.size() - 1] as Array)[0]), "boss", "pacing ends directly on a boss")

func _test_enemy_health_keeps_battles_short() -> void:
	var enemies: Array = _load_json_array("res://data/enemies.json")
	for raw_enemy in enemies:
		var enemy: Dictionary = raw_enemy
		var tier := String(enemy.get("tier", "normal"))
		var hp := int(enemy.get("base_hp", 0))
		match tier:
			"normal":
				_assert_true(hp <= 15, "%s normal hp supports 1-2 turn battles" % String(enemy.get("id", "")))
			"elite":
				_assert_true(hp <= 22, "%s elite hp stays threatening without dragging out the run" % String(enemy.get("id", "")))
			"boss":
				_assert_true(hp <= 36, "%s boss hp supports a mid-length run without turning into a slog" % String(enemy.get("id", "")))

func _load_json_array(path: String) -> Array:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		_failures.append("%s should parse as array" % path)
		return []
	return parsed as Array

func _assert_true(value: bool, message: String) -> void:
	_count += 1
	if not value:
		_failures.append(message)

func _assert_eq(actual, expected, message: String) -> void:
	_count += 1
	if actual != expected:
		_failures.append("%s | expected=%s actual=%s" % [message, str(expected), str(actual)])
