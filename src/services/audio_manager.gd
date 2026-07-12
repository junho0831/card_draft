extends Node
class_name AudioManager

const SAMPLE_RATE := 44100

var players: Array[AudioStreamPlayer] = []
var max_players := 12
var current_player_idx := 0

var streams := {}
var sound_volume_db := {}
var sound_pitch_jitter := {}
var rng := RandomNumberGenerator.new()

func _init() -> void:
	name = "AudioManager"
	rng.seed = 916273
	_generate_all_sounds()

func _ready() -> void:
	for i in range(max_players):
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

func play_sound(sound_name: String) -> void:
	if not streams.has(sound_name):
		return
	if players.is_empty():
		return
	
	var p := players[current_player_idx]
	current_player_idx = (current_player_idx + 1) % max_players
	p.volume_db = float(sound_volume_db.get(sound_name, -3.5))
	var jitter := float(sound_pitch_jitter.get(sound_name, 0.0))
	p.pitch_scale = 1.0 + rng.randf_range(-jitter, jitter)
	
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
	streams["click"] = _generate_rune_click()
	streams["draw"] = _generate_card_draw()
	streams["play"] = _generate_card_play_slam()
	streams["summon"] = _generate_summon_drop()
	streams["spell"] = _generate_spell_cast()
	streams["counter"] = _generate_counter_hit()
	streams["heal"] = _generate_heal_chord()
	streams["hit"] = _generate_weapon_hit()
	streams["combo"] = _generate_combo_burst()
	streams["finisher"] = _generate_finisher_slam()
	streams["reward"] = _generate_reward_chime()
	streams["victory"] = _generate_heavy_fanfare(true)
	streams["defeat"] = _generate_heavy_fanfare(false)
	streams["hover"] = _generate_hover_tick()

	sound_volume_db = {
		"hover": -18.0,
		"click": -9.0,
		"draw": -8.5,
		"play": -3.8,
		"summon": -2.8,
		"spell": -4.0,
		"counter": -4.4,
		"hit": -2.8,
		"finisher": -1.8,
		"combo": -4.0,
		"heal": -6.0,
		"reward": -5.0,
		"victory": -3.0,
		"defeat": -3.5,
	}
	sound_pitch_jitter = {
		"click": 0.025,
		"draw": 0.018,
		"play": 0.02,
		"summon": 0.018,
		"spell": 0.025,
		"hit": 0.035,
		"counter": 0.035,
		"finisher": 0.012,
	}

