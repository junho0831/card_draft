extends RefCounted
class_name ShopScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func _is_tight_shop_layout() -> bool:
	return not _is_shop_compact_layout() and main._layout_viewport_size().y <= 760.0

func _is_shop_compact_layout() -> bool:
	return main._is_compact_layout_for(1360.0, 900.0)

func build(body: VBoxContainer) -> void:
	var shop_state: Dictionary = main.current_run.get("pending_shop", {})
	var compact: bool = _is_shop_compact_layout()
	body.add_child(main._make_run_summary_panel())
	body.add_child(main.ui.make_guidance_banner("다음 행동", "골드로 카드를 강화하거나 덱을 정리하세요", Color(0.2, 0.18, 0.12, 1.0), compact))
	body.add_child(_make_shop_status_strip(compact))

	var hub: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	hub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub.add_theme_constant_override("separation", 10)
	body.add_child(hub)

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
	var subtitle: Label = main._make_label("카드와 유물을 구매하거나 오른쪽에서 덱을 정비하세요.", 12 if compact else 13, Color(0.82, 0.86, 0.92, 1.0))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	products_box.add_child(subtitle)
	products_box.add_child(main.ui.make_objective_panel("상점 목표", "현재 빌드에 맞는 카드나 유물을 고르고, 필요하면 덱을 압축하세요.", compact))
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

	hub.add_child(_make_shop_service_panel(shop_state, compact))

func _make_shop_status_strip(compact: bool) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.07, 0.08, 0.1, 0.98), Color(0.22, 0.18, 0.12, 1.0), 1, 12, 12)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
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
	box.add_child(_make_resource_card("골드", "%d" % int(main.current_run.get("gold", 0)), "●", Color(0.42, 0.3, 0.08, 1.0), compact))
	box.add_child(_make_resource_card("체력", "%d / %d" % [int(main.current_run.get("hp", 0)), int(main.current_run.get("max_hp", 50))], "♥", Color(0.34, 0.14, 0.14, 1.0), compact))
	box.add_child(_make_resource_card("덱", "%d장" % (main.current_run.get("deck_ids", []) as Array).size(), "▣", Color(0.12, 0.22, 0.34, 1.0), compact))
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
	var icon := "◆"
	if title.begins_with("카드"):
		icon = "⌫"
	elif title.begins_with("체력"):
		icon = "♥"
	elif title.begins_with("덱"):
		icon = "▣"
	elif title.begins_with("나가기"):
		icon = "➜"
	var button: Button = main.ui.make_large_action_button(title, detail, icon, color, compact)
	button.custom_minimum_size = Vector2(0, 62 if compact else 70)
	return button

func _make_shop_card_product(card: Dictionary, shop_state: Dictionary, compact: bool) -> Control:
	var tight: bool = _is_tight_shop_layout()
	var frame: PanelContainer = main.ui.make_surface_panel(Color(0.07, 0.07, 0.065, 1.0), Color(0.68, 0.48, 0.16, 1.0), 2, 8, 10)
	frame.custom_minimum_size = Vector2(160 if tight else (154 if compact else 182), 0)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4 if tight else 5)
	frame.add_child(inner)
	var type_label: Label = main._make_label("%s / %s" % [main.deck_service.type_name(String(card.get("type", ""))), String(card.get("attr", ""))], 11 if tight else 12, Color(1.0, 0.88, 0.55, 1.0))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(type_label)
	inner.add_child(main._make_card_art_rect(card, Vector2(142, 82) if tight else (Vector2(132, 84) if compact else Vector2(154, 94))))
	var name_label: Label = main._make_label(String(card.get("name", "")), 13 if tight else (14 if compact else 15), Color(0.98, 0.98, 0.96, 1.0))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(name_label)
	inner.add_child(main.ui.make_chip("골드 %d" % main.shop_run_service.SHOP_CARD_COST, Color(0.38, 0.26, 0.08, 1.0), Color(1.0, 0.86, 0.46, 1.0), 12))
	var text_label: Label = main._make_label(String(card.get("text", "")), 11 if compact else 12, Color(0.82, 0.88, 0.95, 1.0))
	text_label.custom_minimum_size = Vector2(0, 28 if tight else 30)
	text_label.clip_text = true
	inner.add_child(text_label)
	var tag_text: String = main._format_card_tag_text(card)
	if not tag_text.is_empty():
		var tag_label: Label = main._make_label(tag_text, 10 if tight else 11, Color(1.0, 0.82, 0.56, 1.0))
		tag_label.clip_text = true
		inner.add_child(tag_label)
	var button := Button.new()
	button.text = "구매 ▶"
	button.custom_minimum_size = Vector2(120, 36)
	main.ui.style_button(button, Color(0.38, 0.3, 0.14, 1.0))
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
