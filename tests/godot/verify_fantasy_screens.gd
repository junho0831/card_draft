extends SceneTree
const Storage = preload("res://src/services/game_storage.gd")
const Inputs = preload("res://tests/godot/ui_input_test.gd")
var checks := 0
var failures: Array[String] = []
func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
func settle() -> void:
	await create_timer(0.35).timeout
	await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Storage.path_for(name + ".png"))
func run() -> void:
	root.size = Vector2i(1280, 720)
	var main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("disable_timed_battle_fx", true)
	main.set_meta("layout_viewport_override", Vector2i(1280, 720))
	root.add_child(main)
	var input = Inputs.new()
	main.player_profile.learning_stage = 5
	main.pending_guided_run = false
	main._init_run("human", "human_legion")
	main._show_main_menu()
	await settle()
	await capture("main")
	await input.click(input.find_button(main.root_box, "⚔  이어하기"), self)
	check(main.active_screen == "map", "continue returns to the real run")
	await settle()
	await capture("map")
	check(main.root_box.get_global_rect().end.x <= 1280, "map fits desktop width")
	main.current_run.gold = 200
	main.current_run.pending_shop = {"cards": ["militia", "knight_spearman", "training_sword"], "relic": {}, "purchased_cards": []}
	main._show_shop()
	await settle()
	var shop = main.active_screen_controller
	var before: int = main.current_run.deck_ids.size()
	shop._select_shop_card("training_sword")
	check(main.current_run.gold == 200 and main.current_run.deck_ids.size() == before, "selection does not purchase")
	await capture("shop")
	await input.click(input.find_button(shop.preview_box, "35 골드"), self)
	check(main.current_run.gold == 165 and main.current_run.deck_ids.size() == before + 1 and main.current_run.deck_ids.back() == "training_sword", "buy button adds the selected card and charges once")
	main.current_run.pending_shop = {}
	main.current_run.pending_card_reward = {"choices": ["militia", "knight_spearman", "training_sword"], "gold_reward": 20}
	main._show_card_reward()
	await settle()
	var reward = main.active_screen_controller
	reward._select_reference_reward("knight_spearman")
	before = main.current_run.deck_ids.size()
	check(main.current_run.deck_ids.size() == before, "reward selection awaits confirmation")
	await capture("reward")
	await input.click(reward.reference_claim, self)
	check(main.current_run.deck_ids.size() == before + 1 and main.current_run.deck_ids.back() == "knight_spearman", "reward confirmation adds selected card")
	check(main.current_run.pending_card_reward.is_empty(), "reward cleared after confirmation")
	# The phone dock must expose both actions without horizontal scrolling.
	root.size = Vector2i(390, 844)
	main.set_meta("layout_viewport_override", Vector2i(390, 844))
	main._apply_root_layout()
	await settle()
	main.current_run.pending_shop = {"cards": ["training_sword"], "relic": {}, "purchased_cards": []}
	main._show_shop()
	await settle()
	var mobile_shop = main.active_screen_controller
	for label in ["덱 보기", "상점 나가기"]:
		var button: Button = input.find_button(mobile_shop.screen_action_dock, label)
		check(button != null and button.get_global_rect().position.x >= 0 and button.get_global_rect().end.x <= 390 and button.get_global_rect().end.y <= 844, "phone shop action fits: " + label)
	await input.click(input.find_button(mobile_shop.screen_action_dock, "덱 보기"), self)
	check(main.active_screen == "collection", "phone deck action opens collection")
	main._show_compendium()
	await settle()
	var library = main.active_screen_controller
	check(library.grid.columns == 2 and library.grid.get_child_count() == main.card_defs.size(), "phone compendium shows every card in two columns")
	await capture("compendium")
	var run_before := JSON.stringify(main.current_run)
	library.search.text = "훈련용 검"
	library.search.text_changed.emit(library.search.text)
	await settle()
	check(library.grid.get_child_count() == 1, "card search filters by name")
	var face: Control = library.grid.get_child(0)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = face.get_global_rect().get_center()
		event.global_position = event.position
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()
	check(is_instance_valid(library.detail_overlay) and library.detail_overlay.visible, "card art click opens detail")
	await capture("card_detail")
	await input.click(input.find_button(library.detail_overlay, "도감으로 돌아가기"), self)
	check(library.detail_overlay == null and JSON.stringify(main.current_run) == run_before, "closing detail leaves run unchanged")
	failures.append_array(input.failures)
	checks += input.count
	main._clear_screen()
	main.queue_free()
	await process_frame
	print("PASS %d fantasy screen checks" % checks if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
