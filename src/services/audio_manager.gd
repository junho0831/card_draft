extends Node
class_name AudioManager

var players: Array[AudioStreamPlayer] = []
var max_players := 8
var current_player_idx := 0

var streams := {}

func _init() -> void:
	name = "AudioManager"
	streams["click"] = _generate_chirp(220.0, 100.0, 0.08, 0.22, 1)
	streams["draw"] = _generate_chirp(120.0, 380.0, 0.2, 0.36, 0)
	streams["play"] = _generate_chirp(180.0, 60.0, 0.22, 0.35, 1)
	streams["heal"] = _generate_chirp(220.0, 880.0, 0.42, 0.3, 2)
	streams["hit"] = _generate_noise(0.2, 0.35)
	streams["victory"] = _generate_fanfare(true)
	streams["defeat"] = _generate_fanfare(false)

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
		
		# Warm, heavy waveforms instead of cold raw sine waves
		var sample := 0.0
		if env_type == 0: # draw - paper card rustle/whoosh
			var noise := randf_range(-1.0, 1.0)
			phase += (freq * 2.0 * PI) / 44100.0
			var wave := sin(phase)
			sample = (wave * 0.2 + noise * 0.8) # Heavy textured paper friction
		elif env_type == 1: # play - solid punchy impact click
			var noise := randf_range(-1.0, 1.0)
			phase += (freq * 2.0 * PI) / 44100.0
			# Sub-bass mixed with high-mid click
			var sub_bass := sin(phase * 0.3) 
			var snap := sin(phase * 2.2)
			sample = (sub_bass * 0.6 + snap * 0.25 + noise * 0.15)
		elif env_type == 2: # heal - warm harmonic arpeggio
			var steps: Array[float] = [1.0, 1.25, 1.5, 2.0]
			var step_idx := int(progress * steps.size()) % steps.size()
			freq = start_freq * steps[step_idx]
			phase += (freq * 2.0 * PI) / 44100.0
			# Rich harmonic organ/chime sound (sine + thirds + fifths overtones)
			sample = (sin(phase) + sin(phase * 1.5) + sin(phase * 2.0)) * 0.33
		else:
			phase += (freq * 2.0 * PI) / 44100.0
			sample = sin(phase)
			
		var envelope := 1.0 - progress
		if env_type == 0: # draw envelope: smooth card drag whoosh
			envelope = sin(progress * PI)
		elif env_type == 1: # play envelope: steep heavy thud
			envelope = exp(-progress * 8.0)
		elif env_type == 2: # heal envelope: slow warm fading glow
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
	
	var phase_bass := 0.0
	for i in range(num_samples):
		var t := float(i) / 44100.0
		var progress := t / duration
		
		# Low frequency impact sweep (100Hz down to 40Hz)
		var freq: float = lerp(100.0, 40.0, progress)
		phase_bass += (freq * 2.0 * PI) / 44100.0
		
		# Heavy thud (bass sweep + texture noise)
		var bass := sin(phase_bass)
		var noise := randf_range(-1.0, 1.0)
		var sample := bass * 0.7 + noise * 0.3
		
		# Sharp combat impact envelope
		var envelope := exp(-progress * 9.0)
		sample *= envelope * volume
		
		var int_sample := int(clamp(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, int_sample)
		
	stream.data = bytes
	return stream

func _generate_fanfare(is_win: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	
	var duration := 1.2 if is_win else 1.5
	var num_samples := int(44100 * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	# Lowered notes by one whole octave for deep, heavy, dark-fantasy brass horn feel
	var win_notes: Array[float] = [130.81, 164.81, 196.00, 261.63, 329.63, 392.00]
	var lose_notes: Array[float] = [155.56, 146.83, 123.47, 98.00, 82.41, 65.41]
	var notes: Array[float] = win_notes if is_win else lose_notes
	
	var phase := 0.0
	for i in range(num_samples):
		var t := float(i) / 44100.0
		var progress := t / duration
		
		var note_idx := int(progress * notes.size()) % notes.size()
		var freq: float = notes[note_idx]
		
		phase += (freq * 2.0 * PI) / 44100.0
		
		# Brass horn synthesis (Adding rich, warm harmonic overtones)
		var root := sin(phase)
		var second_harmonic := sin(phase * 2.0) * 0.4
		var third_harmonic := sin(phase * 3.0) * 0.2
		var sample := root + second_harmonic + third_harmonic
		
		var note_progress := fmod(progress * notes.size(), 1.0)
		var note_envelope := exp(-note_progress * 4.0)
		var global_envelope := (1.0 - progress) * (1.0 - progress)
		
		sample *= note_envelope * global_envelope * (0.3 if is_win else 0.4)
		var int_sample := int(clamp(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, int_sample)
		
	stream.data = bytes
	return stream
