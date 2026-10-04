extends RefCounted

const MAIN = preload("res://src/core/Main.tscn")
const Fixture = preload("res://tests/godot/combat_strategy_test.gd")
var count := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failures.append(message)

func state(battle) -> String:
	return JSON.stringify([battle.player, battle.opponent, battle.battle_state, battle.main.current_run, battle.current_player])

func run() -> Dictionary:
	var main = MAIN.instantiate()
	main.set_meta("disable_timed_battle_fx", true)
	main.set_meta("disable_battle_ui_rerender", true)
	main.set_meta("disable_window_mode_changes", true)
	Engine.get_main_loop().root.add_child(main)
	main.player_profile.learning_stage = 5
	main.pending_guided_run = false
	main._init_run("human")
	main.run_flow.prepare_battle("normal")
	main.current_run.relic_ids = []
	var battle = main.battle_screen
	var fixture = Fixture.new()
	battle.player = fixture.side([fixture.unit(101, "trainee_swordsman", 7, 6)])
	battle.opponent = fixture.side([fixture.unit(201, "militia", 2, 3), fixture.unit(202, "militia", 1, 8)])
	battle.current_player = "player"
	battle.input_locked = false
	battle.selected_attacker = 0
	battle._reset_battle_state()
	battle.battle_state.active_build_tags = []
	battle.selected_attacker = 0
	var before := state(battle)
	seed(128977)
	var expected_random := randi()
	seed(128977)
	var prediction: Dictionary = battle._predict_unit_attack(battle.player.field[0], battle.opponent.field[0], battle.player, battle.opponent)
	check(prediction.lethal and prediction.counter == 0, "lethal prevents counter")
	check(prediction.attacker_health == 6 and prediction.defender_health == 0, "lethal preview includes both remaining health values")
	check(prediction.overflow == 4 and prediction.mana_gain == 1, "overflow and first kill refund coexist")
	var text: String = battle._attack_prediction_text(prediction)
	check(text.contains("돌파 4") and text.contains("마나 +1"), "both payoffs appear together")
	check(battle._unit_attack_preview_text(battle.opponent.field[0], prediction).contains("6→6"), "comparison retains attacker health")
	var detail: String = battle._battle_choice_detail_text()
	check(detail.contains("미확정") and detail.contains("현재 전장"), "comparison states preview limits")
	check(detail.contains("돌파") and detail.contains("마나"), "tap-accessible information includes attack payoffs")
	check(detail.contains("위협") and detail.contains("제거"), "killing a target links to removed threat")
	battle._next_enemy_action_text()
	var choice_data: Dictionary = battle._battle_choice_data()
	check(choice_data.targets[0].after_hp == 0 and choice_data.targets[0].removed_threats.size() == 1, "structured comparison links the killed target to its removed threat")
	check(String(choice_data.targets[0].outcome).contains("돌파 4") and String(choice_data.targets[0].outcome).contains("마나 +1"), "structured comparison retains simultaneous payoffs")
	check(randi() == expected_random, "all preview calculations preserve global RNG")
	check(state(battle) == before, "all preview calculations preserve combat and save state")
	var original_field: Array = battle.player.field
	battle.player.field = []
	main.current_run.relic_ids = ["holy_shield"]
	battle.battle_state.holy_shield_ready = true
	var shield_before := state(battle)
	var shield_threats: Array = battle._enemy_threats()
	check(shield_threats.all(func(threat): return threat.damage == 0), "each independent hero threat uses current shield state")
	check(state(battle) == shield_before, "hero prediction never consumes shield")
	battle.player.field = original_field
	main.current_run.relic_ids = []
	battle.battle_state.breakthrough_mana_claimed = true
	prediction = battle._predict_unit_attack(battle.player.field[0], battle.opponent.field[0], battle.player, battle.opponent)
	check(prediction.mana_gain == 0 and prediction.overflow == 4, "claimed refund does not hide overflow")
	battle.player.field[0].attack = 2
	battle.player.field[0].health = 1
	prediction = battle._predict_unit_attack(battle.player.field[0], battle.opponent.field[0], battle.player, battle.opponent)
	check(not prediction.lethal and prediction.counter == 2, "surviving defender counters")
	check(prediction.attacker_health == 0 and prediction.defender_health == 1, "counter can kill attacker")
	var upgraded: Dictionary = main.card_db.get_card("trainee_swordsman_plus")
	battle.player.field[0].merge(upgraded, true)
	prediction = battle._predict_unit_attack(battle.player.field[0], battle.opponent.field[1], battle.player, battle.opponent)
	check(prediction.damage == battle._calculate_damage(battle.player.field[0], false, battle.player, int(upgraded.attack)), "upgraded card uses shared damage calculation")
	battle.player.field[0].ember_blade_damage = 2
	battle.opponent.field[0].id = "bone_soldier_plus"
	check(battle._battle_choice_detail_text().contains("미확정"), "equipment and death followups are not presented as final state")
	battle.selected_attacker = -1
	check(not battle._uses_tutorial_guidance(), "normal run never inherits tutorial hints from node index")
	for node_index in [0, 2, 4]:
		main.current_run.current_node_index = node_index
		before = state(battle)
		seed(38291)
		expected_random = randi()
		seed(38291)
		await battle._on_recommended_action_pressed()
		check(state(battle) == before and battle.selected_attacker == -1, "normal information never selects or executes at node %d" % node_index)
		check(randi() == expected_random, "normal information preserves gameplay RNG")
		check(not battle._can_auto_end_turn(), "information blocks automatic turn advancement")
		if is_instance_valid(battle.landscape_view): battle.landscape_view.close_detail()
		if battle.battle_detail_visible: battle._toggle_battle_details()
		for child in main.modal_layer.get_children():
			if child is AcceptDialog or child.name == "BattleChoiceDialog": child.free()
	main.current_run.guided_run = true
	main.current_run.act = 1
	for node_index in [0, 2, 4]:
		main.current_run.current_node_index = node_index
		before = state(battle)
		seed(38291)
		expected_random = randi()
		seed(38291)
		await battle._on_recommended_action_pressed()
		check(state(battle) == before and battle.selected_attacker == -1, "tutorial help never selects or executes at node %d" % node_index)
		check(randi() == expected_random, "tutorial help preserves gameplay RNG")
		if is_instance_valid(battle.landscape_view): battle.landscape_view.close_detail()
	battle._show_interaction_hint("검증 안내")
	var battle_reference: WeakRef = weakref(battle)
	main._clear_run()
	main._clear_screen()
	battle = null
	main.queue_free()
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	check(battle_reference.get_ref() == null, "pending hint timer does not retain a finished battle")
	return {"count": count, "failures": failures}
