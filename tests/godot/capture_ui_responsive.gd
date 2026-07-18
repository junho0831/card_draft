extends SceneTree

const MAIN_SCENE := preload("res://src/core/Main.tscn")
const CAPTURE_NAMES := [
	"01_main_menu",
	"02_race_selection",
	"03_run_map",
	"04_battle",
	"05_card_reward",
	"06_shop",
	"07_event",
	"08_rest",
	"09_run_result",
]
const VIEWPORTS := [
	{"name": "desktop_1920x1080", "size": Vector2i(1920, 1080)},
	{"name": "landscape_1280x720", "size": Vector2i(1280, 720)},
	{"name": "landscape_1024x768", "size": Vector2i(1024, 768)},
	{"name": "portrait_800x1280", "size": Vector2i(800, 1280)},
	{"name": "mobile_390x844", "size": Vector2i(390, 844)},
]

var output_dir := "user://ui_captures_responsive"
var capture_failed := false

func _init() -> void:
	call_deferred("_run_capture")

func _run_capture() -> void:
	var global_dir := ProjectSettings.globalize_path(output_dir)
	DirAccess.make_dir_recursive_absolute(global_dir)
	var args := OS.get_cmdline_user_args()
	var single_index := args.find("--single-viewport")
	if single_index != -1:
		if args.size() < single_index + 4:
			printerr("Expected --single-viewport <name> <width> <height>.")
			quit(1)
			return
		var viewport_name := String(args[single_index + 1])
		var viewport_size := Vector2i(int(args[single_index + 2]), int(args[single_index + 3]))
		await _capture_suite_for_viewport(viewport_name, viewport_size)
		if capture_failed:
			quit(1)
			return
		print("Responsive UI captures saved to %s" % global_dir)
		quit(0)
		return

	for viewport in VIEWPORTS:
		var viewport_name := String(viewport.get("name", ""))
		var viewport_size: Vector2i = viewport.get("size", Vector2i(1280, 720))
		var output: Array = []
		var code := 1
		for attempt in range(3):
			output.clear()
			code = OS.execute(
				OS.get_executable_path(),
				PackedStringArray([
					"--path",
					ProjectSettings.globalize_path("res://"),
					"-s",
					"res://tests/godot/capture_ui_responsive.gd",
					"--",
					"--single-viewport",
					viewport_name,
					str(viewport_size.x),
					str(viewport_size.y),
				]),
				output,
				true
			)
			if code == 0:
				break
			OS.delay_msec(400)
		if code != 0:
			printerr("Responsive capture failed for %s." % viewport_name)
			for line in output:
				printerr(String(line))
			quit(code)
			return

	print("Responsive UI captures saved to %s" % global_dir)
	quit(0)

