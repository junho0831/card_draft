extends RefCounted
const MAIN = preload("res://src/core/Main.tscn")
const Lesson = preload("res://src/services/onboarding_service.gd")
const Reward = preload("res://src/ui/screens/reward_screen.gd")
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
	main.player_profile["learning_stage"] = 0
	main._start_new_run()
	check(main.pending_guided_run, "new player defaults to guided run")
	main._init_run("human")
	check(main.current_run.map_nodes[0].nodes == [["battle"], ["lesson_reward"], ["battle"], ["rest"], ["boss"]], "first act uses five lesson stages")
	check(main.current_run.relic_ids.is_empty(), "relics wait until after the first boss")
	for id in main.current_run.deck_ids:
		check(main.card_db.get_card(id).type == "unit", "first deck has simple units only")
	main.run_flow.prepare_battle("normal")
	var battle = main.battle_screen
	check(not battle._can_use_race_power(), "power locked in first lesson")
	check(battle.opponent.field[0].attack == 1 and battle.opponent.field[0].health == 1, "practice vanguard has simple 1/1 stats")
	check(not battle._combo_card_preview(main.card_db.get_card("militia")).contains("연계"), "first card preview teaches summoning only")
	check(battle._combo_candidate_tags(main.card_db.get_card("militia")).is_empty(), "combos wait until lesson three")
	check(battle._create_battle_objective().is_empty(), "no optional challenges distract from learning")
	check(battle._recommended_action_text() == "도움 보기", "first battle uses help")
	var before_help: String = JSON.stringify([battle.player, battle.opponent, battle.selected_attacker, main.current_run])
	await battle._on_recommended_action_pressed()
	check(JSON.stringify([battle.player, battle.opponent, battle.selected_attacker, main.current_run]) == before_help, "help never spends cards mana or advances turn")
	battle.player.hand = [main.card_db.get_card("knight_spearman")]
	battle._ensure_hand_visual_slots()
	var card_index: int = 0
	await battle._on_hand_card_pressed(card_index)
	check(main.current_run.get("first_play_actions", {}).get("summoned", false), "actual summon records first action")
	battle.player.field[0].can_attack = true
	battle._on_player_unit_pressed(0)
	check(not main.current_run.first_play_actions.get("unit_attacked", false), "selection is not a completed attack")
	await battle._execute_player_unit_attack(0, 0)
	check(main.current_run.first_play_actions.get("unit_attacked", false), "actual attack records learning")
	check(main.current_run.first_play_actions.get("vanguard_defeated", false), "vanguard defeat is recorded")
	main._save_run()
	var first_saved: Dictionary = main.run_store.load_or_empty(preload("res://src/services/game_storage.gd").run_path())
	check(first_saved.first_play_actions == main.current_run.first_play_actions, "first actions survive run storage")
	main.current_run = first_saved
	main.run_flow.continue_run()
	check(main.current_run.first_play_actions.get("unit_attacked", false) and battle.opponent.field.is_empty(), "resume restores board and actual action record")
	battle.game_over = true
	check(battle._current_battle_guidance_text() == "전투 종료", "early victory never forces remaining exercises")
	battle.game_over = false
	main.current_run.erase("first_play_actions")
	battle.selected_attacker = -1
	battle.player.hand.clear()
	battle.player.field.clear()
	check(battle._first_play_guidance().contains("턴 종료"), "legacy empty board gives possible action")
	before_help = JSON.stringify([battle.player, battle.opponent, battle.current_player])
	await battle._on_recommended_action_pressed()
	check(JSON.stringify([battle.player, battle.opponent, battle.current_player]) == before_help, "end-turn help does not end turn")
	main.current_run.active_enemy = {}
	main.current_run.battle_snapshot = {}
	main.run_flow.advance_from_current_node()
	check(main.player_profile.learning_stage == 1, "completed lesson persists in profile")
	main.run_flow.enter_current_node()
	check(main.active_screen == "reward", "second node opens equipment choice")
	for id in main.current_run.pending_card_reward.choices:
		check(main.card_db.get_card(id).type == "equipment", "lesson choices are valid equipment")
	main._save_run()
	var saved: Dictionary = main.run_store.load_or_empty(preload("res://src/services/game_storage.gd").run_path())
	main.current_run = saved
	main.run_flow.continue_run()
	check(main.active_screen == "reward", "lesson reward resumes without advancing")
	var screen = Reward.new(main)
	screen._skip_card_reward()
	check(main.current_run.deck_ids.has("training_sword") and main.current_run.current_node_index == 2, "recommendation grants equipment and advances exactly once")
	main.run_flow.prepare_battle("normal")
	check(battle.player.hand.any(func(card): return card.type == "equipment"), "second battle guarantees equipment in opening hand")
	check(not battle._can_use_race_power(), "power remains locked in second battle")
	check(main.current_run.lesson_equipment_id == "training_sword", "chosen lesson equipment is retained")
	battle.player.field.clear()
	check(battle._equipment_lesson_guidance().contains("먼저 유닛"), "equipment lesson first asks for an ally")
	battle.player.field = [preload("res://tests/godot/combat_strategy_test.gd").new().unit(501)]
	battle.player.hand = [main.card_db.get_card("training_sword")]
	battle.player.mana = 0
	battle._ensure_hand_visual_slots()
	check(battle._equipment_lesson_guidance().contains("마나가 부족"), "equipment lesson explains insufficient mana")
	battle.player.mana = 10
	battle.current_player = "player"
	battle.input_locked = false
	check(battle._equipment_lesson_guidance().contains("강화할 아군"), "equipment lesson explains target selection")
	battle._on_hand_card_pressed(0)
	battle._cancel_ally_selection()
	check(not Dictionary(main.current_run.get("lesson_actions", {})).get("equipped", false), "cancelling target selection does not count as learning equipment")
	battle._on_hand_card_pressed(0)
	battle._confirm_ally_target(501)
	check(main.current_run.lesson_actions.get("equipped", false), "successful equipment use advances contextual lesson")
	check(battle._equipment_lesson_guidance().contains("유닛 두 장"), "equipment use introduces the next combo exercise")
	battle._resolve_card_combo(main.card_db.get_card("militia"))
	battle._resolve_card_combo(main.card_db.get_card("militia"))
	check(main.current_run.lesson_actions.get("combo", false), "actual two-card chain completes combo exercise")
	main._save_run()
	var learned: Dictionary = main.run_store.load_or_empty(preload("res://src/services/game_storage.gd").run_path())
	check(learned.lesson_actions.equipped and learned.lesson_actions.combo, "actual learning actions survive save and reload")
	check(battle._equipment_lesson_guidance().contains("모두 사용"), "completed exercises show completion guidance")
	main.current_run.current_node_index = 4
	main.run_flow._unlock_lesson_content()
	check(not main.current_run.has("lesson_reserve") and main.current_run.deck_ids.has("fireball"), "boss lesson unlocks remaining starter cards")
	var size: int = main.current_run.deck_ids.size()
	main.run_flow._unlock_lesson_content()
	check(main.current_run.deck_ids.size() == size, "unlocking cards is idempotent")
	main.current_run.active_enemy = {}
	main.current_run.battle_snapshot = {}
	main.run_flow.advance_from_current_node()
	check(main.current_run.act == 2 and main.player_profile.learning_stage == 5, "boss completion opens full play and saves mastery")
	check(main.current_run.relic_ids.has("knight_banner"), "starting relic arrives in act two")
	main._start_new_run()
	check(not main.pending_guided_run, "returning player defaults to full play")
	main._init_run("elf")
	check(not main.current_run.get("guided_run", false), "quick start retains normal route")
	check(Lesson.stage({}) == 5, "legacy runs keep all mechanics unlocked")
	check(Lesson.description({"guided_run": true, "lesson_resume_stage": 3, "current_node_index": 0}).is_empty(), "learned lessons are not explained again")
	main._clear_run()
	main._clear_screen()
	main.queue_free()
	return {"count": count, "failures": failures}
