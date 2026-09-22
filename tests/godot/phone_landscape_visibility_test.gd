extends SceneTree
## Actual layout geometry at the connected phone's aspect ratio, without user saves.
const Storage = preload("res://src/services/game_storage.gd")
var failures: Array[String] = []

func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func settle() -> void:
	for i in range(12):
		await process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Storage.path_for(name + ".png"))

func run() -> void:
	root.size = Vector2i(802, 390)
	var main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("layout_viewport_override", Vector2i(802, 390))
	main.set_meta("disable_timed_battle_fx", true)
	root.add_child(main)
	main.touch_input_active = true
	main._apply_root_layout()
	main._clear_run()
	await main._show_main_menu()
	await settle()
	check(main.root_box.get_combined_minimum_size().y <= main.root_scroll.size.y, "home actions fit without vertical scrolling")
	await capture("home")
	main._start_new_run()
	await settle()
	var selection = main.active_screen_controller
	var visible_area: Rect2 = main.root_scroll.get_global_rect()
	check(visible_area.encloses(selection.learning_toggle.get_global_rect()), "learning mode is visible above choices")
	for id in main._valid_race_ids():
		check(visible_area.encloses(selection.race_buttons[id].get_global_rect()), "%s choice button visible without scrolling" % id)
	check(selection.fixed_footer.size.y <= 90, "start dock leaves space for choices")
	check(selection.start_button.get_global_rect().end.y <= root.size.y, "start button fits screen")
	await capture("race-selection")
	selection._select_race("elf")
	check(selection.selected_race_id == "elf", "race remains selectable")
	selection._set_guided_mode(false)
	await settle()
	check(selection.strategy_box.is_visible_in_tree(), "normal-run strategies remain accessible")
	selection._set_guided_mode(true)
	selection._confirm_selection()
	await settle()
	var map = main.active_screen_controller
	check(main.root_scroll.get_global_rect().encloses(map.map_scroll.get_global_rect()), "map route is fully visible on entry: %s inside %s" % [map.map_scroll.get_global_rect(), main.root_scroll.get_global_rect()])
	await capture("map")
	main._enter_current_node()
	await settle()
	var battle = main.battle_screen
	var view = battle.landscape_view
	check(view != null, "uses landscape battle")
	if view != null:
		check(view.board_scroll.scroll_vertical == 0, "battle entry starts at enemy lane")
		check(view.board_scroll.get_global_rect().encloses(battle.opponent_hero_target.get_global_rect()), "enemy hero fully visible on entry")
		if not battle.opponent.field.is_empty():
			check(view.board_scroll.get_global_rect().encloses(battle._card_action_field_slot(false, 0).get_global_rect()), "enemy vanguard fully visible on entry")
		await capture("battle-entry")
		check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(view.ally_lane_button.get_global_rect()), "lane navigation stays on screen")
		view.show_card(0)
		await settle()
		var viewer = view.card_dialog.find_child("CardInspectionView", true, false)
		check(viewer != null and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(viewer.get_global_rect()), "whole inspection card fits in viewport")
		check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(view.confirm_button.get_global_rect()), "card use stays visible")
		await capture("card-detail")
		var before: int = battle.player.hand.size()
		view.close_detail()
		check(battle.player.hand.size() == before, "closing card detail does not play it")
		await view.focus_targets([{"player": true, "hero": true}], true)
		check(view.board_scroll.scroll_vertical > 0, "action focus can still reach ally lane")
		await view.focus_targets([{"player": false, "hero": true}], true)
		check(view.board_scroll.scroll_vertical == 0, "action focus can return to enemy lane")
	print("PASS phone landscape visibility" if failures.is_empty() else str(failures))
	main._clear_screen()
	main.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
