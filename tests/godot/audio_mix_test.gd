extends SceneTree

const Audio = preload("res://src/services/audio_manager.gd")
const Storage = preload("res://src/services/game_storage.gd")
var failures: Array[String] = []

func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Audio mix test requires a real audio driver")
		quit(2)
		return
	var manager := Audio.new()
	root.add_child(manager)
	for key in manager.custom_streams:
		var path: String = manager.custom_streams[key].resource_path
		check(path.begins_with(manager.COMBAT_AUDIO_DIR) or path.begins_with(manager.COMMUNITY_AUDIO_DIR), "only CC0 assets selected: " + key)
	for key in ["hit_human", "hit_elf", "hit_common", "counter", "impact_metal", "impact_heavy", "direct_attack"]:
		var sound: AudioStream = manager.custom_streams[key]
		check(sound.resource_path.begins_with(manager.COMBAT_AUDIO_DIR), "short CC0 recording selected: " + key)
		check(sound.get_length() <= 0.4, "long tail removed: " + key)
	check(manager.custom_streams["spell_fire"].resource_path.begins_with(manager.COMBAT_AUDIO_DIR), "magic also uses CC0")
	check(manager.custom_music_streams["battle_base"].resource_path.begins_with(manager.COMMUNITY_AUDIO_DIR), "CC0 battle music selected")
	check(manager.menu_music_player.stream.resource_path.begins_with(manager.COMMUNITY_AUDIO_DIR), "CC0 menu music selected")
	manager.set_screen_music("map")
	check(manager.menu_music_player.stream.resource_path.ends_with("community_v1/exploration.ogg"), "CC0 exploration selected")
	check(manager._sfx_path("spell_fire").begins_with(manager.COMBAT_AUDIO_DIR), "no model fallback for magic")
	for stream in manager.music_streams.values():
		check(stream.resource_path.begins_with(manager.COMMUNITY_AUDIO_DIR), "every music slot is CC0")
	manager.apply_settings({"bgm_volume": 1.0, "sfx_volume": 1.0})
	var bus := AudioServer.get_bus_index("SFX")
	var count := AudioServer.get_bus_effect_count(bus)
	manager._ensure_sfx_bus()
	check(AudioServer.get_bus_effect_count(bus) == count, "bus effects stay unique")
	check(AudioServer.get_bus_effect(bus, 0) is AudioEffectHighPassFilter, "DC filtering precedes limiter")
	manager.play_sound("hit_human")
	manager.play_sound("hit_elf")
	check(manager.last_sound_at_msec.has("hit_human"), "first impact plays")
	check(not manager.last_sound_at_msec.has("hit_elf"), "same recording is not doubled under an alias")
	check(is_equal_approx(manager.players[0].volume_db, -11.0), "gain reduction occurs before mixing")
	manager.play_sound("heal")
	check(manager.last_sound_at_msec.has("heal"), "different sounds remain independent")
	manager.play_sound("hover")
	manager.play_sound("click")
	check(manager.last_sound_at_msec.has("hover") and manager.last_sound_at_msec.has("click"), "click feedback survives immediately preceding hover using the same recording")
	while Time.get_ticks_msec() - int(manager.last_sound_at_msec["hit_human"]) < 160:
		await process_frame
	manager.play_sound("hit_elf")
	check(manager.last_sound_at_msec.has("hit_elf"), "later impact is not suppressed")
	var recorder := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, recorder)
	recorder.set_recording_active(true)
	manager.set_battle_music_state({"mode": "tension"})
	for i in range(20):
		for key in ["hit_human", "hit_elf", "impact_heavy", "direct_attack", "unit_death", "spell_fire", "heal"]:
			manager.play_sound(key)
		await create_timer(0.16).timeout
	await create_timer(2.0).timeout
	recorder.set_recording_active(false)
	var recording := recorder.get_recording()
	check(recording != null and not recording.data.is_empty(), "engine rendered audio")
	if recording != null and not recording.data.is_empty():
		check(recording.save_to_wav(Storage.path_for("combat_mix.wav")) == OK, "combat mix saved")
		var peak := 0.0
		var samples := recording.data
		for offset in range(0, samples.size(), 2):
			peak = maxf(peak, absf(float(samples.decode_s16(offset))) / 32768.0)
		print("Combat mix peak: ", linear_to_db(peak), " dBFS")
		check(peak > 0.01 and peak < 0.95, "busy combat mix retains output headroom")
	manager.queue_free()
	await process_frame
	print("PASS audio mix" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
