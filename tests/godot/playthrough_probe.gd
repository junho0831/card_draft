extends SceneTree

const TestStorage = preload("res://src/services/game_storage.gd")

const MAIN_SCENE := preload("res://src/core/Main.tscn")

var output_dir := TestStorage.path_for("playthrough_probe")
var report: Array[String] = []
var boss_steps := 0
var max_battle_steps := 0
var vanguards_seen := 0
var breakthroughs_triggered := 0
var breakthrough_damage := 0
var headless := false
var probe_failed := false
var cases: Array[Dictionary] = []
var battle_metrics: Array[Dictionary] = []
var matrix_strategy := ""
var case_seed := 0
var matrix_main: Node
var matrix_profile: Dictionary = {}

func _init() -> void:
	if not TestStorage.prepare_test_directory():
		quit(2)
		return
	call_deferred("_run_all")

func _run_all() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--strategy="):
			matrix_strategy = arg.trim_prefix("--strategy=")
	if not matrix_strategy.is_empty():
		var strategy: Dictionary = preload("res://src/services/starting_strategy_service.gd").get_strategy(matrix_strategy)
		if strategy.is_empty():
			quit(2)
			return
		var checkpoint_path := TestStorage.path_for("progress.json")
		if FileAccess.file_exists(checkpoint_path):
			var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(checkpoint_path))
			cases.assign(saved.get("cases", []))
			battle_metrics.assign(saved.get("battles", []))
			probe_failed = bool(saved.get("failed", false))
		for seed_index in range(10):
			for elite in [false, true]:
				case_seed = 20260909 + seed_index
				if cases.any(func(entry): return int(entry.get("seed", 0)) == case_seed and bool(entry.get("elite", false)) == elite):
					continue
				await _run_case(String(strategy.race_id), elite)
		var file := FileAccess.open(TestStorage.path_for("playthrough_metrics.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"cases": cases, "battles": battle_metrics, "failed": probe_failed}, "\t"))
		var wins := cases.filter(func(entry): return entry.result == "win").size()
		print("STRATEGY RESULT: ", matrix_strategy, " wins=", wins, "/", cases.size(), " stalled=", probe_failed)
		quit(1 if probe_failed or wins == 0 else 0)
		return
	var index := 0
	for race in ["human", "elf", "undead"]:
		if OS.get_cmdline_user_args().has("--elf-only") and race != "elf":
			continue
		for elite in ([false] if OS.get_cmdline_user_args().has("--guided") else [false, true]):
			seed(20260908 + index)
			index += 1
			await _run_case(race, elite)
	var file := FileAccess.open(TestStorage.path_for("playthrough_metrics.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"cases": cases, "battles": battle_metrics, "failed": probe_failed}, "\t"))
	print("PLAYTHROUGH CASES: ", JSON.stringify(cases))
	quit(1 if probe_failed else 0)

func _run_case(race: String, elite: bool) -> void:
	headless = DisplayServer.get_name() == "headless"
	var global_dir := ProjectSettings.globalize_path(output_dir)
	DirAccess.make_dir_recursive_absolute(global_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _wait_for_frame()
	
	var main = matrix_main if is_instance_valid(matrix_main) else MAIN_SCENE.instantiate()
	var newly_created: bool = not main.is_inside_tree()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("layout_viewport_override", Vector2i(1280, 720))
	main.set_meta("disable_timed_battle_fx", true)
	main.set_meta("disable_battle_ui_rerender", headless)
	if newly_created:
		root.add_child(main)
		if not matrix_strategy.is_empty():
			matrix_main = main
			matrix_profile = main.player_profile.duplicate(true)
	elif not matrix_strategy.is_empty():
		main.player_profile = matrix_profile.duplicate(true)
	await _wait_for_frame()
	await _wait_for_frame()
	main.player_profile["settings"]["battle_cutscene"] = false
	main.player_profile["settings"]["fast_ai"] = true
	main._clear_run()
	if matrix_strategy.is_empty():
		main._show_main_menu()
	await _capture("01_main_menu")
	
	main.player_profile["learning_stage"] = 0 if OS.get_cmdline_user_args().has("--guided") else 5
	if matrix_strategy.is_empty():
		main._start_new_run()
	else:
		main.pending_guided_run = false
	await _wait_for_frame()
	_note(main, "start_run")
	await _capture("02_race_selection")
	if String(main.active_screen) == "race_selection" or not matrix_strategy.is_empty():
		if not matrix_strategy.is_empty():
			seed(case_seed)
		main._init_run(race, matrix_strategy)
		await _wait_for_frame()
		await _wait_for_frame()
	_note(main, "race_selected:%s elite=%s" % [race, elite])
	await _capture("03_map_start")
	if String(main.active_screen) != "map":
		_note(main, "race_selection_failed")
		probe_failed = true
	
	var node_count := 0
	for act in main.current_run.get("map_nodes", []):
		node_count += act.get("nodes", []).size()
	var safety_limit := node_count * 6 + 10
	var safety := 0
	var completed_run := false
	while safety < safety_limit:
		safety += 1
		var screen := String(main.active_screen)
		if screen == "run_result":
			_note(main, "run_result")
			await _capture("99_run_result")
			completed_run = true
			break
		match screen:
			"map":
				_note(main, "enter_node")
				var node_index := int(main.current_run.get("current_node_index", 0))
				var act: Dictionary = main._current_act()
				var layer: Array = act.get("nodes", [])[node_index]
				main._enter_current_node(layer.find("elite") if elite and layer.has("elite") else 0)
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
				probe_failed = true
				break
	
	if safety >= safety_limit:
		_note(main, "safety_stop")
		probe_failed = true
	if not completed_run:
		probe_failed = true
	_note_fun_metrics(main)
	
	cases.append({"strategy_id": matrix_strategy, "seed": case_seed, "race": race, "elite": elite, "result": String(main.current_run.get("result", "")), "nodes": main.current_run.get("visited_nodes", []).size(), "hp": main.current_run.get("hp", 0)})
	if not completed_run:
		for line in report:
			print(line)
	report.clear()
	if not matrix_strategy.is_empty():
		var checkpoint := FileAccess.open(TestStorage.path_for("progress.json"), FileAccess.WRITE)
		checkpoint.store_string(JSON.stringify({"cases": cases, "battles": battle_metrics, "failed": probe_failed}))
	print("Playthrough probe captures saved to %s" % global_dir)
	if matrix_strategy.is_empty():
		root.remove_child(main)
		main.queue_free()
	else:
		main._clear_screen()
	await _wait_for_frame()

func _play_battle(main: Node, safety: int) -> void:
	var battle = main.battle_screen
	if battle == null:
		_note(main, "battle_missing")
		probe_failed = true
		return
	_note(main, "battle_start hp=%d enemy=%s enemy_hp=%d hand=%d" % [
		int(battle.player.get("health", 0)),
		String(battle.opponent.get("name", "")),
		int(battle.opponent.get("health", 0)),
		(battle.player.get("hand", []) as Array).size(),
	])
	for unit_variant in battle.opponent.get("field", []):
		if bool(Dictionary(unit_variant).get("is_vanguard", false)):
			vanguards_seen += 1
			break
	await _capture("%02d_battle_start" % safety)
	var steps := 0
	var initial_hp := int(battle.player.get("health", 0))
	var deadline := Time.get_ticks_msec() + 60000
	var wait_ticks := 0
	while String(main.active_screen) == "battle" and steps < 160 and Time.get_ticks_msec() < deadline:
		if battle.input_locked or String(battle.current_player) != "player":
			wait_ticks += 1
			if wait_ticks % 20 == 0:
				_note(main, "battle_wait tick=%d current_player=%s input_locked=%s player_hp=%d enemy_hp=%d pfield=%d efield=%d ohand=%d omana=%d" % [
					wait_ticks,
					String(battle.current_player),
					str(battle.input_locked),
					int(battle.player.get("health", 0)),
					int(battle.opponent.get("health", 0)),
					(battle.player.get("field", []) as Array).size(),
					(battle.opponent.get("field", []) as Array).size(),
					(battle.opponent.get("hand", []) as Array).size(),
					int(battle.opponent.get("mana", 0)),
				])
			await _wait_frames(3 if headless else 18)
			continue
		wait_ticks = 0
		steps += 1
		if not battle.pending_action.is_empty():
			await _choose_ally(battle)
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
		await battle._execute_recommended_action(action)
		await _wait_frames(4 if headless else 28)
		if steps == 3:
			await _capture("%02d_battle_mid" % safety)
	await _wait_frames(3 if headless else 20)
	battle_metrics.append({"strategy_id": matrix_strategy, "seed": case_seed, "metrics": battle.battle_state.get("strategy_metrics", {}).duplicate(true), "first_turn_win": battle.battle_state.get("player_turn_count", 0) == 1 and int(battle.opponent.get("health", 0)) <= 0, "race": main._current_race_id(), "tier": battle.battle_tier, "enemy": battle.opponent.get("name", ""), "turns": battle.battle_state.get("player_turn_count", 0), "finisher": battle.battle_state.get("combo_finisher_used", false), "hp_lost_net": initial_hp - int(battle.player.get("health", 0)), "actions": steps})
	max_battle_steps = maxi(max_battle_steps, steps)
	var node_type := String(main.run_store.current_node(main.current_run).get("type", ""))
	if node_type == "boss":
		boss_steps += steps
	breakthroughs_triggered += int(battle.battle_state.get("breakthrough_count", 0))
	breakthrough_damage += int(battle.battle_state.get("breakthrough_damage", 0))
	_note(main, "battle_end screen=%s steps=%d run_hp=%d" % [
		String(main.active_screen),
		steps,
		int(main.current_run.get("hp", 0)),
	])
	if String(main.active_screen) == "battle":
		probe_failed = true
		_note(main, "battle_stalled current_player=%s input_locked=%s enemy_hp=%d player_hp=%d hand=%d pfield=%d efield=%d" % [
			String(battle.current_player),
			str(battle.input_locked),
			int(battle.opponent.get("health", 0)),
			int(battle.player.get("health", 0)),
			(battle.player.get("hand", []) as Array).size(),
			(battle.player.get("field", []) as Array).size(),
			(battle.opponent.get("field", []) as Array).size(),
		])
	await _capture("%02d_battle_end_%s" % [safety, String(main.active_screen)])

func _claim_first_reward(main: Node, safety: int) -> void:
	var reward: Dictionary = main.current_run.get("pending_card_reward", {})
	var choices: Array = reward.get("choices", [])
	_note(main, "reward choices=%s gold=%d" % [str(choices), int(reward.get("gold_reward", 0))])
	await _capture("%02d_reward" % safety)
	var reward_screen = main.active_screen_controller
	var relics: Array = reward.get("relic_choices", [])
	if not relics.is_empty():
		reward_screen._select_relic_reward(String(relics[0].get("id", "")))
		reward_screen = main.active_screen_controller
	if choices.is_empty():
		reward_screen._skip_card_reward()
	else:
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
	main.run_flow.rest_heal()
	await _wait_for_frame()

func _note(main: Node, text: String) -> void:
	var line := "%s | screen=%s node=%d result=%s deck=%d relics=%d" % [
		text,
		String(main.active_screen),
		int(main.current_run.get("current_node_index", -1)),
		String(main.current_run.get("result", "")),
		(main.current_run.get("deck_ids", []) as Array).size(),
		(main.current_run.get("relic_ids", []) as Array).size(),
	]
	report.append(line)

func _note_fun_metrics(main: Node) -> void:
	var scores: Dictionary = main._current_build_scores()
	var active: Array = main._active_build_tags(scores)
	var trigger_count := 0
	var relic_trigger_count := 0
	if main.battle_screen != null:
		trigger_count = int(main.battle_screen.battle_state.get("build_trigger_count", 0))
		relic_trigger_count = int(main.battle_screen.battle_state.get("relic_trigger_count", 0))
	report.append("fun_metrics active_builds=%s build_scores=%s build_triggers=%d relic_triggers=%d vanguards=%d breakthroughs=%d breakthrough_damage=%d boss_steps=%d max_battle_steps=%d relics=%d result=%s" % [
		str(active),
		str(scores),
		trigger_count,
		relic_trigger_count,
		vanguards_seen,
		breakthroughs_triggered,
		breakthrough_damage,
		boss_steps,
		max_battle_steps,
		(main.current_run.get("relic_ids", []) as Array).size(),
		String(main.current_run.get("result", "")),
	])
	if active.is_empty():
		report.append("fun_warning:no_active_build")
	if trigger_count <= 0:
		report.append("fun_warning:no_build_trigger_seen")
	if vanguards_seen <= 0:
		report.append("fun_warning:no_enemy_vanguard_seen")
	if breakthroughs_triggered <= 0:
		report.append("fun_warning:no_breakthrough_triggered")

func _capture(file_name: String) -> void:
	if headless:
		report.append("capture_skipped:%s" % file_name)
		return
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
	if headless:
		count = mini(count, 4)
	for i in range(count):
		await process_frame

func _wait_for_frame() -> void:
	if headless:
		await process_frame
		return
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

func _choose_ally(battle) -> void:
	var sacrifice := String(battle.pending_action.get("kind", "")) == "power" or String(battle.pending_action.get("card_id", "")).begins_with("corpse_explosion")
	var best_id := -1
	var best_score := -100000
	for unit in battle.player.field:
		var score := int(unit.get("attack", 0)) * 3 + (10 if bool(unit.get("can_attack", false)) else 0)
		if sacrifice:
			score = -int(unit.get("attack", 0)) - int(unit.get("health", 0)) + (10 if String(unit.get("id", "")).trim_suffix("_plus") == "bone_soldier" else 0) + int(unit.get("bone_armor_death_damage", 0)) * 5
		if score > best_score:
			best_score = score
			best_id = int(unit.get("battle_unit_id", -1))
	if best_id >= 0:
		await battle._confirm_ally_target(best_id)
	else:
		battle._cancel_ally_selection()
