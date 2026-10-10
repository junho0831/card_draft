extends SceneTree

const Storage = preload("res://src/services/game_storage.gd")
const Fixture = preload("res://tests/godot/combat_strategy_test.gd")
var failures: Array[String] = []

func _initialize() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.3).timeout

func click(control: Control) -> void:
	check(is_instance_valid(control), "click target exists")
	if not is_instance_valid(control): return
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(event, true)
	await settle()

func capture(name: String) -> void:
	if "--logic-only" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	check(not picture.is_empty(), "rendered image is nonempty")
	picture.save_png(Storage.path_for(name + ".png"))

func check_hand_bounds(battle, expected_size: Vector2, last_visible: bool = false) -> void:
	var bounds: Rect2 = battle.hand_scroll.get_global_rect()
	for card: Control in battle.hand_box.get_children():
		check(card.size.is_equal_approx(expected_size), "hand keeps fixed size: %s" % str(card.size))
		for corner in [Vector2.ZERO, Vector2(card.size.x, 0), card.size, Vector2(0, card.size.y)]:
			var point: Vector2 = card.get_global_transform() * corner
			check(point.y >= bounds.position.y - 1 and point.y <= bounds.end.y + 1, "rotated hand fits vertically")
	var last: Control = battle.hand_box.get_child(battle.hand_box.get_child_count() - 1)
	if last_visible:
		for corner in [Vector2.ZERO, Vector2(last.size.x, 0), last.size, Vector2(0, last.size.y)]:
			var point: Vector2 = last.get_global_transform() * corner
			check(point.x >= bounds.position.x - 1 and point.x <= bounds.end.x + 1, "last rotated card is fully reachable")

func check_field_geometry(battle) -> void:
	var bounds: Rect2 = battle.landscape_view.board_scroll.get_global_rect()
	check(battle.landscape_view.board_scroll.scroll_vertical == 0, "battlefield stays fixed while choosing actions")
	for hero: Control in [battle.player_hero_target, battle.opponent_hero_target]:
		check(bounds.grow(1).encloses(hero.get_global_rect()), "both heroes remain fully visible together")
	for lane in [battle.player_field_box, battle.opponent_field_box]:
		for slot: Control in lane.get_children():
			var rect := slot.get_global_rect()
			check(rect.size.x >= 44 and rect.size.y >= 44, "field slots retain minimum touch dimensions")
			if not battle._is_landscape_phone():
				check(rect.size.y > rect.size.x, "desktop field slots preserve a portrait card silhouette")
			check(bounds.grow(1).encloses(rect), "both five-slot lanes remain fully visible together")
			if battle._is_landscape_phone():
				var face: Control = slot.get_child(0) if slot is VBoxContainer else slot
				if face.has_node("CardName"):
					check(not face.get_node("CardNameBand").get_global_rect().intersects(face.get_node("AttackBand").get_global_rect()), "compact name never covers attack value")
					check(not face.get_node("CardNameBand").get_global_rect().intersects(face.get_node("HealthBand").get_global_rect()), "compact name never covers health value")

func check_power_labels(battle) -> void:
	var button: Button = battle.race_power_button
	var padding := button.get_theme_stylebox("normal").get_minimum_size()
	var available := button.size - padding
	check(button.text.split("\n").size() == 2, "power button separates category and title into two lines")
	# All three existing titles must fit the actual shared button, without changing the run.
	for title in ["필살기", "왕국의 집결", "바람의 순환", "죽음의 계약", "사용 완료"]:
		var glyphs := button.get_theme_font("font").get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size"))
		check(glyphs.x <= available.x + 1, "power title fits actual inner button width: " + title)
	var description: Label = battle.landscape_view.find_child("RacePowerDescription", true, false)
	check(is_instance_valid(description), "power effect has a separate description")
	if is_instance_valid(description):
		check(description.is_visible_in_tree() and not description.text.is_empty(), "separate power effect is visible and populated")
		check(not description.get_global_rect().intersects(button.get_global_rect()), "power description does not cover its button")
		button.hide()
		battle.landscape_view.refresh_labels()
		check(not description.visible, "hidden power action also hides its effect description")
		button.show()
		battle.landscape_view.refresh_labels()
		check(description.visible, "restored power action restores its effect description")

