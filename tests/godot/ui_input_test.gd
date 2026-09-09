extends RefCounted

const MAIN = preload("res://src/core/Main.tscn")
var failures: Array[String] = []
var count := 0

func check(ok: bool, message: String) -> void:
	count += 1
	if not ok:
		failures.append(message)

func run() -> Dictionary:
	var tree = Engine.get_main_loop()
	var original_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	var main = MAIN.instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("layout_viewport_override", Vector2i(1280, 720))
	tree.root.add_child(main)
	main.player_profile["learning_stage"] = 0
	await tree.process_frame
	await tree.process_frame
	var start = find_button(main.root_box, "NEW  새 런 시작")
	check(start != null, "new-run button is available for mouse input")
	if start != null:
		# Exercise GUI event dispatch: synchronous free during release used to crash.
		await click(start, tree)
		check(main.active_screen == "race_selection", "mouse release can switch screens without freeing its event receiver")
		if main.active_screen != "race_selection":
			main._clear_screen()
			main.queue_free()
			await tree.process_frame
			tree.root.size = original_size
			return {"count": count, "failures": failures}
		var screen = main.active_screen_controller
		check(screen.fixed_footer != null, "desktop selection keeps its start action docked")
		var skip = find_button(main.root_box, "바로 시작 · 전략 고르기")
		await click(skip, tree)
		check(screen.strategy_box.visible and not main.pending_guided_run, "quick start reveals strategies through actual input")
		await tree.process_frame
		await tree.process_frame
		check(main.root_scroll.scroll_vertical > 0, "quick start scrolls to the newly revealed strategies")
		var old_panel = main.root_box.get_child(0)
		main._show_main_menu()
		check(is_instance_valid(old_panel) and old_panel.is_queued_for_deletion() and not old_panel.is_inside_tree(), "screen teardown detaches immediately and defers destruction")
	main.pending_guided_run = false
	main.set_meta("disable_timed_battle_fx", true)
	main._init_run("human", "human_elite")
	main.run_flow.prepare_battle("normal")
	var battle = main.battle_screen
	battle.player.field = [{"id": "trainee_swordsman", "name": "초보 검병", "race": "인간", "attack": 2, "health": 3, "max_health": 3, "can_attack": true, "battle_unit_id": 900}]
	battle.player.hand = [main.card_db.get_card("training_sword")]
	battle.player.mana = 10
	battle.current_player = "player"
	battle.input_locked = false
	battle._ensure_hand_visual_slots()
	await battle._on_hand_card_pressed(0)
	await tree.process_frame
	await tree.process_frame
	var field_button: Button = battle.player_field_slots[0].get_child(0)
	await click(field_button, tree)
	check(battle.pending_action.is_empty() and battle.player.field[0].attack == 4, "clicking the unit artwork confirms equipment on that unit")
	main._clear_screen()
	main.queue_free()
	await tree.process_frame
	tree.root.size = original_size
	return {"count": count, "failures": failures}

func find_button(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix):
		return node
	for child in node.get_children():
		var found = find_button(child, prefix)
		if found != null:
			return found
	return null

func click(button: Button, tree) -> void:
	if button == null:
		check(false, "expected clickable control exists")
		return
	var position := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame
