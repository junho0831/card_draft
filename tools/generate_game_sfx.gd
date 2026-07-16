extends SceneTree

const AUDIO_MANAGER = preload("res://src/services/audio_manager.gd")
const SOUND_NAMES := [
	"click",
	"hover",
	"draw",
	"play",
	"summon",
	"spell",
	"heal",
	"hit",
	"counter",
	"combo",
	"finisher",
	"reward",
	"victory",
	"defeat",
]

func _init() -> void:
	call_deferred("_generate")

func _generate() -> void:
	var audio_manager = AUDIO_MANAGER.new()
	var output_dir := ProjectSettings.globalize_path("res://assets/audio")
	DirAccess.make_dir_recursive_absolute(output_dir)
	for sound_name in SOUND_NAMES:
		var stream := audio_manager.streams.get(sound_name) as AudioStreamWAV
		if stream == null:
			printerr("Missing generated stream: %s" % sound_name)
			quit(1)
			return
		var output_path := "%s/%s" % [output_dir, sound_name]
		var error := stream.save_to_wav(output_path)
		if error != OK:
			printerr("Failed to save %s.wav: %s" % [sound_name, error_string(error)])
			quit(1)
			return
	audio_manager.free()
	print("Generated %d dark fantasy SFX files in %s" % [SOUND_NAMES.size(), output_dir])
	quit(0)
