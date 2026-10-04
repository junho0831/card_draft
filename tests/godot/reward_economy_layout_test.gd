extends SceneTree

const Storage = preload("res://src/services/game_storage.gd")
var main
var count := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	count += 1
	if not ok:
		failures.append(message)

func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")

func settle() -> void:
	for frame in range(8):
		await process_frame
	await create_timer(0.15).timeout

func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(Storage.path_for(name + ".png")) == OK, "capture " + name)

func tap(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()

func verify_close_text(close: Button, prefix: String) -> void:
	var rect := close.get_global_rect()
	check(rect.size.x >= 96 and rect.size.y >= 44, prefix + " close actual rect is at least 96x44")
	var text_size := close.get_theme_font("font").get_string_size(close.text, HORIZONTAL_ALIGNMENT_LEFT, -1, close.get_theme_font_size("font_size"))
	var padding := close.get_theme_stylebox("normal").get_minimum_size()
	check(close.is_visible_in_tree() and close.text == "닫기" and not close.clip_text and text_size.x + padding.x <= rect.size.x and text_size.y + padding.y <= rect.size.y, prefix + " close label is visible and fits without clipping")
	print("CLOSE ", prefix, " rect=", rect, " text=", close.text, " glyph_size=", text_size)
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image_size := Vector2(root.get_texture().get_image().get_size())
	var logical_size := Vector2(root.content_scale_size)
	var pixel_scale := image_size / logical_size
	var crop := Rect2i(rect.position * pixel_scale, rect.size * pixel_scale)
	var with_text := root.get_texture().get_image().get_region(crop)
	close.text = ""
	await process_frame
	await RenderingServer.frame_post_draw
	var without_text := root.get_texture().get_image().get_region(crop)
	var changed_pixels := 0
	for y in range(crop.size.y):
		for x in range(crop.size.x):
			if with_text.get_pixel(x, y) != without_text.get_pixel(x, y):
				changed_pixels += 1
	close.text = "닫기"
	await settle()
	check(changed_pixels >= 20, prefix + " close label contributes visible rendered pixels")
	check(close.get_global_rect() == rect, prefix + " close geometry stays fixed during text visibility check")
	print("CLOSE TEXT PIXELS ", prefix, " ", changed_pixels)

func verify_comparison(comparison: Control, card: Dictionary, prefix: String) -> void:
	var expected: Dictionary = main._card_economy_comparison(card)
	check(comparison is VBoxContainer, prefix + " comparison uses structured controls")
	var builds: GridContainer = comparison.get_node("BuildRows")
	check(builds.get_child_count() == 4 + main._valid_build_tags().size() * 4, prefix + " all build rows exist")
	for tag in main._valid_build_tags():
		for side in ["Before", "After"]:
			var values: VBoxContainer = builds.get_node(String(tag) + side)
			var scores: Dictionary = expected.before_scores if side == "Before" else expected.after_scores
			var active: Array = expected.before_active if side == "Before" else expected.after_active
			check(values.get_node("Value").text == str(scores[tag]), prefix + " score matches " + String(tag) + side)
			check(values.get_node("State").text == ("활성" if active.has(tag) else "미활성"), prefix + " state matches " + String(tag) + side)
	for bucket in ["0-1", "2-3", "4+"]:
		for side in ["Before", "After"]:
			var costs: Dictionary = expected.before_costs if side == "Before" else expected.after_costs
			check(comparison.get_node("CostRows/" + bucket + side + "/Value").text == "%d장" % costs[bucket], prefix + " cost matches " + bucket + side)
	for grid in [builds, comparison.get_node("CostRows")]:
		for cell in grid.get_children():
			check(comparison.get_global_rect().encloses(cell.get_global_rect()), prefix + " comparison cell stays within bounds")
			for sibling in grid.get_children():
				if sibling != cell:
					check(not cell.get_global_rect().intersects(sibling.get_global_rect()), prefix + " comparison cells do not overlap")

func verify_action_labels(parent: Node, prefix: String) -> void:
	for button in parent.find_children("*", "Button", true, false):
		if not button.is_visible_in_tree() or not button.get_meta("economy_action", false):
			continue
		var rect: Rect2 = button.get_global_rect()
		var glyphs: Vector2 = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size"))
		var padding: Vector2 = button.get_theme_stylebox("normal").get_minimum_size()
		var minimum_width := 180 if button.get_meta("economy_primary", false) else 92
		check(rect.size.x >= minimum_width and rect.size.y >= 44, prefix + " usable button size: " + button.text)
		check(not button.text.is_empty() and glyphs.x > 0 and glyphs.x + padding.x <= rect.size.x + 1 and glyphs.y + padding.y <= rect.size.y + 1, prefix + " rendered label fits without clipping: " + button.text)

func verify_mobile_offers(prefix: String) -> void:
	var visible_rect: Rect2 = main.root_scroll.get_global_rect()
	var dock: Rect2 = main.active_screen_controller.screen_action_dock.get_global_rect()
	check(main.root_scroll.scroll_vertical == 0, prefix + " offers are checked on the first view")
	for id in ["fireball", "forest_archer", "training_sword"]:
		var face: Control = main.find_child("EconomyOffer_" + id, true, false)
		var rect := face.get_global_rect()
		if id == "fireball":
			print("FIRST VIEW ", prefix, " card=", rect, " visible=", visible_rect, " dock=", dock)
		check(visible_rect.encloses(rect) and not rect.intersects(dock), prefix + " entire card silhouette visible above dock: " + id)
		var title: Label = face.get_node("EconomyOfferName")
		check(rect.encloses(title.get_global_rect()) and title.get_line_count() <= 2 and title.get_visible_line_count() == title.get_line_count(), prefix + " complete card name fits within two lines: " + id)
		var stats: Label = face.get_node("EconomyOfferStats")
		var text_width := stats.get_theme_font("font").get_string_size(stats.text, HORIZONTAL_ALIGNMENT_LEFT, -1, stats.get_theme_font_size("font_size")).x
		check(rect.encloses(stats.get_global_rect()) and text_width <= stats.size.x, prefix + " card cost and stats fully visible: " + id)

func verify_relic_choices(dimensions: Vector2i) -> void:
	var relics: Array = main._roll_relic_reward_choices(3)
	main.current_run.pending_card_reward = {"choices": ["fireball", "forest_archer", "training_sword"], "gold_reward": 20, "relic_choices": relics, "selected_relic_id": ""}
	main._show_card_reward()
	await settle()
	var prefix := "relics-%dx%d" % [dimensions.x, dimensions.y]
	var panel: Control = main.find_child("EconomyRelicChoices", true, false)
	check(panel.get_global_rect().size.y <= 44, prefix + " relic choices use a single 44px row")
	var offers: Control = main.find_child("EconomyOffers", true, false)
	var visible_offers := offers.get_global_rect().intersection(main.root_scroll.get_global_rect())
	check(visible_offers.size.y >= 64, prefix + " card offers remain visible before scrolling")
	if dimensions.x < 1100:
		verify_mobile_offers(prefix)
	check(main.active_screen_controller.reference_claim.disabled, prefix + " card claim waits for relic selection")
	await capture(prefix)
	var row_y := -1.0
	for relic in relics:
		var button: Button = main.find_child("RelicChoice_" + String(relic.id), true, false)
		if row_y < 0:
			row_y = button.get_global_rect().position.y
		check(absf(button.get_global_rect().position.y - row_y) <= 1, prefix + " all relic choices share one row")
		check(main.root_scroll.get_global_rect().encloses(button.get_global_rect()), prefix + " relic button visible without scrolling")
		verify_action_labels(main.root_box, prefix)
		verify_action_labels(main.modal_layer, prefix)
		var selected_before: String = main.current_run.pending_card_reward.get("selected_relic_id", "")
		await tap(button)
		var overlay: Control = main.active_screen_controller.detail_overlay
		check(is_instance_valid(overlay), prefix + " relic opens readable detail")
		if not is_instance_valid(overlay):
			continue
		check(main.current_run.pending_card_reward.get("selected_relic_id", "") == selected_before, prefix + " inspecting relic does not select it")
		var labels := overlay.find_children("*", "Label", true, false)
		check(labels.any(func(label): return label.text == String(relic.get("text", ""))), prefix + " complete relic effect is in detail")
		verify_action_labels(overlay, prefix)
		await tap(overlay.find_child("EconomyDetailAction", true, false))
		check(main.current_run.pending_card_reward.selected_relic_id == String(relic.id), prefix + " confirmation persists selected relic")
		check(not main.active_screen_controller.reference_claim.disabled, prefix + " confirmed relic enables card claim")
		check(main.current_run.pending_card_reward.relic_choices == relics, prefix + " all relic choices are preserved")

func run() -> void:
	main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("disable_timed_battle_fx", true)
	root.add_child(main)
	main.pending_guided_run = false
	main.player_profile.learning_stage = 5
	main._init_run("human", "human_elite")
	for dimensions in [Vector2i(640, 360), Vector2i(844, 390), Vector2i(932, 430), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		main.set_meta("layout_viewport_override", Vector2(dimensions))
		main._apply_root_layout()
		await settle()
		for screen in ["shop", "reward"]:
			main.current_run.pending_shop = {"cards": ["fireball", "forest_archer", "training_sword"], "purchased_cards": [], "relic": {}}
			main.current_run.pending_card_reward = {"choices": ["fireball", "forest_archer", "training_sword"], "gold_reward": 20}
			main.call("_show_shop" if screen == "shop" else "_show_card_reward")
			await settle()
			print("GEOMETRY ", screen, " ", dimensions, " canvas=", main._layout_viewport_size(), " root=", main.root_box.get_global_rect())
			var prefix := "%s-%dx%d" % [screen, dimensions.x, dimensions.y]
			await capture(prefix)
			var controller = main.active_screen_controller
			verify_action_labels(main.root_box, prefix)
			verify_action_labels(main.modal_layer, prefix)
			if dimensions.x < 1100:
				verify_mobile_offers(prefix)
				var dock: Control = controller.screen_action_dock
				check(dock != null and Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(dock.get_global_rect()), prefix + " mobile footer stays visible")
				if screen == "reward":
					check(dock.get_global_rect().encloses(controller.reference_claim.get_global_rect()), prefix + " mobile confirm remains in footer")
			var offers: HBoxContainer = main.find_child("EconomyOffers", true, false)
			check(offers != null and offers.get_child_count() == 3, prefix + " has three centered offers")
			if offers != null:
				var first: Rect2 = offers.get_child(0).get_global_rect()
				var last: Rect2 = offers.get_child(2).get_global_rect()
				check(absf((first.position.x + last.end.x) * 0.5 - offers.get_global_rect().get_center().x) < 2, prefix + " offers are centered")
				check(first.position.x >= 0 and last.end.x <= dimensions.x, prefix + " all offers fit viewport width")
			if dimensions.x >= 1100:
				var action: Button = controller.preview_buy if screen == "shop" else controller.reference_claim
				var scroll: ScrollContainer = controller.preview_content.get_parent() if screen == "shop" else controller.reference_reason.get_parent().get_parent()
				var comparison: Control = controller.preview_content.get_node("EconomyComparison") if screen == "shop" else controller.reference_comparison
				verify_comparison(comparison, main.card_db.get_card(controller.selected_card_id), prefix + " preview")
				var initial: Rect2 = action.get_global_rect()
				check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(initial), prefix + " action is inside viewport")
				check(initial.size.y >= 44, prefix + " preview action has 44px touch target")
				check(not initial.intersects(scroll.get_global_rect()), prefix + " preview action does not overlap scroll")
				check(comparison.get_global_rect().size.x <= scroll.get_global_rect().size.x, prefix + " comparison fits preview width")
				if screen == "reward":
					check(controller.reference_reason is Label and not controller.reference_reason.text.contains("->"), prefix + " card role label remains separate")
				check(main.root_box.get_global_rect().end.y <= dimensions.y, prefix + " footer fits without page scrolling")
				for id in ["fireball", "forest_archer", "training_sword"]:
					controller.call("_select_shop_card" if screen == "shop" else "_select_reference_reward", id)
					await settle()
					comparison = controller.preview_content.get_node("EconomyComparison") if screen == "shop" else controller.reference_comparison
					verify_comparison(comparison, main.card_db.get_card(id), prefix + " selection " + id)
					check(action.get_global_rect() == initial, prefix + " selection keeps action fixed")
					check(comparison.get_global_rect().size.x <= scroll.get_global_rect().size.x, prefix + " selected comparison fits preview width")
					check(comparison.get_parent().find_children("EconomyComparison", "", false, false).size() == 1, prefix + " selection replaces previous comparison")
					if screen == "reward":
						check(controller.reference_reason.text.begins_with(main.card_db.get_card(id).name), prefix + " selected card role label updates")
					await capture(prefix + "-" + id + "-preview")
				scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
				await settle()
				check(action.get_global_rect() == initial, prefix + " scrolling does not move action")
				if not is_instance_valid(comparison):
					comparison = controller.preview_content.get_node("EconomyComparison") if screen == "shop" else controller.reference_comparison
				check(comparison.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1, prefix + " final cost bucket is reachable")
				await capture(prefix + "-comparison")
			if dimensions.x > 0:
				for id in ["fireball", "forest_archer", "training_sword"]:
					if dimensions.x < 1100:
						var inspect: Control = main.find_child("EconomyOffer_" + id, true, false)
						check(inspect != null, prefix + " has tap comparison for " + id)
						check(main.root_scroll.get_global_rect().encloses(inspect.get_global_rect()), prefix + " card tap needs no scrolling")
						await tap(inspect)
					else:
						controller._show_card_comparison(id)
						await settle()
					check(is_instance_valid(controller.detail_overlay), prefix + " tapping opens " + id)
					if not is_instance_valid(controller.detail_overlay):
						continue
					var action: Button = controller.detail_overlay.find_child("EconomyDetailAction", true, false)
					var scroll: ScrollContainer = controller.detail_overlay.find_child("EconomyDetailScroll", true, false)
					var comparison: Control = controller.detail_overlay.find_child("EconomyComparison", true, false)
					verify_comparison(comparison, main.card_db.get_card(id), prefix + " " + id)
					verify_action_labels(controller.detail_overlay, prefix + " detail")
					await capture(prefix + "-" + id + "-detail")
					var initial := action.get_global_rect()
					check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(initial), prefix + " modal action is visible")
					check(initial.size.y >= 44, prefix + " primary action is at least 44px")
					check(not initial.intersects(scroll.get_global_rect()), prefix + " action does not overlap scroll content")
					var close: Button = controller.detail_overlay.find_child("EconomyDetailClose", true, false)
					var close_initial := close.get_global_rect()
					check(not initial.intersects(close_initial), prefix + " action and close do not overlap")
					var panel: Control = controller.detail_overlay.find_child("EconomyDetailPanel", true, false)
					var panel_rect := panel.get_global_rect()
					var panel_style := panel.get_theme_stylebox("panel")
					var content_right := panel_rect.end.x - panel_style.get_margin(SIDE_RIGHT)
					var content_top := panel_rect.position.y + panel_style.get_margin(SIDE_TOP)
					var content_bottom := panel_rect.end.y - panel_style.get_margin(SIDE_BOTTOM)
					check(absf(close_initial.end.x - content_right) <= 1 and absf(close_initial.position.y - content_top) <= 1, prefix + " close occupies exact upper-right content corner")
					check(absf(initial.end.x - content_right) <= 1 and absf(initial.end.y - content_bottom) <= 1, prefix + " primary occupies exact lower-right content corner")
					check(close_initial.position.y < scroll.get_global_rect().position.y, prefix + " close is above scroll")
					check(initial.position.y >= scroll.get_global_rect().end.y, prefix + " purchase is below scroll")
					check(absf(close_initial.end.x - initial.end.x) <= 1, prefix + " close and purchase align right")
					check(panel.get_global_rect().encloses(initial) and panel.get_global_rect().encloses(close_initial), prefix + " fixed controls stay inside themed panel")
					scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
					await settle()
					check(action.get_global_rect() == initial, prefix + " modal action remains fixed")
					check(close.get_global_rect() == close_initial, prefix + " close remains fixed while scrolling")
					check(comparison.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1, prefix + " final cost row is reachable")
					if id == "fireball":
						await capture(prefix + "-detail-comparison")
					await verify_close_text(close, prefix + " " + id)
					await tap(close)
					check(not is_instance_valid(controller.detail_overlay), prefix + " close tap dismisses comparison")
			if screen == "shop":
				main.current_run.gold = 999
				controller._show_card_comparison("fireball")
				await settle()
				var deck_before: int = main.current_run.deck_ids.size()
				var gold_before: int = main.current_run.gold
				await tap(controller.detail_overlay.find_child("EconomyDetailAction", true, false))
				check(main.current_run.deck_ids.size() == deck_before + 1, prefix + " purchase tap adds one card")
				check(main.current_run.gold == gold_before - main.shop_run_service.SHOP_CARD_COST, prefix + " purchase uses existing price")
				check(main.modal_layer.find_child("EconomyDetailOverlay", true, false) == null, prefix + " purchase dismisses overlay")
			else:
				controller._show_card_comparison("forest_archer")
				await settle()
				var deck_before: int = main.current_run.deck_ids.size()
				var gold_before: int = main.current_run.gold
				await tap(controller.detail_overlay.find_child("EconomyDetailAction", true, false))
				check(main.current_run.deck_ids.size() == deck_before + 1, prefix + " reward confirm adds one card")
				check(main.current_run.gold == gold_before, prefix + " reward confirm does not duplicate victory gold")
				check(main.modal_layer.find_child("EconomyDetailOverlay", true, false) == null, prefix + " reward confirm dismisses overlay")
		await verify_relic_choices(dimensions)
	main.queue_free()
	await process_frame
	for failure in failures:
		printerr(failure)
	print("%s economy layout: %d assertions, %d failures" % ["PASS" if failures.is_empty() else "FAIL", count, failures.size()])
	quit(0 if failures.is_empty() else 1)
