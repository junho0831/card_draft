extends SceneTree
## Taps on empty enemy slots use the same attack rules in both phone layouts.
const Storage = preload("res://src/services/game_storage.gd")
var failures: Array[String] = []
var main
var battle

func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func settle() -> void:
	for i in range(12): await process_frame

func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func tap(point: Vector2) -> void:
	await mouse(point, true)
	await mouse(point, false)
	await settle()

func prepare(selected: bool = true) -> void:
	battle.pending_action.clear()
	battle.current_player = "player"
	battle.input_locked = false
	battle.opponent.name = "광신도"
	battle.opponent.health = 40
	battle.opponent.max_health = 40
	battle.opponent.field.clear()
	battle.player.field = [{"id":"militia", "battle_unit_id":9901, "name":"민병대", "race":"인간", "attack":2, "health":8, "max_health":8, "can_attack":true}]
	battle.selected_attacker = 0 if selected else -1
	battle.opponent_field_signature = ""
	battle._refresh_ui()
	await settle()

func target(index: int = 0) -> Vector2:
	var slot: Control = battle.opponent_field_slots[index]
	if is_instance_valid(battle.landscape_view):
		battle.landscape_view.board_scroll.scroll_vertical = 0
	else:
		main.root_scroll.ensure_control_visible(slot)
	await settle()
	return slot.get_global_rect().get_center()

