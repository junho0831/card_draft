extends RefCounted

const MAX_MANA = 10
const MAX_FIELD = 5
const MAX_HAND_VISUAL_SLOTS = 10
const HAND_SLOT_PREFERENCE = [1, 3, 5, 7, 9, 0, 2, 4, 6, 8]
const START_HAND = 5
const STARTING_MAX_MANA = 1
const TURN_TIME_SECONDS = 35.0
const BATTLE_MAX_CONTENT_WIDTH = 1560.0
const BATTLE_STYLES = preload("res://src/ui/styles/battle_styles.gd")
const BATTLE_FX_LAYER = preload("res://src/ui/effects/battle_fx_layer.gd")

var main
var root_box: VBoxContainer
var status_label: Label
var battle_guidance_label: Label
var battle_focus_label: Label
var opponent_info: Label
var opponent_gauge_info: Label
var opponent_field_box: HBoxContainer
var hero_attack_button: Button
var race_power_button: Button
var recommended_action_button: Button
var detail_toggle_button: Button
var detail_panel: PanelContainer
var tutorial_panel: PanelContainer
var opponent_hero_target: Control
var player_hero_target: Control
var opponent_hero_target_badge: PanelContainer
var opponent_hero_target_badge_label: Label
var opponent_hero_target_hp_label: Label
var player_hero_target_hp_label: Label
var player_field_box: HBoxContainer
var player_info: Label
var player_gauge_info: Label
var hand_box: Control
var hand_scroll: ScrollContainer
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
var card_preview_nodes: Array[Node] = []
var player = {}
var opponent = {}
var hover_popup: PanelContainer = null
var last_player_mana: int = 0
var last_player_deck_count: int = 0
var last_player_discard_count: int = 0
var battle_detail_visible = false
var hand_render_signature: String = ""
var last_hand_layout_width: float = 0.0
var player_field_signature: String = ""
var opponent_field_signature: String = ""
var deck_render_signature: String = ""
var battle_fx_layer: Control

