extends RefCounted
const MAIN = preload("res://src/core/Main.tscn")
const Strategies = preload("res://src/services/starting_strategy_service.gd")
const Storage = preload("res://src/services/game_storage.gd")
var count := 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failures.append(message)
func run() -> Dictionary:
	var main = MAIN.instantiate()
	main.set_meta("disable_timed_battle_fx", true)
	main.set_meta("disable_battle_ui_rerender", true)
	main.set_meta("disable_window_mode_changes", true)
	Engine.get_main_loop().root.add_child(main)
	main.pending_guided_run = false
	main.player_profile["upgrades"] = {"start_hp": 0, "start_gold": 0, "second_chance": 0}
	var strategies := Strategies.all()
	check(strategies.size() == 6, "six starting strategies load")
	var seen := {}
	for race in ["human", "elf", "undead"]:
		check(Strategies.for_race(race).size() == 2, "%s has two strategies" % race)
	for strategy in strategies:
		check(not seen.has(strategy.id), "strategy IDs are unique")
		seen[strategy.id] = true
		check(Strategies.is_valid(strategy, strategy.race_id, main.card_db, main.relic_service), "%s has ten eligible cards and a valid relic" % strategy.id)
		main._init_run(strategy.race_id, strategy.id)
		check(main.current_run.strategy_id == strategy.id and main.current_run.deck_ids == strategy.deck_ids, "%s starts with the selected deck" % strategy.id)
		check(main.current_run.relic_ids == [strategy.relic_id], "%s starts with its selected relic" % strategy.id)
		check(main.current_run.hp == 26 and main.current_run.gold == 85, "strategy preserves starting health and gold")
		check(main.current_run.starting_deck_ids == strategy.deck_ids and main.current_run.starting_relic_id == strategy.relic_id, "starting configuration is snapshotted")
		var restored: Dictionary = main.run_store.load_or_empty(Storage.run_path())
		check(restored.strategy_id == strategy.id and restored.strategy_primary_tag == strategy.primary_tag, "strategy identity survives storage")
	var before := JSON.stringify(main.current_run)
	var disk_before := FileAccess.get_file_as_string(Storage.run_path())
	main._init_run("human", "missing")
	check(JSON.stringify(main.current_run) == before and FileAccess.get_file_as_string(Storage.run_path()) == disk_before, "unknown strategy cannot replace existing run")
	main._init_run("human", "elf_cycle")
	check(JSON.stringify(main.current_run) == before, "cross-faction strategy is rejected")
	main.player_profile["learning_stage"] = 5
	main._start_new_run()
	var screen = main.active_screen_controller
	var profile_before := JSON.stringify(main.player_profile)
	screen._choose_strategy("human_elite")
	screen._toggle_strategy_deck("human_elite")
	check(main.pending_strategy_id == "human_elite" and screen.expanded_strategy_id == "human_elite", "strategy selection and deck expansion work")
	check(JSON.stringify(main.current_run) == before and JSON.stringify(main.player_profile) == profile_before, "selection does not mutate run or profile")
	check(FileAccess.get_file_as_string(Storage.run_path()) == disk_before, "selection does not save a run")
	screen._select_race("elf")
	check(main.pending_strategy_id == "elf_cycle" and screen.expanded_strategy_id.is_empty(), "changing faction resets strategy and expanded deck")
	screen._choose_strategy("human_elite")
	check(main.pending_strategy_id == "elf_cycle", "UI ignores cross-faction choices")
	screen._choose_strategy("elf_ambush")
	screen._confirm_selection()
	check(main.current_run.strategy_id == "elf_ambush", "start button uses selected strategy")
	main._init_run("elf", "elf_cycle")
	main.run_flow.prepare_battle("normal")
	var battle = main.battle_screen
	var card: Dictionary = main.card_db.get_card("forest_archer")
	check(battle._combo_candidate_tags(card)[0] == "draw", "cycle strategy starts multi-tag units with draw")
	battle.battle_state["combo_tag"] = "summon"
	battle.battle_state["combo_streak"] = 0
	battle._resolve_card_combo(card)
	check(battle.battle_state.combo_tag == "summon", "existing compatible chain takes priority over starting strategy")
	battle.battle_state["active_build_tags"] = ["summon"]
	check(battle._combo_candidate_tags(card)[0] == "summon", "inactive strategic tag never forces a chain")
	battle._record_strategy_metric("equipment")
	battle._record_strategy_metric("sacrifices")
	battle._store_battle_snapshot()
	var snapshot: Dictionary = main.current_run.battle_snapshot.duplicate(true)
	battle._restore_battle_snapshot(snapshot)
	check(battle.battle_state.strategy_metrics.equipment == 1 and battle.battle_state.strategy_metrics.sacrifices == 1, "strategy play metrics survive battle restore")
	main.current_run.deck_ids = ["small_flame", "small_flame", "small_flame", "small_flame", "small_flame", "militia", "militia", "militia", "militia", "militia"]
	main.current_run.relic_ids = ["burning_heart"]
	check(main._primary_build_tag(main._current_build_scores()) == "fire", "actual deck can change the primary build away from starting strategy")
	check(main._roll_card_reward_choices(3, false).size() == 3, "strategy runs retain three reward directions")
	main._init_run("elf")
	check(not main.current_run.has("strategy_id") and main.current_run.deck_ids == main.run_generator.starter_deck("elf"), "omitted strategy retains legacy starting configuration")
	main.run_flow.prepare_battle("normal")
	check(battle._combo_candidate_tags(card)[0] == "summon", "legacy runs retain their original chain priority")
	main.player_profile["learning_stage"] = 0
	main.pending_guided_run = true
	main._init_run("human", "human_elite")
	check(main.current_run.guided_run and not main.current_run.has("strategy_id"), "guided run ignores strategy and retains lessons")
	main._show_race_selection()
	screen = main.active_screen_controller
	check(not screen.strategy_box.visible, "guided mode hides strategy options")
	screen._set_guided_mode(false)
	check(screen.strategy_box.visible and not main.pending_guided_run, "quick-start mode reveals strategy selection")
	main._clear_run()
	main._clear_screen()
	main.queue_free()
	return {"count": count, "failures": failures}
