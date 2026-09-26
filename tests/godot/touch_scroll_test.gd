extends SceneTree
const Storage = preload("res://src/services/game_storage.gd")
const Router = preload("res://src/ui/touch_scroll_router.gd")
class Surface extends Control:
	var router = Router.new()
	func _input(event: InputEvent) -> void:
		if router.handle(event, self):
			get_viewport().set_input_as_handled()
var clicks := 0
func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(667, 375) if OS.get_cmdline_user_args().has("--small-phone") else Vector2i(844, 390)
	var surface := Surface.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(surface)
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(360, 600)
	surface.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 340
	scroll.add_child(box)
	for i in range(14):
		var button := Button.new()
		button.text = "버튼 위에서도 밀어서 이동 %d" % i
		button.custom_minimum_size = Vector2(330, 80)
		button.pressed.connect(func(): clicks += 1)
		box.add_child(button)
	await process_frame
	await process_frame
	await mouse(Vector2(150, 250), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(150, 130)
	motion.global_position = motion.position
	motion.relative = Vector2(0, -120)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	await process_frame
	var emulated := InputEventScreenDrag.new()
	emulated.device = -1
	emulated.index = 0
	emulated.position = motion.position
	emulated.relative = motion.relative
	root.push_input(emulated, true)
	await process_frame
	assert(scroll.scroll_vertical == 120, "emulated touch must not double mouse scroll")
	await mouse(Vector2(150, 130), false)
	assert(scroll.scroll_vertical >= 100, "dragging button center scrolls content")
	assert(clicks == 0, "swipe must not press button")
	await mouse(Vector2(150, 180), true)
	await mouse(Vector2(150, 180), false)
	assert(clicks == 1, "tap after swipe still works")
	# Real touch events use the same ownership rule, without double mouse scrolling.
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(150, 300)
	touch.pressed = true
	root.push_input(touch, true)
	await process_frame
	var before := scroll.scroll_vertical
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(150, 220)
	drag.relative = Vector2(0, -80)
	root.push_input(drag, true)
	await process_frame
	touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(150, 220)
	root.push_input(touch, true)
	await process_frame
	assert(scroll.scroll_vertical - before == 80, "touch scroll applies movement exactly once")
	assert(clicks == 1, "touch swipe does not activate content")
	var next_press := InputEventMouseButton.new()
	next_press.device = -1
	next_press.button_index = MOUSE_BUTTON_LEFT
	next_press.pressed = true
	next_press.position = Vector2(150, 180)
	assert(not surface.router.handle(next_press, surface), "Android mouse press before next touch must not be swallowed after swipe")
	print("PASS touch and mouse center swipes, no accidental activation, subsequent tap")
	surface.queue_free()
	await process_frame
	await gameplay()
	quit()
func gameplay() -> void:
	var main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("layout_viewport_override", root.size)
	main.set_meta("disable_timed_battle_fx", true)
	root.add_child(main)
	current_scene = main
	main.touch_input_active = true
	main.pending_guided_run = false
	main._init_run("human", "human_elite")
	main.run_flow.prepare_battle("normal")
	var battle = main.battle_screen
	battle.player.hand.clear()
	for i in range(10):
		battle.player.hand.append(main.card_db.get_card("trainee_swordsman").duplicate(true))
	battle._ensure_hand_visual_slots()
	battle._refresh_ui()
	await create_timer(0.5).timeout
	var before: String = JSON.stringify([battle.player.hand, battle.player.field, battle.player.mana])
	await process_frame
	await process_frame
	var visible_hand: Rect2 = battle.hand_scroll.get_global_rect().intersection(main.root_scroll.get_global_rect())
	var point: Vector2 = visible_hand.get_center()
	var footer_before: Vector2 = battle.end_turn_button.global_position
	for button in [battle.end_turn_button, battle.race_power_button]:
		assert(button.size.y >= 52, "mobile battle actions have larger touch targets")
		assert(button.get_theme_font_size("font_size") >= 16, "mobile battle actions remain readable")
	assert(battle.detail_toggle_button.get_theme_font_size("font_size") == preload("res://src/ui/styles/ui_tokens.gd").BUTTON_FONT_COMPACT, "header action uses shared compact font")
	print("MOBILE FOOTER ", battle.end_turn_button.get_global_rect(), " viewport ", main._layout_viewport_size())
	assert(battle.end_turn_button.get_global_rect().end.y <= main._layout_viewport_size().y, "footer fits phone viewport")
	assert(not battle.hand_scroll.get_global_rect().intersects(battle.end_turn_button.get_global_rect()), "footer has separate space from scroll content")
	await mouse(point, true)
	var motion := InputEventMouseMotion.new()
	motion.position = point - Vector2(100, 0)
	motion.global_position = motion.position
	motion.relative = Vector2(-100, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	await process_frame
	await mouse(motion.position, false)
	assert(battle.hand_scroll.scroll_horizontal > 0, "swipe actual hand from its center")
	assert(not battle.is_dragging_hand_card, "mobile scrolling never starts card drag")
	assert(before == JSON.stringify([battle.player.hand, battle.player.field, battle.player.mana]), "hand swipe spends no cards or mana")
	# Vertical movement cancels a hand tap even without a scrollable ancestor.
	var board: ScrollContainer = battle.landscape_view.board_scroll
	await process_frame
	var board_before: int = board.scroll_vertical
	point = battle.hand_scroll.get_global_rect().intersection(main.root_scroll.get_global_rect()).get_center()
	await mouse(point, true)
	motion.position = point + Vector2(0, 80)
	motion.global_position = motion.position
	motion.relative = Vector2(0, 80)
	root.push_input(motion, true)
	await process_frame
	await mouse(motion.position, false)
	assert(board.scroll_vertical == board_before, "vertical hand swipe leaves both lanes fixed")
	board.scroll_vertical = 0
	var wheel := InputEventMouseButton.new()
	wheel.position = point
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	root.push_input(wheel, true)
	await process_frame
	assert(board.scroll_vertical == 0, "wheel never moves the fixed battlefield")
	assert(battle.end_turn_button.global_position.is_equal_approx(footer_before), "footer remains fixed during scrolling")
	assert(before == JSON.stringify([battle.player.hand, battle.player.field, battle.player.mana]), "vertical hand swipe preserves battle")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Storage.path_for("mobile-swiped-hand.png"))
	print("PASS actual mobile hand swipe and battle state preservation")
	battle.hand_scroll.scroll_horizontal = 0
	await process_frame
	await process_frame
	var first_card: Control = battle._hand_card_control(int(battle.player.hand[0].get("_hand_slot", 0)))
	battle.hand_scroll.ensure_control_visible(first_card)
	await process_frame
	point = first_card.get_global_rect().get_center()
	await mouse(point, true)
	await create_timer(0.5).timeout
	await mouse(point, false)
	assert(is_instance_valid(battle.landscape_view.card_dialog), "holding a hand card opens optional inspection")
	assert(before == JSON.stringify([battle.player.hand, battle.player.field, battle.player.mana]), "holding and releasing never uses the card")
	battle.landscape_view.close_detail()
	await process_frame
	await mouse(point, true)
	motion.position = point - Vector2(40, 0)
	motion.relative = Vector2(-40, 0)
	motion.global_position = motion.position
	root.push_input(motion, true)
	await create_timer(0.5).timeout
	await mouse(motion.position, false)
	assert(not is_instance_valid(battle.landscape_view.card_dialog), "scrolling cancels card inspection hold")
	assert(before == JSON.stringify([battle.player.hand, battle.player.field, battle.player.mana]), "held swipe does not use a card")
	print("PASS optional long press inspection and scroll cancellation")
	battle.player.hand = [main.card_db.get_card("trainee_swordsman").duplicate(true)]
	battle.player.mana = 10
	battle._ensure_hand_visual_slots()
	battle._refresh_ui()
	await process_frame
	await process_frame
	point = battle._hand_card_control(int(battle.player.hand[0].get("_hand_slot", 0))).get_global_rect().get_center()
	before = JSON.stringify([battle.player.hand, battle.player.field, battle.player.mana])
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = point
	touch.pressed = true
	root.push_input(touch, true)
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = point + Vector2(0, 9)
	drag.relative = Vector2(0, 9)
	root.push_input(drag, true)
	await create_timer(0.5).timeout
	touch.position = drag.position
	touch.pressed = false
	root.push_input(touch, true)
	await process_frame
	assert(not is_instance_valid(battle.landscape_view.card_dialog), "nine-pixel touch motion cancels hold without scroll overflow")
	assert(before == JSON.stringify([battle.player.hand, battle.player.field, battle.player.mana]), "nine-pixel touch motion never plays the single card")
	print("PASS non-scrollable hand touch cancellation")
	main._start_new_run()
	await create_timer(0.3).timeout
	for node in main.root_box.find_children("*", "Button", true, false):
		if node.text == "바로 시작 · 전략 고르기":
			assert(node.size.y >= 48, "quick-start action is finger sized")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Storage.path_for("mobile-selection.png"))
	print("PASS mobile selection touch target and dock reservation")
	main._clear_screen()
	assert(main.mobile_bottom_inset == 0.0, "leaving a screen clears its bottom reservation")
	main.queue_free()
	await process_frame
func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame
