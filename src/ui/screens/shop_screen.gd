extends RefCounted
class_name ShopScreen

const Fantasy = preload("res://src/ui/fantasy_components.gd")
var selected_card_id := ""
var preview_box: VBoxContainer
var main: Node
var screen_action_dock: PanelContainer = null

func _init(_main: Node) -> void:
	main = _main

func _is_tight_shop_layout() -> bool:
	return not _is_shop_compact_layout() and main._layout_viewport_size().y <= 760.0

func _is_shop_compact_layout() -> bool:
	return main._layout_viewport_size().x < 1000.0

func build(body: VBoxContainer) -> void:
	if main._layout_viewport_size().x >= 1100:
		_build_reference_shop(body)
		return
	var shop_state: Dictionary = main.current_run.get("pending_shop", {})
	var compact: bool = _is_shop_compact_layout()
	var phone_portrait: bool = main._is_phone_portrait_layout()
	var viewport_size: Vector2 = main._layout_viewport_size()
	var action_dock_layout: bool = phone_portrait or (viewport_size.x > viewport_size.y and viewport_size.y <= 800.0)
	if not action_dock_layout:
		body.add_child(main._make_run_summary_panel())
	body.add_child(main.ui.make_guidance_banner("다음 행동", "골드로 카드를 강화하거나 덱을 정리하세요", Color(0.2, 0.18, 0.12, 1.0), compact))
	body.add_child(_make_shop_status_strip(compact))

	var hub: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	hub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub.add_theme_constant_override("separation", 10)
	body.add_child(hub)

	if not action_dock_layout:
		hub.add_child(_make_shop_summary_panel(compact))

	var products_panel: PanelContainer = main.ui.make_surface_panel(Color(0.07, 0.08, 0.1, 1.0), Color(0.2, 0.17, 0.11, 1.0), 1, 12, 14)
	products_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub.add_child(products_panel)
	var products_box := VBoxContainer.new()
	products_box.add_theme_constant_override("separation", 7)
	products_panel.add_child(products_box)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	products_box.add_child(title_row)
	var title: Label = main._make_label("상점", 20 if compact else 23, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var gold: Label = main._make_label("골드 %d" % int(main.current_run.get("gold", 0)), 14 if compact else 16, Color(1.0, 0.86, 0.44, 1.0))
	gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold.autowrap_mode = TextServer.AUTOWRAP_OFF
	gold.custom_minimum_size = Vector2(96, 0)
	title_row.add_child(gold)
	var subtitle: Label = main._make_label("카드와 유물을 골라 덱을 강화하세요.", 12 if compact else 13, Color(0.82, 0.86, 0.92, 1.0))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	products_box.add_child(subtitle)
	var product_row: BoxContainer = main.ui.make_responsive_box(compact, 10)
	product_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	products_box.add_child(product_row)
	for card_id in shop_state.get("cards", []):
		var card: Dictionary = main.card_db.get_card(String(card_id))
		if card.is_empty():
			continue
		product_row.add_child(_make_shop_card_product(card, shop_state, compact))

	var relic: Dictionary = shop_state.get("relic", {})
	if not relic.is_empty():
		product_row.add_child(_make_shop_relic_product(relic, shop_state, compact))

	if action_dock_layout:
		if phone_portrait:
			hub.add_child(_make_shop_service_panel(shop_state, compact))
		_mount_shop_action_dock(body, shop_state)
	else:
		hub.add_child(_make_shop_service_panel(shop_state, compact))

func _mount_shop_action_dock(body: VBoxContainer, shop_state: Dictionary) -> void:
	var dock: Dictionary = main.ui.mount_screen_action_dock(
		main,
		body,
		"상품을 눌러 구매",
		"정비 서비스는 상품 아래에 있습니다.",
		Color(0.78, 0.55, 0.2, 1.0),
		126
	)
	screen_action_dock = dock.get("panel") as PanelContainer
	var actions: BoxContainer = dock.get("actions") as BoxContainer
	if main._is_phone_portrait_layout():
		for entry in [["덱 보기", Callable(main, "_show_collection")], ["상점 나가기", Callable(self, "_leave_shop")]]:
			var button: Button = main.ui.make_dock_action_button(entry[0], "", Color(0.18, 0.42, 0.66), entry[0] == "상점 나가기", 152)
			button.pressed.connect(entry[1])
			actions.add_child(button)
		return
	var recommended_card := _recommended_shop_card(shop_state)
	if not recommended_card.is_empty():
		var buy_button: Button = main.ui.make_dock_action_button("추천 카드 구매 ▶", "%s · 골드 %d" % [String(recommended_card.get("name", "카드")), main.shop_run_service.SHOP_CARD_COST], Color(0.48, 0.32, 0.1, 1.0), true, 224)
		buy_button.disabled = int(main.current_run.get("gold", 0)) < main.shop_run_service.SHOP_CARD_COST
		buy_button.pressed.connect(Callable(self, "_buy_shop_card").bind(String(recommended_card.get("id", ""))))
		actions.add_child(buy_button)
	var leave_button: Button = main.ui.make_dock_action_button("상점 나가기 ▶", "다음 노드로 이동", Color(0.18, 0.42, 0.66, 1.0), true, 188)
	leave_button.pressed.connect(Callable(self, "_leave_shop"))
	actions.add_child(leave_button)

	var heal_button: Button = main.ui.make_dock_action_button("체력 회복", "골드 %d · 체력 +20" % main.shop_run_service.SHOP_HEAL_COST, Color(0.18, 0.42, 0.24, 1.0), false, 180)
	heal_button.disabled = int(main.current_run.get("gold", 0)) < main.shop_run_service.SHOP_HEAL_COST or int(main.current_run.get("hp", 0)) >= int(main.current_run.get("max_hp", 50))
	heal_button.pressed.connect(Callable(self, "_buy_shop_heal"))
	actions.add_child(heal_button)

	var remove_cost := _shop_remove_cost()
	var remove_button: Button = main.ui.make_dock_action_button("카드 제거", "골드 %d · 덱 압축" % remove_cost, Color(0.42, 0.2, 0.18, 1.0), false, 180)
	remove_button.disabled = int(main.current_run.get("gold", 0)) < remove_cost or (main.current_run.get("deck_ids", []) as Array).is_empty()
	remove_button.pressed.connect(Callable(self, "_begin_shop_remove"))
	actions.add_child(remove_button)

	var deck_button: Button = main.ui.make_dock_action_button("덱 확인", "카드와 빌드 보기", Color(0.16, 0.28, 0.44, 1.0), false, 166)
	deck_button.pressed.connect(Callable(main, "_show_collection"))
	actions.add_child(deck_button)

func _recommended_shop_card(shop_state: Dictionary) -> Dictionary:
	var purchased_cards: Array = shop_state.get("purchased_cards", [])
	for card_id_variant in shop_state.get("cards", []):
		var card_id := String(card_id_variant)
		if purchased_cards.has(card_id):
			continue
		var card: Dictionary = main.card_db.get_card(card_id)
		if not card.is_empty():
			return card
	return {}

func _make_shop_status_strip(compact: bool) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.07, 0.08, 0.1, 0.98), Color(0.22, 0.18, 0.12, 1.0), 1, 12, 12)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HFlowContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	row.add_child(main.ui.make_chip("현재 골드 %d" % int(main.current_run.get("gold", 0)), Color(0.34, 0.24, 0.08, 1.0), Color(1.0, 0.9, 0.62, 1.0), 13 if compact else 14))
	row.add_child(main.ui.make_chip("덱 %d장" % (main.current_run.get("deck_ids", []) as Array).size(), Color(0.12, 0.2, 0.32, 1.0), Color(0.88, 0.92, 1.0, 1.0), 13 if compact else 14))
	row.add_child(main.ui.make_chip("추천 %s" % _shop_guidance_text(), Color(0.16, 0.18, 0.1, 1.0), Color(0.96, 0.94, 0.82, 1.0), 13 if compact else 14))
	return panel

