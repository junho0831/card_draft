extends SceneTree

const Storage = preload("res://src/services/game_storage.gd")
const OFFER_IDS = ["fireball", "forest_archer", "training_sword"]
var main
var count := 0
var failures: Array[String] = []

func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	count += 1
	if not ok:
		failures.append(message)

func settle() -> void:
	for frame in range(8):
		await process_frame
	await create_timer(0.15).timeout

func tap(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()

func show_screen(screen: String, gold: int = 999, purchased: Array = [], with_relics: bool = false) -> void:
	main.current_run.gold = gold
	main.current_run.pending_shop = {"cards": OFFER_IDS.duplicate(), "purchased_cards": purchased.duplicate(), "relic": {}}
	var reward := {"choices": OFFER_IDS.duplicate(), "gold_reward": 20}
	if with_relics:
		reward["relic_choices"] = main._roll_relic_reward_choices(3)
		reward["selected_relic_id"] = ""
	main.current_run.pending_card_reward = reward
	main.call("_show_shop" if screen == "shop" else "_show_card_reward")
	await settle()

func verify_button(button: Button, prefix: String) -> void:
	var rect := button.get_global_rect()
	var glyphs := button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size"))
	var padding := button.get_theme_stylebox("normal").get_minimum_size()
	check(rect.size.x >= 44 and rect.size.y >= 44, prefix + " action keeps 44px target")
	check(not button.clip_text and glyphs.x + padding.x <= rect.size.x + 1 and glyphs.y + padding.y <= rect.size.y + 1, prefix + " action label fits: " + button.text)

func verify_selection(screen: String, prefix: String) -> void:
	var controller = main.active_screen_controller
	var cards: Dictionary = controller.offer_cards if screen == "shop" else controller.reference_cards
	var selected := 0
	for id in cards:
		var face: Control = cards[id]
		var marker: Control = face.get_node("EconomyOfferSelection")
		check(marker.visible == (id == controller.selected_card_id), prefix + " selection follows " + String(id))
		if marker.visible:
			selected += 1
			var badge: Control = marker.get_child(0)
			check(face.get_global_rect().encloses(badge.get_global_rect()), prefix + " selected corner fits card")
			check(marker.find_child("EconomyOfferCheck", true, false) != null, prefix + " selected corner has check label")
	check(selected == (0 if controller.selected_card_id.is_empty() else 1), prefix + " exactly one selected corner")

func verify_offers(screen: String, dimensions: Vector2i, prefix: String) -> void:
	var desktop := dimensions.x >= 1100
	var offers: Control = main.find_child("EconomyOffers", true, false)
	check(offers.get_child_count() == 3, prefix + " keeps three offers")
	var face_rects: Array[Rect2] = []
	for id in OFFER_IDS:
		var face: Control = main.find_child("EconomyOffer_" + id, true, false)
		var card: Dictionary = main.card_db.get_card(id)
		var rect := face.get_global_rect()
		face_rects.append(rect)
		check(rect.size.x >= 44 and rect.size.y >= 44, prefix + " card tap target: " + id)
		if desktop:
			var summaries := face.find_children("*", "Label", true, false)
			check(summaries.any(func(label): return label.text == main._card_effect_summary(card)), prefix + " desktop retains effect summary: " + id)
			continue
		check(main.root_scroll.get_global_rect().encloses(rect), prefix + " entire offer visible without scrolling: %s card=%s scroll=%s offset=%d" % [id, rect, main.root_scroll.get_global_rect(), main.root_scroll.scroll_vertical])
		check(not rect.intersects(main.active_screen_controller.screen_action_dock.get_global_rect()), prefix + " offer clears fixed dock: " + id)
		var art: TextureRect = face.get_node("EconomyOfferArt")
		check(art.get_global_rect().size.y > 60 and art.texture != null, prefix + " actual offer art exceeds 60px: " + id)
		check(rect.encloses(art.get_global_rect()), prefix + " complete art stays inside card: " + id)
		if id == OFFER_IDS[0]:
			print("OFFER ART ", prefix, " face=", rect.size, " art=", art.get_global_rect().size)
		var labels: Array[Control] = [art]
		for node_name in ["EconomyOfferName", "EconomyOfferStats", "EconomyOfferEffect"]:
			var label: Label = face.get_node(node_name)
			labels.append(label)
			check(label.is_visible_in_tree() and rect.encloses(label.get_global_rect()), prefix + " visible label inside card: " + node_name + id)
			check(label.get_visible_line_count() == label.get_line_count(), prefix + " sample label lines fit: " + node_name + id)
		var effect: Label = face.get_node("EconomyOfferEffect")
		check(effect.text == main._card_effect_summary(card) and not effect.text.is_empty(), prefix + " uses existing effect summary: " + id)
		var stats: Label = face.get_node("EconomyOfferStats")
		check(stats.text.begins_with("마나 %d" % int(card.cost)), prefix + " mana stays distinct from gold: " + id)
		check(stats.get_theme_font("font").get_string_size(stats.text, HORIZONTAL_ALIGNMENT_LEFT, -1, stats.get_theme_font_size("font_size")).x <= stats.size.x, prefix + " mana and unit stats fit: " + id)
		if screen == "shop":
			var price: Label = face.get_node("EconomyOfferPrice")
			labels.append(price)
			var expected := "%d 골드" % main.shop_run_service.SHOP_CARD_COST
			if main.current_run.pending_shop.purchased_cards.has(id):
				expected += " · 품절"
			elif int(main.current_run.gold) < main.shop_run_service.SHOP_CARD_COST:
				expected += " · 골드 부족"
			check(price.text == expected and price.is_visible_in_tree(), prefix + " actual price and availability: " + id)
			check(rect.encloses(price.get_global_rect()), prefix + " price fits card: " + id)
			check(price.get_theme_font("font").get_string_size(price.text, HORIZONTAL_ALIGNMENT_LEFT, -1, price.get_theme_font_size("font_size")).x <= price.size.x, prefix + " price and status text fit: " + id)
		for index in range(labels.size()):
			for other in range(index + 1, labels.size()):
				check(not labels[index].get_global_rect().intersects(labels[other].get_global_rect()), prefix + " card information never overlaps: %s %s=%s %s=%s" % [id, labels[index].name, labels[index].get_global_rect(), labels[other].name, labels[other].get_global_rect()])
	for index in range(face_rects.size() - 1):
		check(not face_rects[index].intersects(face_rects[index + 1]), prefix + " adjacent offers never overlap")
	verify_selection(screen, prefix)
	for parent in [main.root_box, main.modal_layer]:
		for button in parent.find_children("*", "Button", true, false):
			if button.is_visible_in_tree() and button.get_meta("economy_action", false):
				verify_button(button, prefix)

func verify_inspection(screen: String, dimensions: Vector2i, prefix: String) -> void:
	var controller = main.active_screen_controller
	var desktop := dimensions.x >= 1100
	var fixed: Button = controller.preview_buy if screen == "shop" and desktop else (controller.reference_inspect if screen == "shop" else controller.reference_claim)
	var fixed_rect := fixed.get_global_rect()
	var before := JSON.stringify(main.current_run)
	var saved_before := FileAccess.get_file_as_string(Storage.run_path())
	for id in OFFER_IDS:
		if desktop:
			controller.call("_select_shop_card" if screen == "shop" else "_select_reference_reward", id)
			await settle()
		else:
			await tap(main.find_child("EconomyOffer_" + id, true, false))
			check(is_instance_valid(controller.detail_overlay), prefix + " card tap opens comparison: " + id)
			if not is_instance_valid(controller.detail_overlay):
				continue
			var action: Button = controller.detail_overlay.find_child("EconomyDetailAction", true, false)
			var scroll: Control = controller.detail_overlay.find_child("EconomyDetailScroll", true, false)
			check(action.text.begins_with(String(main.card_db.get_card(id).name)), prefix + " modal confirmation names card: " + id)
			check(not action.get_global_rect().intersects(scroll.get_global_rect()), prefix + " modal confirm clears comparison")
			var unavailable: bool = screen == "shop" and (int(main.current_run.gold) < main.shop_run_service.SHOP_CARD_COST or main.current_run.pending_shop.purchased_cards.has(id))
			var waiting_for_relic: bool = screen == "reward" and not controller._relic_choice_ready(main.current_run.pending_card_reward)
			check(action.disabled == (unavailable or waiting_for_relic), prefix + " confirmation keeps existing availability rule: " + id)
			verify_button(action, prefix)
			await tap(controller.detail_overlay.find_child("EconomyDetailClose", true, false))
		check(controller.selected_card_id == id, prefix + " inspection updates existing selection")
		check(fixed.text.begins_with(String(main.card_db.get_card(id).name)), prefix + " fixed action names card: " + id)
		check(fixed.get_global_rect() == fixed_rect, prefix + " changing selection keeps fixed action geometry")
		verify_selection(screen, prefix)
		verify_button(fixed, prefix)
		if desktop:
			var comparison: Control = controller.preview_content.get_node("EconomyComparison") if screen == "shop" else controller.reference_comparison
			check(comparison.has_node("BuildRows") and comparison.has_node("CostRows"), prefix + " desktop retains build and mana comparisons")
	check(JSON.stringify(main.current_run) == before, prefix + " inspection leaves run data unchanged")
	check(FileAccess.get_file_as_string(Storage.run_path()) == saved_before, prefix + " inspection leaves saved data unchanged")
	main.root_scroll.scroll_vertical = int(main.root_scroll.get_v_scroll_bar().max_value)
	await settle()
	check(fixed.get_global_rect() == fixed_rect, prefix + " fixed action does not move when scrolling")

func run() -> void:
	main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("disable_timed_battle_fx", true)
	root.add_child(main)
	main.pending_guided_run = false
	main.player_profile.learning_stage = 5
	main._init_run("human", "human_elite")
	for dimensions in [Vector2i(844, 390), Vector2i(932, 430), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		main.set_meta("layout_viewport_override", Vector2(dimensions))
		main._apply_root_layout()
		await settle()
		for screen in ["shop", "reward"]:
			var prefix := "%s-%dx%d" % [screen, dimensions.x, dimensions.y]
			await show_screen(screen)
			var controller = main.active_screen_controller
			var recommended: Dictionary = controller._recommended_shop_card(main.current_run.pending_shop) if screen == "shop" else controller._recommended_reward_card(main.current_run.pending_card_reward)
			check(controller.selected_card_id == String(recommended.get("id", "")), prefix + " existing automatic selection is retained")
			verify_offers(screen, dimensions, prefix)
			await verify_inspection(screen, dimensions, prefix)
		if dimensions.x >= 1100:
			continue
		for state in [{"gold": 0, "purchased": []}, {"gold": 999, "purchased": ["fireball"]}, {"gold": 0, "purchased": OFFER_IDS}]:
			var prefix := "shop-state-%dx%d-%d-%d" % [dimensions.x, dimensions.y, state.gold, state.purchased.size()]
			await show_screen("shop", state.gold, state.purchased)
			verify_offers("shop", dimensions, prefix)
			await verify_inspection("shop", dimensions, prefix)
		await show_screen("reward", 999, [], true)
		verify_offers("reward", dimensions, "reward-with-relics")
		check(main.active_screen_controller.reference_claim.disabled, "reward waits for the existing relic confirmation")
		await verify_inspection("reward", dimensions, "reward-with-relics")
	main._clear_screen()
	main.queue_free()
	await process_frame
	for failure in failures:
		printerr(failure)
	print("%s economy offer visibility: %d assertions, %d failures" % ["PASS" if failures.is_empty() else "FAIL", count, failures.size()])
	quit(0 if failures.is_empty() else 1)
