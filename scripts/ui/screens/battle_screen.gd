extends RefCounted

var main
var root_box: VBoxContainer
var status_label: Label
var opponent_info: Label
var opponent_field_box: HBoxContainer
var hero_attack_button: Button
var player_field_box: HBoxContainer
var player_info: Label
var hand_box: HBoxContainer
var deck_count_label: Label
var turn_overlay: Panel
var turn_timer: Timer
var turn_timer_label: Label
var deck_list_label: RichTextLabel
var end_turn_button: Button
var last_player_health: int = -1
var last_opponent_health: int = -1
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
	}


func _build_battle_ui() -> void:
	main._add_title("CARD DRAFT")
	var status_row = HBoxContainer.new()
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_child(status_row)
	
	status_label = main._make_label("", 18, Color(0.82, 0.9, 1.0, 1.0))
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_row.add_child(status_label)
	
	turn_timer_label = main._make_label("", 18, Color(1.0, 0.4, 0.4, 1.0))
	turn_timer_label.custom_minimum_size = Vector2(120, 0)
	turn_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_row.add_child(turn_timer_label)

	var content_row := HBoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 14)
	root_box.add_child(content_row)

	var board_panel := main._make_panel_container(Color(0.12, 0.135, 0.16, 1.0))
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(board_panel)

	var board_box := VBoxContainer.new()
	board_box.add_theme_constant_override("separation", 10)
	board_panel.add_child(board_box)

	opponent_info = main._make_label("", 16, Color(1.0, 0.78, 0.78, 1.0))
	board_box.add_child(opponent_info)
	opponent_field_box = HBoxContainer.new()
	opponent_field_box.alignment = BoxContainer.ALIGNMENT_CENTER
	opponent_field_box.custom_minimum_size = Vector2(0, 124)
	board_box.add_child(opponent_field_box)
	board_box.add_child(HSeparator.new())

	player_field_box = HBoxContainer.new()
	player_field_box.alignment = BoxContainer.ALIGNMENT_CENTER
	player_field_box.custom_minimum_size = Vector2(0, 124)
	board_box.add_child(player_field_box)
	player_info = main._make_label("", 16, Color(0.78, 0.9, 1.0, 1.0))
	board_box.add_child(player_info)
	board_box.add_child(main._make_label("내 손패", 16, Color(0.96, 0.88, 0.55, 1.0)))

	hand_box = HBoxContainer.new()
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_box.custom_minimum_size = Vector2(0, 166)
	board_box.add_child(hand_box)

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

	var side_panel := main._make_panel_container(Color(0.105, 0.115, 0.135, 1.0))
	side_panel.custom_minimum_size = Vector2(330, 0)
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(side_panel)
	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 10)
	side_panel.add_child(side_box)

	side_box.add_child(main._make_label("내 덱", 20, Color(0.96, 0.88, 0.55, 1.0)))
	deck_count_label = main._make_label("", 14, Color(0.82, 0.9, 1.0, 1.0))
	side_box.add_child(deck_count_label)

	var deck_scroll := ScrollContainer.new()
	deck_scroll.custom_minimum_size = Vector2(0, 230)
	deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_box.add_child(deck_scroll)

	deck_list_label = RichTextLabel.new()
	deck_list_label.custom_minimum_size = Vector2(290, 220)
	deck_list_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_list_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_list_label.bbcode_enabled = false
	deck_list_label.fit_content = false
	deck_list_label.scroll_active = false
	deck_list_label.add_theme_color_override("default_color", Color(0.9, 0.92, 0.95, 1.0))
	deck_scroll.add_child(deck_list_label)

	side_box.add_child(main._make_label("게임 로그", 20, Color(0.96, 0.88, 0.55, 1.0)))
	log_label = RichTextLabel.new()
	log_label.custom_minimum_size = Vector2(0, 140)
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.bbcode_enabled = false
	log_label.fit_content = false
	log_label.add_theme_color_override("default_color", Color(0.9, 0.92, 0.95, 1.0))
	side_box.add_child(log_label)

	side_box.add_child(HSeparator.new())

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 10)
	side_box.add_child(action_row)

	hero_attack_button = Button.new()
	hero_attack_button.text = "상대 영웅 공격"
	hero_attack_button.custom_minimum_size = Vector2(140, 48)
	main.ui.style_button(hero_attack_button, Color(0.5, 0.13, 0.13, 1.0))
	hero_attack_button.pressed.connect(Callable(self, "_attack_opponent_hero"))
	action_row.add_child(hero_attack_button)

	end_turn_button = Button.new()
	end_turn_button.text = "턴 종료"
	end_turn_button.custom_minimum_size = Vector2(140, 48)
	main.ui.style_button(end_turn_button, Color(0.18, 0.34, 0.48, 1.0))
	end_turn_button.pressed.connect(Callable(self, "_on_end_turn_pressed"))
	action_row.add_child(end_turn_button)


