extends RefCounted

const MAX_MANA := 10
const MAX_FIELD := 5
const START_HAND := 5
const STARTING_MAX_MANA := 1
const TURN_TIME_SECONDS := 35.0
const BATTLE_MAX_CONTENT_WIDTH := 1240.0

var main
var root_box: VBoxContainer
var status_label: Label
var battle_guidance_label: Label
var opponent_info: Label
var opponent_gauge_info: Label
var opponent_field_box: HBoxContainer
var hero_attack_button: Button
var opponent_hero_target: Control
var player_hero_target: Control
var opponent_hero_target_hp_label: Label
var player_hero_target_hp_label: Label
var player_field_box: HBoxContainer
var player_info: Label
var player_gauge_info: Label
var hand_box: Control
var deck_count_label: Label
var turn_overlay: Panel
var turn_timer: Timer
var turn_timer_label: Label
var deck_list_label: RichTextLabel
var log_label: RichTextLabel
var end_turn_button: Button
var enemy_hero_name_label: Label
var enemy_hero_hp_label: Label
var enemy_hero_sub_label: Label
var player_hero_name_label: Label
var player_hero_hp_label: Label
var player_hero_sub_label: Label
var enemy_hand_count_label: Label
var enemy_deck_count_label: Label
var build_chip_box: BoxContainer
var mana_status_label: Label
var player_deck_status_label: Label
var player_field_status_label: Label
var opponent_field_slots: Array[Control] = []
var player_field_slots: Array[Control] = []
var player := {}
var opponent := {}
var current_player := "player"
var selected_attacker := -1
var game_over := false
var battle_finished := false
var input_locked := false
var battle_state := {}
var battle_tier := "normal"

const ENEMY_HERO_ART := 11
const PLAYER_HERO_ART := 8

func _init(main_ref) -> void:
	main = main_ref
	root_box = main.root_box

func _on_turn_timeout() -> void:
	if main.active_screen == "battle" and current_player == "player" and not game_over and not input_locked:
		_add_log("시간 초과! 턴이 강제로 종료됩니다.")
		_on_end_turn_pressed()

func _save_run() -> void:
	main._save_run()

func _serialize_side(side: Dictionary) -> Dictionary:
	return {
		"name": String(side.get("name", "")),
		"health": int(side.get("health", 0)),
		"max_health": int(side.get("max_health", 0)),
		"mana": int(side.get("mana", 0)),
		"max_mana": int(side.get("max_mana", 0)),
		"deck": (side.get("deck", []) as Array).duplicate(true),
		"discard_pile": (side.get("discard_pile", []) as Array).duplicate(true),
		"hand": (side.get("hand", []) as Array).duplicate(true),
		"field": (side.get("field", []) as Array).duplicate(true),
		"corpse_explosion_stacks": int(side.get("corpse_explosion_stacks", 0)),
		"curses": int(side.get("curses", 0)),
		"ritual_stacks": int(side.get("ritual_stacks", 0)),
	}

func _restore_side(snapshot: Dictionary, fallback_name: String) -> Dictionary:
	return {
		"name": String(snapshot.get("name", fallback_name)),
		"health": int(snapshot.get("health", 0)),
		"max_health": int(snapshot.get("max_health", 0)),
		"mana": int(snapshot.get("mana", 0)),
		"max_mana": int(snapshot.get("max_mana", 0)),
		"deck": (snapshot.get("deck", []) as Array).duplicate(true),
		"discard_pile": (snapshot.get("discard_pile", []) as Array).duplicate(true),
		"hand": (snapshot.get("hand", []) as Array).duplicate(true),
		"field": (snapshot.get("field", []) as Array).duplicate(true),
		"corpse_explosion_stacks": int(snapshot.get("corpse_explosion_stacks", 0)),
		"curses": int(snapshot.get("curses", 0)),
		"ritual_stacks": int(snapshot.get("ritual_stacks", 0)),
	}

func _store_battle_snapshot() -> void:
	if main.active_screen != "battle" or battle_finished or main.current_run.is_empty():
		return
	main.current_run["battle_snapshot"] = {
		"battle_tier": battle_tier,
		"current_player": current_player,
		"selected_attacker": selected_attacker,
		"input_locked": input_locked,
		"player": _serialize_side(player),
		"opponent": _serialize_side(opponent),
		"log_text": "" if log_label == null else log_label.text,
		"turn_timer_left": 0.0 if turn_timer == null or turn_timer.is_stopped() else turn_timer.time_left,
		"battle_state_flags": {
			"cards_played_this_turn": int(battle_state.get("cards_played_this_turn", 0)),
			"mana_crystal_bonus": bool(battle_state.get("mana_crystal_bonus", false)),
			"first_card_discount_available": bool(battle_state.get("first_card_discount_available", false)),
			"necromancer_ring_used": bool(battle_state.get("necromancer_ring_used", false)),
			"second_chance_used": bool(battle_state.get("second_chance_used", false)),
			"summon_build_started": bool(battle_state.get("summon_build_started", false)),
		},
	}
	_save_run()

func _restore_battle_snapshot(snapshot: Dictionary) -> void:
	battle_tier = String(snapshot.get("battle_tier", battle_tier))
	player = _restore_side(Dictionary(snapshot.get("player", {})), "플레이어")
	opponent = _restore_side(Dictionary(snapshot.get("opponent", {})), "적")
	_reset_battle_state()
	current_player = String(snapshot.get("current_player", "player"))
	selected_attacker = int(snapshot.get("selected_attacker", -1))
	input_locked = bool(snapshot.get("input_locked", false))
	var flags: Dictionary = snapshot.get("battle_state_flags", {})
	battle_state["cards_played_this_turn"] = int(flags.get("cards_played_this_turn", 0))
	battle_state["mana_crystal_bonus"] = bool(flags.get("mana_crystal_bonus", false))
	battle_state["first_card_discount_available"] = bool(flags.get("first_card_discount_available", false))
	battle_state["necromancer_ring_used"] = bool(flags.get("necromancer_ring_used", false))
	battle_state["second_chance_used"] = bool(flags.get("second_chance_used", false))
	battle_state["summon_build_started"] = bool(flags.get("summon_build_started", false))
	_build_battle_ui()
	if log_label != null:
		log_label.text = String(snapshot.get("log_text", ""))
	var restored_time_left: float = float(snapshot.get("turn_timer_left", 0.0))
	if current_player == "player" and turn_timer != null and restored_time_left > 0.0:
		turn_timer.start(restored_time_left)
	elif turn_timer != null:
		turn_timer.stop()
	_refresh_ui()
	if current_player == "opponent" and not game_over:
		call_deferred("_resume_opponent_turn_from_snapshot")

func _resume_opponent_turn_from_snapshot() -> void:
	if game_over or main.active_screen != "battle" or current_player != "opponent":
		return
	input_locked = true
	_refresh_ui()
	await _run_ai_turn()

func _show_message(message: String, callback_method: String) -> void:
	main._show_message(message, callback_method)

func _profile_upgrades() -> Dictionary:
	return main._profile_upgrades()

func _finish_run(is_win: bool) -> void:
	main._finish_run(is_win)

func _show_card_reward() -> void:
	main._show_card_reward()

func _roll_high_cost_cards(count: int) -> Array[String]:
	return main._roll_high_cost_cards(count)

func _roll_card_choices(count: int) -> Array[String]:
	return main._roll_card_choices(count)

func _node_type_name(node_type: String) -> String:
	return main._node_type_name(node_type)

func _can_play_card(side: Dictionary, card: Dictionary, owner_key: String) -> bool:
	var cost: int = main.relic_service.modify_card_cost(main.current_run, battle_state, card, owner_key)
	if cost > int(side.mana):
		return false
	if String(card.get("type", "")) == "unit" and side.field.size() >= MAX_FIELD:
		return false
	if String(card.get("type", "")) == "equipment" and side.field.is_empty():
		return false
	return true

func _is_battle_cutscene_enabled() -> bool:
	return bool(main.player_profile.get("settings", {}).get("battle_cutscene", false))

func _is_player_input_locked() -> bool:
	return input_locked or game_over or current_player != "player"

func _format_side_status(side: Dictionary, fallback_name: String, is_enemy_hero: bool = false) -> String:
	if is_enemy_hero:
		return "적 영웅 HP %d/%d" % [int(side.get("health", 0)), int(side.get("max_health", 0))]
	return "%s  HP %d/%d" % [String(side.get("name", fallback_name)), int(side.get("health", 0)), int(side.get("max_health", 0))]

func _format_side_resources(side: Dictionary) -> String:
	return "마나 %d/%d | 손패 %d | 덱 %d" % [int(side.get("mana", 0)), int(side.get("max_mana", 0)), (side.get("hand", []) as Array).size(), (side.get("deck", []) as Array).size()]

func _format_opponent_victory_gauge() -> String:
	return "적 자원: %s" % _format_side_resources(opponent)

func _format_player_victory_gauge() -> String:
	return "%s | %s" % [main._battle_build_hint_text(), _format_side_resources(player)]

func _current_battle_guidance_text() -> String:
	if game_over:
		return "전투가 끝났습니다."
	if input_locked or current_player != "player":
		return "적 행동을 확인하세요."
	if selected_attacker != -1:
		if opponent.field.is_empty():
			return "상대 영웅 공격 버튼을 누르세요."
		return "공격할 적 유닛을 고르거나 상대 영웅을 공격하세요."
	for card in player.hand:
		if _can_play_card(player, card, "player"):
			return "밝게 표시된 카드를 내거나 공격 가능한 유닛을 선택하세요."
	for unit in player.field:
		if bool(unit.get("can_attack", false)):
			return "밝게 표시된 유닛을 선택해 공격하세요."
	return "할 행동이 없으면 턴 종료를 누르세요."

func _unplayable_card_hint(card: Dictionary, cost: int) -> String:
	if _is_player_input_locked():
		return "대기"
	if cost > int(player.mana):
		return "마나 부족"
	if String(card.get("type", "")) == "unit" and player.field.size() >= MAX_FIELD:
		return "필드 가득"
	if String(card.get("type", "")) == "equipment" and player.field.is_empty():
		return "대상 없음"
	return "사용 불가"

func _make_battle_guidance_panel(compact: bool) -> PanelContainer:
	var panel := _make_battle_surface(Color(0.04, 0.052, 0.068, 0.9), Color(0.18, 0.42, 0.7, 0.85), 1, 10, 14)
	var tight := _is_tight_battle_layout()
	panel.custom_minimum_size = Vector2(0, 36 if tight else (52 if compact else 58))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var title: Label = main._make_label("NEXT", 11 if tight else (12 if compact else 13), Color(0.45, 0.7, 1.0, 1.0))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.custom_minimum_size = Vector2(72 if tight else (82 if compact else 110), 0)
	row.add_child(title)
	battle_guidance_label = main._make_label("", 12 if tight else (15 if compact else 17), Color(0.93, 0.97, 1.0, 1.0))
	battle_guidance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	battle_guidance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(battle_guidance_label)
	return panel

func _is_fast_ai_enabled() -> bool:
	return bool(main.player_profile["settings"]["fast_ai"])

func _should_skip_timed_battle_fx() -> bool:
	return DisplayServer.get_name() == "headless" or bool(main.get_meta("disable_timed_battle_fx", false))

func _is_compact_layout() -> bool:
	return main._is_compact_layout_for(1360.0, 700.0)

func _is_tight_battle_layout() -> bool:
	var viewport_size: Vector2 = main._layout_viewport_size()
	return viewport_size.x <= 1024.0 or viewport_size.y <= 760.0

func _is_portrait_battle_layout() -> bool:
	var viewport_size: Vector2 = main._layout_viewport_size()
	return viewport_size.y > viewport_size.x

func _is_wide_tight_battle_layout() -> bool:
	var viewport_size: Vector2 = main._layout_viewport_size()
	return viewport_size.x >= 1100.0 and viewport_size.y <= 760.0

func _make_battle_content_root(tight: bool) -> VBoxContainer:
	var viewport_size: Vector2 = main._layout_viewport_size()
	var content_width: float = min(BATTLE_MAX_CONTENT_WIDTH, max(320.0, viewport_size.x - 20.0))
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(content_width, 0)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_theme_constant_override("separation", 6 if tight else 10)
	root_box.add_child(box)
	return box

func _battle_reward_choices() -> Array[String]:
	return main._roll_card_reward_choices(2, false)

