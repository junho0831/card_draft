extends Node
class_name AudioManager

const SAMPLE_RATE := 44100

var players: Array[AudioStreamPlayer] = []
var max_players := 12
var current_player_idx := 0

var streams := {}
var custom_streams := {}
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
	_load_custom_sounds()

func _exit_tree() -> void:
	for player in players:
		if player == null or not is_instance_valid(player):
			continue
		player.stop()
		player.stream = null
	players.clear()
	custom_streams.clear()
	streams.clear()

func play_sound(sound_name: String) -> void:
	if _is_headless_runtime():
		return
	if not streams.has(sound_name):
		return
	if players.is_empty():
		return
	
	var p := players[current_player_idx]
	current_player_idx = (current_player_idx + 1) % max_players
	p.volume_db = float(sound_volume_db.get(sound_name, -3.5))
	var jitter := float(sound_pitch_jitter.get(sound_name, 0.0))
	p.pitch_scale = 1.0 + rng.randf_range(-jitter, jitter)

	p.stream = custom_streams.get(sound_name, streams[sound_name])
	p.play()

func _is_headless_runtime() -> bool:
	return DisplayServer.get_name() == "headless"

func _load_custom_sounds() -> void:
	custom_streams.clear()
	for sound_name in streams.keys():
		for extension in ["wav", "ogg", "mp3"]:
			var custom_path := "res://assets/audio/%s.%s" % [sound_name, extension]
			if not FileAccess.file_exists(custom_path):
				continue
			var custom_stream = _load_wav_stream(custom_path) if extension == "wav" else load(custom_path)
			if custom_stream != null:
				custom_streams[sound_name] = custom_stream
				break

func _load_wav_stream(path: String) -> AudioStreamWAV:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	if bytes.size() < 44:
		return null
	if _read_ascii(bytes, 0, 4) != "RIFF" or _read_ascii(bytes, 8, 4) != "WAVE":
		return null

	var channels := 1
	var sample_rate := SAMPLE_RATE
	var bits_per_sample := 16
	var data := PackedByteArray()
	var offset := 12
	while offset + 8 <= bytes.size():
		var chunk_id := _read_ascii(bytes, offset, 4)
		var chunk_size := _read_u32_le(bytes, offset + 4)
		var chunk_start := offset + 8
		var chunk_end: int = min(chunk_start + chunk_size, bytes.size())
		if chunk_id == "fmt " and chunk_size >= 16:
			var audio_format := _read_u16_le(bytes, chunk_start)
			if audio_format != 1:
				return null
			channels = _read_u16_le(bytes, chunk_start + 2)
			sample_rate = _read_u32_le(bytes, chunk_start + 4)
			bits_per_sample = _read_u16_le(bytes, chunk_start + 14)
		elif chunk_id == "data":
			data = bytes.slice(chunk_start, chunk_end)
		offset = chunk_end + int(chunk_size % 2)

	if data.is_empty() or bits_per_sample != 16:
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = channels == 2
	stream.data = data
	return stream

func _read_ascii(bytes: PackedByteArray, offset: int, length: int) -> String:
	var chars := PackedByteArray()
	chars.resize(length)
	for i in range(length):
		chars[i] = bytes[offset + i]
	return chars.get_string_from_ascii()

func _read_u16_le(bytes: PackedByteArray, offset: int) -> int:
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8)

func _read_u32_le(bytes: PackedByteArray, offset: int) -> int:
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8) | (int(bytes[offset + 2]) << 16) | (int(bytes[offset + 3]) << 24)

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
		"click": -8.0,
		"draw": -6.8,
		"play": -2.8,
		"summon": -1.6,
		"spell": -2.8,
		"counter": -3.4,
		"hit": -1.9,
		"finisher": -0.8,
		"combo": -2.6,
		"heal": -5.0,
		"reward": -3.6,
		"victory": -1.8,
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
	var bytes: PackedByteArray = parts["bytes"]
	var peak := 0
	for i in range(int(parts["samples"])):
		peak = maxi(peak, absi(bytes.decode_s16(i * 2)))
	var target_peak := int(32767.0 * 0.88)
	if peak > target_peak:
		var scale := float(target_peak) / float(peak)
		for i in range(int(parts["samples"])):
			bytes.encode_s16(i * 2, int(float(bytes.decode_s16(i * 2)) * scale))
	stream.data = bytes
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

func _triangle_wave(phase: float) -> float:
	return (2.0 / PI) * asin(sin(phase))

func _impact_after(progress: float, start: float, decay: float) -> float:
	if progress < start:
		return 0.0
	return exp(-((progress - start) / max(0.001, 1.0 - start)) * decay)