func _make_shop_summary_panel(compact: bool) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.08, 0.09, 0.11, 0.96), Color(0.16, 0.18, 0.23, 1.0), 1, 12, 14)
	panel.custom_minimum_size = Vector2(0 if compact else 185, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title: Label = main._make_label("보유 자원", 17 if compact else 18, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	box.add_child(_make_resource_card("골드", "%d" % int(main.current_run.get("gold", 0)), "골드", Color(0.42, 0.3, 0.08, 1.0), compact))
	box.add_child(_make_resource_card("체력", "%d / %d" % [int(main.current_run.get("hp", 0)), int(main.current_run.get("max_hp", 50))], "HP", Color(0.34, 0.14, 0.14, 1.0), compact))
	box.add_child(_make_resource_card("덱", "%d장" % (main.current_run.get("deck_ids", []) as Array).size(), "덱", Color(0.12, 0.22, 0.34, 1.0), compact))
	box.add_child(HSeparator.new())
	box.add_child(main.ui.make_chip("우선순위: 핵심 카드 확보 -> 제거 -> 회복", Color(0.16, 0.16, 0.1, 1.0), Color(0.96, 0.94, 0.82, 1.0), 12 if compact else 13))
	var hint: Label = main._make_label("강화할지, 골드를 아낄지 선택하세요.", 12 if compact else 13, Color(0.82, 0.86, 0.92, 1.0))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(hint)
	return panel

func _make_shop_service_panel(shop_state: Dictionary, compact: bool) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.08, 0.09, 0.11, 0.96), Color(0.22, 0.19, 0.11, 1.0), 1, 12, 14)
	panel.custom_minimum_size = Vector2(0 if compact else 210, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title: Label = main._make_label("정비", 17 if compact else 18, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	box.add_child(main.ui.make_chip("덱 압축과 생존 정비", Color(0.16, 0.16, 0.1, 1.0), Color(0.96, 0.94, 0.82, 1.0), 12 if compact else 13))

	var remove_cost := _shop_remove_cost()
	var remove_button: Button = _make_service_button("카드 제거", "골드 %d\n덱에서 카드 1장 제거" % remove_cost, Color(0.34, 0.18, 0.16, 1.0), compact)
	remove_button.disabled = int(main.current_run.get("gold", 0)) < remove_cost or (main.current_run.get("deck_ids", []) as Array).is_empty()
	remove_button.pressed.connect(Callable(self, "_begin_shop_remove"))
	box.add_child(remove_button)

	var heal_button: Button = _make_service_button("체력 회복", "골드 %d\n체력 20 회복" % main.shop_run_service.SHOP_HEAL_COST, Color(0.18, 0.4, 0.24, 1.0), compact)
	heal_button.disabled = int(main.current_run.get("gold", 0)) < main.shop_run_service.SHOP_HEAL_COST or int(main.current_run.get("hp", 0)) >= int(main.current_run.get("max_hp", 50))
	heal_button.pressed.connect(Callable(self, "_buy_shop_heal"))
	box.add_child(heal_button)

	var deck_button: Button = _make_service_button("덱 확인", "현재 덱 구성과 빌드 태그 확인", Color(0.16, 0.22, 0.32, 1.0), compact)
	deck_button.pressed.connect(Callable(main, "_show_collection"))
	box.add_child(deck_button)

	var leave_button: Button = _make_service_button("나가기 ▶", "상점을 마치고 다음 노드로 이동", Color(0.18, 0.34, 0.48, 1.0), compact)
	main.ui.style_primary_button(leave_button, Color(0.18, 0.34, 0.48, 1.0))
	leave_button.pressed.connect(Callable(self, "_leave_shop"))
	box.add_child(leave_button)
	return panel

func _make_resource_card(title: String, value: String, icon: String, color: Color, compact: bool) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(color, color.lightened(0.18), 1, 8, 8)
	panel.custom_minimum_size = Vector2(0, 50 if compact else 56)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var icon_label: Label = main._make_label(icon, 15 if compact else 17, Color(1.0, 0.9, 0.58, 1.0))
	icon_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(icon_label)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)
	var title_label: Label = main._make_label(title, 11 if compact else 12, Color(0.78, 0.82, 0.88, 1.0))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	text_box.add_child(title_label)
	var value_label: Label = main._make_label(value, 15 if compact else 17, Color(1.0, 0.92, 0.62, 1.0))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	text_box.add_child(value_label)
	return panel

func _make_service_button(title: String, detail: String, color: Color, compact: bool) -> Button:
	var icon := "상품"
	if title.begins_with("카드"):
		icon = "⌫"
	elif title.begins_with("체력"):
		icon = "회복"
	elif title.begins_with("덱"):
		icon = "덱"
	elif title.begins_with("나가기"):
		icon = "➜"
	var button: Button = main.ui.make_large_action_button(title, detail, icon, color, compact)
	button.custom_minimum_size = Vector2(0, 62 if compact else 70)
	return button

func _make_shop_card_product(card: Dictionary, shop_state: Dictionary, compact: bool) -> Control:
	var tight: bool = _is_tight_shop_layout()
	var frame: PanelContainer = main.ui.make_race_card_panel(card, 10, 2, 0.08)
	frame.custom_minimum_size = Vector2(160 if tight else (154 if compact else 182), 0)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4 if tight else 5)
	frame.add_child(inner)
	inner.add_child(main.ui.make_card_face(main, card, "shop", {
		"compact": compact,
		"tight": tight,
		"art_size": Vector2(142, 150) if tight else (Vector2(132, 120) if compact else Vector2(154, 170)),
		"include_stats": true,
		"summary_text": main._card_effect_summary(card),
		"show_detail": false,
		"rules_min_height": 30.0,
	}))
	inner.add_child(main.ui.make_chip("골드 %d" % main.shop_run_service.SHOP_CARD_COST, Color(0.38, 0.26, 0.08, 1.0), Color(1.0, 0.86, 0.46, 1.0), 12))
	var tag_text: String = main._format_card_tag_text(card)
	if not tag_text.is_empty():
		var tag_label: Label = main._make_label(tag_text, 10 if tight else 11, Color(1.0, 0.82, 0.56, 1.0))
		tag_label.clip_text = true
		inner.add_child(tag_label)
	var button := Button.new()
	button.text = "구매 ▶"
	button.custom_minimum_size = Vector2(120, 36)
	main.ui.style_role_button(button, "primary", Color(0.96, 0.74, 0.3, 1.0), Color(0.24, 0.18, 0.07, 1.0), 14)
	button.disabled = int(main.current_run.get("gold", 0)) < main.shop_run_service.SHOP_CARD_COST or (shop_state.get("purchased_cards", []) as Array).has(String(card.get("id", "")))
	button.pressed.connect(Callable(self, "_buy_shop_card").bind(String(card.get("id", ""))))
	inner.add_child(button)
	if button.disabled:
		frame.modulate = Color(0.58, 0.6, 0.64, 0.78)
	return frame

