extends SceneTree
const Storage = preload("res://src/services/game_storage.gd")
const MAIN = preload("res://src/core/Main.tscn")
var main
var width := 390
var height := 844
func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg == "--desktop":
			width = 1280
			height = 720
	call_deferred("run")
func frames() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
func capture(name: String) -> void:
	await create_timer(0.1).timeout
	RenderingServer.force_draw(false, 0.0)
	for i in range(5): await frames()
	root.get_texture().get_image().save_png(Storage.path_for(name + ".png"))
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(width, height))
	main = MAIN.instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("layout_viewport_override", Vector2i(1280, 720))
	main.set_meta("disable_timed_battle_fx", true)
	root.add_child(main)
	await frames()
	main.set_meta("layout_viewport_override", Vector2i(width, height))
	main._apply_root_layout()
	main._on_layout_resize_timeout()
	main.player_profile["learning_stage"] = 5
	main._start_new_run()
	await frames()
	var screen = main.active_screen_controller
	main.root_scroll.ensure_control_visible(screen.strategy_box)
	await capture("01_strategy_choices")
	screen._toggle_strategy_deck("human_legion")
	await capture("02_strategy_deck")
	screen._choose_strategy("human_elite")
	main.root_scroll.ensure_control_visible(screen.strategy_box)
	await capture("03_selected_elite")
	main.root_scroll.ensure_control_visible(screen.start_button)
	await capture("03_start_button")
	screen._select_race("elf")
	await frames()
	main.root_scroll.ensure_control_visible(screen.strategy_box)
	await capture("04_elf_choices")
	var evidence: Array = []
	for strategy_id in ["human_legion", "human_elite", "elf_cycle", "elf_ambush"]:
		var strategy: Dictionary = main.StartingStrategies.get_strategy(strategy_id)
		seed(20260909)
		main._init_run(strategy.race_id, strategy_id)
		main.run_flow.prepare_battle("normal")
		await frames()
		var battle = main.battle_screen
		var moves: Array[String] = []
		# Drive normal card and target-selection handlers, choosing units before equipment.
		for step in range(12):
			if main.active_screen != "battle" or battle.game_over: break
			if battle.input_locked or battle.current_player != "player":
				await create_timer(0.15).timeout
				continue
			var index := -1
			var best_score := -1000
			for i in range(battle.player.hand.size()):
				var candidate: Dictionary = battle.player.hand[i]
				if not battle._can_play_card(battle.player, candidate, "player"): continue
				var score := 0
				if battle.player.field.is_empty():
					score = 100 if candidate.type == "unit" else 0
				elif strategy_id == "human_elite":
					score = 100 if candidate.type == "equipment" else (50 if candidate.type == "spell" else 0)
				elif strategy_id == "elf_cycle":
					score = 100 if main._card_build_tags(candidate).has("draw") else 0
				else:
					score = 100 if candidate.type == "unit" else 0
				score -= int(candidate.cost)
				if score > best_score:
					best_score = score
					index = i
			if index < 0:
				var action: Dictionary = battle._recommended_action_state()
				moves.append("action:" + String(action.get("kind", "")))
				await battle._execute_recommended_action(action)
				await frames()
				continue
			var card: Dictionary = battle.player.hand[index]
			moves.append(String(card.id))
			battle.selected_hand_slot = int(card.get("_hand_slot", index))
			await battle._on_hand_card_pressed(index)
			if not battle.pending_action.is_empty() and not battle.player.field.is_empty():
				await battle._confirm_ally_target(int(battle.player.field[0].battle_unit_id))
			await frames()
		evidence.append({"strategy_id": strategy_id, "moves": moves, "turns": battle.battle_state.get("player_turn_count", 0), "mana": battle.player.mana, "field": battle.player.field.duplicate(true), "combo": battle.battle_state.get("combo_tag", ""), "metrics": battle.battle_state.get("strategy_metrics", {}).duplicate(true)})
		main.root_scroll.scroll_vertical = 0
		await capture("play_" + strategy_id)
	var file := FileAccess.open(Storage.path_for("input_scenarios.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t"))
	main._clear_screen()
	main.queue_free()
	await frames()
	print("PASS strategy UI and input scenarios")
	quit()
