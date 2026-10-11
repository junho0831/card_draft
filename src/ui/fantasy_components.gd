extends RefCounted
const CardView = preload("res://src/ui/components/card_view.gd")
const Tokens = preload("res://src/ui/styles/ui_tokens.gd")

static func heading(main: Node, text: String, size: int = 24) -> Label:
	return CardView.make_title(main, text, size)

static func panel(main: Node, title: String, width: int = 0) -> VBoxContainer:
	var outer: PanelContainer = main.ui.make_surface_panel(Tokens.SURFACE, Tokens.BORDER, 1, 8, 12)
	outer.custom_minimum_size.x = width
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	outer.add_child(box)
	box.add_child(heading(main, title, 19))
	box.set_meta("frame", outer)
	return box

static func action(main: Node, title: String, callback: Callable, gold: bool = true) -> Button:
	var button: Button = main.ui.make_action_button(title, callback, "primary" if gold else "secondary", Tokens.ACCENT_GOLD if gold else Tokens.BORDER, Color.TRANSPARENT, 16)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button

static func card(main: Node, data: Dictionary, width: int, height: int, selected: bool = false) -> PanelContainer:
	return CardView.make_illustrated_face(main, data, width, height, selected)

static func clickable_card(frame: Control, callback: Callable) -> void:
	_ignore_children(frame)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	frame.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			callback.call()
	)

static func _ignore_children(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_children(child)

static func gem(main: Node, value: int, red: bool) -> PanelContainer:
	return CardView.make_gem(main, value, red)
