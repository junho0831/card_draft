extends RefCounted

const MAX_MANA := 10
const MAX_FIELD := 5
const START_HAND := 4
const TURN_TIME_SECONDS := 60.0

var main
var root_box: VBoxContainer
var status_label: Label
var opponent_info: Label
var opponent_gauge_info: Label
var opponent_field_box: HBoxContainer
var hero_attack_button: Button
var player_field_box: HBoxContainer
var player_info: Label
var player_gauge_info: Label
var hand_box: HBoxContainer
var deck_count_label: Label
var turn_overlay: Panel
var turn_timer: Timer
var turn_timer_label: Label
var deck_list_label: RichTextLabel
var log_label: RichTextLabel
var end_turn_button: Button
var player := {}
var opponent := {}
var current_player := "player"
var selected_attacker := -1
var game_over := false
var battle_finished := false
var input_locked := false
var battle_state := {}
var battle_tier := "normal"

func _init(main_ref) -> void:
	main = main_ref
	root_box = main.root_box

func _on_turn_timeout() -> void:
	if main.active_screen == "battle" and current_player == "player" and not game_over and not input_locked:
		_add_log("시간 초과! 턴이 강제로 종료됩니다.")
		_on_end_turn_pressed()

func _save_run() -> void:
	main._save_run()

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

func _format_side_status(side: Dictionary, fallback_name: String) -> String:
	return "%s  HP %d/%d" % [String(side.get("name", fallback_name)), int(side.get("health", 0)), int(side.get("max_health", 0))]

func _format_side_resources(side: Dictionary) -> String:
	return "마나 %d/%d | 손패 %d | 덱 %d" % [int(side.get("mana", 0)), int(side.get("max_mana", 0)), (side.get("hand", []) as Array).size(), (side.get("deck", []) as Array).size()]

func _is_fast_ai_enabled() -> bool:
	return bool(main.player_profile["settings"]["fast_ai"])

func _is_compact_layout() -> bool:
	return main._is_compact_layout()

func _battle_reward_choices() -> Array[String]:
	return _roll_high_cost_cards(3) if battle_tier == "boss" else _roll_card_choices(3)

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

func _finish_opponent_defeat() -> void:
	game_over = true
	battle_finished = true
	main.current_run["hp"] = int(player.health)

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
		"main.relic_service": main.relic_service,
		"run_data": main.current_run,
		"max_health": int(main.current_run.get("max_hp", 50)),
		"player_state": player,
		"first_card_discount_available": false,
		"mana_crystal_bonus": false,
		"cards_played_this_turn": 0,
		"necromancer_ring_used": false,
		"second_chance_used": false,
	}

func _prepare_battle(tier: String) -> void:
	var enemy: Dictionary = main.enemy_service.pick_enemy(int(main.current_run.get("act", 1)), tier)
	if enemy.is_empty():
		_show_message("적 데이터를 준비하지 못했습니다. 런을 다시 시작해주세요.", "_show_main_menu")
		return
	main.current_run["active_enemy"] = enemy
	_save_run()
	start_battle()


func _new_side(display_name: String, deck: Array, hp: int, max_hp: int) -> Dictionary:
	deck.shuffle()
	return {
		"name": display_name,
		"health": hp,
		"max_health": max_hp,
		"mana": 0,
		"max_mana": 0,
		"deck": deck,
		"hand": [],
		"field": [],
		"corpse_explosion_stacks": 0,
		"curses": 0,
		"ritual_stacks": 0,
	}


