extends RefCounted
class_name ShopScreen

const SHOP_CARD_COST = 60
const SHOP_RELIC_COST = 150
const SHOP_HEAL_COST = 40

var main: Node

func _init(_main: Node) -> void:
	main = _main

static func generate_shop_state(main: Node) -> Dictionary:
	return {
		"cards": main._roll_card_choices(3),
		"relic": main.relic_service.random_relic(main.current_run.get("relic_ids", [])),
		"remove_used": false,
		"purchased_cards": [],
		"relic_bought": false,
		"remove_count": 0
	}

func build(body: VBoxContainer) -> void:
	var shop_state: Dictionary = main.current_run.get("pending_shop", {})
	body.add_child(main._make_run_summary_panel())
	var panel := main._make_screen_panel(Color(0.105, 0.115, 0.135, 1.0), 760)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(main._make_label("카드 구매, 유물 구매, 카드 제거를 할 수 있습니다.", 15, Color(0.84, 0.88, 0.95, 1.0)))

	for card_id in shop_state.get("cards", []):
		if not main.cards_by_id.has(String(card_id)):
			continue
		box.add_child(_make_shop_card_row(main.cards_by_id[String(card_id)], shop_state))

	var relic: Dictionary = shop_state.get("relic", {})
	if not relic.is_empty():
		box.add_child(_make_shop_relic_row(relic, shop_state))

	var remove_row := HBoxContainer.new()
	remove_row.add_theme_constant_override("separation", 10)
	box.add_child(remove_row)
	var remove_cost := _shop_remove_cost()
	var remove_label := main._make_label("카드 제거 - 골드 %d" % remove_cost, 15, Color(0.92, 0.94, 0.98, 1.0))
	remove_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	remove_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remove_row.add_child(remove_label)
	var remove_button := Button.new()
	remove_button.text = "제거"
	remove_button.custom_minimum_size = Vector2(96, 40)
	main.ui.style_button(remove_button, Color(0.32, 0.18, 0.18, 1.0))
	remove_button.disabled = int(main.current_run.get("gold", 0)) < remove_cost
	remove_button.pressed.connect(Callable(self, "_begin_shop_remove"))
	remove_row.add_child(remove_button)

	var heal_row := HBoxContainer.new()
	heal_row.add_theme_constant_override("separation", 10)
	box.add_child(heal_row)
	var heal_label := main._make_label("체력 20 회복 - 골드 %d" % SHOP_HEAL_COST, 15, Color(0.92, 0.94, 0.98, 1.0))
	heal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heal_row.add_child(heal_label)
	var heal_button := Button.new()
	heal_button.text = "회복"
	heal_button.custom_minimum_size = Vector2(96, 40)
	main.ui.style_button(heal_button, Color(0.18, 0.4, 0.24, 1.0))
	heal_button.disabled = int(main.current_run.get("gold", 0)) < SHOP_HEAL_COST
	heal_button.pressed.connect(Callable(self, "_buy_shop_heal"))
	heal_row.add_child(heal_button)

	var actions: BoxContainer = main.ui.make_action_bar(main._is_compact_layout(), 10)
	box.add_child(actions)
	main._add_menu_button(actions, "지도 복귀", "_leave_shop", Color(0.18, 0.34, 0.48, 1.0), self)