func _apply_battle_victory_rewards() -> Dictionary:
	var bonus_relic := {}
	var gold_reward := randi_range(15, 25)
	if battle_tier in ["elite", "boss"]:
		bonus_relic = main.relic_service.random_relic(main.current_run.get("relic_ids", []))
		gold_reward = randi_range(30, 50) if battle_tier == "elite" else 50
	if battle_tier == "boss":
		main.current_run["max_hp"] = int(main.current_run.get("max_hp", 0)) + 5
		main.current_run["hp"] = min(int(main.current_run.get("max_hp", 0)), int(player.health) + 5)
	else:
		main.current_run["hp"] = int(player.health)
	gold_reward += main.relic_service.victory_gold_bonus(main.current_run)
	main.current_run["gold"] = int(main.current_run.get("gold", 0)) + gold_reward
	main.current_run["gold_earned"] = int(main.current_run.get("gold_earned", 0)) + gold_reward
	main.current_run["enemies_defeated"] = int(main.current_run.get("enemies_defeated", 0)) + 1
	return {
		"choices": _battle_reward_choices(),
		"bonus_relic": bonus_relic,
		"battle_tier": battle_tier,
		"gold_reward": gold_reward,
	}

func _finish_player_defeat() -> void:
	game_over = true
	battle_finished = true
	main.current_run["hp"] = 0
	main.current_run["result"] = "loss"
	_finish_run(false)

func _finish_player_victory(victory_type: String) -> void:
	game_over = true
	battle_finished = true
	main.current_run["hp"] = int(player.health)
	main.current_run["battle_victory_type"] = victory_type

func _reset_battle_state() -> void:
	current_player = "player"
	selected_attacker = -1
	game_over = false
	battle_finished = false
	input_locked = false
	battle_state = {
		"draw_cards": Callable(self, "_draw_cards"),
		"log": Callable(self, "_add_log"),
		"cleanup_dead_units": Callable(self, "_cleanup_dead_units"),
		"calculate_damage": Callable(self, "_calculate_damage"),
		"relic_service": main.relic_service,
		"run_data": main.current_run,
		"max_health": int(main.current_run.get("max_hp", 50)),
		"player_state": player,
		"first_card_discount_available": false,
		"mana_crystal_bonus": false,
		"cards_played_this_turn": 0,
		"necromancer_ring_used": false,
		"second_chance_used": false,
		"active_build_tags": main._active_build_tags(main._current_build_scores()),
		"summon_build_started": false,
	}

func _prepare_battle(tier: String) -> void:
	var enemy: Dictionary = main.enemy_service.pick_enemy(int(main.current_run.get("act", 1)), tier)
	if enemy.is_empty():
		_show_message("적 데이터를 준비하지 못했습니다. 런을 다시 시작해주세요.", "_show_main_menu")
		return
	main.current_run["battle_snapshot"] = {}
	main.current_run["active_enemy"] = enemy
	_save_run()
	start_battle()


func _new_side(display_name: String, deck: Array, hp: int, max_hp: int) -> Dictionary:
	deck.shuffle()
	return {
		"name": display_name,
		"health": hp,
		"max_health": max_hp,
		"mana": STARTING_MAX_MANA,
		"max_mana": STARTING_MAX_MANA,
		"deck": deck,
		"discard_pile": [],
		"hand": [],
		"field": [],
		"corpse_explosion_stacks": 0,
		"curses": 0,
		"ritual_stacks": 0,
	}

func _is_build_active(tag: String) -> bool:
	return (battle_state.get("active_build_tags", []) as Array).has(tag)

func _add_build_log(message: String) -> void:
	_add_log("빌드 효과: %s" % message)

func _spawn_build_token() -> void:
	if not _is_build_active("summon") or bool(battle_state.get("summon_build_started", false)):
		return
	if player.field.size() >= MAX_FIELD:
		return
	var token: Dictionary = {
		"id": "build_token",
		"name": "전열 토큰",
		"race": "중립",
		"attr": "대지",
		"attack": 1,
		"health": 1,
		"max_health": 1,
		"art": 0,
		"can_attack": false,
	}
	player.field.append(token)
	_apply_build_on_unit_summoned(player, token)
	battle_state["summon_build_started"] = true
	_add_build_log("소환 빌드 활성, 전투 시작 시 1/1 토큰 소환")

func _apply_build_on_turn_start() -> void:
	if _is_build_active("draw"):
		_draw_cards(player, 1)
		_add_build_log("드로우 빌드 활성, 카드 1장 추가 드로우")

func _apply_build_on_unit_summoned(owner_state: Dictionary, unit: Dictionary) -> void:
	if owner_state == player and _is_build_active("buff"):
		unit["health"] = int(unit.get("health", 0)) + 1
		unit["max_health"] = int(unit.get("max_health", 0)) + 1
		_add_build_log("버프 빌드 활성, %s 체력 +1" % String(unit.get("name", "유닛")))

func _apply_build_on_ally_died(enemy_state: Dictionary) -> void:
	if _is_build_active("death"):
		enemy_state["health"] = int(enemy_state.get("health", 0)) - 1
		_add_build_log("사망 빌드 활성, 적 영웅 피해 1")

func _build_damage_bonus(source: Dictionary, is_spell: bool, owner_state: Dictionary) -> int:
	var bonus := 0
	if _is_build_active("fire") and String(source.get("attr", "")) == "화염":
		bonus += 2
	if _is_build_active("low_hp") and not is_spell and owner_state == player and int(player.get("health", 0)) <= int(player.get("max_health", 0)) / 2:
		bonus += 1
	return bonus

func _top_resource_text() -> String:
	return "💧 %d/%d   📘 %d   🪙 %s%s" % [
		int(player.get("mana", 0)),
		int(player.get("max_mana", 0)),
		(player.get("deck", []) as Array).size(),
		main._format_large_number(int(main.current_run.get("gold", 0))),
		("   ⏱ %d" % int(ceili(turn_timer.time_left))) if current_player == "player" and turn_timer != null and not turn_timer.is_stopped() else "",
	]

func _make_top_status_bar(compact: bool) -> PanelContainer:
	var panel := _make_battle_surface(Color(0.018, 0.026, 0.036, 0.92), Color(0.12, 0.22, 0.34, 0.8), 1, 10, 9)
	var tight := _is_tight_battle_layout()
	panel.custom_minimum_size = Vector2(0, 28 if tight else (42 if compact else 46))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	status_label = main._make_label("", 12 if tight else (14 if compact else 16), Color(1.0, 0.9, 0.62, 1.0))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(status_label)

	turn_timer_label = main._make_label("", 11 if tight else (12 if compact else 13), Color(0.86, 0.92, 0.98, 1.0))
	turn_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	turn_timer_label.custom_minimum_size = Vector2(148 if tight else (160 if compact else 260), 0)
	row.add_child(turn_timer_label)
	return panel

func _make_side_info_card(title_text: String, side: Dictionary, hero_art: int, compact: bool, enemy_side: bool) -> PanelContainer:
	var tight := _is_tight_battle_layout()
	var panel := _make_battle_surface(Color(0.035, 0.048, 0.062, 0.86), Color(0.24, 0.38, 0.52, 0.7), 1, 10, 10)
	panel.custom_minimum_size = Vector2(0, 92 if tight else (112 if compact else 124))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5 if tight else 7)
	panel.add_child(box)

	var title: Label = main._make_label(title_text, 12 if tight else (13 if compact else 14), Color(0.74, 0.86, 1.0, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	row.add_child(main._make_art_rect(hero_art, Vector2(48, 48) if tight else (Vector2(54, 54) if compact else Vector2(62, 62))))

	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 4)
	row.add_child(info_box)

	var hero_name: Label = main._make_label(String(side.get("name", "")), 14 if tight else (15 if compact else 16), Color(0.96, 0.98, 0.93, 1.0))
	hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info_box.add_child(hero_name)

	var hp_text := "❤ %d / %d" % [int(side.get("health", 0)), int(side.get("max_health", 0))]
	var hp_label: Label = main._make_label(hp_text, 13 if tight else (14 if compact else 15), Color(1.0, 0.76, 0.76, 1.0))
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info_box.add_child(hp_label)

	var sub_text := "⚔ %d  |  손패 %d" % [
		_total_field_attack(side),
		(side.get("hand", []) as Array).size(),
	]
	if enemy_side:
		sub_text = "⚔ %d  |  덱 %d" % [_total_field_attack(side), (side.get("deck", []) as Array).size()]
	var sub_label: Label = main._make_label(sub_text, 11 if tight else (12 if compact else 13), Color(0.84, 0.88, 0.94, 1.0))
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info_box.add_child(sub_label)
	var priority_chip: PanelContainer = _make_battle_badge("우선 목표" if enemy_side else "현재 상태", Color(0.07, 0.09, 0.12, 0.94), Color(0.7, 0.26, 0.22, 1.0) if enemy_side else Color(0.24, 0.5, 0.8, 1.0), 10 if tight else 11)
	box.add_child(priority_chip)

	if tight:
		var chip_row := HBoxContainer.new()
		chip_row.add_theme_constant_override("separation", 6)
		box.add_child(chip_row)
		var hp_chip_data: Dictionary = _make_tight_info_chip("HP %d" % int(side.get("health", 0)), Color(0.24, 0.12, 0.14, 1.0), 58)
		chip_row.add_child(hp_chip_data["panel"])
		var secondary_text := "덱 %d" % (side.get("deck", []) as Array).size() if enemy_side else "손패 %d" % (side.get("hand", []) as Array).size()
		var secondary_chip_data: Dictionary = _make_tight_info_chip(secondary_text, Color(0.12, 0.14, 0.22, 1.0), 62)
		chip_row.add_child(secondary_chip_data["panel"])

	if enemy_side:
		enemy_hero_name_label = hero_name
		enemy_hero_hp_label = hp_label
		enemy_hero_sub_label = sub_label
	else:
		player_hero_name_label = hero_name
		player_hero_hp_label = hp_label
		player_hero_sub_label = sub_label

	return panel

func _make_hero_target(side: Dictionary, hero_art: int, enemy_target: bool, compact: bool) -> Control:
	var tight := _is_tight_battle_layout()
	var bg := Color(0.045, 0.06, 0.078, 0.92)
	var accent := Color(0.72, 0.18, 0.16, 1.0) if enemy_target else Color(0.18, 0.42, 0.72, 1.0)
	var node: Control
	var content_parent: Control
	if enemy_target:
		var button := Button.new()
		button.text = ""
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 58 if tight else (66 if compact else 56))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(Callable(self, "_attack_opponent_hero"))
		_style_battle_button(button, bg, accent, selected_attacker != -1 and not _is_player_input_locked())
		node = button
		content_parent = button
		hero_attack_button = button
	else:
		var panel := _make_battle_surface(bg, accent, 1, 10, 8)
		panel.custom_minimum_size = Vector2(0, 54 if tight else (62 if compact else 54))
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node = panel
		content_parent = panel

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10 if tight else 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_parent.add_child(row)

	var art: TextureRect = main._make_art_rect(hero_art, Vector2(42, 42) if tight else (Vector2(50, 50) if compact else Vector2(42, 42)))
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	var eyebrow_text := "TARGET" if enemy_target else "PLAYER"
	var eyebrow: Label = main._make_label(eyebrow_text, 9 if tight else 10, Color(0.58, 0.72, 0.88, 1.0))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	eyebrow.autowrap_mode = TextServer.AUTOWRAP_OFF
	eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(eyebrow)

	var name: Label = main._make_label(String(side.get("name", "")), 14 if tight else (17 if compact else 16), Color(0.95, 0.98, 1.0, 1.0))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name)

	var hp: Label = main._make_label("HP %d / %d" % [int(side.get("health", 0)), int(side.get("max_health", 0))], 12 if tight else (14 if compact else 13), Color(1.0, 0.62, 0.62, 1.0) if enemy_target else Color(0.72, 0.88, 1.0, 1.0))
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hp.autowrap_mode = TextServer.AUTOWRAP_OFF
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(hp)
	if enemy_target:
		opponent_hero_target = node
		opponent_hero_target_hp_label = hp
	else:
		player_hero_target = node
		player_hero_target_hp_label = hp

	var badge_text := "공격 가능" if enemy_target and selected_attacker != -1 else ("영웅 공격 대상" if enemy_target else "방어할 영웅")
	var badge := _make_battle_badge(badge_text, Color(0.08, 0.1, 0.13, 0.92), accent, 10 if tight else 10)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)
	return node

