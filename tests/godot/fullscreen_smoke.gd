extends SceneTree

const MAIN_SCENE := preload("res://src/core/Main.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	main.player_profile["settings"]["fullscreen"] = true
	main._apply_window_mode()
	await process_frame
	await process_frame

	var mode := DisplayServer.window_get_mode()
	var window_size := DisplayServer.window_get_size()
	var viewport_size: Vector2 = main.get_viewport_rect().size
	if mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		printerr("Fullscreen smoke failed: mode=%d window=%s viewport=%s" % [mode, str(window_size), str(viewport_size)])
		quit(1)
		return
	if main._layout_viewport_size() != viewport_size:
		printerr("Fullscreen smoke failed: layout size %s does not match viewport %s" % [str(main._layout_viewport_size()), str(viewport_size)])
		quit(1)
		return
	print("Fullscreen smoke passed: mode=%d window=%s viewport=%s" % [mode, str(window_size), str(viewport_size)])
	quit(0)
