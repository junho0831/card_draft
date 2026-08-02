extends Node
class_name AudioManager

const SAMPLE_RATE := 44100
const SFX_BUS_NAME := &"SFX"
const BGM_BUS_NAME := &"BGM"
const BATTLE_MUSIC_KEYS := ["battle_base", "battle_tension", "battle_lethal", "battle_low_hp"]
const ELEVENLABS_SFX_KEYS := [
	"play",
	"draw",
	"hit_human",
	"hit_elf",
	"hit_undead",
	"hit_common",
	"impact_heavy",
	"summon_human",
	"summon_elf",
	"summon_undead",
	"summon_common",
	"spell_fire",
	"spell_death",
	"spell_buff",
	"spell_draw",
	"spell_summon",
	"spell_low_hp",
	"spell_common",
	"equipment_human",
	"equipment_elf",
	"equipment_undead",
	"equipment_common",
	"power_human",
	"power_elf",
	"power_undead",
	"combo",
	"counter",
	"finisher",
	"reward",
	"victory_burst",
]

var players: Array[AudioStreamPlayer] = []
var max_players := 12

var music_players := {}
var streams := {}
var custom_streams := {}
var music_streams := {}
var custom_music_streams := {}
var sound_volume_db := {}
var sound_pitch_jitter := {}
var current_battle_music_mode := "stopped"
var current_battle_music_signature := ""
var rng := RandomNumberGenerator.new()
var last_sound_at_msec := {}
var duck_until_msec := 0

func _init() -> void:
	name = "AudioManager"
	rng.seed = 916273
	_generate_all_sounds()
	_generate_all_music()

func _ready() -> void:
	_ensure_sfx_bus()
	_ensure_bgm_bus()
	for i in range(max_players):
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS_NAME
		add_child(p)
		players.append(p)
	_load_custom_sounds()
	_load_custom_music()
	_setup_battle_music_players()

func _exit_tree() -> void:
	for player in players:
		if player == null or not is_instance_valid(player):
			continue
		player.stop()
		player.stream = null
	for key in music_players.keys():
		var music_player: AudioStreamPlayer = music_players[key]
		if music_player == null or not is_instance_valid(music_player):
			continue
		music_player.stop()
		music_player.stream = null
	players.clear()
	music_players.clear()
	custom_streams.clear()
	custom_music_streams.clear()
	streams.clear()
	music_streams.clear()
	last_sound_at_msec.clear()

func play_sound(sound_name: String) -> void:
	if _is_headless_runtime():
		return
	if not streams.has(sound_name):
		return
	if players.is_empty():
		return
	var now_msec := Time.get_ticks_msec()
	var priority := _sound_priority(sound_name)
	var minimum_gap := _minimum_gap_msec(sound_name)
	if minimum_gap > 0 and now_msec - int(last_sound_at_msec.get(sound_name, -1000)) < minimum_gap:
		return
	var p := _claim_player(priority)
	if p == null:
		return
	var duck_db := -11.0 if now_msec < duck_until_msec and priority <= 1 else 0.0
	p.volume_db = float(sound_volume_db.get(sound_name, -3.5)) + duck_db
	var jitter := float(sound_pitch_jitter.get(sound_name, 0.0))
	p.pitch_scale = 1.0 + rng.randf_range(-jitter, jitter)
	p.set_meta("sfx_priority", priority)
	p.set_meta("sfx_started_msec", now_msec)
	p.stream = custom_streams.get(sound_name, streams[sound_name])
	p.play()
	last_sound_at_msec[sound_name] = now_msec
	var duck_duration := _duck_duration_msec(sound_name)
	if duck_duration > 0:
		duck_until_msec = maxi(duck_until_msec, now_msec + duck_duration)

func authored_sfx_keys() -> Array:
	return ELEVENLABS_SFX_KEYS.duplicate()

func has_authored_sfx(sound_name: String) -> bool:
	return custom_streams.has(sound_name)

func _ensure_sfx_bus() -> void:
	var bus_index := _ensure_bus(SFX_BUS_NAME)
	var has_limiter := false
	for effect_index in range(AudioServer.get_bus_effect_count(bus_index)):
		if AudioServer.get_bus_effect(bus_index, effect_index) is AudioEffectLimiter:
			has_limiter = true
			break
	if not has_limiter:
		AudioServer.add_bus_effect(bus_index, AudioEffectLimiter.new())

func _ensure_bgm_bus() -> void:
	var bus_index := _ensure_bus(BGM_BUS_NAME)
	AudioServer.set_bus_volume_db(bus_index, -3.0)

