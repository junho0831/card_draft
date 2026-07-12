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
	var duration := 0.12
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_low := 0.0
	var phase_tick := 0.0
	for i in range(int(parts["samples"])):
		var t := float(i) / float(SAMPLE_RATE)
		var p := t / duration
		phase_low += (86.0 * 2.0 * PI) / float(SAMPLE_RATE)
		phase_tick += (820.0 * 2.0 * PI) / float(SAMPLE_RATE)
		var thock := sin(phase_low) * exp(-p * 18.0) * 0.72
		var tick := sin(phase_tick) * exp(-p * 32.0) * 0.18
		var grit := rng.randf_range(-1.0, 1.0) * exp(-p * 24.0) * 0.12
		_write_sample(bytes, i, _saturate(thock + tick + grit, 1.45))
	return _finish_stream(parts)

func _generate_card_draw() -> AudioStreamWAV:
	var duration := 0.38
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_rub := 0.0
	var phase_body := 0.0
	for i in range(int(parts["samples"])):
		var t := float(i) / float(SAMPLE_RATE)
		var p := t / duration
		phase_rub += (lerp(150.0, 92.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_body += (58.0 * 2.0 * PI) / float(SAMPLE_RATE)
		var body := sin(phase_body) * sin(p * PI) * 0.18
		var rub := sin(phase_rub + sin(phase_rub * 0.57) * 1.6) * sin(p * PI) * 0.28
		var paper := rng.randf_range(-1.0, 1.0) * sin(p * PI) * 0.24
		_write_sample(bytes, i, _saturate(body + rub + paper, 1.25))
	return _finish_stream(parts)

func _generate_card_play_slam() -> AudioStreamWAV:
	var duration := 0.52
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_sub := 0.0
	var phase_wood := 0.0
	var phase_metal := 0.0
	for i in range(int(parts["samples"])):
		var t := float(i) / float(SAMPLE_RATE)
		var p := t / duration
		phase_sub += (lerp(72.0, 34.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_wood += (lerp(145.0, 92.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_metal += (lerp(520.0, 350.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		var impact := _hit_envelope(p, 0.018, 8.5)
		var click := exp(-p * 42.0)
		var tail := _release_envelope(p, 1.7)
		var sub := sin(phase_sub) * impact * 0.82
		var wood := sin(phase_wood + sin(phase_wood * 1.8) * 0.8) * impact * 0.38
		var metal := sin(phase_metal) * click * 0.16
		var dust := rng.randf_range(-1.0, 1.0) * tail * 0.12
		_write_sample(bytes, i, _saturate(sub + wood + metal + dust, 1.85))
	return _finish_stream(parts)

func _generate_summon_drop() -> AudioStreamWAV:
	var duration := 0.72
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_gate := 0.0
	var phase_low := 0.0
	var phase_chime := 0.0
	for i in range(int(parts["samples"])):
		var t := float(i) / float(SAMPLE_RATE)
		var p := t / duration
		phase_gate += (lerp(118.0, 54.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_low += (lerp(64.0, 38.0, min(p * 1.6, 1.0)) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_chime += (293.66 * 2.0 * PI) / float(SAMPLE_RATE)
		var rise: float = clamp(p / 0.16, 0.0, 1.0)
		var drop: float = exp(-max(0.0, p - 0.18) * 5.8)
		var gate: float = sin(phase_gate + sin(phase_gate * 2.0) * 2.4) * rise * drop * 0.46
		var low: float = sin(phase_low) * _hit_envelope(p, 0.19, 4.8) * 0.66
		var chime: float = sin(phase_chime) * exp(-max(0.0, p - 0.10) * 7.0) * 0.12
		var ash: float = rng.randf_range(-1.0, 1.0) * rise * drop * 0.10
		_write_sample(bytes, i, _saturate(gate + low + chime + ash, 1.7))
	return _finish_stream(parts)

func _generate_spell_cast() -> AudioStreamWAV:
	var duration := 0.46
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_arc := 0.0
	var phase_low := 0.0
	for i in range(int(parts["samples"])):
		var t := float(i) / float(SAMPLE_RATE)
		var p := t / duration
		phase_arc += (lerp(220.0, 760.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_low += (lerp(82.0, 46.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		var arc := sin(phase_arc + sin(phase_arc * 0.5) * 3.2) * sin(p * PI) * 0.38
		var low := sin(phase_low) * exp(-p * 5.2) * 0.46
		var sparks := rng.randf_range(-1.0, 1.0) * sin(p * PI) * 0.18
		_write_sample(bytes, i, _saturate(arc + low + sparks, 1.55))
	return _finish_stream(parts)

func _generate_heal_chord() -> AudioStreamWAV:
	var duration := 0.95
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phases: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var freqs: Array[float] = [110.0, 146.83, 185.0, 220.0]
	for i in range(int(parts["samples"])):
		var t := float(i) / float(SAMPLE_RATE)
		var p := t / duration
		var sample := 0.0
		for j in range(freqs.size()):
			phases[j] += (freqs[j] * 2.0 * PI) / float(SAMPLE_RATE)
			sample += sin(phases[j] + sin(phases[j] * 0.5) * 0.32) * (0.42 - float(j) * 0.04)
		var shimmer := sin(2.0 * PI * 520.0 * t) * sin(p * PI) * 0.05
		_write_sample(bytes, i, _saturate((sample / 1.5 + shimmer) * _release_envelope(p, 2.2), 1.2))
	return _finish_stream(parts)

func _generate_weapon_hit() -> AudioStreamWAV:
	var duration := 0.42
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_sub := 0.0
	var phase_blade := 0.0
	var phase_ring := 0.0
	for i in range(int(parts["samples"])):
		var t := float(i) / float(SAMPLE_RATE)
		var p := t / duration
		phase_sub += (lerp(96.0, 32.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_blade += (lerp(360.0, 188.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_ring += (910.0 * 2.0 * PI) / float(SAMPLE_RATE)
		var impact := _hit_envelope(p, 0.012, 9.2)
		var sub := sin(phase_sub) * impact * 0.82
		var blade := sin(phase_blade + sin(phase_blade * 1.7) * 1.7) * exp(-p * 14.0) * 0.38
		var ring := sin(phase_ring) * exp(-p * 9.5) * 0.13
		var crack := rng.randf_range(-1.0, 1.0) * exp(-p * 18.0) * 0.28
		_write_sample(bytes, i, _saturate(sub + blade + ring + crack, 2.15))
	return _finish_stream(parts)

func _generate_counter_hit() -> AudioStreamWAV:
	var duration := 0.34
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_low := 0.0
	var phase_clang := 0.0
	for i in range(int(parts["samples"])):
		var t := float(i) / float(SAMPLE_RATE)
		var p := t / duration
		phase_low += (lerp(74.0, 44.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_clang += (lerp(760.0, 540.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		var sample := sin(phase_low) * exp(-p * 8.0) * 0.52
		sample += sin(phase_clang) * exp(-p * 12.0) * 0.22
		sample += rng.randf_range(-1.0, 1.0) * exp(-p * 20.0) * 0.18
		_write_sample(bytes, i, _saturate(sample, 1.85))
	return _finish_stream(parts)

func _generate_combo_burst() -> AudioStreamWAV:
	var duration := 0.62
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_low := 0.0
	var phase_a := 0.0
	var phase_b := 0.0
	for i in range(int(parts["samples"])):
		var t := float(i) / float(SAMPLE_RATE)
		var p := t / duration
		phase_low += (lerp(86.0, 54.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_a += (lerp(220.0, 392.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_b += (lerp(329.63, 587.33, p) * 2.0 * PI) / float(SAMPLE_RATE)
		var low := sin(phase_low) * exp(-p * 5.0) * 0.44
		var chant := (sin(phase_a) * 0.32 + sin(phase_b) * 0.24) * _release_envelope(p, 1.5)
		var dust := rng.randf_range(-1.0, 1.0) * exp(-p * 7.5) * 0.09
		_write_sample(bytes, i, _saturate(low + chant + dust, 1.45))
	return _finish_stream(parts)

func _generate_finisher_slam() -> AudioStreamWAV:
	var duration := 0.78
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_low := 0.0
	var phase_gong := 0.0
	var phase_blade := 0.0
	for i in range(int(parts["samples"])):
		var t := float(i) / float(SAMPLE_RATE)
		var p := t / duration
		phase_low += (lerp(104.0, 30.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_gong += (146.83 * 2.0 * PI) / float(SAMPLE_RATE)
		phase_blade += (lerp(620.0, 320.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		var impact := _hit_envelope(p, 0.01, 6.2)
		var sub := sin(phase_low) * impact * 0.98
		var gong := sin(phase_gong + sin(phase_gong * 1.5) * 0.35) * exp(-p * 2.7) * 0.30
		var blade := sin(phase_blade) * exp(-p * 14.0) * 0.18
		var burst := rng.randf_range(-1.0, 1.0) * exp(-p * 16.0) * 0.24
		_write_sample(bytes, i, _saturate(sub + gong + blade + burst, 2.1))
	return _finish_stream(parts)

func _generate_reward_chime() -> AudioStreamWAV:
	var duration := 0.88
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var notes: Array[float] = [196.0, 246.94, 293.66]
	var phases: Array[float] = [0.0, 0.0, 0.0]
	var phase_low := 0.0
	for i in range(int(parts["samples"])):
		var t := float(i) / float(SAMPLE_RATE)
		var p := t / duration
		phase_low += (73.42 * 2.0 * PI) / float(SAMPLE_RATE)
		var sample := 0.0
		for j in range(notes.size()):
			phases[j] += (notes[j] * 2.0 * PI) / float(SAMPLE_RATE)
			sample += sin(phases[j] + sin(phases[j] * 0.75) * 0.18) * (0.36 - float(j) * 0.04)
		var bell := sample * exp(-p * 2.8)
		var low := sin(phase_low) * exp(-p * 3.2) * 0.22
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
	var phase_drum := 0.0
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
		var drum := sin(phase_drum) * exp(-note_progress * 12.0) * global_envelope * (0.28 if is_win else 0.22)
		var sample := horn_sample * (0.34 if is_win else 0.40) + drum
		_write_sample(bytes, i, _saturate(sample, 1.45))
	return _finish_stream(parts)

func _generate_hover_tick() -> AudioStreamWAV:
	var duration: float = 0.035
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase: float = 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var progress: float = t / duration
		var freq: float = lerp(480.0, 320.0, progress)
		phase += (freq * 2.0 * PI) / float(SAMPLE_RATE)
		var sample: float = sin(phase)
		var envelope: float = exp(-progress * 18.0)
		sample *= envelope * 0.18
		_write_sample(bytes, i, sample)
	return _finish_stream(parts)