func _start_turn(side: Dictionary, is_player_turn: bool) -> void:
	if is_player_turn:
		turn_timer.start(60.0)
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
		var bg_tween = create_tween()
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
	
	add_child(banner)
	
	banner.pivot_offset = main.get_viewport_rect().size / 2.0
	banner.scale = Vector2(0.2, 0.2)
	banner.modulate.a = 0.0
	
	var tween = create_tween()
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
	if cost > int(player.mana):
		_add_log("마나가 부족합니다.")
		return
	if String(card.get("type", "")) == "unit" and player.field.size() >= MAX_FIELD:
		_add_log("필드가 가득 찼습니다.")
		return
	if String(card.get("type", "")) == "equipment" and player.field.is_empty():
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
		"log": Callable(main, "_add_log"),
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
	
	if bool(main.player_profile["settings"]["main.battle_cutscene"]):
		await main.battle_cutscene.play_unit_battle(attacker, defender, attack_damage, defense_damage)
	
	defender.health -= attack_damage
	attacker.health -= defense_damage
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
		var cost = main.relic_service.modify_card_cost(main.current_run, battle_state, card, "player")
		if cost <= int(player.mana):
			if String(card.get("type", "")) == "unit" and player.field.size() >= MAX_FIELD:
				continue
			if String(card.get("type", "")) == "equipment" and player.field.is_empty():
				continue
			has_playable_card = true
			break
	if not has_attacker and not has_playable_card:
		_add_log("더 이상 할 수 있는 행동이 없어 패배합니다.")
		player.health = 0
		_check_game_over()




func _play_hero_cutscene(attacker: Dictionary, defender_name: String, damage: int) -> void:
	if bool(main.player_profile["settings"]["main.battle_cutscene"]):
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
	if bool(main.player_profile["settings"]["fast_ai"]):
		ai_wait = 0.08
	await main.get_tree().create_timer(ai_wait).timeout
	await _run_ai_turn()


func _run_ai_turn() -> void:
	if game_over:
		return
	var played := true
	while played:
		played = false
		for i in range(opponent.hand.size()):
			var card: Dictionary = opponent.hand[i]
			if int(card.get("cost", 0)) <= int(opponent.mana):
				if String(card.get("type", "")) == "unit" and opponent.field.size() >= MAX_FIELD:
					continue
				if String(card.get("type", "")) == "equipment" and opponent.field.is_empty():
					continue
				opponent.mana -= int(card.cost)
				opponent.hand.remove_at(i)
				main.battle_effects.play_card(opponent, player, card, _battle_effect_context())
				played = true
				if not bool(main.player_profile["settings"]["fast_ai"]):
					await main.get_tree().create_timer(0.2).timeout
				break

	var i := 0
	while i < opponent.field.size():
		if not bool(opponent.field[i].can_attack):
			i += 1
			continue
		if not player.field.is_empty():
			await _combat(opponent, player, i, 0)
		elif i < opponent.field.size():
			var unit: Dictionary = opponent.field[i]
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
		_check_game_over()
		if game_over:
			break
		if i < opponent.field.size() and not bool(opponent.field[i].can_attack):
			i += 1

	if not game_over:
		current_player = "player"
		await _start_turn(player, true)
		input_locked = false
	_refresh_ui()


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
		game_over = true
		battle_finished = true
		main.current_run["hp"] = 0
		main.current_run["result"] = "loss"
		_finish_run(false)
	elif int(opponent.health) <= 0:
		game_over = true
		battle_finished = true
		main.current_run["hp"] = int(player.health)
		await _finish_battle_victory()


func _finish_battle_victory() -> void:
	main.current_run["active_enemy"] = {}
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
	main.current_run["pending_card_reward"] = {
		"choices": _roll_high_cost_cards(3) if battle_tier == "boss" else _roll_card_choices(3),
		"bonus_relic": bonus_relic,
		"battle_tier": battle_tier,
		"gold_reward": gold_reward,
	}
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
	
	var tween = create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 60, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_callback(lbl.queue_free)


