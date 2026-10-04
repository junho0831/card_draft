extends RefCounted

const Tokens = preload("res://src/ui/styles/ui_tokens.gd")

static func back(main: Node, body: VBoxContainer, callback: String = "_show_main_menu") -> Button:
	var button: Button = main.ui.make_dock_action_button("돌아가기", "", Tokens.ACCENT_TEAL, false, 104)
	button.custom_minimum_size = Vector2(104, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(Callable(main, callback))
	for sibling in body.get_parent().get_children():
		if sibling == body:
			break
		if sibling is HBoxContainer:
			sibling.add_child(button)
			sibling.move_child(button, 0)
			return button
		if sibling is PanelContainer and sibling.get_child_count() > 0 and sibling.get_child(0) is HBoxContainer:
			var header: HBoxContainer = sibling.get_child(0)
			header.add_child(button)
			header.move_child(button, 0)
			return button
	body.add_child(button)
	body.move_child(button, 0)
	return button

static func label(main: Node, text: String, secondary: bool = false) -> Label:
	var result: Label = main.ui.make_label(text, 14 if secondary else 16, Tokens.TEXT_SECONDARY if secondary else Tokens.TEXT_PRIMARY)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return result

static func dock(main: Node, body: VBoxContainer) -> Dictionary:
	var result: Dictionary = main.ui.mount_screen_action_dock(main, body, "", "", Tokens.ACCENT_GOLD, 64)
	result.title_label.hide()
	result.detail_label.hide()
	result.actions.alignment = BoxContainer.ALIGNMENT_END
	return result
