extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")

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
	var size := DisplayServer.window_get_size()
	if mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		printerr("Fullscreen smoke failed: mode=%d size=%s" % [mode, str(size)])
		quit(1)
		return
	print("Fullscreen smoke passed: mode=%d size=%s" % [mode, str(size)])
	quit(0)