func _shop_guidance_text() -> String:
	var scores: Dictionary = main._current_build_scores()
	var primary: String = main._primary_build_tag(scores)
	if primary.is_empty():
		return "기본 전력 확보"
	var meta: Dictionary = main._build_tag_meta().get(primary, {})
	return "%s %s 시너지 우선" % [String(meta.get("icon", "")), String(meta.get("name", ""))]

func _make_shop_relic_product(relic: Dictionary, shop_state: Dictionary, compact: bool) -> Control:
	var tight: bool = _is_tight_shop_layout()
	var relic_meta: Dictionary = main.ui.relic_visual_meta(relic)
	var accent: Color = relic_meta["accent"]
	var frame: PanelContainer = main.ui.make_surface_panel(Color(0.12, 0.1, 0.14, 1.0), accent, 2, 8, 10)
	frame.custom_minimum_size = Vector2(160 if tight else (154 if compact else 182), 0)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	frame.add_child(box)
	box.add_child(main.ui.make_relic_badge(relic, compact))
	box.add_child(main.ui.make_chip("골드 %d" % main.shop_run_service.SHOP_RELIC_COST, Color(0.34, 0.23, 0.08, 1.0), Color(1.0, 0.86, 0.46, 1.0), 12))
	var relic_text: Label = main._make_label(String(relic.get("text", "")), 11 if tight else (12 if compact else 13), Color(0.9, 0.86, 0.98, 1.0))
	relic_text.custom_minimum_size = Vector2(0, 58 if tight else 64)
	relic_text.clip_text = true
	box.add_child(relic_text)
	var relic_tags: Array[String] = main._relic_build_tags(relic)
	if not relic_tags.is_empty():
		var tag_names: Array[String] = []
		for tag in relic_tags:
			var meta: Dictionary = main._build_tag_meta().get(tag, {})
			tag_names.append("%s %s" % [String(meta.get("icon", "")), String(meta.get("name", ""))])
		var relic_tag_label: Label = main._make_label(" / ".join(tag_names), 10 if tight else 11, Color(1.0, 0.82, 0.56, 1.0))
		relic_tag_label.clip_text = true
		box.add_child(relic_tag_label)
		var promise: PanelContainer = main.ui.make_chip(main._choice_playstyle_text(relic), Color(0.12, 0.18, 0.24, 1.0), Color(0.84, 0.94, 1.0, 1.0), 10 if tight else 11)
		box.add_child(promise)
	var button := Button.new()
	button.text = "유물 구매 ▶"
	button.custom_minimum_size = Vector2(120, 34)
	main.ui.style_button(button, Color(0.38, 0.3, 0.14, 1.0))
	button.disabled = int(main.current_run.get("gold", 0)) < main.shop_run_service.SHOP_RELIC_COST or bool(shop_state.get("relic_bought", false))
	button.pressed.connect(Callable(self, "_buy_shop_relic"))
	box.add_child(button)
	if button.disabled:
		frame.modulate = Color(0.58, 0.6, 0.64, 0.78)
	return frame

