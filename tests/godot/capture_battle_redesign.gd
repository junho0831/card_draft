extends SceneTree
const Storage = preload("res://src/services/game_storage.gd")
func _init():
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")
func run():
	var landscape := OS.get_cmdline_user_args().has("--landscape")
	var mobile := OS.get_cmdline_user_args().has("--mobile") or landscape
	var viewport := Vector2i(667, 375) if OS.get_cmdline_user_args().has("--small-landscape") else Vector2i(844, 390) if landscape else (Vector2i(390, 844) if mobile else Vector2i(1280, 720))
	root.size = viewport
	var main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("layout_viewport_override", viewport)
	main.set_meta("disable_timed_battle_fx", true)
	root.add_child(main)
	main.touch_input_active = mobile
	main.player_profile["battle_tutorial_seen"] = true
	main.pending_guided_run = false
	main._init_run("human", "human_elite")
	main.run_flow.prepare_battle("normal")
	var battle = main.battle_screen
	battle.player.field = [unit("trainee_swordsman", 91, 3, 4), unit("shield_guard", 92, 2, 5)]
	battle.opponent.field = [unit("militia", 93, 2, 3)]
	for side in [battle.player, battle.opponent]:
		for card in side.field:
			card["art"] = main.card_db.get_card(card.id).get("art", 0)
			card["art_id"] = card.id
	battle.opponent.field[0]["is_vanguard"] = true
	battle.player.hand.clear()
	for id in ["trainee_swordsman", "training_sword", "royal_support", "shield_guard", "small_flame"]:
		battle.player.hand.append(main.card_db.get_card(id))
	battle.player.mana = 4
	battle.player.max_mana = 4
	battle._ensure_hand_visual_slots()
	battle._refresh_ui()
	await create_timer(1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Storage.path_for("battle.png"))
	print("CAPTURE ", viewport, " hand=", battle.hand_box.get_global_rect(), " action=", battle.end_turn_button.get_global_rect())
	if landscape:
		var kinds := {"trainee_swordsman":"unit", "training_sword":"equipment", "first_aid":"support", "small_flame":"damage", "vampiric_strike":"damage", "dark_bargain":"support", "death_mark":"damage"}
		for id in kinds:
			var sample: Dictionary = main.card_db.get_card(id)
			assert(battle.landscape_view.card_kind(sample) == kinds[id], "card type classification including mixed effects")
			sample.id = id + "_plus"
			assert(battle.landscape_view.card_kind(sample) == kinds[id], "upgraded cards keep their category")
		for face in battle.hand_box.get_children():
			assert(face.has_node("TypeBorder") and face.has_node("TypeIcon"), "type has color and icon")
			assert(face.size.y > face.size.x, "hand has portrait card proportions")
			assert(face.get_node("Illustration").modulate.a == 1.0, "card artwork remains visible")
			assert(face.get_node("Cost").get_theme_font_size("font_size") >= 16, "cost stays readable")
			assert(face.get_global_rect().end.y <= viewport.y, "portrait hand fits viewport")
		assert(battle.end_turn_button.size.y >= 52, "action touch area stays large")
	var input = preload("res://tests/godot/ui_input_test.gd").new()
	var before := JSON.stringify({"mana": battle.player.mana, "hp": battle.player.health, "hand": battle.player.hand})
	await input.click(battle.detail_toggle_button, self)
	await create_timer(0.3).timeout
	assert(battle.detail_overlay.visible, "information opens above the battle")
	assert(battle.deck_list_label.size.x > 200, "deck text has readable width in information")
	assert(before == JSON.stringify({"mana": battle.player.mana, "hp": battle.player.health, "hand": battle.player.hand}), "information does not change combat")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Storage.path_for("information.png"))
	await input.click(input.find_button(battle.detail_overlay, "전투로 돌아가기"), self)
	assert(not battle.detail_overlay.visible, "information closes")
	var equipment_slot: int = battle.player.hand[1].get("_hand_slot", 1)
	await input.click(battle._hand_card_control(equipment_slot), self)
	if landscape:
		assert(is_instance_valid(battle.landscape_view.card_dialog), "landscape card opens details only")
		assert(battle._hand_card_control(equipment_slot).has_node("SelectionBorder"), "selection uses separate white border")
		assert(before == JSON.stringify({"mana": battle.player.mana, "hp": battle.player.health, "hand": battle.player.hand}), "detail does not spend resources")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Storage.path_for("card-detail.png"))
		await input.click(battle._hand_card_control(equipment_slot), self)
		assert(battle.pending_action.is_empty(), "background repeated card tap never uses the card")
		await input.click(battle.landscape_view.confirm_button, self)
	elif mobile:
		await input.click(battle._hand_card_control(equipment_slot), self)
	await create_timer(0.3).timeout
	assert(not battle.pending_action.is_empty(), "equipment input enters targeting")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Storage.path_for("targeting.png"))
	await input.click(battle.end_turn_button, self)
	assert(battle.pending_action.is_empty(), "bottom cancel exits targeting")
	assert(battle.selected_hand_slot == -1, "cancel also clears card preview selection")
	assert(before == JSON.stringify({"mana": battle.player.mana, "hp": battle.player.health, "hand": battle.player.hand}), "cancel does not spend resources")
	assert(battle.end_turn_button.get_global_rect().end.y <= viewport.y, "action remains visible")
	# The preview uses combat damage and must never mutate combat state.
	var state_before := JSON.stringify([battle.player, battle.opponent, battle.battle_state])
	var prediction: Dictionary = battle._predict_unit_attack(battle.player.field[0], battle.opponent.field[0], battle.player, battle.opponent)
	assert(prediction.defender_health == 0 and prediction.attacker_health == 4, "lethal hit prevents retaliation")
	var strong_enemy: Dictionary = battle.opponent.field[0].duplicate(true)
	strong_enemy.health = 9
	var exchange: Dictionary = battle._predict_unit_attack(battle.player.field[0], strong_enemy, battle.player, battle.opponent)
	assert(exchange.defender_health == 6 and exchange.attacker_health == 2, "nonlethal exchange predicts both health values")
	assert(state_before == JSON.stringify([battle.player, battle.opponent, battle.battle_state]), "prediction is read only")
	await input.click(find_button(battle._field_slot_for(battle.player, 0)), self)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Storage.path_for("attack-preview.png"))
	if landscape:
		var rendered_enemy := find_button(battle.opponent_field_slots[0])
		assert(rendered_enemy.has_meta("attack_prediction"), "compact target renders health prediction")
		assert(rendered_enemy.get_meta("attack_prediction").defender_health == prediction.defender_health, "displayed prediction uses combat calculation")
		assert(rendered_enemy.get_node("EnemyPrediction").text == "적3→0" and find_button(battle._field_slot_for(battle.player, 0)).get_node("OwnPrediction").text == "내4→4", "both resulting health values are visible labels")
	if not mobile:
		var enemy_button := find_button(battle._field_slot_for(battle.opponent, 0))
		var motion := InputEventMouseMotion.new()
		motion.position = enemy_button.get_global_rect().get_center()
		motion.global_position = motion.position
		root.push_input(motion, true)
		await process_frame
		assert(battle.battle_fx_layer.drag_line != null, "hovering an attack target shows the connection")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Storage.path_for("attack-arrow.png"))
	await input.click(find_button(battle._field_slot_for(battle.opponent, 0)), self)
	await create_timer(0.3).timeout
	assert(battle.opponent.field.is_empty(), "actual lethal attack removes the predicted target")
	assert(battle.player.field[0].health == prediction.attacker_health, "actual lethal attack matches own health preview")
	battle.opponent.field = [strong_enemy]
	battle.player.field[0].can_attack = true
	battle._refresh_ui()
	await process_frame
	await input.click(find_button(battle._field_slot_for(battle.player, 0)), self)
	await input.click(find_button(battle._field_slot_for(battle.opponent, 0)), self)
	await create_timer(0.3).timeout
	assert(battle.opponent.field[0].health == exchange.defender_health, "actual nonlethal enemy health matches preview")
	assert(battle.player.field[0].health == exchange.attacker_health, "actual retaliation health matches preview")
	assert(battle.battle_fx_layer.drag_line == null, "connection clears after attack")
	battle.player.mana = 0
	for card in battle.player.hand:
		card.cost = 99
	battle.selected_attacker = -1
	for ally in battle.player.field:
		ally.can_attack = false
	battle.battle_state.race_power_used = true
	battle._refresh_ui()
	assert(battle._turn_action_state().exhausted, "no card, attack or power recommends ending turn")
	assert(battle.end_turn_button.text == "턴 종료", "exhausted label")
	for frame in battle.hand_box.get_children():
		if frame is Button and landscape:
			assert(frame.get_node("Illustration").modulate.r < 0.5 and frame.get_node("Cost").modulate.r == 1.0, "unaffordable art dims while cost stays readable")
		elif frame is Button:
			assert(frame.modulate.r < 0.5, "unaffordable cards are dim")
	battle.current_player = "opponent"
	battle._refresh_ui()
	assert(battle.end_turn_button.disabled and battle.end_turn_button.text == "상대 턴", "enemy phase disables action")
	battle.current_player = "player"
	battle.input_locked = true
	battle._refresh_ui()
	assert(battle.end_turn_button.text == "행동 처리 중", "player animation is not enemy turn")
	if landscape:
		battle.input_locked = false
		battle.player.mana = 4
		battle.player.hand[0].cost = 1
		battle._refresh_ui()
		await process_frame
		var card_button = battle._hand_card_control(int(battle.player.hand[0].get("_hand_slot", 0)))
		await input.click(card_button, self)
		battle.player.mana = 0
		battle.player.hand[0].cost = 9
		await input.click(battle.landscape_view.confirm_button, self)
		assert(battle.landscape_view.confirm_button.disabled, "confirmation rechecks changed mana")
		assert(battle.landscape_view.handle_back(), "back closes card detail")
		battle.selected_attacker = 0
		assert(battle.landscape_view.handle_back() and battle.current_player == "player", "back cancels attacker without ending turn")
		var field_button = find_button(battle.player_field_slots[0])
		var hold := InputEventMouseButton.new()
		hold.button_index = MOUSE_BUTTON_LEFT
		hold.position = field_button.get_global_rect().get_center()
		hold.global_position = hold.position
		hold.pressed = true
		root.push_input(hold, true)
		await create_timer(0.45).timeout
		hold.pressed = false
		root.push_input(hold, true)
		await process_frame
		assert(is_instance_valid(battle.landscape_view.card_dialog) and battle.selected_attacker == -1, "long press opens unit details without selecting or attacking")
		battle.landscape_view.close_detail()
		for side in [battle.player, battle.opponent]:
			while side.field.size() < 5:
				side.field.append(unit("shield_guard", 200 + side.field.size(), 3, 7))
		battle._refresh_ui()
		await process_frame
		await process_frame
		for lane in [battle.player_field_slots, battle.opponent_field_slots]:
			assert(lane.size() == 5, "all five slots visible")
			for slot in lane:
				assert(Rect2(Vector2.ZERO, viewport).encloses(slot.get_global_rect()), "entire field remains onscreen")
		assert(battle.hand_scroll.get_global_rect().end.y <= viewport.y, "hand remains onscreen with full fields")
		assert(main.root_scroll.get_v_scroll_bar().max_value <= main.root_scroll.get_v_scroll_bar().page, "landscape has no page scrolling")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Storage.path_for("full-board.png"))
		for card_id in ["training_sword", "corpse_explosion"]:
			battle.player.hand = [main.card_db.get_card(card_id).duplicate(true)]
			battle.player.mana = 10
			battle.opponent.health = 50
			battle._refresh_ui()
			await process_frame
			await process_frame
			var target_id: int = battle.player.field[0].battle_unit_id
			var old_attack: int = battle.player.field[0].attack
			await input.click(battle._hand_card_control(int(battle.player.hand[0].get("_hand_slot", 0))), self)
			await input.click(battle.landscape_view.confirm_button, self)
			assert(not battle.pending_action.is_empty() and battle.player.hand.size() == 1, "targeted card waits without consumption")
			await input.click(find_button(battle.player_field_slots[0]), self)
			await create_timer(0.3).timeout
			assert(battle.player.hand.is_empty() and battle.pending_action.is_empty(), "target confirmation uses exactly one card")
			if card_id == "training_sword":
				assert(battle.player.field[0].attack > old_attack, "equipment strengthens chosen ally")
			else:
				assert(battle._ally_index_by_id(target_id) == -1, "sacrifice removes chosen ally")
	print("PASS active states, combat health preview, phase labels and battle input checks")
	main._clear_screen()
	main.queue_free()
	await process_frame
	quit()
func unit(id: String, uid: int, attack: int, health: int) -> Dictionary:
	return {"id":id,"battle_unit_id":uid,"name": {"trainee_swordsman":"초보 검병","shield_guard":"방패 수호병","militia":"민병대"}[id],"race":"인간","attack":attack,"health":health,"max_health":health,"can_attack":true}

func find_button(node: Node) -> Button:
	if node is Button:
		return node
	for child in node.get_children():
		var found := find_button(child)
		if found != null:
			return found
	return null