func _ensure_bus(bus_name: StringName) -> int:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, bus_name)
		AudioServer.set_bus_send(bus_index, &"Master")
	return bus_index

func set_battle_music_state(state: Dictionary) -> void:
	var mode := String(state.get("mode", "base"))
	if not BATTLE_MUSIC_KEYS.has("battle_%s" % mode):
		mode = "base"
	var signature := "%s:%s:%s:%s" % [
		mode,
		str(state.get("player_low_hp", false)),
		str(state.get("lethal", false)),
		str(state.get("boss", false)),
	]
	current_battle_music_mode = mode
	current_battle_music_signature = signature
	if _is_headless_runtime():
		return
	if music_players.is_empty():
		_setup_battle_music_players()
	_ensure_battle_music_playing()
	var targets := _battle_music_layer_targets(mode, state)
	for key in BATTLE_MUSIC_KEYS:
		_fade_music_layer(key, float(targets.get(key, -80.0)), 0.55)

func stop_battle_music() -> void:
	current_battle_music_mode = "stopped"
	current_battle_music_signature = "stopped"
	for key in music_players.keys():
		var player: AudioStreamPlayer = music_players[key]
		if player == null or not is_instance_valid(player):
			continue
		if _is_headless_runtime():
			player.volume_db = -80.0
			continue
		var tween := create_tween()
		tween.tween_property(player, "volume_db", -80.0, 0.36)
		tween.tween_callback(Callable(player, "stop"))

func _setup_battle_music_players() -> void:
	for key in BATTLE_MUSIC_KEYS:
		if music_players.has(key):
			continue
		if not music_streams.has(key):
			continue
		var player := AudioStreamPlayer.new()
		player.bus = BGM_BUS_NAME
		player.volume_db = -80.0
		player.stream = custom_music_streams.get(key, music_streams[key])
		add_child(player)
		music_players[key] = player

func _ensure_battle_music_playing() -> void:
	for key in BATTLE_MUSIC_KEYS:
		if not music_players.has(key):
			continue
		var player: AudioStreamPlayer = music_players[key]
		if player.stream == null:
			player.stream = custom_music_streams.get(key, music_streams.get(key))
		if player.stream != null and not player.playing:
			player.play()

func _battle_music_layer_targets(mode: String, state: Dictionary) -> Dictionary:
	var targets := {
		"battle_base": -23.5,
		"battle_tension": -80.0,
		"battle_lethal": -80.0,
		"battle_low_hp": -80.0,
	}
	if bool(state.get("boss", false)):
		targets["battle_base"] = -24.5
		targets["battle_tension"] = -22.0
	match mode:
		"tension":
			targets["battle_base"] = -25.5
			targets["battle_tension"] = -19.5
		"lethal":
			targets["battle_base"] = -27.0
			targets["battle_tension"] = -22.0
			targets["battle_lethal"] = -17.8
		"low_hp":
			targets["battle_base"] = -28.0
			targets["battle_tension"] = -23.5
			targets["battle_low_hp"] = -18.5
	return targets

func _fade_music_layer(key: String, target_db: float, duration: float) -> void:
	if not music_players.has(key):
		return
	var player: AudioStreamPlayer = music_players[key]
	if player == null or not is_instance_valid(player):
		return
	if _is_headless_runtime():
		player.volume_db = target_db
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target_db, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _claim_player(priority: int) -> AudioStreamPlayer:
	for player in players:
		if not player.playing:
			return player
	var candidate: AudioStreamPlayer = null
	var candidate_priority := 999
	var candidate_started := 0x7FFFFFFF
	for player in players:
		var player_priority := int(player.get_meta("sfx_priority", 0))
		var player_started := int(player.get_meta("sfx_started_msec", 0))
		if player_priority < candidate_priority or (player_priority == candidate_priority and player_started < candidate_started):
			candidate = player
			candidate_priority = player_priority
			candidate_started = player_started
	if candidate == null or candidate_priority > priority:
		return null
	candidate.stop()
	return candidate

func _sound_priority(sound_name: String) -> int:
	if sound_name in ["victory_burst", "finisher"]:
		return 5
	if sound_name in ["direct_attack", "impact_heavy", "power_human", "power_elf", "power_undead"]:
		return 4
	if sound_name.begins_with("summon_") or sound_name.begins_with("hit_") or sound_name.begins_with("spell_") or sound_name.begins_with("equipment_"):
		return 3
	if sound_name in ["combo", "counter", "hit", "summon", "spell", "reward", "victory", "defeat"]:
		return 3
	if sound_name in ["play", "draw", "heal"]:
		return 2
	return 0 if sound_name == "hover" else 1

