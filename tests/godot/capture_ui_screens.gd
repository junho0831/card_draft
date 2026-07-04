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
	main._clear_run()
	main._show_main_menu()
	await process_frame
	await process_frame
	await _capture("01_main_menu")

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

	main._show_ui_guide()
	await process_frame
	await process_frame
	await _capture("01b_ui_guide")

	root.remove_child(main)
	main.free()
	print("UI captures saved to %s" % global_dir)
	quit(0)

func _capture(file_name: String) -> void:
	var image: Image = null
	for i in range(12):
		await _wait_for_capture_frame()
		var texture := root.get_viewport().get_texture()
		if texture == null:
			printerr("Viewport texture is unavailable. Run this capture script without --headless.")
			quit(1)
			return
		image = texture.get_image()
		if image != null and _image_has_content(image):
			break
	if image == null:
		printerr("Viewport image is unavailable. Run this capture script without --headless.")
		quit(1)
		return
	if not _image_has_content(image):
		printerr("Viewport image has no rendered UI content for %s." % file_name)
		quit(1)
		return
	var path := "%s/%s.png" % [output_dir, file_name]
	var err := image.save_png(path)
	if err != OK:
		printerr("Failed to save %s: %s" % [path, error_string(err)])
		quit(1)

func _wait_for_capture_frame() -> void:
	var draw_state := {"ready": false}
	var mark_draw := func() -> void:
		draw_state["ready"] = true
	RenderingServer.frame_post_draw.connect(mark_draw, CONNECT_ONE_SHOT)
	for i in range(8):
		await process_frame
		if bool(draw_state.get("ready", false)):
			break
	if RenderingServer.frame_post_draw.is_connected(mark_draw):
		RenderingServer.frame_post_draw.disconnect(mark_draw)

func _image_has_content(image: Image) -> bool:
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return false
	var min_luma := 1.0
	var max_luma := 0.0
	for x_index in range(12):
		for y_index in range(8):
			var x := int(float(width - 1) * (float(x_index) + 0.5) / 12.0)
			var y := int(float(height - 1) * (float(y_index) + 0.5) / 8.0)
			var color := image.get_pixel(x, y)
			var luma := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
			min_luma = minf(min_luma, luma)
			max_luma = maxf(max_luma, luma)
	return max_luma - min_luma > 0.02

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
