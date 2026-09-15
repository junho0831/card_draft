extends RefCounted
const MAIN = preload("res://src/core/Main.tscn")
const Fixture = preload("res://tests/godot/combat_strategy_test.gd")
var failures: Array[String] = []
var count := 0

class DummyView extends Control:
	func refresh_labels() -> void:
		pass

class DelayedPresentation extends RefCounted:
	var disposed := false
	func focus(_targets: Array, _immediate: bool = false) -> void:
		for i in range(3):
			if disposed: return
			await Engine.get_main_loop().process_frame
	func play_attack(_result: Dictionary) -> void:
		pass
	func dispose() -> void:
		disposed = true

func check(value: bool, message: String) -> void:
	count += 1
	if not value: failures.append(message)

func reset(battle, f, actor: String = "player", scenario: String = "normal") -> void:
	battle.player = f.side([f.unit(101, "trainee_swordsman", 3, 5)])
	battle.opponent = f.side([f.unit(201, "bone_soldier", 2, 6)])
	var attacking: Dictionary = battle.player if actor == "player" else battle.opponent
	var defending: Dictionary = battle.opponent if actor == "player" else battle.player
	if scenario == "lethal":
		attacking.field[0].attack = 9
		defending.field[0].health = 2
	if scenario == "death_equipment":
		attacking.field[0].id = "bone_soldier"
		attacking.field[0].health = 1
		attacking.field[0].bone_armor_death_damage = 2
		attacking.field[0].ember_blade_damage = 1
		defending.field[0].health = 20
	battle.current_player = actor
	battle.input_locked = actor != "player"
	battle.leaving_battle = false
	battle.game_over = false
	battle.battle_finished = false
	battle.pending_action.clear()
	battle._reset_battle_state()
	battle.battle_state["active_build_tags"] = []
	battle.current_player = actor
	battle.input_locked = actor != "player"

func result(battle) -> String:
	return JSON.stringify([battle.player, battle.opponent, battle.SnapshotCodec.flags(battle.battle_state)])

func run() -> Dictionary:
	var tree = Engine.get_main_loop()
	var main = MAIN.instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("disable_timed_battle_fx", true)
	main.set_meta("disable_battle_ui_rerender", true)
	tree.root.add_child(main)
	main._init_run("human")
	main.run_flow.prepare_battle("normal")
	main.current_run.relic_ids = []
	var battle = main.battle_screen
	var f = Fixture.new()
	# Compare the unchanged rule adapters with the new validated entry point.
	for actor in ["player", "opponent"]:
		for hero in [false, true]:
			for scenario in (["normal"] if hero else ["normal", "lethal", "death_equipment"]):
				reset(battle, f, actor, scenario)
				if hero:
					if actor == "opponent": battle.player.field.clear()
					if actor == "player": await battle._resolve_player_hero_attack(0)
					else: await battle._resolve_ai_hero_attack(0)
				elif actor == "player": await battle._resolve_player_unit_attack(0, 0)
				else: await battle._resolve_unit_combat(battle.opponent, battle.player, 0, 0)
				var expected := result(battle)
				reset(battle, f, actor, scenario)
				if hero and actor == "opponent": battle.player.field.clear()
				var target := {"kind": "hero"} if hero else {"kind": "unit", "id": 201 if actor == "player" else 101}
				check(await battle.attack_executor.execute(actor, 101 if actor == "player" else 201, target), "valid attack accepted")
				check(result(battle) == expected, "rules and new entry produce identical %s hero=%s state" % [actor, hero])
				check(battle.input_locked == (actor == "opponent"), "AI attack completion never enables player input")
	reset(battle, f)
	var before := result(battle)
	check(not await battle.attack_executor.execute("player", 999, {"kind":"hero"}), "missing attacker rejected")
	check(not await battle.attack_executor.execute("player", 101, {"kind":"unit", "id":999}), "missing target rejected")
	check(result(battle) == before, "rejected requests preserve state")
	battle.opponent.field[0].is_vanguard = true
	check(not await battle.attack_executor.execute("player", 101, {"kind":"hero"}), "vanguard blocks hero attack")
	reset(battle, f)
	var dummy := DummyView.new()
	tree.root.add_child(dummy)
	battle.landscape_view = dummy
	battle.presentation.dispose()
	battle.presentation = DelayedPresentation.new()
	battle.attack_executor.execute("player", 101, {"kind":"unit", "id":201})
	check(battle.attack_executor.busy, "lock is acquired before first await")
	check(not await battle.attack_executor.execute("player", 101, {"kind":"unit", "id":201}), "duplicate request is not queued")
	await battle.prepare_to_leave()
	check(not battle.attack_executor.busy and battle.opponent.field[0].health == 3, "menu drain finishes accepted damage once")
	check(not battle.player.field[0].can_attack, "drained attack persists consumption")
	check(int(main.current_run.battle_snapshot.opponent.field[0].health) == 3, "menu drain saves completed action")
	reset(battle, f, "opponent")
	battle.player.field[0].health = 100
	battle.player.field[0].max_health = 100
	battle.opponent.field.append(f.unit(202, "militia", 2, 10))
	battle.battle_state.ai_phase = "attacks"
	battle.presentation = DelayedPresentation.new()
	battle._run_ai_turn()
	await tree.process_frame
	await battle.prepare_to_leave()
	check(battle.player.field[0].health == 98, "leaving AI turn completes only current attack")
	check(battle.opponent.field[1].can_attack, "remaining AI attacker stays unconsumed")
	var saved: Dictionary = main.current_run.battle_snapshot.duplicate(true)
	check(saved.battle_state_flags.ai_phase == "attacks", "menu retains incomplete AI attack phase")
	battle.landscape_view = null
	dummy.queue_free()
	battle._restore_battle_snapshot(saved)
	for frame in range(120):
		if battle.current_player == "player": break
		await tree.process_frame
	check(battle.current_player == "player" and battle.player.field[0].health == 96, "resume executes only the remaining AI attack")
	main._clear_screen()
	main._clear_run()
	main.queue_free()
	await tree.process_frame
	return {"count":count, "failures":failures}
