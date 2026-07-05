extends Node
class_name AudioManager

var players: Array[AudioStreamPlayer] = []
var max_players := 8
var current_player_idx := 0

var streams := {}

func _init() -> void:
	name = "AudioManager"
	streams["click"] = _generate_chirp(1000.0, 800.0, 0.05, 0.15)
	streams["draw"] = _generate_chirp(150.0, 500.0, 0.15, 0.25, 0)
	streams["play"] = _generate_chirp(600.0, 200.0, 0.2, 0.25, 1)
	streams["heal"] = _generate_chirp(300.0, 1200.0, 0.35, 0.25, 2)
	streams["hit"] = _generate_noise(0.2, 0.35)

func _ready() -> void:
	for i in range(max_players):
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

func play_sound(sound_name: String) -> void:
	if not streams.has(sound_name):
		return
	var stream: AudioStreamWAV = streams[sound_name]
	
	var p := players[current_player_idx]
	current_player_idx = (current_player_idx + 1) % max_players
	
	p.stream = stream
	p.play()

func _generate_chirp(start_freq: float, end_freq: float, duration: float, volume: float = 0.5, env_type: int = 0) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	
	var num_samples := int(44100 * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var phase := 0.0
	for i in range(num_samples):
		var t := float(i) / 44100.0
		var progress := t / duration
		
		var freq := float(lerp(start_freq, end_freq, progress))
		if env_type == 2: # heal arpeggio
			var steps := [1.0, 1.25, 1.5, 2.0]
			var step_idx := int(progress * steps.size()) % steps.size()
			freq = start_freq * steps[step_idx]
			
		phase += (freq * 2.0 * PI) / 44100.0
		var sample := sin(phase)
		
		var envelope := 1.0 - progress
		if env_type == 0: # draw fade-in fade-out
			envelope = sin(progress * PI)
		elif env_type == 1: # play decay
			envelope = (1.0 - progress) * (1.0 - progress)
			
		sample *= envelope * volume
		var int_sample := int(clamp(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, int_sample)
		
	stream.data = bytes
	return stream

func _generate_noise(duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	
	var num_samples := int(44100 * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t := float(i) / 44100.0
		var progress := t / duration
		var sample := randf_range(-1.0, 1.0)
		
		var envelope := (1.0 - progress) * (1.0 - progress)
		sample *= envelope * volume
		
		var int_sample := int(clamp(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, int_sample)
		
	stream.data = bytes
	return stream
