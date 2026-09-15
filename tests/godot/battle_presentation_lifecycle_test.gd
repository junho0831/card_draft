extends SceneTree
const Storage = preload("res://src/services/game_storage.gd")
const Fixture = preload("res://tests/godot/combat_strategy_test.gd")
var failures: Array[String] = []
func _initialize():
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")
func check(ok: bool, message: String):
	if not ok: failures.append(message)
func run():
	root.size = Vector2i(844, 390)
	var main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("layout_viewport_override", Vector2i(844, 390))
	main.set_meta("disable_timed_battle_fx", true)
	root.add_child(main)
	main.touch_input_active = true
	main._init_run("human")
	main.run_flow.prepare_battle("normal")
	main.current_run.relic_ids = []
	var battle = main.battle_screen
	var f = Fixture.new()
	for change in ["rotate", "menu"]:
		battle.leaving_battle = false
		main.active_screen = "battle"
		battle.player = f.side([f.unit(101, "trainee_swordsman", 3, 10)])
		battle.opponent = f.side([f.unit(201, "militia", 2, 10)])
		battle._reset_battle_state()
		battle.battle_state.active_build_tags = []
		battle.rebuild_layout()
		await process_frame
		await process_frame
		main.set_meta("disable_timed_battle_fx", false)
		main.player_profile.settings.battle_cutscene = true
		var old_session = battle.presentation
		battle.attack_executor.execute("player", 101, {"kind":"unit", "id":201})
		await create_timer(0.05).timeout
		check(battle.attack_executor.busy, "real animation keeps action owned")
		if change == "rotate":
			battle.rebuild_layout()
		else:
			await main._show_main_menu()
		for frame in range(120):
			if not battle.attack_executor.busy: break
			await process_frame
		check(not battle.attack_executor.busy, "%s releases action wait" % change)
		check(old_session.disposed and old_session.tweens.is_empty(), "%s disposes original session" % change)
		check(battle.opponent.field[0].health == 7 and battle.player.field[0].health == 8, "%s commits damage exactly once" % change)
		check(not battle.player.field[0].can_attack, "%s consumes attack" % change)
		if change == "menu":
			check(main.active_screen == "main_menu", "menu appears after commit")
			var saved: Dictionary = main.current_run.battle_snapshot.duplicate(true)
			check(saved.opponent.field[0].health == 7, "menu saves completed action")
			main.active_screen = "battle"
			main.set_meta("disable_timed_battle_fx", true)
			battle._restore_battle_snapshot(saved)
			await process_frame
			check(not battle.input_locked and not battle.player.field[0].can_attack, "resume does not replay attack or keep lock")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Storage.path_for("resumed.png"))
	print("PASS presentation rotation/menu/resume" if failures.is_empty() else str(failures))
	main._clear_screen()
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
