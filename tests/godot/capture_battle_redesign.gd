extends SceneTree
const Storage = preload("res://src/services/game_storage.gd")
func _init():
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")
func run():
	var mobile := OS.get_cmdline_user_args().has("--mobile")
	var viewport := Vector2i(390, 844) if mobile else Vector2i(1280, 720)
	root.size = viewport
	var main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("layout_viewport_override", viewport)
	main.set_meta("disable_timed_battle_fx", true)
	root.add_child(main)
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
	for id in ["trainee_swordsman", "training_sword", "royal_support", "shield_guard", "first_aid"]:
		battle.player.hand.append(main.card_db.get_card(id))
	battle.player.mana = 4
	battle.player.max_mana = 4
	battle._ensure_hand_visual_slots()
	battle._refresh_ui()
	await create_timer(1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Storage.path_for("battle.png"))
	print("CAPTURE ", viewport, " hand=", battle.hand_box.get_global_rect(), " action=", battle.end_turn_button.get_global_rect())
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
	if mobile:
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
		if frame is Button:
			assert(frame.modulate.r < 0.5, "unaffordable cards are dim")
	battle.current_player = "opponent"
	battle._refresh_ui()
	assert(battle.end_turn_button.disabled and battle.end_turn_button.text == "상대 턴", "enemy phase disables action")
	battle.current_player = "player"
	battle.input_locked = true
	battle._refresh_ui()
	assert(battle.end_turn_button.text == "행동 처리 중", "player animation is not enemy turn")
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
