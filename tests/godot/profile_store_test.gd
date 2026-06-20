extends RefCounted

const ProfileStoreScript := preload("res://scripts/core/profile_store.gd")

var _failures: Array[String] = []
var _count := 0

func run() -> Dictionary:
	_failures.clear()
	_count = 0
	var store = ProfileStoreScript.new()

	var defaults: Dictionary = store.make_default_profile([])
	_assert_true(bool(defaults["settings"].get("fullscreen", false)), "new profiles start in fullscreen")
	_assert_true(bool(defaults["settings"].get("fullscreen_setting_initialized", false)), "new profiles mark fullscreen preference initialized")

	var legacy: Dictionary = {"settings": {"fullscreen": false}}
	var migrated: Dictionary = store.normalize(legacy, [])
	_assert_true(bool(migrated["settings"].get("fullscreen", false)), "legacy profiles migrate to fullscreen once")
	_assert_true(bool(migrated["settings"].get("fullscreen_setting_initialized", false)), "legacy fullscreen migration records initialization")

	var windowed: Dictionary = {"settings": {"fullscreen": false, "fullscreen_setting_initialized": true}}
	var preserved: Dictionary = store.normalize(windowed, [])
	_assert_true(not bool(preserved["settings"].get("fullscreen", true)), "explicit windowed preference remains disabled")

	return {"count": _count, "failures": _failures}

func _assert_true(value: bool, message: String) -> void:
	_count += 1
	if not value:
		_failures.append(message)
