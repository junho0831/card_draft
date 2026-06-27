extends SceneTree

const MAIN_SCENE := preload("res://src/core/Main.tscn")

var output_dir := "user://ui_captures"

func _init() -> void:
	call_deferred("_capture_all")

func _capture_all() -> void:
	var global_dir := ProjectSettings.globalize_path(output_dir)
	DirAccess.make_dir_recursive_absolute(global_dir)

	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	main.set_meta("disable_timed_battle_fx", true)
	await process_frame
	await process_frame
	await _capture("01_main_menu")

	main._show_ui_guide()
	await process_frame
	await process_frame
	await _capture("01b_ui_guide")

	main._show_main_menu()
	await process_frame
	await process_frame

	main._start_new_run()
	await process_frame
	await process_frame
	await _capture("02_run_map")

	main._enter_current_node()
	await process_frame
	await process_frame
	await process_frame
	_seed_battle_preview_units(main)
	await process_frame
	await _capture("03_battle")

	main.current_run["pending_card_reward"] = {
		"choices": main._roll_card_reward_choices(3, false),
		"gold_reward": 20,
		"bonus_relic": {},
	}
	main._show_card_reward()
	await process_frame
	await process_frame
	await _capture("04_card_reward")

	main.current_run["pending_shop"] = main.shop_run_service.generate_shop_state({
		"roll_card_choices": Callable(main, "_roll_card_choices"),
		"random_relic": Callable(main.relic_service, "random_relic"),
		"relic_ids": main.current_run.get("relic_ids", []),
	})
	main._show_shop()
	await process_frame
	await process_frame
	await _capture("05_shop")

	main.current_run["pending_event"] = main.event_service.roll_event()
	main.current_run["pending_card_reward"] = {}
	main._show_event()
	await process_frame
	await process_frame
	await _capture("06_event")

	main.current_run["pending_card_reward"] = {}
	main.current_run["pending_event"] = {}
	main.current_run["pending_shop"] = {}
	main._show_rest()
	await process_frame
	await process_frame
	await _capture("07_rest")

	main.current_run["pending_card_reward"] = {}
	main.current_run["pending_shop"] = {}
	main.current_run["pending_event"] = {}
	main.current_run["earned_soul_stones"] = 45
	main._show_run_result(true)
	await process_frame
	await process_frame
	await _capture("08_run_result")

	root.remove_child(main)
	main.free()
	print("UI captures saved to %s" % global_dir)
	quit(0)

func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var texture := root.get_viewport().get_texture()
	if texture == null:
		printerr("Viewport texture is unavailable. Run this capture script without --headless.")
		quit(1)
		return
	var image := texture.get_image()
	if image == null:
		printerr("Viewport image is unavailable. Run this capture script without --headless.")
		quit(1)
		return
	var path := "%s/%s.png" % [output_dir, file_name]
	var err := image.save_png(path)
	if err != OK:
		printerr("Failed to save %s: %s" % [path, error_string(err)])
		quit(1)

func _seed_battle_preview_units(main: Node) -> void:
	if main.battle_screen == null:
		return
	var player_unit: Dictionary = main.cards_by_id.get("rookie_swordsman", main.cards_by_id.get("militia", {})).duplicate(true)
	var enemy_unit: Dictionary = main.cards_by_id.get("skeleton_soldier", main.cards_by_id.get("thief", main.cards_by_id.get("militia", {}))).duplicate(true)
	if player_unit.is_empty() or enemy_unit.is_empty():
		return
	player_unit["can_attack"] = true
	enemy_unit["can_attack"] = false
	main.battle_screen.player["field"] = [player_unit]
	main.battle_screen.opponent["field"] = [enemy_unit]
	main.battle_screen.selected_attacker = 0
	main.battle_screen._refresh_ui()
