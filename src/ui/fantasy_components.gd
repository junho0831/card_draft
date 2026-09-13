extends RefCounted

static func heading(main: Node, text: String, size: int = 24) -> Label:
	var label: Label = main._make_label(text, size, Color(0.98, 0.85, 0.55))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label

static func panel(main: Node, title: String, width: int = 0) -> VBoxContainer:
	var outer: PanelContainer = main.ui.make_surface_panel(Color(0.025, 0.035, 0.05, 0.94), Color(0.7, 0.5, 0.22), 1, 12, 18)
	outer.custom_minimum_size.x = width
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	outer.add_child(box)
	box.add_child(heading(main, title, 19))
	box.set_meta("frame", outer)
	return box

static func action(main: Node, title: String, callback: Callable, gold: bool = true) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(0, 54)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.ui.style_role_button(button, "primary" if gold else "turn", Color(0.95, 0.75, 0.3) if gold else Color(0.3, 0.64, 1), Color.TRANSPARENT, 18)
	button.pressed.connect(callback)
	return button

static func card(main: Node, data: Dictionary, width: int, height: int, selected: bool = false) -> PanelContainer:
	var frame: PanelContainer = main.ui.make_surface_panel(Color(0.025, 0.035, 0.05), Color(0.9, 0.69, 0.28), 2, 12, 8)
	frame.add_theme_stylebox_override("panel", preload("res://src/ui/styles/ui_styles.gd").make_textured_panel_style(Color(1, 1, 1, 0.95), Color(0.9, 0.7, 0.3), 8, true))
	frame.custom_minimum_size = Vector2(width, height)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.tooltip_text = String(data.get("text", ""))
	if selected:
		frame.modulate = Color(1.12, 1.07, 0.96)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	frame.add_child(box)
	var art: TextureRect = main._make_card_art_rect(data, Vector2(width - 16, height * 0.52))
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	box.add_child(art)
	var cost: PanelContainer = gem(main, int(data.get("cost", 0)), false)
	cost.position = Vector2(0, 0)
	art.add_child(cost)
	var name_label: Label = heading(main, String(data.get("name", "")), 18 if width >= 190 else 15)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	box.add_child(HSeparator.new())
	var rules: Label = main._make_label(main._card_effect_summary(data), 13, Color(0.91, 0.91, 0.87))
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(rules)
	var stats := HBoxContainer.new()
	box.add_child(stats)
	if String(data.get("type", "")) == "unit":
		stats.add_child(gem(main, int(data.get("attack", 0)), true))
		var space := Control.new()
		space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(space)
		stats.add_child(gem(main, int(data.get("health", 0)), false))
	else:
		var tag := heading(main, ("주문" if data.get("type") == "spell" else "장비") + " · " + String(data.get("race", "공용")), 12)
		tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(tag)
	return frame

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
	var frame := PanelContainer.new()
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/ui/fantasy/gem_red.svg" if red else "res://assets/ui/fantasy/gem_blue.svg")
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	frame.add_theme_stylebox_override("panel", style)
	frame.custom_minimum_size = Vector2(40, 44)
	frame.add_child(main._make_label(str(value), 22, Color.WHITE))
	return frame
