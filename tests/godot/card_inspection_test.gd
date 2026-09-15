extends SceneTree
const Storage = preload("res://src/services/game_storage.gd")
var failures: Array[String] = []
func _initialize():
	if not Storage.prepare_test_directory(): quit(2); return
	create_timer(60).timeout.connect(func(): printerr("Card inspection test timed out"); quit(1))
	call_deferred("run")
func check(value: bool, text: String):
	if not value: failures.append(text)
func run():
	root.size = Vector2i(844, 390)
	var main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("layout_viewport_override", root.size)
	main.set_meta("disable_timed_battle_fx", true)
	root.add_child(main)
	main.touch_input_active = true
	main._init_run("human", "human_elite")
	main.run_flow.prepare_battle("normal")
	var battle = main.battle_screen
	if "--frontier-cards" in OS.get_cmdline_user_args():
		battle.player.hand = [main.card_db.get_card("sunforge_sabre")]
		battle._ensure_hand_visual_slots()
	battle.landscape_view.show_card(0)
	await create_timer(0.4).timeout
	var viewer = main.modal_layer.find_child("CardInspectionView", true, false)
	check(viewer != null, "viewer in card dialog")
	var before := JSON.stringify(battle.player)
	var input = preload("res://tests/godot/ui_input_test.gd").new()
	var center: Vector2 = viewer.get_global_rect().get_center()
	var touch := InputEventScreenTouch.new()
	touch.index = 0; touch.pressed = true; touch.position = center
	Input.parse_input_event(touch)
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = 0; drag.position = center + Vector2(80, -15); drag.relative = Vector2(80, -15)
	Input.parse_input_event(drag)
	await create_timer(0.3).timeout
	check(viewer.tilt.length() > 0.08, "touch drag tilts card")
	check(JSON.stringify(battle.player) == before, "inspection cannot play a card")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Storage.path_for("tilted.png"))
	touch.pressed = false; touch.position = drag.position
	Input.parse_input_event(touch)
	await create_timer(0.7).timeout
	check(viewer.tilt.length() < 0.002, "release returns to front")
	check(not viewer.is_processing(), "idle viewer stops processing")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Storage.path_for("front.png"))
	var scroll = main.modal_layer.find_child("CardDetailScroll", true, false)
	check(viewer.size.y >= 470, "card stays large instead of fitting screen height")
	check(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "large card is scrollable")
	var action_rect: Rect2 = battle.landscape_view.confirm_button.get_global_rect()
	touch.pressed = true; touch.position = viewer.global_position + Vector2(100, 95)
	Input.parse_input_event(touch)
	await process_frame
	drag.position = touch.position - Vector2(0, 65); drag.relative = Vector2(0, -65)
	Input.parse_input_event(drag)
	await process_frame
	touch.pressed = false; touch.position = drag.position
	Input.parse_input_event(touch)
	await create_timer(0.2).timeout
	check(scroll.scroll_vertical > 0, "vertical swipe over card scrolls content")
	check(battle.landscape_view.confirm_button.get_global_rect() == action_rect, "use button stays fixed")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Storage.path_for("scrolled.png"))
	await input.click(battle.landscape_view.card_dialog.find_children("*", "Button", true, false)[0], self)
	await process_frame
	check(not is_instance_valid(viewer), "close releases viewer")
	check(JSON.stringify(battle.player) == before, "close preserves game state")
	main.set_meta("layout_viewport_override", Vector2i(390, 844))
	root.size = Vector2i(390, 844)
	await main._show_main_menu()
	main._show_collection()
	await create_timer(0.4).timeout
	var collection = preload("res://src/ui/screens/collection_screen.gd").new(main)
	collection._inspect_card(main.card_db.get_card("moonstring_bow" if "--frontier-cards" in OS.get_cmdline_user_args() else "training_sword"))
	await create_timer(0.4).timeout
	var collection_view = main.modal_layer.find_child("CardInspectionView", true, false)
	check(is_instance_valid(collection_view), "collection opens inspection")
	if is_instance_valid(collection_view): check(collection_view.get_global_rect().end.x <= 390, "portrait inspection fits")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Storage.path_for("collection.png"))
	main._clear_modal()
	await process_frame
	check(not is_instance_valid(collection_view), "collection close releases viewer")
	if "--frontier-cards" in OS.get_cmdline_user_args():
		main.set_meta("layout_viewport_override", Vector2i(844, 390))
		root.size = Vector2i(844, 390)
		await create_timer(0.3).timeout
		main._show_compendium()
		await create_timer(0.3).timeout
		var codex = main.active_screen_controller
		check(codex.grid.columns == 3, "landscape compendium fits three full cards")
		check(codex.grid.get_global_rect().end.x <= 844, "compendium rightmost card stays in viewport")
		codex.search.text = "잿불 관문병"
		codex._refresh_grid()
		await process_frame
		check(codex.grid.get_child_count() == 1, "compendium search finds the new sentinel")
		var face: Control = codex.grid.get_child(0)
		var ancestor = face.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer:
				ancestor.ensure_control_visible(face)
				break
			ancestor = ancestor.get_parent()
		await create_timer(0.2).timeout
		await input.click(face, self)
		await create_timer(0.3).timeout
		var codex_view = main.modal_layer.find_child("CardInspectionView", true, false)
		check(is_instance_valid(codex_view), "tapping new card opens compendium 2.5D viewer")
		if is_instance_valid(codex_view):
			check(codex_view.size.is_equal_approx(Vector2(300, 470)), "compendium viewer preserves a tall card instead of stretching across the screen")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Storage.path_for("compendium.png"))
		codex._close_detail()
	main.queue_free()
	await process_frame
	print("PASS card inspection touch, release, idle, close and state isolation" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