func _make_shop_card_row(card: Dictionary, shop_state: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var frame := main._make_card_frame()
	frame.custom_minimum_size = Vector2(0, 0)
	row.add_child(frame)
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	frame.add_child(inner)
	inner.add_child(main._make_art_rect(int(card.get("art", 0)), Vector2(72, 52)))
	var label := main._make_label("[%d] %s - %s" % [int(card.get("cost", 0)), String(card.get("name", "")), String(card.get("text", ""))], 14, Color(0.92, 0.94, 0.98, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(label)
	var button := Button.new()
	button.text = "구매"
	button.custom_minimum_size = Vector2(96, 40)
	main.ui.style_button(button, Color(0.38, 0.3, 0.14, 1.0))
	button.disabled = int(main.current_run.get("gold", 0)) < SHOP_CARD_COST or (shop_state.get("purchased_cards", []) as Array).has(String(card.get("id", "")))
	button.pressed.connect(Callable(self, "_buy_shop_card").bind(String(card.get("id", ""))))
	row.add_child(button)
	return row

func _make_shop_relic_row(relic: Dictionary, shop_state: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := main._make_label("%s - %s (골드 %d)" % [String(relic.get("name", "")), String(relic.get("text", "")), SHOP_RELIC_COST], 14, Color(1.0, 0.88, 0.55, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button := Button.new()
	button.text = "유물 구매"
	button.custom_minimum_size = Vector2(110, 40)
	main.ui.style_button(button, Color(0.38, 0.3, 0.14, 1.0))
	button.disabled = int(main.current_run.get("gold", 0)) < SHOP_RELIC_COST or bool(shop_state.get("relic_bought", false))
	button.pressed.connect(Callable(self, "_buy_shop_relic"))
	row.add_child(button)
	return row

func _shop_remove_cost() -> int:
	var shop_state: Dictionary = main.current_run.get("pending_shop", {})
	return 50 + int(shop_state.get("remove_count", 0)) * 25

func _buy_shop_card(card_id: String) -> void:
	if int(main.current_run.get("gold", 0)) < SHOP_CARD_COST:
		return
	main.current_run["gold"] = int(main.current_run["gold"]) - SHOP_CARD_COST
	(main.current_run.get("deck_ids", []) as Array).append(card_id)
	var shop_state: Dictionary = main.current_run.get("pending_shop", {})
	(shop_state.get("purchased_cards", []) as Array).append(card_id)
	main.current_run["pending_shop"] = shop_state
	main._save_run()
	main._show_shop()

func _buy_shop_relic() -> void:
	var shop_state: Dictionary = main.current_run.get("pending_shop", {})
	var relic: Dictionary = shop_state.get("relic", {})
	if relic.is_empty() or int(main.current_run.get("gold", 0)) < SHOP_RELIC_COST:
		return
	main.current_run["gold"] = int(main.current_run["gold"]) - SHOP_RELIC_COST
	(main.current_run.get("relic_ids", []) as Array).append(String(relic.get("id", "")))
	main.relic_service.apply_on_acquire(main.current_run, String(relic.get("id", "")))
	shop_state["relic_bought"] = true
	main.current_run["pending_shop"] = shop_state
	main._save_run()
	main._show_shop()

func _begin_shop_remove() -> void:
	var remove_cost := _shop_remove_cost()
	if int(main.current_run.get("gold", 0)) < remove_cost:
		return
	main.current_run["gold"] = int(main.current_run["gold"]) - remove_cost
	var shop_state: Dictionary = main.current_run.get("pending_shop", {})
	shop_state["remove_count"] = int(shop_state.get("remove_count", 0)) + 1
	main.current_run["pending_shop"] = shop_state
	main.pending_return_screen = "shop"
	main._save_run()
	main._show_remove_card_screen("상점")

func _buy_shop_heal() -> void:
	if int(main.current_run.get("gold", 0)) < SHOP_HEAL_COST:
		return
	main.current_run["gold"] = int(main.current_run["gold"]) - SHOP_HEAL_COST
	main.current_run["hp"] = min(int(main.current_run.get("max_hp", 50)), int(main.current_run.get("hp", 0)) + 20)
	main._save_run()
	main._show_shop()

func _leave_shop() -> void:
	main.current_run["pending_shop"] = {}
	main.run_store.mark_node_cleared(main.current_run)
	main.run_store.advance_after_node(main.current_run)
	main._save_run()
	var MapScreenClass = load("res://scripts/ui/screens/map_screen.gd")
	main._show_map()
