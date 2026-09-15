extends SceneTree
const Storage = preload("res://src/services/game_storage.gd")
const Fixture = preload("res://tests/godot/combat_strategy_test.gd")
var failures: Array[String] = []
func _initialize():
	if not Storage.prepare_test_directory(): quit(2); return
	call_deferred("run")
func check(ok: bool, message: String):
	if not ok: failures.append(message)
func run():
	var orphan_count_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	root.size = Vector2i(640, 360)
	var main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("layout_viewport_override", Vector2i(640, 360))
	main.set_meta("disable_timed_battle_fx", true)
	root.add_child(main)
	main.touch_input_active = true
	main._init_run("human")
	main._show_map()
	await process_frame
	await process_frame
	var map = main.active_screen_controller
	check(is_instance_valid(map.screen_action_dock), "landscape map docks progress action")
	if is_instance_valid(map.screen_action_dock):
		var rect: Rect2 = map.screen_action_dock.get_global_rect()
		check(rect.position.y >= 0 and rect.end.y <= 361, "map action stays inside short viewport")
		main.root_scroll.scroll_vertical = 500
		await process_frame
		check(map.screen_action_dock.get_global_rect() == rect, "scrolling map does not move action dock")
	main.run_flow.prepare_battle("normal")
	var battle = main.battle_screen
	var f = Fixture.new()
	for scenario in [[true, true], [false, true], [false, false]]:
		var has_guard: bool = scenario[0]
		battle.player = f.side([f.unit(101, "trainee_swordsman", 3, 10)])
		battle.opponent = f.side([f.unit(201, "militia", 2, 10)] if has_guard else [])
		battle.player.hand = [main.card_db.get_card("militia")] if scenario[1] else []
		battle.current_player = "player"
		battle.input_locked = false
		battle.selected_attacker = -1
		battle.rebuild_layout()
		await process_frame
		await process_frame
		await battle.landscape_view.focus_targets([{"player":true,"hero":true}], true)
		var before := JSON.stringify([battle.player, battle.opponent])
		await battle._on_player_unit_pressed(0)
		await process_frame
		var target: Control = battle._card_action_field_slot(false, 0) if has_guard else battle._hero_target_for_player(false)
		var viewport: Rect2 = battle.landscape_view.board_scroll.get_global_rect()
		check(viewport.encloses(target.get_global_rect()), "selection reveals legal target guard=%s" % has_guard)
		check(JSON.stringify([battle.player,battle.opponent]) == before, "selection does not attack guard=%s" % has_guard)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Storage.path_for("target-visible.png"))
	main._clear_screen()
	main.queue_free()
	await process_frame
	await process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == orphan_count_before, "rebuilding and closing battle leaves no orphan nodes")
	print("PASS map dock, attack target navigation and node cleanup" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
