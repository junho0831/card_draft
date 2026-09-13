extends SceneTree
const Storage = preload("res://src/services/game_storage.gd")
const MAIN = preload("res://src/core/Main.tscn")
func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")
func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
func capture(name: String) -> void:
	await create_timer(0.6).timeout
	await frame()
	RenderingServer.force_draw(false, 0.0)
	for i in range(5):
		await frame()
	get_root().get_texture().get_image().save_png(Storage.path_for(name + ".png"))
func run() -> void:
	var viewport := Vector2i(1280, 720) if OS.get_cmdline_user_args().has("--desktop") else Vector2i(390, 844)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = viewport
	var main = MAIN.instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("layout_viewport_override", viewport)
	main.set_meta("disable_timed_battle_fx", true)
	root.add_child(main)
	await frame()
	main.set_meta("layout_viewport_override", viewport)
	root.size = viewport
	main._apply_root_layout()
	main._on_layout_resize_timeout()
	await frame()
	main.player_profile["learning_stage"] = 0
	main._start_new_run()
	await capture("01_learning_choice")
	main._init_run("human")
	await capture("02_learning_map")
	main.run_flow.prepare_battle("normal")
	await capture("03_first_battle")
	if main.battle_screen.mana_status_label.text != "마나 2 / 2":
		push_error("First-turn mana display is stale")
		quit(1)
		return
	main.current_run.active_enemy = {}
	main.current_run.battle_snapshot = {}
	main.run_flow.advance_from_current_node()
	main.run_flow.enter_current_node()
	await capture("04_equipment_reward")
	var reward = preload("res://src/ui/screens/reward_screen.gd").new(main)
	reward._skip_card_reward()
	main.run_flow.prepare_battle("normal")
	await capture("05_second_battle")
	main._clear_screen()
	main.queue_free()
	await frame()
	print("PASS onboarding captures")
	quit()