func _capture_suite_for_viewport(viewport_name: String, viewport_size: Vector2i) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_position(Vector2i(40, 40))
	DisplayServer.window_set_size(viewport_size)
	await _wait_for_window_size(viewport_size)

	var main = MAIN_SCENE.instantiate()
	var initial_layout_size := Vector2i(1280, 720) if viewport_size.y > viewport_size.x else viewport_size
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("layout_viewport_override", initial_layout_size)
	main.set_meta("disable_timed_battle_fx", true)
	root.add_child(main)
	await _wait_for_capture_frame()
	await _wait_for_capture_frame()
	main._clear_run()
	main._show_main_menu()
	if initial_layout_size != viewport_size:
		main.set_meta("layout_viewport_override", viewport_size)
		main._apply_root_layout()
		main._on_layout_resize_timeout()
	await _wait_for_capture_frame()
	await _wait_for_capture_frame()

	if not _validate_wide_root_layout(main, viewport_size, "main_menu"):
		capture_failed = true
		quit(1)
		return
	await _capture_screen(main, "%s_%s" % [viewport_name, CAPTURE_NAMES[0]], "main_menu")

	main._start_new_run()
	await _wait_for_capture_frame()
	await _wait_for_capture_frame()
	await _capture_screen(main, "%s_%s" % [viewport_name, CAPTURE_NAMES[1]], "race_selection")

	main._init_run("human")
	await _wait_for_capture_frame()
	await _wait_for_capture_frame()
	await _capture_screen(main, "%s_%s" % [viewport_name, CAPTURE_NAMES[2]], "map")

	main._enter_current_node()
	await _wait_for_capture_frame()
	await _wait_for_capture_frame()
	await _wait_for_capture_frame()
	_seed_battle_preview_units(main)
	if initial_layout_size != viewport_size:
		var battle_state_preserved: bool = await _exercise_battle_runtime_resize(main, initial_layout_size, viewport_size)
		if not battle_state_preserved:
			capture_failed = true
			quit(1)
			return
	if viewport_size.y > viewport_size.x and viewport_size.x <= 900 and main.battle_screen != null:
		var hand_before := _hand_slot_signature(main.battle_screen.player.get("hand", []))
		var hand_count_before := (main.battle_screen.player.get("hand", []) as Array).size()
		main.battle_screen._on_hand_card_pressed(0)
		await _wait_for_capture_frame()
		await _wait_for_capture_frame()
		var hand_after := _hand_slot_signature(main.battle_screen.player.get("hand", []))
		if hand_count_before != (main.battle_screen.player.get("hand", []) as Array).size() or hand_before != hand_after:
			printerr("First touch changed hand contents or visual slots before confirmation @ %s." % viewport_name)
			capture_failed = true
			quit(1)
			return
	await _wait_for_capture_frame()
	if not _validate_wide_root_layout(main, viewport_size, "battle"):
		capture_failed = true
		quit(1)
		return
	if not _validate_landscape_battle_actions(main, viewport_size):
		capture_failed = true
		quit(1)
		return
	await _capture_screen(main, "%s_%s" % [viewport_name, CAPTURE_NAMES[3]], "battle")
	if viewport_size.x <= 600:
		main.root_scroll.scroll_vertical = 1000000
		await _wait_for_capture_frame()
		await _wait_for_capture_frame()
		await _capture_screen(main, "%s_04b_battle_hand" % viewport_name, "battle")
		main.root_scroll.scroll_vertical = 0
		await _wait_for_capture_frame()

	main.current_run["pending_card_reward"] = {
		"choices": main._roll_card_reward_choices(3, false),
		"gold_reward": 20,
		"bonus_relic": {},
	}
	main._show_card_reward()
	await _wait_for_capture_frame()
	await _wait_for_capture_frame()
	await _capture_screen(main, "%s_%s" % [viewport_name, CAPTURE_NAMES[4]], "reward")

	main.current_run["pending_shop"] = main.shop_run_service.generate_shop_state({
		"roll_card_choices": Callable(main, "_roll_card_choices"),
		"random_relic": Callable(main.relic_service, "random_relic"),
		"relic_ids": main.current_run.get("relic_ids", []),
	})
	main._show_shop()
	await _wait_for_capture_frame()
	await _wait_for_capture_frame()
	await _capture_screen(main, "%s_%s" % [viewport_name, CAPTURE_NAMES[5]], "shop")

	main.current_run["pending_event"] = main.event_service.roll_event()
	main.current_run["pending_card_reward"] = {}
	main._show_event()
	await _wait_for_capture_frame()
	await _wait_for_capture_frame()
	await _capture_screen(main, "%s_%s" % [viewport_name, CAPTURE_NAMES[6]], "event")

	main.current_run["pending_card_reward"] = {}
	main.current_run["pending_event"] = {}
	main.current_run["pending_shop"] = {}
	main._show_rest()
	for i in range(10):
		await _wait_for_capture_frame()
	await _capture_screen(main, "%s_%s" % [viewport_name, CAPTURE_NAMES[7]], "rest")

	main.current_run["pending_card_reward"] = {}
	main.current_run["pending_shop"] = {}
	main.current_run["pending_event"] = {}
	main.current_run["earned_soul_stones"] = 45
	main._show_run_result(true)
	await _wait_for_capture_frame()
	await _wait_for_capture_frame()
	await _capture_screen(main, "%s_%s" % [viewport_name, CAPTURE_NAMES[8]], "run_result")

	root.remove_child(main)
	main.queue_free()
	await _wait_for_capture_frame()

func _capture_screen(main: Node, file_name: String, expected_screen: String) -> void:
	if String(main.active_screen) != expected_screen:
		printerr("Expected %s before %s, got %s." % [expected_screen, file_name, String(main.active_screen)])
		capture_failed = true
		quit(1)
		return
	await create_timer(0.08).timeout
	for i in range(3):
		await _wait_for_capture_frame()
	RenderingServer.force_draw(false, 0.0)
	await _wait_for_capture_frame()
	await _capture(file_name)

func _capture(file_name: String) -> void:
	var image: Image = null
	for i in range(3):
		await _wait_for_capture_frame()
	for i in range(30):
		await _wait_for_capture_frame()
		var texture := root.get_viewport().get_texture()
		if texture == null:
			printerr("Viewport texture is unavailable for %s. Run this capture script without --headless." % file_name)
			capture_failed = true
			quit(1)
			return
		image = texture.get_image()
		if image != null and _image_has_content(image):
			break
	if image == null:
		printerr("Viewport image is unavailable for %s. Run this capture script without --headless." % file_name)
		capture_failed = true
		quit(1)
		return
	if not _image_has_content(image):
		printerr("Viewport image has no rendered UI content for %s." % file_name)
		capture_failed = true
		quit(1)
		return
	var path := "%s/%s.png" % [output_dir, file_name]
	var err := image.save_png(path)
	if err != OK:
		printerr("Failed to save %s: %s" % [path, error_string(err)])
		capture_failed = true
		quit(1)