func _shop_remove_cost() -> int:
	return main.shop_run_service.remove_cost(main.current_run.get("pending_shop", {}))

func _buy_shop_card(card_id: String) -> void:
	if main.audio_manager != null:
		main.audio_manager.play_sound("click")
	var result: Dictionary = main.shop_run_service.buy_card(main.current_run, card_id)
	if not bool(result.get("ok", false)):
		return
	main._save_run()
	main._show_shop()

func _buy_shop_relic() -> void:
	if main.audio_manager != null:
		main.audio_manager.play_sound("click")
	var result: Dictionary = main.shop_run_service.buy_relic(main.current_run, Callable(main.relic_service, "apply_on_acquire"))
	if not bool(result.get("ok", false)):
		return
	main._save_run()
	main._show_shop()

func _begin_shop_remove() -> void:
	if main.audio_manager != null:
		main.audio_manager.play_sound("click")
	var result: Dictionary = main.shop_run_service.begin_remove(main.current_run)
	if not bool(result.get("ok", false)):
		return
	main._save_run()
	main._show_remove_card_screen(String(result.get("reason", "상점")), String(result.get("source", "shop")))

func _buy_shop_heal() -> void:
	if main.audio_manager != null:
		main.audio_manager.play_sound("click")
	var result: Dictionary = main.shop_run_service.buy_heal(main.current_run)
	if not bool(result.get("ok", false)):
		return
	main._save_run()
	main._show_shop()