func _make_board_lane_header(title_text: String, subtitle_text: String, compact: bool, enemy_lane: bool) -> PanelContainer:
	var tight := _is_tight_battle_layout()
	var panel := _make_battle_surface(Color(0.025, 0.034, 0.045, 0.74), Color(0.58, 0.18, 0.16, 0.9) if enemy_lane else Color(0.18, 0.42, 0.7, 0.9), 1, 8, 8)
	panel.custom_minimum_size = Vector2(0, 28 if tight else (32 if compact else 30))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var icon_label: Label = main._make_label("⚔" if enemy_lane else "🛡", 11 if tight else 13, Color(1.0, 0.86, 0.58, 1.0))
	icon_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(icon_label)
	var title: Label = main._make_label(title_text, 12 if tight else (14 if compact else 15), Color(1.0, 0.94, 0.84, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(title)
	var subtitle: Label = main._make_label(subtitle_text, 10 if tight else (11 if compact else 12), Color(0.76, 0.82, 0.9, 1.0))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(subtitle)
	return panel

func _make_meta_box(title_text: String, compact: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10 if compact else 12)
	var title: Label = main._make_label(title_text, 16 if compact else 18, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	return box

func _make_section_panel(title_text: String, compact: bool, min_height: int = 0) -> Dictionary:
	var panel := _make_battle_surface(Color(0.035, 0.048, 0.062, 0.86), Color(0.18, 0.3, 0.42, 0.7), 1, 10, 12)
	if min_height > 0:
		panel.custom_minimum_size = Vector2(0, min_height)
	var tight := _is_tight_battle_layout()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6 if tight else (10 if compact else 12))
	var title: Label = main._make_label(title_text, 14 if tight else (16 if compact else 18), Color(0.72, 0.86, 1.0, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	panel.add_child(box)
	return {
		"panel": panel,
		"content": box,
	}

func _make_right_info_panel(title_text: String, compact: bool, min_height: int, accent_color: Color) -> Dictionary:
	var tight := _is_tight_battle_layout()
	var panel := _make_battle_surface(Color(0.03, 0.04, 0.052, 0.88), accent_color, 1, 10, 8)
	panel.custom_minimum_size = Vector2(0, min_height)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4 if tight else (6 if compact else 8))
	panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	box.add_child(header)

	var marker := ColorRect.new()
	marker.color = accent_color
	marker.custom_minimum_size = Vector2(3, 14 if tight else 18)
	header.add_child(marker)

	var title: Label = main._make_label(title_text, 12 if tight else (13 if compact else 14), Color(0.78, 0.9, 1.0, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var divider := ColorRect.new()
	divider.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.42)
	divider.custom_minimum_size = Vector2(0, 1)
	box.add_child(divider)

	return {
		"panel": panel,
		"content": box,
	}

func _make_deck_preview_panel(compact: bool, min_height: int) -> Dictionary:
	var deck_panel: Dictionary = _make_right_info_panel("남은 덱", compact, min_height, Color(0.42, 0.33, 0.72, 1.0))
	var deck_box: VBoxContainer = deck_panel["content"]
	var tight := _is_tight_battle_layout()

	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 6 if tight else 8)
	deck_box.add_child(count_row)

	var deck_icon: Label = main._make_label("▣", 12 if tight else (15 if compact else 17), Color(0.7, 0.62, 1.0, 1.0))
	deck_icon.autowrap_mode = TextServer.AUTOWRAP_OFF
	count_row.add_child(deck_icon)

	deck_count_label = main._make_label("", 13 if tight else (15 if compact else 16), Color(0.98, 0.96, 0.82, 1.0))
	deck_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	deck_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_row.add_child(deck_count_label)

	if not tight:
		var hint: Label = main._make_label("다음 드로우 후보", 10 if compact else 11, Color(0.58, 0.64, 0.72, 1.0))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		deck_box.add_child(hint)
	else:
		var hint_chip_data: Dictionary = _make_tight_info_chip("다음 드로우", Color(0.1, 0.12, 0.2, 1.0), 76)
		deck_box.add_child(hint_chip_data["panel"])

	var deck_scroll := ScrollContainer.new()
	deck_scroll.custom_minimum_size = Vector2(0, max(26 if tight else 38, min_height - (52 if tight else 64)))
	deck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_box.add_child(deck_scroll)

	deck_list_label = RichTextLabel.new()
	deck_list_label.fit_content = false
	deck_list_label.scroll_active = false
	deck_list_label.bbcode_enabled = true
	deck_list_label.custom_minimum_size = Vector2(0, max(22 if tight else 34, min_height - (58 if tight else 72)))
	deck_list_label.add_theme_color_override("default_color", Color(0.82, 0.87, 0.92, 1.0))
	deck_list_label.add_theme_font_size_override("normal_font_size", 10 if tight else (11 if compact else 12))
	deck_scroll.add_child(deck_list_label)

	return deck_panel

func _make_battle_log_panel(compact: bool, min_height: int) -> Dictionary:
	var log_panel: Dictionary = _make_right_info_panel("전투 로그", compact, min_height, Color(0.62, 0.42, 0.18, 1.0))
	var log_box: VBoxContainer = log_panel["content"]
	var tight := _is_tight_battle_layout()
	if not tight:
		var sub: Label = main._make_label("최근 행동이 위에 표시됩니다.", 10 if compact else 11, Color(0.62, 0.66, 0.72, 1.0))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		log_box.add_child(sub)
	var log_hint_chip: PanelContainer = main.ui.make_chip("사망 / 드로우 / 빌드 효과 확인", Color(0.16, 0.12, 0.08, 1.0), Color(0.96, 0.9, 0.76, 1.0), 10 if tight else 11)
	log_box.add_child(log_hint_chip)

	log_label = RichTextLabel.new()
	log_label.fit_content = false
	log_label.scroll_active = true
	log_label.bbcode_enabled = true
	log_label.custom_minimum_size = Vector2(0, max(58 if tight else 74, min_height - (44 if tight else 54)))
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_color_override("default_color", Color(0.86, 0.9, 0.94, 1.0))
	log_label.add_theme_font_size_override("normal_font_size", 10 if tight else (11 if compact else 12))
	log_box.add_child(log_label)

	return log_panel

func _make_battle_action_panel(compact: bool) -> PanelContainer:
	var tight := _is_tight_battle_layout()
	var vertical_stack := compact and not _is_wide_tight_battle_layout()
	var panel := _make_battle_surface(Color(0.035, 0.045, 0.058, 0.92), Color(0.18, 0.32, 0.46, 0.7), 1, 10, 10)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6 if tight else 8)
	panel.add_child(box)
	var title: Label = main._make_label("턴 조작", 12 if tight else (14 if compact else 15), Color(0.82, 0.9, 1.0, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	if tight:
		var sub: Label = main._make_label("공격은 전장 타겟에서 선택", 10, Color(0.66, 0.72, 0.8, 1.0))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(sub)
	var action_hint_chip: PanelContainer = _make_battle_badge("카드 사용 -> 전장 공격 -> 턴 종료", Color(0.08, 0.1, 0.13, 0.92), Color(0.25, 0.48, 0.72, 1.0), 10 if tight else 11)
	box.add_child(action_hint_chip)

	end_turn_button = Button.new()
	end_turn_button.text = "턴 종료"
	end_turn_button.custom_minimum_size = Vector2(320 if vertical_stack else 0, 48 if tight else (50 if compact else 58))
	if vertical_stack:
		end_turn_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_battle_button(end_turn_button, Color(0.08, 0.16, 0.24, 0.96), Color(0.22, 0.62, 0.95, 1.0), true)
	end_turn_button.add_theme_font_size_override("font_size", 12 if tight else 16)
	end_turn_button.pressed.connect(Callable(self, "_on_end_turn_pressed"))
	box.add_child(end_turn_button)

	var surrender_button := Button.new()
	surrender_button.text = "도망가기"
	surrender_button.custom_minimum_size = Vector2(320 if vertical_stack else 0, 42 if tight else (46 if compact else 50))
	if vertical_stack:
		surrender_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_battle_button(surrender_button, Color(0.12, 0.13, 0.16, 0.92), Color(0.34, 0.38, 0.46, 0.9), false)
	surrender_button.add_theme_font_size_override("font_size", 12 if tight else 14)
	surrender_button.pressed.connect(Callable(self, "_on_surrender_pressed"))
	box.add_child(surrender_button)

	return panel

func _on_surrender_pressed() -> void:
	if _is_player_input_locked():
		return
	_add_log("전투에서 도망쳤습니다. (패배)")
	_finish_player_defeat()

func _initialize_battle_runtime_ui() -> void:
	turn_overlay = Panel.new()
	turn_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	turn_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left = 60
	style.border_width_right = 60
	style.border_width_top = 60
	style.border_width_bottom = 60
	style.border_color = Color(0, 0, 0, 0)
	style.border_blend = true
	turn_overlay.add_theme_stylebox_override("panel", style)
	main.modal_layer.add_child(turn_overlay)

	if turn_timer != null and is_instance_valid(turn_timer):
		turn_timer.queue_free()
	turn_timer = Timer.new()
	turn_timer.one_shot = true
	turn_timer.timeout.connect(Callable(self, "_on_turn_timeout"))
	main.root_box.add_child(turn_timer)

func _escape_rich_text(value: String) -> String:
	return value.replace("[", "\\[").replace("]", "\\]")

func _total_field_attack(side: Dictionary) -> int:
	var total := 0
	for unit in side.get("field", []):
		total += int(Dictionary(unit).get("attack", 0))
	return total

func _build_stat_chip_texts() -> Array[String]:
	var scores: Dictionary = main._current_build_scores()
	return [
		"화염 %d" % int(scores.get("fire", 0)),
		"드로우 %d" % int(scores.get("draw", 0)),
		"사망 %d" % int(scores.get("death", 0)),
		"버프 %d" % int(scores.get("buff", 0)),
		"저체력 %d" % int(scores.get("low_hp", 0)),
		"소환 %d" % int(scores.get("summon", 0)),
	]

func _build_stat_chip_color(index: int) -> Color:
	var colors := [
		Color(0.42, 0.22, 0.12, 1.0),
		Color(0.14, 0.22, 0.38, 1.0),
		Color(0.24, 0.16, 0.34, 1.0),
		Color(0.36, 0.3, 0.12, 1.0),
		Color(0.34, 0.14, 0.16, 1.0),
		Color(0.12, 0.26, 0.2, 1.0),
	]
	return colors[index % colors.size()]

func _build_stat_chip_tags() -> Array[Dictionary]:
	var scores: Dictionary = main._current_build_scores()
	return [
		{"tag": "fire", "label": "화염", "value": int(scores.get("fire", 0))},
		{"tag": "draw", "label": "드로우", "value": int(scores.get("draw", 0))},
		{"tag": "death", "label": "사망", "value": int(scores.get("death", 0))},
		{"tag": "buff", "label": "버프", "value": int(scores.get("buff", 0))},
		{"tag": "low_hp", "label": "저체력", "value": int(scores.get("low_hp", 0))},
		{"tag": "summon", "label": "소환", "value": int(scores.get("summon", 0))},
	]

func _card_accent_color(card: Dictionary) -> Color:
	return main.ui.card_race_color(card)

func _make_hand_card_style(bg_color: Color, border_color: Color, border_width: int = 2) -> StyleBoxFlat:
	var style: StyleBoxFlat = main.ui.make_style_box(bg_color, border_color, border_width, 8)
	style.content_margin_left = 5
	style.content_margin_top = 5
	style.content_margin_right = 5
	style.content_margin_bottom = 5
	return style

func _make_modern_style(bg_color: Color, border_color: Color, border_width: int = 1, radius: int = 8, margin: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = margin
	style.content_margin_top = margin
	style.content_margin_right = margin
	style.content_margin_bottom = margin
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 5)
	return style

func _make_battle_surface(bg_color: Color, accent_color: Color, border_width: int = 1, radius: int = 8, margin: int = 10) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_modern_style(bg_color, accent_color, border_width, radius, margin))
	return panel

func _style_battle_button(button: Button, bg_color: Color, accent_color: Color, active: bool = false) -> void:
	var normal := _make_modern_style(bg_color, accent_color, 2 if active else 1, 8, 8)
	normal.shadow_size = 8 if active else 4
	var hover := normal.duplicate()
	hover.bg_color = bg_color.lightened(0.08)
	hover.border_color = accent_color.lightened(0.12)
	var pressed := normal.duplicate()
	pressed.bg_color = bg_color.darkened(0.08)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(bg_color.r, bg_color.g, bg_color.b, 0.42)
	disabled.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.34)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.5, 0.58, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.65))
	button.add_theme_constant_override("outline_size", 2)

