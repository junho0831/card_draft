extends RefCounted
class_name MapScreen

var main: Node
var map_scroll: ScrollContainer
var map_canvas: Control
var nodes_data: Array
var current_index: int

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer, act_data: Dictionary) -> void:
	nodes_data = act_data.get("nodes", [])
	current_index = int(main.current_run.get("current_node_index", 0))

	# 1. Summary
	body.add_child(main._make_run_summary_panel())

	# 2. Map Panel
	var compact: bool = main._is_compact_layout()
	var panel = main._make_screen_panel(Color(0.105, 0.115, 0.135, 1.0), 960 if not compact else 420)
	panel.custom_minimum_size.y = 360
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(panel)

	map_scroll = ScrollContainer.new()
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(map_scroll)

	map_canvas = Control.new()
	var node_spacing = 160
	var canvas_width = max(960, nodes_data.size() * node_spacing + 200)
	map_canvas.custom_minimum_size = Vector2(canvas_width, 340)
	map_scroll.add_child(map_canvas)

	_draw_map(node_spacing)

	# 3. Actions
	var actions: BoxContainer = main.ui.make_action_bar(compact, 10)
	body.add_child(actions)
	main._add_menu_button(actions, "메인 메뉴", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))
	main._add_menu_button(actions, "런 포기", "_abandon_run", Color(0.42, 0.18, 0.18, 1.0))

func _draw_map(spacing: int) -> void:
	var cy = 170
	var line = Line2D.new()
	line.width = 8
	line.default_color = Color(0.2, 0.25, 0.3)
	map_canvas.add_child(line)

	var points: PackedVector2Array = []
	var node_controls = []

	for i in range(nodes_data.size()):
		var px = 120 + i * spacing
		var py = cy
		if i > 0 and i < nodes_data.size() - 1:
			py += (randi() % 80) - 40 # Random zig-zag
		
		var pos = Vector2(px, py)
		points.append(pos)
		
		# Draw passed line differently
		if i < current_index:
			var segment = Line2D.new()
			segment.width = 8
			segment.default_color = Color(0.6, 0.5, 0.2) # Goldish cleared path
			if i > 0:
				segment.add_point(points[i-1])
				segment.add_point(pos)
				map_canvas.add_child(segment)
		
		var node_btn = _make_node_button(i, String(nodes_data[i]), pos)
		node_controls.append(node_btn)

	line.points = points
	
	# Add nodes over the lines
	for btn in node_controls:
		map_canvas.add_child(btn)

	# Add player marker / glow
	if current_index < points.size():
		var glow = Panel.new()
		glow.custom_minimum_size = Vector2(80, 80)
		glow.position = points[current_index] - Vector2(40, 40)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.9, 0.2, 0.2)
		style.border_color = Color(1.0, 0.9, 0.2, 0.8)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.corner_radius_top_left = 40
		style.corner_radius_top_right = 40
		style.corner_radius_bottom_left = 40
		style.corner_radius_bottom_right = 40
		glow.add_theme_stylebox_override("panel", style)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_canvas.add_child(glow)

		var tween = main.create_tween().set_loops()
		tween.tween_property(glow, "scale", Vector2(1.2, 1.2), 0.6).set_trans(Tween.TRANS_SINE)
		tween.tween_property(glow, "modulate:a", 0.3, 0.6)
		tween.parallel()
		tween.tween_property(glow, "scale", Vector2(0.9, 0.9), 0.6).set_trans(Tween.TRANS_SINE)
		tween.tween_property(glow, "modulate:a", 1.0, 0.6)

		# Scroll animation
		main.get_tree().create_timer(0.05).timeout.connect(func():
			var target_scroll = max(0, points[current_index].x - 480)
			var scroll_tween = main.create_tween()
			scroll_tween.tween_property(map_scroll, "scroll_horizontal", target_scroll, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		)

func _make_node_button(index: int, type: String, pos: Vector2) -> Control:
	var btn = Button.new()
	var size = 60
	
	var text = ""
	var color = Color(0.3, 0.3, 0.3)
	match type:
		"battle":
			text = "전투"
			color = Color(0.6, 0.25, 0.25)
		"elite":
			text = "엘리트"
			color = Color(0.8, 0.15, 0.15)
			size = 72
		"boss":
			text = "보스"
			color = Color(0.9, 0.1, 0.1)
			size = 84
		"event":
			text = "?"
			color = Color(0.25, 0.45, 0.8)
		"shop":
			text = "$"
			color = Color(0.7, 0.6, 0.15)
		"rest":
			text = "휴식"
			color = Color(0.25, 0.65, 0.25)
			
	btn.custom_minimum_size = Vector2(size, size)
	btn.position = pos - Vector2(size / 2.0, size / 2.0)
			
	if index < current_index:
		color = color.darkened(0.6)
		text = "✔"
		btn.disabled = true
	elif index == current_index:
		btn.pressed.connect(Callable(main, "_enter_current_node"))
	else:
		color = color.darkened(0.4)
		btn.disabled = true

	# Circular button
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color.BLACK
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = size/2
	style.corner_radius_top_right = size/2
	style.corner_radius_bottom_left = size/2
	style.corner_radius_bottom_right = size/2
	btn.add_theme_stylebox_override("normal", style)
	
	var hover = style.duplicate()
	hover.border_color = Color.WHITE
	btn.add_theme_stylebox_override("hover", hover)
	
	var disabled = style.duplicate()
	disabled.bg_color = Color(0.15, 0.15, 0.15)
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.text = text
	btn.add_theme_font_size_override("font_size", int(size * 0.35))
	btn.add_theme_color_override("font_color", Color.WHITE)
	
	return btn
