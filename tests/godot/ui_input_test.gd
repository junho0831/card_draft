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
	var start = find_button(main.root_box, "새 런 시작")
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
	for viewport in [Vector2i(1280, 720), Vector2i(390, 844)]:
		for race in ["human", "elf", "undead"]:
			tree.root.size = viewport
			main.set_meta("layout_viewport_override", viewport)
			main.player_profile["learning_stage"] = 0
			main.pending_guided_run = true
			main._init_run(race)
			main._apply_root_layout()
			main.run_flow.prepare_battle("normal")
			battle = main.battle_screen
			battle.player.hand = [main.card_db.get_card({"human": "knight_spearman", "elf": "elf_ranger", "undead": "bone_soldier"}[race])]
			battle._ensure_hand_visual_slots()
			battle._refresh_ui()
			await tree.process_frame
			await tree.process_frame
			await tree.create_timer(0.35).timeout
			var unchanged: String = JSON.stringify([battle.player, battle.opponent, battle.selected_attacker])
			await click(battle.recommended_action_button, tree)
			check(JSON.stringify([battle.player, battle.opponent, battle.selected_attacker]) == unchanged, "help input preserves combat %s %s" % [race, viewport])
			var index: int = battle._recommended_hand_index()
			var slot: int = battle.player.hand[index].get("_hand_slot", index)
			var card_button: Button = battle._hand_card_control(slot)
			battle.hand_scroll.ensure_control_visible(card_button)
			await tree.process_frame
			await click(battle._hand_card_control(slot), tree)
			if viewport.x < 500:
				check(battle.player.field.is_empty(), "mobile first tap only previews")
				await click(battle._hand_card_control(slot), tree)
			check(not battle.player.field.is_empty(), "manual card input summons %s %s" % [race, viewport])
			if battle.player.field.is_empty():
				continue
			# A ready-unit resume fixture exercises targeting independently of summon sickness.
			battle.player.field[0].can_attack = true
			battle._refresh_ui()
			await tree.process_frame
			await click(find_button(battle.player_field_slots[0], ""), tree)
			check(battle.selected_attacker == 0, "manual attacker selection")
			if OS.get_cmdline_user_args().has("--capture-input") and race == "human":
				await RenderingServer.frame_post_draw
				tree.root.get_texture().get_image().save_png(preload("res://src/services/game_storage.gd").path_for("target_%d.png" % viewport.x))
			await click(find_button(battle.opponent_field_slots[0], ""), tree)
			check(main.current_run.get("first_play_actions", {}).get("unit_attacked", false), "manual vanguard attack")
			check(not battle.end_turn_button.get_global_rect().intersects(battle.hand_scroll.get_global_rect()), "action dock does not overlap hand")
			var turns: int = battle.battle_state.get("player_turn_count", 0)
			await click(battle.end_turn_button, tree)
			for wait_frame in range(200):
				if battle.current_player == "player" and not battle.input_locked:
					break
				await tree.create_timer(0.05).timeout
			check(int(battle.battle_state.get("player_turn_count", 0)) > turns, "manual turn end starts another player turn")
			await click(find_button(battle.player_field_slots[0], ""), tree)
			await click(battle.hero_attack_button, tree)
			check(main.current_run.get("first_play_actions", {}).get("hero_attacked", false), "manual hero attack records actual action")
			if race == "human":
				main.current_run.current_node_index = 2
				battle.player.hand = [main.card_db.get_card("training_sword")]
				battle.player.mana = 10
				battle._ensure_hand_visual_slots()
				battle._refresh_ui()
				await tree.process_frame
				var equipment_slot: int = battle.player.hand[0].get("_hand_slot", 0)
				await click(battle._hand_card_control(equipment_slot), tree)
				if viewport.x < 500:
					await click(battle._hand_card_control(equipment_slot), tree)
				check(not battle.pending_action.is_empty(), "equipment input opens target selection")
				await click(battle.end_turn_button, tree)
				check(battle.pending_action.is_empty() and battle.player.mana == 10 and battle.player.hand.size() == 1, "cancel input preserves equipment and mana")
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
