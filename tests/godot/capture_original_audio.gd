extends SceneTree
const Storage = preload("res://src/services/game_storage.gd")
const Audio = preload("res://src/services/audio_manager.gd")

func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")

func run() -> void:
	var manager := Audio.new()
	root.add_child(manager)
	if OS.get_cmdline_user_args().has("--expect-model-pack"):
		if not manager._has_model_battle_score() or ResourceLoader.exists("res://assets/audio/original_v1/direct_attack.ogg"):
			printerr("FAIL exported package contains the wrong audio pack")
			quit(1)
			return
		for key in manager.authored_sfx_keys():
			var stream = manager.custom_streams.get(key)
			if stream == null or not String(stream.resource_path).begins_with(manager.MODEL_AUDIO_DIR):
				printerr("FAIL generated SFX missing from package: " + String(key))
				quit(1)
				return
	var recorder := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, recorder)
	recorder.set_recording_active(true)
	await create_timer(2.0).timeout
	if not manager.menu_music_player.playing:
		printerr("FAIL menu music did not start")
		quit(1)
		return
	manager.set_battle_music_state({"mode": "tension"})
	if manager.menu_music_player.playing:
		printerr("FAIL menu music overlaps battle")
		quit(1)
		return
	for key in ["draw", "play", "summon_human", "equipment_elf", "hit_human", "spell_fire", "heal", "combo", "finisher", "victory_burst"]:
		manager.play_sound(key)
		await create_timer(0.75).timeout
	manager.stop_battle_music()
	await create_timer(0.1).timeout
	manager.set_battle_music_state({"mode": "base"})
	await create_timer(0.6).timeout
	if not manager.music_players["battle_base"].playing:
		printerr("FAIL stale fade-out stopped resumed battle music")
		quit(1)
		return
	if manager._has_model_battle_score():
		for key in ["battle_tension", "battle_lethal", "battle_low_hp"]:
			if manager.music_players[key].playing:
				printerr("FAIL old music stem plays over generated score")
				quit(1)
				return
	manager.stop_battle_music()
	await create_timer(1.0).timeout
	recorder.set_recording_active(false)
	var recording := recorder.get_recording()
	if recording == null or recording.data.is_empty():
		printerr("FAIL no audio rendered")
		quit(1)
		return
	var saved := recording.save_to_wav(Storage.path_for("engine_audio.wav"))
	if saved != OK:
		quit(1)
		return
	print("PASS original menu, battle transition, 10 SFX and return; engine recording saved")
	manager.queue_free()
	await process_frame
	quit()
