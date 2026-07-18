extends RefCounted
class_name DeckEditScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build_remove(body: VBoxContainer, reason: String) -> void:
	body.add_child(main._make_run_summary_panel())
	var panel: PanelContainer = main._make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 760)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(main._make_label("%s - 카드 제거" % reason, 22, Color(1.0, 0.88, 0.55, 1.0)))
	box.add_child(main._make_label("덱에서 제거할 카드 1장을 고르세요.", 16, Color(0.92, 0.94, 0.98, 1.0)))

	var unique_ids := {}
	var has_options := false
	for card_id in main.current_run.get("deck_ids", []):
		unique_ids[String(card_id)] = true
	for card_id in unique_ids.keys():
		var card: Dictionary = main.card_db.get_card(String(card_id))
		if card.is_empty():
			continue
		has_options = true
		var count: int = main.deck_service.count_in_array(main.current_run.get("deck_ids", []), String(card_id))
		box.add_child(_make_option_row("%s x%d" % [String(card.get("name", "")), count], "제거", Callable(main, "_remove_card_from_run").bind(String(card_id))))

	if not has_options:
		box.add_child(main._make_label("제거할 카드가 없습니다.", 15, Color(0.92, 0.94, 0.98, 1.0)))
	main._add_menu_button(box, "돌아가기", "_cancel_pending_subscreen", Color(0.22, 0.24, 0.28, 1.0))

func build_upgrade(body: VBoxContainer) -> void:
	body.add_child(main._make_run_summary_panel())
	var panel: PanelContainer = main._make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 760)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(main._make_label("휴식 - 카드 강화", 22, Color(1.0, 0.88, 0.55, 1.0)))
	box.add_child(main._make_label("강화할 카드 1장을 고르세요.", 16, Color(0.92, 0.94, 0.98, 1.0)))

	var unique_ids := {}
	var has_options := false
	for card_id in main.current_run.get("deck_ids", []):
		unique_ids[String(card_id)] = true
	for card_id in unique_ids.keys():
		if String(card_id).ends_with("_plus"):
			continue
		var card: Dictionary = main.card_db.get_card(String(card_id))
		if card.is_empty():
			continue
		has_options = true
		box.add_child(_make_option_row(String(card.get("name", "")), "강화", Callable(main, "_upgrade_card_in_run").bind(String(card_id))))

	if not has_options:
		box.add_child(main._make_label("강화할 카드가 없습니다.", 15, Color(0.92, 0.94, 0.98, 1.0)))
	main._add_menu_button(box, "돌아가기", "_cancel_pending_subscreen", Color(0.22, 0.24, 0.28, 1.0))

func _make_option_row(label_text: String, button_text: String, callback: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label: Label = main._make_label(label_text, 15, Color(0.92, 0.94, 0.98, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(96, 40)
	if button_text == "제거":
		main.ui.style_role_button(button, "danger", Color(0.9, 0.3, 0.28, 1.0), Color(0.24, 0.07, 0.08, 1.0), 15)
	else:
		main.ui.style_role_button(button, "primary", Color(0.46, 0.7, 1.0, 1.0), Color(0.1, 0.24, 0.48, 1.0), 15)
	button.pressed.connect(callback)
	row.add_child(button)
	return row
