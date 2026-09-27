extends SceneTree

const Storage = preload("res://src/services/game_storage.gd")
var failures: Array[String] = []

func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func settle() -> void:
	for i in range(12):
		await process_frame

func run() -> void:
	root.size = Vector2i(1024, 768)
	var main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("disable_timed_battle_fx", true)
	main.set_meta("layout_viewport_override", Vector2i(1024, 768))
	root.add_child(main)
	await settle()
	main._clear_run()
	check(main._layout_signature(Vector2(990, 768)) != main._layout_signature(Vector2(1024, 768)), "battle breakpoint triggers a layout rebuild")
	check(main._layout_signature(Vector2(1024, 790)) != main._layout_signature(Vector2(1024, 810)), "race selection height breakpoint triggers a layout rebuild")
	main.player_profile["learning_stage"] = 5
	main._start_new_run()
	await settle()
	var selection = main.active_screen_controller
	check(main.root_scroll.get_global_rect().end.y <= selection.fixed_footer.get_global_rect().position.y, "fixed footer does not cover scrollable content")
	main.root_scroll.scroll_vertical = 1000000
	await settle()
	check(main.root_scroll.get_global_rect().encloses(selection.strategy_cards.get_global_rect()), "strategy descriptions remain reachable above footer")
	main._init_run("human")
	main._enter_current_node()
	await settle()
	var battle = main.battle_screen
	check(main.root_scroll.get_global_rect().encloses(battle.hand_box.get_global_rect()), "1024x768 hand fits on the first screen: %s inside %s" % [battle.hand_box.get_global_rect(), main.root_scroll.get_global_rect()])
	var tag_meta: Dictionary = main._build_tag_meta()
	for meta in tag_meta.values():
		check(meta.icon != meta.name, "build icon does not repeat its name")
	main._show_upgrade_card_screen()
	await settle()
	var upgrade_screen = main.active_screen_controller
	var card: Dictionary = main.card_db.get_card("militia")
	var upgraded: Dictionary = main.card_db.get_card("militia_plus")
	check(upgrade_screen._card_summary("현재", card).contains("공격 1 / 체력 1"), "upgrade preview shows base unit stats")
	check(upgrade_screen._card_summary("강화 후", upgraded).contains("공격 2 / 체력 2"), "upgrade preview shows actual upgraded stats")
	main.player_profile["soul_stones"] = 49
	main._show_meta_upgrade()
	await settle()
	var button := find_button(main.root_box, "튼튼한 몸 강화")
	check(button != null and button.disabled and button.text.contains("50") and button.text.contains("1 부족"), "unaffordable upgrade shows price and shortfall")
	main.player_profile["soul_stones"] = 50
	main._show_meta_upgrade()
	await settle()
	button = find_button(main.root_box, "튼튼한 몸 강화")
	check(button != null and not button.disabled, "affordable upgrade is enabled")
	if button != null:
		button.pressed.emit()
	await settle()
	check(int(main.player_profile.soul_stones) == 0, "displayed upgrade price matches charged price")
	button = find_button(main.root_box, "튼튼한 몸 강화")
	check(button != null and button.text.contains("75"), "next level updates its price")
	main._clear_screen()
	main.queue_free()
	await settle()
	print("PASS visual review regressions" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)

func find_button(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix):
		return node
	for child in node.get_children():
		var found := find_button(child, prefix)
		if found != null:
			return found
	return null