func _show_hover_popup(node: Control, title_text: String, description_text: String, accent_color: Color) -> void:
	if _should_skip_timed_battle_fx():
		return
	_hide_hover_popup()

	hover_popup = PanelContainer.new()
	var popup_width: float = 320.0 if not _is_tight_battle_layout() else 280.0
	hover_popup.custom_minimum_size = Vector2(popup_width, 0)
	hover_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style: StyleBoxFlat = _make_modern_style(Color(0.055, 0.065, 0.08, 0.98).lerp(accent_color, 0.08), accent_color.darkened(0.08), 1, 8, 12)
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	hover_popup.add_theme_stylebox_override("panel", style)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_popup.add_child(box)

	var title_label: Label = main._make_label(title_text, 16, accent_color.lightened(0.24))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_constant_override("outline_size", 5)
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	box.add_child(title_label)

	var sep: HSeparator = HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sep)

	var desc_label = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.text = description_text
	desc_label.add_theme_font_size_override("normal_font_size", 13)
	desc_label.add_theme_color_override("default_color", Color(0.92, 0.94, 0.98, 1.0))
	desc_label.add_theme_constant_override("outline_size", 3)
	desc_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	desc_label.fit_content = true
	desc_label.scroll_active = false
	desc_label.custom_minimum_size = Vector2(popup_width - 28.0, 0)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(desc_label)

	main.modal_layer.add_child(hover_popup)

	var global_pos: Vector2 = node.global_position
	var size_y: float = hover_popup.size.y if hover_popup.size.y > 0 else 82.0
	var viewport_size: Vector2 = main.get_viewport_rect().size

	var target_pos = Vector2(
		clamp(global_pos.x + (node.size.x - popup_width) / 2.0, 10.0, viewport_size.x - popup_width - 10.0),
		clamp(global_pos.y - size_y - 12.0, 10.0, viewport_size.y - size_y - 10.0)
	)

	hover_popup.position = target_pos + Vector2(0, 10.0)
	hover_popup.scale = Vector2(0.82, 0.82)
	hover_popup.pivot_offset = Vector2(popup_width / 2.0, size_y)
	hover_popup.modulate.a = 0.0

	var tween: Tween = main.create_tween()
	tween.set_parallel(true)
	tween.tween_property(hover_popup, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(hover_popup, "position", target_pos, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(hover_popup, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_hover_popup() -> void:
	if hover_popup != null and is_instance_valid(hover_popup):
		hover_popup.queue_free()
	hover_popup = null

var current_player = "player"
var selected_attacker = -1
var game_over = false
var battle_finished = false
var input_locked = false
var battle_state = {}
var battle_tier = "normal"

const ENEMY_HERO_ART = 11
const PLAYER_HERO_ART = 8

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
			"combo_tag": String(battle_state.get("combo_tag", "")),
			"combo_streak": int(battle_state.get("combo_streak", 0)),
			"mana_crystal_bonus": bool(battle_state.get("mana_crystal_bonus", false)),
			"first_card_discount_available": bool(battle_state.get("first_card_discount_available", false)),
			"necromancer_ring_used": bool(battle_state.get("necromancer_ring_used", false)),
			"second_chance_used": bool(battle_state.get("second_chance_used", false)),
			"summon_build_started": bool(battle_state.get("summon_build_started", false)),
			"boss_turn_count": int(battle_state.get("boss_turn_count", 0)),
			"race_power_used": bool(battle_state.get("race_power_used", false)),
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
	battle_state["combo_tag"] = String(flags.get("combo_tag", ""))
	battle_state["combo_streak"] = int(flags.get("combo_streak", 0))
	battle_state["mana_crystal_bonus"] = bool(flags.get("mana_crystal_bonus", false))
	battle_state["first_card_discount_available"] = bool(flags.get("first_card_discount_available", false))
	battle_state["necromancer_ring_used"] = bool(flags.get("necromancer_ring_used", false))
	battle_state["second_chance_used"] = bool(flags.get("second_chance_used", false))
	battle_state["summon_build_started"] = bool(flags.get("summon_build_started", false))
	battle_state["boss_turn_count"] = int(flags.get("boss_turn_count", 0))
	battle_state["race_power_used"] = bool(flags.get("race_power_used", false))
	_build_battle_ui()
	if log_label != null:
		log_label.text = String(snapshot.get("log_text", ""))
	var restored_time_left: float = float(snapshot.get("turn_timer_left", 0.0))
	if current_player == "player" and turn_timer != null and restored_time_left > 0.0:
		turn_timer.start(restored_time_left)
	elif turn_timer != null:
		turn_timer.stop()
	_init_status_trackers()
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
	if _should_skip_timed_battle_fx():
		return false
	return bool(main.player_profile.get("settings", {}).get("battle_cutscene", true))

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
	var parts: Array[String] = [main._battle_build_hint_text()]
	var combo_text := _combo_status_text()
	if not combo_text.is_empty():
		parts.append(combo_text)
	parts.append(_format_side_resources(player))
	return " | ".join(parts)

func _recommended_action_state() -> Dictionary:
	if _is_player_input_locked():
		return {
			"kind": "wait",
			"text": "상대 턴 진행 중",
			"guidance": "상대 턴 | %s" % _next_enemy_action_text(),
		}
	if selected_attacker != -1:
		var selected = _selected_player_attacker()
		if selected.is_empty():
			return {
				"kind": "end_turn",
				"text": "턴 넘기기",
				"guidance": "추천 진행 또는 턴 종료를 누르세요.",
			}
		var selected_target = _recommended_attack_target_index(selected)
		if int(opponent.get("health", 0)) <= _predict_hero_attack_damage(selected, player, false):
			return {
				"kind": "hero_attack_selected",
				"text": "%s 영웅 공격" % String(selected.get("name", "유닛")),
				"guidance": "1. 적 영웅 선택  2. 바로 마무리",
			}
		if selected_target != -1:
			return {
				"kind": "unit_attack_selected",
				"text": "%s 유닛 공격" % String(selected.get("name", "유닛")),
				"guidance": "1. 공격 대상 선택  2. 적 유닛 정리 또는 영웅 압박",
				"target_index": selected_target,
			}
		return {
			"kind": "hero_attack_selected",
			"text": "%s 영웅 공격" % String(selected.get("name", "유닛")),
			"guidance": "1. 공격 대상 선택  2. 적 영웅 압박",
		}

	var race_power_state := _recommended_race_power_state()
	if not race_power_state.is_empty():
		return race_power_state

	var ready_attacker_index = _recommended_ready_attacker_index()
	if ready_attacker_index != -1 and ready_attacker_index < player.field.size():
		var ready_attacker: Dictionary = player.field[ready_attacker_index]
		var ready_target = _recommended_attack_target_index(ready_attacker)
		if int(opponent.get("health", 0)) <= _predict_hero_attack_damage(ready_attacker, player, false):
			return {
				"kind": "hero_attack_direct",
				"text": "%s 공격" % String(ready_attacker.get("name", "유닛")),
				"guidance": "1. 공격 가능한 내 유닛으로 적 영웅 압박  2. 바로 마무리",
				"attacker_index": ready_attacker_index,
			}
		if ready_target != -1:
			return {
				"kind": "unit_attack_direct",
				"text": "%s 공격" % String(ready_attacker.get("name", "유닛")),
				"guidance": "1. 공격 가능한 내 유닛으로 전장 정리  2. 유리한 교환부터 진행",
				"attacker_index": ready_attacker_index,
				"target_index": ready_target,
			}
		return {
			"kind": "hero_attack_direct",
			"text": "%s 공격" % String(ready_attacker.get("name", "유닛")),
			"guidance": "1. 공격 가능한 내 유닛으로 적 영웅 압박  2. 전투를 빠르게 끝내세요",
			"attacker_index": ready_attacker_index,
		}

	var recommended_index = _recommended_hand_index()
	if recommended_index != -1 and recommended_index < player.hand.size():
		var recommended_card: Dictionary = player.hand[recommended_index]
		var card_type = String(recommended_card.get("type", ""))
		var card_id = _base_card_id(String(recommended_card.get("id", "")))
		var guidance = "1. 추천 카드 사용  2. 남은 마나로 추가 전개"
		if card_type == "unit":
			guidance = "1. 추천 유닛 소환  2. 다음 공격 준비"
		elif _direct_damage_preview(recommended_card) > 0 and not opponent.field.is_empty():
			guidance = "1. 추천 피해 카드 사용  2. 앞줄 정리 후 공격"
		elif card_id in ["first_aid", "healing_potion", "moonwell", "vampiric_strike"]:
			guidance = "1. 회복 카드 사용  2. 안전해지면 공격"
		return {
			"kind": "play_card",
			"text": "%s 사용" % String(recommended_card.get("name", "카드")),
			"guidance": guidance,
			"card_index": recommended_index,
		}

	return {
		"kind": "end_turn",
		"text": "턴 넘기기",
		"guidance": "할 수 있는 행동이 없으면 턴 종료를 누르세요.",
	}

func _enemy_strategy_text() -> String:
	var enemy_data: Dictionary = main.current_run.get("active_enemy", {})
	var tags: Array = enemy_data.get("ai_tags", [])
	if tags.has("swarm"):
		return "유닛을 많이 깔아 전장을 압박"
	if tags.has("direct_damage") or tags.has("aggressive"):
		return "영웅 체력을 직접 노림"
	if tags.has("defense") or tags.has("field_test"):
		return "큰 유닛으로 전장을 버팀"
	if tags.has("death") or tags.has("revive"):
		return "사망 효과로 추가 피해를 노림"
	if tags.has("self_harm") or tags.has("low_hp"):
		return "체력을 깎고 강한 효과를 사용"
	return "카드 사용과 공격을 준비"

func _boss_pattern_text() -> String:
	var enemy_data: Dictionary = main.current_run.get("active_enemy", {})
	if String(enemy_data.get("tier", "")) != "boss":
		return ""
	match String(enemy_data.get("id", "")):
		"border_guardian":
			return "보스 패턴: 매 적 턴 선봉 공격 +1"
		"undead_king":
			return "보스 패턴: 3턴마다 해골 지원"
		"necro_lord":
			return "보스 패턴: 매 적 턴 저주 +1"
	return "보스 패턴: %s" % _enemy_strategy_text()

func _apply_boss_pattern_on_turn_start() -> void:
	var enemy_data: Dictionary = main.current_run.get("active_enemy", {})
	if String(enemy_data.get("tier", "")) != "boss":
		return
	battle_state["boss_turn_count"] = int(battle_state.get("boss_turn_count", 0)) + 1
	match String(enemy_data.get("id", "")):
		"border_guardian":
			if not opponent.field.is_empty():
				opponent.field[0]["attack"] = int(opponent.field[0].get("attack", 0)) + 1
				_add_log("보스 패턴: 국경 수호자가 선봉 공격력 +1")
				_record_build_trigger("boss", "선봉 강화", _field_slot_for(opponent, 0), Color(1.0, 0.58, 0.24, 1.0), false)
		"undead_king":
			if int(battle_state.get("boss_turn_count", 0)) % 3 == 0 and opponent.field.size() < 3:
				opponent.field.append({
					"id": "bone_soldier",
					"name": "왕의 해골",
					"race": "언데드",
					"attr": "암흑",
					"attack": 1,
					"health": 1,
					"max_health": 1,
					"art": 2,
					"art_id": "bone_soldier",
					"can_attack": false,
				})
				_add_log("보스 패턴: 언데드 왕이 해골 지원 소환")
				_record_build_trigger("boss", "해골 소환", _field_slot_for(opponent, opponent.field.size() - 1), Color(0.76, 0.5, 1.0, 1.0), false)
		"necro_lord":
			player["curses"] = int(player.get("curses", 0)) + 1
			_add_log("보스 패턴: 강령술사 군주가 저주 +1")
			_record_build_trigger("boss", "저주 +1", _hero_target_for_player(true), Color(0.76, 0.5, 1.0, 1.0), false)

func _next_enemy_action_text() -> String:
	var ready_attack = 0
	for unit in opponent.field:
		if bool(Dictionary(unit).get("can_attack", false)):
			ready_attack += int(Dictionary(unit).get("attack", 0))
	if ready_attack >= int(player.get("health", 0)):
		return "다음 적 행동: 영웅 공격 위험"
	if ready_attack > 0:
		return "다음 적 행동: 유닛 공격 · %s" % _enemy_strategy_text()
	for card in opponent.hand:
		var enemy_card: Dictionary = card
		if String(enemy_card.get("type", "")) == "unit" and _can_play_card(opponent, enemy_card, "opponent"):
			return "다음 적 행동: 소환 준비 · %s" % _enemy_strategy_text()
	return "다음 적 행동: %s" % _enemy_strategy_text()

func _combo_status_text() -> String:
	var tag := String(battle_state.get("combo_tag", ""))
	var streak := int(battle_state.get("combo_streak", 0))
	if tag.is_empty() or streak <= 0:
		var active_tags: Array = battle_state.get("active_build_tags", []) as Array
		if active_tags.is_empty():
			return ""
		var active_tag := String(active_tags[0])
		var active_meta: Dictionary = main._build_tag_meta().get(active_tag, {})
		return "%s 연계 준비" % String(active_meta.get("name", active_tag))
	var meta: Dictionary = main._build_tag_meta().get(tag, {})
	var next_text := "다음 같은 태그면 발동" if streak == 1 else "연계 발동 중"
	return "%s %d연계 · %s" % [String(meta.get("name", tag)), streak, next_text]

func _strongest_active_build_text() -> String:
	var scores: Dictionary = main._current_build_scores()
	var active: Array[String] = main._active_build_tags(scores)
	if active.is_empty():
		return main._active_build_text(scores)
	var tag := String(active[0])
	return main._build_activation_effect_text(tag)

func _current_battle_guidance_text() -> String:
	if game_over:
		return "전투 종료"
	var guidance := String(_recommended_action_state().get("guidance", "추천 진행 또는 턴 종료를 누르세요."))
	var combo_text := _combo_status_text()
	if not combo_text.is_empty() and current_player == "player" and not input_locked:
		guidance = "%s  |  %s" % [guidance, combo_text]
	return guidance

func _current_battle_focus_text() -> String:
	var boss_pattern := _boss_pattern_text()
	if selected_attacker != -1 and selected_attacker < player.field.size():
		var attacker: Dictionary = player.field[selected_attacker]
		if opponent.field.is_empty():
			return "이번 턴 플랜: %s 누르고 적 영웅 치기 -> 끝" % String(attacker.get("name", "유닛"))
		return "이번 턴 플랜: %s로 앞 적부터 치기 -> 더 할 것 확인" % String(attacker.get("name", "유닛"))
	if _is_player_input_locked():
		return boss_pattern if not boss_pattern.is_empty() else "이번 턴 플랜: 지금은 기다리면 됩니다."
	for unit in player.field:
		if bool(Dictionary(unit).get("can_attack", false)):
			return "이번 턴 플랜: 공격 가능한 내 유닛 먼저 누르기 -> 필요하면 카드 쓰기"
	var recommended_card = _recommended_hand_card()
	if not recommended_card.is_empty():
		var impact: String = main._choice_impact_text(recommended_card)
		return "이번 턴 플랜: %s 먼저 쓰기 -> %s" % [String(recommended_card.get("name", "추천 카드")), impact]
	return "이번 턴 플랜: %s" % _strongest_active_build_text()

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

func _compact_card_hover_text(card: Dictionary, cost: int, playable: bool) -> String:
	var parts: Array[String] = []
	parts.append("비용 %d  |  %s" % [cost, "사용 가능" if playable else _unplayable_card_hint(card, cost)])
	parts.append(_card_result_preview(card))
	var tags: Array = main._card_build_tags(card)
	if not tags.is_empty():
		parts.append("빌드: %s" % main._build_progress_text_for_tags(tags))
	return "\n".join(parts)

func _compact_unit_hover_text(unit: Dictionary, card_def: Dictionary, is_player_field: bool) -> String:
	var status_text := "아군" if is_player_field else "적군"
	if is_player_field:
		status_text = "공격 가능" if bool(unit.get("can_attack", false)) else "행동 완료"
	var parts: Array[String] = [
		"공격 %d  |  체력 %d/%d  |  %s" % [
			int(unit.get("attack", 0)),
			int(unit.get("health", 0)),
			int(unit.get("max_health", unit.get("health", 0))),
			status_text
		]
	]
	var text := String(card_def.get("text", "")).strip_edges()
	if not text.is_empty():
		parts.append(text)
	return "\n".join(parts)

func _make_battle_guidance_panel(compact: bool) -> PanelContainer:
	var panel = _make_battle_surface(Color(0.055, 0.085, 0.14, 0.98), Color(0.34, 0.62, 1.0, 0.95), 1, 8, 10)
	var tight = _is_tight_battle_layout()
	var wide_tight = _is_wide_tight_battle_layout()
	var mobile = _is_mobile_battle_layout()
	panel.custom_minimum_size = Vector2(0, 62 if mobile else (30 if wide_tight else (36 if tight else (52 if compact else 58))))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: BoxContainer = VBoxContainer.new() if mobile else HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 2 if mobile else 10)
	panel.add_child(row)
	var title: Label = main._make_label("추천 행동" if mobile else "지금 할 일", 11 if mobile else (12 if tight else (14 if compact else 16)), Color(0.48, 0.72, 1.0, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.custom_minimum_size = Vector2(0 if mobile else (80 if tight else (96 if compact else 125)), 0)
	row.add_child(title)
	battle_guidance_label = main._make_label("", 15 if mobile else (14 if tight else (18 if compact else 21)), Color(1.0, 0.98, 0.94, 1.0))
	battle_guidance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	battle_guidance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_guidance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if mobile else TextServer.AUTOWRAP_OFF
	row.add_child(battle_guidance_label)
	return panel

func _should_show_battle_tutorial() -> bool:
	return _battle_tutorial_stage() < 3 and not bool(main.player_profile.get("battle_tutorial_seen", false))

func _battle_tutorial_stage() -> int:
	return clampi(int(main.player_profile.get("battle_tutorial_stage", 0)), 0, 3)

func _battle_tutorial_content() -> Dictionary:
	var stage := _battle_tutorial_stage()
	match stage:
		0:
			return {
				"title": "첫 전투: 추천 진행부터 누르세요",
				"compact": "밝은 카드와 큰 추천 버튼만 보고 시작하면 됩니다.",
				"lines": [
					"1. 큰 추천 버튼 누르기  2. 밝은 카드나 공격 가능한 유닛 누르기  3. 더 없으면 턴 종료",
					"초반에는 카드 전체를 다 읽지 않아도 됩니다. 추천 진행과 밝은 카드만 따라가도 충분합니다.",
					"보상 화면에서는 '이 카드 고르면' 줄만 보고 골라도 첫 런에는 충분합니다.",
				],
			}
		1:
			return {
				"title": "두 번째 전투: 공격 순서를 익히세요",
				"compact": "카드 쓴 뒤엔 공격 가능한 유닛을 먼저 보세요.",
				"lines": [
					"카드를 쓴 뒤 공격 가능한 유닛이 생기면, 카드 추가 사용보다 공격을 먼저 처리하는 편이 좋습니다.",
					"영웅을 바로 치기보다 앞 적을 정리하면 다음 턴 피해를 줄일 수 있습니다.",
					"'지금 할 일' 문구와 추천 버튼 텍스트는 같은 다음 행동을 가리킵니다.",
				],
			}
		2:
			return {
				"title": "세 번째 전투: 연계를 터뜨리세요",
				"compact": "같은 빌드 태그 카드를 이어 쓰면 더 세게 터집니다.",
				"lines": [
					"같은 빌드 태그 카드를 한 턴에 연속으로 쓰면 연계가 발동합니다. 예: 화염 카드 -> 또 화염 카드",
					"이번 런에서 자주 뜨는 태그를 따라가면 카드 보상과 전투가 같이 쉬워집니다.",
					"이 전투를 지나면 튜토리얼 패널은 사라지고, 이후에는 추천 진행과 하이라이트만 남습니다.",
				],
			}
		_:
			return {
				"title": "",
				"compact": "",
				"lines": [],
			}

func _dismiss_battle_tutorial() -> void:
	var next_stage: int = min(_battle_tutorial_stage() + 1, 3)
	main.player_profile["battle_tutorial_stage"] = next_stage
	main.player_profile["battle_tutorial_seen"] = next_stage >= 3
	main._save_profile()
	if tutorial_panel != null and is_instance_valid(tutorial_panel):
		tutorial_panel.visible = false

func _make_battle_tutorial_panel(compact: bool) -> PanelContainer:
	var tight = _is_tight_battle_layout()
	var wide_tight = _is_wide_tight_battle_layout()
	var mobile = _is_mobile_battle_layout()
	var tutorial_content := _battle_tutorial_content()
	var panel = _make_battle_surface(Color(0.06, 0.075, 0.1, 0.98), Color(0.42, 0.62, 0.88, 0.82), 1, 10, 7 if mobile or wide_tight else 12)
	panel.visible = _should_show_battle_tutorial() and not wide_tight
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 3 if wide_tight else 6)
	panel.add_child(box)
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	box.add_child(title_row)
	var title_text := "전투 가이드" if mobile else String(tutorial_content.get("title", "전투 가이드"))
	var title: Label = main._make_label(title_text, 11 if tight else (14 if compact else 15), Color(0.92, 0.98, 1.0, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var stage_badge: Label = main._make_label("%d/3" % min(_battle_tutorial_stage() + 1, 3), 10 if tight else 11, Color(0.7, 0.84, 1.0, 1.0))
	stage_badge.custom_minimum_size = Vector2(34, 0)
	stage_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_row.add_child(stage_badge)
	var dismiss = Button.new()
	dismiss.text = "확인"
	dismiss.focus_mode = Control.FOCUS_NONE
	dismiss.custom_minimum_size = Vector2(72 if mobile else (64 if wide_tight else (74 if tight else 88)), 44 if mobile else (24 if wide_tight else (28 if tight else 30)))
	_style_battle_button(dismiss, Color(0.08, 0.12, 0.18, 0.96), Color(0.34, 0.52, 0.76, 1.0), false)
	dismiss.add_theme_font_size_override("font_size", 9 if wide_tight else (10 if tight else 11))
	dismiss.pressed.connect(Callable(self, "_dismiss_battle_tutorial"))
	title_row.add_child(dismiss)
	if mobile or wide_tight:
		var compact_hint: Label = main._make_label(String(tutorial_content.get("compact", "밝은 카드/유닛만 보고, 더 할 게 없으면 턴 종료.")), 12 if mobile else 9, Color(0.84, 0.9, 0.98, 1.0))
		compact_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(compact_hint)
	else:
		var lines: Array = tutorial_content.get("lines", [])
		var line_colors := [
			Color(0.84, 0.9, 0.98, 1.0),
			Color(1.0, 0.88, 0.6, 1.0),
			Color(0.82, 0.92, 0.84, 1.0),
		]
		for idx in range(lines.size()):
			box.add_child(main._make_label(String(lines[idx]), 10 if tight else 12, line_colors[min(idx, line_colors.size() - 1)]))
	return panel

func _is_fast_ai_enabled() -> bool:
	return bool(main.player_profile["settings"]["fast_ai"])

func _should_skip_timed_battle_fx() -> bool:
	return DisplayServer.get_name() == "headless" or bool(main.get_meta("disable_timed_battle_fx", false))

func _is_compact_layout() -> bool:
	return main._is_compact_layout_for(1080.0)

func _is_tight_battle_layout() -> bool:
	var viewport_size: Vector2 = main._layout_viewport_size()
	return viewport_size.x <= 1024.0 or viewport_size.y <= 760.0

func _is_portrait_battle_layout() -> bool:
	var viewport_size: Vector2 = main._layout_viewport_size()
	return viewport_size.y > viewport_size.x

func _is_mobile_battle_layout() -> bool:
	var viewport_size: Vector2 = main._layout_viewport_size()
	return viewport_size.x <= 600.0 and viewport_size.y > viewport_size.x

func _is_wide_tight_battle_layout() -> bool:
	var viewport_size: Vector2 = main._layout_viewport_size()
	return viewport_size.x >= 1100.0 and viewport_size.y <= 760.0

func _make_battle_content_root(tight: bool) -> VBoxContainer:
	var viewport_size: Vector2 = main._layout_viewport_size()
	var mobile := _is_mobile_battle_layout()
	var content_width: float = min(BATTLE_MAX_CONTENT_WIDTH, max(300.0, viewport_size.x - (8.0 if mobile else 20.0)))
	var box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(content_width, 0)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_theme_constant_override("separation", 6 if tight else 10)
	root_box.add_child(box)
	return box

func _add_field_lane(parent: VBoxContainer, lane: HBoxContainer, lane_height: int, mobile: bool) -> void:
	if not mobile:
		parent.add_child(lane)
		return
	var lane_scroll := ScrollContainer.new()
	lane_scroll.custom_minimum_size = Vector2(0, lane_height)
	lane_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lane_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	lane_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lane_scroll.follow_focus = true
	lane_scroll.add_child(lane)
	parent.add_child(lane_scroll)

func _battle_reward_choices() -> Array[String]:
	return main._roll_card_reward_choices(3, false)

func _apply_battle_victory_rewards() -> Dictionary:
	var bonus_relic = {}
	var gold_reward = randi_range(15, 25)
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
		"relic_trigger": Callable(self, "_on_relic_trigger"),
		"relic_service": main.relic_service,
		"run_data": main.current_run,
		"max_health": int(main.current_run.get("max_hp", 50)),
		"player_state": player,
		"first_card_discount_available": false,
		"mana_crystal_bonus": false,
		"cards_played_this_turn": 0,
		"combo_tag": "",
		"combo_streak": 0,
		"build_trigger_count": 0,
		"necromancer_ring_used": false,
		"second_chance_used": false,
		"active_build_tags": main._active_build_tags(main._current_build_scores()),
		"summon_build_started": false,
		"boss_turn_count": 0,
		"race_power_used": false,
	}

func _prepare_battle(tier: String) -> void:
	var enemy: Dictionary = main.enemy_service.pick_enemy(int(main.current_run.get("act", 1)), tier)
	if tier == "normal" and int(main.current_run.get("act", 1)) == 1 and int(main.current_run.get("current_node_index", 0)) == 0:
		var intro_enemy: Dictionary = main.enemy_service.enemy_by_id("goblin_raider")
		if not intro_enemy.is_empty():
			enemy = intro_enemy
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

func _on_relic_trigger(relic_id: String, text: String) -> void:
	battle_state["relic_trigger_count"] = int(battle_state.get("relic_trigger_count", 0)) + 1
	var relic: Dictionary = main.relic_service.get_relic(relic_id)
	var tags: Array[String] = main._relic_build_tags(relic)
	var tag := String(tags[0]) if not tags.is_empty() else ""
	var meta: Dictionary = main._build_tag_meta().get(tag, {})
	var color: Color = meta.get("color", Color(0.82, 0.72, 1.0, 1.0))
	var label := "%s: %s" % [String(relic.get("name", relic_id)), text]
	_add_log("유물 발동: %s" % label)
	var target := _hero_target_for_player(true)
	if tag in ["fire", "death"]:
		target = _hero_target_for_player(false)
	elif tag in ["buff", "summon"] and not player.field.is_empty():
		target = _field_slot_for(player, 0)
	_record_build_trigger(tag if not tag.is_empty() else "relic", label, target, color, false)

func _record_build_trigger(tag: String, text: String, target: Control, color: Color, strong: bool = false) -> void:
	battle_state["build_trigger_count"] = int(battle_state.get("build_trigger_count", 0)) + 1
	var tag_key := "build_trigger_%s" % tag
	battle_state[tag_key] = int(battle_state.get(tag_key, 0)) + 1
	if _should_skip_timed_battle_fx():
		return
	_play_effect_hit_feedback(target, text, color)
	if strong:
		_trigger_hype_moment(target, text, color, "finisher", 14.0, 44, true)

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
	_record_build_trigger("summon", "전열 토큰", _hero_target_for_player(true), Color(0.4, 1.0, 0.62, 1.0), false)

func _apply_build_on_turn_start() -> void:
	if _is_build_active("draw"):
		_draw_cards(player, 1)
		_add_build_log("드로우 빌드 활성, 카드 1장 추가 드로우")
		_record_build_trigger("draw", "추가 드로우", _hero_target_for_player(true), Color(0.42, 0.76, 1.0, 1.0), false)

func _apply_build_on_unit_summoned(owner_state: Dictionary, unit: Dictionary) -> void:
	if owner_state == player and _is_build_active("buff"):
		unit["health"] = int(unit.get("health", 0)) + 1
		unit["max_health"] = int(unit.get("max_health", 0)) + 1
		_add_build_log("버프 빌드 활성, %s 체력 +1" % String(unit.get("name", "유닛")))
		_record_build_trigger("buff", "전열 성장", _hero_target_for_player(true), Color(1.0, 0.82, 0.34, 1.0), false)

func _apply_build_on_ally_died(enemy_state: Dictionary) -> void:
	if _is_build_active("death"):
		enemy_state["health"] = int(enemy_state.get("health", 0)) - 1
		_add_build_log("사망 빌드 활성, 적 영웅 피해 1")
		_record_build_trigger("death", "희생 피해", _hero_target_for_player(false), Color(0.76, 0.5, 1.0, 1.0), false)

func _race_power_button_text() -> String:
	var meta: Dictionary = main._current_race_meta()
	if bool(battle_state.get("race_power_used", false)):
		return "필살기 사용 완료"
	return "필살기 · %s\n%s" % [String(meta.get("power_name", "")), String(meta.get("power_short", "전투당 1회"))]

func _can_use_race_power() -> bool:
	if _is_player_input_locked() or bool(battle_state.get("race_power_used", false)):
		return false
	if main._current_race_id() == "undead" and player.field.is_empty():
		return false
	return true

func _recommended_race_power_state() -> Dictionary:
	if not _can_use_race_power():
		return {}
	var race_id: String = main._current_race_id()
	var should_recommend := false
	match race_id:
		"human":
			should_recommend = player.field.size() >= 2 or (_recommended_hand_index() == -1 and player.field.size() < MAX_FIELD)
		"elf":
			should_recommend = player.hand.size() <= 3 or _recommended_hand_index() == -1
		"undead":
			should_recommend = int(opponent.get("health", 0)) <= 3
			if not should_recommend:
				for unit_variant in player.field:
					if int(Dictionary(unit_variant).get("health", 0)) <= 1:
						should_recommend = true
						break
	if not should_recommend:
		return {}
	var meta: Dictionary = main._current_race_meta()
	return {
		"kind": "race_power",
		"text": "%s 사용" % String(meta.get("power_name", "필살기")),
		"guidance": "1. 세력 필살기 사용  2. 강화된 전장으로 공격",
	}

func _on_race_power_pressed() -> void:
	if not _can_use_race_power():
		return
	input_locked = true
	selected_attacker = -1
	battle_state["race_power_used"] = true
	var old_player_hp := int(player.get("health", 0))
	var old_opponent_hp := int(opponent.get("health", 0))
	match main._current_race_id():
		"elf":
			_resolve_elf_race_power()
		"undead":
			_resolve_undead_race_power()
		_:
			_resolve_human_race_power()
	input_locked = false
	_apply_damage_juice(old_player_hp, old_opponent_hp)
	_refresh_ui()
	_play_race_power_feedback()
	_store_battle_snapshot()
	_check_game_over()
	_check_no_actions_loss()

func _resolve_human_race_power() -> void:
	if player.field.size() < MAX_FIELD:
		_summon_race_token({
			"id": "kingdom_guard_token",
			"name": "왕국 근위대",
			"race": "인간",
			"attr": "대지",
			"attack": 1,
			"health": 2,
			"max_health": 2,
			"art": 7,
			"art_id": "knight_spearman",
			"can_attack": true,
		})
	for unit_variant in player.field:
		var unit: Dictionary = unit_variant
		unit["attack"] = int(unit.get("attack", 0)) + 1
	_add_log("세력 필살기: 왕국의 집결 - 근위대 소환 / 모든 아군 공격력 +1")

func _resolve_elf_race_power() -> void:
	_draw_cards(player, 2)
	player["mana"] = int(player.get("mana", 0)) + 2
	_add_log("세력 필살기: 바람의 순환 - 카드 2장 드로우 / 마나 +2")

func _resolve_undead_race_power() -> void:
	var sacrifice_index := 0
	var lowest_health := 999999
	for i in range(player.field.size()):
		var health := int(player.field[i].get("health", 0))
		if health < lowest_health:
			lowest_health = health
			sacrifice_index = i
	var sacrifice_name := String(player.field[sacrifice_index].get("name", "아군"))
	player.field[sacrifice_index]["health"] = 0
	_cleanup_dead_units(player, opponent)
	opponent["health"] = int(opponent.get("health", 0)) - 3
	if player.field.size() < MAX_FIELD:
		_summon_race_token({
			"id": "grave_skeleton_token",
			"name": "계약의 해골",
			"race": "언데드",
			"attr": "암흑",
			"attack": 1,
			"health": 1,
			"max_health": 1,
			"art": 2,
			"art_id": "bone_soldier",
			"can_attack": true,
		})
	_add_log("세력 필살기: 죽음의 계약 - %s 희생 / 적 영웅 피해 3" % sacrifice_name)

func _summon_race_token(token: Dictionary) -> void:
	if player.field.size() >= MAX_FIELD:
		return
	main.relic_service.on_unit_summoned(main.current_run, token, _battle_effect_context())
	player.field.append(token)
	_apply_build_on_unit_summoned(player, token)

func _play_race_power_feedback() -> void:
	var meta: Dictionary = main._current_race_meta()
	var color: Color = meta.get("color", Color(0.42, 0.68, 1.0, 1.0))
	_play_sfx(String(meta.get("power_sfx", "combo")))
	if _should_skip_timed_battle_fx():
		return
	var target := _hero_target_for_player(true)
	if main._current_race_id() == "undead":
		target = _hero_target_for_player(false)
	elif main._current_race_id() == "human" and not player.field.is_empty():
		target = _field_slot_for(player, player.field.size() - 1)
	if _is_battle_cutscene_enabled():
		_trigger_hype_moment(target, String(meta.get("power_name", "필살기")), color, "", 14.0, 48, true)
	else:
		_play_effect_hit_feedback(target, String(meta.get("power_name", "필살기")), color)

func _combo_candidate_tags(card: Dictionary) -> Array[String]:
	var active_tags: Array[String] = []
	for tag in main._card_build_tags(card):
		if _is_build_active(tag):
			active_tags.append(String(tag))
	return active_tags

func _resolve_card_combo(card: Dictionary) -> void:
	var combo_tags: Array[String] = _combo_candidate_tags(card)
	if combo_tags.is_empty():
		battle_state["combo_tag"] = ""
		battle_state["combo_streak"] = 0
		return
	var current_tag = String(battle_state.get("combo_tag", ""))
	var next_tag = String(combo_tags[0])
	var next_streak = 1
	if not current_tag.is_empty() and combo_tags.has(current_tag):
		next_tag = current_tag
		next_streak = int(battle_state.get("combo_streak", 0)) + 1
	battle_state["combo_tag"] = next_tag
	battle_state["combo_streak"] = next_streak
	if next_streak < 2:
		return
	_trigger_combo_bonus(next_tag, next_streak)

func _trigger_combo_bonus(tag: String, streak: int) -> void:
	var meta: Dictionary = main._build_tag_meta().get(tag, {})
	var combo_name = "%s %s 연계 %d" % [String(meta.get("icon", "")), String(meta.get("name", "")), streak]
	var combo_color := Color(1.0, 0.86, 0.34, 1.0)
	match tag:
		"fire":
			var burst_damage: int = 2 + int(streak / 3)
			if opponent.field.is_empty():
				opponent["health"] = int(opponent.get("health", 0)) - burst_damage
				_play_effect_hit_feedback(_hero_target_for_player(false), "폭발 %d" % burst_damage, Color(1.0, 0.46, 0.24, 1.0))
				combo_color = Color(1.0, 0.46, 0.24, 1.0)
			else:
				opponent.field[0]["health"] = int(opponent.field[0].get("health", 0)) - burst_damage
				_play_effect_hit_feedback(_field_slot_for(opponent, 0), "폭발 %d" % burst_damage, Color(1.0, 0.46, 0.24, 1.0))
				combo_color = Color(1.0, 0.46, 0.24, 1.0)
				_cleanup_dead_units(player, opponent)
			_add_log("연계 발동: 화염 카드 연속 사용으로 폭발 피해 %d" % burst_damage)
		"draw":
			_draw_cards(player, 1)
			player["mana"] = int(player.get("mana", 0)) + 1 if streak >= 3 else int(player.get("mana", 0))
			_add_log("연계 발동: 드로우 카드 연속 사용으로 카드 1장 추가%s" % (" / 마나 +1" if streak >= 3 else ""))
			_play_effect_hit_feedback(_hero_target_for_player(true), combo_name, Color(0.42, 0.76, 1.0, 1.0))
			combo_color = Color(0.42, 0.76, 1.0, 1.0)
		"buff":
			if not player.field.is_empty():
				player.field[0]["attack"] = int(player.field[0].get("attack", 0)) + 1
				player.field[0]["health"] = int(player.field[0].get("health", 0)) + (1 if streak >= 3 else 0)
				player.field[0]["max_health"] = int(player.field[0].get("max_health", 0)) + (1 if streak >= 3 else 0)
				_add_log("연계 발동: 버프 카드 연속 사용으로 선봉 성장")
				_play_slot_pop_feedback(_field_slot_for(player, 0), "성장", Color(1.0, 0.82, 0.34, 1.0))
				combo_color = Color(1.0, 0.82, 0.34, 1.0)
		"death":
			var death_damage: int = 1 + (1 if streak >= 3 else 0)
			opponent["health"] = int(opponent.get("health", 0)) - death_damage
			_add_log("연계 발동: 사망 카드 연속 사용으로 적 영웅 피해 %d" % death_damage)
			_play_effect_hit_feedback(_hero_target_for_player(false), "영혼 피해 %d" % death_damage, Color(0.76, 0.5, 1.0, 1.0))
			combo_color = Color(0.76, 0.5, 1.0, 1.0)
		"summon":
			if not player.field.is_empty():
				var last_index: int = player.field.size() - 1
				player.field[last_index]["can_attack"] = true
				_add_log("연계 발동: 소환 카드 연속 사용으로 마지막 소환 유닛 즉시 공격")
				_play_slot_pop_feedback(_field_slot_for(player, last_index), "즉시 공격", Color(0.4, 1.0, 0.62, 1.0))
				combo_color = Color(0.4, 1.0, 0.62, 1.0)
		"low_hp":
			var recover: int = 1 + (1 if int(player.get("health", 0)) <= int(player.get("max_health", 0)) / 2 else 0)
			player["health"] = min(int(player.get("max_health", 0)), int(player.get("health", 0)) + recover)
			_add_log("연계 발동: 저체력 카드 연속 사용으로 영웅 체력 %d 회복" % recover)
			_play_effect_hit_feedback(_hero_target_for_player(true), "위험 반격", Color(0.42, 1.0, 0.62, 1.0))
			combo_color = Color(0.42, 1.0, 0.62, 1.0)
	var focus_target := _hero_target_for_player(true)
	if tag in ["fire", "death"]:
		focus_target = _hero_target_for_player(false)
	elif tag == "buff" and not player.field.is_empty():
		focus_target = _field_slot_for(player, 0)
	elif tag == "summon" and not player.field.is_empty():
		focus_target = _field_slot_for(player, player.field.size() - 1)
	_record_build_trigger(tag, combo_name, focus_target, combo_color, false)
	_trigger_hype_moment(focus_target, combo_name, combo_color, "combo", 10.0 + float(streak - 2) * 2.0, 34 + min(10, streak * 2), streak >= 3)

func _build_damage_bonus(source: Dictionary, is_spell: bool, owner_state: Dictionary) -> int:
	var bonus = 0
	if _is_build_active("fire") and String(source.get("attr", "")) == "화염":
		bonus += 2
	if _is_build_active("low_hp") and not is_spell and owner_state == player and int(player.get("health", 0)) <= int(player.get("max_health", 0)) / 2:
		bonus += 1
	return bonus

func _top_resource_text() -> String:
	return "💧 %d/%d%s" % [
		int(player.get("mana", 0)),
		int(player.get("max_mana", 0)),
		("   ⏱ %d" % int(ceili(turn_timer.time_left))) if current_player == "player" and turn_timer != null and not turn_timer.is_stopped() else "",
	]

func _make_top_status_bar(compact: bool) -> PanelContainer:
	var panel = _make_battle_surface(Color(0.018, 0.026, 0.036, 0.92), Color(0.12, 0.22, 0.34, 0.8), 1, 10, 9)
	var tight = _is_tight_battle_layout()
	var mobile = _is_mobile_battle_layout()
	panel.custom_minimum_size = Vector2(0, 48 if mobile else (34 if tight else (50 if compact else 54)))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8 if tight else 12)
	panel.add_child(row)

	status_label = main._make_label("", 12 if tight else (14 if compact else 16), Color(0.9, 0.94, 1.0, 1.0))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label.clip_text = mobile
	row.add_child(status_label)

	turn_timer_label = main._make_label("", 11 if tight else (12 if compact else 13), Color(0.86, 0.92, 0.98, 1.0))
	turn_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	turn_timer_label.custom_minimum_size = Vector2(74 if mobile else (118 if tight else (132 if compact else 170)), 0)
	row.add_child(turn_timer_label)

	var actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 6 if tight else 8)
	row.add_child(actions)
	actions.add_child(_make_exit_button("메뉴", "_show_main_menu", Color(0.08, 0.12, 0.18, 0.96), tight, compact, mobile))
	if not mobile:
		actions.add_child(_make_exit_button("포기", "_abandon_run", Color(0.28, 0.1, 0.1, 0.96), tight, compact))
		if not OS.has_feature("web"):
			actions.add_child(_make_exit_button("종료", "_quit_game", Color(0.14, 0.14, 0.14, 0.96), tight, compact))
	return panel

func _make_exit_button(text: String, callback_method: String, color: Color, tight: bool, compact: bool, mobile: bool = false) -> Button:
	var button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(54 if mobile else (44 if tight else (54 if compact else 62)), 44 if mobile else (24 if tight else 28))
	_style_battle_button(button, color, Color(0.34, 0.42, 0.52, 0.9), false)
	button.add_theme_font_size_override("font_size", 10 if tight else 11)
	button.pressed.connect(Callable(main, callback_method))
	return button

func _make_battle_hero_art(hero_art: int, size: Vector2, enemy_side: bool) -> TextureRect:
	if enemy_side:
		return main._make_art_rect(hero_art, size)
	var race_meta: Dictionary = main._current_race_meta()
	var representative_card: Dictionary = main.card_db.get_card(String(race_meta.get("representative_card_id", "")))
	return main._make_card_art_rect(representative_card, size)

func _make_side_info_card(title_text: String, side: Dictionary, hero_art: int, compact: bool, enemy_side: bool) -> PanelContainer:
	var tight = _is_tight_battle_layout()
	var panel = _make_battle_surface(Color(0.035, 0.048, 0.062, 0.86), Color(0.24, 0.38, 0.52, 0.7), 1, 10, 10)
	panel.custom_minimum_size = Vector2(0, 92 if tight else (112 if compact else 124))
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5 if tight else 7)
	panel.add_child(box)

	var title: Label = main._make_label(title_text, 12 if tight else (13 if compact else 14), Color(0.74, 0.86, 1.0, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	row.add_child(_make_battle_hero_art(hero_art, Vector2(48, 48) if tight else (Vector2(54, 54) if compact else Vector2(62, 62)), enemy_side))

	var info_box = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 4)
	row.add_child(info_box)

	var hero_name: Label = main._make_label(String(side.get("name", "")), 14 if tight else (15 if compact else 16), Color(0.96, 0.98, 0.93, 1.0))
	hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info_box.add_child(hero_name)

	var hp_text = "❤ %d / %d" % [int(side.get("health", 0)), int(side.get("max_health", 0))]
	var hp_label: Label = main._make_label(hp_text, 13 if tight else (14 if compact else 15), Color(1.0, 0.76, 0.76, 1.0))
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info_box.add_child(hp_label)

	var sub_text = "⚔ %d  |  손패 %d" % [
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
		var chip_row = HBoxContainer.new()
		chip_row.add_theme_constant_override("separation", 6)
		box.add_child(chip_row)
		var hp_chip_data: Dictionary = _make_tight_info_chip("HP %d" % int(side.get("health", 0)), Color(0.24, 0.12, 0.14, 1.0), 58)
		chip_row.add_child(hp_chip_data["panel"])
		var secondary_text = "덱 %d" % (side.get("deck", []) as Array).size() if enemy_side else "손패 %d" % (side.get("hand", []) as Array).size()
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
	var tight = _is_tight_battle_layout()
	var wide_tight = _is_wide_tight_battle_layout()
	var mobile = _is_mobile_battle_layout()
	var bg = Color(0.04, 0.052, 0.072, 0.94)
	var accent = Color(0.72, 0.18, 0.16, 1.0) if enemy_target else Color(0.18, 0.42, 0.72, 1.0)
	var node: Control
	var content_parent: Control
	if enemy_target:
		var button = Button.new()
		button.text = ""
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 54 if mobile else (34 if wide_tight else (42 if tight else (66 if compact else 56))))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(Callable(self, "_attack_opponent_hero"))
		_style_battle_button(button, bg, accent, selected_attacker != -1 and not _is_player_input_locked())
		node = button
		content_parent = button
		hero_attack_button = button
	else:
		var panel = _make_battle_surface(bg, accent, 1, 8, 5 if tight else 8)
		panel.custom_minimum_size = Vector2(0, 52 if mobile else (32 if wide_tight else (40 if tight else (62 if compact else 54))))
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node = panel
		content_parent = panel

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8 if tight else 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_parent.add_child(row)

	var art: TextureRect = _make_battle_hero_art(hero_art, Vector2(36, 36) if mobile else (Vector2(24, 24) if wide_tight else (Vector2(30, 30) if tight else (Vector2(50, 50) if compact else Vector2(42, 42)))), enemy_target)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)

	var name: Label
	var hp: Label
	if tight:
		name = main._make_label(String(side.get("name", "")), 13, Color(0.95, 0.98, 1.0, 1.0))
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.autowrap_mode = TextServer.AUTOWRAP_OFF
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name)
		hp = main._make_label("HP %d / %d" % [int(side.get("health", 0)), int(side.get("max_health", 0))], 12, Color(1.0, 0.62, 0.62, 1.0) if enemy_target else Color(0.72, 0.88, 1.0, 1.0))
		hp.autowrap_mode = TextServer.AUTOWRAP_OFF
		hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(hp)
	else:
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 3)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(info)
		var eyebrow_text = "TARGET" if enemy_target else "PLAYER"
		var eyebrow: Label = main._make_label(eyebrow_text, 10, Color(0.58, 0.72, 0.88, 1.0))
		eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		eyebrow.autowrap_mode = TextServer.AUTOWRAP_OFF
		eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(eyebrow)
		name = main._make_label(String(side.get("name", "")), 17 if compact else 16, Color(0.95, 0.98, 1.0, 1.0))
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name.autowrap_mode = TextServer.AUTOWRAP_OFF
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(name)
		hp = main._make_label("HP %d / %d" % [int(side.get("health", 0)), int(side.get("max_health", 0))], 14 if compact else 13, Color(1.0, 0.62, 0.62, 1.0) if enemy_target else Color(0.72, 0.88, 1.0, 1.0))
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

	var badge_text = "공격 가능" if enemy_target and selected_attacker != -1 else ("영웅 공격" if enemy_target else "내 영웅")
	var badge_accent = accent
	if enemy_target and selected_attacker != -1 and not _is_player_input_locked():
		var attacker = _selected_player_attacker()
		var damage = _predict_hero_attack_damage(attacker, player, false)
		badge_text = "영웅 피해 %d" % damage
		badge_accent = Color(1.0, 0.32, 0.26, 1.0)
	var badge = _make_battle_badge(badge_text, Color(0.08, 0.1, 0.13, 0.92), badge_accent, 9 if tight else 10)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)
	if enemy_target:
		opponent_hero_target_badge = badge
		opponent_hero_target_badge_label = badge.get_meta("text_label") as Label
	return node

