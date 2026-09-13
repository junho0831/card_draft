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
	assert(before == JSON.stringify({"mana": battle.player.mana, "hp": battle.player.health, "hand": battle.player.hand}), "cancel does not spend resources")
	assert(battle.end_turn_button.get_global_rect().end.y <= viewport.y, "action remains visible")
	print("PASS battle presentation input checks")
	main._clear_screen()
	main.queue_free()
	await process_frame
	quit()
func unit(id: String, uid: int, attack: int, health: int) -> Dictionary:
	return {"id":id,"battle_unit_id":uid,"name": {"trainee_swordsman":"초보 검병","shield_guard":"방패 수호병","militia":"민병대"}[id],"race":"인간","attack":attack,"health":health,"max_health":health,"can_attack":true}