func _duck_duration_msec(sound_name: String) -> int:
	match sound_name:
		"victory_burst":
			return 2600
		"finisher":
			return 900
		"impact_heavy":
			return 420
		"direct_attack":
			return 360
		"power_human", "power_elf", "power_undead":
			return 780
	return 0

func _minimum_gap_msec(sound_name: String) -> int:
	match sound_name:
		"hit", "counter":
			return 85
		"impact_heavy":
			return 180
		"direct_attack":
			return 220
		"play", "summon":
			return 120
		"power_human", "power_undead", "finisher":
			return 260
		"victory_burst", "victory", "defeat":
			return 900
	if sound_name.begins_with("hit_"):
		return 85
	if sound_name.begins_with("summon_") or sound_name.begins_with("spell_") or sound_name.begins_with("equipment_"):
		return 120
	return 45 if _sound_priority(sound_name) <= 1 else 0

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

func _load_custom_music() -> void:
	custom_music_streams.clear()
	for music_name in music_streams.keys():
		for extension in ["wav", "ogg", "mp3"]:
			var custom_path := "res://assets/audio/%s.%s" % [music_name, extension]
			if not FileAccess.file_exists(custom_path):
				continue
			var custom_stream = _load_wav_stream(custom_path) if extension == "wav" else load(custom_path)
			if custom_stream != null:
				_make_stream_loop(custom_stream)
				custom_music_streams[music_name] = custom_stream
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

func _make_stream_loop(stream) -> void:
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.data.size() / (4 if stream.stereo else 2))
	elif stream != null and stream.has_method("set_loop"):
		stream.set_loop(true)

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
	streams["power_human"] = _generate_human_power()
	streams["power_elf"] = _generate_elf_power()
	streams["power_undead"] = _generate_undead_power()
	streams["impact_heavy"] = _generate_heavy_impact()
	streams["direct_attack"] = _generate_direct_attack()
	streams["victory_burst"] = _generate_victory_burst()
	streams["summon_human"] = _generate_race_summon("human")
	streams["summon_elf"] = _generate_race_summon("elf")
	streams["summon_undead"] = _generate_race_summon("undead")
	streams["summon_common"] = _generate_race_summon("common")
	streams["hit_human"] = _generate_race_hit("human")
	streams["hit_elf"] = _generate_race_hit("elf")
	streams["hit_undead"] = _generate_race_hit("undead")
	streams["hit_common"] = _generate_race_hit("common")
	streams["spell_fire"] = _generate_build_spell("fire")
	streams["spell_draw"] = _generate_build_spell("draw")
	streams["spell_death"] = _generate_build_spell("death")
	streams["spell_buff"] = _generate_build_spell("buff")
	streams["spell_summon"] = _generate_build_spell("summon")
	streams["spell_low_hp"] = _generate_build_spell("low_hp")
	streams["spell_common"] = _generate_build_spell("common")
	streams["equipment_human"] = _generate_equipment_sig("human")
	streams["equipment_elf"] = _generate_equipment_sig("elf")
	streams["equipment_undead"] = _generate_equipment_sig("undead")
	streams["equipment_common"] = _generate_equipment_sig("common")

	sound_volume_db = {
		"hover": -18.0,
		"click": -8.0,
		"draw": -6.8,
		"play": -5.2,
		"summon": -5.8,
		"spell": -2.8,
		"counter": -5.8,
		"hit": -5.2,
		"finisher": -4.8,
		"combo": -2.6,
		"heal": -5.0,
		"reward": -3.6,
		"victory": -4.8,
		"defeat": -3.5,
		"power_human": -5.2,
		"power_elf": -2.0,
		"power_undead": -5.8,
		"impact_heavy": -5.4,
		"direct_attack": -4.9,
		"victory_burst": -4.2,
		"summon_human": -5.4,
		"summon_elf": -5.8,
		"summon_undead": -6.0,
		"summon_common": -5.8,
		"hit_human": -5.0,
		"hit_elf": -5.6,
		"hit_undead": -5.8,
		"hit_common": -5.4,
		"spell_fire": -4.0,
		"spell_draw": -5.2,
		"spell_death": -5.6,
		"spell_buff": -4.8,
		"spell_summon": -5.0,
		"spell_low_hp": -5.0,
		"spell_common": -4.8,
		"equipment_human": -5.0,
		"equipment_elf": -5.3,
		"equipment_undead": -5.6,
		"equipment_common": -5.2,
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
		"power_human": 0.008,
		"power_elf": 0.012,
		"power_undead": 0.008,
		"impact_heavy": 0.012,
		"direct_attack": 0.01,
		"victory_burst": 0.0,
		"summon_human": 0.014,
		"summon_elf": 0.018,
		"summon_undead": 0.01,
		"summon_common": 0.014,
		"hit_human": 0.025,
		"hit_elf": 0.03,
		"hit_undead": 0.02,
		"hit_common": 0.025,
	}