func _flash_label(label: Label, delta: int, original_color: Color) -> void:
	var color := Color(1, 0.2, 0.2) if delta < 0 else Color(0.2, 1, 0.2)
	label.add_theme_color_override("font_color", color)
	var tween = create_tween()
	tween.tween_property(label, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.3)
	tween.tween_callback(func(): label.add_theme_color_override("font_color", original_color))


func _render_field(container: HBoxContainer, side: Dictionary, is_player_field: bool) -> void:
	for child in container.get_children():
		child.queue_free()
	for i in range(MAX_FIELD):
		var frame := main._make_card_frame()
		frame.custom_minimum_size = Vector2(138, 122)
		var slot := VBoxContainer.new()
		slot.custom_minimum_size = Vector2(132, 116)
		slot.add_theme_constant_override("separation", 3)
		frame.add_child(slot)
		var button := Button.new()
		button.custom_minimum_size = Vector2(130, 42)
		main.ui.style_button(button, Color(0.2, 0.23, 0.28, 1.0))
		if i < side.field.size():
			var unit: Dictionary = side.field[i]
			slot.add_child(main._make_art_rect(int(unit.get("art", 0)), Vector2(130, 68)))
			button.text = "%s %s/%s" % [unit.name, unit.attack, unit.health]
			if is_player_field:
				button.disabled = input_locked or game_over or current_player != "player" or not bool(unit.can_attack)
				button.pressed.connect(Callable(self, "_on_player_unit_pressed").bind(i))
				if i == selected_attacker:
					button.text = "[선택] " + button.text
			else:
				button.disabled = input_locked or game_over or current_player != "player" or selected_attacker == -1
				button.pressed.connect(Callable(self, "_on_opponent_unit_pressed").bind(i))
		else:
			var placeholder := ColorRect.new()
			placeholder.color = Color(0.09, 0.1, 0.12, 1.0)
			placeholder.custom_minimum_size = Vector2(130, 68)
			slot.add_child(placeholder)
			button.text = "빈 슬롯"
			button.disabled = true
		slot.add_child(button)
		container.add_child(frame)


func _render_hand() -> void:
	for child in hand_box.get_children():
		child.queue_free()
	for i in range(player.hand.size()):
		var card: Dictionary = player.hand[i]
		var frame := main._make_card_frame()
		frame.custom_minimum_size = Vector2(151, 160)
		var card_box := VBoxContainer.new()
		card_box.custom_minimum_size = Vector2(145, 154)
		card_box.add_theme_constant_override("separation", 4)
		frame.add_child(card_box)
		card_box.add_child(main._make_art_rect(int(card.get("art", 0)), Vector2(145, 82)))
		var button := Button.new()
		var cost: int = main.relic_service.modify_card_cost(main.current_run, battle_state, card, "player")
		button.custom_minimum_size = Vector2(145, 68)
		button.text = "%s\n비용 %d | %s\n%s" % [String(card.get("name", "")), cost, main.deck_service.type_name(String(card.get("type", ""))), String(card.get("text", ""))]
		button.disabled = input_locked or game_over or current_player != "player" or cost > int(player.mana)
		main.ui.style_button(button, Color(0.18, 0.24, 0.3, 1.0))
		button.pressed.connect(Callable(self, "_on_hand_card_pressed").bind(i))
		card_box.add_child(button)
		hand_box.add_child(frame)


func _render_battle_deck() -> void:
	if deck_count_label == null or deck_list_label == null:
		return
	deck_count_label.text = "남은 카드 %d장" % player.deck.size()
	deck_list_label.text = main.deck_service.deck_summary_from_cards(player.deck)





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
	_build_battle_ui()
	main.relic_service.on_battle_start(main.current_run, player, battle_state)
	player.health = int(main.current_run.get("hp", player.health))
	last_player_health = int(player.health)
	last_opponent_health = int(opponent.health)
	_add_log("%s 전투 시작. 적 영웅 체력을 0으로 만드세요." % _node_type_name(String(main.run_store.current_node(main.current_run).get("type", "battle"))))
	_refresh_ui()
	await _show_turn_banner("전투 시작!", true)
	await _start_turn(player, true)


func _add_log(message: String) -> void:
	if log_label == null:
		return
	log_label.text = message + "\n" + log_label.text