func _build_battle_ui() -> void:
	main._add_title("CARD DRAFT")
	var compact := _is_compact_layout()
	var status_row = HBoxContainer.new()
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_child(status_row)
	
	status_label = main._make_label("", 18 if not compact else 15, Color(0.82, 0.9, 1.0, 1.0))
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_row.add_child(status_label)
	
	turn_timer_label = main._make_label("", 18 if not compact else 15, Color(1.0, 0.4, 0.4, 1.0))
	turn_timer_label.custom_minimum_size = Vector2(120 if not compact else 84, 0)
	turn_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_row.add_child(turn_timer_label)

	var content_row := HBoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 14 if not compact else 8)
	root_box.add_child(content_row)

	var board_panel = main._make_panel_container(Color(0.12, 0.135, 0.16, 1.0))
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(board_panel)

	var board_box := VBoxContainer.new()
	board_box.add_theme_constant_override("separation", 10 if not compact else 6)
	board_panel.add_child(board_box)

	opponent_info = main._make_label("", 16 if not compact else 13, Color(1.0, 0.78, 0.78, 1.0))
	board_box.add_child(opponent_info)
	opponent_gauge_info = main._make_label("", 14 if not compact else 12, Color(0.8, 0.6, 1.0, 1.0))
	board_box.add_child(opponent_gauge_info)
	var opponent_field_scroll := ScrollContainer.new()
	opponent_field_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	opponent_field_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	opponent_field_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opponent_field_scroll.custom_minimum_size = Vector2(0, 124 if not compact else 98)
	board_box.add_child(opponent_field_scroll)
	opponent_field_box = HBoxContainer.new()
	opponent_field_box.alignment = BoxContainer.ALIGNMENT_CENTER
	opponent_field_box.custom_minimum_size = Vector2(720 if not compact else 420, 124 if not compact else 98)
	opponent_field_scroll.add_child(opponent_field_box)
	board_box.add_child(HSeparator.new())

	var player_field_scroll := ScrollContainer.new()
	player_field_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	player_field_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	player_field_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_field_scroll.custom_minimum_size = Vector2(0, 124 if not compact else 98)
	board_box.add_child(player_field_scroll)
	player_field_box = HBoxContainer.new()
	player_field_box.alignment = BoxContainer.ALIGNMENT_CENTER
	player_field_box.custom_minimum_size = Vector2(720 if not compact else 420, 124 if not compact else 98)
	player_field_scroll.add_child(player_field_box)
	player_info = main._make_label("", 16 if not compact else 13, Color(0.78, 0.9, 1.0, 1.0))
	board_box.add_child(player_info)
	player_gauge_info = main._make_label("", 14 if not compact else 12, Color(0.6, 1.0, 0.6, 1.0))
	board_box.add_child(player_gauge_info)
	board_box.add_child(main._make_label("내 손패", 16 if not compact else 13, Color(0.96, 0.88, 0.55, 1.0)))

	var hand_scroll := ScrollContainer.new()
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_scroll.custom_minimum_size = Vector2(0, 166 if not compact else 142)
	board_box.add_child(hand_scroll)
	hand_box = HBoxContainer.new()
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_box.custom_minimum_size = Vector2(760 if not compact else 420, 166 if not compact else 142)
	hand_scroll.add_child(hand_box)

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
	main.add_child(turn_timer)

	var side_panel = main._make_panel_container(Color(0.105, 0.115, 0.135, 1.0))
	side_panel.custom_minimum_size = Vector2(330 if not compact else 220, 0)
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(side_panel)
	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 10 if not compact else 6)
	side_panel.add_child(side_box)

	side_box.add_child(main._make_label("내 덱", 20 if not compact else 15, Color(0.96, 0.88, 0.55, 1.0)))
	deck_count_label = main._make_label("", 14 if not compact else 12, Color(0.82, 0.9, 1.0, 1.0))
	side_box.add_child(deck_count_label)

	var deck_scroll := ScrollContainer.new()
	deck_scroll.custom_minimum_size = Vector2(0, 230 if not compact else 110)
	deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_box.add_child(deck_scroll)

	deck_list_label = RichTextLabel.new()
	deck_list_label.custom_minimum_size = Vector2(290 if not compact else 180, 220 if not compact else 96)
	deck_list_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_list_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_list_label.bbcode_enabled = false
	deck_list_label.fit_content = false
	deck_list_label.scroll_active = false
	deck_list_label.add_theme_color_override("default_color", Color(0.9, 0.92, 0.95, 1.0))
	deck_scroll.add_child(deck_list_label)

	side_box.add_child(main._make_label("게임 로그", 20 if not compact else 15, Color(0.96, 0.88, 0.55, 1.0)))
	log_label = RichTextLabel.new()
	log_label.custom_minimum_size = Vector2(0, 140 if not compact else 72)
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.bbcode_enabled = false
	log_label.fit_content = false
	log_label.add_theme_color_override("default_color", Color(0.9, 0.92, 0.95, 1.0))
	side_box.add_child(log_label)

	side_box.add_child(HSeparator.new())

	var action_row := VBoxContainer.new() if compact else HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 10 if not compact else 6)
	side_box.add_child(action_row)

	hero_attack_button = Button.new()
	hero_attack_button.text = "상대 영웅 공격"
	hero_attack_button.custom_minimum_size = Vector2(140, 48) if not compact else Vector2(0, 40)
	main.ui.style_button(hero_attack_button, Color(0.5, 0.13, 0.13, 1.0))
	hero_attack_button.pressed.connect(Callable(self, "_attack_opponent_hero"))
	action_row.add_child(hero_attack_button)

	end_turn_button = Button.new()
	end_turn_button.text = "턴 종료"
	end_turn_button.custom_minimum_size = Vector2(140, 48) if not compact else Vector2(0, 40)
	main.ui.style_button(end_turn_button, Color(0.18, 0.34, 0.48, 1.0))
	end_turn_button.pressed.connect(Callable(self, "_on_end_turn_pressed"))
	action_row.add_child(end_turn_button)


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
	_draw_cards(side, 1)
	if is_player_turn:
		battle_state["cards_played_this_turn"] = 0
		main.relic_service.on_turn_start(main.current_run, battle_state, player)
	_add_log("%s 턴 시작: 마나 %d/%d" % [side.name, side.mana, side.max_mana])