func _new_stream(duration: float) -> Dictionary:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	var num_samples := int(float(SAMPLE_RATE) * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	return {"stream": stream, "bytes": bytes, "samples": num_samples}

func _finish_stream(parts: Dictionary) -> AudioStreamWAV:
	var stream: AudioStreamWAV = parts["stream"]
	stream.data = parts["bytes"]
	return stream

func _write_sample(bytes: PackedByteArray, index: int, sample: float) -> void:
	bytes.encode_s16(index * 2, int(clamp(sample, -1.0, 1.0) * 32767.0))

func _saturate(sample: float, drive: float = 1.0) -> float:
	var driven := sample * drive
	return clamp(driven / (1.0 + abs(driven) * 0.42), -1.0, 1.0)

func _hit_envelope(progress: float, attack: float, decay: float) -> float:
	if progress < attack:
		return progress / max(0.001, attack)
	return exp(-(progress - attack) * decay)

func _release_envelope(progress: float, curve: float = 2.0) -> float:
	return pow(max(0.0, 1.0 - progress), curve)

func _generate_rune_click() -> AudioStreamWAV:
	var duration := 0.18
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_low: float = 0.0
	var phase_mid: float = 0.0
	var phase_metal: float = 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_low += (54.0 * 2.0 * PI) / float(SAMPLE_RATE)
		phase_mid += (120.0 * 2.0 * PI) / float(SAMPLE_RATE)
		phase_metal += (680.0 * 2.0 * PI) / float(SAMPLE_RATE)
		
		var bass: float = sin(phase_low) * exp(-p * 14.0) * 0.65
		var wood: float = sin(phase_mid + sin(phase_mid * 1.5) * 0.4) * exp(-p * 12.0) * 0.35
		var ring: float = sin(phase_metal) * exp(-p * 6.5) * 0.15
		var dust: float = rng.randf_range(-1.0, 1.0) * exp(-p * 20.0) * 0.08
		_write_sample(bytes, i, _saturate(bass + wood + ring + dust, 1.35))
	return _finish_stream(parts)

func _generate_card_draw() -> AudioStreamWAV:
	var duration := 0.52
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_whoosh: float = 0.0
	var phase_rub: float = 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_whoosh += (lerp(320.0, 110.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_rub += (lerp(180.0, 90.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		
		var envelope: float = sin(p * PI)
		var whoosh: float = sin(phase_whoosh) * envelope * 0.32
		var rub: float = sin(phase_rub + sin(phase_rub * 0.45) * 1.8) * envelope * 0.28
		var noise: float = rng.randf_range(-1.0, 1.0) * envelope * 0.28
		_write_sample(bytes, i, _saturate(whoosh + rub + noise, 1.15))
	return _finish_stream(parts)

func _generate_card_play_slam() -> AudioStreamWAV:
	var duration := 0.82
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_sub: float = 0.0
	var phase_stone: float = 0.0
	var phase_echo: float = 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_sub += (lerp(52.0, 28.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_stone += (lerp(120.0, 74.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_echo += (lerp(240.0, 180.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		
		var impact: float = _hit_envelope(p, 0.02, 6.5)
		var tail: float = _release_envelope(p, 1.8)
		
		var sub: float = sin(phase_sub) * impact * 0.92
		var stone: float = sin(phase_stone + sin(phase_stone * 1.6) * 0.6) * impact * 0.44
		var echo: float = sin(phase_echo) * exp(-p * 4.2) * 0.22
		var dust: float = rng.randf_range(-1.0, 1.0) * tail * 0.16
		
		_write_sample(bytes, i, _saturate(sub + stone + echo + dust, 2.1))
	return _finish_stream(parts)

func _generate_summon_drop() -> AudioStreamWAV:
	var duration := 0.85
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_portal: float = 0.0
	var phase_sub: float = 0.0
	var phase_shimmer: float = 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_portal += (lerp(180.0, 52.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_sub += (lerp(58.0, 32.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_shimmer += (lerp(440.0, 330.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		
		var rise: float = clamp(p / 0.12, 0.0, 1.0)
		var drop: float = exp(-max(0.0, p - 0.15) * 4.8)
		
		var portal: float = sin(phase_portal + sin(phase_portal * 1.8) * 1.6) * rise * drop * 0.48
		var sub: float = sin(phase_sub) * _hit_envelope(p, 0.15, 3.8) * 0.68
		var shimmer: float = sin(phase_shimmer) * exp(-max(0.0, p - 0.10) * 3.5) * 0.18
		var mist: float = rng.randf_range(-1.0, 1.0) * rise * drop * 0.12
		
		_write_sample(bytes, i, _saturate(portal + sub + shimmer + mist, 1.85))
	return _finish_stream(parts)

func _generate_spell_cast() -> AudioStreamWAV:
	var duration := 0.62
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_mag: float = 0.0
	var phase_sub: float = 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_mag += (lerp(380.0, 920.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_sub += (lerp(74.0, 38.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		
		var env: float = sin(p * PI)
		var spell: float = sin(phase_mag + sin(phase_mag * 0.45) * 3.6) * env * 0.42
		var sub: float = sin(phase_sub) * exp(-p * 4.5) * 0.52
		var sparks: float = rng.randf_range(-1.0, 1.0) * env * 0.22
		
		_write_sample(bytes, i, _saturate(spell + sub + sparks, 1.65))
	return _finish_stream(parts)

func _generate_heal_chord() -> AudioStreamWAV:
	var duration := 1.25
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phases: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	var freqs: Array[float] = [130.81, 164.81, 196.0, 261.63, 329.63]
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		var sample: float = 0.0
		for j in range(freqs.size()):
			phases[j] += (freqs[j] * 2.0 * PI) / float(SAMPLE_RATE)
			sample += sin(phases[j] + sin(phases[j] * 0.4) * 0.28) * (0.38 - float(j) * 0.04)
		var bell_phase_a: float = 2.0 * PI * 523.25 * t
		var bell_phase_b: float = 2.0 * PI * 659.25 * t
		var bell: float = (sin(bell_phase_a) + sin(bell_phase_b) * 0.7) * exp(-p * 3.2) * 0.16
		
		var organ: float = sample * _release_envelope(p, 1.8) * 0.62
		_write_sample(bytes, i, _saturate(organ + bell, 1.3))
	return _finish_stream(parts)

func _generate_weapon_hit() -> AudioStreamWAV:
	var duration := 0.48
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_sub: float = 0.0
	var phase_blade: float = 0.0
	var phase_ring: float = 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_sub += (lerp(88.0, 24.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_blade += (lerp(380.0, 160.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_ring += (1040.0 * 2.0 * PI) / float(SAMPLE_RATE)
		
		var impact: float = _hit_envelope(p, 0.01, 8.5)
		var sub: float = sin(phase_sub) * impact * 0.94
		var blade: float = sin(phase_blade + sin(phase_blade * 1.8) * 1.8) * exp(-p * 11.0) * 0.44
		var ring: float = sin(phase_ring) * exp(-p * 7.0) * 0.16
		var blood: float = rng.randf_range(-1.0, 1.0) * exp(-p * 14.0) * 0.32
		
		_write_sample(bytes, i, _saturate(sub + blade + ring + blood, 2.35))
	return _finish_stream(parts)

func _generate_counter_hit() -> AudioStreamWAV:
	var duration := 0.38
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_low: float = 0.0
	var phase_clang: float = 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_low += (lerp(64.0, 36.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_clang += (lerp(880.0, 620.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		
		var low: float = sin(phase_low) * exp(-p * 7.2) * 0.62
		var clang: float = sin(phase_clang + sin(phase_clang * 0.8) * 1.2) * exp(-p * 9.5) * 0.28
		var grit: float = rng.randf_range(-1.0, 1.0) * exp(-p * 18.0) * 0.22
		
		_write_sample(bytes, i, _saturate(low + clang + grit, 2.05))
	return _finish_stream(parts)

func _generate_combo_burst() -> AudioStreamWAV:
	var duration := 0.62
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_low: float = 0.0
	var phase_a: float = 0.0
	var phase_b: float = 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_low += (lerp(86.0, 54.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_a += (lerp(220.0, 392.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_b += (lerp(329.63, 587.33, p) * 2.0 * PI) / float(SAMPLE_RATE)
		var low: float = sin(phase_low) * exp(-p * 5.0) * 0.44
		var chant: float = (sin(phase_a) * 0.32 + sin(phase_b) * 0.24) * _release_envelope(p, 1.5)
		var dust: float = rng.randf_range(-1.0, 1.0) * exp(-p * 7.5) * 0.09
		_write_sample(bytes, i, _saturate(low + chant + dust, 1.45))
	return _finish_stream(parts)

func _generate_finisher_slam() -> AudioStreamWAV:
	var duration := 0.95
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_low: float = 0.0
	var phase_gong: float = 0.0
	var phase_blade: float = 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_low += (lerp(88.0, 22.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_gong += (110.0 * 2.0 * PI) / float(SAMPLE_RATE)
		phase_blade += (lerp(580.0, 220.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		
		var impact: float = _hit_envelope(p, 0.008, 5.2)
		var sub: float = sin(phase_low) * impact * 1.12
		var gong: float = sin(phase_gong + sin(phase_gong * 1.8) * 0.46) * exp(-p * 1.8) * 0.38
		var blade: float = sin(phase_blade) * exp(-p * 12.0) * 0.22
		var burst: float = rng.randf_range(-1.0, 1.0) * exp(-p * 14.0) * 0.28
		
		_write_sample(bytes, i, _saturate(sub + gong + blade + burst, 2.45))
	return _finish_stream(parts)

func _generate_reward_chime() -> AudioStreamWAV:
	var duration := 0.88
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var notes: Array[float] = [196.0, 246.94, 293.66]
	var phases: Array[float] = [0.0, 0.0, 0.0]
	var phase_low: float = 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_low += (73.42 * 2.0 * PI) / float(SAMPLE_RATE)
		var sample: float = 0.0
		for j in range(notes.size()):
			phases[j] += (notes[j] * 2.0 * PI) / float(SAMPLE_RATE)
			sample += sin(phases[j] + sin(phases[j] * 0.75) * 0.18) * (0.36 - float(j) * 0.04)
		var bell: float = sample * exp(-p * 2.8)
		var low: float = sin(phase_low) * exp(-p * 3.2) * 0.22
		_write_sample(bytes, i, _saturate(bell + low, 1.25))
	return _finish_stream(parts)

func _generate_heavy_fanfare(is_win: bool) -> AudioStreamWAV:
	var duration: float = 1.9 if is_win else 1.7
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var win_notes: Array[float] = [73.42, 98.00, 123.47, 146.83, 196.00]
	var lose_notes: Array[float] = [82.41, 73.42, 65.41, 55.00, 49.00]
	var notes: Array[float] = win_notes if is_win else lose_notes
	var phases_f: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	var phases_u: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	var phases_l: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	var phase_drum: float = 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var progress: float = t / duration
		var note_idx: int = int(progress * notes.size()) % notes.size()
		var freq: float = notes[note_idx]
		phases_f[note_idx] += (freq * 2.0 * PI) / float(SAMPLE_RATE)
		phases_u[note_idx] += (freq * 1.012 * 2.0 * PI) / float(SAMPLE_RATE)
		phases_l[note_idx] += (freq * 0.988 * 2.0 * PI) / float(SAMPLE_RATE)
		phase_drum += (49.0 * 2.0 * PI) / float(SAMPLE_RATE)
		var fundamental: float = sin(phases_f[note_idx])
		var detuned_upper: float = sin(phases_u[note_idx]) * 0.36
		var detuned_lower: float = sin(phases_l[note_idx]) * 0.36
		var note_progress: float = fmod(progress * notes.size(), 1.0)
		var note_envelope: float = _hit_envelope(note_progress, 0.035, 3.8)
		var global_envelope: float = _release_envelope(progress, 1.25 if is_win else 1.05)
		var horn_sample: float = (fundamental + detuned_upper + detuned_lower) * note_envelope * global_envelope
		var drum: float = sin(phase_drum) * exp(-note_progress * 12.0) * global_envelope * (0.28 if is_win else 0.22)
		var sample: float = horn_sample * (0.34 if is_win else 0.40) + drum
		_write_sample(bytes, i, _saturate(sample, 1.45))
	return _finish_stream(parts)

func _generate_hover_tick() -> AudioStreamWAV:
	var duration: float = 0.028
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase: float = 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var progress: float = t / duration
		var freq: float = lerp(220.0, 110.0, progress)
		phase += (freq * 2.0 * PI) / float(SAMPLE_RATE)
		var sample: float = sin(phase)
		var envelope: float = exp(-progress * 14.0)
		sample *= envelope * 0.22
		_write_sample(bytes, i, sample)
	return _finish_stream(parts)

