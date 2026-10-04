extends SceneTree

const Audio = preload("res://src/services/audio_manager.gd")
const Storage = preload("res://src/services/game_storage.gd")

func _initialize() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")

func run() -> void:
	var manager := Audio.new()
	root.add_child(manager)
	var licensed := {}
	for directory in [manager.COMBAT_AUDIO_DIR, manager.COMMUNITY_AUDIO_DIR]:
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(directory + "/manifest.json"))
		assert(manifest is Array, "CC0 manifest is shipped")
		for entry in manifest:
			assert(entry.license == "CC0-1.0", "only CC0 manifest entries")
			licensed[directory + "/" + entry.file] = true
	for key in manager.streams:
		assert(manager.custom_streams.has(key), "every event has packaged audio: " + key)
		assert(licensed.has(manager.custom_streams[key].resource_path), "every event has CC0 provenance: " + key)
	for stream in manager.music_streams.values():
		assert(licensed.has(stream.resource_path), "every music slot has CC0 provenance")
	assert(licensed.has(manager.menu_music_player.stream.resource_path), "menu is CC0")
	manager.set_screen_music("map")
	assert(licensed.has(manager.menu_music_player.stream.resource_path), "exploration is CC0")
	if "--exported" in OS.get_cmdline_user_args():
		for path in [manager.MODEL_AUDIO_DIR + "/sword_hit.ogg", manager.FOLEY_AUDIO_DIR + "/sword_hit.ogg", manager.ORIGINAL_AUDIO_DIR + "/direct_attack.ogg"]:
			assert(not ResourceLoader.exists(path), "old audio excluded from export")
	manager.queue_free()
	await process_frame
	print("PASS every runtime audio event uses a packaged CC0 source")
	quit()
