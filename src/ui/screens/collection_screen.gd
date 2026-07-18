extends RefCounted
class_name CollectionScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer) -> void:
	var compact = main._is_compact_layout()
	var panel = main._make_screen_panel(Color(0.105, 0.115, 0.135, 1.0), 760 if not compact else 420)
	body.add_child(panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(list)
	list.add_child(main._make_label("카드 %d종 | 보유 카드는 밝게, 미보유 카드는 어둡게 표시됩니다." % main.card_defs.size(), 14, Color(0.82, 0.88, 0.95, 1.0)))
	list.add_child(main.ui.make_filter_bar(["전체", "보유", "미보유", "인간", "엘프", "언데드", "공용"], main.collection_filter, self, "_set_collection_filter", compact))
	var filtered_cards := _filtered_collection_cards()
	var columns := 2 if compact else 4
	var row: HBoxContainer = null
	for index in range(filtered_cards.size()):
		if index % columns == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 10)
			list.add_child(row)
		row.add_child(_make_collection_card(filtered_cards[index], compact))
	var actions: BoxContainer = main.ui.make_action_bar(compact, 10)
	body.add_child(actions)
	main._add_menu_button(actions, "메인으로", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))

func _set_collection_filter(filter: String) -> void:
	main.collection_filter = filter
	main._show_collection()

func _filtered_collection_cards() -> Array:
	var filtered: Array = []
	var race_filter: String = "중립" if main.collection_filter == "공용" else String(main.collection_filter)
	for card in main.card_defs:
		var owned := int(main.player_profile["owned_cards"].get(String(card.get("id", "")), 0))
		if main.collection_filter == "보유" and owned <= 0:
			continue
		if main.collection_filter == "미보유" and owned > 0:
			continue
		if race_filter not in ["전체", "보유", "미보유"] and String(card.get("race", "")) != race_filter:
			continue
		filtered.append(card)
	return filtered

func _make_collection_card(card: Dictionary, compact: bool) -> Control:
	var owned := int(main.player_profile["owned_cards"].get(String(card.get("id", "")), 0))
	var panel = main.ui.make_race_card_panel(card, 10, 3 if owned > 0 else 2, 0.08 if owned > 0 else 0.0)
	panel.custom_minimum_size = Vector2(170 if compact else 220, 0)
	if owned <= 0:
		panel.modulate = Color(0.45, 0.45, 0.5, 1.0)
	panel.add_child(main.ui.make_card_face(main, card, "collection", {
		"compact": compact,
		"suffix": "x%d" % owned,
		"art_size": Vector2(132, 92) if compact else Vector2(150, 108),
		"dim_art": owned <= 0,
		"include_stats": true,
		"summary_text": main._card_effect_summary(card),
		"detail_text": String(card.get("text", "")),
	}))
	return panel
