extends SceneTree

const TEST_SCRIPTS := [
	preload("res://tests/godot/run_state_test.gd"),
	preload("res://tests/godot/card_database_test.gd"),
	preload("res://tests/godot/event_run_service_test.gd"),
	preload("res://tests/godot/shop_run_service_test.gd"),
	preload("res://tests/godot/profile_store_test.gd"),
	preload("res://tests/godot/card_effects_test.gd"),
	preload("res://tests/godot/pacing_test.gd"),
	preload("res://tests/godot/main_flow_smoke_test.gd"),
]

var _profile_path := ProjectSettings.globalize_path("user://meta_profile.json")
var _profile_backup := ""
var _had_profile := false

func _init() -> void:
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	_isolate_profile()
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
		_restore_profile()
		quit(0)
		return
		
	printerr("FAIL %d/%d assertions" % [failures.size(), total])
	for failure in failures:
		printerr("- %s" % failure)
	_restore_profile()
	quit(1)

func _isolate_profile() -> void:
	_had_profile = FileAccess.file_exists(_profile_path)
	_profile_backup = FileAccess.get_file_as_string(_profile_path) if _had_profile else ""
	if _had_profile:
		DirAccess.remove_absolute(_profile_path)

func _restore_profile() -> void:
	if _had_profile:
		var file := FileAccess.open(_profile_path, FileAccess.WRITE)
		if file != null:
			file.store_string(_profile_backup)
	elif FileAccess.file_exists(_profile_path):
		DirAccess.remove_absolute(_profile_path)