func _generate_rune_click() -> AudioStreamWAV:
	var duration := 0.15
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_body := 0.0
	var phase_metal_a := 0.0
	var phase_metal_b := 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_body += (lerpf(112.0, 72.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_metal_a += (536.0 * 2.0 * PI) / float(SAMPLE_RATE)
		phase_metal_b += (927.0 * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.18)
		var body: float = _triangle_wave(phase_body) * exp(-p * 17.0) * 0.52
		var metal: float = (sin(phase_metal_a) * 0.16 + sin(phase_metal_b) * 0.08) * exp(-p * 9.0)
		var grit: float = (raw_noise - noise_lp) * exp(-p * 26.0) * 0.11
		_write_sample(bytes, i, _saturate(body + metal + grit, 1.45))
	return _finish_stream(parts)

func _generate_card_draw() -> AudioStreamWAV:
	var duration := 0.46
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_rub := 0.0
	var phase_settle := 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_rub += (lerpf(176.0, 92.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_settle += (lerpf(104.0, 62.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.075)
		var swipe_env: float = pow(sin(p * PI), 0.72)
		var paper: float = (raw_noise - noise_lp) * swipe_env * 0.34
		var grain: float = _triangle_wave(phase_rub) * swipe_env * (0.08 + absf(sin(p * PI * 7.0)) * 0.08)
		var settle: float = _triangle_wave(phase_settle) * _impact_after(p, 0.76, 13.0) * 0.34
		_write_sample(bytes, i, _saturate(paper + grain + settle, 1.35))
	return _finish_stream(parts)

func _generate_card_play_slam() -> AudioStreamWAV:
	var duration := 0.64
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_sub: float = 0.0
	var phase_leather: float = 0.0
	var phase_resonance: float = 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_sub += (lerpf(76.0, 34.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_leather += (lerpf(154.0, 82.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_resonance += (238.0 * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.12)
		var first_hit: float = exp(-p * 14.0)
		var table_hit: float = _impact_after(p, 0.055, 10.0)
		var sub: float = sin(phase_sub) * (first_hit + table_hit * 0.42) * 0.82
		var leather: float = _triangle_wave(phase_leather) * first_hit * 0.32
		var slap: float = (raw_noise - noise_lp) * exp(-p * 34.0) * 0.42
		var resonance: float = sin(phase_resonance) * exp(-p * 5.2) * 0.12
		_write_sample(bytes, i, _saturate(sub + leather + slap + resonance, 2.15))
	return _finish_stream(parts)

func _generate_summon_drop() -> AudioStreamWAV:
	var duration := 1.08
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_portal: float = 0.0
	var phase_sub: float = 0.0
	var phase_rune_a := 0.0
	var phase_rune_b := 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_portal += (lerpf(214.0, 68.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_sub += (lerpf(61.0, 29.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_rune_a += (417.0 * 2.0 * PI) / float(SAMPLE_RATE)
		phase_rune_b += (691.0 * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.045)
		var charge: float = smoothstep(0.0, 0.32, p) * (1.0 - smoothstep(0.34, 0.78, p))
		var landing: float = _impact_after(p, 0.31, 7.2)
		var portal: float = _triangle_wave(phase_portal) * charge * 0.28
		var mist: float = noise_lp * charge * 0.36
		var sub: float = sin(phase_sub) * landing * 0.98
		var rune: float = (sin(phase_rune_a) * 0.13 + sin(phase_rune_b) * 0.07) * _impact_after(p, 0.25, 3.4)
		var debris: float = (raw_noise - noise_lp) * landing * 0.24
		_write_sample(bytes, i, _saturate(portal + mist + sub + rune + debris, 2.2))
	return _finish_stream(parts)

func _generate_spell_cast() -> AudioStreamWAV:
	var duration := 0.72
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_mag: float = 0.0
	var phase_sub: float = 0.0
	var phase_glass := 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_mag += (lerpf(246.0, 786.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_sub += (lerpf(82.0, 39.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_glass += (1217.0 * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.08)
		var charge: float = pow(sin(p * PI), 0.72)
		var release: float = _impact_after(p, 0.58, 8.0)
		var arcane: float = _triangle_wave(phase_mag) * charge * 0.24
		var sub: float = sin(phase_sub) * (exp(-p * 5.0) + release * 0.65) * 0.5
		var sparks: float = (raw_noise - noise_lp) * charge * (0.14 + release * 0.22)
		var glass: float = sin(phase_glass) * release * 0.09
		_write_sample(bytes, i, _saturate(arcane + sub + sparks + glass, 1.8))
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
	var duration := 0.5
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_sub: float = 0.0
	var phase_blade_a: float = 0.0
	var phase_blade_b: float = 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_sub += (lerpf(96.0, 31.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_blade_a += (lerpf(612.0, 284.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_blade_b += (1049.0 * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.16)
		var impact: float = exp(-p * 12.0)
		var body: float = sin(phase_sub) * impact * 1.02
		var blade: float = (sin(phase_blade_a) * 0.32 + sin(phase_blade_b) * 0.1) * exp(-p * 10.0)
		var crunch: float = (raw_noise * 0.55 + noise_lp * 0.45) * exp(-p * 19.0) * 0.38
		var recoil: float = sin(phase_sub * 0.52) * _impact_after(p, 0.075, 9.0) * 0.32
		_write_sample(bytes, i, _saturate(body + blade + crunch + recoil, 2.5))
	return _finish_stream(parts)

func _generate_counter_hit() -> AudioStreamWAV:
	var duration := 0.5
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_low: float = 0.0
	var phase_clang_a: float = 0.0
	var phase_clang_b: float = 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_low += (lerpf(78.0, 39.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_clang_a += (lerpf(746.0, 518.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_clang_b += (1283.0 * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.14)
		var low: float = sin(phase_low) * exp(-p * 8.0) * 0.62
		var clang: float = (sin(phase_clang_a) * 0.32 + sin(phase_clang_b) * 0.13) * exp(-p * 7.0)
		var scrape: float = (raw_noise - noise_lp) * exp(-p * 20.0) * 0.22
		var recoil: float = sin(phase_low * 0.5) * _impact_after(p, 0.09, 10.0) * 0.24
		_write_sample(bytes, i, _saturate(low + clang + scrape + recoil, 2.1))
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
	var duration := 1.24
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_low: float = 0.0
	var phase_gong_a: float = 0.0
	var phase_gong_b: float = 0.0
	var phase_blade: float = 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_low += (lerpf(92.0, 24.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_gong_a += (113.0 * 2.0 * PI) / float(SAMPLE_RATE)
		phase_gong_b += (291.0 * 2.0 * PI) / float(SAMPLE_RATE)
		phase_blade += (lerpf(684.0, 232.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.08)
		var impact: float = exp(-p * 7.5)
		var aftershock: float = _impact_after(p, 0.32, 5.2)
		var last_boom: float = _impact_after(p, 0.57, 7.0)
		var sub: float = sin(phase_low) * (impact + aftershock * 0.48 + last_boom * 0.32) * 1.08
		var gong: float = (sin(phase_gong_a) * 0.34 + sin(phase_gong_b) * 0.16) * exp(-p * 2.1)
		var blade: float = _triangle_wave(phase_blade) * exp(-p * 13.0) * 0.2
		var break_noise: float = (raw_noise * 0.6 + noise_lp * 0.4) * (impact + aftershock * 0.5) * 0.34
		_write_sample(bytes, i, _saturate(sub + gong + blade + break_noise, 2.65))
	return _finish_stream(parts)

func _generate_reward_chime() -> AudioStreamWAV:
	var duration := 1.12
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var notes: Array[float] = [174.61, 220.0, 261.63]
	var phases: Array[float] = [0.0, 0.0, 0.0]
	var upper_phases: Array[float] = [0.0, 0.0, 0.0]
	var phase_low: float = 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_low += (65.41 * 2.0 * PI) / float(SAMPLE_RATE)
		var sample: float = 0.0
		for j in range(notes.size()):
			phases[j] += (notes[j] * 2.0 * PI) / float(SAMPLE_RATE)
			upper_phases[j] += (notes[j] * 2.73 * 2.0 * PI) / float(SAMPLE_RATE)
			var note_start: float = float(j) * 0.12
			var note_env: float = _impact_after(p, note_start, 4.2)
			sample += (sin(phases[j]) * 0.27 + sin(upper_phases[j]) * 0.1) * note_env
		var bell: float = sample
		var low: float = sin(phase_low) * exp(-p * 3.4) * 0.18
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
	var duration: float = 0.045
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_body := 0.0
	var phase_metal := 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var progress: float = t / duration
		phase_body += (lerpf(286.0, 148.0, progress) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_metal += (812.0 * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.2)
		var envelope: float = exp(-progress * 18.0)
		var sample: float = _triangle_wave(phase_body) * envelope * 0.12
		sample += sin(phase_metal) * envelope * 0.035
		sample += (raw_noise - noise_lp) * envelope * 0.03
		_write_sample(bytes, i, sample)
	return _finish_stream(parts)
