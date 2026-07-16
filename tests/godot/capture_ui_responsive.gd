extends SceneTree

const MAIN_SCENE := preload("res://src/core/Main.tscn")
const CAPTURE_NAMES := [
	"01_main_menu",
	"02_run_map",
	"03_battle",
	"04_card_reward",
	"05_shop",
	"06_event",
	"07_rest",
	"08_run_result",
]
const VIEWPORTS := [
	{"name": "desktop_1920x1080", "size": Vector2i(1920, 1080)},
	{"name": "landscape_1280x720", "size": Vector2i(1280, 720)},
	{"name": "landscape_1024x768", "size": Vector2i(1024, 768)},
	{"name": "portrait_800x1280", "size": Vector2i(800, 1280)},
]

var output_dir := "user://ui_captures_responsive"

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
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("layout_viewport_override", viewport_size)
	main.set_meta("disable_timed_battle_fx", true)
	root.add_child(main)
	await _wait_for_capture_frame()
	await _wait_for_capture_frame()
	main._clear_run()
	main._show_main_menu()
	await _wait_for_capture_frame()
	await _wait_for_capture_frame()

	await _capture("%s_%s" % [viewport_name, CAPTURE_NAMES[0]])

	main._start_new_run()
	await _wait_for_capture_frame()
	await _wait_for_capture_frame()
	await _capture("%s_%s" % [viewport_name, CAPTURE_NAMES[1]])

	main._enter_current_node()
	await _wait_for_capture_frame()
	await _wait_for_capture_frame()
	await _wait_for_capture_frame()
	_seed_battle_preview_units(main)
	await _wait_for_capture_frame()
	await _capture("%s_%s" % [viewport_name, CAPTURE_NAMES[2]])

	main.current_run["pending_card_reward"] = {
		"choices": main._roll_card_reward_choices(3, false),
		"gold_reward": 20,
		"bonus_relic": {},
	}
	main._show_card_reward()
	await _wait_for_capture_frame()
	await _wait_for_capture_frame()
	await _capture("%s_%s" % [viewport_name, CAPTURE_NAMES[3]])

	main.current_run["pending_shop"] = main.shop_run_service.generate_shop_state({
		"roll_card_choices": Callable(main, "_roll_card_choices"),
		"random_relic": Callable(main.relic_service, "random_relic"),
		"relic_ids": main.current_run.get("relic_ids", []),
	})
	main._show_shop()
	await _wait_for_capture_frame()
	await _wait_for_capture_frame()
	await _capture("%s_%s" % [viewport_name, CAPTURE_NAMES[4]])

	main.current_run["pending_event"] = main.event_service.roll_event()
	main.current_run["pending_card_reward"] = {}
	main._show_event()
	await _wait_for_capture_frame()
	await _wait_for_capture_frame()
	await _capture("%s_%s" % [viewport_name, CAPTURE_NAMES[5]])

	main.current_run["pending_card_reward"] = {}
	main.current_run["pending_event"] = {}
	main.current_run["pending_shop"] = {}
	main._show_rest()
	for i in range(10):
		await _wait_for_capture_frame()
	await _capture("%s_%s" % [viewport_name, CAPTURE_NAMES[6]])

	main.current_run["pending_card_reward"] = {}
	main.current_run["pending_shop"] = {}
	main.current_run["pending_event"] = {}
	main.current_run["earned_soul_stones"] = 45
	main._show_run_result(true)
	await _wait_for_capture_frame()
	await _wait_for_capture_frame()
	await _capture("%s_%s" % [viewport_name, CAPTURE_NAMES[7]])

	root.remove_child(main)
	main.queue_free()
	await _wait_for_capture_frame()

func _capture(file_name: String) -> void:
	var image: Image = null
	for i in range(3):
		await _wait_for_capture_frame()
	for i in range(30):
		await _wait_for_capture_frame()
		var texture := root.get_viewport().get_texture()
		if texture == null:
			printerr("Viewport texture is unavailable for %s. Run this capture script without --headless." % file_name)
			quit(1)
			return
		image = texture.get_image()
		if image != null and _image_has_content(image):
			break
	if image == null:
		printerr("Viewport image is unavailable for %s. Run this capture script without --headless." % file_name)
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
