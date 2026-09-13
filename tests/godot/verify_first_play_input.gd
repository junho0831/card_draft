extends SceneTree

const Storage = preload("res://src/services/game_storage.gd")

func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")

func run() -> void:
	var result: Dictionary = await preload("res://tests/godot/ui_input_test.gd").new().run()
	if result.failures.is_empty():
		print("PASS %d input assertions" % result.count)
	else:
		printerr(result.failures)
	quit(0 if result.failures.is_empty() else 1)