func _show_turn_banner(text: String, is_player: bool) -> void:
	if turn_overlay and is_instance_valid(turn_overlay):
		var target_color = Color(0.2, 0.5, 1.0, 0.25) if is_player else Color(0.9, 0.2, 0.2, 0.25)
		var style: StyleBoxFlat = turn_overlay.get_theme_stylebox("panel")
		var bg_tween = main.create_tween()
		bg_tween.tween_property(style, "border_color", target_color, 0.6)

	var banner := Label.new()
	banner.text = text
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.add_theme_font_size_override("font_size", 96)
	var color = Color(0.6, 0.8, 1.0) if is_player else Color(1.0, 0.5, 0.5)
	banner.add_theme_color_override("font_color", color)
	banner.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1))
	banner.add_theme_constant_override("outline_size", 20)
	
	main.add_child(banner)
	
	banner.pivot_offset = main.get_viewport_rect().size / 2.0
	banner.scale = Vector2(0.2, 0.2)
	banner.modulate.a = 0.0
	
	var tween = main.create_tween()
	tween.tween_property(banner, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(banner, "modulate:a", 1.0, 0.2)
	tween.tween_interval(0.5)
	tween.tween_property(banner, "modulate:a", 0.0, 0.3)
	tween.tween_callback(banner.queue_free)
	await tween.finished


func _draw_cards(side: Dictionary, count: int) -> void:
	for i in range(count):
		if side.deck.is_empty():
			side.health -= 1
			_add_log("%s 덱 고갈: 피해 1" % side.name)
			continue
		side.hand.append(side.deck.pop_back())


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
	main.relic_service.consume_card_discount(battle_state)
	battle_state["cards_played_this_turn"] = int(battle_state.get("cards_played_this_turn", 0)) + 1
	main.battle_effects.play_card(player, opponent, card, _battle_effect_context())
	main.relic_service.on_card_played(main.current_run, battle_state, player)
	_check_game_over()
	_refresh_ui()
	_check_no_actions_loss()


func _battle_effect_context() -> Dictionary:
	return {
		"draw_cards": Callable(self, "_draw_cards"),
		"log": Callable(self, "_add_log"),
		"cleanup_dead_units": Callable(self, "_cleanup_dead_units"),
		"calculate_damage": Callable(self, "_calculate_damage"),
		"main.relic_service": main.relic_service,
		"run_data": main.current_run,
		"max_health": int(main.current_run.get("max_hp", 50)),
	}


func _calculate_damage(card_or_unit: Dictionary, is_spell: bool, owner_state: Dictionary, base_damage: int) -> int:
	return base_damage + main.relic_service.damage_bonus(main.current_run, card_or_unit, is_spell, owner_state)


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


func _on_opponent_unit_pressed(index: int) -> void:
	if input_locked or game_over or current_player != "player" or selected_attacker == -1:
		return
	if index < 0 or index >= opponent.field.size():
		return
	await _combat(player, opponent, selected_attacker, index)
	selected_attacker = -1
	_check_game_over()
	_refresh_ui()
	_check_no_actions_loss()


func _attack_opponent_hero() -> void:
	if input_locked or game_over or current_player != "player" or selected_attacker == -1:
		return
	var attacker: Dictionary = player.field[selected_attacker]
	var damage := _calculate_damage(attacker, false, player, int(attacker.attack))
	input_locked = true
	_refresh_ui()
	await _play_hero_cutscene(attacker, opponent.name, damage)
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
	
	if _is_battle_cutscene_enabled():
		await main.battle_cutscene.play_unit_battle(attacker, defender, attack_damage, defense_damage)
	
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




func _play_hero_cutscene(attacker: Dictionary, defender_name: String, damage: int) -> void:
	if _is_battle_cutscene_enabled():
		await main.battle_cutscene.play_hero_attack(attacker, defender_name, damage)


func _cleanup_dead_units(side_a: Dictionary, side_b: Dictionary) -> void:
	_cleanup_side_dead(side_a, side_b)
	_cleanup_side_dead(side_b, side_a)


func _cleanup_side_dead(owner: Dictionary, enemy: Dictionary) -> void:
	for i in range(owner.field.size() - 1, -1, -1):
		if int(owner.field[i].health) <= 0:
			var dead_unit: Dictionary = owner.field[i]
			owner.field.remove_at(i)
			main.battle_effects.on_unit_died(dead_unit, owner, enemy, _battle_effect_context())
			if owner == player:
				main.relic_service.on_ally_unit_died(main.current_run, battle_state, dead_unit)
			_add_log("%s 사망" % String(dead_unit.get("name", "")))


func _on_end_turn_pressed() -> void:
	if input_locked or game_over or current_player != "player":
		return
	input_locked = true
	current_player = "opponent"
	selected_attacker = -1
	await _start_turn(opponent, false)
	_refresh_ui()
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
		current_player = "player"
		await _start_turn(player, true)
		input_locked = false
	_refresh_ui()

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
				main.battle_effects.play_card(opponent, player, card, _battle_effect_context())
				played = true
				if not _is_fast_ai_enabled():
					await main.get_tree().create_timer(0.2).timeout
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
	await _play_hero_cutscene(unit, player.name, damage)
	damage = main.relic_service.mitigate_hero_damage(main.current_run, battle_state, damage, true)
	player.health -= damage
	if damage > 0:
		main.relic_service.on_hero_hp_lost(main.current_run, battle_state, player, damage)
	unit.can_attack = false
	_add_log("%s가 내 영웅에게 피해 %d" % [unit.name, damage])
	input_locked = false


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
		_finish_opponent_defeat()
		await _finish_battle_victory()


func _finish_battle_victory() -> void:
	main.current_run["active_enemy"] = {}
	main.current_run["pending_card_reward"] = _apply_battle_victory_rewards()
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
	button.text = "%s %s/%s" % [unit.name, unit.attack, unit.health]
	if is_player_field:
		button.disabled = _is_player_input_locked() or not bool(unit.can_attack)
		button.pressed.connect(Callable(self, "_on_player_unit_pressed").bind(index))
		if index == selected_attacker:
			button.text = "[선택] " + button.text
	else:
		button.disabled = _is_player_input_locked() or selected_attacker == -1
		button.pressed.connect(Callable(self, "_on_opponent_unit_pressed").bind(index))

func _build_field_slot(side: Dictionary, index: int, is_player_field: bool) -> Control:
	var compact := _is_compact_layout()
	var frame = main._make_card_frame()
	frame.custom_minimum_size = Vector2(138 if not compact else 110, 122 if not compact else 96)
	var slot := VBoxContainer.new()
	slot.custom_minimum_size = Vector2(132 if not compact else 104, 116 if not compact else 90)
	slot.add_theme_constant_override("separation", 3)
	frame.add_child(slot)
	var button := Button.new()
	button.custom_minimum_size = Vector2(130 if not compact else 102, 42 if not compact else 34)
	main.ui.style_button(button, Color(0.2, 0.23, 0.28, 1.0))
	if index < side.field.size():
		var unit: Dictionary = side.field[index]
		slot.add_child(main._make_art_rect(int(unit.get("art", 0)), Vector2(130, 68) if not compact else Vector2(102, 50)))
		_configure_field_button(button, unit, index, is_player_field)
	else:
		var placeholder := ColorRect.new()
		placeholder.color = Color(0.09, 0.1, 0.12, 1.0)
		placeholder.custom_minimum_size = Vector2(130, 68) if not compact else Vector2(102, 50)
		slot.add_child(placeholder)
		button.text = "빈 슬롯"
		button.disabled = true
	slot.add_child(button)
	return frame

func _render_field(container: HBoxContainer, side: Dictionary, is_player_field: bool) -> void:
	_clear_container(container)
	for i in range(MAX_FIELD):
		container.add_child(_build_field_slot(side, i, is_player_field))


func _render_hand() -> void:
	var compact := _is_compact_layout()
	_clear_container(hand_box)
	for i in range(player.hand.size()):
		var card: Dictionary = player.hand[i]
		var frame = main._make_card_frame()
		frame.custom_minimum_size = Vector2(151, 160) if not compact else Vector2(124, 136)
		var card_box := VBoxContainer.new()
		card_box.custom_minimum_size = Vector2(145, 154) if not compact else Vector2(118, 130)
		card_box.add_theme_constant_override("separation", 4)
		frame.add_child(card_box)
		card_box.add_child(main._make_art_rect(int(card.get("art", 0)), Vector2(145, 82) if not compact else Vector2(118, 62)))
		var button := Button.new()
		var cost: int = main.relic_service.modify_card_cost(main.current_run, battle_state, card, "player")
		button.custom_minimum_size = Vector2(145, 68) if not compact else Vector2(118, 60)
		button.text = "%s\n비용 %d | %s\n%s" % [String(card.get("name", "")), cost, main.deck_service.type_name(String(card.get("type", ""))), String(card.get("text", ""))]
		button.disabled = _is_player_input_locked() or not _can_play_card(player, card, "player")
		main.ui.style_button(button, Color(0.18, 0.24, 0.3, 1.0))
		button.pressed.connect(Callable(self, "_on_hand_card_pressed").bind(i))
		card_box.add_child(button)
		hand_box.add_child(frame)


func _render_battle_deck() -> void:
	if deck_count_label == null or deck_list_label == null:
		return
	deck_count_label.text = "남은 카드 %d장" % player.deck.size()
	deck_list_label.text = main.deck_service.deck_summary_from_cards(player.deck)

func _refresh_timer_label() -> void:
	if turn_timer_label == null:
		return
	if current_player == "player" and turn_timer != null and not turn_timer.is_stopped():
		turn_timer_label.text = "%d초" % int(ceili(turn_timer.time_left))
	else:
		turn_timer_label.text = ""

func _refresh_status_labels() -> void:
	if status_label != null:
		status_label.text = "전투 중"
	if opponent_info != null:
		opponent_info.text = _format_side_status(opponent, "적")
	if opponent_gauge_info != null:
		opponent_gauge_info.text = _format_side_resources(opponent)
	if player_info != null:
		player_info.text = _format_side_status(player, "플레이어")
	if player_gauge_info != null:
		player_gauge_info.text = _format_side_resources(player)

func _refresh_action_buttons() -> void:
	if hero_attack_button != null:
		hero_attack_button.disabled = _is_player_input_locked() or selected_attacker == -1
	if end_turn_button != null:
		end_turn_button.disabled = _is_player_input_locked()

func _refresh_ui() -> void:
	_refresh_timer_label()
	_refresh_status_labels()
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
	battle_tier = String(enemy.get("tier", "normal"))
	player = _new_side("플레이어", main.card_db.build_deck_from_ids(main.current_run.get("deck_ids", [])), int(main.current_run.get("hp", 50)), int(main.current_run.get("max_hp", 50)))
	opponent = _new_side(String(enemy.get("name", "적")), main.card_db.build_deck_from_ids(enemy.get("deck_ids", [])), int(enemy.get("base_hp", 20)), int(enemy.get("base_hp", 20)))
	_draw_cards(player, START_HAND)
	_draw_cards(opponent, START_HAND)
	_reset_battle_state()
	_build_battle_ui()
	main.relic_service.on_battle_start(main.current_run, player, battle_state)
	player.health = int(main.current_run.get("hp", player.health))
	_add_log("%s 전투 시작. 적 영웅 체력을 0으로 만드세요." % _node_type_name(String(main.run_store.current_node(main.current_run).get("type", "battle"))))
	_refresh_ui()
	await _show_turn_banner("전투 시작!", true)
	await _start_turn(player, true)


func _add_log(message: String) -> void:
	if log_label == null:
		return
	log_label.text = message + "\n" + log_label.text

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
