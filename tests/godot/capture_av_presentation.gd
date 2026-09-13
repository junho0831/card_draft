extends SceneTree
## Real engine playback / transient-node cleanup, always in isolated storage.
const Storage = preload("res://src/services/game_storage.gd")

func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")

func run() -> void:
	var viewport := Vector2i(390, 844) if OS.get_cmdline_user_args().has("--mobile") else Vector2i(1280, 720)
	root.size = viewport
	var main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("layout_viewport_override", viewport)
	root.add_child(main)
	current_scene = main
	main.player_profile["battle_tutorial_seen"] = true
	main.pending_guided_run = false
	main._init_run("human", "human_elite")
	main.run_flow.prepare_battle("normal")
	var battle = main.battle_screen
	battle.player.field.clear()
	battle.opponent.field.clear()
	for spec in [[battle.player, "trainee_swordsman", 91], [battle.opponent, "militia", 92], [battle.player, "shield_guard", 93]]:
		var card: Dictionary = main.card_db.get_card(spec[1]).duplicate(true)
		card.merge({"battle_unit_id": spec[2], "attack": 3, "health": 5, "max_health": 5, "can_attack": true, "art_id": spec[1]}, true)
		spec[0].field.append(card)
	battle._refresh_ui()
	await create_timer(0.6).timeout
	var fx: Control = battle.battle_fx_layer
	var baseline := fx.get_child_count()
	var before := JSON.stringify([battle.player, battle.opponent])
	var attacker: Control = battle._field_slot_for(battle.player, 0)
	var defender: Control = battle._field_slot_for(battle.opponent, 0)
	var attacker_position := attacker.position
	for style in ["hit_human", "hit_elf", "hit_undead", "impact_heavy"]:
		# Exercise the actual battle presentation entry point, including recoil.
		await battle._play_inline_attack_feedback(attacker, defender, 5 if style == "impact_heavy" else 2, true, false, style)
		await create_timer(0.4).timeout
	battle._play_heal_fx(true, 3)
	main.audio_manager.play_sound("heal")
	await capture("heal")
	await create_timer(0.9).timeout
	var slot_color := defender.modulate
	var slot_scale := defender.scale
	battle._play_defeat_feedback(defender, Color.GOLD)
	fx.play_death(defender)
	main.audio_manager.play_sound("unit_death")
	await capture("death")
	await create_timer(0.7).timeout
	assert(defender.modulate == slot_color and defender.scale == slot_scale, "death must not darken or shrink the next unit slot")
	var equipped: Control = battle._field_slot_for(battle.player, 1)
	battle._play_card_resolution_feedback(main.card_db.get_card("training_sword"), "equipment", -1, int(battle.player.health), int(battle.opponent.health), 93)
	assert(attacker.scale.is_equal_approx(Vector2.ONE), "equipment must not animate the unselected first ally")
	assert(equipped.scale.x < 1.0, "equipment animates the selected second ally")
	await create_timer(0.6).timeout
	battle._play_race_power_feedback()
	await capture("ultimate")
	await create_timer(1.8).timeout
	assert(before == JSON.stringify([battle.player, battle.opponent]), "presentation alone must not mutate combat")
	assert(fx.get_child_count() == baseline, "transient effects must clean up")
	assert(attacker.scale.is_equal_approx(Vector2.ONE), "attacker returns to original scale")
	assert(attacker.position.is_equal_approx(attacker_position), "attacker returns to original position")
	assert(absf(attacker.rotation) < 0.001, "attacker returns to original rotation")
	battle.game_over = true
	main.audio_manager.stop_battle_music()
	battle._update_adaptive_battle_music()
	assert(main.audio_manager.current_battle_music_mode == "stopped", "victory UI refresh must not restart battle music")
	main._clear_screen()
	main.queue_free()
	await process_frame
	print("PASS audiovisual presentation, cleanup and state isolation ", viewport)
	quit()

func capture(label: String) -> void:
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Storage.path_for(label + ".png"))
