extends SceneTree

const TEST_SCRIPTS := [
	preload("res://tests/godot/run_state_test.gd"),
	preload("res://tests/godot/card_database_test.gd"),
	preload("res://tests/godot/event_run_service_test.gd"),
	preload("res://tests/godot/shop_run_service_test.gd"),
	preload("res://tests/godot/main_flow_smoke_test.gd"),
]

func _init() -> void:
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	var failures: Array[String] = []
	var total := 0
	for script in TEST_SCRIPTS:
		var test_case = script.new()
		var result: Dictionary = test_case.run()
		total += int(result.get("count", 0))
		for failure in result.get("failures", []):
			failures.append(String(failure))
	if failures.is_empty():
		print("PASS %d assertions" % total)
		quit(0)
		return
		
	printerr("FAIL %d/%d assertions" % [failures.size(), total])
	for failure in failures:
		printerr("- %s" % failure)
	quit(1)