func _make_battle_badge(text: String, bg_color: Color, accent_color: Color, font_size: int = 11) -> PanelContainer:
	var panel := _make_battle_surface(bg_color, accent_color, 1, 6, 5)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label: Label = main._make_label(text, font_size, Color(0.9, 0.94, 1.0, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel.add_child(label)
	return panel

func _make_field_slot_style(bg_color: Color, border_color: Color, border_width: int = 2) -> StyleBoxFlat:
	var style: StyleBoxFlat = _make_modern_style(bg_color, border_color, border_width, 8, 6)
	style.content_margin_left = 6
	style.content_margin_top = 5
	style.content_margin_right = 6
	style.content_margin_bottom = 5
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 3)
	return style

func _make_status_chip(text: String, bg_color: Color, font_size: int) -> Dictionary:
	var panel: PanelContainer = main.ui.make_surface_panel(bg_color, bg_color.lightened(0.16), 1, 8, 10)
	panel.custom_minimum_size = Vector2(0, 48)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label: Label = main._make_label(text, font_size, Color(0.96, 0.97, 0.94, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel.add_child(label)
	return {
		"panel": panel,
		"label": label,
	}

func _make_tight_info_chip(text: String, bg_color: Color, width: int = 72) -> Dictionary:
	var panel: PanelContainer = main.ui.make_surface_panel(bg_color, bg_color.lightened(0.18), 1, 8, 6)
	panel.custom_minimum_size = Vector2(width, 24)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label: Label = main._make_label(text, 11, Color(0.96, 0.97, 0.94, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel.add_child(label)
	return {
		"panel": panel,
		"label": label,
	}

func _render_build_chips() -> void:
	if build_chip_box == null or not is_instance_valid(build_chip_box):
		return
	_clear_container(build_chip_box)
	var compact := _is_compact_layout()
	var tight := _is_tight_battle_layout()
	var active_tags: Array = battle_state.get("active_build_tags", []) as Array
	var chip_data: Array[Dictionary] = _build_stat_chip_tags()
	for i in range(chip_data.size()):
		var item: Dictionary = chip_data[i]
		var active: bool = active_tags.has(String(item.get("tag", "")))
		var base_color: Color = _build_stat_chip_color(i)
		var panel: PanelContainer = main.ui.make_surface_panel(base_color.lightened(0.14) if active else base_color, Color(1.0, 0.78, 0.34, 1.0) if active else base_color.lightened(0.16), 2 if active else 1, 8, 6)
		panel.custom_minimum_size = Vector2(48 if tight else (54 if compact else 62), 38 if tight else (44 if compact else 48))
		var label: Label = main._make_label("%s\n%d" % [String(item.get("label", "")), int(item.get("value", 0))], 9 if tight else (10 if compact else 11), Color(1.0, 0.96, 0.82, 1.0) if active else Color(0.92, 0.94, 0.92, 1.0))
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		panel.add_child(label)
		build_chip_box.add_child(panel)

func _refresh_side_info_cards() -> void:
	if enemy_hero_name_label != null and is_instance_valid(enemy_hero_name_label):
		enemy_hero_name_label.text = String(opponent.get("name", "적 영웅"))
	if enemy_hero_hp_label != null and is_instance_valid(enemy_hero_hp_label):
		enemy_hero_hp_label.text = "❤ %d / %d" % [int(opponent.get("health", 0)), int(opponent.get("max_health", 0))]
	if enemy_hero_sub_label != null and is_instance_valid(enemy_hero_sub_label):
		enemy_hero_sub_label.text = "⚔ %d  |  덱 %d / 버림 %d" % [_total_field_attack(opponent), (opponent.get("deck", []) as Array).size(), (opponent.get("discard_pile", []) as Array).size()]
	if player_hero_name_label != null and is_instance_valid(player_hero_name_label):
		player_hero_name_label.text = String(player.get("name", "플레이어"))
	if player_hero_hp_label != null and is_instance_valid(player_hero_hp_label):
		player_hero_hp_label.text = "❤ %d / %d" % [int(player.get("health", 0)), int(player.get("max_health", 0))]
	if player_hero_sub_label != null and is_instance_valid(player_hero_sub_label):
		player_hero_sub_label.text = "⚔ %d  |  손패 %d" % [_total_field_attack(player), (player.get("hand", []) as Array).size()]
	if enemy_hand_count_label != null and is_instance_valid(enemy_hand_count_label):
		if enemy_deck_count_label == null:
			enemy_hand_count_label.text = "손패 %d | 덱 %d" % [(opponent.get("hand", []) as Array).size(), (opponent.get("deck", []) as Array).size()]
		else:
			enemy_hand_count_label.text = "손패 %d" % (opponent.get("hand", []) as Array).size()
	if enemy_deck_count_label != null and is_instance_valid(enemy_deck_count_label):
		enemy_deck_count_label.text = "덱 %d | 버림 %d" % [(opponent.get("deck", []) as Array).size(), (opponent.get("discard_pile", []) as Array).size()]
	if opponent_hero_target_hp_label != null and is_instance_valid(opponent_hero_target_hp_label):
		opponent_hero_target_hp_label.text = "HP %d / %d" % [int(opponent.get("health", 0)), int(opponent.get("max_health", 0))]
	if player_hero_target_hp_label != null and is_instance_valid(player_hero_target_hp_label):
		player_hero_target_hp_label.text = "HP %d / %d" % [int(player.get("health", 0)), int(player.get("max_health", 0))]

func _refresh_status_chips() -> void:
	if mana_status_label != null and is_instance_valid(mana_status_label):
		mana_status_label.text = "마나 %d / %d" % [int(player.get("mana", 0)), int(player.get("max_mana", 0))]
	if player_deck_status_label != null and is_instance_valid(player_deck_status_label):
		player_deck_status_label.text = "덱 %d | 버림 %d" % [(player.get("deck", []) as Array).size(), (player.get("discard_pile", []) as Array).size()]
	if player_field_status_label != null and is_instance_valid(player_field_status_label):
		player_field_status_label.text = "필드 %d / %d" % [player.field.size(), MAX_FIELD]

func _refresh_battle_dashboard() -> void:
	_refresh_side_info_cards()
	_refresh_status_chips()
	_render_build_chips()

func _player_has_available_action() -> bool:
	if _is_player_input_locked():
		return false
	for card in player.hand:
		if _can_play_card(player, card, "player"):
			return true
	for unit in player.field:
		if bool(Dictionary(unit).get("can_attack", false)):
			return true
	return false

func _build_battle_ui() -> void:
	var compact := _is_compact_layout()
	var tight := _is_tight_battle_layout()
	var wide_tight := _is_wide_tight_battle_layout()
	var portrait := _is_portrait_battle_layout()
	var vertical_stack := compact and not wide_tight
	var horizontal_battle := not vertical_stack
	root_box.add_theme_constant_override("separation", 6 if tight else 10)
	player_info = null
	player_gauge_info = null
	hero_attack_button = null
	opponent_hero_target = null
	player_hero_target = null
	opponent_hero_target_hp_label = null
	player_hero_target_hp_label = null
	enemy_hero_name_label = null
	enemy_hero_hp_label = null
	enemy_hero_sub_label = null
	player_hero_name_label = null
	player_hero_hp_label = null
	player_hero_sub_label = null
	enemy_hand_count_label = null
	enemy_deck_count_label = null
	build_chip_box = null
	mana_status_label = null
	player_deck_status_label = null
	player_field_status_label = null
	var field_height := 118 if wide_tight else (96 if tight and portrait else (106 if tight else (132 if not compact else 120)))
	var board_width := 760 if not compact else 0
	var sidebar_width := 136 if wide_tight else (170 if tight else (178 if not compact else 0))
	var hand_height := 178 if wide_tight else (208 if tight and portrait else (190 if tight else (236 if not compact else 214)))
	var deck_height := 44 if wide_tight else (58 if tight else (108 if not compact else 78))
	var log_height := 72 if wide_tight else (112 if tight else (162 if not compact else 126))
	var battle_root := _make_battle_content_root(tight)

	battle_root.add_child(_make_top_status_bar(compact))
	battle_root.add_child(_make_battle_guidance_panel(compact))

	var main_row: BoxContainer = VBoxContainer.new() if vertical_stack else HBoxContainer.new()
	main_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	main_row.add_theme_constant_override("separation", 8 if vertical_stack else (8 if tight else 12))
	battle_root.add_child(main_row)

	var left_column := VBoxContainer.new()
	left_column.custom_minimum_size = Vector2(sidebar_width, 0)
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL if vertical_stack else Control.SIZE_SHRINK_BEGIN
	left_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	left_column.add_theme_constant_override("separation", 4 if tight else 8)
	if horizontal_battle:
		main_row.add_child(left_column)

	left_column.add_child(_make_side_info_card("적 영웅", opponent, ENEMY_HERO_ART, compact, true))

	var enemy_meta: Dictionary = _make_section_panel("적 효과", compact, 54 if wide_tight else (72 if tight else (88 if not compact else 86)))
	left_column.add_child(enemy_meta["panel"])
	var enemy_meta_box: VBoxContainer = enemy_meta["content"]
	if wide_tight:
		enemy_hand_count_label = main._make_label("손패 %d | 덱 %d" % [(opponent.get("hand", []) as Array).size(), (opponent.get("deck", []) as Array).size()], 10, Color(0.84, 0.88, 0.94, 1.0))
		enemy_hand_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		enemy_meta_box.add_child(enemy_hand_count_label)
	else:
		var enemy_state: Label = main._make_label("현재 전투: %s" % main._node_type_name(battle_tier), 12 if tight else (14 if compact else 15), Color(0.84, 0.88, 0.94, 1.0))
		enemy_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		enemy_meta_box.add_child(enemy_state)
		var enemy_stat_row := HBoxContainer.new()
		enemy_stat_row.add_theme_constant_override("separation", 6)
		enemy_meta_box.add_child(enemy_stat_row)
		enemy_stat_row.add_child(main.ui.make_stat_tile("손패", str((opponent.get("hand", []) as Array).size()), Color(0.22, 0.18, 0.42, 1.0), compact))
		enemy_stat_row.add_child(main.ui.make_stat_tile("덱", str((opponent.get("deck", []) as Array).size()), Color(0.16, 0.18, 0.24, 1.0), compact))
		enemy_meta_box.add_child(main.ui.make_objective_panel("위협 요약", "손패와 덱 수를 보고 다음 턴 압박을 예측하세요.", tight or compact))
		if tight:
			var enemy_hint_chip: PanelContainer = main.ui.make_chip("상대 영웅 HP를 우선 확인하세요", Color(0.16, 0.16, 0.11, 1.0), Color(0.96, 0.92, 0.78, 1.0), 10)
			enemy_meta_box.add_child(enemy_hint_chip)
	if not tight:
		enemy_hand_count_label = main._make_label("손패 %d" % (opponent.get("hand", []) as Array).size(), 14 if compact else 15, Color(0.84, 0.88, 0.94, 1.0))
		enemy_hand_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		enemy_meta_box.add_child(enemy_hand_count_label)
		enemy_deck_count_label = main._make_label("덱 %d" % (opponent.get("deck", []) as Array).size(), 14 if compact else 15, Color(0.84, 0.88, 0.94, 1.0))
		enemy_deck_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		enemy_meta_box.add_child(enemy_deck_count_label)
		var enemy_hint: Label = main._make_label("사망 효과와 직접 피해 로그를 확인하세요.", 11 if compact else 12, Color(0.7, 0.76, 0.84, 1.0))
		enemy_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		enemy_meta_box.add_child(enemy_hint)

	var center_column := VBoxContainer.new()
	center_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_column.add_theme_constant_override("separation", 6 if tight else 8)
	if not compact:
		center_column.custom_minimum_size = Vector2(board_width, 0)
	elif wide_tight:
		center_column.custom_minimum_size = Vector2(0, 0)
	main_row.add_child(center_column)

	var board_panel := _make_battle_surface(Color(0.025, 0.034, 0.045, 0.9), Color(0.16, 0.28, 0.38, 0.78), 1, 12, 6 if tight else 10)
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	center_column.add_child(board_panel)
	var board_box := VBoxContainer.new()
	board_box.add_theme_constant_override("separation", 4 if tight else 7)
	board_panel.add_child(board_box)

	opponent_info = main._make_label("", 18 if tight else (16 if not compact else 17), Color(1.0, 0.88, 0.84, 1.0))
	opponent_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	board_box.add_child(opponent_info)
	opponent_gauge_info = main._make_label("", 12 if tight else (12 if not compact else 12), Color(0.78, 0.82, 0.9, 1.0))
	opponent_gauge_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	board_box.add_child(opponent_gauge_info)
	if tight:
		var board_goal_chip: PanelContainer = main.ui.make_chip("목표: 적 영웅 HP 0", Color(0.16, 0.1, 0.08, 1.0), Color(1.0, 0.9, 0.76, 1.0), 11)
		board_box.add_child(board_goal_chip)
	board_box.add_child(_make_hero_target(opponent, ENEMY_HERO_ART, true, compact))
	board_box.add_child(_make_board_lane_header("적 전장", "유닛 5칸", compact, true))

	opponent_field_box = HBoxContainer.new()
	opponent_field_box.alignment = BoxContainer.ALIGNMENT_CENTER
	opponent_field_box.custom_minimum_size = Vector2(0, field_height)
	opponent_field_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_box.add_child(opponent_field_box)

	var divider := ColorRect.new()
	divider.color = Color(0.28, 0.22, 0.12, 1.0)
	divider.custom_minimum_size = Vector2(0, 1 if tight else 2)
	board_box.add_child(divider)
	board_box.add_child(_make_board_lane_header("내 전장", "필드 장악과 영웅 압박", compact, false))

	player_field_box = HBoxContainer.new()
	player_field_box.alignment = BoxContainer.ALIGNMENT_CENTER
	player_field_box.custom_minimum_size = Vector2(0, field_height)
	player_field_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_box.add_child(player_field_box)
	board_box.add_child(_make_hero_target(player, PLAYER_HERO_ART, false, compact))

	var player_strip: BoxContainer = HBoxContainer.new() if wide_tight else (VBoxContainer.new() if compact else HBoxContainer.new())
	player_strip.add_theme_constant_override("separation", 4 if tight else 8)
	board_box.add_child(player_strip)

	if tight:
		var player_hp_data: Dictionary = _make_tight_info_chip("HP 0/0", Color(0.11, 0.13, 0.18, 1.0), 92)
		player_info = player_hp_data["label"]
		var player_hp_panel: PanelContainer = player_hp_data["panel"]
		player_hp_panel.custom_minimum_size = Vector2(92, 30)
		player_strip.add_child(player_hp_panel)
	elif not compact:
		var player_status_panel := _make_battle_surface(Color(0.035, 0.048, 0.062, 0.86), Color(0.18, 0.42, 0.7, 0.82), 1, 8, 6)
		player_status_panel.custom_minimum_size = Vector2(160, 40)
		player_strip.add_child(player_status_panel)
		player_info = main._make_label("HP %d/%d" % [int(player.get("health", 0)), int(player.get("max_health", 0))], 14, Color(0.78, 0.9, 1.0, 1.0))
		player_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		player_status_panel.add_child(player_info)
	else:
		var player_status_panel := _make_side_info_card("플레이어", player, PLAYER_HERO_ART, compact, false)
		player_status_panel.custom_minimum_size = Vector2(0, 92)
		player_strip.add_child(player_status_panel)

	var chips_wrap: BoxContainer = HBoxContainer.new() if wide_tight else (VBoxContainer.new() if compact else HBoxContainer.new())
	chips_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips_wrap.add_theme_constant_override("separation", 4 if tight else 8)
	player_strip.add_child(chips_wrap)
	build_chip_box = chips_wrap
	_render_build_chips()
	if tight:
		player_gauge_info = main._make_label("", 10, Color(0.76, 0.82, 0.9, 1.0))
		player_gauge_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		player_gauge_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player_strip.add_child(player_gauge_info)

	var turn_actions: BoxContainer = HBoxContainer.new() if wide_tight else (VBoxContainer.new() if compact else HBoxContainer.new())
	turn_actions.add_theme_constant_override("separation", 4 if tight else 8)
	player_strip.add_child(turn_actions)

	var mana_chip_data: Dictionary = _make_tight_info_chip("마나 0/0", Color(0.08, 0.18, 0.32, 1.0), 82) if tight else _make_status_chip("마나 0 / 0", Color(0.08, 0.18, 0.32, 1.0), 15 if compact else 16)
	mana_status_label = mana_chip_data["label"]
	var mana_panel: PanelContainer = mana_chip_data["panel"]
	mana_panel.custom_minimum_size = Vector2(82 if tight else (94 if compact else 108), 30 if tight else (48 if compact else 56))
	turn_actions.add_child(mana_chip_data["panel"])

	var right_column := VBoxContainer.new()
	right_column.custom_minimum_size = Vector2(sidebar_width, 0)
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL if vertical_stack else Control.SIZE_SHRINK_BEGIN
	right_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right_column.add_theme_constant_override("separation", 4 if tight else 8)
	if horizontal_battle:
		main_row.add_child(right_column)

	var deck_panel: Dictionary = _make_deck_preview_panel(compact, deck_height)
	right_column.add_child(deck_panel["panel"])

	var log_panel: Dictionary = _make_battle_log_panel(compact, log_height)
	right_column.add_child(log_panel["panel"])
	if not (tight and vertical_stack):
		right_column.add_child(_make_battle_action_panel(compact))

	if tight:
		var tight_actions_panel := _make_battle_action_panel(compact)
		if vertical_stack:
			center_column.add_child(tight_actions_panel)
		var tight_hand_panel: PanelContainer = main.ui.make_surface_panel(Color(0.06, 0.07, 0.09, 1.0), Color(0.22, 0.18, 0.1, 1.0), 1, 12, 8)
		tight_hand_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tight_hand_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		center_column.add_child(tight_hand_panel)
		var tight_hand_box := VBoxContainer.new()
		tight_hand_box.add_theme_constant_override("separation", 4)
		tight_hand_panel.add_child(tight_hand_box)
		player_deck_status_label = deck_count_label
		player_field_status_label = null
		hand_box = HFlowContainer.new()
		hand_box.custom_minimum_size = Vector2(0, hand_height)
		hand_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hand_box.add_theme_constant_override("h_separation", 6)
		hand_box.add_theme_constant_override("v_separation", 6)
		tight_hand_box.add_child(hand_box)
		if vertical_stack:
			left_column.visible = false
			right_column.visible = false
			main_row.add_child(left_column)
			main_row.add_child(right_column)
		_initialize_battle_runtime_ui()
		return

	var bottom_row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	bottom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_theme_constant_override("separation", 10 if tight else 12)
	battle_root.add_child(bottom_row)

	var left_actions_panel: PanelContainer = main.ui.make_surface_panel(Color(0.055, 0.06, 0.075, 0.98), Color(0.2, 0.16, 0.3, 1.0), 1, 10, 10)
	left_actions_panel.custom_minimum_size = Vector2(sidebar_width, 0)
	bottom_row.add_child(left_actions_panel)
	var left_actions := VBoxContainer.new()
	left_actions.custom_minimum_size = Vector2(sidebar_width, 0)
	left_actions.add_theme_constant_override("separation", 6 if tight else 8)
	left_actions_panel.add_child(left_actions)
	if not tight:
		var left_actions_title: Label = main._make_label("전투 자원", 14 if compact else 15, Color(1.0, 0.88, 0.56, 1.0))
		left_actions_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		left_actions.add_child(left_actions_title)
	var deck_chip_data: Dictionary = _make_status_chip("덱 %d" % (player.get("deck", []) as Array).size(), Color(0.16, 0.12, 0.28, 1.0), 16 if compact else 18)
	player_deck_status_label = deck_chip_data["label"]
	left_actions.add_child(deck_chip_data["panel"])
	var field_chip_data: Dictionary = _make_status_chip("필드 %d / %d" % [player.field.size(), MAX_FIELD], Color(0.12, 0.14, 0.18, 1.0), 15 if compact else 16)
	player_field_status_label = field_chip_data["label"]
	left_actions.add_child(field_chip_data["panel"])
	if not tight:
		var utility_hint: Label = main._make_label("밝은 카드는 사용 가능, 선택된 유닛은 공격 가능 상태입니다.", 11 if compact else 12, Color(0.74, 0.8, 0.88, 1.0))
		utility_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		left_actions.add_child(utility_hint)

	var hand_panel: PanelContainer = main.ui.make_surface_panel(Color(0.06, 0.07, 0.09, 1.0), Color(0.22, 0.18, 0.1, 1.0), 1, 12, 10)
	hand_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(hand_panel)
	var hand_box_wrap := VBoxContainer.new()
	hand_box_wrap.add_theme_constant_override("separation", 4 if tight else 6)
	hand_panel.add_child(hand_box_wrap)
	var hand_header := HBoxContainer.new()
	hand_header.add_theme_constant_override("separation", 8)
	hand_box_wrap.add_child(hand_header)
	var hand_title: Label = main._make_label("내 손패", 11 if tight else (13 if compact else 15), Color(1.0, 0.88, 0.55, 1.0))
	hand_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hand_header.add_child(hand_title)
	var hand_hint: Label = main._make_label("밝은 카드를 사용하세요", 10 if tight else (11 if compact else 12), Color(0.76, 0.82, 0.9, 1.0))
	hand_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hand_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_header.add_child(hand_hint)
	if compact:
		var hand_goal_chip_large: PanelContainer = main.ui.make_chip("핵심 카드부터 사용하고 공격 가능한 유닛으로 마무리하세요", Color(0.16, 0.16, 0.1, 1.0), Color(0.96, 0.94, 0.82, 1.0), 11)
		hand_box_wrap.add_child(hand_goal_chip_large)
	hand_box = HFlowContainer.new()
	hand_box.custom_minimum_size = Vector2(0, hand_height)
	hand_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_box.add_theme_constant_override("h_separation", 8)
	hand_box.add_theme_constant_override("v_separation", 8)
	hand_box_wrap.add_child(hand_box)

	_initialize_battle_runtime_ui()

func _start_turn(side: Dictionary, is_player_turn: bool) -> void:
	if is_player_turn:
		turn_timer.start(TURN_TIME_SECONDS)
		await _show_turn_banner("내 턴!", true)
	else:
		turn_timer.stop()
		turn_timer_label.text = ""
		await _show_turn_banner("적 턴!", false)

	side.max_mana = min(MAX_MANA, int(side.max_mana) + 1)
	side.mana = side.max_mana
	if is_player_turn and bool(battle_state.get("mana_crystal_bonus", false)):
		side.mana += 1
		side.max_mana += 1
		battle_state["mana_crystal_bonus"] = false
	for unit in side.field:
		unit.can_attack = true
	_draw_cards(side, 5)
	if is_player_turn:
		battle_state["cards_played_this_turn"] = 0
		main.relic_service.on_turn_start(main.current_run, battle_state, player)
		_apply_build_on_turn_start()
	_apply_delayed_status(side)
	_check_game_over()
	if game_over:
		return
	_add_log("%s 턴 시작: 마나 %d/%d" % [side.name, side.mana, side.max_mana])
	_store_battle_snapshot()


func _apply_delayed_status(side: Dictionary) -> void:
	var curses := int(side.get("curses", 0))
	if curses > 0:
		side["health"] = int(side.get("health", 0)) - curses
		side["curses"] = 0
		_add_log("%s 저주 발동: 영웅 피해 %d" % [String(side.get("name", "대상")), curses])
	var ritual_stacks := int(side.get("ritual_stacks", 0))
	if ritual_stacks > 0:
		side["health"] = min(int(side.get("max_health", side.get("health", 0))), int(side.get("health", 0)) + ritual_stacks)
		side["ritual_stacks"] = 0
		_add_log("%s 의식 발동: 영웅 체력 %d 회복" % [String(side.get("name", "대상")), ritual_stacks])


func _show_turn_banner(text: String, is_player: bool) -> void:
	if _should_skip_timed_battle_fx():
		return
	if turn_overlay and is_instance_valid(turn_overlay):
		var target_color = Color(0.2, 0.5, 1.0, 0.25) if is_player else Color(0.9, 0.2, 0.2, 0.25)
		var style: StyleBoxFlat = turn_overlay.get_theme_stylebox("panel")
		var bg_tween = main.create_tween()
		bg_tween.tween_property(style, "border_color", target_color, 0.6)

	var banner := PanelContainer.new()
	banner.custom_minimum_size = Vector2(260, 54)
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color(0.04, 0.06, 0.08, 0.92)
	banner_style.border_color = Color(0.52, 0.68, 0.9, 0.95) if is_player else Color(0.9, 0.36, 0.3, 0.95)
	banner_style.border_width_left = 2
	banner_style.border_width_top = 2
	banner_style.border_width_right = 2
	banner_style.border_width_bottom = 2
	banner_style.corner_radius_top_left = 10
	banner_style.corner_radius_top_right = 10
	banner_style.corner_radius_bottom_left = 10
	banner_style.corner_radius_bottom_right = 10
	banner_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	banner_style.shadow_size = 8
	banner.add_theme_stylebox_override("panel", banner_style)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	var color = Color(0.6, 0.8, 1.0) if is_player else Color(1.0, 0.5, 0.5)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1))
	label.add_theme_constant_override("outline_size", 4)
	banner.add_child(label)
	
	main.add_child(banner)
	
	var viewport_size: Vector2 = main._layout_viewport_size()
	banner.position = Vector2((viewport_size.x - 260.0) / 2.0, 126.0)
	banner.pivot_offset = Vector2(130, 27)
	banner.scale = Vector2(0.88, 0.88)
	banner.modulate.a = 0.0
	
	var tween = main.create_tween()
	tween.tween_property(banner, "scale", Vector2(1.0, 1.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(banner, "modulate:a", 1.0, 0.12)
	tween.tween_interval(0.28)
	tween.tween_property(banner, "modulate:a", 0.0, 0.16)
	tween.tween_callback(banner.queue_free)
	await tween.finished


func _discard_hand(side: Dictionary) -> void:
	if side.hand.size() > 0:
		for card in side.hand:
			side.discard_pile.append(card)
		side.hand.clear()
		_add_log("%s 패 버림" % side.name)

func _draw_cards(side: Dictionary, count: int) -> void:
	for i in range(count):
		if side.deck.is_empty():
			if not side.discard_pile.is_empty():
				side.deck = side.discard_pile.duplicate()
				side.discard_pile.clear()
				side.deck.shuffle()
				_add_log("%s 덱 재정렬" % side.name)
			else:
				side.health -= 1
				_add_log("%s 덱 고갈: 피해 1" % side.name)
				continue
		
		if side.hand.size() < 10:
			side.hand.append(side.deck.pop_back())
		else:
			var burned_card = side.deck.pop_back()
			side.discard_pile.append(burned_card)
			_add_log("패가 가득 차서 카드가 버려짐: %s" % burned_card.get("name", ""))


func _on_hand_card_pressed(index: int) -> void:
	if input_locked or game_over or current_player != "player":
		return
	if index < 0 or index >= player.hand.size():
		return
	var card: Dictionary = player.hand[index]
	var cost: int = main.relic_service.modify_card_cost(main.current_run, battle_state, card, "player")
	if not _can_play_card(player, card, "player"):
		if cost > int(player.mana):
			_add_log("마나가 부족합니다.")
		elif String(card.get("type", "")) == "unit":
			_add_log("필드가 가득 찼습니다.")
		else:
			_add_log("장착할 아군 유닛이 없습니다.")
		return
	player.mana -= cost
	player.hand.remove_at(index)
	if String(card.get("type", "")) != "unit":
		player.discard_pile.append(card)
	main.relic_service.consume_card_discount(battle_state)
	battle_state["cards_played_this_turn"] = int(battle_state.get("cards_played_this_turn", 0)) + 1
	var old_p_hp = int(player.health)
	var old_o_hp = int(opponent.health)
	main.battle_effects.play_card(player, opponent, card, _battle_effect_context())
	main.relic_service.on_card_played(main.current_run, battle_state, player)
	_apply_damage_juice(old_p_hp, old_o_hp)
	_check_game_over()
	_refresh_ui()
	_store_battle_snapshot()
	_check_no_actions_loss()


func _battle_effect_context() -> Dictionary:
	return {
		"draw_cards": Callable(self, "_draw_cards"),
		"log": Callable(self, "_add_log"),
		"cleanup_dead_units": Callable(self, "_cleanup_dead_units"),
		"calculate_damage": Callable(self, "_calculate_damage"),
		"on_unit_summoned": Callable(self, "_apply_build_on_unit_summoned"),
		"relic_service": main.relic_service,
		"run_data": main.current_run,
		"max_health": int(main.current_run.get("max_hp", 50)),
		"cards_played_this_turn": int(battle_state.get("cards_played_this_turn", 0)),
	}


func _calculate_damage(card_or_unit: Dictionary, is_spell: bool, owner_state: Dictionary, base_damage: int) -> int:
	return base_damage + main.relic_service.damage_bonus(main.current_run, card_or_unit, is_spell, owner_state) + _build_damage_bonus(card_or_unit, is_spell, owner_state)


func _on_player_unit_pressed(index: int) -> void:
	if input_locked or game_over or current_player != "player":
		return
	if index < 0 or index >= player.field.size():
		return
	if not bool(player.field[index].can_attack):
		_add_log("이 유닛은 이번 턴 공격할 수 없습니다.")
		return
	selected_attacker = index
	_add_log("%s 공격 대상 선택 중" % player.field[index].name)
	_refresh_ui()
	_store_battle_snapshot()


func _on_opponent_unit_pressed(index: int) -> void:
	if input_locked or game_over or current_player != "player" or selected_attacker == -1:
		return
	if index < 0 or index >= opponent.field.size():
		return
	await _combat(player, opponent, selected_attacker, index)
	selected_attacker = -1
	_check_game_over()
	_refresh_ui()
	_store_battle_snapshot()
	_check_no_actions_loss()


func _attack_opponent_hero() -> void:
	if input_locked or game_over or current_player != "player" or selected_attacker == -1:
		return
	var attacker: Dictionary = player.field[selected_attacker]
	var damage := _calculate_damage(attacker, false, player, int(attacker.attack))
	input_locked = true
	_refresh_ui()
	await _play_hero_cutscene(attacker, opponent.name, damage, player, selected_attacker, false)
	damage = main.relic_service.mitigate_hero_damage(main.current_run, battle_state, damage, false)
	opponent.health -= damage
	attacker.can_attack = false
	if damage >= 3:
		_shake_screen(15.0, 0.3)
	_add_log("%s가 상대 영웅에게 피해 %d" % [attacker.name, damage])
	selected_attacker = -1
	input_locked = false
	_check_game_over()
	_refresh_ui()
	_store_battle_snapshot()
	_check_no_actions_loss()


func _combat(attacker_side: Dictionary, defender_side: Dictionary, attacker_index: int, defender_index: int) -> void:
	var attacker: Dictionary = attacker_side.field[attacker_index]
	var defender: Dictionary = defender_side.field[defender_index]
	var attack_damage := _calculate_damage(attacker, false, attacker_side, int(attacker.attack))
	var defense_damage := _calculate_damage(defender, false, defender_side, int(defender.attack))
	
	if int(defender.health) - attack_damage <= 0:
		defense_damage = 0
		
	input_locked = true
	_refresh_ui()
	
	await _play_unit_battle_feedback(attacker_side, defender_side, attacker_index, defender_index, attack_damage, defense_damage)
	
	defender.health -= attack_damage
	attacker.health -= defense_damage
	if attack_damage >= 3 or defense_damage >= 3:
		_shake_screen(10.0, 0.2)
	attacker.can_attack = false
	
	_add_log("%s 공격! %s에게 %d 피해" % [attacker.name, defender.name, attack_damage])
	if defense_damage > 0:
		_add_log("%s 반격! %s에게 %d 피해" % [defender.name, attacker.name, defense_damage])
	elif int(defender.health) <= 0:
		_add_log("%s가 처치되었습니다." % defender.name)
		
	_cleanup_dead_units(attacker_side, defender_side)
	input_locked = false
	_store_battle_snapshot()


func _check_no_actions_loss() -> void:
	if current_player != "player" or input_locked or game_over or main.active_screen != "battle":
		return
	var has_attacker := false
	for unit in player.field:
		if bool(unit.get("can_attack", false)):
			has_attacker = true
			break
	var has_playable_card := false
	for card in player.hand:
		if _can_play_card(player, card, "player"):
			has_playable_card = true
			break
	if not has_attacker and not has_playable_card:
		_add_log("더 이상 할 수 있는 행동이 없어 턴을 종료합니다.")
		call_deferred("_on_end_turn_pressed")




func _play_hero_cutscene(attacker: Dictionary, defender_name: String, damage: int, attacker_side: Dictionary, attacker_index: int, defender_is_player: bool) -> void:
	await _play_hero_attack_feedback(attacker_side, attacker_index, defender_is_player, damage)

func _field_slot_for(side: Dictionary, index: int) -> Control:
	var slots := player_field_slots if side == player else opponent_field_slots
	if index < 0 or index >= slots.size():
		return null
	var slot: Control = slots[index]
	if slot == null or not is_instance_valid(slot):
		return null
	return slot

func _hero_target_for_player(is_player_target: bool) -> Control:
	var target := player_hero_target if is_player_target else opponent_hero_target
	if target == null or not is_instance_valid(target):
		return null
	return target

func _play_unit_battle_feedback(attacker_side: Dictionary, defender_side: Dictionary, attacker_index: int, defender_index: int, attack_damage: int, defense_damage: int) -> void:
	var attacker_node := _field_slot_for(attacker_side, attacker_index)
	var defender_node := _field_slot_for(defender_side, defender_index)
	if not _is_battle_cutscene_enabled():
		_show_damage_number(defender_node, attack_damage)
		_show_damage_number(attacker_node, defense_damage)
		return
	await _play_inline_attack_feedback(attacker_node, defender_node, attack_damage, attacker_side == player)
	if defense_damage > 0:
		await _play_inline_attack_feedback(defender_node, attacker_node, defense_damage, defender_side == player, true)

func _play_hero_attack_feedback(attacker_side: Dictionary, attacker_index: int, defender_is_player: bool, damage: int) -> void:
	var attacker_node := _field_slot_for(attacker_side, attacker_index)
	var defender_node := _hero_target_for_player(defender_is_player)
	if not _is_battle_cutscene_enabled():
		_show_damage_number(defender_node, damage)
		return
	await _play_inline_attack_feedback(attacker_node, defender_node, damage, attacker_side == player)

func _play_inline_attack_feedback(attacker_node: Control, defender_node: Control, damage: int, attacker_is_player: bool, counter: bool = false) -> void:
	if attacker_node == null or defender_node == null:
		_show_damage_number(defender_node, damage)
		return
	var start_pos := attacker_node.position
	var lunge_offset := Vector2(0, -22 if attacker_is_player else 22)
	if counter:
		lunge_offset *= 0.75
	var lunge := attacker_node.create_tween()
	lunge.tween_property(attacker_node, "position", start_pos + lunge_offset, 0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	lunge.tween_property(attacker_node, "position", start_pos, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await lunge.finished
	_show_damage_number(defender_node, damage)
	_spawn_impact_slash(defender_node)
	await _shake_target(defender_node, 8.0 if damage < 3 else 12.0)

func _show_damage_number(target: Control, damage: int) -> void:
	if damage <= 0 or target == null or not is_instance_valid(target):
		return
	_spawn_floating_text(target, -damage)

func _shake_target(target: Control, intensity: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var origin := target.position
	var tween := target.create_tween()
	for i in range(4):
		tween.tween_property(target, "position", origin + Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), 0.035)
	tween.tween_property(target, "position", origin, 0.05)
	await tween.finished

func _spawn_impact_slash(target: Control) -> void:
	if target == null or not is_instance_valid(target):
		return
	var slash := Line2D.new()
	slash.width = 6.0
	slash.default_color = Color(0.72, 0.9, 1.0, 0.95)
	slash.begin_cap_mode = Line2D.LINE_CAP_ROUND
	slash.end_cap_mode = Line2D.LINE_CAP_ROUND
	var cx: float = max(24.0, target.size.x * 0.5)
	var cy: float = max(24.0, target.size.y * 0.5)
	slash.add_point(Vector2(cx - 34.0, cy - 26.0))
	slash.add_point(Vector2(cx + 34.0, cy + 26.0))
	target.add_child(slash)
	var tween := slash.create_tween()
	tween.tween_property(slash, "width", 0.0, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slash, "modulate:a", 0.0, 0.18)
	tween.tween_callback(slash.queue_free)


func _cleanup_dead_units(side_a: Dictionary, side_b: Dictionary) -> void:
	_cleanup_side_dead(side_a, side_b)
	_cleanup_side_dead(side_b, side_a)


func _cleanup_side_dead(owner: Dictionary, enemy: Dictionary) -> void:
	for i in range(owner.field.size() - 1, -1, -1):
		if int(owner.field[i].health) <= 0:
			var dead_unit: Dictionary = owner.field[i]
			owner.field.remove_at(i)
			if dead_unit.has("id") and String(dead_unit.get("id", "")) != "build_token":
				var original_card = main.card_db.get_card(String(dead_unit.get("id", "")))
				if not original_card.is_empty():
					owner.discard_pile.append(original_card)
			main.battle_effects.on_unit_died(dead_unit, owner, enemy, _battle_effect_context())
			if owner == player:
				main.relic_service.on_ally_unit_died(main.current_run, battle_state, dead_unit)
				_apply_build_on_ally_died(enemy)
			_add_log("%s 사망" % String(dead_unit.get("name", "")))


func _on_end_turn_pressed() -> void:
	if input_locked or game_over or current_player != "player":
		return
	input_locked = true
	_discard_hand(player)
	current_player = "opponent"
	selected_attacker = -1
	await _start_turn(opponent, false)
	_refresh_ui()
	_store_battle_snapshot()
	var ai_wait := 0.5
	if _is_fast_ai_enabled():
		ai_wait = 0.08
	await main.get_tree().create_timer(ai_wait).timeout
	await _run_ai_turn()


func _run_ai_turn() -> void:
	if game_over:
		return
	await _run_ai_play_cards()
	await _run_ai_attack_sequence()
	if not game_over:
		_discard_hand(opponent)
		current_player = "player"
		await _start_turn(player, true)
		input_locked = false
	_refresh_ui()
	_store_battle_snapshot()

func _run_ai_play_cards() -> void:
	var played := true
	while played:
		played = false
		for i in range(opponent.hand.size()):
			var card: Dictionary = opponent.hand[i]
			if _can_play_card(opponent, card, "opponent"):
				var cost: int = main.relic_service.modify_card_cost(main.current_run, battle_state, card, "opponent")
				opponent.mana -= cost
				opponent.hand.remove_at(i)
				if String(card.get("type", "")) != "unit":
					opponent.discard_pile.append(card)
				main.battle_effects.play_card(opponent, player, card, _battle_effect_context())
				_check_game_over()
				played = true
				if game_over:
					return
				if not _is_fast_ai_enabled():
					await main.get_tree().create_timer(0.2).timeout
				_store_battle_snapshot()
				break

func _run_ai_attack_sequence() -> void:
	var i := 0
	while i < opponent.field.size():
		if not bool(opponent.field[i].can_attack):
			i += 1
			continue
		if not player.field.is_empty():
			await _combat(opponent, player, i, 0)
		else:
			await _run_ai_hero_attack(i)
		_check_game_over()
		if game_over:
			break
		if i < opponent.field.size() and not bool(opponent.field[i].can_attack):
			i += 1

func _run_ai_hero_attack(index: int) -> void:
	if index >= opponent.field.size():
		return
	var unit: Dictionary = opponent.field[index]
	var damage := _calculate_damage(unit, false, opponent, int(unit.attack))
	input_locked = true
	_refresh_ui()
	await _play_hero_cutscene(unit, player.name, damage, opponent, index, true)
	damage = main.relic_service.mitigate_hero_damage(main.current_run, battle_state, damage, true)
	player.health -= damage
	if damage > 0:
		main.relic_service.on_hero_hp_lost(main.current_run, battle_state, player, damage)
	unit.can_attack = false
	_add_log("%s가 내 영웅에게 피해 %d" % [unit.name, damage])
	input_locked = false
	_store_battle_snapshot()


func _check_game_over() -> void:
	if battle_finished:
		return
	if int(player.health) <= 0:
		var upgrades := _profile_upgrades()
		if int(upgrades.get("second_chance", 0)) > 0 and not bool(battle_state.get("second_chance_used", false)):
			battle_state["second_chance_used"] = true
			player.health = 1
			_add_log("두 번째 기회 발동: 체력 1로 버팁니다.")
			_refresh_ui()
			return
		_finish_player_defeat()
	elif int(opponent.health) <= 0:
		_add_log("적 영웅을 쓰러뜨려 승리했습니다.")
		_finish_player_victory("health")
		await _finish_battle_victory()

func _finish_battle_victory() -> void:
	main.current_run["active_enemy"] = {}
	main.current_run["battle_snapshot"] = {}
	var reward: Dictionary = _apply_battle_victory_rewards()
	if battle_tier == "boss":
		main.current_run["pending_card_reward"] = {}
		main.run_flow.advance_from_current_node()
		return
	main.current_run["pending_card_reward"] = reward
	_save_run()
	_show_card_reward()

func _spawn_floating_text(target: Control, delta: int) -> void:
	if delta == 0 or target == null or not is_instance_valid(target):
		return
	var color := Color(1, 0.2, 0.2) if delta < 0 else Color(0.2, 1, 0.2)
	var lbl := Label.new()
	lbl.text = ("%+d" % delta) if delta > 0 else ("%d" % delta)
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.z_index = 100
	lbl.rotation_degrees = randf_range(-15, 15)
	
	main.modal_layer.add_child(lbl)
	lbl.global_position = target.global_position + target.size / 2 - Vector2(20, 20)
	
	var tween = main.create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 60, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_callback(lbl.queue_free)


func _flash_label(label: Label, delta: int, original_color: Color) -> void:
	var color := Color(1, 0.2, 0.2) if delta < 0 else Color(0.2, 1, 0.2)
	label.add_theme_color_override("font_color", color)
	var tween = main.create_tween()
	tween.tween_property(label, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.3)
	tween.tween_callback(func(): label.add_theme_color_override("font_color", original_color))

func _clear_container(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()

func _configure_field_button(button: Button, unit: Dictionary, index: int, is_player_field: bool) -> void:
	if is_player_field:
		button.disabled = _is_player_input_locked() or not bool(unit.can_attack)
		button.pressed.connect(Callable(self, "_on_player_unit_pressed").bind(index))
		if index == selected_attacker:
			button.text = "선택"
			_style_battle_button(button, Color(0.06, 0.13, 0.18, 0.96), Color(0.34, 0.72, 1.0, 1.0), true)
		elif not button.disabled:
			button.text = "공격"
			_style_battle_button(button, Color(0.04, 0.13, 0.09, 0.96), Color(0.2, 0.82, 0.56, 1.0), true)
		else:
			button.text = "대기"
	else:
		button.disabled = _is_player_input_locked() or selected_attacker == -1
		button.pressed.connect(Callable(self, "_on_opponent_unit_pressed").bind(index))
		if not button.disabled:
			button.text = "대상"
			_style_battle_button(button, Color(0.13, 0.04, 0.045, 0.96), Color(1.0, 0.32, 0.26, 1.0), true)
		else:
			button.text = "적"

func _make_empty_field_slot(compact: bool) -> PanelContainer:
	var tight := _is_tight_battle_layout()
	var portrait := _is_portrait_battle_layout()
	var placeholder := PanelContainer.new()
	placeholder.add_theme_stylebox_override("panel", _make_field_slot_style(Color(0.025, 0.034, 0.045, 0.74), Color(0.18, 0.28, 0.38, 0.72), 1))
	placeholder.custom_minimum_size = Vector2(78, 92) if tight and portrait else (Vector2(104, 112) if tight else (Vector2(124, 132) if not compact else Vector2(104, 116)))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	placeholder.add_child(box)
	var emblem: Label = main._make_label("✦", 18 if tight else (24 if compact else 26), Color(0.62, 0.52, 0.28, 0.46))
	emblem.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(emblem)
	var text: Label = main._make_label("빈 슬롯", 8 if tight else (9 if compact else 10), Color(0.56, 0.53, 0.42, 0.8))
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(text)
	return placeholder

func _build_field_slot(side: Dictionary, index: int, is_player_field: bool) -> Control:
	var compact := _is_compact_layout()
	var tight := _is_tight_battle_layout()
	var portrait := _is_portrait_battle_layout()
	if index >= side.field.size():
		return _make_empty_field_slot(compact)
	var frame_size := Vector2(78, 96) if tight and portrait else (Vector2(108, 118) if tight else (Vector2(124, 132) if not compact else Vector2(108, 116)))
	var content_size := Vector2(frame_size.x - 12.0, frame_size.y - 10.0)
	var art_size := Vector2(60, 30) if tight and portrait else (Vector2(88, 42) if tight else (Vector2(106, 52) if not compact else Vector2(92, 42)))
	var frame := PanelContainer.new()
	frame.custom_minimum_size = frame_size
	var slot := VBoxContainer.new()
	slot.custom_minimum_size = content_size
	slot.add_theme_constant_override("separation", 2)
	frame.add_child(slot)
	var unit: Dictionary = side.field[index]
	var race_border := _card_accent_color(unit)
	var slot_border := race_border
	var slot_bg := Color(0.035, 0.045, 0.058, 0.88)
	if is_player_field and index == selected_attacker:
		slot_border = Color(0.34, 0.72, 1.0, 1.0)
		slot_bg = Color(0.05, 0.1, 0.15, 0.96)
	elif is_player_field and bool(unit.get("can_attack", false)) and not _is_player_input_locked():
		slot_border = Color(0.2, 0.82, 0.56, 1.0)
		slot_bg = Color(0.035, 0.08, 0.065, 0.94)
	elif not is_player_field and selected_attacker != -1 and not _is_player_input_locked():
		slot_border = Color(1.0, 0.32, 0.26, 1.0)
		slot_bg = Color(0.09, 0.035, 0.04, 0.95)
	frame.add_theme_stylebox_override("panel", _make_field_slot_style(slot_bg, slot_border, 2))
	var name_band: PanelContainer = _make_battle_surface(race_border.darkened(0.42), race_border.lightened(0.08), 1, 5, 3)
	slot.add_child(name_band)
	var name_label: Label = main._make_label(String(unit.get("name", "")), 8 if tight and portrait else (10 if tight else (11 if compact else 12)), Color(1.0, 0.96, 0.82, 1.0))
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	name_band.add_child(name_label)
	slot.add_child(main._make_card_art_rect(unit, art_size))
	var type_label: Label = main._make_label("%s / %s" % [String(unit.get("race", "")), String(unit.get("attr", ""))], 7 if tight and portrait else (8 if tight else 9), Color(0.88, 0.9, 0.76, 1.0))
	type_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	type_label.clip_text = true
	slot.add_child(type_label)
	var stat_row := HBoxContainer.new()
	stat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stat_row.add_theme_constant_override("separation", 4)
	slot.add_child(stat_row)
	stat_row.add_child(main.ui.make_stat_badge("%d" % int(unit.get("attack", 0)), Color(0.46, 0.16, 0.12, 1.0), true))
	stat_row.add_child(main.ui.make_stat_badge("%d" % int(unit.get("health", 0)), Color(0.1, 0.24, 0.46, 1.0), true))
	var button := Button.new()
	button.custom_minimum_size = Vector2(58, 19) if tight and portrait else (Vector2(78, 22) if tight else Vector2(86 if not compact else 80, 24))
	_style_battle_button(button, Color(0.06, 0.07, 0.085, 0.92), Color(0.26, 0.34, 0.44, 0.9))
	button.add_theme_font_size_override("font_size", 9 if tight and portrait else (10 if tight else 11))
	_configure_field_button(button, unit, index, is_player_field)
	slot.add_child(button)
	return frame

func _render_field(container: HBoxContainer, side: Dictionary, is_player_field: bool) -> void:
	_clear_container(container)
	if is_player_field:
		player_field_slots.clear()
	else:
		opponent_field_slots.clear()
	for i in range(MAX_FIELD):
		var slot := _build_field_slot(side, i, is_player_field)
		container.add_child(slot)
		if is_player_field:
			player_field_slots.append(slot)
		else:
			opponent_field_slots.append(slot)


func _render_hand() -> void:
	var compact := _is_compact_layout()
	var tight := _is_tight_battle_layout()
	var portrait := _is_portrait_battle_layout()
	_clear_container(hand_box)
	for i in range(player.hand.size()):
		var card: Dictionary = player.hand[i]
		var accent := _card_accent_color(card)
		var cost: int = main.relic_service.modify_card_cost(main.current_run, battle_state, card, "player")
		var playable: bool = not _is_player_input_locked() and _can_play_card(player, card, "player")
		var frame := Button.new()
		frame.text = ""
		frame.focus_mode = Control.FOCUS_NONE
		var frame_size := Vector2(140, 176) if tight and portrait else (Vector2(132, 166) if tight else (Vector2(190, 226) if not compact else Vector2(154, 188)))
		var content_size := Vector2(frame_size.x - 12.0, frame_size.y - 12.0)
		frame.custom_minimum_size = frame_size
		var hand_border := accent.lightened(0.12) if playable else accent.darkened(0.08)
		frame.add_theme_stylebox_override("normal", _make_hand_card_style(Color(0.075, 0.068, 0.052, 1.0), hand_border, 3 if playable else 2))
		frame.add_theme_stylebox_override("hover", _make_hand_card_style(Color(0.095, 0.082, 0.055, 1.0), accent.lightened(0.22), 3))
		frame.add_theme_stylebox_override("pressed", _make_hand_card_style(Color(0.05, 0.045, 0.038, 1.0), accent, 3))
		frame.add_theme_color_override("font_color", Color(1, 1, 1, 0))
		frame.pressed.connect(Callable(self, "_on_hand_card_pressed").bind(i))
		if not playable:
			frame.modulate = Color(0.66, 0.68, 0.72, 0.86)
		var card_box := VBoxContainer.new()
		card_box.custom_minimum_size = content_size
		card_box.add_theme_constant_override("separation", 3 if tight else 5)
		card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(card_box)
		var header_row := HBoxContainer.new()
		header_row.add_theme_constant_override("separation", 4)
		header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_box.add_child(header_row)
		var cost_badge: PanelContainer = main.ui.make_cost_badge("%d" % cost, true)
		cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header_row.add_child(cost_badge)
		var name_band: PanelContainer = main.ui.make_surface_panel(accent.darkened(0.28), accent.lightened(0.12), 1, 5, 3)
		name_band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header_row.add_child(name_band)
		var name_label: Label = main._make_label(String(card.get("name", "")), 12 if tight else (15 if not compact else 12), Color(1.0, 0.96, 0.82, 1.0))
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_band.add_child(name_label)
		var art_size := Vector2(content_size.x - 4.0, 58) if tight else (Vector2(176, 92) if not compact else Vector2(140, 64))
		var art_rect: TextureRect = main._make_card_art_rect(card, art_size)
		art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_box.add_child(art_rect)
		if not tight:
			var status_chip: PanelContainer = main.ui.make_surface_panel(accent.darkened(0.36), accent.lightened(0.06), 1, 5, 2)
			status_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_box.add_child(status_chip)
			var status_label: Label = main._make_label("사용 가능" if playable else _unplayable_card_hint(card, cost), 8, Color(1.0, 0.92, 0.76, 1.0) if playable else Color(0.74, 0.78, 0.84, 1.0))
			status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			status_chip.add_child(status_label)
		var type_line := "%s / %s" % [main.deck_service.type_name(String(card.get("type", ""))), String(card.get("attr", ""))]
		var type_label: Label = main._make_label(type_line, 9 if tight else 10, Color(0.9, 0.86, 0.66, 1.0))
		type_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not tight:
			card_box.add_child(type_label)
		if String(card.get("type", "")) == "unit":
			var card_stat_row := HBoxContainer.new()
			card_stat_row.alignment = BoxContainer.ALIGNMENT_CENTER
			card_stat_row.add_theme_constant_override("separation", 4)
			card_stat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_box.add_child(card_stat_row)
			var attack_badge: PanelContainer = main.ui.make_stat_badge("%d" % int(card.get("attack", 0)), Color(0.46, 0.16, 0.12, 1.0), true)
			attack_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_stat_row.add_child(attack_badge)
			var health_badge: PanelContainer = main.ui.make_stat_badge("%d" % int(card.get("health", 0)), Color(0.1, 0.24, 0.46, 1.0), true)
			health_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_stat_row.add_child(health_badge)
		var effect_label: Label = main._make_label(String(card.get("text", "")), 10 if tight else (12 if not compact else 10), Color(0.82, 0.88, 0.95, 1.0))
		effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect_label.custom_minimum_size = Vector2(0, 30 if tight else (46 if not compact else 32))
		effect_label.clip_text = true
		effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not tight:
			card_box.add_child(effect_label)
		var action_label: Label = main._make_label("즉시 사용" if playable else _unplayable_card_hint(card, cost), 10 if tight else (11 if not compact else 9), Color(0.55, 0.82, 1.0, 1.0) if playable else Color(0.58, 0.62, 0.68, 1.0))
		action_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		action_label.clip_text = true
		action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_box.add_child(action_label)
		hand_box.add_child(frame)


func _render_battle_deck() -> void:
	if deck_count_label == null or not is_instance_valid(deck_count_label) or deck_list_label == null or not is_instance_valid(deck_list_label):
		return
	deck_count_label.text = "덱 %d장" % player.deck.size()
	deck_list_label.text = _compact_deck_summary(player.deck, 5)

func _compact_deck_summary(deck: Array, max_lines: int) -> String:
	var summary := String(main.deck_service.deck_summary_from_cards(deck)).strip_edges()
	if summary.is_empty():
		return "[color=#7D8490]덱이 비었습니다.[/color]"
	var lines := summary.split("\n", false)
	var output: Array[String] = []
	var limit: int = min(lines.size(), max_lines)
	for i in range(limit):
		output.append("[color=#C9D4EA]• %s[/color]" % _escape_rich_text(String(lines[i])))
	if lines.size() > max_lines:
		output.append("[color=#8D96A6]외 %d종[/color]" % (lines.size() - max_lines))
	return "\n".join(output)

func _refresh_timer_label() -> void:
	if turn_timer_label == null or not is_instance_valid(turn_timer_label):
		return
	turn_timer_label.text = _top_resource_text()

func _refresh_status_labels() -> void:
	if status_label != null and is_instance_valid(status_label):
		status_label.text = "현재 목표: 적 영웅 체력을 0으로 만드세요."
	if opponent_info != null and is_instance_valid(opponent_info):
		opponent_info.text = "적 영웅 HP %d/%d" % [int(opponent.get("health", 0)), int(opponent.get("max_health", 0))]
	if opponent_gauge_info != null and is_instance_valid(opponent_gauge_info):
		opponent_gauge_info.text = _format_opponent_victory_gauge()
	if player_info != null and is_instance_valid(player_info):
		player_info.text = "HP %d/%d" % [int(player.get("health", 0)), int(player.get("max_health", 0))]
	if player_gauge_info != null and is_instance_valid(player_gauge_info):
		player_gauge_info.text = main._battle_build_hint_text()
	if battle_guidance_label != null and is_instance_valid(battle_guidance_label):
		battle_guidance_label.text = _current_battle_guidance_text()

func _refresh_action_buttons() -> void:
	if hero_attack_button != null:
		var can_attack_hero: bool = not _is_player_input_locked() and selected_attacker != -1
		hero_attack_button.disabled = not can_attack_hero
		hero_attack_button.text = "영웅 공격 ▶" if can_attack_hero else "영웅 공격"
		if can_attack_hero:
			_style_battle_button(hero_attack_button, Color(0.13, 0.04, 0.045, 0.96), Color(1.0, 0.32, 0.26, 1.0), true)
		else:
			_style_battle_button(hero_attack_button, Color(0.045, 0.06, 0.078, 0.92), Color(0.72, 0.18, 0.16, 1.0), false)
	if end_turn_button != null:
		end_turn_button.disabled = _is_player_input_locked()
		if _player_has_available_action():
			end_turn_button.text = "턴 종료"
			_style_battle_button(end_turn_button, Color(0.08, 0.1, 0.13, 0.92), Color(0.24, 0.34, 0.44, 0.9), false)
		else:
			end_turn_button.text = "턴 종료 ▶"
			_style_battle_button(end_turn_button, Color(0.08, 0.16, 0.24, 0.96), Color(0.22, 0.62, 0.95, 1.0), true)

func _refresh_ui() -> void:
	_refresh_timer_label()
	_refresh_status_labels()
	_refresh_battle_dashboard()
	_refresh_action_buttons()
	if opponent_field_box != null:
		_render_field(opponent_field_box, opponent, false)
	if player_field_box != null:
		_render_field(player_field_box, player, true)
	if hand_box != null:
		_render_hand()
	_render_battle_deck()

func start_battle() -> void:
	main.active_screen = "battle"
	main._clear_screen()
	var enemy: Dictionary = main.current_run.get("active_enemy", {})
	if enemy.is_empty():
		main._show_map()
		return
	var snapshot: Dictionary = main.current_run.get("battle_snapshot", {})
	if not snapshot.is_empty():
		_restore_battle_snapshot(snapshot)
		return
	battle_tier = String(enemy.get("tier", "normal"))
	player = _new_side("플레이어", main.card_db.build_deck_from_ids(main.current_run.get("deck_ids", [])), int(main.current_run.get("hp", 50)), int(main.current_run.get("max_hp", 50)))
	opponent = _new_side(String(enemy.get("name", "적")), main.card_db.build_deck_from_ids(enemy.get("deck_ids", [])), int(enemy.get("base_hp", 20)), int(enemy.get("base_hp", 20)))
	_draw_cards(player, START_HAND)
	_draw_cards(opponent, START_HAND)
	_reset_battle_state()
	_build_battle_ui()
	main.relic_service.on_battle_start(main.current_run, player, battle_state)
	_spawn_build_token()
	player.health = int(main.current_run.get("hp", player.health))
	_add_log("%s 전투 시작. 적 영웅 체력을 0으로 만드세요." % _node_type_name(String(main.run_store.current_node(main.current_run).get("type", "battle"))))
	_refresh_ui()
	_store_battle_snapshot()
	await _show_turn_banner("전투 시작!", true)
	await _start_turn(player, true)


func _add_log(message: String) -> void:
	if log_label == null:
		return
	var current_lines := log_label.text.split("\n", false)
	var output: Array[String] = ["[color=#F2C96B][b]•[/b][/color] %s" % _escape_rich_text(message)]
	var max_lines := 18
	var limit: int = min(current_lines.size(), max_lines - 1)
	for i in range(limit):
		output.append(String(current_lines[i]))
	log_label.text = "\n".join(output)

func _shake_screen(intensity: float, duration: float) -> void:
	if main.root_scroll == null or not is_instance_valid(main.root_scroll):
		return
	var tween = main.create_tween()
	var original_pos = main.root_scroll.position
	for i in range(int(duration * 20)):
		tween.tween_property(main.root_scroll, "position", original_pos + Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), 0.05)
		tween.parallel().tween_property(main.modal_layer, "position", Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), 0.05)
	tween.tween_property(main.root_scroll, "position", original_pos, 0.05)
	tween.parallel().tween_property(main.modal_layer, "position", Vector2.ZERO, 0.05)


func _apply_damage_juice(old_p_hp: int, old_o_hp: int) -> void:
	if int(player.health) < old_p_hp:
		_flash_and_shake(player_info, Color(1.0, 0.2, 0.2, 1.0))
		_flash_and_shake(player_hero_hp_label, Color(1.0, 0.2, 0.2, 1.0))
	if int(opponent.health) < old_o_hp:
		_flash_and_shake(opponent_info, Color(1.0, 0.2, 0.2, 1.0))
		_flash_and_shake(enemy_hero_hp_label, Color(1.0, 0.2, 0.2, 1.0))

func _flash_and_shake(node: Control, color: Color) -> void:
	if not is_instance_valid(node): return
	var tween := node.create_tween()
	var orig_pos := node.position
	var orig_modulate := node.modulate
	node.modulate = color
	tween.tween_property(node, "modulate", orig_modulate, 0.3)
	for i in range(4):
		tween.parallel().tween_property(node, "position", orig_pos + Vector2(randf_range(-8, 8), randf_range(-8, 8)), 0.05)
	tween.tween_property(node, "position", orig_pos, 0.05)
