extends SceneTree
const Storage = preload("res://src/services/game_storage.gd")
var failures: Array[String] = []

func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func settle() -> void:
	for i in range(12): await process_frame

func run() -> void:
	for viewport in [Vector2i(667, 375), Vector2i(844, 390)]:
		root.size = viewport
		var main = preload("res://src/core/Main.tscn").instantiate()
		main.set_meta("disable_window_mode_changes", true)
		main.set_meta("layout_viewport_override", viewport)
		main.set_meta("display_safe_area_override", Rect2(44, 0, viewport.x - 88, viewport.y - 21))
		main.set_meta("disable_timed_battle_fx", true)
		root.add_child(main)
		main.touch_input_active = true
		main.pending_guided_run = false
		main._init_run("human", "human_elite")
		main.run_flow.prepare_battle("normal")
		var battle = main.battle_screen
		var view = battle.landscape_view
		for side in [battle.player, battle.opponent]:
			side.field.clear()
			for i in range(5):
				var unit: Dictionary = main.card_db.get_card("militia").duplicate(true)
				unit.merge({"battle_unit_id": i + (100 if side == battle.player else 200), "health": 3, "max_health": 3, "attack": 2, "can_attack": true}, true)
				side.field.append(unit)
		battle._refresh_ui()
		await settle()
		var safe: Rect2 = main.modal_layer.get_global_rect()
		for control in [battle.player_hero_target, battle.opponent_hero_target, battle.hand_scroll, battle.end_turn_button, battle.race_power_button, battle.detail_toggle_button]:
			check(safe.encloses(control.get_global_rect()), "safe-area control %s %s" % [viewport, control.get_global_rect()])
		for slots in [battle.player_field_slots, battle.opponent_field_slots]:
			check(slots.size() == 5, "five slots per side")
			for slot in slots:
				check(view.board_scroll.get_global_rect().encloses(slot.get_global_rect()), "both full lanes visible %s %s" % [viewport, slot.get_global_rect()])
		check(view.board_scroll.scroll_vertical == 0, "no battlefield scrolling")
		battle.opponent.field.clear()
		battle.selected_attacker = 0
		battle._refresh_ui()
		await settle()
		for slot in battle.opponent_field_slots:
			check(slot.disabled and not slot.has_node("TargetBorder"), "empty enemy slots are never attack targets")
		check(view.cancel_button.visible and battle.end_turn_button.disabled, "dedicated cancel during selection")
		check(battle.opponent_hero_target.get_node("TargetBorder").visible, "attackable hero has a border above its portrait")
		view.cancel_button.pressed.emit()
		check(battle.selected_attacker == -1, "cancel clears attacker")
		check(not battle.opponent_hero_target.get_node("TargetBorder").visible, "hero border clears with selection")
		battle.player.hand.clear()
		battle.player.field.resize(1)
		battle.player.field[0].can_attack = false
		battle.player.mana = 10
		battle.battle_state.race_power_used = false
		check(battle._can_use_race_power(), "power-only fixture can use power")
		check(not battle._can_auto_end_turn(), "power-only state never ends automatically")
		battle.battle_state.race_power_used = true
		check(battle._can_auto_end_turn(), "exhausted turn can end")
		view.show_unit(battle.player.field[0], true)
		check(not battle._can_auto_end_turn(), "inspection pauses auto end")
		view.close_detail()
		battle._refresh_ui()
		battle._spawn_floating_text(battle.opponent_hero_target, "마나 +1", Color.CYAN)
		battle._spawn_floating_text(battle.player_hero_target, "-4", Color.RED)
		battle._spawn_center_banner("연계 발동", Color.GREEN)
		for child in main.modal_layer.get_children():
			check(not child is Label, "combat notifications never add a second oversized banner")
		for child in battle.battle_fx_layer.get_children():
			if child is Label:
				check(child.get_theme_font_size("font_size") <= 22, "compact floating text")
				check(view.board_scroll.get_global_rect().encloses(child.get_global_rect()), "effect stays within battlefield")
		battle._check_no_actions_loss()
		battle._check_no_actions_loss()
		check(battle.auto_end_pending, "one pending auto-end task")
		var turns: int = battle.battle_state.get("player_turn_count", 0)
		await create_timer(0.3).timeout
		check(int(battle.battle_state.get("player_turn_count", 0)) == turns, "effects complete before turn transition")
		# A newly available power cancels the pending transition at execution time.
		battle.battle_state.race_power_used = false
		await create_timer(1.4).timeout
		check(int(battle.battle_state.get("player_turn_count", 0)) == turns and not battle.auto_end_pending, "auto end rechecks availability")
		battle.battle_state.race_power_used = true
		battle._check_no_actions_loss()
		battle.battle_state.player_turn_count = turns + 1
		await create_timer(0.8).timeout
		turns += 1
		check(int(battle.battle_state.get("player_turn_count", 0)) == turns and not battle.auto_end_pending, "stale auto end cannot end a different turn")
		battle._check_no_actions_loss()
		battle._check_no_actions_loss()
		await create_timer(0.2).timeout
		check(view.center_guidance.text == "행동 완료 · 상대 턴", "transition label is readable before ending")
		for i in range(200):
			if not battle.auto_end_pending: break
			await create_timer(0.05).timeout
		check(int(battle.battle_state.get("player_turn_count", 0)) == turns + 1, "exhausted turn ends exactly once")
		await battle.prepare_to_leave()
		main._clear_screen()
		main.queue_free()
		await settle()
	print("PASS compact battlefield and automatic turn regression" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
