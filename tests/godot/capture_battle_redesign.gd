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
	main._clear_screen()
	main.queue_free()
	await process_frame
	quit()
func unit(id: String, uid: int, attack: int, health: int) -> Dictionary:
	return {"id":id,"battle_unit_id":uid,"name": {"trainee_swordsman":"초보 검병","shield_guard":"방패 수호병","militia":"민병대"}[id],"race":"인간","attack":attack,"health":health,"max_health":health,"can_attack":true}
