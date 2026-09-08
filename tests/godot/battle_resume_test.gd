extends RefCounted

const MAIN = preload("res://src/core/Main.tscn")
const Fixture = preload("res://tests/godot/combat_strategy_test.gd")
var failures: Array[String] = []
var count := 0

func check(value: bool, message: String) -> void:
	count += 1
	if not value:
		failures.append(message)

func run() -> Dictionary:
	var tree = Engine.get_main_loop()
	var f = Fixture.new()
	var main = MAIN.instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("disable_timed_battle_fx", true)
	main.set_meta("disable_battle_ui_rerender", true)
	tree.root.add_child(main)
	main._init_run("human")
	main.run_flow.prepare_battle("normal")
	main.current_run["relic_ids"] = []
	main.current_run["active_enemy"] = main.enemy_service.enemy_by_id("necro_lord")
	var battle = main.battle_screen
	for phase in ["start", "cards", "attacks", "end"]:
		battle.player = f.side([f.unit(101, "stone_golem", 0, 100)])
		battle.player.health = 100
		battle.player.max_health = 100
		battle.player.deck = main.card_db.build_deck_from_ids(["militia", "militia", "militia", "militia", "militia"])
		battle.opponent = f.side([f.unit(201, "mercenary", 2, 100)])
		battle.opponent.mana = 1
		battle.opponent.max_mana = 1
		battle.opponent.hand = main.card_db.build_deck_from_ids(["militia"])
		battle.opponent.deck = main.card_db.build_deck_from_ids(["militia", "militia", "militia", "militia"])
		battle._reset_battle_state()
		battle.current_player = "opponent"
		battle.battle_state["boss_turn_count"] = 2
		battle.battle_state["ai_phase"] = phase
		if phase == "attacks":
			battle.opponent.field[0].can_attack = false
		battle._store_battle_snapshot()
		var snapshot: Dictionary = main.current_run.battle_snapshot.duplicate(true)
		battle._restore_battle_snapshot(snapshot)
		for frame in range(120):
			await tree.process_frame
			if String(battle.current_player) == "player":
				break
		check(String(battle.current_player) == "player", "%s phase resumes to player turn" % phase)
		check(int(battle.battle_state.get("boss_turn_count", 0)) == (3 if phase == "start" else 2), "%s phase applies boss start exactly once" % phase)
		check(int(battle.opponent.max_mana) == (2 if phase == "start" else 1), "%s phase does not repeat mana growth" % phase)
		check(battle.opponent.field.size() == (3 if phase == "start" else (2 if phase == "cards" else 1)), "%s phase only plays remaining cards" % phase)
		if phase in ["attacks", "end"]:
			check(int(battle.player.field[0].health) == 100, "%s phase never repeats completed attacks" % phase)
		check(not battle.input_locked, "%s phase restores player input" % phase)
	main._clear_screen()
	main._clear_run()
	tree.root.remove_child(main)
	main.queue_free()
	await tree.process_frame
	return {"count": count, "failures": failures}
