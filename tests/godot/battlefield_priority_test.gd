extends SceneTree

const Storage = preload("res://src/services/game_storage.gd")
const Tokens = preload("res://src/ui/styles/ui_tokens.gd")
var failures: Array[String] = []
var count := 0

func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	create_timer(120).timeout.connect(func(): printerr("Battlefield priority test timed out"); quit(1))
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failures.append(message)

func settle() -> void:
	for frame in range(12): await process_frame
	await create_timer(0.25).timeout

func tap(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		await process_frame
	await settle()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Storage.path_for(label + ".png"))

func run() -> void:
	for dimensions in [Vector2i(844, 390), Vector2i(932, 430), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		var main = preload("res://src/core/Main.tscn").instantiate()
		main.set_meta("disable_window_mode_changes", true)
		main.set_meta("disable_timed_battle_fx", true)
		main.set_meta("layout_viewport_override", dimensions)
		main.touch_input_active = dimensions.x < 1100
		root.add_child(main)
		main.pending_guided_run = false
		main.player_profile.learning_stage = 5
		main._apply_root_layout()
		await settle()
		main._init_run("human", "human_elite")
		main.run_flow.prepare_battle("normal")
		var battle = main.battle_screen
		battle.player.hand.clear()
		for i in range(10):
			battle.player.hand.append(main.card_db.get_card("militia_plus" if i % 3 == 0 else "militia").duplicate(true))
		battle._ensure_hand_visual_slots()
		battle.player.mana = 10
		for side in [battle.player, battle.opponent]:
			side.field.clear()
			for i in range(5):
				var unit: Dictionary = main.card_db.get_card("militia").duplicate(true)
				unit.merge({"battle_unit_id": i + (100 if side == battle.player else 200), "health": 5, "max_health": 5, "attack": 2, "can_attack": true}, true)
				side.field.append(unit)
		battle.selected_attacker = -1
		battle._refresh_ui()
		await settle()
		battle._store_battle_snapshot()
		var view = battle.landscape_view
		var before := JSON.stringify(battle.battle_state)
		var saved := FileAccess.get_file_as_string(Storage.run_path())
		var prefix := "%dx%d" % [dimensions.x, dimensions.y]
		for slots in [battle.player_field_slots, battle.opponent_field_slots]:
			for slot in slots:
				check(view.board_scroll.get_global_rect().encloses(slot.get_global_rect()), "all ten enlarged slots fit: " + prefix)
				check(slot.size.x >= (88 if view.compact_board else 154) and slot.size.y >= (90 if view.compact_board else 180), "field card receives priority: " + prefix)
				var card: Control = slot if slot is Button else slot.get_child(0)
				for name in ["Attack", "Health"]:
					var badge: Label = card.get_node(name)
					check(badge.get_theme_font_size("font_size") == 20 and card.get_global_rect().encloses(badge.get_global_rect()), "large stat badge stays inside its card")
		if not view.compact_board:
			await capture(prefix + "-battle")
			main.queue_free()
			await settle()
			continue
		check(battle.hand_scroll.size.y == Tokens.HAND_PEEK_HEIGHT, "resting hand uses the shallow fan")
		check(battle.hand_scroll.get_global_rect().end.y <= dimensions.y, "fan stays above the screen edge")
		check(battle.hand_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "folding does not add vertical hand scrolling")
		await capture(prefix + "-battle")
		var card: Control = battle.hand_box.get_child(0)
		var visible: Rect2 = card.get_global_rect().intersection(battle.hand_scroll.get_global_rect())
		check(visible.size.x >= 44 and visible.size.y >= 44, "folded card retains a full touch target")
		seed(64214)
		var expected := randi()
		seed(64214)
		await tap(visible.get_center())
		check(is_instance_valid(view.card_dialog), "tapping a folded card opens the full card before use")
		check(JSON.stringify(battle.battle_state) == before, "tap does not spend mana or play the card")
		check(FileAccess.get_file_as_string(Storage.run_path()) == saved, "tap preserves the saved battle")
		check(randi() == expected, "tap preserves RNG")
		await capture(prefix + "-selected-card")
		view.close_detail()
		await settle()
		check(JSON.stringify(battle.battle_state) == before, "closing the full card preserves battle")
		var original_height: float = view.field_height
		seed(65214)
		expected = randi()
		seed(65214)
		battle.selected_attacker = 0
		battle._refresh_ui()
		await settle()
		check(battle.hand_scroll.size.y == Tokens.HAND_TARGETING_HEIGHT, "target selection lowers the hand")
		check(view.field_height >= original_height, "target selection expands rather than shrinks the field")
		check(JSON.stringify(battle.battle_state) == before and randi() == expected, "field expansion is read-only")
		for slot in battle.opponent_field_slots:
			check(view.board_scroll.get_global_rect().encloses(slot.get_global_rect()), "prediction and target remain visible")
		await capture(prefix + "-target-selection")
		seed(66214)
		expected = randi()
		seed(66214)
		view._cancel_selection()
		await settle()
		check(battle.hand_scroll.size.y == Tokens.HAND_PEEK_HEIGHT and view.field_height == original_height, "cancel restores the resting composition")
		check(JSON.stringify(battle.battle_state) == before, "cancel does not attack or spend mana")
		check(FileAccess.get_file_as_string(Storage.run_path()) == saved, "cancel preserves the saved battle")
		check(randi() == expected, "cancel preserves RNG")
		before = JSON.stringify(battle.battle_state)
		await view.show_card(0)
		await settle()
		view.confirm_button.pressed.emit()
		await settle()
		check(battle.player.hand.size() == 10, "full field prevents confirming an extra unit")
		check(JSON.stringify(battle.battle_state) == before, "disabled confirmation cannot mutate battle")
		view.close_detail()
		battle.player.field.pop_back()
		battle._refresh_ui()
		await settle()
		var cost: int = main.relic_service.modify_card_cost(main.current_run, battle.battle_state, battle.player.hand[0], "player")
		var mana: int = battle.player.mana
		view.show_card(0)
		await settle()
		var confirm: Button = view.confirm_button
		confirm.pressed.emit()
		if is_instance_valid(confirm): confirm.pressed.emit()
		await settle()
		check(battle.player.hand.size() == 9 and battle.player.field.size() == 5, "confirmation plays exactly one card")
		check(battle.player.mana == mana - cost, "confirmation spends the existing cost exactly once")
		battle._on_player_unit_pressed(0)
		await settle()
		var prediction: Dictionary = battle._predict_unit_attack(battle.player.field[0], battle.opponent.field[0], battle.player, battle.opponent)
		var target: Control = battle.opponent_field_slots[0]
		if not target is Button: target = target.get_child(0)
		await tap(target.get_global_rect().get_center())
		check(battle.player.field[0].health == prediction.attacker_health and battle.opponent.field[0].health == prediction.defender_health, "enlarged targets still resolve the shared attack prediction")
		check(not battle.input_locked and battle.selected_attacker == -1 and battle.hand_scroll.size.y == Tokens.HAND_PEEK_HEIGHT, "attack completion restores the hand and input")
		main.queue_free()
		await settle()
	for failure in failures: printerr(failure)
	print("%s battlefield priority: %d assertions, %d failures" % ["PASS" if failures.is_empty() else "FAIL", count, failures.size()])
	quit(0 if failures.is_empty() else 1)
