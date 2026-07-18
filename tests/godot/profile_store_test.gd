extends RefCounted

const ProfileStoreScript := preload("res://src/core/profile_store.gd")

var _failures: Array[String] = []
var _count := 0

func run() -> Dictionary:
	_failures.clear()
	_count = 0
	var store = ProfileStoreScript.new()

	var defaults: Dictionary = store.make_default_profile([])
	_assert_true(bool(defaults["settings"].get("fullscreen", false)), "new profiles start in fullscreen")
	_assert_true(bool(defaults["settings"].get("fullscreen_setting_initialized", false)), "new profiles mark fullscreen preference initialized")
	_assert_eq(String(defaults["settings"].get("ui_scale_mode", "")), "auto", "new profiles use automatic UI scale")

	var legacy: Dictionary = {"settings": {"fullscreen": false}}
	var migrated: Dictionary = store.normalize(legacy, [])
	_assert_true(bool(migrated["settings"].get("fullscreen", false)), "legacy profiles migrate to fullscreen once")
	_assert_true(bool(migrated["settings"].get("fullscreen_setting_initialized", false)), "legacy fullscreen migration records initialization")
	_assert_eq(String(migrated["settings"].get("ui_scale_mode", "")), "auto", "legacy profiles gain automatic UI scale")

	var windowed: Dictionary = {"settings": {"fullscreen": false, "fullscreen_setting_initialized": true}}
	var preserved: Dictionary = store.normalize(windowed, [])
	_assert_true(not bool(preserved["settings"].get("fullscreen", true)), "explicit windowed preference remains disabled")

	var invalid_scale: Dictionary = {"settings": {"ui_scale_mode": "huge"}}
	var normalized_scale: Dictionary = store.normalize(invalid_scale, [])
	_assert_eq(String(normalized_scale["settings"].get("ui_scale_mode", "")), "auto", "invalid UI scale falls back to automatic")

	return {"count": _count, "failures": _failures}

func _assert_true(value: bool, message: String) -> void:
	_count += 1
	if not value:
		_failures.append(message)

func _assert_eq(actual, expected, message: String) -> void:
	_assert_true(actual == expected, "%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
