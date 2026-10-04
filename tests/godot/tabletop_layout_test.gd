extends SceneTree

const Storage = preload("res://src/services/game_storage.gd")
var failures: Array[String] = []
var count := 0

func _initialize() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failures.append(message)

func settle() -> void:
	for frame in range(12): await process_frame

func verify_actions(main: Node, viewport: Vector2i) -> void:
	for button in main.find_children("*", "Button", true, false):
		if not button.is_visible_in_tree() or not button.has_meta("standard_action_metrics"): continue
		check(button.size.y >= 44, "touch height: %s %s" % [viewport, button.text])
		check(button.size.x >= 44, "touch width: %s %s" % [viewport, button.text])
		var before: Rect2 = button.get_global_rect()
		var disabled: bool = button.disabled
		button.disabled = not disabled
		await settle()
		check(button.get_global_rect() == before, "stable disabled state: " + button.text)
		button.disabled = disabled

func run() -> void:
	var main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("disable_timed_battle_fx", true)
	root.add_child(main)
	main.set_process(false)
	main.player_profile.learning_stage = 5
	main._init_run("human")
	for viewport in [Vector2i(844, 390), Vector2i(932, 430), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = viewport
		main.set_meta("layout_viewport_override", viewport)
		main.touch_input_active = viewport.x < 1100
		main._apply_root_layout()
		main.last_layout_signature = main._layout_signature(viewport)
		main.layout_resize_timer.stop()
		main._show_race_selection()
		await settle()
		var bounds := Rect2(Vector2.ZERO, Vector2(root.content_scale_size))
		if viewport.x < 1100:
			for portrait in main.root_box.find_children("RacePortrait", "TextureRect", true, false):
				check(portrait.size.y >= 96 and portrait.size.x >= 200, "race portrait fills choice")
				check(bounds.encloses(portrait.get_global_rect()), "race portrait visible")
		await verify_actions(main, viewport)
		main._show_map()
		await settle()
		if viewport.x < 1100:
			var dock: Control = main.active_screen_controller.screen_action_dock
			var buttons := dock.find_children("*", "Button", true, false)
			for button in buttons:
				check(button.size.x <= 240.1, "map action bounded")
				check(bounds.encloses(button.get_global_rect()), "map action visible")
			check(buttons.back().get_global_rect().end.x > bounds.end.x - 32, "map action right aligned")
		await verify_actions(main, viewport)
		main._show_settings()
		await settle()
		for key in ["bgm_volume", "sfx_volume"]:
			var slider: Control = main.root_box.find_child(key, true, false)
			check(bounds.encloses(slider.get_global_rect()), "settings volume visible")
			check(slider.size.x <= bounds.size.x * 0.6, "settings slider bounded")
		await verify_actions(main, viewport)
		main._show_main_menu()
		await settle()
		await verify_actions(main, viewport)
	root.size = Vector2i(932, 430)
	main.touch_input_active = true
	main.set_meta("layout_viewport_override", root.size)
	main.set_meta("display_safe_area_override", Rect2(59, 0, 814, 409))
	main._apply_root_layout()
	main._show_main_menu()
	await settle()
	var safe_bounds: Rect2 = main._safe_layout_rect()
	var home_action: Button
	for button in main.modal_layer.find_children("*", "Button", true, false):
		if button.text in ["이어하기", "새 런 시작"]: home_action = button
	check(is_instance_valid(home_action), "home primary stays in fixed dock")
	if is_instance_valid(home_action):
		check(safe_bounds.encloses(home_action.get_global_rect()), "home action respects notch and home indicator")
		check(home_action.get_global_rect().end.x >= safe_bounds.end.x - 32, "home action bottom right safe area")
		check(home_action.get_global_rect().end.y >= safe_bounds.end.y - 32, "home action stays near bottom")
	main._clear_screen()
	main.queue_free()
	await settle()
	for failure in failures: printerr(failure)
	print("PASS %d tabletop layout checks" % count if failures.is_empty() else "FAIL %d/%d" % [failures.size(), count])
	quit(0 if failures.is_empty() else 1)