func _generate_all_music() -> void:
	music_streams["battle_base"] = _generate_battle_music_loop("base")
	music_streams["battle_tension"] = _generate_battle_music_loop("tension")
	music_streams["battle_lethal"] = _generate_battle_music_loop("lethal")
	music_streams["battle_low_hp"] = _generate_battle_music_loop("low_hp")

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

func _finish_loop_stream(parts: Dictionary) -> AudioStreamWAV:
	var stream := _finish_stream(parts)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(parts["samples"])
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
	var duration := 0.44
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_sub: float = 0.0
	var phase_leather: float = 0.0
	var phase_resonance: float = 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_sub += (lerpf(118.0, 78.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_leather += (lerpf(210.0, 132.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_resonance += (238.0 * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.12)
		var first_hit: float = exp(-p * 24.0)
		var table_hit: float = _impact_after(p, 0.045, 18.0)
		var sub: float = sin(phase_sub) * (first_hit + table_hit * 0.22) * 0.28
		var leather: float = _triangle_wave(phase_leather) * first_hit * 0.26
		var slap: float = (raw_noise - noise_lp) * exp(-p * 42.0) * 0.46
		var resonance: float = sin(phase_resonance) * exp(-p * 8.0) * 0.18
		_write_sample(bytes, i, _saturate(sub + leather + slap + resonance, 1.7))
	return _finish_stream(parts)

func _generate_summon_drop() -> AudioStreamWAV:
	var duration := 0.78
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
		phase_portal += (lerpf(318.0, 138.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_sub += (lerpf(118.0, 72.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_rune_a += (417.0 * 2.0 * PI) / float(SAMPLE_RATE)
		phase_rune_b += (691.0 * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.045)
		var charge: float = smoothstep(0.0, 0.24, p) * (1.0 - smoothstep(0.28, 0.62, p))
		var landing: float = _impact_after(p, 0.24, 11.0)
		var portal: float = _triangle_wave(phase_portal) * charge * 0.24
		var mist: float = noise_lp * charge * 0.24
		var sub: float = sin(phase_sub) * landing * 0.22
		var rune: float = (sin(phase_rune_a) * 0.16 + sin(phase_rune_b) * 0.09) * _impact_after(p, 0.22, 4.8)
		var debris: float = (raw_noise - noise_lp) * landing * 0.32
		_write_sample(bytes, i, _saturate(portal + mist + sub + rune + debris, 1.7))
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
	var duration := 0.34
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_sub: float = 0.0
	var phase_blade_a: float = 0.0
	var phase_blade_b: float = 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_sub += (lerpf(142.0, 84.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_blade_a += (lerpf(880.0, 390.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_blade_b += (1049.0 * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.16)
		var impact: float = exp(-p * 22.0)
		var body: float = sin(phase_sub) * impact * 0.3
		var blade: float = (sin(phase_blade_a) * 0.36 + sin(phase_blade_b) * 0.13) * exp(-p * 13.0)
		var crunch: float = (raw_noise * 0.55 + noise_lp * 0.45) * exp(-p * 24.0) * 0.44
		var recoil: float = sin(phase_sub * 0.82) * _impact_after(p, 0.06, 16.0) * 0.12
		_write_sample(bytes, i, _saturate(body + blade + crunch + recoil, 1.95))
	return _finish_stream(parts)

func _generate_counter_hit() -> AudioStreamWAV:
	var duration := 0.34
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_low: float = 0.0
	var phase_clang_a: float = 0.0
	var phase_clang_b: float = 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_low += (lerpf(132.0, 86.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_clang_a += (lerpf(746.0, 518.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_clang_b += (1283.0 * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.14)
		var low: float = sin(phase_low) * exp(-p * 14.0) * 0.2
		var clang: float = (sin(phase_clang_a) * 0.4 + sin(phase_clang_b) * 0.18) * exp(-p * 9.0)
		var scrape: float = (raw_noise - noise_lp) * exp(-p * 24.0) * 0.28
		var recoil: float = sin(phase_low * 0.82) * _impact_after(p, 0.08, 17.0) * 0.1
		_write_sample(bytes, i, _saturate(low + clang + scrape + recoil, 1.75))
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

func _generate_human_power() -> AudioStreamWAV:
	var duration := 0.72
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_drum := 0.0
	var phase_metal_a := 0.0
	var phase_metal_b := 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_drum += (lerpf(128.0, 82.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_metal_a += (392.0 * 2.0 * PI) / float(SAMPLE_RATE)
		phase_metal_b += (658.0 * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.1)
		var first_hit := exp(-p * 24.0)
		var second_hit := _impact_after(p, 0.22, 16.0)
		var drum: float = sin(phase_drum) * (first_hit + second_hit * 0.34) * 0.24
		var metal: float = (sin(phase_metal_a) * 0.32 + sin(phase_metal_b) * 0.22) * second_hit
		var strike: float = (raw_noise - noise_lp) * (first_hit + second_hit) * 0.32
		_write_sample(bytes, i, _saturate(drum + metal + strike, 1.85))
	return _finish_stream(parts)

func _generate_elf_power() -> AudioStreamWAV:
	var duration := 1.02
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_low := 0.0
	var phase_a := 0.0
	var phase_b := 0.0
	var wind_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_low += (110.0 * 2.0 * PI) / float(SAMPLE_RATE)
		phase_a += (lerpf(246.94, 493.88, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_b += (lerpf(329.63, 659.25, p) * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		wind_lp = lerpf(wind_lp, raw_noise, 0.035)
		var rise := sin(phase_a) * 0.3 + sin(phase_b) * 0.2
		var shimmer := sin(phase_b * 2.03) * _impact_after(p, 0.38, 4.2) * 0.12
		var wind := wind_lp * sin(p * PI) * 0.22
		var low := sin(phase_low) * exp(-p * 4.0) * 0.14
		_write_sample(bytes, i, _saturate((rise + shimmer + wind) * _release_envelope(p, 1.2) + low, 1.35))
	return _finish_stream(parts)

func _generate_undead_power() -> AudioStreamWAV:
	var duration := 0.82
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_sub := 0.0
	var phase_voice_a := 0.0
	var phase_voice_b := 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_sub += (lerpf(112.0, 68.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_voice_a += (lerpf(138.0, 92.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_voice_b += (lerpf(207.0, 146.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.025)
		var impact := exp(-p * 16.0)
		var return_pulse := _impact_after(p, 0.3, 8.0)
		var sub: float = sin(phase_sub) * (impact + return_pulse * 0.28) * 0.24
		var voice: float = (sin(phase_voice_a) * 0.3 + _triangle_wave(phase_voice_b) * 0.14) * _release_envelope(p, 1.8)
		var breath: float = noise_lp * sin(p * PI) * 0.3
		_write_sample(bytes, i, _saturate(sub + voice + breath, 1.7))
	return _finish_stream(parts)

func _generate_heavy_impact() -> AudioStreamWAV:
	var duration := 0.42
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_sub := 0.0
	var phase_body := 0.0
	var phase_metal_a := 0.0
	var phase_metal_b := 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_sub += (lerpf(148.0, 92.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_body += (lerpf(230.0, 118.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_metal_a += (lerpf(1120.0, 420.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_metal_b += (1379.0 * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.14)
		var first := exp(-p * 26.0)
		var second := _impact_after(p, 0.08, 20.0)
		var tail := _impact_after(p, 0.18, 12.0)
		var sub: float = sin(phase_sub) * (first + second * 0.24) * 0.26
		var body: float = _triangle_wave(phase_body) * (first + second * 0.48) * 0.44
		var metal: float = (sin(phase_metal_a) * 0.34 + sin(phase_metal_b) * 0.15) * (first + second * 0.76)
		var crack: float = (raw_noise - noise_lp * 0.35) * (first + second * 0.9) * 0.58
		var air: float = noise_lp * tail * 0.2
		_write_sample(bytes, i, _saturate(sub + body + metal + crack + air, 2.0))
	return _finish_stream(parts)

func _generate_direct_attack() -> AudioStreamWAV:
	var duration := 0.62
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_whoosh := 0.0
	var phase_low := 0.0
	var phase_blade := 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_whoosh += (lerpf(620.0, 180.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_low += (lerpf(118.0, 58.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_blade += (lerpf(1320.0, 460.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.12)
		var launch := _impact_after(p, 0.0, 13.5)
		var strike := _impact_after(p, 0.18, 16.0)
		var settle := _impact_after(p, 0.34, 9.0)
		var whoosh: float = _triangle_wave(phase_whoosh) * sin(clampf(p / 0.34, 0.0, 1.0) * PI) * 0.26
		var blade: float = sin(phase_blade) * (launch * 0.28 + strike * 0.7) * 0.28
		var body: float = sin(phase_low) * (strike + settle * 0.34) * 0.48
		var snap: float = (raw_noise - noise_lp * 0.28) * (launch * 0.26 + strike * 0.62) * 0.42
		_write_sample(bytes, i, _saturate(whoosh + blade + body + snap, 2.2))
	return _finish_stream(parts)

func _generate_victory_burst() -> AudioStreamWAV:
	var duration := 2.1
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var horn_freqs: Array[float] = [130.81, 164.81, 196.0, 261.63, 329.63]
	var horn_phases: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	var horn_upper_phases: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	var phase_sub := 0.0
	var phase_bell_a := 0.0
	var phase_bell_b := 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		phase_sub += (lerpf(128.0, 86.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_bell_a += (784.0 * 2.0 * PI) / float(SAMPLE_RATE)
		phase_bell_b += (1174.66 * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.04)
		var horn_sample := 0.0
		for note_index in range(horn_freqs.size()):
			horn_phases[note_index] += (horn_freqs[note_index] * 2.0 * PI) / float(SAMPLE_RATE)
			horn_upper_phases[note_index] += (horn_freqs[note_index] * 2.015 * 2.0 * PI) / float(SAMPLE_RATE)
			var note_start := 0.08 + float(note_index) * 0.11
			var note_env := _impact_after(p, note_start, 2.6)
			horn_sample += (sin(horn_phases[note_index]) * 0.22 + sin(horn_upper_phases[note_index]) * 0.055) * note_env
		var drum_a := exp(-p * 24.0)
		var drum_b := _impact_after(p, 0.13, 22.0)
		var drum_c := _impact_after(p, 0.26, 20.0)
		var final_slam := _impact_after(p, 0.57, 12.0)
		var drums: float = sin(phase_sub) * (drum_a + drum_b * 0.28 + drum_c * 0.22 + final_slam * 0.32) * 0.22
		var bell_env := _impact_after(p, 0.34, 3.8)
		var bells: float = (sin(phase_bell_a) * 0.14 + sin(phase_bell_b) * 0.1) * bell_env
		var shimmer: float = noise_lp * sin(clampf((p - 0.2) / 0.8, 0.0, 1.0) * PI) * 0.2
		var global_release := _release_envelope(p, 0.82)
		var sample: float = (horn_sample * 0.82 + drums + bells + shimmer) * global_release
		_write_sample(bytes, i, _saturate(sample, 1.55))
	return _finish_stream(parts)

func _generate_finisher_slam() -> AudioStreamWAV:
	var duration := 0.88
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
		phase_low += (lerpf(136.0, 82.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_gong_a += (113.0 * 2.0 * PI) / float(SAMPLE_RATE)
		phase_gong_b += (291.0 * 2.0 * PI) / float(SAMPLE_RATE)
		phase_blade += (lerpf(684.0, 232.0, p) * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.08)
		var impact: float = exp(-p * 13.0)
		var aftershock: float = _impact_after(p, 0.26, 9.0)
		var last_boom: float = _impact_after(p, 0.48, 10.0)
		var sub: float = sin(phase_low) * (impact + aftershock * 0.22 + last_boom * 0.14) * 0.28
		var gong: float = (sin(phase_gong_a) * 0.36 + sin(phase_gong_b) * 0.18) * exp(-p * 2.8)
		var blade: float = _triangle_wave(phase_blade) * exp(-p * 16.0) * 0.26
		var break_noise: float = (raw_noise * 0.6 + noise_lp * 0.4) * (impact + aftershock * 0.5) * 0.42
		_write_sample(bytes, i, _saturate(sub + gong + blade + break_noise, 1.9))
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
	var win_notes: Array[float] = [146.83, 196.00, 246.94, 293.66, 392.00]
	var lose_notes: Array[float] = [130.81, 110.00, 98.00, 82.41, 73.42]
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
		phase_drum += (92.0 * 2.0 * PI) / float(SAMPLE_RATE)
		var fundamental: float = sin(phases_f[note_idx])
		var detuned_upper: float = sin(phases_u[note_idx]) * 0.36
		var detuned_lower: float = sin(phases_l[note_idx]) * 0.36
		var note_progress: float = fmod(progress * notes.size(), 1.0)
		var note_envelope: float = _hit_envelope(note_progress, 0.035, 3.8)
		var global_envelope: float = _release_envelope(progress, 1.25 if is_win else 1.05)
		var horn_sample: float = (fundamental + detuned_upper + detuned_lower) * note_envelope * global_envelope
		var drum: float = sin(phase_drum) * exp(-note_progress * 18.0) * global_envelope * (0.08 if is_win else 0.06)
		var sample: float = horn_sample * (0.34 if is_win else 0.40) + drum
		_write_sample(bytes, i, _saturate(sample, 1.45))
	return _finish_stream(parts)

func _generate_race_summon(race_key: String) -> AudioStreamWAV:
	var duration := 0.62
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_body := 0.0
	var phase_a := 0.0
	var phase_b := 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		var body_freq := 118.0
		var accent_a := 392.0
		var accent_b := 784.0
		var body_gain := 0.18
		var accent_gain := 0.26
		match race_key:
			"human":
				body_freq = 132.0
				accent_a = 430.0
				accent_b = 910.0
				body_gain = 0.2
				accent_gain = 0.28
			"elf":
				body_freq = 176.0
				accent_a = 740.0
				accent_b = 1480.0
				body_gain = 0.08
				accent_gain = 0.34
			"undead":
				body_freq = 104.0
				accent_a = 260.0
				accent_b = 620.0
				body_gain = 0.16
				accent_gain = 0.22
		phase_body += (lerpf(body_freq, body_freq * 0.72, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_a += (lerpf(accent_a, accent_a * 0.82, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_b += (accent_b * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.06 if race_key == "elf" else 0.12)
		var entry := smoothstep(0.0, 0.18, p) * _release_envelope(p, 1.8)
		var land := _impact_after(p, 0.2, 12.0)
		var body: float = sin(phase_body) * land * body_gain
		var accent: float = (sin(phase_a) * 0.22 + sin(phase_b) * 0.08) * entry * accent_gain
		var texture: float = (raw_noise - noise_lp) * (entry * 0.1 + land * 0.24)
		if race_key == "undead":
			texture += _triangle_wave(phase_a * 0.5) * land * 0.12
		_write_sample(bytes, i, _saturate(body + accent + texture, 1.55))
	return _finish_stream(parts)


func _generate_race_hit(race_key: String) -> AudioStreamWAV:
	var duration := 0.3
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_body := 0.0
	var phase_a := 0.0
	var phase_b := 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		var body_freq := 132.0
		var accent_a := 760.0
		var accent_b := 1180.0
		match race_key:
			"human":
				body_freq = 156.0
				accent_a = 870.0
				accent_b = 1320.0
			"elf":
				body_freq = 210.0
				accent_a = 1180.0
				accent_b = 1760.0
			"undead":
				body_freq = 122.0
				accent_a = 420.0
				accent_b = 930.0
		phase_body += (lerpf(body_freq, body_freq * 0.68, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_a += (lerpf(accent_a, accent_a * 0.62, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_b += (accent_b * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.18)
		var hit := exp(-p * 24.0)
		var body: float = sin(phase_body) * hit * (0.2 if race_key != "elf" else 0.08)
		var accent: float = (sin(phase_a) * 0.34 + sin(phase_b) * 0.12) * exp(-p * (12.0 if race_key != "undead" else 8.0))
		var crack: float = (raw_noise - noise_lp) * exp(-p * 26.0) * (0.42 if race_key != "elf" else 0.28)
		if race_key == "undead":
			crack += _triangle_wave(phase_a) * exp(-p * 18.0) * 0.12
		_write_sample(bytes, i, _saturate(body + accent + crack, 1.8))
	return _finish_stream(parts)


func _generate_build_spell(tag: String) -> AudioStreamWAV:
	var duration := 0.58
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_a := 0.0
	var phase_b := 0.0
	var phase_body := 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		var freq_a := 520.0
		var freq_b := 980.0
		var body_freq := 138.0
		var noise_gain := 0.16
		match tag:
			"fire":
				freq_a = 430.0
				freq_b = 1320.0
				body_freq = 156.0
				noise_gain = 0.34
			"draw":
				freq_a = 620.0
				freq_b = 1540.0
				body_freq = 196.0
				noise_gain = 0.12
			"death":
				freq_a = 260.0
				freq_b = 740.0
				body_freq = 112.0
				noise_gain = 0.26
			"buff":
				freq_a = 392.0
				freq_b = 1046.0
				body_freq = 174.0
				noise_gain = 0.1
			"summon":
				freq_a = 318.0
				freq_b = 880.0
				body_freq = 132.0
				noise_gain = 0.18
			"low_hp":
				freq_a = 330.0
				freq_b = 990.0
				body_freq = 146.0
				noise_gain = 0.2
		phase_a += (lerpf(freq_a, freq_a * 1.22, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_b += (freq_b * 2.0 * PI) / float(SAMPLE_RATE)
		phase_body += (lerpf(body_freq, body_freq * 0.82, p) * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.08)
		var charge := sin(p * PI)
		var release := _impact_after(p, 0.46, 10.0)
		var tone: float = (_triangle_wave(phase_a) * 0.22 + sin(phase_b) * 0.08) * charge
		var body: float = sin(phase_body) * release * 0.16
		var texture: float = (raw_noise - noise_lp) * (charge * noise_gain + release * 0.18)
		_write_sample(bytes, i, _saturate(tone + body + texture, 1.55))
	return _finish_stream(parts)


func _generate_equipment_sig(race_key: String) -> AudioStreamWAV:
	var duration := 0.42
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var phase_a := 0.0
	var phase_b := 0.0
	var phase_body := 0.0
	var noise_lp := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / duration
		var body_freq := 154.0
		var accent_a := 620.0
		var accent_b := 1240.0
		match race_key:
			"human":
				body_freq = 180.0
				accent_a = 720.0
				accent_b = 1440.0
			"elf":
				body_freq = 220.0
				accent_a = 980.0
				accent_b = 1840.0
			"undead":
				body_freq = 118.0
				accent_a = 360.0
				accent_b = 860.0
		phase_body += (body_freq * 2.0 * PI) / float(SAMPLE_RATE)
		phase_a += (lerpf(accent_a, accent_a * 0.76, p) * 2.0 * PI) / float(SAMPLE_RATE)
		phase_b += (accent_b * 2.0 * PI) / float(SAMPLE_RATE)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		noise_lp = lerpf(noise_lp, raw_noise, 0.14)
		var bind := _impact_after(p, 0.08, 9.0)
		var body: float = sin(phase_body) * bind * 0.16
		var ring: float = (sin(phase_a) * 0.3 + sin(phase_b) * 0.11) * _release_envelope(p, 1.8)
		var grit: float = (raw_noise - noise_lp) * bind * 0.2
		_write_sample(bytes, i, _saturate(body + ring + grit, 1.55))
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

func _generate_battle_music_loop(mode: String) -> AudioStreamWAV:
	var duration := 7.0
	var parts := _new_stream(duration)
	var bytes: PackedByteArray = parts["bytes"]
	var low_phase := 0.0
	var mid_phase := 0.0
	var pulse_phase := 0.0
	var high_phase := 0.0
	for i in range(int(parts["samples"])):
		var t: float = float(i) / float(SAMPLE_RATE)
		var loop_p: float = t / duration
		var seam_fade: float = minf(smoothstep(0.0, 0.08, loop_p), 1.0 - smoothstep(0.92, 1.0, loop_p))
		var low_freq := 55.0
		var mid_freq := 110.0
		var pulse_rate := 0.5
		var low_gain := 0.08
		var mid_gain := 0.035
		var noise_gain := 0.015
		match mode:
			"tension":
				low_freq = 62.0
				mid_freq = 123.47
				pulse_rate = 1.0
				low_gain = 0.105
				mid_gain = 0.055
				noise_gain = 0.026
			"lethal":
				low_freq = 73.42
				mid_freq = 146.83
				pulse_rate = 1.35
				low_gain = 0.08
				mid_gain = 0.075
				noise_gain = 0.035
			"low_hp":
				low_freq = 49.0
				mid_freq = 98.0
				pulse_rate = 1.18
				low_gain = 0.12
				mid_gain = 0.04
				noise_gain = 0.032
		low_phase += (low_freq * 2.0 * PI) / float(SAMPLE_RATE)
		mid_phase += (mid_freq * 2.0 * PI) / float(SAMPLE_RATE)
		pulse_phase += (pulse_rate * 2.0 * PI) / float(SAMPLE_RATE)
		high_phase += ((mid_freq * 4.02) * 2.0 * PI) / float(SAMPLE_RATE)
		var pulse: float = 0.58 + maxf(0.0, sin(pulse_phase)) * 0.42
		var low: float = sin(low_phase) * low_gain * pulse
		var mid: float = _triangle_wave(mid_phase) * mid_gain * (0.65 + sin(pulse_phase * 0.5) * 0.35)
		var high: float = sin(high_phase) * 0.012 * (1.0 if mode in ["lethal", "tension"] else 0.45)
		var texture: float = rng.randf_range(-1.0, 1.0) * noise_gain
		if mode == "low_hp":
			var heartbeat: float = pow(maxf(0.0, sin(pulse_phase)), 8.0) * 0.08
			low += sin(low_phase * 0.5) * heartbeat
		if mode == "lethal":
			var rise: float = smoothstep(0.2, 0.86, loop_p)
			high += sin(high_phase * 1.5) * rise * 0.026
		_write_sample(bytes, i, _saturate((low + mid + high + texture) * seam_fade, 1.18))
	return _finish_loop_stream(parts)
