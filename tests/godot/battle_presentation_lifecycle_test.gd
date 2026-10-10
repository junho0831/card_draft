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
	var viewport := Vector2i(390, 844) if OS.get_cmdline_user_args().has("--portrait") else Vector2i(844, 390)
	root.size = viewport
	var main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("layout_viewport_override", viewport)
	main.set_meta("disable_timed_battle_fx", true)
	root.add_child(main)
	main.touch_input_active = true
	main._init_run("human")
	main.run_flow.prepare_battle("normal")
	main.current_run.relic_ids = []
	var battle = main.battle_screen
	var f = Fixture.new()
	for change in ["complete", "rotate", "menu"]:
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
		elif change == "menu":
			await main._show_main_menu()
		var captured := false
		for frame in range(240):
			if not battle.attack_executor.busy: break
			if change == "complete" and not captured and battle.battle_fx_layer.get_child_count() > 0:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(Storage.path_for("impact.png"))
				captured = true
			await process_frame
		check(not battle.attack_executor.busy, "%s releases action wait" % change)
		if change == "complete":
			check(captured, "real attack renders impact effects")
			check(not old_session.disposed and old_session.tweens.is_empty(), "completed animation releases tweens")
			await create_timer(0.25).timeout
			check(battle._field_slot_for(battle.player, 0).scale.is_equal_approx(Vector2.ONE), "attacker returns to original scale")
		else:
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
	if viewport.x > viewport.y:
		await verify_sacrifice_focus(main, f)
	print("PASS presentation impact/completion/rotation/menu/resume" if failures.is_empty() else str(failures))
	main._clear_screen()
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func verify_sacrifice_focus(main, fixture) -> void:
	for scenario in ["power", "corpse_explosion", "corpse_explosion_manual"]:
		main.set_meta("disable_timed_battle_fx", true)
		main.pending_guided_run = false
		main.player_profile.learning_stage = 5
		main._init_run("undead")
		main.run_flow.prepare_battle("normal")
		main.current_run.relic_ids = []
		var battle = main.battle_screen
		battle.player = fixture.side([fixture.unit(101, "militia", 2, 10), fixture.unit(102, "militia", 2, 10)])
		battle.opponent = fixture.side([fixture.unit(201, "militia", 2, 10)])
		battle._reset_battle_state()
		battle.battle_state.active_build_tags = []
		battle.player.hand = [main.card_db.get_card("corpse_explosion")]
		battle.current_player = "player"
		battle.input_locked = false
		battle._ensure_hand_visual_slots()
		battle.rebuild_layout()
		await process_frame
		await process_frame
		var view = battle.landscape_view
		main.player_profile.settings.battle_auto_focus = "outside"
		await view.focus_targets([{"player": true, "hero": true}], true)
		main.set_meta("disable_timed_battle_fx", false)
		main.player_profile.settings.battle_cutscene = true
		var old_mana: int = battle.player.mana
		var cost: int = main.relic_service.modify_card_cost(main.current_run, battle.battle_state, battle.player.hand[0], "player")
		if scenario == "power":
			battle._on_race_power_pressed(102)
		else:
			battle._on_hand_card_pressed(0, 102)
		var observed_damage := false
		for frame in range(360):
			var damaged: bool = battle.opponent.health < 20 if scenario == "power" else battle.opponent.field[0].health < 10
			if damaged and not observed_damage:
				observed_damage = true
				var impact: Control = battle.opponent_hero_target if scenario == "power" else battle._field_slot_for(battle.opponent, 0)
				check(view.board_scroll.get_global_rect().encloses(impact.get_global_rect()), scenario + " enemy impact is visible when health changes")
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(Storage.path_for(scenario + "-impact.png"))
			if observed_damage and battle.inflight_actions == 0:
				break
			await process_frame
		check(observed_damage and battle.inflight_actions == 0, scenario + " real FX action finishes")
		check(battle._ally_index_by_id(102) == -1 and battle._ally_index_by_id(101) >= 0, scenario + " sacrifices only the selected ally")
		check(battle.player.discard_pile.filter(func(card): return card.id == "militia").size() == 1, scenario + " records one sacrificed card")
		if scenario == "power":
			check(battle.opponent.health == 17 and battle.battle_state.race_power_used and battle.player.mana == old_mana, "power applies three damage once and consumes one use")
		else:
			check(battle.opponent.field[0].health == 8 and battle.player.mana == old_mana - cost and battle.player.hand.is_empty(), scenario + " spends one card and one cost for two damage")
		var stopped_scroll: int = view.board_scroll.scroll_vertical
		if scenario.ends_with("manual"):
			view.session.gesture_started(Vector2.ZERO)
			view.session.gesture_ended()
		await create_timer(0.9).timeout
		if scenario.ends_with("manual"):
			check(view.board_scroll.scroll_vertical == stopped_scroll, "manual gesture cancels delayed return after sacrifice")
		else:
			check(view.board_scroll.get_global_rect().encloses(battle._field_slot_for(battle.player, 0).get_global_rect()), scenario + " returns to surviving ally after impact")