func _make_board_lane_header(title_text: String, subtitle_text: String, compact: bool, enemy_lane: bool) -> PanelContainer:
	var tight = _is_tight_battle_layout()
	var panel = _make_battle_surface(Color(0.025, 0.034, 0.045, 0.74), Color(0.58, 0.18, 0.16, 0.9) if enemy_lane else Color(0.18, 0.42, 0.7, 0.9), 1, 8, 8)
	panel.custom_minimum_size = Vector2(0, 22 if tight else (30 if compact else 28))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var icon_label: Label = main._make_label("▲" if enemy_lane else "▼", 9 if tight else 11, Color(0.62, 0.72, 0.86, 1.0))
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

func _make_collision_line(compact: bool) -> PanelContainer:
	var tight = _is_tight_battle_layout()
	var panel = _make_battle_surface(Color(0.08, 0.045, 0.035, 0.9), Color(0.92, 0.36, 0.2, 0.95), 1, 8, 4 if tight else 5)
	panel.custom_minimum_size = Vector2(0, 14 if tight else (22 if compact else 24))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var left_line = ColorRect.new()
	left_line.color = Color(1.0, 0.46, 0.18, 0.72)
	left_line.custom_minimum_size = Vector2(0, 2)
	left_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left_line)
	var label: Label = main._make_label("VS", 9 if tight else 10, Color(0.82, 0.86, 0.94, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	var right_line = ColorRect.new()
	right_line.color = Color(0.34, 0.72, 1.0, 0.62)
	right_line.custom_minimum_size = Vector2(0, 2)
	right_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right_line)
	return panel

func _make_meta_box(title_text: String, compact: bool) -> VBoxContainer:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10 if compact else 12)
	var title: Label = main._make_label(title_text, 16 if compact else 18, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	return box

func _make_section_panel(title_text: String, compact: bool, min_height: int = 0) -> Dictionary:
	var panel = _make_battle_surface(Color(0.035, 0.048, 0.062, 0.86), Color(0.18, 0.3, 0.42, 0.7), 1, 10, 12)
	if min_height > 0:
		panel.custom_minimum_size = Vector2(0, min_height)
	var tight = _is_tight_battle_layout()
	var box = VBoxContainer.new()
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
	var tight = _is_tight_battle_layout()
	var panel = _make_battle_surface(Color(0.03, 0.04, 0.052, 0.88), accent_color, 1, 10, 8)
	panel.custom_minimum_size = Vector2(0, min_height)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4 if tight else (6 if compact else 8))
	panel.add_child(box)

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	box.add_child(header)

	var marker = ColorRect.new()
	marker.color = accent_color
	marker.custom_minimum_size = Vector2(3, 14 if tight else 18)
	header.add_child(marker)

	var title: Label = main._make_label(title_text, 12 if tight else (13 if compact else 14), Color(0.78, 0.9, 1.0, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var divider = ColorRect.new()
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
	var tight = _is_tight_battle_layout()

	var count_row = HBoxContainer.new()
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

	var deck_scroll = ScrollContainer.new()
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
	var tight = _is_tight_battle_layout()
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
	var tight = _is_tight_battle_layout()
	var wide_tight = _is_wide_tight_battle_layout()
	var portrait = _is_portrait_battle_layout()
	var mobile = _is_mobile_battle_layout()
	var vertical_stack = compact and not wide_tight
	var phone_stack = tight and portrait and vertical_stack
	var panel = _make_battle_surface(Color(0.035, 0.045, 0.058, 0.92), Color(0.18, 0.32, 0.46, 0.7), 1, 10, 4 if phone_stack else (6 if wide_tight else 10))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: BoxContainer = HBoxContainer.new() if wide_tight else VBoxContainer.new()
	box.add_theme_constant_override("separation", 4 if phone_stack else (6 if tight else 8))
	panel.add_child(box)
	if not wide_tight and not phone_stack:
		var title: Label = main._make_label("추천 진행", 12 if tight else (14 if compact else 15), Color(0.82, 0.9, 1.0, 1.0))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(title)
	if tight and not wide_tight and not phone_stack:
		var sub: Label = main._make_label("이 버튼부터 누르고, 필요하면 카드/유닛을 직접 고르세요.", 10, Color(0.66, 0.72, 0.8, 1.0))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(sub)
	if not wide_tight and not phone_stack:
		var action_hint_chip: PanelContainer = _make_battle_badge("추천 진행 -> 필요시 직접 선택 -> 턴 종료", Color(0.08, 0.1, 0.13, 0.92), Color(0.25, 0.48, 0.72, 1.0), 10 if tight else 11)
		box.add_child(action_hint_chip)

	var race_meta: Dictionary = main._current_race_meta()
	var race_color: Color = race_meta.get("color", Color(0.42, 0.68, 1.0, 1.0))
	race_power_button = Button.new()
	race_power_button.text = _race_power_button_text()
	race_power_button.tooltip_text = "전투당 1회 · %s" % String(race_meta.get("power_text", ""))
	race_power_button.custom_minimum_size = Vector2(0 if phone_stack else (300 if vertical_stack else 0), 52 if mobile else (42 if phone_stack else (46 if wide_tight else (50 if tight else (54 if compact else 60)))))
	race_power_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vertical_stack:
		race_power_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_stack else Control.SIZE_SHRINK_CENTER
	_style_battle_button(race_power_button, race_color.darkened(0.56), race_color, true)
	race_power_button.add_theme_font_size_override("font_size", 12 if mobile else (11 if tight else 14))
	race_power_button.pressed.connect(Callable(self, "_on_race_power_pressed"))
	box.add_child(race_power_button)

	recommended_action_button = Button.new()
	recommended_action_button.text = "추천 행동"
	recommended_action_button.custom_minimum_size = Vector2(0 if phone_stack else (320 if vertical_stack else 0), 52 if mobile else (42 if phone_stack else (46 if wide_tight else (52 if tight else (56 if compact else 64)))))
	recommended_action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vertical_stack:
		recommended_action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_stack else Control.SIZE_SHRINK_CENTER
	_style_battle_button(recommended_action_button, Color(0.07, 0.16, 0.32, 0.98), Color(0.42, 0.68, 1.0, 1.0), true)
	recommended_action_button.add_theme_font_size_override("font_size", 14 if mobile else (12 if phone_stack else (13 if tight else 18)))
	recommended_action_button.pressed.connect(Callable(self, "_on_recommended_action_pressed"))
	box.add_child(recommended_action_button)

	end_turn_button = Button.new()
	end_turn_button.text = "턴 넘기기"
	end_turn_button.custom_minimum_size = Vector2(0 if phone_stack else (320 if vertical_stack else 0), 48 if mobile else (34 if phone_stack else (38 if wide_tight else (42 if tight else (44 if compact else 48)))))
	end_turn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vertical_stack:
		end_turn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone_stack else Control.SIZE_SHRINK_CENTER
	_style_battle_button(end_turn_button, Color(0.08, 0.1, 0.13, 0.92), Color(0.24, 0.34, 0.44, 0.9), false)
	end_turn_button.add_theme_font_size_override("font_size", 13 if mobile else (11 if tight else 14))
	end_turn_button.pressed.connect(Callable(self, "_on_end_turn_pressed"))
	box.add_child(end_turn_button)

	return panel

func _make_detail_toggle_row(compact: bool) -> HBoxContainer:
	var tight = _is_tight_battle_layout()
	var portrait = _is_portrait_battle_layout()
	var phone_row = tight and portrait
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6 if phone_row else 8)
	if not phone_row:
		var title: Label = main._make_label("상세 보기", 11 if tight else (12 if compact else 13), Color(0.76, 0.82, 0.9, 1.0))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
	else:
		row.alignment = BoxContainer.ALIGNMENT_END
	detail_toggle_button = Button.new()
	detail_toggle_button.text = "상세 정보"
	detail_toggle_button.custom_minimum_size = Vector2(108 if phone_row else (124 if tight else 144), 28 if phone_row else (30 if tight else 34))
	_style_battle_button(detail_toggle_button, Color(0.07, 0.09, 0.12, 0.92), Color(0.24, 0.34, 0.44, 0.9), false)
	detail_toggle_button.add_theme_font_size_override("font_size", 9 if phone_row else (10 if tight else 12))
	detail_toggle_button.pressed.connect(Callable(self, "_toggle_battle_details"))
	row.add_child(detail_toggle_button)
	return row

func _make_battle_detail_panel(compact: bool) -> PanelContainer:
	var tight = _is_tight_battle_layout()
	var panel = _make_battle_surface(Color(0.028, 0.038, 0.05, 0.96), Color(0.18, 0.32, 0.46, 0.7), 1, 10, 10)
	panel.visible = battle_detail_visible
	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8 if tight else 10)
	panel.add_child(outer)

	var top_row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	outer.add_child(top_row)

	var meta_panel = _make_battle_surface(Color(0.045, 0.055, 0.07, 0.94), Color(0.22, 0.3, 0.4, 0.7), 1, 8, 8)
	meta_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(meta_panel)
	var meta_box = VBoxContainer.new()
	meta_box.add_theme_constant_override("separation", 6)
	meta_panel.add_child(meta_box)
	var meta_title: Label = main._make_label("전투 메모", 11 if tight else (12 if compact else 13), Color(1.0, 0.88, 0.55, 1.0))
	meta_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	meta_box.add_child(meta_title)
	enemy_hand_count_label = main._make_label("", 10 if tight else 12, Color(0.84, 0.88, 0.94, 1.0))
	enemy_hand_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	meta_box.add_child(enemy_hand_count_label)
	enemy_deck_count_label = main._make_label("", 10 if tight else 12, Color(0.84, 0.88, 0.94, 1.0))
	enemy_deck_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	meta_box.add_child(enemy_deck_count_label)
	var deck_chip_data: Dictionary = _make_tight_info_chip("덱 0 | 버림 0", Color(0.1, 0.12, 0.2, 1.0), 124) if tight else _make_status_chip("덱 0 | 버림 0", Color(0.1, 0.12, 0.2, 1.0), 12 if compact else 13)
	player_deck_status_label = deck_chip_data["label"]
	meta_box.add_child(deck_chip_data["panel"])

	var build_panel = _make_battle_surface(Color(0.045, 0.055, 0.07, 0.94), Color(0.22, 0.3, 0.4, 0.7), 1, 8, 8)
	build_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(build_panel)
	var build_box = VBoxContainer.new()
	build_box.add_theme_constant_override("separation", 6)
	build_panel.add_child(build_box)
	var build_title: Label = main._make_label("빌드 시너지", 11 if tight else (12 if compact else 13), Color(1.0, 0.88, 0.55, 1.0))
	build_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	build_box.add_child(build_title)
	var chips_wrap: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	chips_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips_wrap.add_theme_constant_override("separation", 4 if tight else 8)
	build_box.add_child(chips_wrap)
	build_chip_box = chips_wrap

	var bottom_row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8 if tight else 10)
	outer.add_child(bottom_row)
	var deck_panel: Dictionary = _make_deck_preview_panel(compact, 110 if tight else 132)
	deck_panel["panel"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(deck_panel["panel"])
	var log_panel: Dictionary = _make_battle_log_panel(compact, 110 if tight else 132)
	log_panel["panel"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(log_panel["panel"])
	return panel

func _toggle_battle_details() -> void:
	battle_detail_visible = not battle_detail_visible
	if detail_panel != null and is_instance_valid(detail_panel):
		detail_panel.visible = battle_detail_visible
	if detail_toggle_button != null and is_instance_valid(detail_toggle_button):
		detail_toggle_button.text = "상세 닫기" if battle_detail_visible else "상세 정보"

func _on_surrender_pressed() -> void:
	if _is_player_input_locked():
		return
	_add_log("전투에서 도망쳤습니다. (패배)")
	_finish_player_defeat()

func _recommended_ready_attacker_index() -> int:
	var best_index = -1
	var best_attack = -1
	for i in range(player.field.size()):
		var unit: Dictionary = player.field[i]
		if not bool(unit.get("can_attack", false)):
			continue
		var attack = int(unit.get("attack", 0))
		if attack > best_attack:
			best_attack = attack
			best_index = i
	return best_index

func _recommended_attack_target_index(attacker: Dictionary) -> int:
	var best_lethal_index = -1
	var best_lethal_attack = -1
	var best_fallback_index = -1
	var best_fallback_health = 999999
	for i in range(opponent.field.size()):
		var enemy_unit: Dictionary = opponent.field[i]
		var prediction = _predict_unit_attack(attacker, enemy_unit, player, opponent)
		if bool(prediction.get("lethal", false)):
			var threat = int(enemy_unit.get("attack", 0))
			if threat > best_lethal_attack:
				best_lethal_attack = threat
				best_lethal_index = i
		var hp = int(enemy_unit.get("health", 0))
		if hp < best_fallback_health:
			best_fallback_health = hp
			best_fallback_index = i
	if best_lethal_index != -1:
		return best_lethal_index
	return best_fallback_index

func _recommended_action_text() -> String:
	return String(_recommended_action_state().get("text", "턴 넘기기"))

func _on_recommended_action_pressed() -> void:
	if _is_player_input_locked():
		return
	var state = _recommended_action_state()
	match String(state.get("kind", "")):
		"hero_attack_selected":
			await _execute_player_hero_attack(selected_attacker)
			selected_attacker = -1
			_check_game_over()
			_refresh_ui()
			_store_battle_snapshot()
			_check_no_actions_loss()
		"unit_attack_selected":
			await _execute_player_unit_attack(selected_attacker, int(state.get("target_index", -1)))
			selected_attacker = -1
			_check_game_over()
			_refresh_ui()
			_store_battle_snapshot()
			_check_no_actions_loss()
		"hero_attack_direct":
			await _execute_player_hero_attack(int(state.get("attacker_index", -1)))
			_check_game_over()
			_refresh_ui()
			_store_battle_snapshot()
			_check_no_actions_loss()
		"unit_attack_direct":
			await _execute_player_unit_attack(int(state.get("attacker_index", -1)), int(state.get("target_index", -1)))
			_check_game_over()
			_refresh_ui()
			_store_battle_snapshot()
			_check_no_actions_loss()
		"play_card":
			_on_hand_card_pressed(int(state.get("card_index", -1)))
		"race_power":
			_on_race_power_pressed()
		_:
			_on_end_turn_pressed()

func _initialize_battle_runtime_ui() -> void:
	turn_overlay = Panel.new()
	turn_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	turn_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
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
	var total = 0
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
	var colors = [
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
	return BATTLE_STYLES.make_hand_card_style(bg_color, border_color, border_width)

func _make_modern_style(bg_color: Color, border_color: Color, border_width: int = 1, radius: int = 8, margin: int = 10) -> StyleBoxFlat:
	return BATTLE_STYLES.make_modern_style(bg_color, border_color, border_width, radius, margin)

func _make_battle_surface(bg_color: Color, accent_color: Color, border_width: int = 1, radius: int = 8, margin: int = 10) -> PanelContainer:
	return BATTLE_STYLES.make_battle_surface(bg_color, accent_color, border_width, radius, margin)

func _style_battle_button(button: Button, bg_color: Color, accent_color: Color, active: bool = false) -> void:
	BATTLE_STYLES.apply_battle_button(button, bg_color, accent_color, active)

func _make_battle_badge(text: String, bg_color: Color, accent_color: Color, font_size: int = 11) -> PanelContainer:
	var panel = _make_battle_surface(bg_color, accent_color, 1, 6, 5)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label: Label = main._make_label(text, font_size, Color(0.9, 0.94, 1.0, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel.add_child(label)
	panel.set_meta("text_label", label)
	return panel

func _make_field_slot_style(bg_color: Color, border_color: Color, border_width: int = 2) -> StyleBoxFlat:
	return BATTLE_STYLES.make_field_slot_style(bg_color, border_color, border_width)

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

func _has_playable_hand_card() -> bool:
	for card in player.hand:
		if _can_play_card(player, card, "player"):
			return true
	return false

func _has_ready_attacker() -> bool:
	for unit in player.field:
		if bool(unit.get("can_attack", false)):
			return true
	return false

func _only_end_turn_remains() -> bool:
	return not _is_player_input_locked() and not _has_playable_hand_card() and not _has_ready_attacker()

func _render_build_chips() -> void:
	if build_chip_box == null or not is_instance_valid(build_chip_box):
		return
	_clear_container(build_chip_box)
	var compact = _is_compact_layout()
	var tight = _is_tight_battle_layout()
	var active_tags: Array = battle_state.get("active_build_tags", []) as Array
	var chip_data: Array[Dictionary] = _build_stat_chip_tags()
	for i in range(chip_data.size()):
		var item: Dictionary = chip_data[i]
		var tag = String(item.get("tag", ""))
		var val = int(item.get("value", 0))
		var active: bool = active_tags.has(tag)
		var combo_active := String(battle_state.get("combo_tag", "")) == tag and int(battle_state.get("combo_streak", 0)) > 0
		var base_color: Color = _build_stat_chip_color(i)
		var border_color := Color(1.0, 0.78, 0.34, 1.0) if active else base_color.lightened(0.16)
		if combo_active:
			border_color = Color(1.0, 0.96, 0.62, 1.0)
		var panel: PanelContainer = main.ui.make_surface_panel(base_color.lightened(0.2) if combo_active else (base_color.lightened(0.14) if active else base_color), border_color, 3 if combo_active else (2 if active else 1), 8, 6)
		panel.custom_minimum_size = Vector2(48 if tight else (54 if compact else 62), 38 if tight else (44 if compact else 48))
		var label_text := "%s\n%d" % [String(item.get("label", "")), val]
		if combo_active:
			label_text = "%s\n%d연계" % [String(item.get("label", "")), int(battle_state.get("combo_streak", 0))]
		var label: Label = main._make_label(label_text, 9 if tight else (10 if compact else 11), Color(1.0, 0.96, 0.82, 1.0) if active or combo_active else Color(0.92, 0.94, 0.92, 1.0))
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		panel.add_child(label)
		build_chip_box.add_child(panel)

		# Synergy tag tooltip hover integration
		var meta: Dictionary = main._build_tag_meta().get(tag, {})
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_entered.connect(func():
			if panel == null or not is_instance_valid(panel):
				return
			var title_text = "%s %s 시너지 (%d/%d)" % [meta.get("icon", ""), meta.get("name", ""), val, main._build_threshold()]
			var status_str = ""
			if active:
				status_str = "[color=#5CD65C][b]● 활성화됨[/b][/color] (효과 적용 중)"
			else:
				status_str = "[color=#A0A5B0]○ 비활성화됨[/color] (활성화까지 %d장 부족)" % (main._build_threshold() - val)
			if combo_active:
				status_str += "\n[color=#FFE76A][b]연계 %d[/b][/color] - 같은 태그 카드를 이어 쓰면 추가 효과" % int(battle_state.get("combo_streak", 0))
			var desc_text = "%s\n\n[color=#F2C96B][b]효과:[/b][/color] %s" % [status_str, meta.get("bonus", "")]
			_show_hover_popup(panel, title_text, desc_text, base_color)
		)
		panel.mouse_exited.connect(func():
			_hide_hover_popup()
		)

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
		var current_mana = int(player.get("mana", 0))
		var max_mana = int(player.get("max_mana", 0))
		mana_status_label.text = "마나 %d / %d" % [current_mana, max_mana]
		if current_mana != last_player_mana:
			var delta = current_mana - last_player_mana
			_flash_label(mana_status_label, delta, Color(1.0, 0.98, 0.86, 1.0))
			last_player_mana = current_mana

	if player_deck_status_label != null and is_instance_valid(player_deck_status_label):
		var deck_size = (player.get("deck", []) as Array).size()
		var discard_size = (player.get("discard_pile", []) as Array).size()
		player_deck_status_label.text = "덱 %d | 버림 %d" % [deck_size, discard_size]
		if deck_size != last_player_deck_count or discard_size != last_player_discard_count:
			var delta = (deck_size + discard_size) - (last_player_deck_count + last_player_discard_count)
			_flash_label(player_deck_status_label, delta, Color(0.9, 0.92, 0.94, 1.0))
			last_player_deck_count = deck_size
			last_player_discard_count = discard_size

	if player_field_status_label != null and is_instance_valid(player_field_status_label):
		player_field_status_label.text = "필드 %d / %d" % [player.field.size(), MAX_FIELD]

func _init_status_trackers() -> void:
	last_player_mana = int(player.get("mana", 0))
	last_player_deck_count = (player.get("deck", []) as Array).size()
	last_player_discard_count = (player.get("discard_pile", []) as Array).size()

func _refresh_battle_dashboard() -> void:
	_refresh_side_info_cards()
	_refresh_status_chips()
	_render_build_chips()

func _player_has_available_action() -> bool:
	if _is_player_input_locked():
		return false
	if _can_use_race_power():
		return true
	for card in player.hand:
		if _can_play_card(player, card, "player"):
			return true
	for unit in player.field:
		if bool(Dictionary(unit).get("can_attack", false)):
			return true
	return false

func _build_battle_ui() -> void:
	var compact = _is_compact_layout()
	var tight = _is_tight_battle_layout()
	var wide_tight = _is_wide_tight_battle_layout()
	var portrait = _is_portrait_battle_layout()
	var mobile = _is_mobile_battle_layout()
	battle_fx_layer = BATTLE_FX_LAYER.new()
	main.modal_layer.add_child(battle_fx_layer)
	root_box.add_theme_constant_override("separation", 5 if tight else 8)
	battle_detail_visible = false
	player_info = null
	player_gauge_info = null
	battle_focus_label = null
	hero_attack_button = null
	race_power_button = null
	recommended_action_button = null
	detail_toggle_button = null
	detail_panel = null
	opponent_hero_target = null
	player_hero_target = null
	opponent_hero_target_badge = null
	opponent_hero_target_badge_label = null
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
	hand_render_signature = ""
	last_hand_layout_width = 0.0
	player_field_signature = ""
	opponent_field_signature = ""
	deck_render_signature = ""
	deck_count_label = null
	deck_list_label = null
	log_label = null
	hand_scroll = null
	var field_height = 158 if mobile else (122 if wide_tight else (128 if tight and portrait else (146 if tight else (168 if not compact else 148))))
	var hand_height = 244 if mobile else (160 if wide_tight else (176 if tight and portrait else (154 if tight else (220 if not compact else 214))))
	var battle_root = _make_battle_content_root(tight)

	battle_root.add_child(_make_top_status_bar(compact))
	battle_root.add_child(_make_battle_guidance_panel(compact))
	tutorial_panel = _make_battle_tutorial_panel(compact)
	battle_root.add_child(tutorial_panel)

	var center_column = VBoxContainer.new()
	center_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_column.add_theme_constant_override("separation", 5 if tight else 6)
	battle_root.add_child(center_column)

	var board_panel = _make_battle_surface(Color(0.025, 0.034, 0.045, 0.9), Color(0.16, 0.28, 0.38, 0.78), 1, 12, 6 if tight else 8)
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	center_column.add_child(board_panel)
	var board_box = VBoxContainer.new()
	board_box.add_theme_constant_override("separation", 2 if tight else 4)
	board_panel.add_child(board_box)

	opponent_gauge_info = main._make_label("", 12 if tight else (12 if not compact else 12), Color(0.78, 0.82, 0.9, 1.0))
	opponent_gauge_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	opponent_gauge_info.visible = false
	board_box.add_child(opponent_gauge_info)
	var focus_panel = _make_battle_surface(Color(0.035, 0.05, 0.07, 0.9), Color(0.28, 0.48, 0.7, 0.86), 1, 8, 4 if tight else 6)
	focus_panel.custom_minimum_size = Vector2(0, 18 if wide_tight else (24 if tight else 30))
	board_box.add_child(focus_panel)
	battle_focus_label = main._make_label("", 11 if tight else (12 if compact else 13), Color(0.86, 0.94, 1.0, 1.0))
	battle_focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_focus_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	focus_panel.add_child(battle_focus_label)
	board_box.add_child(_make_hero_target(opponent, ENEMY_HERO_ART, true, compact))
	opponent_info = opponent_hero_target_hp_label
	if not tight:
		board_box.add_child(_make_board_lane_header("적 전장", "유닛 5칸", compact, true))

	opponent_field_box = HBoxContainer.new()
	opponent_field_box.alignment = BoxContainer.ALIGNMENT_CENTER
	opponent_field_box.custom_minimum_size = Vector2(0, field_height)
	opponent_field_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if mobile else Control.SIZE_EXPAND_FILL
	opponent_field_box.add_theme_constant_override("separation", 6 if tight else 8)
	_add_field_lane(board_box, opponent_field_box, field_height, mobile)

	board_box.add_child(_make_collision_line(compact))
	if not tight:
		board_box.add_child(_make_board_lane_header("내 전장", "필드 장악과 영웅 압박", compact, false))

	player_field_box = HBoxContainer.new()
	player_field_box.alignment = BoxContainer.ALIGNMENT_CENTER
	player_field_box.custom_minimum_size = Vector2(0, field_height)
	player_field_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if mobile else Control.SIZE_EXPAND_FILL
	player_field_box.add_theme_constant_override("separation", 6 if tight else 8)
	_add_field_lane(board_box, player_field_box, field_height, mobile)
	board_box.add_child(_make_hero_target(player, PLAYER_HERO_ART, false, compact))
	player_info = player_hero_target_hp_label

	var player_strip: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	player_strip.add_theme_constant_override("separation", 4 if tight else 8)
	board_box.add_child(player_strip)

	if not tight and not compact:
		var player_status_panel = _make_battle_surface(Color(0.035, 0.048, 0.062, 0.86), Color(0.18, 0.42, 0.7, 0.82), 1, 8, 6)
		player_status_panel.custom_minimum_size = Vector2(160, 40)
		player_strip.add_child(player_status_panel)
		player_info = main._make_label("HP %d/%d" % [int(player.get("health", 0)), int(player.get("max_health", 0))], 14, Color(0.78, 0.9, 1.0, 1.0))
		player_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		player_status_panel.add_child(player_info)
	elif not tight:
		var player_status_panel = _make_side_info_card("플레이어", player, PLAYER_HERO_ART, compact, false)
		player_status_panel.custom_minimum_size = Vector2(0, 92)
		player_strip.add_child(player_status_panel)

	var turn_actions: BoxContainer = HBoxContainer.new() if wide_tight else (VBoxContainer.new() if compact else HBoxContainer.new())
	turn_actions.add_theme_constant_override("separation", 4 if tight else 8)
	player_strip.add_child(turn_actions)

	var mana_chip_data: Dictionary = _make_tight_info_chip("마나 0/0", Color(0.08, 0.18, 0.32, 1.0), 82) if tight else _make_status_chip("마나 0 / 0", Color(0.08, 0.18, 0.32, 1.0), 15 if compact else 16)
	mana_status_label = mana_chip_data["label"]
	var mana_panel: PanelContainer = mana_chip_data["panel"]
	mana_panel.custom_minimum_size = Vector2(82 if tight else (94 if compact else 108), 30 if tight else (48 if compact else 56))
	turn_actions.add_child(mana_chip_data["panel"])

	var bottom_row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	bottom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_theme_constant_override("separation", 8 if tight else 10)
	center_column.add_child(bottom_row)
	var bottom_action_panel = _make_battle_action_panel(compact)
	bottom_action_panel.custom_minimum_size = Vector2(220 if not compact else 0, 0)
	bottom_action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_END
	if compact:
		bottom_row.add_child(bottom_action_panel)

	var hand_panel: PanelContainer = main.ui.make_surface_panel(Color(0.045, 0.055, 0.072, 1.0), Color(0.18, 0.26, 0.36, 1.0), 1, 8, 8)
	hand_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(hand_panel)
	var hand_box_wrap = VBoxContainer.new()
	hand_box_wrap.add_theme_constant_override("separation", 4 if tight else 6)
	hand_panel.add_child(hand_box_wrap)
	var hand_header = HBoxContainer.new()
	hand_header.add_theme_constant_override("separation", 8)
	hand_box_wrap.add_child(hand_header)
	var hand_title: Label = main._make_label("내 손패", 11 if tight else (13 if compact else 15), Color(0.92, 0.95, 1.0, 1.0))
	hand_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hand_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	hand_header.add_child(hand_title)
	var hand_hint_text := "좌우로 밀고 밝은 카드 사용" if mobile else "밝은 카드를 사용하세요"
	var hand_hint: Label = main._make_label(hand_hint_text, 10 if tight else (11 if compact else 12), Color(0.76, 0.82, 0.9, 1.0))
	hand_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hand_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_header.add_child(hand_hint)
	hand_box = Control.new()
	hand_box.custom_minimum_size = Vector2(0, hand_height)
	hand_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if mobile else Control.SIZE_EXPAND_FILL
	hand_box.mouse_filter = Control.MOUSE_FILTER_PASS
	hand_box.resized.connect(Callable(self, "_layout_hand_cards"))
	if mobile:
		hand_scroll = ScrollContainer.new()
		hand_scroll.custom_minimum_size = Vector2(0, hand_height)
		hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		hand_scroll.follow_focus = true
		hand_scroll.add_child(hand_box)
		hand_box_wrap.add_child(hand_scroll)
	else:
		hand_box_wrap.add_child(hand_box)

	if not compact:
		bottom_row.add_child(bottom_action_panel)

	battle_root.add_child(_make_detail_toggle_row(compact))
	detail_panel = _make_battle_detail_panel(compact)
	battle_root.add_child(detail_panel)

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
	_draw_cards(side, max(0, START_HAND - (side.get("hand", []) as Array).size()))
	if is_player_turn:
		battle_state["cards_played_this_turn"] = 0
		battle_state["combo_tag"] = ""
		battle_state["combo_streak"] = 0
		main.relic_service.on_turn_start(main.current_run, battle_state, player)
		_apply_build_on_turn_start()
	else:
		_apply_boss_pattern_on_turn_start()
	_apply_delayed_status(side)
	_check_game_over()
	if game_over:
		return
	_add_log("%s 턴 시작: 마나 %d/%d" % [side.name, side.mana, side.max_mana])
	_store_battle_snapshot()


func _apply_delayed_status(side: Dictionary) -> void:
	var curses = int(side.get("curses", 0))
	if curses > 0:
		side["health"] = int(side.get("health", 0)) - curses
		side["curses"] = 0
		_add_log("%s 저주 발동: 영웅 피해 %d" % [String(side.get("name", "대상")), curses])
	var ritual_stacks = int(side.get("ritual_stacks", 0))
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

	var banner = PanelContainer.new()
	var wide_tight := _is_wide_tight_battle_layout()
	banner.custom_minimum_size = Vector2(190 if wide_tight else 260, 34 if wide_tight else 54)
	var banner_style = StyleBoxFlat.new()
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
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15 if wide_tight else 22)
	var color = Color(0.6, 0.8, 1.0) if is_player else Color(1.0, 0.5, 0.5)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1))
	label.add_theme_constant_override("outline_size", 4)
	banner.add_child(label)

	main.add_child(banner)

	var viewport_size: Vector2 = main._layout_viewport_size()
	var banner_size: Vector2 = banner.custom_minimum_size
	banner.position = Vector2((viewport_size.x - banner_size.x) / 2.0, 72.0 if wide_tight else 126.0)
	banner.pivot_offset = banner_size / 2.0
	banner.scale = Vector2(0.88, 0.88)
	banner.modulate.a = 0.0

	var tween = main.create_tween()
	tween.tween_property(banner, "scale", Vector2(1.0, 1.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(banner, "modulate:a", 1.0, 0.12)
	tween.tween_interval(1.15)
	tween.tween_property(banner, "modulate:a", 0.0, 0.16)
	tween.tween_callback(Callable(self, "_queue_free_if_valid").bind(banner))
	await tween.finished


func _discard_hand(side: Dictionary) -> void:
	if side.hand.size() > 0:
		for card in side.hand:
			side.discard_pile.append(card)
		side.hand.clear()
		_add_log("%s 패 버림" % side.name)


func _first_unused_hand_slot(used_slots: Dictionary, fallback_slot: int = 0) -> int:
	for preferred_slot in HAND_SLOT_PREFERENCE:
		var slot: int = int(preferred_slot)
		if not used_slots.has(slot):
			return slot
	for slot in range(MAX_HAND_VISUAL_SLOTS):
		if not used_slots.has(slot):
			return slot
	return clampi(fallback_slot, 0, MAX_HAND_VISUAL_SLOTS - 1)


func _next_free_hand_slot(hand: Array) -> int:
	var used_slots: Dictionary = {}
	for entry in hand:
		var card: Dictionary = entry
		var slot: int = int(card.get("_hand_slot", -1))
		if slot >= 0 and slot < MAX_HAND_VISUAL_SLOTS and not used_slots.has(slot):
			used_slots[slot] = true
	return _first_unused_hand_slot(used_slots, hand.size())


func _ensure_hand_visual_slots() -> void:
	if player.is_empty() or not player.has("hand"):
		return
	var used_slots: Dictionary = {}
	var pending_indices: Array[int] = []
	for i in range(player.hand.size()):
		var card: Dictionary = player.hand[i]
		var slot: int = int(card.get("_hand_slot", -1))
		if slot < 0 or slot >= MAX_HAND_VISUAL_SLOTS or used_slots.has(slot):
			pending_indices.append(i)
			continue
		used_slots[slot] = true

	for index in pending_indices:
		var card: Dictionary = player.hand[index]
		var slot: int = _first_unused_hand_slot(used_slots, index)
		card["_hand_slot"] = slot
		player.hand[index] = card
		used_slots[slot] = true


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
			var drawn = side.deck.pop_back()
			if side == player:
				drawn["_is_new"] = true
				drawn["_hand_slot"] = _next_free_hand_slot(side.hand)
			side.hand.append(drawn)
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
	var card_type = String(card.get("type", ""))
	var old_field_size: int = player.field.size()
	player.mana -= cost
	player.hand.remove_at(index)
	_play_sfx(_card_play_sfx(card_type))
	_add_log("%s 사용" % String(card.get("name", "카드")))
	if card_type != "unit":
		player.discard_pile.append(card)
	main.relic_service.consume_card_discount(battle_state)
	battle_state["cards_played_this_turn"] = int(battle_state.get("cards_played_this_turn", 0)) + 1
	var old_p_hp = int(player.health)
	var old_o_hp = int(opponent.health)
	main.battle_effects.play_card(player, opponent, card, _battle_effect_context())
	main.relic_service.on_card_played(main.current_run, battle_state, player)
	_resolve_card_combo(card)
	var summoned_index = -1
	if card_type == "unit" and player.field.size() > old_field_size:
		summoned_index = player.field.size() - 1
	var growth: Dictionary = main._build_delta_summary(card)
	if bool(growth.get("will_activate", false)):
		_add_log("핵심 시너지 점화: %s" % String(growth.get("headline", "")))
	_apply_damage_juice(old_p_hp, old_o_hp)
	_check_game_over()
	_refresh_ui()
	_play_card_resolution_feedback(card, card_type, summoned_index, old_p_hp, old_o_hp)
	_store_battle_snapshot()
	_check_no_actions_loss()


func _battle_effect_context() -> Dictionary:
	return {
		"draw_cards": Callable(self, "_draw_cards"),
		"log": Callable(self, "_add_log"),
		"cleanup_dead_units": Callable(self, "_cleanup_dead_units"),
		"calculate_damage": Callable(self, "_calculate_damage"),
		"on_unit_summoned": Callable(self, "_apply_build_on_unit_summoned"),
		"relic_trigger": Callable(self, "_on_relic_trigger"),
		"relic_service": main.relic_service,
		"run_data": main.current_run,
		"max_health": int(main.current_run.get("max_hp", 50)),
		"cards_played_this_turn": int(battle_state.get("cards_played_this_turn", 0)),
	}

func _card_play_sfx(card_type: String) -> String:
	match card_type:
		"unit":
			return "summon"
		"equipment":
			return "combo"
	return "spell"


func _calculate_damage(card_or_unit: Dictionary, is_spell: bool, owner_state: Dictionary, base_damage: int) -> int:
	var damage: int = base_damage + main.relic_service.damage_bonus(main.current_run, card_or_unit, is_spell, owner_state) + _build_damage_bonus(card_or_unit, is_spell, owner_state)
	if owner_state == player and is_spell and String(card_or_unit.get("attr", "")) == "화염":
		var relic_ids: Array = main.current_run.get("relic_ids", [])
		if relic_ids.has("burning_heart") and int(battle_state.get("cards_played_this_turn", 0)) >= 2:
			damage += 1
	return damage

func _play_card_resolution_feedback(card: Dictionary, card_type: String, summoned_index: int, old_player_hp: int, old_opponent_hp: int) -> void:
	if _should_skip_timed_battle_fx():
		return
	var growth: Dictionary = main._build_delta_summary(card)
	if card_type == "unit" and summoned_index >= 0:
		_play_slot_pop_feedback(_field_slot_for(player, summoned_index), "소환", Color(0.34, 0.82, 1.0, 1.0))
		if bool(growth.get("will_activate", false)):
			_play_effect_hit_feedback(_field_slot_for(player, summoned_index), "빌드 활성", Color(0.42, 1.0, 0.62, 1.0))
		return
	if card_type == "equipment":
		_play_slot_pop_feedback(_field_slot_for(player, 0), "강화", Color(1.0, 0.78, 0.24, 1.0))
		if bool(growth.get("will_activate", false)):
			_play_effect_hit_feedback(_field_slot_for(player, 0), "시너지 점화", Color(0.42, 1.0, 0.62, 1.0))
		return
	var opponent_hp_loss = old_opponent_hp - int(opponent.get("health", old_opponent_hp))
	var player_hp_gain = int(player.get("health", old_player_hp)) - old_player_hp
	if opponent_hp_loss > 0:
		var hit_text = "강타 %d" % opponent_hp_loss if opponent_hp_loss >= 4 else "피해 %d" % opponent_hp_loss
		_play_effect_hit_feedback(_hero_target_for_player(false), hit_text, Color(1.0, 0.32, 0.24, 1.0))
		if bool(growth.get("will_activate", false)):
			_play_effect_hit_feedback(_hero_target_for_player(false), "빌드 활성", Color(0.42, 1.0, 0.62, 1.0))
	elif player_hp_gain > 0:
		_play_effect_hit_feedback(_hero_target_for_player(true), "회복 %d" % player_hp_gain, Color(0.34, 1.0, 0.62, 1.0))
	elif _is_build_active("low_hp") and int(player.get("health", 0)) <= int(player.get("max_health", 0)) / 2:
		_play_effect_hit_feedback(_hero_target_for_player(true), "위험 반격 활성", Color(1.0, 0.36, 0.38, 1.0))
	elif not opponent.field.is_empty():
		_play_effect_hit_feedback(_field_slot_for(opponent, 0), _card_result_preview(card), Color(0.78, 0.9, 1.0, 1.0))
	else:
		_play_effect_hit_feedback(_hero_target_for_player(false), _card_result_preview(card), Color(0.78, 0.9, 1.0, 1.0))

func _play_slot_pop_feedback(target: Control, text: String, color: Color) -> void:
	if target == null or not is_instance_valid(target):
		return
	target.pivot_offset = target.size * 0.5
	var original_scale = target.scale
	var original_modulate = target.modulate
	target.scale = original_scale * 0.72
	target.modulate = Color(color.r, color.g, color.b, 0.88)
	_show_slot_overlay_text(target, text, color)
	_spawn_target_glow(target, color, 0.48)
	var tween = target.create_tween()
	tween.tween_property(target, "scale", original_scale * 1.2, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(target, "modulate", original_modulate, 0.22)
	tween.tween_property(target, "scale", original_scale, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_shake_target(target, 7.0)

func _play_effect_hit_feedback(target: Control, text: String, color: Color) -> void:
	if target == null or not is_instance_valid(target):
		return
	_show_outcome_text(target, text, color)
	_spawn_target_glow(target, color, 0.28)
	_flash_target(target, color, 0.24)

func _base_card_id(card_id: String) -> String:
	return card_id.trim_suffix("_plus") if card_id.ends_with("_plus") else card_id

func _selected_player_attacker() -> Dictionary:
	if selected_attacker < 0 or selected_attacker >= player.field.size():
		return {}
	return player.field[selected_attacker]

func _predict_unit_attack(attacker: Dictionary, defender: Dictionary, attacker_side: Dictionary, defender_side: Dictionary) -> Dictionary:
	if attacker.is_empty() or defender.is_empty():
		return {}
	var attack_damage = _calculate_damage(attacker, false, attacker_side, int(attacker.get("attack", 0)))
	var counter_damage = _calculate_damage(defender, false, defender_side, int(defender.get("attack", 0)))
	var lethal = int(defender.get("health", 0)) - attack_damage <= 0
	if lethal:
		counter_damage = 0
	return {
		"damage": attack_damage,
		"counter": counter_damage,
		"lethal": lethal,
	}

func _predict_hero_attack_damage(attacker: Dictionary, attacker_side: Dictionary, target_is_player: bool) -> int:
	if attacker.is_empty():
		return 0
	var damage = _calculate_damage(attacker, false, attacker_side, int(attacker.get("attack", 0)))
	if not target_is_player:
		damage = main.relic_service.mitigate_hero_damage(main.current_run, battle_state, damage, false)
	return damage

func _attack_prediction_text(prediction: Dictionary) -> String:
	if prediction.is_empty():
		return ""
	var parts: Array[String] = []
	if bool(prediction.get("lethal", false)):
		parts.append("처치 가능")
	else:
		parts.append("피해 %d" % int(prediction.get("damage", 0)))
	if int(prediction.get("counter", 0)) > 0:
		parts.append("반격 %d" % int(prediction.get("counter", 0)))
	return " · ".join(parts)

func _card_heal_preview(card: Dictionary) -> int:
	var card_id = _base_card_id(String(card.get("id", "")))
	match card_id:
		"first_aid":
			return 3
		"healing_potion":
			return 5
		"vampiric_strike":
			return 2
		"moonwell":
			return 4
	return 0

func _direct_damage_preview(card: Dictionary) -> int:
	var card_id = _base_card_id(String(card.get("id", "")))
	var base_damage = 0
	match card_id:
		"small_flame", "funeral_fog", "vampiric_strike":
			base_damage = 2
		"fireball":
			base_damage = 4
		"gale_shot":
			base_damage = 4 if int(battle_state.get("cards_played_this_turn", 0)) >= 3 else 1
		"corpse_explosion":
			base_damage = 2
		"plague_spread":
			base_damage = 1
	if base_damage <= 0:
		return 0
	return _calculate_damage(card, true, player, base_damage)

func _card_result_preview(card: Dictionary) -> String:
	var default_summary: String = main._card_effect_summary(card)
	var card_type = String(card.get("type", ""))
	var card_id = _base_card_id(String(card.get("id", "")))
	var parts: Array[String] = []
	if card_type == "unit":
		parts.append("소환 %d/%d" % [int(card.get("attack", 0)), int(card.get("health", 0))])
		match card_id:
			"militia":
				parts.append("앞 적 피해 1")
			"trainee_swordsman":
				parts.append("체력 +1")
			"forest_archer":
				parts.append("드로우 +1")
			"knight_spearman":
				parts.append("선봉 공격 +1")
			"thief":
				parts.append("내 HP -1")
			"bone_oracle":
				parts.append("저주 +1")
			"ritual_sapling":
				parts.append("의식 +1")
			"stone_golem":
				parts.append("회복 +2")
		return " · ".join(parts.slice(0, 2))
	if card_type == "equipment":
		return default_summary
	var damage = _direct_damage_preview(card)
	if damage > 0:
		if card_id == "corpse_explosion":
			parts.append("광역 피해 %d" % damage)
		elif card_id == "plague_spread":
			parts.append("전체 피해 %d" % damage)
		else:
			parts.append("앞 적 피해 %d" % damage)
	var heal = _card_heal_preview(card)
	if heal > 0:
		parts.append("영웅 회복 %d" % heal)
		if card_id == "first_aid":
			parts.append("앞 아군 체력 +1")
	if card_id in ["elven_insight", "dark_bargain"]:
		parts.append("드로우 +2")
	if card_id in ["royal_support", "soul_shackle", "nature_communion", "ancient_oath"]:
		parts.append("드로우 +1")
	if card_id == "battlecry":
		parts.append("아군 강화")
	if card_id == "captain_order":
		parts.append("아군 강화")
	if card_id == "nature_blessing":
		parts.append("아군 강화")
	if card_id == "call_of_dead":
		parts.append("소환 1/1 x2")
	if card_id in ["death_mark", "bone_oracle", "funeral_fog"]:
		parts.append("저주 +1")
	if card_id in ["soul_shackle", "plague_spread"]:
		parts.append("저주 +2")
	if card_id in ["world_tree_ritual", "nature_communion"]:
		parts.append("의식 +1")
	if card_id == "ancient_oath":
		parts.append("의식 +2")
	if card_id == "corpse_explosion":
		parts.append("아군 희생")
	if parts.is_empty():
		parts.append(default_summary)
	return " · ".join(parts.slice(0, 2))

func _recommended_hand_index() -> int:
	if _is_player_input_locked():
		return -1
	var best_index = -1
	var best_score = -1
	var needs_heal = int(player.get("health", 0)) <= int(ceil(float(player.get("max_health", 1)) * 0.45))
	var front_enemy_health = 0
	if not opponent.field.is_empty():
		front_enemy_health = int(Dictionary(opponent.field[0]).get("health", 0))
	var build_scores: Dictionary = main._current_build_scores()
	for i in range(player.hand.size()):
		var card: Dictionary = player.hand[i]
		if not _can_play_card(player, card, "player"):
			continue
		var score = 10
		var card_type = String(card.get("type", ""))
		var heal = _card_heal_preview(card)
		var damage = _direct_damage_preview(card)
		if needs_heal and heal > 0:
			score = 130
		elif front_enemy_health > 0 and damage >= front_enemy_health:
			score = 120
		elif card_type == "unit":
			score = 100
		elif damage > 0:
			score = 80
		elif heal > 0:
			score = 60
		elif card_type == "equipment":
			score = 55
		for tag in main._card_build_tags(card):
			var current_score := int(build_scores.get(tag, 0))
			if current_score >= main._build_threshold():
				score += 28
			elif current_score + 1 >= main._build_threshold():
				score += 42
			elif current_score >= main._build_threshold() - 2:
				score += 18
		var combo_tag := String(battle_state.get("combo_tag", ""))
		if not combo_tag.is_empty() and main._card_build_tags(card).has(combo_tag):
			score += 34
		if score > best_score:
			best_score = score
			best_index = i
	return best_index

func _recommended_hand_card() -> Dictionary:
	var index = _recommended_hand_index()
	if index < 0 or index >= player.hand.size():
		return {}
	return player.hand[index]


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
	await _execute_player_unit_attack(selected_attacker, index)
	selected_attacker = -1
	_check_game_over()
	_refresh_ui()
	_store_battle_snapshot()
	_check_no_actions_loss()


func _attack_opponent_hero() -> void:
	if input_locked or game_over or current_player != "player" or selected_attacker == -1:
		return
	await _execute_player_hero_attack(selected_attacker)
	selected_attacker = -1
	_check_game_over()
	_refresh_ui()
	_store_battle_snapshot()
	_check_no_actions_loss()

func _execute_player_hero_attack(attacker_index: int) -> void:
	if attacker_index < 0 or attacker_index >= player.field.size():
		return
	var attacker: Dictionary = player.field[attacker_index]
	var damage = _calculate_damage(attacker, false, player, int(attacker.attack))
	damage = main.relic_service.mitigate_hero_damage(main.current_run, battle_state, damage, false)
	input_locked = true
	_refresh_ui()
	if _is_battle_cutscene_enabled():
		await _play_hero_cutscene(attacker, opponent.name, damage, player, attacker_index, false)
	else:
		_play_hero_attack_feedback(player, attacker_index, false, damage)
	opponent.health -= damage
	attacker.can_attack = false
	if damage >= 3:
		_shake_screen(15.0, 0.3)
	if int(opponent.health) <= 0:
		_show_outcome_text(_hero_target_for_player(false), "승리", Color(1.0, 0.82, 0.24, 1.0))
	if damage >= 5:
		_play_effect_hit_feedback(_hero_target_for_player(false), "결정타", Color(1.0, 0.86, 0.34, 1.0))
	_add_log("%s -> 적 영웅: %d 피해" % [attacker.name, damage])
	input_locked = false

func _execute_player_unit_attack(attacker_index: int, defender_index: int) -> void:
	if attacker_index < 0 or attacker_index >= player.field.size():
		return
	if defender_index < 0 or defender_index >= opponent.field.size():
		return
	await _combat(player, opponent, attacker_index, defender_index)


func _combat(attacker_side: Dictionary, defender_side: Dictionary, attacker_index: int, defender_index: int) -> void:
	var attacker: Dictionary = attacker_side.field[attacker_index]
	var defender: Dictionary = defender_side.field[defender_index]
	var attack_damage = _calculate_damage(attacker, false, attacker_side, int(attacker.attack))
	var defense_damage = _calculate_damage(defender, false, defender_side, int(defender.attack))
	var defender_lethal = int(defender.health) - attack_damage <= 0

	if defender_lethal:
		defense_damage = 0
	var attacker_lethal = defense_damage > 0 and int(attacker.health) - defense_damage <= 0

	input_locked = true
	_refresh_ui()

	if _is_battle_cutscene_enabled():
		await _play_unit_battle_feedback(attacker_side, defender_side, attacker_index, defender_index, attack_damage, defense_damage)
	else:
		_play_unit_battle_feedback(attacker_side, defender_side, attacker_index, defender_index, attack_damage, defense_damage)

	defender.health -= attack_damage
	attacker.health -= defense_damage
	if attack_damage >= 3 or defense_damage >= 3:
		_shake_screen(10.0, 0.2)
	attacker.can_attack = false
	if defender_lethal:
		_play_defeat_feedback(_field_slot_for(defender_side, defender_index), Color(1.0, 0.82, 0.24, 1.0))
	if attacker_lethal:
		_play_defeat_feedback(_field_slot_for(attacker_side, attacker_index), Color(1.0, 0.42, 0.34, 1.0))
	_cleanup_dead_units(attacker_side, defender_side)
	if defense_damage > 0:
		_add_log("%s 반격: %d 피해" % [defender.name, defense_damage])
	var summary = "%s -> %s: %d 피해" % [attacker.name, defender.name, attack_damage]
	if defender_lethal:
		summary += " / 처치"
		_play_effect_hit_feedback(_field_slot_for(defender_side, defender_index), "유리한 교환", Color(1.0, 0.86, 0.34, 1.0))
		_trigger_hype_moment(_field_slot_for(defender_side, defender_index), "처치!", Color(1.0, 0.86, 0.34, 1.0), "finisher", 12.0, 42, false)
	elif attack_damage >= 4:
		_play_effect_hit_feedback(_field_slot_for(defender_side, defender_index), "강한 압박", Color(1.0, 0.58, 0.24, 1.0))
		_trigger_hype_moment(_field_slot_for(defender_side, defender_index), "강타 %d" % attack_damage, Color(1.0, 0.58, 0.24, 1.0), "finisher", 8.0, 34, false)
	_add_log(summary)
	input_locked = false
	_store_battle_snapshot()


func _check_no_actions_loss() -> void:
	if current_player != "player" or input_locked or game_over or main.active_screen != "battle":
		return
	var has_attacker = false
	for unit in player.field:
		if bool(unit.get("can_attack", false)):
			has_attacker = true
			break
	var has_playable_card = false
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
	var slots = player_field_slots if side == player else opponent_field_slots
	if index < 0 or index >= slots.size():
		return null
	var slot = slots[index]
	if slot == null or not is_instance_valid(slot):
		return null
	return slot as Control

func _hero_target_for_player(is_player_target: bool) -> Control:
	var target = player_hero_target if is_player_target else opponent_hero_target
	if target == null or not is_instance_valid(target):
		return null
	return target

func _play_unit_battle_feedback(attacker_side: Dictionary, defender_side: Dictionary, attacker_index: int, defender_index: int, attack_damage: int, defense_damage: int) -> void:
	var attacker_node = _field_slot_for(attacker_side, attacker_index)
	var defender_node = _field_slot_for(defender_side, defender_index)
	if not _is_battle_cutscene_enabled():
		_show_damage_number(defender_node, attack_damage)
		_play_attack_impact_fx(attacker_node, defender_node, attack_damage, false)
		_play_sfx(_attack_impact_sfx(attack_damage, false))
		_show_damage_number(attacker_node, defense_damage, true)
		if defense_damage > 0:
			_play_attack_impact_fx(defender_node, attacker_node, defense_damage, true)
			_play_sfx(_attack_impact_sfx(defense_damage, true))
		if not _should_skip_timed_battle_fx():
			_spawn_impact_slash(defender_node, false)
			_flash_target(defender_node, Color(1.0, 0.28, 0.22, 1.0), 0.22)
			if defense_damage > 0:
				_spawn_impact_slash(attacker_node, true)
				_flash_target(attacker_node, Color(1.0, 0.66, 0.18, 1.0), 0.22)
		return
	await _play_inline_attack_feedback(attacker_node, defender_node, attack_damage, attacker_side == player)
	if defense_damage > 0:
		await _play_inline_attack_feedback(defender_node, attacker_node, defense_damage, defender_side == player, true)

func _play_hero_attack_feedback(attacker_side: Dictionary, attacker_index: int, defender_is_player: bool, damage: int) -> void:
	var attacker_node = _field_slot_for(attacker_side, attacker_index)
	var defender_node = _hero_target_for_player(defender_is_player)
	if not _is_battle_cutscene_enabled():
		_show_damage_number(defender_node, damage)
		_play_attack_impact_fx(attacker_node, defender_node, damage, false)
		_play_sfx(_attack_impact_sfx(damage, false))
		if not _should_skip_timed_battle_fx():
			_spawn_impact_slash(defender_node, false)
			_flash_target(defender_node, Color(1.0, 0.28, 0.22, 1.0), 0.22)
		return
	await _play_inline_attack_feedback(attacker_node, defender_node, damage, attacker_side == player)

func _play_inline_attack_feedback(attacker_node: Control, defender_node: Control, damage: int, attacker_is_player: bool, counter: bool = false) -> void:
	if attacker_node == null or defender_node == null:
		_show_damage_number(defender_node, damage, counter)
		return
	var start_pos = attacker_node.position
	var start_rotation := attacker_node.rotation
	var lunge_offset = Vector2(0, -58 if attacker_is_player else 58)
	if counter:
		lunge_offset *= 0.72
	attacker_node.pivot_offset = attacker_node.size * 0.5
	var lunge = attacker_node.create_tween()
	lunge.tween_property(attacker_node, "position", start_pos + lunge_offset, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	lunge.parallel().tween_property(attacker_node, "scale", Vector2(1.15, 1.15), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lunge.parallel().tween_property(attacker_node, "rotation", start_rotation + deg_to_rad(-3.5 if attacker_is_player else 3.5), 0.1)
	lunge.tween_property(attacker_node, "position", start_pos, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	lunge.parallel().tween_property(attacker_node, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	lunge.parallel().tween_property(attacker_node, "rotation", start_rotation, 0.16)
	await lunge.finished
	_show_damage_number(defender_node, damage, counter)
	_play_attack_impact_fx(attacker_node, defender_node, damage, counter)
	_play_sfx(_attack_impact_sfx(damage, counter))
	_spawn_impact_slash(defender_node, counter)
	_flash_target(defender_node, Color(1.0, 0.66, 0.18, 1.0) if counter else Color(1.0, 0.28, 0.22, 1.0), 0.24)
	await _shake_target(defender_node, 12.0 if damage < 3 else 18.0)

func _attack_impact_sfx(damage: int, counter: bool) -> String:
	if counter:
		return "counter"
	return "impact_heavy" if damage >= 4 else "hit"

func _play_attack_impact_fx(attacker: Control, defender: Control, damage: int, counter: bool) -> void:
	if _should_skip_timed_battle_fx():
		return
	if battle_fx_layer != null and is_instance_valid(battle_fx_layer):
		battle_fx_layer.play_attack(attacker, defender, damage, counter)
	_pulse_impact_target(defender, damage >= 4)

func _pulse_impact_target(target: Control, strong: bool) -> void:
	if target == null or not is_instance_valid(target):
		return
	target.pivot_offset = target.size * 0.5
	var original_scale := target.scale
	var squash := Vector2(original_scale.x * (1.12 if strong else 1.07), original_scale.y * (0.9 if strong else 0.94))
	var tween := target.create_tween()
	tween.tween_property(target, "scale", squash, 0.045).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", original_scale, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _show_damage_number(target: Control, damage: int, counter: bool = false) -> void:
	if damage <= 0 or target == null or not is_instance_valid(target):
		return
	var color = Color(1.0, 0.72, 0.24, 1.0) if counter else Color(1.0, 0.26, 0.24, 1.0)
	var font_size := 48 if counter else (72 if damage >= 4 else 58)
	var lifetime := 1.15 if damage >= 4 else 1.0
	_spawn_floating_text(target, "-%d" % damage, color, font_size, lifetime, Vector2.ZERO)
	if damage >= 4 and not counter:
		_shake_screen(12.0, 0.2)

func _show_outcome_text(target: Control, text: String, color: Color) -> void:
	if target == null or not is_instance_valid(target):
		return
	_spawn_floating_text(target, text, color, 38, 0.95, Vector2(0, -32))

func _show_slot_overlay_text(target: Control, text: String, color: Color) -> void:
	if target == null or not is_instance_valid(target) or text.is_empty():
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.custom_minimum_size = Vector2(max(92.0, target.size.x), 36)
	lbl.add_theme_font_size_override("font_size", 26 if not _is_tight_battle_layout() else 20)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.01, 0.01, 0.01, 1.0))
	lbl.add_theme_constant_override("outline_size", 7)
	lbl.z_index = 160
	target.add_child(lbl)
	lbl.position = Vector2((target.size.x - lbl.custom_minimum_size.x) * 0.5, target.size.y * 0.42 - 18.0)
	lbl.scale = Vector2(0.72, 0.72)
	lbl.modulate.a = 0.0
	var tween := lbl.create_tween()
	tween.tween_property(lbl, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 1.0, 0.08)
	tween.tween_interval(0.34)
	tween.tween_property(lbl, "position:y", lbl.position.y - 22.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_callback(Callable(self, "_queue_free_if_valid").bind(lbl))

func _clear_card_board_preview() -> void:
	for node in card_preview_nodes:
		_queue_free_if_valid(node)
	card_preview_nodes.clear()

func _add_card_preview_marker(target: Control, text: String, color: Color, offset: Vector2 = Vector2.ZERO) -> void:
	if target == null or not is_instance_valid(target) or text.is_empty():
		return
	var glow := ColorRect.new()
	glow.color = Color(color.r, color.g, color.b, 0.16)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.z_index = 180
	target.add_child(glow)
	card_preview_nodes.append(glow)

	var marker := _make_battle_badge(text, Color(0.025, 0.035, 0.048, 0.96), color, 11 if not _is_tight_battle_layout() else 9)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.z_index = 190
	target.add_child(marker)
	var width: float = max(88.0, min(target.size.x + 22.0, 164.0))
	marker.custom_minimum_size = Vector2(width, 30)
	marker.position = Vector2((target.size.x - width) * 0.5, max(4.0, target.size.y * 0.28 - 16.0)) + offset
	marker.scale = Vector2(0.92, 0.92)
	marker.modulate.a = 0.0
	card_preview_nodes.append(marker)
	var tween := marker.create_tween()
	tween.tween_property(marker, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(marker, "modulate:a", 1.0, 0.08)

func _front_opponent_target() -> Control:
	if not opponent.field.is_empty():
		return _field_slot_for(opponent, 0)
	return _hero_target_for_player(false)

func _show_card_board_preview(card: Dictionary, playable: bool) -> void:
	_clear_card_board_preview()
	if not playable or _is_player_input_locked():
		return
	var card_type := String(card.get("type", ""))
	var card_id := _base_card_id(String(card.get("id", "")))
	var accent := _card_accent_color(card)
	if card_type == "unit":
		var summon_index: int = player.field.size()
		if summon_index < player_field_slots.size():
			_add_card_preview_marker(player_field_slots[summon_index], "소환 %d/%d" % [int(card.get("attack", 0)), int(card.get("health", 0))], Color(0.34, 0.82, 1.0, 1.0))
		if card_id == "militia" and not opponent.field.is_empty():
			var target := _field_slot_for(opponent, 0)
			var damage := 1
			var hp := int(Dictionary(opponent.field[0]).get("health", 0))
			_add_card_preview_marker(target, "처치 가능" if damage >= hp else "피해 %d" % damage, Color(1.0, 0.34, 0.24, 1.0), Vector2(0, 24))
		elif card_id == "stone_golem":
			_add_card_preview_marker(_hero_target_for_player(true), "회복 2", Color(0.34, 1.0, 0.68, 1.0))
		elif card_id == "forest_archer":
			_add_card_preview_marker(_hero_target_for_player(true), "드로우 +1", Color(0.42, 0.72, 1.0, 1.0))
		return
	var damage := _direct_damage_preview(card)
	if damage > 0:
		if card_id == "plague_spread":
			for i in range(opponent.field.size()):
				var unit: Dictionary = opponent.field[i]
				_add_card_preview_marker(_field_slot_for(opponent, i), "처치 가능" if damage >= int(unit.get("health", 0)) else "피해 %d" % damage, Color(1.0, 0.34, 0.24, 1.0))
			_add_card_preview_marker(_hero_target_for_player(false), "영웅 피해 %d" % damage, Color(1.0, 0.34, 0.24, 1.0))
		elif card_id == "corpse_explosion":
			for i in range(opponent.field.size()):
				var unit: Dictionary = opponent.field[i]
				_add_card_preview_marker(_field_slot_for(opponent, i), "처치 가능" if damage >= int(unit.get("health", 0)) else "피해 %d" % damage, Color(1.0, 0.34, 0.24, 1.0))
			if not player.field.is_empty():
				_add_card_preview_marker(_field_slot_for(player, 0), "희생", Color(0.76, 0.5, 1.0, 1.0))
		else:
			var target := _front_opponent_target()
			var text := "피해 %d" % damage
			if not opponent.field.is_empty() and damage >= int(Dictionary(opponent.field[0]).get("health", 0)):
				text = "처치 가능"
			elif opponent.field.is_empty():
				text = "영웅 피해 %d" % damage
			_add_card_preview_marker(target, text, Color(1.0, 0.34, 0.24, 1.0))
	var heal := _card_heal_preview(card)
	if heal > 0:
		_add_card_preview_marker(_hero_target_for_player(true), "회복 %d" % heal, Color(0.34, 1.0, 0.68, 1.0))
	if card_id == "first_aid" and not player.field.is_empty():
		_add_card_preview_marker(_field_slot_for(player, 0), "체력 +1", Color(0.34, 1.0, 0.68, 1.0), Vector2(0, 24))
	if card_id in ["battlecry", "captain_order", "nature_blessing"] and not player.field.is_empty():
		_add_card_preview_marker(_field_slot_for(player, 0), "강화", accent.lightened(0.2))
	if card_id in ["elven_insight", "dark_bargain", "royal_support", "soul_shackle", "nature_communion", "ancient_oath"]:
		_add_card_preview_marker(_hero_target_for_player(true), _card_result_preview(card), Color(0.42, 0.72, 1.0, 1.0))

func _play_defeat_feedback(target: Control, color: Color) -> void:
	if target == null or not is_instance_valid(target):
		return
	_show_outcome_text(target, "처치", color)
	_spawn_target_glow(target, color, 0.36)
	target.pivot_offset = target.size * 0.5
	var tween = target.create_tween()
	tween.tween_property(target, "scale", Vector2(0.92, 0.92), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(target, "modulate", Color(0.38, 0.34, 0.34, 0.76), 0.12)

func _flash_target(target: Control, color: Color, duration: float = 0.2) -> void:
	if target == null or not is_instance_valid(target):
		return
	var original_modulate = target.modulate
	target.modulate = Color(color.r, color.g, color.b, 0.92)
	var tween = target.create_tween()
	tween.tween_property(target, "modulate", original_modulate, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func _spawn_target_glow(target: Control, color: Color, duration: float = 0.28) -> void:
	if target == null or not is_instance_valid(target):
		return
	var glow = ColorRect.new()
	glow.color = Color(color.r, color.g, color.b, 0.18)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.z_index = 90
	target.add_child(glow)
	var tween = glow.create_tween()
	tween.tween_property(glow, "color:a", 0.0, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_callback(Callable(self, "_queue_free_if_valid").bind(glow))

func _shake_target(target: Control, intensity: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var origin = target.position
	var tween = target.create_tween()
	for i in range(4):
		tween.tween_property(target, "position", origin + Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), 0.035)
	tween.tween_property(target, "position", origin, 0.05)
	await tween.finished

func _spawn_impact_slash(target: Control, counter: bool = false) -> void:
	if target == null or not is_instance_valid(target):
		return
	var slash = Line2D.new()
	slash.width = 10.0
	slash.default_color = Color(1.0, 0.72, 0.24, 0.95) if counter else Color(0.72, 0.9, 1.0, 0.98)
	slash.begin_cap_mode = Line2D.LINE_CAP_ROUND
	slash.end_cap_mode = Line2D.LINE_CAP_ROUND
	var cx: float = max(24.0, target.size.x * 0.5)
	var cy: float = max(24.0, target.size.y * 0.5)
	slash.add_point(Vector2(cx - 44.0, cy - 32.0))
	slash.add_point(Vector2(cx + 44.0, cy + 32.0))
	target.add_child(slash)
	var slash_two = Line2D.new()
	slash_two.width = 5.0
	slash_two.default_color = Color(1.0, 0.34, 0.24, 0.72) if counter else Color(1.0, 1.0, 1.0, 0.72)
	slash_two.begin_cap_mode = Line2D.LINE_CAP_ROUND
	slash_two.end_cap_mode = Line2D.LINE_CAP_ROUND
	slash_two.add_point(Vector2(cx + 34.0, cy - 30.0))
	slash_two.add_point(Vector2(cx - 34.0, cy + 30.0))
	target.add_child(slash_two)
	var tween = slash.create_tween()
	tween.tween_property(slash, "width", 0.0, 0.24).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slash, "modulate:a", 0.0, 0.24)
	tween.tween_callback(Callable(self, "_queue_free_if_valid").bind(slash))
	var tween_two = slash_two.create_tween()
	tween_two.tween_property(slash_two, "width", 0.0, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween_two.parallel().tween_property(slash_two, "modulate:a", 0.0, 0.18)
	tween_two.tween_callback(Callable(self, "_queue_free_if_valid").bind(slash_two))


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
	_play_sfx("click")
	input_locked = true
	_discard_hand(player)
	current_player = "opponent"
	selected_attacker = -1
	await _start_turn(opponent, false)
	_refresh_ui()
	_store_battle_snapshot()
	var ai_wait = 0.5
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

func _show_opponent_played_card_fx(card: Dictionary) -> void:
	if _should_skip_timed_battle_fx():
		return

	if main.audio_manager != null:
		main.audio_manager.play_sound(_card_play_sfx(String(card.get("type", ""))))

	var popup = PanelContainer.new()
	var frame_size = Vector2(200, 260)
	popup.custom_minimum_size = frame_size
	popup.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	popup.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var viewport_size: Vector2 = main.get_viewport_rect().size
	popup.position = (viewport_size - frame_size) / 2.0
	popup.modulate.a = 0.0
	popup.scale = Vector2(0.6, 0.6)
	popup.pivot_offset = frame_size / 2.0

	var style = _make_modern_style(Color(0.055, 0.065, 0.078, 0.98), _card_accent_color(card), 2, 8, 12)
	style.content_margin_left = 12
	style.content_margin_top = 12
	style.content_margin_right = 12
	style.content_margin_bottom = 12
	popup.add_theme_stylebox_override("panel", style)

	main.add_child(popup)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(box)

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)

	var cost: int = main.relic_service.modify_card_cost(main.current_run, battle_state, card, "opponent")
	var cost_badge: PanelContainer = main.ui.make_cost_badge("%d" % cost, true)
	cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(cost_badge)

	var name_band: PanelContainer = main.ui.make_surface_panel(_card_accent_color(card).darkened(0.28), _card_accent_color(card).lightened(0.12), 1, 5, 3)
	name_band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(name_band)

	var name_label: Label = main._make_label(String(card.get("name", "")), 13, Color(1.0, 0.96, 0.82, 1.0))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_band.add_child(name_label)

	var art_size = Vector2(176, 110)
	var art_rect: TextureRect = main._make_card_art_rect(card, art_size)
	art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(art_rect)

	var effect_label: Label = main._make_label(main._card_detail_text(card), 11, Color(0.85, 0.9, 0.96, 1.0))
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.custom_minimum_size = Vector2(0, 48)
	effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(effect_label)

	var banner: PanelContainer = main.ui.make_chip("적 카드 사용!", Color(0.42, 0.12, 0.12, 1.0), Color(1.0, 0.82, 0.82, 1.0), 10)
	banner.position = Vector2((frame_size.x - banner.custom_minimum_size.x) / 2.0, -18)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(banner)

	var tween: Tween = main.create_tween()
	tween.tween_property(popup, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(popup, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await main.get_tree().create_timer(0.85).timeout

	var fade_tween: Tween = main.create_tween()
	fade_tween.tween_property(popup, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade_tween.parallel().tween_property(popup, "scale", Vector2(0.8, 0.8), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade_tween.tween_callback(Callable(self, "_queue_free_if_valid").bind(popup))

	await fade_tween.finished

func _run_ai_play_cards() -> void:
	var played = true
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

				# Show card play presentation for AI
				_refresh_ui()
				await _show_opponent_played_card_fx(card)

				main.battle_effects.play_card(opponent, player, card, _battle_effect_context())
				_refresh_ui()
				_check_game_over()
				played = true
				if game_over:
					return
				if not _is_fast_ai_enabled() and not _should_skip_timed_battle_fx():
					await main.get_tree().create_timer(0.25).timeout
				_store_battle_snapshot()
				break

func _run_ai_attack_sequence() -> void:
	var i = 0
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
	var damage = _calculate_damage(unit, false, opponent, int(unit.attack))
	damage = main.relic_service.mitigate_hero_damage(main.current_run, battle_state, damage, true)
	input_locked = true
	_refresh_ui()
	if _is_battle_cutscene_enabled():
		await _play_hero_cutscene(unit, player.name, damage, opponent, index, true)
	else:
		_play_hero_attack_feedback(opponent, index, true, damage)
	player.health -= damage
	if damage > 0:
		main.relic_service.on_hero_hp_lost(main.current_run, battle_state, player, damage)
	unit.can_attack = false
	if int(player.health) <= 0:
		_show_outcome_text(_hero_target_for_player(true), "패배", Color(1.0, 0.34, 0.28, 1.0))
	_add_log("플레이어 영웅 %d 피해" % damage)
	input_locked = false
	_store_battle_snapshot()


func _check_game_over() -> void:
	if battle_finished:
		return
	if int(player.health) <= 0:
		var upgrades = _profile_upgrades()
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
	var reward: Dictionary = _apply_battle_victory_rewards()
	await _play_battle_victory_sequence(reward)
	main.current_run["active_enemy"] = {}
	main.current_run["battle_snapshot"] = {}
	if battle_tier == "boss":
		main.current_run["pending_card_reward"] = {}
		main.set_meta("suppress_next_result_victory_audio", true)
		main.run_flow.advance_from_current_node()
		return
	main.current_run["pending_card_reward"] = reward
	_save_run()
	_show_card_reward()

func _play_battle_victory_sequence(reward: Dictionary) -> void:
	var race_meta: Dictionary = main._current_race_meta()
	var accent: Color = race_meta.get("color", Color(1.0, 0.82, 0.28, 1.0))
	var target := _hero_target_for_player(false)
	var title := "보스 격파!" if battle_tier == "boss" else "전투 승리!"
	_play_sfx("victory_burst")
	if _should_skip_timed_battle_fx():
		return
	if battle_fx_layer != null and is_instance_valid(battle_fx_layer):
		battle_fx_layer.play_victory(accent, _is_battle_cutscene_enabled() or battle_tier == "boss")
	if target != null and is_instance_valid(target):
		_spawn_target_glow(target, Color(1.0, 0.82, 0.28, 1.0), 0.92)
		_spawn_floating_text(target, title, Color(1.0, 0.88, 0.38, 1.0), 62, 1.25, Vector2(0, -8))
	_spawn_center_banner(title, Color(1.0, 0.9, 0.48, 1.0), 56, 1.18)
	_shake_screen(22.0 if battle_tier == "boss" else 17.0, 0.38)
	var full_sequence := _is_battle_cutscene_enabled() or battle_tier == "boss"
	await main.get_tree().create_timer(0.58 if full_sequence else 0.22).timeout
	_spawn_center_banner("보상 +%dG" % int(reward.get("gold_reward", 0)), accent.lightened(0.36), 36, 0.72)
	_play_sfx("reward")
	await main.get_tree().create_timer(0.48 if full_sequence else 0.12).timeout

func _spawn_floating_text(target: Control, text: String, color: Color, font_size: int = 42, duration: float = 0.85, center_offset: Vector2 = Vector2.ZERO) -> void:
	if text.is_empty() or target == null or not is_instance_valid(target):
		return
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(160, 48)
	lbl.pivot_offset = Vector2(80, 24)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 7)
	lbl.z_index = 100
	lbl.rotation_degrees = randf_range(-12, 12)

	main.modal_layer.add_child(lbl)
	lbl.global_position = target.global_position + target.size / 2.0 - Vector2(80, 24) + center_offset

	var tween: Tween = main.create_tween()
	tween.tween_property(lbl, "scale", Vector2(1.22, 1.22), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "position:y", lbl.position.y - 76, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_callback(Callable(self, "_queue_free_if_valid").bind(lbl))

func _spawn_center_banner(text: String, color: Color, font_size: int = 42, duration: float = 0.9) -> void:
	if text.is_empty() or main.modal_layer == null or not is_instance_valid(main.modal_layer):
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(420, 72)
	lbl.pivot_offset = lbl.custom_minimum_size / 2.0
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 1.0))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.z_index = 120
	main.modal_layer.add_child(lbl)
	var viewport: Vector2 = main.get_viewport_rect().size
	lbl.global_position = viewport * 0.5 - lbl.custom_minimum_size / 2.0 + Vector2(0, -80)
	lbl.scale = Vector2(0.76, 0.76)
	lbl.modulate.a = 0.0
	var tween: Tween = main.create_tween()
	tween.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 1.0, 0.12)
	tween.tween_interval(max(0.22, duration - 0.28))
	tween.tween_property(lbl, "position:y", lbl.position.y - 36, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_callback(Callable(self, "_queue_free_if_valid").bind(lbl))

func _trigger_hype_moment(target: Control, text: String, color: Color, sfx_name: String, shake: float = 8.0, font_size: int = 42, center_banner: bool = false) -> void:
	if not sfx_name.is_empty():
		_play_sfx(sfx_name)
	if shake > 0.0:
		_shake_screen(shake, 0.18 if shake < 12.0 else 0.24)
	if target != null and is_instance_valid(target):
		_spawn_target_glow(target, color, 0.42)
		_spawn_floating_text(target, text, color, font_size, 0.95, Vector2.ZERO)
	if center_banner:
		_spawn_center_banner(text, color, max(28, font_size - 6), 1.0)


func _flash_label(label: Label, delta: int, original_color: Color) -> void:
	if label == null or not is_instance_valid(label):
		return
	var color = Color(1.0, 0.25, 0.25) if delta < 0 else Color(0.25, 1.0, 0.25)
	label.add_theme_color_override("font_color", color)
	label.pivot_offset = label.size / 2.0
	var tween: Tween = main.create_tween()
	tween.tween_property(label, "scale", Vector2(1.18, 1.18), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(Callable(self, "_restore_label_color_if_valid").bind(label, original_color))

func _clear_container(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()

func _queue_free_if_valid(node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()

func _restore_label_color_if_valid(label, original_color: Color) -> void:
	if label != null and is_instance_valid(label) and label is Label:
		(label as Label).add_theme_color_override("font_color", original_color)

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
	var tight = _is_tight_battle_layout()
	var portrait = _is_portrait_battle_layout()
	var wide_tight = _is_wide_tight_battle_layout()
	var mobile = _is_mobile_battle_layout()
	var placeholder = PanelContainer.new()
	placeholder.add_theme_stylebox_override("panel", _make_field_slot_style(Color(0.018, 0.025, 0.035, 0.52), Color(0.18, 0.3, 0.42, 0.54), 1))
	placeholder.custom_minimum_size = Vector2(116, 146) if mobile else (Vector2(108, 132) if tight and portrait else (Vector2(126, 118) if wide_tight else (Vector2(128, 150) if tight else (Vector2(150, 176) if not compact else Vector2(128, 150)))))
	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	placeholder.add_child(box)
	var emblem: Label = main._make_label("+", 26 if mobile else (22 if tight and portrait else (24 if tight else (26 if compact else 30))), Color(0.4, 0.52, 0.68, 0.32))
	emblem.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(emblem)
	var text: Label = main._make_label("빈 슬롯", 9 if tight and portrait else (10 if tight else (10 if compact else 11)), Color(0.52, 0.6, 0.7, 0.58))
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(text)
	return placeholder

func _build_field_slot(side: Dictionary, index: int, is_player_field: bool) -> Control:
	var compact = _is_compact_layout()
	var tight = _is_tight_battle_layout()
	var portrait = _is_portrait_battle_layout()
	var wide_tight = _is_wide_tight_battle_layout()
	var mobile = _is_mobile_battle_layout()
	if index >= side.field.size():
		return _make_empty_field_slot(compact)

	var frame_size = Vector2(116, 146) if mobile else (Vector2(108, 132) if tight and portrait else (Vector2(126, 118) if wide_tight else (Vector2(128, 150) if tight else (Vector2(150, 176) if not compact else Vector2(128, 150)))))
	var content_size = Vector2(frame_size.x - 12.0, frame_size.y - 10.0)
	var art_size = Vector2(content_size.x, content_size.y - (20 if wide_tight else (24 if tight else 30)))

	# The slot container is now a Button, making the entire card clickable!
	var frame = Button.new()
	frame.custom_minimum_size = frame_size

	# Determine interaction states
	var is_disabled = false
	var unit: Dictionary = side.field[index]
	if is_player_field:
		is_disabled = _is_player_input_locked() or not bool(unit.get("can_attack", false))
		if not is_disabled:
			frame.pressed.connect(func(): _on_player_unit_pressed(index))
	else:
		is_disabled = _is_player_input_locked() or selected_attacker == -1
		if not is_disabled:
			frame.pressed.connect(func(): _on_opponent_unit_pressed(index))
	frame.disabled = is_disabled

	# Card border highlights exactly matching the glowing states in screenshots
	var race_border = _card_accent_color(unit)
	frame.mouse_entered.connect(func():
		if frame == null or not is_instance_valid(frame):
			return
		var card_def: Dictionary = main.card_db.get_card(String(unit.get("id", "")))
		var description := _compact_unit_hover_text(unit, card_def, is_player_field)
		_show_hover_popup(frame, String(unit.get("name", "유닛")), description, race_border)
	)
	frame.mouse_exited.connect(func():
		if frame == null or not is_instance_valid(frame):
			return
		_hide_hover_popup()
	)
	var slot_border = race_border
	var slot_border_width = 2
	var slot_bg = Color(0.025, 0.03, 0.04, 0.94)

	if is_player_field and index == selected_attacker:
		slot_border = Color(0.34, 0.72, 1.0, 1.0) # Bright Blue selected glow
		slot_border_width = 3
		slot_bg = Color(0.04, 0.08, 0.14, 0.98)
	elif is_player_field and bool(unit.get("can_attack", false)) and not _is_player_input_locked():
		slot_border = Color(0.2, 0.82, 0.56, 1.0) # Bright Green playable glow
		slot_border_width = 3
		slot_bg = Color(0.02, 0.07, 0.05, 0.96)
	elif not is_player_field and selected_attacker != -1 and not _is_player_input_locked():
		slot_border = Color(1.0, 0.32, 0.26, 1.0) # Bright Red target glow
		slot_border_width = 3
		slot_bg = Color(0.08, 0.03, 0.03, 0.96)

	var normal_style = _make_field_slot_style(slot_bg, slot_border, slot_border_width)
	var hover_style = _make_field_slot_style(slot_bg.lightened(0.08) if not is_disabled else slot_bg, slot_border, slot_border_width + 1)
	var pressed_style = _make_field_slot_style(slot_bg.darkened(0.12), slot_border, slot_border_width)
	var disabled_style = _make_field_slot_style(slot_bg, slot_border.darkened(0.3) if is_disabled and is_player_field else slot_border, slot_border_width)

	frame.add_theme_stylebox_override("normal", normal_style)
	frame.add_theme_stylebox_override("hover", hover_style)
	frame.add_theme_stylebox_override("pressed", pressed_style)
	frame.add_theme_stylebox_override("disabled", disabled_style)

	var slot = VBoxContainer.new()
	slot.custom_minimum_size = content_size
	slot.add_theme_constant_override("separation", 2)
	frame.add_child(slot)

	# 1. Name band at the top of the card
	var name_band: PanelContainer = _make_battle_surface(race_border.darkened(0.42), race_border.lightened(0.08), 1, 5, 3)
	slot.add_child(name_band)
	var name_label: Label = main._make_label(String(unit.get("name", "")), 10 if tight and portrait else (11 if tight else (12 if compact else 13)), Color(1.0, 0.96, 0.82, 1.0))
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	name_band.add_child(name_label)

	# 2. Art container that holds the card illustration, overlaying stat badges at bottom corners
	var art_container = Control.new()
	art_container.custom_minimum_size = art_size
	art_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.add_child(art_container)

	var art: TextureRect = main._make_card_art_rect(unit, art_size)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_container.add_child(art)

	# Overlay Attack badge (bottom-left) and Health badge (bottom-right)
	var attack_badge: PanelContainer = main.ui.make_stat_badge("%d" % int(unit.get("attack", 0)), Color(0.46, 0.16, 0.12, 1.0), true)
	attack_badge.position = Vector2(4, art_size.y - attack_badge.custom_minimum_size.y - 4)
	art_container.add_child(attack_badge)

	var health_badge: PanelContainer = main.ui.make_stat_badge("%d" % int(unit.get("health", 0)), Color(0.1, 0.24, 0.46, 1.0), true)
	health_badge.position = Vector2(art_size.x - health_badge.custom_minimum_size.x - 4, art_size.y - health_badge.custom_minimum_size.y - 4)
	art_container.add_child(health_badge)

	# Overlay prediction badge (top-center) if aiming at this unit
	if not is_player_field and selected_attacker != -1 and not _is_player_input_locked():
		var attacker = _selected_player_attacker()
		var prediction = _predict_unit_attack(attacker, unit, player, opponent)
		var prediction_text = _attack_prediction_text(prediction)
		if not prediction_text.is_empty():
			var prediction_badge: PanelContainer = _make_battle_badge(prediction_text, Color(0.16, 0.05, 0.055, 0.96), Color(1.0, 0.34, 0.24, 1.0), 9)
			prediction_badge.position = Vector2((art_size.x - prediction_badge.custom_minimum_size.x) / 2.0, 4)
			art_container.add_child(prediction_badge)
	if is_player_field and index == selected_attacker:
		var selected_badge: PanelContainer = _make_battle_badge("선택됨", Color(0.03, 0.12, 0.2, 0.96), Color(0.34, 0.72, 1.0, 1.0), 9)
		selected_badge.position = Vector2(max(4.0, art_size.x - selected_badge.custom_minimum_size.x - 4.0), 4)
		art_container.add_child(selected_badge)
	elif is_player_field and bool(unit.get("can_attack", false)) and not _is_player_input_locked():
		var ready_badge: PanelContainer = _make_battle_badge("공격 가능", Color(0.03, 0.18, 0.12, 0.96), Color(0.22, 0.88, 0.58, 1.0), 9)
		ready_badge.position = Vector2(max(4.0, art_size.x - ready_badge.custom_minimum_size.x - 4.0), 4)
		art_container.add_child(ready_badge)
	elif not is_player_field and selected_attacker != -1 and not _is_player_input_locked():
		var target_badge: PanelContainer = _make_battle_badge("여기 공격", Color(0.18, 0.05, 0.05, 0.96), Color(1.0, 0.34, 0.24, 1.0), 9)
		target_badge.position = Vector2(max(4.0, art_size.x - target_badge.custom_minimum_size.x - 4.0), 4)
		art_container.add_child(target_badge)

	return frame

func _render_field(container: HBoxContainer, side: Dictionary, is_player_field: bool) -> void:
	_clear_container(container)
	if is_player_field:
		player_field_slots.clear()
	else:
		opponent_field_slots.clear()
	var visible_slots: int = maxi(3, (side.get("field", []) as Array).size()) if _is_mobile_battle_layout() else MAX_FIELD
	for i in range(min(MAX_FIELD, visible_slots)):
		var slot = _build_field_slot(side, i, is_player_field)
		container.add_child(slot)
		if is_player_field:
			player_field_slots.append(slot)
		else:
			opponent_field_slots.append(slot)


func _render_hand() -> void:
	_clear_card_board_preview()
	var compact = _is_compact_layout()
	var tight = _is_tight_battle_layout()
	var portrait = _is_portrait_battle_layout()
	var mobile = _is_mobile_battle_layout()
	_ensure_hand_visual_slots()
	var recommended_index = _recommended_hand_index()
	_clear_container(hand_box)
	for i in range(player.hand.size()):
		var card: Dictionary = player.hand[i]
		var hand_slot: int = int(card.get("_hand_slot", i))
		var accent = _card_accent_color(card)
		var cost: int = main.relic_service.modify_card_cost(main.current_run, battle_state, card, "player")
		var playable: bool = not _is_player_input_locked() and _can_play_card(player, card, "player")
		var is_recommended = i == recommended_index
		var frame = Button.new()
		frame.text = ""
		frame.focus_mode = Control.FOCUS_NONE
		var wide_tight := _is_wide_tight_battle_layout()
		var frame_size = Vector2(164, 226) if mobile else (Vector2(140, 192) if tight and portrait else (Vector2(150, 160) if wide_tight else (Vector2(132, 170) if tight else (Vector2(184, 212) if not compact else Vector2(156, 186)))))
		var content_size = Vector2(frame_size.x - 12.0, frame_size.y - 12.0)
		frame.custom_minimum_size = frame_size
		var hand_border = Color(0.46, 0.72, 1.0, 1.0) if is_recommended else (accent.lightened(0.12) if playable else accent.darkened(0.08))
		frame.add_theme_stylebox_override("normal", _make_hand_card_style(Color(0.055, 0.075, 0.11, 1.0) if is_recommended else Color(0.05, 0.058, 0.072, 1.0), hand_border, 3 if is_recommended else (2 if playable else 1)))
		frame.add_theme_stylebox_override("hover", _make_hand_card_style(Color(0.07, 0.082, 0.105, 1.0), accent.lightened(0.22), 3))
		frame.add_theme_stylebox_override("pressed", _make_hand_card_style(Color(0.035, 0.042, 0.055, 1.0), accent, 2))
		frame.add_theme_color_override("font_color", Color(1, 1, 1, 0))
		frame.pressed.connect(Callable(self, "_on_hand_card_pressed").bind(i))
		frame.set_meta("hand_slot", hand_slot)
		if not playable:
			frame.modulate = Color(0.46, 0.48, 0.54, 0.82)
		elif recommended_index != -1 and not is_recommended:
			frame.modulate = Color(0.86, 0.9, 0.96, 0.96)
		frame.set_meta("base_modulate", frame.modulate)
		var card_box = VBoxContainer.new()
		card_box.custom_minimum_size = content_size
		card_box.add_theme_constant_override("separation", 3 if tight else 5)
		card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(card_box)
		var header_row = HBoxContainer.new()
		header_row.add_theme_constant_override("separation", 4)
		header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_box.add_child(header_row)
		var cost_badge: PanelContainer = main.ui.make_cost_badge("%d" % cost, true)
		cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header_row.add_child(cost_badge)
		if is_recommended:
			var recommend_badge: PanelContainer = main.ui.make_chip("추천", Color(0.42, 0.28, 0.06, 1.0), Color(1.0, 0.94, 0.62, 1.0), 8 if tight else 10)
			recommend_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			header_row.add_child(recommend_badge)
		elif playable:
			var playable_badge: PanelContainer = main.ui.make_chip("지금 가능", Color(0.08, 0.28, 0.18, 1.0), Color(0.76, 1.0, 0.88, 1.0), 8 if tight else 10)
			playable_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			header_row.add_child(playable_badge)
		var name_band: PanelContainer = main.ui.make_surface_panel(accent.darkened(0.28), accent.lightened(0.12), 1, 5, 3)
		name_band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header_row.add_child(name_band)
		var name_label: Label = main._make_label(String(card.get("name", "")), 12 if mobile else (10 if tight else (15 if not compact else 12)), Color(1.0, 0.96, 0.82, 1.0))
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main.ui.style_card_title(name_label, tight)
		name_band.add_child(name_label)
		var subtype_label: Label = main._make_label("%s · %s" % [String(card.get("race", "")), String(card.get("attr", ""))], 8 if tight else 10, Color(0.96, 0.89, 0.7, 1.0))
		subtype_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		subtype_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		subtype_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		subtype_label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.03, 1.0))
		subtype_label.add_theme_constant_override("outline_size", 2)
		if not wide_tight:
			card_box.add_child(subtype_label)
		var art_size = Vector2(content_size.x - 4.0, 86) if mobile else (Vector2(content_size.x - 4.0, 72 if tight and portrait else (44 if wide_tight else 56)) if tight else (Vector2(164, 88) if not compact else Vector2(140, 68)))
		var art_rect: TextureRect = main._make_card_art_rect(card, art_size)
		art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_box.add_child(art_rect)
		var preview_text = _card_result_preview(card)
		var preview_chip: PanelContainer = main.ui.make_surface_panel(Color(0.19, 0.15, 0.1, 0.96), Color(0.74, 0.6, 0.34, 1.0), 1, 6, 6 if tight else 8)
		preview_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_box.add_child(preview_chip)
		var preview_box := VBoxContainer.new()
		preview_box.add_theme_constant_override("separation", 2)
		preview_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_chip.add_child(preview_box)
		var preview_label: Label = main._make_label(preview_text, 11 if mobile else (10 if tight and portrait else (9 if tight else (12 if not compact else 10))), Color(0.98, 0.95, 0.86, 1.0))
		preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main.ui.style_card_rules(preview_label, tight, false)
		preview_box.add_child(preview_label)
		var rules_text := String(card.get("text", "")).strip_edges()
		if not wide_tight and not rules_text.is_empty() and rules_text != preview_text:
			var rules_label: Label = main._make_label(rules_text, 9 if mobile else (8 if tight else 9), Color(0.9, 0.87, 0.8, 0.82))
			rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rules_label.custom_minimum_size = Vector2(0, 22 if tight else 24)
			rules_label.clip_text = true
			rules_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			main.ui.style_card_rules(rules_label, true, true)
			preview_box.add_child(rules_label)
		if String(card.get("type", "")) == "unit":
			var card_stat_row = HBoxContainer.new()
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
		var action_panel: PanelContainer = main.ui.make_surface_panel(
			Color(0.08, 0.24, 0.16, 0.96) if playable else Color(0.08, 0.1, 0.13, 0.82),
			Color(0.3, 0.9, 0.62, 1.0) if playable else Color(0.3, 0.36, 0.44, 0.8),
			2 if playable else 1,
			5,
			3 if tight else 4
		)
		action_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_box.add_child(action_panel)
		var action_text = "지금 사용 가능" if playable else _unplayable_card_hint(card, cost)
		var action_label: Label = main._make_label(action_text, 12 if mobile else (11 if tight and portrait else (10 if tight else (11 if not compact else 9))), Color(0.86, 1.0, 0.92, 1.0) if playable else Color(0.58, 0.62, 0.68, 1.0))
		action_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		action_label.clip_text = true
		action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		action_label.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.03, 1.0))
		action_label.add_theme_constant_override("outline_size", 2)
		action_panel.add_child(action_label)
		hand_box.add_child(frame)

		frame.pivot_offset = Vector2(frame_size.x / 2.0, frame_size.y)
		frame.mouse_entered.connect(func():
			if frame == null or not is_instance_valid(frame):
				return
			var base_pos: Vector2 = frame.get_meta("base_position", Vector2.ZERO)
			var base_scale: Vector2 = frame.get_meta("base_scale", Vector2.ONE)
			var hover_scale := 1.3
			var hover_lift := -46.0
			if tight and portrait:
				hover_scale = 1.24
				hover_lift = -54.0
			elif tight:
				hover_scale = 1.22
				hover_lift = -38.0
			var h_tween: Tween = frame.create_tween()
			h_tween.tween_property(frame, "position", base_pos + Vector2(0, hover_lift), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			h_tween.parallel().tween_property(frame, "scale", base_scale * hover_scale, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			h_tween.parallel().tween_property(frame, "rotation_degrees", 0.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			h_tween.parallel().tween_property(frame, "modulate", Color(1.08, 1.1, 1.12, 1.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			frame.z_index = 100 + hand_slot
			var current_cost: int = main.relic_service.modify_card_cost(main.current_run, battle_state, card, "player")
			var description := _compact_card_hover_text(card, current_cost, playable)
			_show_card_board_preview(card, playable)
			_show_hover_popup(frame, String(card.get("name", "카드")), description, accent)
		)
		frame.mouse_exited.connect(func():
			if frame == null or not is_instance_valid(frame):
				return
			var base_pos: Vector2 = frame.get_meta("base_position", Vector2.ZERO)
			var base_rotation: float = float(frame.get_meta("base_rotation", 0.0))
			var base_scale: Vector2 = frame.get_meta("base_scale", Vector2.ONE)
			var base_z: int = int(frame.get_meta("base_z_index", i))
			var base_modulate: Color = frame.get_meta("base_modulate", Color(1, 1, 1, 1))
			var h_tween: Tween = frame.create_tween()
			h_tween.tween_property(frame, "position", base_pos, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			h_tween.parallel().tween_property(frame, "scale", base_scale, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			h_tween.parallel().tween_property(frame, "rotation_degrees", base_rotation, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			h_tween.parallel().tween_property(frame, "modulate", base_modulate, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			frame.z_index = base_z
			_clear_card_board_preview()
			_hide_hover_popup()
		)

		var is_new = bool(card.get("_is_new", false))
		if is_new:
			card.erase("_is_new")
			player.hand[i] = card
			frame.scale = Vector2(0.2, 0.2)
			frame.modulate.a = 0.0
			var draw_tween: Tween = frame.create_tween()
			draw_tween.tween_interval(i * 0.08)
			draw_tween.tween_callback(Callable(self, "_play_sfx").bind("draw"))
			draw_tween.tween_property(frame, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			draw_tween.parallel().tween_property(frame, "modulate:a", 1.0, 0.2)
	_layout_hand_cards()

func _hand_signature() -> String:
	_ensure_hand_visual_slots()
	var parts: Array[String] = []
	var recommended_index := _recommended_hand_index()
	for i in range(player.hand.size()):
		var card: Dictionary = player.hand[i]
		var cost: int = main.relic_service.modify_card_cost(main.current_run, battle_state, card, "player")
		var playable: bool = not _is_player_input_locked() and _can_play_card(player, card, "player")
		parts.append("%s:%d:%d:%s:%s" % [
			String(card.get("id", "")),
			int(card.get("_hand_slot", i)),
			cost,
			"1" if playable else "0",
			"1" if i == recommended_index else "0",
		])
	parts.append("sel:%d" % selected_attacker)
	parts.append("turn:%s" % current_player)
	parts.append("lock:%s" % ("1" if _is_player_input_locked() else "0"))
	return "|".join(parts)

func _field_signature(side: Dictionary, is_player_field: bool) -> String:
	var parts: Array[String] = []
	for unit_data in side.get("field", []):
		var unit: Dictionary = unit_data
		parts.append("%s:%d:%d:%s" % [
			String(unit.get("id", "")),
			int(unit.get("attack", 0)),
			int(unit.get("health", 0)),
			"1" if bool(unit.get("can_attack", false)) else "0",
		])
	parts.append("sel:%d" % selected_attacker)
	parts.append("lock:%s" % ("1" if _is_player_input_locked() else "0"))
	parts.append("pf:%s" % ("1" if is_player_field else "0"))
	return "|".join(parts)

func _deck_signature() -> String:
	return "%d|%d|%s" % [player.deck.size(), player.discard_pile.size(), _compact_deck_summary(player.deck, 5)]

func _layout_hand_cards() -> void:
	if hand_box == null or not is_instance_valid(hand_box):
		return
	var count := hand_box.get_child_count()
	if count <= 0:
		return
	var tight := _is_tight_battle_layout()
	var portrait := _is_portrait_battle_layout()
	var wide_tight := _is_wide_tight_battle_layout()
	var mobile := _is_mobile_battle_layout()
	var first_card: Control = hand_box.get_child(0) as Control
	if first_card == null:
		return
	var card_size: Vector2 = first_card.custom_minimum_size
	if mobile:
		var gap := 12.0
		var edge_margin := 10.0
		var max_rank := 0
		for idx in range(count):
			var card: Control = hand_box.get_child(idx) as Control
			if card == null:
				continue
			var slot_index: int = clampi(int(card.get_meta("hand_slot", idx)), 0, MAX_HAND_VISUAL_SLOTS - 1)
			var slot_rank := HAND_SLOT_PREFERENCE.find(slot_index)
			if slot_rank < 0:
				slot_rank = slot_index
			max_rank = maxi(max_rank, slot_rank)
			var target_pos := Vector2(edge_margin + float(slot_rank) * (card_size.x + gap), 8.0)
			card.position = target_pos
			card.rotation_degrees = 0.0
			card.scale = Vector2.ONE
			card.pivot_offset = Vector2(card.custom_minimum_size.x / 2.0, card.custom_minimum_size.y)
			card.z_index = slot_rank
			card.modulate.a = 1.0
			card.set_meta("base_position", target_pos)
			card.set_meta("base_rotation", 0.0)
			card.set_meta("base_scale", Vector2.ONE)
			card.set_meta("base_z_index", card.z_index)
		var visible_width: float = float(main._layout_viewport_size().x) - 36.0
		if hand_scroll != null and is_instance_valid(hand_scroll) and hand_scroll.size.x > 1.0:
			visible_width = hand_scroll.size.x
		var track_width := edge_margin * 2.0 + float(max_rank + 1) * card_size.x + float(max_rank) * gap
		hand_box.custom_minimum_size = Vector2(max(visible_width, track_width), card_size.y + 24.0)
		last_hand_layout_width = hand_box.custom_minimum_size.x
		return
	var available_width: float = hand_box.size.x
	if available_width <= 1.0:
		return
	last_hand_layout_width = available_width
	var max_hand_slots := float(MAX_HAND_VISUAL_SLOTS)
	var fit_spacing: float = (available_width - card_size.x - 16.0) / max(1.0, max_hand_slots - 1.0)
	var spacing: float = clamp(fit_spacing, card_size.x * 0.28, card_size.x * 0.54)
	if wide_tight:
		spacing = clamp(fit_spacing, card_size.x * 0.22, card_size.x * 0.34)
	elif portrait:
		spacing = clamp(fit_spacing, card_size.x * 0.24, card_size.x * 0.38)
	var slot_track_width: float = card_size.x + spacing * float(MAX_HAND_VISUAL_SLOTS - 1)
	var start_x: float = max(8.0, (available_width - slot_track_width) * 0.5)
	var base_y: float = 14.0 if portrait else (2.0 if wide_tight else 10.0)
	var center_slot := 4.5
	var max_angle: float = 5.0 if portrait else (2.0 if wide_tight else 4.0)
	hand_box.custom_minimum_size = Vector2(0, card_size.y + (18.0 if wide_tight else 42.0))
	for idx in range(count):
		var card: Control = hand_box.get_child(idx) as Control
		if card == null:
			continue
		var slot_index: int = clampi(int(card.get_meta("hand_slot", idx)), 0, MAX_HAND_VISUAL_SLOTS - 1)
		var normalized: float = clamp((float(slot_index) - center_slot) / center_slot, -1.0, 1.0)
		var angle: float = normalized * max_angle
		var target_pos: Vector2 = Vector2(start_x + spacing * float(slot_index), base_y)
		card.position = target_pos
		card.rotation_degrees = angle
		card.scale = Vector2.ONE
		card.pivot_offset = Vector2(card.custom_minimum_size.x / 2.0, card.custom_minimum_size.y)
		card.z_index = slot_index
		card.modulate.a = 1.0
		card.set_meta("base_position", target_pos)
		card.set_meta("base_rotation", angle)
		card.set_meta("base_scale", Vector2.ONE)
		card.set_meta("base_z_index", card.z_index)


func _render_battle_deck() -> void:
	if deck_count_label == null or not is_instance_valid(deck_count_label) or deck_list_label == null or not is_instance_valid(deck_list_label):
		return
	deck_count_label.text = "덱 %d장" % player.deck.size()
	deck_list_label.text = _compact_deck_summary(player.deck, 5)

func _compact_deck_summary(deck: Array, max_lines: int) -> String:
	var summary = String(main.deck_service.deck_summary_from_cards(deck)).strip_edges()
	if summary.is_empty():
		return "[color=#7D8490]덱이 비었습니다.[/color]"
	var lines = summary.split("\n", false)
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
		var boss_pattern := _boss_pattern_text()
		if _is_mobile_battle_layout():
			status_label.text = boss_pattern if not boss_pattern.is_empty() else "전투 진행"
		else:
			status_label.text = boss_pattern if not boss_pattern.is_empty() else "현재 목표: 추천 순서대로 전개하고 적 영웅 체력을 0으로 만드세요."
	if opponent_info != null and is_instance_valid(opponent_info):
		opponent_info.text = "적 영웅 HP %d/%d" % [int(opponent.get("health", 0)), int(opponent.get("max_health", 0))]
	if opponent_gauge_info != null and is_instance_valid(opponent_gauge_info):
		opponent_gauge_info.text = _format_opponent_victory_gauge()
	if player_info != null and is_instance_valid(player_info):
		player_info.text = "HP %d/%d" % [int(player.get("health", 0)), int(player.get("max_health", 0))]
	if player_gauge_info != null and is_instance_valid(player_gauge_info):
		player_gauge_info.text = _format_player_victory_gauge()
	if battle_guidance_label != null and is_instance_valid(battle_guidance_label):
		var new_guidance = _current_battle_guidance_text()
		if battle_guidance_label.text != new_guidance:
			battle_guidance_label.text = new_guidance
			var parent_panel = battle_guidance_label.get_parent().get_parent() as PanelContainer
			if parent_panel != null:
				var flash_tween: Tween = main.create_tween()
				flash_tween.tween_property(parent_panel, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.12)
				flash_tween.tween_property(parent_panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.22)
	if battle_focus_label != null and is_instance_valid(battle_focus_label):
		battle_focus_label.text = _current_battle_focus_text()

func _refresh_action_buttons() -> void:
	if detail_toggle_button != null and is_instance_valid(detail_toggle_button):
		detail_toggle_button.text = "상세 닫기" if battle_detail_visible else "상세 정보"
	if race_power_button != null and is_instance_valid(race_power_button):
		var race_meta: Dictionary = main._current_race_meta()
		var race_color: Color = race_meta.get("color", Color(0.42, 0.68, 1.0, 1.0))
		var power_used := bool(battle_state.get("race_power_used", false))
		var can_use_power := _can_use_race_power()
		race_power_button.disabled = not can_use_power
		race_power_button.text = _race_power_button_text()
		if power_used:
			race_power_button.tooltip_text = "이번 전투에서 이미 사용했습니다."
		elif main._current_race_id() == "undead" and player.field.is_empty():
			race_power_button.tooltip_text = "희생할 아군 유닛을 먼저 소환하세요."
		else:
			race_power_button.tooltip_text = "전투당 1회 · %s" % String(race_meta.get("power_text", ""))
		if can_use_power:
			_style_battle_button(race_power_button, race_color.darkened(0.56), race_color, true)
		else:
			_style_battle_button(race_power_button, Color(0.07, 0.08, 0.1, 0.84), Color(0.24, 0.28, 0.34, 0.8), false)
	var only_end_turn = _only_end_turn_remains()
	if recommended_action_button != null:
		recommended_action_button.disabled = _is_player_input_locked()
		recommended_action_button.text = _recommended_action_text()
		var highlighted = not _is_player_input_locked() and not only_end_turn
		if only_end_turn:
			_style_battle_button(recommended_action_button, Color(0.08, 0.1, 0.13, 0.82), Color(0.28, 0.34, 0.42, 0.8), false)
		else:
			_style_battle_button(recommended_action_button, Color(0.12, 0.085, 0.035, 0.98), Color(0.94, 0.72, 0.28, 1.0), highlighted)
	if hero_attack_button != null:
		var can_attack_hero: bool = not _is_player_input_locked() and selected_attacker != -1
		hero_attack_button.disabled = not can_attack_hero
		hero_attack_button.text = ""
		hero_attack_button.tooltip_text = "선택한 유닛으로 적 영웅 공격" if can_attack_hero else "먼저 공격할 내 유닛을 선택하세요"
		if can_attack_hero:
			_style_battle_button(hero_attack_button, Color(0.09, 0.06, 0.08, 0.96), Color(0.72, 0.22, 0.18, 1.0), false)
		else:
			_style_battle_button(hero_attack_button, Color(0.045, 0.06, 0.078, 0.92), Color(0.72, 0.18, 0.16, 1.0), false)
		if opponent_hero_target_badge_label != null and is_instance_valid(opponent_hero_target_badge_label):
			opponent_hero_target_badge_label.text = "영웅 공격 대상"
			if can_attack_hero:
				opponent_hero_target_badge_label.text = "영웅 피해 %d" % _predict_hero_attack_damage(_selected_player_attacker(), player, false)
		if opponent_hero_target_badge != null and is_instance_valid(opponent_hero_target_badge):
			var badge_accent = Color(1.0, 0.32, 0.26, 1.0) if can_attack_hero else Color(0.72, 0.18, 0.16, 1.0)
			opponent_hero_target_badge.add_theme_stylebox_override("panel", _make_modern_style(Color(0.08, 0.1, 0.13, 0.92), badge_accent, 1, 6, 5))
	if end_turn_button != null:
		end_turn_button.disabled = _is_player_input_locked()
		if _player_has_available_action():
			end_turn_button.text = "턴 넘기기"
			_style_battle_button(end_turn_button, Color(0.08, 0.1, 0.13, 0.92), Color(0.24, 0.34, 0.44, 0.9), false)
		else:
			end_turn_button.text = "턴 넘기기"
			_style_battle_button(end_turn_button, Color(0.08, 0.16, 0.24, 0.96), Color(0.22, 0.62, 0.95, 1.0), true)

func _refresh_ui() -> void:
	_hide_hover_popup()
	_refresh_timer_label()
	_refresh_status_labels()
	_refresh_battle_dashboard()
	_refresh_action_buttons()
	if bool(main.get_meta("disable_battle_ui_rerender", false)):
		return
	if opponent_field_box != null:
		var next_opponent_signature: String = _field_signature(opponent, false)
		if next_opponent_signature != opponent_field_signature:
			_render_field(opponent_field_box, opponent, false)
			opponent_field_signature = next_opponent_signature
	if player_field_box != null:
		var next_player_signature: String = _field_signature(player, true)
		if next_player_signature != player_field_signature:
			_render_field(player_field_box, player, true)
			player_field_signature = next_player_signature
	if hand_box != null and not input_locked:
		var next_signature: String = _hand_signature()
		var layout_width: float = hand_box.size.x
		if next_signature != hand_render_signature:
			_render_hand()
			hand_render_signature = next_signature
		elif absf(layout_width - last_hand_layout_width) > 2.0:
			_layout_hand_cards()
	var next_deck_signature: String = _deck_signature()
	if next_deck_signature != deck_render_signature:
		_render_battle_deck()
		deck_render_signature = next_deck_signature

func rebuild_layout() -> void:
	var timer_was_running: bool = turn_timer != null and is_instance_valid(turn_timer) and not turn_timer.is_stopped()
	var timer_left: float = float(turn_timer.time_left) if timer_was_running else 0.0
	var saved_log: String = "" if log_label == null or not is_instance_valid(log_label) else log_label.text
	var show_details: bool = bool(battle_detail_visible)
	main._clear_screen()
	_build_battle_ui()
	battle_detail_visible = show_details
	if detail_panel != null and is_instance_valid(detail_panel):
		detail_panel.visible = show_details
	if log_label != null and is_instance_valid(log_label):
		log_label.text = saved_log
	if timer_was_running and current_player == "player" and timer_left > 0.0:
		turn_timer.start(timer_left)
	else:
		turn_timer.stop()
	_init_status_trackers()
	_refresh_ui()

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
	player = _new_side(main._current_race_hero_name(), main.card_db.build_deck_from_ids(main.current_run.get("deck_ids", [])), int(main.current_run.get("hp", 50)), int(main.current_run.get("max_hp", 50)))
	opponent = _new_side(String(enemy.get("name", "적")), main.card_db.build_deck_from_ids(enemy.get("deck_ids", [])), int(enemy.get("base_hp", 20)), int(enemy.get("base_hp", 20)))
	_draw_cards(player, START_HAND)
	_draw_cards(opponent, START_HAND)
	_reset_battle_state()
	_build_battle_ui()
	main.relic_service.on_battle_start(main.current_run, player, battle_state)
	_spawn_build_token()
	player.health = int(main.current_run.get("hp", player.health))
	_add_log("%s 전투 시작. 적 영웅 체력을 0으로 만드세요." % _node_type_name(String(main.run_store.current_node(main.current_run).get("type", "battle"))))
	_init_status_trackers()
	_refresh_ui()
	_store_battle_snapshot()
	await _show_turn_banner("전투 시작!", true)
	await _start_turn(player, true)


func _add_log(message: String) -> void:
	if log_label == null:
		return
	var current_lines = log_label.text.split("\n", false)
	var output: Array[String] = ["[color=#F2C96B][b]•[/b][/color] %s" % _escape_rich_text(message)]
	var max_lines = 18
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


func _play_sfx(sfx_name: String) -> void:
	var root = Engine.get_main_loop().current_scene
	if root and root.get("audio_manager") != null:
		root.audio_manager.play_sound(sfx_name)

func _apply_damage_juice(old_p_hp: int, old_o_hp: int) -> void:
	if int(player.health) < old_p_hp:
		_flash_and_shake(player_info, Color(1.0, 0.2, 0.2, 1.0))
		_flash_and_shake(player_hero_hp_label, Color(1.0, 0.2, 0.2, 1.0))
		_play_sfx("hit")
	elif int(player.health) > old_p_hp:
		_flash_and_shake(player_info, Color(0.2, 1.0, 0.2, 1.0))
		_flash_and_shake(player_hero_hp_label, Color(0.2, 1.0, 0.2, 1.0))
		_play_sfx("heal")

	if int(opponent.health) < old_o_hp:
		_flash_and_shake(opponent_info, Color(1.0, 0.2, 0.2, 1.0))
		_flash_and_shake(enemy_hero_hp_label, Color(1.0, 0.2, 0.2, 1.0))
		_play_sfx("hit")
	elif int(opponent.health) > old_o_hp:
		_flash_and_shake(opponent_info, Color(0.2, 1.0, 0.2, 1.0))
		_flash_and_shake(enemy_hero_hp_label, Color(0.2, 1.0, 0.2, 1.0))
		_play_sfx("heal")

func _flash_and_shake(node: Control, color: Color) -> void:
	if not is_instance_valid(node): return
	var tween = node.create_tween()
	var orig_pos = node.position
	var orig_modulate = node.modulate
	node.modulate = color
	tween.tween_property(node, "modulate", orig_modulate, 0.3)
	for i in range(4):
		tween.parallel().tween_property(node, "position", orig_pos + Vector2(randf_range(-8, 8), randf_range(-8, 8)), 0.05)
	tween.tween_property(node, "position", orig_pos, 0.05)
