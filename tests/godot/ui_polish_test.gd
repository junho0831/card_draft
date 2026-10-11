extends SceneTree

const Storage = preload("res://src/services/game_storage.gd")
const Tokens = preload("res://src/ui/styles/ui_tokens.gd")
const Styles = preload("res://src/ui/styles/ui_styles.gd")
const Cards = preload("res://src/ui/components/card_view.gd")
var failures: Array[String] = []
var count := 0

func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	create_timer(120).timeout.connect(func(): printerr("Polish test timed out"); quit(1))
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failures.append(message)

func settle() -> void:
	for frame in range(12): await process_frame
	await create_timer(0.15).timeout

func transformed_bounds(card: Control) -> Rect2:
	var rect := Rect2(card.get_global_transform() * Vector2.ZERO, Vector2.ZERO)
	for point in [Vector2(card.size.x, 0), card.size, Vector2(0, card.size.y)]:
		rect = rect.expand(card.get_global_transform() * point)
	return rect

func run() -> void:
	for type in ["unit", "spell", "equipment"]:
		var texture := load(Tokens.MATERIAL_PATH + "frame_%s.png" % type) as Texture2D
		var image := texture.get_image()
		if image.is_compressed(): image.decompress()
		check(image.get_pixel(image.get_width() / 2, image.get_height() / 2).a < 0.01, "frame leaves illustration transparent: " + type)
	for path in [Styles.BUTTON_GOLD_PATH, Styles.BUTTON_BLUE_PATH]:
		var image := Styles._load_texture(path).get_image()
		check(image.get_pixel(image.get_width() / 2, image.get_height() / 2).a > 0.9, "button center is solid after padding removal")
	check(Tokens.PRESS_DURATION <= 0.1 and Tokens.SELECTION_DURATION == 0.12, "shared feedback timing")
	var main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("disable_timed_battle_fx", true)
	root.add_child(main)
	main.pending_guided_run = false
	main.player_profile.learning_stage = 5
	var kinds := {"militia": "unit", "training_sword": "equipment", "first_aid": "support", "fireball": "damage", "vampiric_strike": "damage"}
	for id in kinds:
		var card: Dictionary = main.card_db.get_card(id)
		check(Cards.card_kind(card) == kinds[id], "shared category: " + id)
		var face := Cards.make_compact_offer(main, card, 96, 144)
		check(face.get_node("TypeIcon").texture.resource_path == "res://assets/ui/fantasy/type_%s.svg" % kinds[id], "shared card icon: " + id)
		face.free()
	for extent in [Vector2i(96, 144), Vector2i(132, 198), Vector2i(220, 330), Vector2i(284, 426)]:
		var card: Dictionary = main.card_db.get_card("forest_archer").duplicate(true)
		card.name = "왕국의 정예 궁수"
		var face := Cards.make_compact_offer(main, card, extent.x, extent.y)
		root.add_child(face)
		await settle()
		var art: Control = face.get_node("EconomyOfferArt")
		var title: Label = face.get_node("EconomyOfferName")
		var effect: Label = face.get_node("EconomyOfferEffect")
		check(art.size.y > 0 and art.get_rect().end.y <= title.position.y, "portrait and name do not overlap: " + str(extent))
		check(title.get_visible_line_count() == mini(2, title.get_line_count()), "measured Korean title is not clipped: " + str(extent))
		check(title.get_rect().end.y <= extent.y - 30, "title clears stat badges: " + str(extent))
		if effect.visible:
			check(effect.get_visible_line_count() == mini(2, effect.get_line_count()), "measured effect is not clipped: " + str(extent))
			check(effect.get_rect().end.y <= extent.y - 30, "effect clears stat badges: " + str(extent))
			check(art.size.y > extent.y * 0.5, "illustration remains larger than the lower plate")
		var rules_style: StyleBoxFlat = face.get_node("EconomyOfferRules").get_theme_stylebox("panel")
		check(rules_style.bg_color == Color(Tokens.SURFACE, 0.92), "rules use a restrained shared material")
		face.free()
	for dimensions in [Vector2i(844, 390), Vector2i(932, 430), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		main.set_meta("layout_viewport_override", dimensions)
		main.touch_input_active = dimensions.x < 1100
		main._apply_root_layout()
		await settle()
		main._init_run("human", "human_elite")
		main.run_flow.prepare_battle("normal")
		var battle = main.battle_screen
		battle.player.hand.clear()
		for i in range(10):
			var card: Dictionary = main.card_db.get_card("militia_plus" if i % 3 == 0 else "militia").duplicate(true)
			if i == 5: card.name = "아주 긴 한국어 이름을 가진 왕국의 기사"
			battle.player.hand.append(card)
		battle._ensure_hand_visual_slots()
		battle.player.mana = 10
		for field_count in [0, 1, 5]:
			for side in [battle.player, battle.opponent]:
				side.field.clear()
				for i in range(field_count):
					var unit: Dictionary = main.card_db.get_card("militia").duplicate(true)
					unit.merge({"battle_unit_id": i + (100 if side == battle.player else 200), "health": 3, "max_health": 3, "attack": 2, "can_attack": true}, true)
					side.field.append(unit)
			battle._refresh_ui()
			await settle()
			for hero in [battle.player_hero_target, battle.opponent_hero_target]:
				var medallion: Control = hero.get_node("HeroMedallion")
				check(is_equal_approx(medallion.size.x, medallion.size.y), "hero support is circular instead of stretched")
				check(medallion.get_theme_stylebox("panel").corner_radius_top_left >= medallion.size.x * 0.5, "hero support uses an actual circular border")
				check(hero.size.x >= 64 and hero.size.y >= 44, "hero keeps its wide tap target")
				check(hero.get_global_rect().encloses(hero.get_node("HeroHealthPlate").get_global_rect()), "hero health badge remains inside tap target")
				check(battle.landscape_view.board_scroll.get_global_rect().encloses(hero.get_global_rect()), "hero stays inside its lane")
			var target: Panel = battle.opponent_hero_target.get_node("TargetBorder")
			check(is_equal_approx(target.size.x, target.size.y) and target.get_theme_stylebox("panel").border_width_left == 3, "enemy target outline remains a thin circle")
			for slots in [battle.player_field_slots, battle.opponent_field_slots]:
				check(slots.size() == 5, "fixed five slots at " + str(dimensions))
				for slot in slots:
					check(slot.size.x >= 44 and slot.size.y >= 44, "field minimum touch size")
					check(battle.landscape_view.board_scroll.get_global_rect().encloses(slot.get_global_rect()), "both lanes stay visible")
					check(slot.size.x / slot.size.y <= 1.4, "field portraits are not flattened at " + str(dimensions))
					var button: Control = slot if slot is Button else slot.get_child(0)
					if button.has_node("Attack"):
						for badge_name in ["Attack", "Health"]:
							var badge: Control = button.get_node(badge_name)
							check(button.get_global_rect().encloses(badge.get_global_rect()), "field badge stays inside its card")
							check(badge.get_index() > button.get_node("RaceOrnaments").get_index(), "ornaments cannot cover field badges")
		var hand: Control = battle.hand_box.get_child(0)
		check(hand.size.x >= 96 and hand.size.y >= 144, "hand is never shrunk below portrait minimum")
		for card in battle.hand_box.get_children():
			check(absf(card.rotation_degrees) <= 7.01, "fan rotation limit")
		var last: Control = battle.hand_box.get_child(9)
		battle.selected_hand_slot = int(last.get_meta("hand_slot"))
		battle._layout_hand_cards()
		await settle()
		if battle.landscape_view.compact_board:
			var visible: Rect2 = battle.hand_scroll.get_global_rect().intersection(last.get_global_rect())
			check(visible.size.x >= 44 and visible.size.y >= 44, "folded hand keeps a usable tap target: " + str(dimensions))
			check(battle.hand_scroll.get_global_rect().grow(1).encloses(last.get_node("CardName").get_global_rect()), "folded hand name remains visible: " + str(dimensions))
		else:
			check(battle.hand_scroll.get_global_rect().grow(1).encloses(transformed_bounds(last)), "selected rotated card is completely visible: " + str(dimensions))
		var before := JSON.stringify(battle.battle_state)
		var saved := FileAccess.get_file_as_string(Storage.run_path())
		seed(73411)
		var expected := randi()
		seed(73411)
		battle.landscape_view.show_card(0)
		await settle()
		var viewer: Control = main.modal_layer.find_child("CardInspectionView", true, false)
		var scroll: Control = main.modal_layer.find_child("CardDetailScroll", true, false)
		check(viewer != null and not scroll.is_ancestor_of(viewer), "detail card is fixed outside description scroll")
		battle.landscape_view.close_detail()
		await settle()
		check(randi() == expected, "detail feedback preserves global RNG")
		check(JSON.stringify(battle.battle_state) == before, "detail feedback preserves battle state")
		check(FileAccess.get_file_as_string(Storage.run_path()) == saved, "detail feedback preserves saved run")
		if dimensions.x < 1100:
			var children: int = battle.battle_fx_layer.get_child_count()
			battle.battle_fx_layer._spawn_screen_flash(Color.WHITE, 1, 0.1)
			check(battle.battle_fx_layer.get_child_count() == children, "mobile never creates a full-screen flash")
			var relic: Dictionary = main._roll_relic_reward_choices(1)[0]
			main.current_run.gold = 999
			main.current_run.pending_shop = {"cards": ["fireball", "forest_archer", "training_sword"], "purchased_cards": [], "relic": relic, "relic_bought": false}
			main._show_shop()
			await settle()
			var shop = main.active_screen_controller
			var run_before := JSON.stringify(main.current_run)
			var save_before := FileAccess.get_file_as_string(Storage.run_path())
			var relic_offer: Button = null
			for candidate in main.root_box.find_children("*", "Button", true, false):
				if candidate.text == "%s · %d 골드" % [String(relic.name), main.shop_run_service.SHOP_RELIC_COST]: relic_offer = candidate
			check(relic_offer != null, "mobile relic has a tap target")
			seed(84212)
			var expected_rng := randi()
			seed(84212)
			if relic_offer != null:
				relic_offer.pressed.emit()
				await settle()
				check(is_instance_valid(shop.detail_overlay), "mobile relic effect opens before purchase")
				if is_instance_valid(shop.detail_overlay):
					var labels: Array[Node] = shop.detail_overlay.find_children("*", "Label", true, false)
					check(labels.any(func(label): return label.text == String(relic.text)), "mobile relic exposes complete effect without hover")
				shop._close_card_comparison()
				await settle()
				check(JSON.stringify(main.current_run) == run_before and FileAccess.get_file_as_string(Storage.run_path()) == save_before, "relic inspection and cancel preserve run/save")
				check(randi() == expected_rng, "relic inspection and cancel preserve RNG")
		else:
			main.current_run.gold = 999
			main.current_run.pending_shop = {"cards": ["fireball", "forest_archer", "training_sword"], "purchased_cards": [], "relic": {}}
			main._show_shop()
			await settle()
			var shop = main.active_screen_controller
			check(main.root_box.find_children("EconomyInspect_*", "Button", true, false).is_empty(), "desktop has no duplicate per-card confirmation buttons")
			var buy_width: float = shop.preview_buy.size.x
			var run_before := JSON.stringify(main.current_run)
			var save_before := FileAccess.get_file_as_string(Storage.run_path())
			seed(84129)
			var expected_rng := randi()
			seed(84129)
			for id in shop.offer_cards:
				shop._select_shop_card(id)
				await settle()
				check(shop.selected_card_id == id and not shop.preview_buy.disabled, "desktop selection feeds the fixed purchase action")
				check(is_equal_approx(shop.preview_buy.size.x, buy_width), "purchase action width stays fixed when selection changes")
				check(shop.offer_cards[id].get_node("EconomyOfferPrice").visible, "price remains outside the selected card")
			check(JSON.stringify(main.current_run) == run_before and FileAccess.get_file_as_string(Storage.run_path()) == save_before, "desktop selection preserves run and save")
			check(randi() == expected_rng, "desktop selection preserves RNG")
		main._show_map()
		await settle()
		var summary: Label = main.root_box.find_child("MapNodeSummary", true, false)
		check(summary.get_line_count() == 2 and summary.get_visible_line_count() == 2, "map exposes destination, risk and rewards on two lines")
		check(main.root_scroll.get_global_rect().grow(1).encloses(summary.get_global_rect()), "complete map summary is visible above the action dock at %s: %s inside %s" % [dimensions, summary.get_global_rect(), main.root_scroll.get_global_rect()])
	main.queue_free()
	await settle()
	for failure in failures: printerr(failure)
	print("%s UI polish: %d assertions, %d failures" % ["PASS" if failures.is_empty() else "FAIL", count, failures.size()])
	quit(0 if failures.is_empty() else 1)
