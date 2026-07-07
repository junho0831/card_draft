extends Node
class_name AudioManager

var players: Array[AudioStreamPlayer] = []
var max_players := 8
var current_player_idx := 0

var streams := {}

func _init() -> void:
	name = "AudioManager"
	_generate_all_sounds()

func _ready() -> void:
	for i in range(max_players):
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

func play_sound(sound_name: String) -> void:
	if not streams.has(sound_name):
		return
	
	var p := players[current_player_idx]
	current_player_idx = (current_player_idx + 1) % max_players
	
	var custom_path_wav := "res://assets/audio/%s.wav" % sound_name
	var custom_path_ogg := "res://assets/audio/%s.ogg" % sound_name
	var custom_path_mp3 := "res://assets/audio/%s.mp3" % sound_name
	
	if FileAccess.file_exists(custom_path_wav):
		var custom_stream := load(custom_path_wav)
		if custom_stream != null:
			p.stream = custom_stream
			p.play()
			return
	elif FileAccess.file_exists(custom_path_ogg):
		var custom_stream := load(custom_path_ogg)
		if custom_stream != null:
			p.stream = custom_stream
			p.play()
			return
	elif FileAccess.file_exists(custom_path_mp3):
		var custom_stream := load(custom_path_mp3)
		if custom_stream != null:
			p.stream = custom_stream
			p.play()
			return
			
	p.stream = streams[sound_name]
	p.play()

func _generate_all_sounds() -> void:
	streams["click"] = _generate_heavy_click()
	streams["draw"] = _generate_heavy_draw()
	streams["play"] = _generate_heavy_play()
	streams["heal"] = _generate_heavy_heal()
	streams["hit"] = _generate_heavy_hit()
	streams["victory"] = _generate_heavy_fanfare(true)
	streams["defeat"] = _generate_heavy_fanfare(false)
	streams["hover"] = _generate_heavy_hover()