func check_external_predictions(battle, input) -> void:
	var bounds: Rect2 = battle.landscape_view.board_scroll.get_global_rect()
	for index in range(battle.opponent.field.size()):
		var slot: Control = battle._card_action_field_slot(false, index)
		var preview: Label = slot.get_node_or_null("CombatPrediction")
		check(slot is VBoxContainer and is_instance_valid(preview), "enemy preview uses a separate target column")
		if not is_instance_valid(preview): continue
		var face: Button = input.find_button(slot, "")
		check(is_instance_valid(face), "prediction retains the attackable card button")
		if not is_instance_valid(face): continue
		check(preview.get_global_rect().position.y >= face.get_global_rect().end.y, "damage preview sits below card artwork")
		for node_name in ["Illustration", "CardName", "Attack", "Health"]:
			var content: Control = face.get_node(node_name)
			check(content.is_visible_in_tree(), "prediction preserves ordinary card information: " + node_name)
			check(not preview.get_global_rect().intersects(content.get_global_rect()), "prediction does not cover card information: " + node_name)
		check(bounds.grow(1).encloses(slot.get_global_rect()), "focused battlefield includes the whole predicted target and preview")

func check_tutorial_header(battle) -> void:
	var guide: Label = battle.landscape_view.center_guidance
	var text_size := guide.get_theme_font("font").get_string_size(guide.text, HORIZONTAL_ALIGNMENT_LEFT, -1, guide.get_theme_font_size("font_size"))
	check(text_size.x <= guide.size.x + 1, "first lesson instruction fits without ellipsis: " + guide.text)
	check(not guide.tooltip_text.is_empty(), "short tutorial instruction retains its full explanation")
	for child in guide.get_parent().get_parent().get_children():
		if child is Button and child.is_visible_in_tree():
			var glyph_width: float = child.get_theme_font("font").get_string_size(child.text, HORIZONTAL_ALIGNMENT_LEFT, -1, child.get_theme_font_size("font_size")).x
			check(glyph_width <= child.size.x - child.get_theme_stylebox("normal").get_minimum_size().x + 1, "tutorial header label fits inner width: " + child.text)