func run() -> void:
	root.size = Vector2i(390, 844) if OS.get_cmdline_user_args().has("--portrait") else (Vector2i(667, 375) if OS.get_cmdline_user_args().has("--small") else Vector2i(802, 390))
	main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("layout_viewport_override", root.size)
	main.set_meta("disable_timed_battle_fx", true)
	root.add_child(main)
	main.touch_input_active = true
	main.pending_guided_run = true
	main._init_run("human")
	main.run_flow.prepare_battle("normal")
	battle = main.battle_screen
	main.current_run.relic_ids = []
	await settle()
	if is_instance_valid(battle.landscape_view):
		check(battle.landscape_view.board_scroll.scroll_vertical > 0, "new battle shows ally lane first")
	await prepare()
	check(main.Onboarding.first_battle(main.current_run), "also tests the first learning battle")
	await tap(await target())
	check(battle.opponent.health == 38 and not battle.player.field[0].can_attack, "empty field attacks hero exactly once")
	check(battle._unit_attack_status(battle.player.field[0], 0).label == "공격 완료", "successful attack displays spent status")
	if is_instance_valid(battle.landscape_view):
		check(battle.landscape_view.board_scroll.scroll_vertical > 0, "completed attack returns to allies")
	await tap(await target())
	check(battle.opponent.health == 38, "exhausted unit cannot attack again")
	await prepare(false)
	await tap(await target(1))
	check(battle.opponent.health == 40 and battle.selected_attacker == -1 and battle.player.field[0].can_attack, "unselected field tap explains without attacking")
	await battle._on_player_unit_pressed(0)
	await tap(await target(1))
	check(battle.opponent.health == 38, "selected attacker can attack the empty field")
	await prepare()
	battle.opponent.field = [{"id":"militia", "battle_unit_id":9902, "name":"선봉", "race":"인간", "attack":1, "health":8, "max_health":8, "can_attack":true, "is_vanguard":true}]
	battle._refresh_ui()
	await tap(await target(1))
	check(battle.opponent.health == 40 and battle.player.field[0].can_attack, "empty field never bypasses vanguard")
	await tap(await target())
	check(battle.opponent.health == 40 and battle.opponent.field[0].health == 6, "occupied slot attacks its unit instead of hero")
	await prepare()
	battle.pending_action = {"kind":"equipment", "card_index":0}
	battle._refresh_ui()
	await tap(await target())
	check(battle.opponent.health == 40 and battle.player.field[0].can_attack and not battle.pending_action.is_empty(), "pending friendly target is not consumed")
	await prepare()
	battle.current_player = "opponent"
	battle.input_locked = true
	battle._refresh_ui()
	await tap(await target())
	check(battle.opponent.health == 40, "enemy turn blocks field attacks")
	await prepare()
	var point := await target()
	await mouse(point, true)
	var motion := InputEventMouseMotion.new()
	motion.position = point - Vector2(0, 24)
	motion.global_position = motion.position
	motion.relative = Vector2(0, -24)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	await process_frame
	await mouse(motion.position, false)
	await settle()
	check(battle.opponent.health == 40 and battle.player.field[0].can_attack, "swipe on empty field does not attack")
	await tap(await target())
	check(battle.opponent.health == 38, "tap after swipe still attacks")
	await prepare(false)
	var ally: Control = battle.player_field_slots[0]
	if is_instance_valid(battle.landscape_view):
		await battle.landscape_view.focus_targets([{"player":true, "hero":true}], true)
	else:
		main.root_scroll.ensure_control_visible(ally)
	await settle()
	await tap(ally.get_global_rect().get_center())
	check(battle.selected_attacker == 0 and battle.opponent.health == 40, "ally tap only selects")
	if is_instance_valid(battle.landscape_view):
		await battle.landscape_view.focus_targets([{"player":true, "hero":true}], true)
	await settle()
	await tap(battle.player_field_slots[0].get_global_rect().get_center())
	check(battle.selected_attacker == -1 and battle.player.field[0].can_attack, "same ally tap cancels without consuming attack")
	await battle._on_player_unit_pressed(0)
	check(battle.end_turn_button.text == "선택 취소", "selected attacker exposes cancel action")
	await tap(battle.end_turn_button.get_global_rect().get_center())
	check(battle.selected_attacker == -1 and battle.current_player == "player" and battle.player.field[0].can_attack, "cancel button does not end turn or attack")
	battle.player.field[0].can_attack = false
	battle.player.field[0].attack_wait_reason = "summoned"
	check(battle._unit_attack_status(battle.player.field[0]).label == "소환 대기", "summon waiting status")
	var restored: Dictionary = battle.SnapshotCodec.side(battle.player)
	check(restored.field[0].attack_wait_reason == "summoned", "status survives snapshot normalization")
	battle.player.field[0].can_attack = true
	check(battle._unit_attack_status(battle.player.field[0]).label == "공격 가능", "immediate or restored attack permission takes priority")
	battle.player.field[0].can_attack = false
	battle.player.field[0].erase("attack_wait_reason")
	check(battle._unit_attack_status(battle.player.field[0]).reason == "이번 턴 공격 불가", "legacy save uses an honest fallback")
	if is_instance_valid(battle.landscape_view):
		var view = battle.landscape_view
		for mode in ["outside", "always", "off"]:
			await prepare(false)
			main.player_profile.settings.battle_auto_focus = mode
			await view.focus_targets([{"player":true, "hero":true}], true, true)
			await battle._on_player_unit_pressed(0)
			check((view.board_scroll.scroll_vertical > 0) == (mode == "off"), "selection respects camera mode " + mode)
			await view.focus_targets([{"player":false, "hero":true}], false, true)
			check(view.board_scroll.scroll_vertical == 0, "manual navigation works in " + mode)
		main.player_profile.settings.battle_auto_focus = "outside"
		main.set_meta("disable_timed_battle_fx", false)
		battle.presentation.return_to_allies(battle.presentation.interaction_generation)
		battle.presentation.gesture_started(Vector2.ZERO)
		battle.presentation.gesture_ended()
		await create_timer(0.55).timeout
		check(view.board_scroll.scroll_vertical == 0, "user gesture cancels delayed return even after release")
		battle.presentation.return_to_allies(battle.presentation.interaction_generation)
		view.show_help()
		view.close_detail()
		await create_timer(0.55).timeout
		check(view.board_scroll.scroll_vertical == 0, "opening and closing a modal cancels delayed return")
		main.set_meta("disable_timed_battle_fx", true)
	if DisplayServer.get_name() != "headless":
		await prepare()
		await target()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Storage.path_for("enemy-field.png"))
	print("PASS enemy field taps " + str(root.size) if failures.is_empty() else str(failures))
	main._clear_screen()
	main.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