func _leave_shop() -> void:
	if main.audio_manager != null:
		main.audio_manager.play_sound("click")
	main.run_flow.leave_shop()

func _build_reference_shop(body: VBoxContainer) -> void:
	var state: Dictionary = main.current_run.get("pending_shop", {})
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)
	var merchant := VBoxContainer.new()
	merchant.custom_minimum_size = Vector2(245, 480)
	merchant.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(merchant)
	var speech := Fantasy.panel(main, "바렌 · 전장의 상인")
	merchant.add_child(speech.get_meta("frame"))
	speech.add_child(main._make_label("좋은 장비는 더 긴 이야기를
만들지. 무엇이 필요한가?", 15, Color(0.86, 0.85, 0.78)))
	var stock := VBoxContainer.new()
	stock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stock.add_theme_constant_override("separation", 12)
	row.add_child(stock)
	stock.add_child(Fantasy.heading(main, "⚜  카드 구매", 21))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 10)
	stock.add_child(cards)
	for id in state.get("cards", []):
		var card: Dictionary = main.card_db.get_card(String(id))
		var stack := VBoxContainer.new()
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.add_child(stack)
		var face := Fantasy.card(main, card, 145, 240)
		stack.add_child(face)
		Fantasy.clickable_card(face, _select_shop_card.bind(String(id)))
		var pick := Fantasy.action(main, "확인 · %d 골드" % main.shop_run_service.SHOP_CARD_COST, _select_shop_card.bind(String(id)), false)
		pick.add_theme_font_size_override("font_size", 13)
		pick.custom_minimum_size.y = 38
		stack.add_child(pick)
	var services := HBoxContainer.new()
	services.add_theme_constant_override("separation", 10)
	stock.add_child(services)
	var relic: Dictionary = state.get("relic", {})
	if not relic.is_empty():
		var relic_box := Fantasy.panel(main, "유물 · " + String(relic.get("name", "")))
		var relic_frame: Control = relic_box.get_meta("frame")
		relic_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		services.add_child(relic_frame)
		relic_box.add_child(main._make_label(String(relic.get("text", "")), 14, Color(0.86, 0.85, 0.92)))
		var buy_relic := Fantasy.action(main, "%d 골드 · 유물 구매" % main.shop_run_service.SHOP_RELIC_COST, _buy_shop_relic)
		buy_relic.disabled = int(main.current_run.gold) < main.shop_run_service.SHOP_RELIC_COST or bool(state.get("relic_bought", false))
		relic_box.add_child(buy_relic)
	var service_box := Fantasy.panel(main, "서비스", 190)
	services.add_child(service_box.get_meta("frame"))
	service_box.add_child(Fantasy.action(main, "카드 제거 · %d" % _shop_remove_cost(), _begin_shop_remove, false))
	var heal := Fantasy.action(main, "회복 · %d" % main.shop_run_service.SHOP_HEAL_COST, _buy_shop_heal, false)
	heal.disabled = int(main.current_run.gold) < main.shop_run_service.SHOP_HEAL_COST or int(main.current_run.hp) >= int(main.current_run.max_hp)
	service_box.add_child(heal)
	preview_box = Fantasy.panel(main, "선택한 카드", 238)
	row.add_child(preview_box.get_meta("frame"))
	var recommended := _recommended_shop_card(state)
	_select_shop_card(String(recommended.get("id", "")))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	body.add_child(footer)
	var resources := Fantasy.heading(main, "골드 %d    ·    현재 덱 %d장    ·    보유 유물 %d개" % [main.current_run.gold, main.current_run.deck_ids.size(), main.current_run.relic_ids.size()], 18)
	resources.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(resources)
	footer.add_child(Fantasy.action(main, "덱 보기", Callable(main, "_show_collection"), false))
	footer.add_child(Fantasy.action(main, "나가기  ❯", _leave_shop, false))

func _select_shop_card(card_id: String) -> void:
	selected_card_id = card_id
	for child in preview_box.get_children():
		preview_box.remove_child(child)
		child.queue_free()
	var card: Dictionary = main.card_db.get_card(card_id)
	if card.is_empty():
		preview_box.add_child(Fantasy.heading(main, "카드를 모두 구매했습니다", 17))
		return
	preview_box.add_child(Fantasy.card(main, card, 202, 345, true))
	preview_box.add_child(main._make_label("구매 시 덱에 추가됩니다.", 13, Color(0.8, 0.83, 0.87)))
	var buy := Fantasy.action(main, "%d 골드   구매" % main.shop_run_service.SHOP_CARD_COST, _buy_shop_card.bind(card_id))
	buy.disabled = int(main.current_run.gold) < main.shop_run_service.SHOP_CARD_COST or main.current_run.pending_shop.get("purchased_cards", []).has(card_id)
	preview_box.add_child(buy)