func run() -> void:
	var mobile := "--landscape" in OS.get_cmdline_user_args()
	var race_id := "human"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--race="):
			race_id = argument.trim_prefix("--race=")
	if race_id not in ["human", "elf", "undead"]:
		printerr("Unsupported capture race: ", race_id)
		quit(2)
		return
	var viewport := Vector2i(844, 390) if mobile else Vector2i(1280, 720)
	if mobile and "--small" in OS.get_cmdline_user_args():
		viewport = Vector2i(740, 360)
	if mobile and "--safe-area" in OS.get_cmdline_user_args():
		viewport = Vector2i(667, 375)
	if mobile and "--large-phone" in OS.get_cmdline_user_args():
		viewport = Vector2i(932, 430)
	if not mobile and "--wide" in OS.get_cmdline_user_args():
		viewport = Vector2i(1920, 1080)
	var expected_hand_size := Vector2(82, 110) if mobile else Vector2(132, 178)
	root.size = viewport
	root.gui_embed_subwindows = true
	var main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("disable_timed_battle_fx", true)
	main.set_meta("layout_viewport_override", viewport)
	if "--safe-area" in OS.get_cmdline_user_args():
		main.set_meta("display_safe_area_override", Rect2(44, 0, viewport.x - 88, viewport.y - 21))
	root.add_child(main)
	main.touch_input_active = mobile
	main.pending_guided_run = false
	main.player_profile.learning_stage = 5
	main._init_run(race_id, {"human": "human_elite", "elf": "elf_cycle", "undead": "undead_sacrifice"}[race_id])
	main._apply_root_layout()
	main.current_run.relic_ids = []
	main.run_flow.prepare_battle("normal")
	var battle = main.battle_screen
	var fixture = Fixture.new()
	battle.player = fixture.side([fixture.unit(101, "trainee_swordsman", 7, 6), fixture.unit(102, "militia", 2, 5)])
	battle.opponent = fixture.side([fixture.unit(201, "bone_soldier", 3, 3), fixture.unit(202, "militia", 2, 9)])
	fixture = null
	battle.player.field[0].name = "초보 검병"
	battle.player.field[1].name = "민병대"
	battle.opponent.field[0].name = "해골 병사"
	battle.opponent.field[1].name = "민병대"
	for side in [battle.player, battle.opponent]:
		for unit in side.field:
			var definition: Dictionary = main.card_db.get_card(unit.id)
			for key in ["race", "attr", "art_id", "art", "type"]:
				unit[key] = definition.get(key, unit.get(key))
	battle.player.hand = main.card_db.build_deck_from_ids(["militia", "training_sword", "fireball"])
	battle.current_player = "player"
	battle.input_locked = false
	battle.battle_state.active_build_tags = []
	battle._ensure_hand_visual_slots()
	battle._refresh_ui()
	await settle()
	check(is_instance_valid(battle.landscape_view), "landscape phone and desktop both use the shared board")
	check(battle._is_landscape_phone() == mobile, "board presentation does not masquerade as phone input")
	if is_instance_valid(battle.landscape_view):
		check_field_geometry(battle)
		check_power_labels(battle)
		check(battle.player_field_box.get_child_count() == 5 and battle.opponent_field_box.get_child_count() == 5, "both lanes retain five slots")
		check(battle.opponent_field_box.global_position.y < battle.player_field_box.global_position.y, "enemy lane remains above allies")
		check(not battle.detail_toggle_button.is_visible_in_tree(), "normal battle has one shared information entry")
		check(battle.hand_box.get_child(0).size.is_equal_approx(expected_hand_size), "hand has fixed readable dimensions for its viewport")
		check_hand_bounds(battle, expected_hand_size, true)
		for unit_card: Control in battle.player_field_box.get_children():
			var card_name := unit_card.get_node_or_null("CardName")
			if card_name != null:
				check(card_name.is_visible_in_tree(), "field card names remain visible on mobile")
		var borders := []
		for card: Control in battle.hand_box.get_children():
			borders.append(card.get_node("TypeBorder").get_theme_stylebox("panel").border_color)
		check(borders[0] != borders[1] and borders[1] != borders[2] and borders[0] != borders[2], "unit equipment and damage have distinct type borders")
		var board_bounds: Rect2 = battle.landscape_view.get_global_rect()
		check(absf(battle.end_turn_button.get_global_rect().end.y - board_bounds.end.y) <= 12, "primary action stays at board bottom")
		check(absf(battle.end_turn_button.get_global_rect().end.x - board_bounds.end.x) <= 12, "primary action stays at board right")
		check(battle.hand_scroll.get_global_rect().end.x <= battle.end_turn_button.global_position.x, "hand reserves action rail")
		check(battle.landscape_view.cancel_button.is_visible_in_tree() and battle.landscape_view.cancel_button.disabled, "inactive selection cancel retains its space")
		check(battle.opponent_info.text == str(battle.opponent.health) and battle.player_info.text == str(battle.player.health), "hero portraits show current health only")
		for hero: Control in [battle.opponent_hero_target, battle.player_hero_target]:
			check(hero.find_children("*", "Label", true, false).size() == 2, "hero portrait reserves its center for artwork")
		var info_style: StyleBoxTexture = battle.recommended_action_button.get_theme_stylebox("normal") as StyleBoxTexture
		check(info_style != null and info_style.texture.resource_path.ends_with("button_silver.svg"), "battle information uses silver secondary style")
	await capture("01-threats")
	var before := JSON.stringify([battle.player, battle.opponent, battle.SnapshotCodec.flags(battle.battle_state)])
	seed(729441)
	var expected_random := randi()
	seed(729441)
	var input = preload("res://tests/godot/ui_input_test.gd").new()
	await click(input.find_button(battle._card_action_field_slot(true, 0), ""))
	check(battle.selected_attacker == 0, "tap selects attacker")
	if is_instance_valid(battle.landscape_view):
		check_field_geometry(battle)
		check_external_predictions(battle, input)
		check(battle.reference_mana_label.get_global_rect().end.x <= battle.landscape_view.get_global_rect().end.x, "mana stays inside reserved rail after selection")
		check(battle.landscape_view.cancel_button.size.x >= (104 if mobile else 120), "selection cancel retains its touch target width")
		for header_button: Button in [battle.landscape_view.cancel_button, battle.recommended_action_button]:
			var glyph_width := header_button.get_theme_font("font").get_string_size(header_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, header_button.get_theme_font_size("font_size")).x
			check(glyph_width <= header_button.size.x - header_button.get_theme_stylebox("normal").get_minimum_size().x + 1, "header action label fits actual inner width: " + header_button.text)
	await capture("02-selected")
	await click(battle.recommended_action_button)
	var desktop_dialog: Control = main.modal_layer.get_node_or_null("BattleChoiceDialog")
	check(is_instance_valid(desktop_dialog) or (is_instance_valid(battle.landscape_view) and is_instance_valid(battle.landscape_view.card_dialog)), "tap opens battle information")
	if is_instance_valid(desktop_dialog):
		var desktop_close: Button = desktop_dialog.find_child("BattleChoiceClose", true, false)
		check(desktop_close.size.x >= 96 and desktop_close.size.y >= 44, "desktop close target meets minimum touch dimensions")
		check(desktop_close.global_position.x > viewport.x * 0.5 and desktop_close.global_position.y < viewport.y * 0.25, "shared information closes from upper right")
	await capture("03-comparison")
	var comparison: Control = main.modal_layer.find_child("BattleChoiceComparison", true, false)
	check(is_instance_valid(comparison), "structured target comparison is visible")
	if is_instance_valid(comparison):
		for item in comparison.find_children("*", "Label", true, false):
			check(item.get_global_rect().position.x >= comparison.get_global_rect().position.x - 1 and item.get_global_rect().end.x <= comparison.get_global_rect().end.x + 1, "comparison text stays within its horizontal bounds")
			check(item.size.y >= item.get_minimum_size().y, "comparison text has enough wrapping height")
	if is_instance_valid(battle.landscape_view):
		var scroll: ScrollContainer = battle.landscape_view.card_dialog.find_child("CardDetailScroll", true, false)
		scroll.scroll_vertical = 10000
		await settle()
		if mobile:
			check(scroll.scroll_vertical > 0, "mobile comparison scrolls to remaining targets and limits")
		else:
			check(scroll.scroll_vertical > 0 or comparison.size.y <= scroll.size.y, "desktop comparison is fully visible or scrollable")
		await capture("03b-comparison-bottom")
		var close: Button = input.find_button(battle.landscape_view.card_dialog, "닫기")
		await click(close)
		await click(battle.landscape_view.cancel_button)
	else:
		if is_instance_valid(desktop_dialog):
			await click(desktop_dialog.find_child("BattleChoiceClose", true, false))
		await settle()
		await click(battle.recommended_action_button)
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		root.push_input(escape, true)
		await settle()
		check(main.modal_layer.get_node_or_null("BattleChoiceDialog") == null, "Escape closes desktop information without performing an action")
		await click(input.find_button(battle._card_action_field_slot(true, 0), ""))
	check(battle.selected_attacker == -1, "cancel clears selection")
	check(main.current_run.battle_snapshot.selected_attacker == -1, "cancel also clears saved selection")
	check(main.run_store.load_or_empty(Storage.run_path()).battle_snapshot.selected_attacker == -1, "cancelled selection stays cleared after loading disk save")
	check(JSON.stringify([battle.player, battle.opponent, battle.SnapshotCodec.flags(battle.battle_state)]) == before, "select inspect and cancel preserve gameplay state (selection log excluded)")
	check(randi() == expected_random, "select inspect and cancel preserve gameplay RNG")
	if is_instance_valid(battle.landscape_view):
		check_field_geometry(battle)
	await capture("04-cancelled")
	await click(battle.recommended_action_button)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	await settle()
	check(main.modal_layer.get_node_or_null("BattleChoiceDialog") == null, "Escape closes shared information")
	if is_instance_valid(battle.landscape_view):
		battle.player.hand = main.card_db.build_deck_from_ids(["militia", "training_sword", "fireball", "militia", "training_sword", "fireball", "militia", "training_sword", "fireball", "militia"])
		battle._ensure_hand_visual_slots()
		battle._refresh_ui()
		await settle()
		battle.hand_scroll.scroll_horizontal = 10000
		await settle()
		check_hand_bounds(battle, expected_hand_size, true)
		await capture("04b-ten-card-hand")
		battle.player.hand = main.card_db.build_deck_from_ids(["militia", "training_sword", "fireball", "militia", "training_sword", "fireball", "militia", "training_sword", "fireball", "militia", "training_sword", "fireball", "militia", "training_sword"])
		battle._ensure_hand_visual_slots()
		battle._refresh_ui()
		await settle()
		battle.hand_scroll.scroll_horizontal = 10000
		await settle()
		check(battle.hand_scroll.scroll_horizontal > 0, "full hand scrolls horizontally")
		check_hand_bounds(battle, expected_hand_size, true)
		await capture("05-full-hand")
	if not mobile:
		battle.hand_scroll.scroll_horizontal = 0
		await settle()
		var field_count: int = battle.player.field.size()
		await click(battle.hand_box.get_child(0))
		check(battle.player.field.size() == field_count + 1, "desktop mouse click still plays a hand card directly")
		battle.player.hand = main.card_db.build_deck_from_ids(["training_sword"])
		battle._ensure_hand_visual_slots()
		var attack_before: int = battle.player.field[1].attack
		battle._on_hand_card_pressed(0)
		check(not battle.pending_action.is_empty(), "desktop direct equipment API requests a target immediately")
		battle._confirm_ally_target(int(battle.player.field[1].battle_unit_id))
		check(battle.player.hand.is_empty() and battle.player.field[1].attack > attack_before, "desktop direct equipment API resolves without a presentation frame wait")
	if mobile:
		# A fresh first lesson exercises its additional information button and live prompts.
		await battle.prepare_to_leave()
		main._clear_screen()
		main.player_profile.learning_stage = 0
		main.pending_guided_run = true
		main._init_run("human")
		main.run_flow.prepare_battle("normal")
		battle = main.battle_screen
		await settle()
		check_tutorial_header(battle)
		var tutorial_fixture = Fixture.new()
		battle.player.field = [tutorial_fixture.unit(901, "militia", 2, 3)]
		battle.player.field[0].can_attack = true
		battle._record_first_play_action("summoned")
		battle._refresh_ui()
		await settle()
		check_tutorial_header(battle)
		await battle._on_player_unit_pressed(0)
		await settle()
		check_tutorial_header(battle)
		await capture("06-first-lesson-target")
		tutorial_fixture = null
	main._clear_run()
	main._clear_screen()
	main.queue_free()
	input = null
	await process_frame
	await process_frame
	check(not is_instance_valid(main), "capture scene is released before shutdown")
	print("PASS battle information, input and cancel ", viewport) if failures.is_empty() else printerr(failures)
	# Let this coroutine release its locals before the engine tears down resources.
	call_deferred("finish")

func finish() -> void:
	quit(0 if failures.is_empty() else 1)