func _generate_heavy_click() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	
	var duration: float = 0.08
	var num_samples: int = int(44100.0 * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var phase_carrier: float = 0.0
	var phase_mod: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / 44100.0
		var progress: float = t / duration
		
		# Solid stone slot click: carrier 90Hz, modulator 130Hz
		phase_carrier += (90.0 * 2.0 * PI) / 44100.0
		phase_mod += (130.0 * 2.0 * PI) / 44100.0
		
		var mod: float = sin(phase_mod) * 2.0
		var sample: float = sin(phase_carrier + mod)
		
		# Decays very rapidly
		var envelope: float = exp(-progress * 15.0)
		sample *= envelope * 0.45
		
		var int_sample: int = int(clamp(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, int_sample)
		
	stream.data = bytes
	return stream

func _generate_heavy_draw() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	
	var duration: float = 0.32
	var num_samples: int = int(44100.0 * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var phase_base: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / 44100.0
		var progress: float = t / duration
		
		# Low card dragging sound: 70Hz to 120Hz sweep
		var freq: float = lerp(70.0, 120.0, progress)
		phase_base += (freq * 2.0 * PI) / 44100.0
		
		var noise: float = randf_range(-1.0, 1.0)
		var base_wave: float = sin(phase_base)
		var sample: float = base_wave * 0.25 + noise * 0.62
		
		# Slide whoosh envelope: sweeps up, decays
		var envelope: float = sin(progress * PI)
		sample *= envelope * 0.38
		
		var int_sample: int = int(clamp(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, int_sample)
		
	stream.data = bytes
	return stream

func _generate_heavy_play() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	
	var duration: float = 0.42
	var num_samples: int = int(44100.0 * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var phase_bass: float = 0.0
	var phase_snap: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / 44100.0
		var progress: float = t / duration
		
		# Sub-bass thud: 52Hz down to 40Hz
		var freq_bass: float = lerp(52.0, 40.0, progress)
		phase_bass += (freq_bass * 2.0 * PI) / 44100.0
		var bass: float = sin(phase_bass)
		
		# FM snap: carrier 220Hz, modulator 310Hz
		phase_snap += (220.0 * 2.0 * PI) / 44100.0
		var snap: float = sin(phase_snap + sin(phase_snap * 1.41) * 3.0)
		
		var bass_env: float = exp(-progress * 6.5)
		var snap_env: float = exp(-progress * 18.0)
		var noise: float = randf_range(-1.0, 1.0) * 0.12 * snap_env
		
		var sample: float = (bass * 0.65 * bass_env) + (snap * 0.3 * snap_env) + noise
		sample = clamp(sample * 1.2, -1.0, 1.0)
		
		var int_sample: int = int(clamp(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, int_sample)
		
	stream.data = bytes
	return stream

func _generate_heavy_heal() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	
	var duration: float = 0.75
	var num_samples: int = int(44100.0 * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var phases: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var freqs: Array[float] = [146.83, 185.0, 220.0, 293.66] # D3 chord
	
	for i in range(num_samples):
		var t: float = float(i) / 44100.0
		var progress: float = t / duration
		
		var sample: float = 0.0
		for j in range(freqs.size()):
			phases[j] += (freqs[j] * 2.0 * PI) / 44100.0
			var carrier: float = phases[j]
			var modulator: float = sin(carrier * 1.5) * 0.25
			sample += sin(carrier + modulator)
			
		sample = sample / float(freqs.size())
		
		var envelope: float = (1.0 - progress) * (1.0 - progress) * (1.0 - progress)
		sample *= envelope * 0.45
		
		var int_sample: int = int(clamp(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, int_sample)
		
	stream.data = bytes
	return stream

func _generate_heavy_hit() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	
	var duration: float = 0.28
	var num_samples: int = int(44100.0 * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var phase_bass: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / 44100.0
		var progress: float = t / duration
		
		# Distorted low frequency slam sweep
		var freq: float = lerp(90.0, 30.0, progress)
		phase_bass += (freq * 2.0 * PI) / 44100.0
		
		var bass: float = sin(phase_bass)
		var noise: float = randf_range(-1.0, 1.0)
		
		var raw_sample: float = bass * 0.58 + noise * 0.42
		var sample: float = clamp(raw_sample * 2.6, -1.0, 1.0)
		
		var envelope: float = exp(-progress * 8.5)
		sample *= envelope * 0.45
		
		var int_sample: int = int(clamp(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, int_sample)
		
	stream.data = bytes
	return stream

func _generate_heavy_fanfare(is_win: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	
	var duration: float = 1.5 if is_win else 1.8
	var num_samples: int = int(44100.0 * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var win_notes: Array[float] = [98.00, 123.47, 146.83, 196.00, 246.94]
	var lose_notes: Array[float] = [82.41, 77.78, 65.41, 55.00, 48.99]
	var notes: Array[float] = win_notes if is_win else lose_notes
	
	var phases_f: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	var phases_u: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	var phases_l: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	
	for i in range(num_samples):
		var t: float = float(i) / 44100.0
		var progress: float = t / duration
		
		var note_idx: int = int(progress * notes.size()) % notes.size()
		var freq: float = notes[note_idx]
		
		phases_f[note_idx] += (freq * 2.0 * PI) / 44100.0
		phases_u[note_idx] += (freq * 1.015 * 2.0 * PI) / 44100.0
		phases_l[note_idx] += (freq * 0.985 * 2.0 * PI) / 44100.0
		
		var fundamental: float = sin(phases_f[note_idx])
		var detuned_upper: float = sin(phases_u[note_idx]) * 0.4
		var detuned_lower: float = sin(phases_l[note_idx]) * 0.4
		
		var horn_sample: float = fundamental + detuned_upper + detuned_lower
		var sample: float = clamp(horn_sample * 1.4, -1.0, 1.0)
		
		var note_progress: float = fmod(progress * notes.size(), 1.0)
		var note_envelope: float = exp(-note_progress * 4.5)
		var global_envelope: float = (1.0 - progress) * (1.0 - progress)
		
		sample *= note_envelope * global_envelope * (0.24 if is_win else 0.32)
		var int_sample: int = int(clamp(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, int_sample)
		
	stream.data = bytes
	return stream

func _generate_heavy_hover() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	
	var duration: float = 0.035
	var num_samples: int = int(44100.0 * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var phase: float = 0.0
	for i in range(num_samples):
		var t: float = float(i) / 44100.0
		var progress: float = t / duration
		
		# High-frequency tap: 480Hz down to 320Hz sweep
		var freq: float = lerp(480.0, 320.0, progress)
		phase += (freq * 2.0 * PI) / 44100.0
		var sample: float = sin(phase)
		
		var envelope: float = exp(-progress * 18.0)
		sample *= envelope * 0.18
		
		var int_sample: int = int(clamp(sample, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, int_sample)
		
	stream.data = bytes
	return stream