func _validate_wide_root_layout(main: Node, viewport_size: Vector2i, screen_name: String) -> bool:
	if viewport_size.x < 1600:
		return true
	var root_box := main.root_box as Control
	if root_box == null:
		printerr("Root content is unavailable for %s @ %s." % [screen_name, str(viewport_size)])
		return false
	var render_scale: float = main._render_scale_for_physical_size(Vector2(viewport_size))
	var rendered_position := root_box.global_position * render_scale
	var rendered_size := root_box.size * render_scale
	var left_gutter := rendered_position.x
	var right_gutter := float(viewport_size.x) - (rendered_position.x + rendered_size.x)
	if rendered_size.x < float(viewport_size.x) * 0.88:
		printerr("Wide root uses too little width for %s @ %s: %.1f." % [screen_name, str(viewport_size), rendered_size.x])
		return false
	if absf(left_gutter - right_gutter) > 24.0:
		printerr("Wide root is not centered for %s @ %s: left %.1f, right %.1f." % [screen_name, str(viewport_size), left_gutter, right_gutter])
		return false
	return true

func _validate_landscape_battle_actions(main: Node, viewport_size: Vector2i) -> bool:
	if viewport_size.y > viewport_size.x or viewport_size.x < 1280:
		return true
	if main.battle_screen == null or main.battle_screen.end_turn_button == null:
		printerr("Battle action controls are unavailable @ %s." % str(viewport_size))
		return false
	var end_turn_button := main.battle_screen.end_turn_button as Control
	var render_scale: float = main._render_scale_for_physical_size(Vector2(viewport_size))
	var rendered_bottom := (end_turn_button.global_position.y + end_turn_button.size.y) * render_scale
	if rendered_bottom > float(viewport_size.y) - 4.0:
		printerr("End turn action is below the first screen @ %s: bottom %.1f." % [str(viewport_size), rendered_bottom])
		return false
	return true

func _wait_for_window_size(viewport_size: Vector2i) -> void:
	for i in range(16):
		await process_frame
		var actual_size := DisplayServer.window_get_size()
		if abs(actual_size.x - viewport_size.x) <= 2 and abs(actual_size.y - viewport_size.y) <= 2:
			break

func _wait_for_capture_frame() -> void:
	var draw_state := {"ready": false}
	var mark_draw := func() -> void:
		draw_state["ready"] = true
	RenderingServer.frame_post_draw.connect(mark_draw, CONNECT_ONE_SHOT)
	for i in range(16):
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

func _exercise_battle_runtime_resize(main: Node, wide_size: Vector2i, target_size: Vector2i) -> bool:
	var before: String = _battle_state_signature(main)
	for layout_size in [wide_size, target_size]:
		main.set_meta("layout_viewport_override", layout_size)
		main._apply_root_layout()
		main._on_layout_resize_timeout()
		await _wait_for_capture_frame()
		await _wait_for_capture_frame()
	var after: String = _battle_state_signature(main)
	if before != after:
		printerr("Battle state changed during responsive rebuild.\nBefore: %s\nAfter: %s" % [before, after])
		return false
	return true

func _battle_state_signature(main: Node) -> String:
	var battle = main.battle_screen
	if battle == null:
		return ""
	return JSON.stringify({
		"current_player": String(battle.current_player),
		"selected_attacker": int(battle.selected_attacker),
		"player_hp": int(battle.player.get("health", 0)),
		"player_mana": int(battle.player.get("mana", 0)),
		"player_hand": _card_ids(battle.player.get("hand", [])),
		"player_field": _card_ids(battle.player.get("field", [])),
		"opponent_hp": int(battle.opponent.get("health", 0)),
		"opponent_mana": int(battle.opponent.get("mana", 0)),
		"opponent_hand": _card_ids(battle.opponent.get("hand", [])),
		"opponent_field": _card_ids(battle.opponent.get("field", [])),
	})

func _card_ids(cards: Array) -> Array[String]:
	var ids: Array[String] = []
	for card_data in cards:
		var card: Dictionary = card_data
		ids.append(String(card.get("id", card.get("name", ""))))
	return ids

func _hand_slot_signature(cards: Array) -> String:
	var parts: Array[String] = []
	for card_data in cards:
		var card: Dictionary = card_data
		parts.append("%s:%d" % [String(card.get("id", "")), int(card.get("_hand_slot", -1))])
	return "|".join(parts)

func _seed_battle_preview_units(main: Node) -> void:
	if main.battle_screen == null:
		return
	var player_unit: Dictionary = main.cards_by_id.get("rookie_swordsman", main.cards_by_id.get("militia", {})).duplicate(true)
	var enemy_unit: Dictionary = main.cards_by_id.get("skeleton_soldier", main.cards_by_id.get("thief", main.cards_by_id.get("militia", {}))).duplicate(true)
	if player_unit.is_empty() or enemy_unit.is_empty():
		return
	player_unit["attack"] = int(player_unit.get("attack", 0)) + 1
	player_unit["can_attack"] = true
	player_unit["ember_blade_damage"] = 1
	player_unit["equipment_names"] = ["잿불 검"]
	enemy_unit["can_attack"] = false
	main.battle_screen.player["field"] = [player_unit]
	main.battle_screen.opponent["field"] = [enemy_unit]
	main.battle_screen.battle_state["combo_tag"] = "fire"
	main.battle_screen.battle_state["combo_streak"] = 2
	main.battle_screen.battle_state["combo_finisher_used"] = false
	main.battle_screen.selected_attacker = 0
	main.battle_screen._refresh_ui()
