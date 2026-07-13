extends SceneTree

const MAIN_SCENE := preload("res://src/core/Main.tscn")

var output_dir := "user://playthrough_probe"
var report: Array[String] = []
var boss_steps := 0
var max_battle_steps := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var global_dir := ProjectSettings.globalize_path(output_dir)
	DirAccess.make_dir_recursive_absolute(global_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _wait_for_frame()
	
	var main = MAIN_SCENE.instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("layout_viewport_override", Vector2i(1280, 720))
	root.add_child(main)
	await _wait_for_frame()
	await _wait_for_frame()
	main._clear_run()
	main._show_main_menu()
	await _capture("01_main_menu")
	
	main._start_new_run()
	await _wait_for_frame()
	_note(main, "start_run")
	await _capture("02_map_start")
	
	var safety := 0
	while safety < 40:
		safety += 1
		var screen := String(main.active_screen)
		if screen == "run_result":
			_note(main, "run_result")
			await _capture("99_run_result")
			break
		match screen:
			"map":
				_note(main, "enter_node")
				main._enter_current_node(0)
				await _wait_for_frame()
				await _capture("%02d_%s" % [safety, String(main.active_screen)])
			"battle":
				await _play_battle(main, safety)
			"reward":
				await _claim_first_reward(main, safety)
			"event":
				await _resolve_event(main, safety)
			"shop":
				await _leave_shop(main, safety)
			"rest":
				await _complete_rest(main, safety)
			"message":
				_note(main, "message confirm")
				await _capture("%02d_message" % safety)
				main._complete_event_and_return()
				await _wait_for_frame()
			_:
				_note(main, "unexpected_screen:%s" % screen)
				break
	
	if safety >= 40:
		_note(main, "safety_stop")
	_note_fun_metrics(main)
	
	for line in report:
		print(line)
	print("Playthrough probe captures saved to %s" % global_dir)
	root.remove_child(main)
	main.queue_free()
	await _wait_for_frame()
	quit(0)

func _play_battle(main: Node, safety: int) -> void:
	var battle = main.battle_screen
	if battle == null:
		_note(main, "battle_missing")
		return
	_note(main, "battle_start hp=%d enemy=%s enemy_hp=%d hand=%d" % [
		int(battle.player.get("health", 0)),
		String(battle.opponent.get("name", "")),
		int(battle.opponent.get("health", 0)),
		(battle.player.get("hand", []) as Array).size(),
	])
	await _capture("%02d_battle_start" % safety)
	var steps := 0
	while String(main.active_screen) == "battle" and steps < 80:
		steps += 1
		if battle.input_locked or String(battle.current_player) != "player":
			await _wait_frames(18)
			continue
		var action: Dictionary = battle._recommended_action_state()
		_note(main, "battle_action step=%d kind=%s text=%s player_hp=%d enemy_hp=%d mana=%d hand=%d pfield=%d efield=%d" % [
			steps,
			String(action.get("kind", "")),
			String(action.get("text", "")),
			int(battle.player.get("health", 0)),
			int(battle.opponent.get("health", 0)),
			int(battle.player.get("mana", 0)),
			(battle.player.get("hand", []) as Array).size(),
			(battle.player.get("field", []) as Array).size(),
			(battle.opponent.get("field", []) as Array).size(),
		])
		battle._on_recommended_action_pressed()
		await _wait_frames(28)
		if steps == 3:
			await _capture("%02d_battle_mid" % safety)
	await _wait_frames(20)
	max_battle_steps = maxi(max_battle_steps, steps)
	var node_type := String(main.run_store.current_node(main.current_run).get("type", ""))
	if node_type == "boss":
		boss_steps += steps
	_note(main, "battle_end screen=%s steps=%d run_hp=%d" % [
		String(main.active_screen),
		steps,
		int(main.current_run.get("hp", 0)),
	])
	await _capture("%02d_battle_end_%s" % [safety, String(main.active_screen)])

func _claim_first_reward(main: Node, safety: int) -> void:
	var reward: Dictionary = main.current_run.get("pending_card_reward", {})
	var choices: Array = reward.get("choices", [])
	_note(main, "reward choices=%s gold=%d" % [str(choices), int(reward.get("gold_reward", 0))])
	await _capture("%02d_reward" % safety)
	if choices.is_empty():
		main.run_flow.advance_from_current_node(["pending_card_reward"])
	else:
		var reward_screen = main.active_screen_controller
		reward_screen._claim_card_reward(String(choices[0]))
	await _wait_for_frame()

func _resolve_event(main: Node, safety: int) -> void:
	var event_data: Dictionary = main.current_run.get("pending_event", {})
	var options: Array = event_data.get("options", [])
	var effect := "leave"
	for option in options:
		var option_data: Dictionary = option
		if String(option_data.get("effect", "")) == "leave":
			effect = "leave"
			break
		effect = String(option_data.get("effect", effect))
	_note(main, "event id=%s effect=%s" % [String(event_data.get("id", "")), effect])
	await _capture("%02d_event" % safety)
	main.active_screen_controller._resolve_event_option(effect)
	await _wait_for_frame()

func _leave_shop(main: Node, safety: int) -> void:
	_note(main, "shop leave gold=%d" % int(main.current_run.get("gold", 0)))
	await _capture("%02d_shop" % safety)
	main.active_screen_controller._leave_shop()
	await _wait_for_frame()

func _complete_rest(main: Node, safety: int) -> void:
	_note(main, "rest complete hp=%d/%d" % [int(main.current_run.get("hp", 0)), int(main.current_run.get("max_hp", 0))])
	await _capture("%02d_rest" % safety)
	main._complete_rest()
	await _wait_for_frame()

func _note(main: Node, text: String) -> void:
	report.append("%s | screen=%s node=%d result=%s deck=%d relics=%d" % [
		text,
		String(main.active_screen),
		int(main.current_run.get("current_node_index", -1)),
		String(main.current_run.get("result", "")),
		(main.current_run.get("deck_ids", []) as Array).size(),
		(main.current_run.get("relic_ids", []) as Array).size(),
	])

func _note_fun_metrics(main: Node) -> void:
	var scores: Dictionary = main._current_build_scores()
	var active: Array = main._active_build_tags(scores)
	var trigger_count := 0
	var relic_trigger_count := 0
	if main.battle_screen != null:
		trigger_count = int(main.battle_screen.battle_state.get("build_trigger_count", 0))
		relic_trigger_count = int(main.battle_screen.battle_state.get("relic_trigger_count", 0))
	report.append("fun_metrics active_builds=%s build_scores=%s build_triggers=%d relic_triggers=%d boss_steps=%d max_battle_steps=%d relics=%d result=%s" % [
		str(active),
		str(scores),
		trigger_count,
		relic_trigger_count,
		boss_steps,
		max_battle_steps,
		(main.current_run.get("relic_ids", []) as Array).size(),
		String(main.current_run.get("result", "")),
	])
	if active.is_empty():
		report.append("fun_warning:no_active_build")
	if trigger_count <= 0:
		report.append("fun_warning:no_build_trigger_seen")

func _capture(file_name: String) -> void:
	var image: Image = null
	for i in range(20):
		await _wait_for_frame()
		var texture := root.get_viewport().get_texture()
		if texture != null:
			image = texture.get_image()
			if image != null and _image_has_content(image):
				break
	if image == null or not _image_has_content(image):
		report.append("capture_failed:%s" % file_name)
		return
	image.save_png("%s/%s.png" % [output_dir, file_name])

func _wait_frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _wait_for_frame() -> void:
	var draw_state := {"ready": false}
	var mark_draw := func() -> void:
		draw_state["ready"] = true
	RenderingServer.frame_post_draw.connect(mark_draw, CONNECT_ONE_SHOT)
	for i in range(12):
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
	for x_index in range(10):
		for y_index in range(8):
			var x := int(float(width - 1) * (float(x_index) + 0.5) / 10.0)
			var y := int(float(height - 1) * (float(y_index) + 0.5) / 8.0)
			var color := image.get_pixel(x, y)
			var luma := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
			min_luma = minf(min_luma, luma)
			max_luma = maxf(max_luma, luma)
	return max_luma - min_luma > 0.02
