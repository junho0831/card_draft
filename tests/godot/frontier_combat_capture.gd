extends SceneTree
const Storage = preload("res://src/services/game_storage.gd")
func _initialize():
	if not Storage.prepare_test_directory(): quit(2); return
	call_deferred("run")
func run():
	var viewport := Vector2i(844,390) if "--landscape" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	root.size = viewport
	var main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes",true)
	main.set_meta("layout_viewport_override",viewport)
	root.add_child(main)
	main.touch_input_active = viewport.x == 844
	main.pending_guided_run = false
	main._init_run("elf", "elf_cycle")
	main.current_run.relic_ids = []
	main.run_flow.prepare_battle("normal")
	var battle = main.battle_screen
	battle.battle_state.active_build_tags = []
	battle.player.field.clear(); battle.opponent.field.clear()
	battle.player.mana = 10
	battle.player.hand = main.card_db.build_deck_from_ids(["frostseed_burst","moonstring_bow","dew_scout"])
	for spec in [[battle.player,"storm_perch_archer",101],[battle.player,"rootshield_warden",102],[battle.opponent,"ossuary_guard",201]]:
		var card: Dictionary = main.card_db.get_card(spec[1])
		card.merge({"battle_unit_id":spec[2],"health":20,"max_health":20,"attack":3,"can_attack":true},true)
		spec[0].field.append(card)
	battle._ensure_hand_visual_slots()
	battle._refresh_ui()
	await create_timer(0.5).timeout
	var enemy_hp: int = battle.opponent.field[0].health
	var player_hp: int = battle.player.field[0].health
	var expected: Dictionary = battle._predict_unit_attack(battle.player.field[0],battle.opponent.field[0],battle.player,battle.opponent)
	battle._on_player_unit_pressed(0)
	battle._on_opponent_unit_pressed(0)
	await create_timer(0.18).timeout
	await capture("attack")
	for i in range(120):
		if not battle.attack_executor.busy: break
		await create_timer(0.05).timeout
	assert(not battle.attack_executor.busy,"new-card attack finishes")
	assert(battle.opponent.field[0].health == enemy_hp - int(expected.damage),"new unit deals previewed damage")
	assert(battle.player.field[0].health == player_hp - int(expected.counter),"new unit receives previewed counter damage")
	assert(not battle.player.field[0].can_attack,"new attack consumes readiness")
	await capture("after-attack")
	main._clear_screen(); main._clear_run(); main.queue_free()
	await process_frame
	print("PASS new card combat and damage preview ",viewport)
	quit()
func capture(label: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Storage.path_for(label+".png"))
