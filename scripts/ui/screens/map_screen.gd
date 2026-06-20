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

	body.add_child(main._make_run_summary_panel())
	var compact: bool = _is_map_compact_layout()
	body.add_child(main.ui.make_guidance_banner("다음 행동", "빛나는 노드를 눌러 다음 장소로 진입", Color(0.2, 0.24, 0.18, 1.0), compact))
	body.add_child(_make_map_status_strip(compact))

	var hub: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	hub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hub.add_theme_constant_override("separation", 10)
	body.add_child(hub)

	hub.add_child(_make_legend_panel(compact))
	hub.add_child(_make_map_panel(compact))
	hub.add_child(_make_objective_panel(compact, act_data))

	body.add_child(_make_build_direction_panel(compact))

func _is_map_compact_layout() -> bool:
	return main._is_compact_layout_for(1360.0, 760.0)

func _make_map_status_strip(compact: bool) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.07, 0.08, 0.1, 0.98), Color(0.2, 0.18, 0.12, 1.0), 1, 12, 12)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	row.add_child(main.ui.make_chip("Act %d" % int(main.current_run.get("act", 1)), Color(0.12, 0.22, 0.34, 1.0), Color(0.86, 0.92, 1.0, 1.0), 13 if compact else 14))
	row.add_child(main.ui.make_chip("노드 %d / %d" % [current_index + 1, nodes_data.size()], Color(0.14, 0.18, 0.24, 1.0), Color(0.96, 0.97, 0.94, 1.0), 13 if compact else 14))
	row.add_child(main.ui.make_chip("다음 %s" % main._node_type_name(_current_node_type()), Color(0.18, 0.18, 0.1, 1.0), Color(1.0, 0.92, 0.72, 1.0), 13 if compact else 14))
	row.add_child(main.ui.make_chip("추천 방향 %s" % _primary_build_hint(), Color(0.12, 0.16, 0.24, 1.0), Color(0.84, 0.9, 1.0, 1.0), 13 if compact else 14))
	return panel

func _make_map_panel(compact: bool) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.055, 0.065, 0.075, 1.0), Color(0.2, 0.17, 0.11, 1.0), 1, 12, 12)
	panel.custom_minimum_size = Vector2(0, 300 if compact else 318)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	box.add_child(title_row)
	var title: Label = main._make_label("Act 경로", 18 if compact else 20, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var progress: Label = main._make_label("노드 %d / %d" % [current_index + 1, nodes_data.size()], 14 if compact else 15, Color(0.82, 0.86, 0.92, 1.0))
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress.autowrap_mode = TextServer.AUTOWRAP_OFF
	progress.custom_minimum_size = Vector2(96, 0)
	title_row.add_child(progress)
	var subtitle: Label = main._make_label("현재 진입 가능한 노드만 밝게 표시됩니다.", 13 if compact else 14, Color(0.8, 0.84, 0.9, 1.0))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(subtitle)

	map_scroll = ScrollContainer.new()
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_scroll.custom_minimum_size = Vector2(0, 206 if compact else 220)
	map_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(map_scroll)

	map_canvas = Control.new()
	var step_count: int = max(1, nodes_data.size() - 1)
	var viewport_width: int = int(main._layout_viewport_size().x)
	var visible_map_width: int = max(420 if compact else 520, viewport_width - (48 if compact else 420))
	var min_spacing: int = 60 if compact else 66
	var max_spacing: int = 116 if compact else 126
	var node_spacing: int = clampi(int((visible_map_width - 184) / step_count), min_spacing, max_spacing)
	var canvas_width: int = 184 + step_count * node_spacing
	var canvas_height := 198 if compact else 212
	map_canvas.custom_minimum_size = Vector2(canvas_width, canvas_height)
	map_canvas.size = map_canvas.custom_minimum_size
	map_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	map_scroll.add_child(map_canvas)

	_draw_map_background(canvas_width, canvas_height, compact)
	_draw_map(node_spacing, canvas_height)
	return panel

func _make_legend_panel(compact: bool) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.08, 0.09, 0.11, 0.96), Color(0.16, 0.18, 0.23, 1.0), 1, 12, 14)
	panel.custom_minimum_size = Vector2(0 if compact else 160, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title: Label = main._make_label("노드 범례", 16 if compact else 17, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	for node_type in ["battle", "elite", "event", "shop", "rest", "boss"]:
		box.add_child(_make_legend_row(node_type, compact))
	box.add_child(HSeparator.new())
	var hint: Label = main._make_label("빛나는 노드만 진입 가능", 12 if compact else 13, Color(0.82, 0.86, 0.92, 1.0))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(hint)
	return panel

func _make_legend_row(node_type: String, compact: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon_panel: PanelContainer = main.ui.make_surface_panel(_node_color(node_type), _node_color(node_type).lightened(0.2), 1, 6, 4)
	icon_panel.custom_minimum_size = Vector2(18, 18)
	var icon_label: Label = main._make_label(_node_icon(node_type), 10 if compact else 11, Color(1.0, 0.96, 0.88, 1.0))
	icon_panel.add_child(icon_label)
	row.add_child(icon_panel)
	var label: Label = main._make_label(main._node_type_name(node_type), 14 if compact else 15, Color(0.9, 0.92, 0.95, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row

func _make_objective_panel(compact: bool, act_data: Dictionary) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.08, 0.09, 0.11, 0.96), Color(0.22, 0.19, 0.11, 1.0), 1, 12, 14)
	panel.custom_minimum_size = Vector2(0 if compact else 235, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)

	var act_name := String(act_data.get("name", "Act"))
	box.add_child(_make_panel_title("현재 목표", compact))
	var objective: Label = main._make_label("Act %d - %s 진행" % [int(main.current_run.get("act", 1)), act_name], 15 if compact else 16, Color(0.68, 0.92, 0.48, 1.0))
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(objective)
	var current_type := _current_node_type()
	var current_label: Label = main._make_label("다음 장소: %s" % main._node_type_name(current_type), 16 if compact else 18, Color(1.0, 0.88, 0.55, 1.0))
	current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(current_label)
	var high_level_goal: PanelContainer = main.ui.make_objective_panel("이번 목표", _node_objective_text(current_type), compact)
	box.add_child(high_level_goal)
	var route_chip: PanelContainer = main.ui.make_chip("노드 %d / %d" % [current_index + 1, nodes_data.size()], Color(0.14, 0.18, 0.24, 1.0), Color(0.98, 0.98, 0.94, 1.0), 13 if compact else 14)
	box.add_child(route_chip)
	var desc: Label = main._make_label(_node_description(current_type), 14 if compact else 15, Color(0.86, 0.9, 0.96, 1.0))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(desc)

	box.add_child(HSeparator.new())
	var current_layer: Variant = nodes_data[current_index]
	if typeof(current_layer) == TYPE_ARRAY and (current_layer as Array).size() > 1:
		box.add_child(_make_panel_title("경로 선택", compact))
		for path_idx in range((current_layer as Array).size()):
			var ptype := String((current_layer as Array)[path_idx])
			var btn: Button = main._add_menu_button(box, "%s 진입 ▶" % main._node_type_name(ptype), "", Color(0.55, 0.36, 0.1, 1.0))
			btn.pressed.connect(func():
				main._enter_current_node(path_idx)
			)
			if path_idx == 0:
				main.ui.style_primary_button(btn)
	else:
		var enter_button: Button = main._add_menu_button(box, "현재 노드 진입 ▶", "", Color(0.55, 0.36, 0.1, 1.0))
		enter_button.pressed.connect(func():
			main._enter_current_node(0)
		)
		main.ui.style_primary_button(enter_button)

	box.add_child(HSeparator.new())
	box.add_child(_make_panel_title("예상 보상", compact))
	var rewards: Label = main._make_label(_node_reward_text(current_type), 14 if compact else 15, Color(0.94, 0.9, 0.72, 1.0))
	rewards.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(rewards)
	var risk_chip: PanelContainer = main.ui.make_chip(_node_risk_text(current_type), Color(0.16, 0.12, 0.08, 1.0), Color(1.0, 0.9, 0.72, 1.0), 12 if compact else 13)
	box.add_child(risk_chip)

	return panel

func _make_build_direction_panel(compact: bool) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.08, 0.09, 0.11, 0.96), Color(0.18, 0.21, 0.26, 1.0), 1, 12, 14)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title: Label = main._make_label("현재 빌드", 16 if compact else 17, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	var chip_row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 8)
	box.add_child(chip_row)
	var scores: Dictionary = main._current_build_scores()
	for tag in ["fire", "draw", "death", "buff", "low_hp", "summon"]:
		var meta: Dictionary = main._build_tag_meta().get(tag, {})
		var chip: PanelContainer = main.ui.make_chip("%s %d" % [String(meta.get("name", "")), int(scores.get(tag, 0))], Color(meta.get("color", Color(0.2, 0.2, 0.2, 1.0))).darkened(0.45), Color(0.98, 0.98, 0.94, 1.0), 13 if compact else 14)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip_row.add_child(chip)
	var active: Label = main._make_label(main._active_build_text(scores), 14 if compact else 15, Color(1.0, 0.86, 0.52, 1.0))
	active.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(active)
	var guidance: Label = main._make_label(_primary_build_guidance(scores), 13 if compact else 14, Color(0.84, 0.9, 0.96, 1.0))
	guidance.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(guidance)
	return panel

func _make_panel_title(text: String, compact: bool) -> Label:
	var label: Label = main._make_label(text, 14 if compact else 15, Color(0.74, 0.78, 0.86, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label

func _current_node_type() -> String:
	if current_index < 0 or current_index >= nodes_data.size():
		return ""
	var layer: Variant = nodes_data[current_index]
	var path_index = int(main.current_run.get("current_path_index", 0))
	if typeof(layer) == TYPE_ARRAY:
		if path_index >= 0 and path_index < layer.size():
			return String(layer[path_index])
		else:
			return String(layer[0])
	return String(layer)

func _node_description(node_type: String) -> String:
	match node_type:
		"battle":
			return "일반 적과 전투합니다. 덱을 키우는 기본 경로입니다."
		"elite":
			return "강한 적과 싸웁니다. 위험하지만 유물 보상이 붙습니다."
		"event":
			return "선택지로 체력, 골드, 카드, 유물이 바뀝니다."
		"shop":
			return "골드를 사용해 카드, 유물, 회복, 제거를 선택합니다."
		"rest":
			return "안전 구역입니다. 체력을 회복하거나 카드를 강화합니다."
		"boss":
			return "Act 마지막 보스입니다. 승리하면 다음 Act로 이동합니다."
		_:
			return "다음 진행 지점을 선택하세요."

func _node_reward_text(node_type: String) -> String:
	match node_type:
		"battle":
			return "골드 15-25\n카드 3장 중 1장"
		"elite":
			return "골드 30-50\n유물 1개\n카드 보상"
		"event":
			return "선택에 따라 보상 또는 비용 발생"
		"shop":
			return "카드/유물 구매\n카드 제거 또는 회복"
		"rest":
			return "체력 회복\n카드 강화"
		"boss":
			return "유물 보상\n최대 체력 +5\n다음 Act"
		_:
			return "진행 보상"

func _node_objective_text(node_type: String) -> String:
	match node_type:
		"battle":
			return "일반 적을 처치하고 카드 보상으로 덱을 강화하세요."
		"elite":
			return "위험을 감수하고 유물을 노리세요."
		"event":
			return "선택지 결과를 보고 현재 빌드에 맞게 판단하세요."
		"shop":
			return "골드로 덱 압축 또는 유물 구매를 결정하세요."
		"rest":
			return "다음 전투 전에 회복과 강화를 정비하세요."
		"boss":
			return "현재 빌드 완성도를 시험하는 보스 전투입니다."
		_:
			return "다음 노드를 선택하세요."

func _node_risk_text(node_type: String) -> String:
	match node_type:
		"battle":
			return "위험도 보통"
		"elite":
			return "위험도 높음 / 유물 보상"
		"event":
			return "위험도 가변 / 선택지 의존"
		"shop":
			return "위험도 낮음 / 자원 사용"
		"rest":
			return "안전 구역"
		"boss":
			return "위험도 최고 / Act 전환"
		_:
			return "진행 정보"

func _primary_build_hint() -> String:
	var scores: Dictionary = main._current_build_scores()
	var primary: String = main._primary_build_tag(scores)
	if primary.is_empty():
		return "탐색"
	var meta: Dictionary = main._build_tag_meta().get(primary, {})
	return "%s %s" % [String(meta.get("icon", "")), String(meta.get("name", ""))]

func _primary_build_guidance(scores: Dictionary) -> String:
	var primary: String = main._primary_build_tag(scores)
	if primary.is_empty():
		return "아직 빌드가 고정되지 않았습니다. 현재 노드 보상으로 방향을 잡으세요."
	var meta: Dictionary = main._build_tag_meta().get(primary, {})
	return "현재는 %s %s 축이 가장 강합니다. 이 노드의 보상이 시너지를 이어주는지 확인하세요." % [String(meta.get("icon", "")), String(meta.get("name", ""))]

func _node_color(node_type: String) -> Color:
	match node_type:
		"battle":
			return Color(0.46, 0.23, 0.18, 1.0)
		"elite":
			return Color(0.68, 0.18, 0.12, 1.0)
		"boss":
			return Color(0.72, 0.46, 0.14, 1.0)
		"event":
			return Color(0.28, 0.36, 0.64, 1.0)
		"shop":
			return Color(0.52, 0.44, 0.16, 1.0)
		"rest":
			return Color(0.22, 0.48, 0.28, 1.0)
		_:
			return Color(0.25, 0.27, 0.3, 1.0)

func _draw_map_background(canvas_width: int, canvas_height: int, compact: bool) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.055, 0.052, 1.0)
	bg.custom_minimum_size = Vector2(canvas_width, canvas_height)
	bg.size = bg.custom_minimum_size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_canvas.add_child(bg)

	for i in range(8):
		var ridge := ColorRect.new()
		ridge.color = Color(0.09, 0.11, 0.08, 0.42)
		ridge.custom_minimum_size = Vector2(170 + i * 16, 3)
		ridge.size = ridge.custom_minimum_size
		ridge.position = Vector2(38 + i * 112, 50 + int(sin(float(i)) * 26.0))
		ridge.rotation = -0.28 + float(i % 3) * 0.18
		ridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_canvas.add_child(ridge)

	for i in range(14):
		var star: Label = main._make_label("✦", 10 if compact else 12, Color(0.38, 0.34, 0.18, 0.32))
		star.position = Vector2(42 + i * 73, 24 + int((i * 37) % max(80, canvas_height - 40)))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_canvas.add_child(star)

	var act_label: Label = main._make_label("국경지대 원정로", 14 if compact else 16, Color(0.72, 0.78, 0.66, 0.42))
	act_label.position = Vector2(24, 18)
	act_label.custom_minimum_size = Vector2(180, 24)
	act_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	act_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_canvas.add_child(act_label)

func _draw_map(spacing: int, canvas_height: int) -> void:
	var cy: int = int(canvas_height * 0.52)
	var points: PackedVector2Array = []
	var node_controls: Array[Control] = []
	var offsets := [0, -34, 26, -18, 32, -26, 18, 0]

	for i in range(nodes_data.size()):
		var px := 92 + i * spacing
		var py := cy
		if i > 0 and i < nodes_data.size() - 1:
			py += int(offsets[i % offsets.size()])
		
		var pos := Vector2(px, py)
		points.append(pos)
		var node_type: String = ""
		var layer_data: Variant = nodes_data[i]
		if typeof(layer_data) == TYPE_ARRAY and (layer_data as Array).size() > 0:
			node_type = String(layer_data[0])
		else:
			node_type = String(layer_data)
			
		var node_btn: Control = _make_node_button(i, node_type, pos)
		node_controls.append(node_btn)

	for i in range(1, points.size()):
		var base_color := Color(0.2, 0.25, 0.3)
		if i - 1 < current_index:
			base_color = Color(0.76, 0.58, 0.22)
		elif i - 1 == current_index:
			base_color = Color(0.52, 0.62, 0.78)
		map_canvas.add_child(_make_path_segment(points[i - 1], points[i], base_color))

	if current_index < points.size():
		var glow := Panel.new()
		glow.custom_minimum_size = Vector2(88, 88)
		glow.position = points[current_index] - Vector2(44, 44)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.9, 0.25, 0.18)
		style.border_color = Color(1.0, 0.86, 0.26, 0.9)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.corner_radius_top_left = 44
		style.corner_radius_top_right = 44
		style.corner_radius_bottom_left = 44
		style.corner_radius_bottom_right = 44
		glow.add_theme_stylebox_override("panel", style)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.z_index = 2
		map_canvas.add_child(glow)

		var tween = main.create_tween()
		tween.set_loops(6)
		tween.tween_property(glow, "scale", Vector2(1.12, 1.12), 0.65).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(glow, "modulate:a", 0.45, 0.65)
		tween.tween_property(glow, "scale", Vector2(0.95, 0.95), 0.65).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(glow, "modulate:a", 1.0, 0.65)

		# Scroll animation
		main.get_tree().create_timer(0.05).timeout.connect(func():
			if main == null or not is_instance_valid(main) or map_scroll == null or not is_instance_valid(map_scroll):
				return
			var target_scroll: int = int(max(0.0, points[current_index].x - 420.0))
			var scroll_tween: Tween = main.create_tween()
			scroll_tween.tween_property(map_scroll, "scroll_horizontal", target_scroll, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		)

	for btn in node_controls:
		map_canvas.add_child(btn)

func _make_path_segment(from_pos: Vector2, to_pos: Vector2, color: Color) -> Control:
	var segment := ColorRect.new()
	var direction: Vector2 = to_pos - from_pos
	var length: float = direction.length()
	segment.color = color
	segment.custom_minimum_size = Vector2(length, 6)
	segment.size = segment.custom_minimum_size
	segment.position = from_pos - Vector2(0, 3)
	segment.pivot_offset = Vector2(0, 3)
	segment.rotation = direction.angle()
	segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	segment.z_index = 1
	return segment

func _make_node_button(index: int, type: String, pos: Vector2) -> Control:
	var btn := Button.new()
	var size: int = 60
	var label_text: String = main._node_type_name(type)
	var icon_text: String = _node_icon(type)
	var color: Color = _node_color(type)
	match type:
		"elite":
			size = 68
		"boss":
			size = 78
			
	btn.custom_minimum_size = Vector2(size, size)
	btn.position = pos - Vector2(size / 2.0, size / 2.0)
			
	if index < current_index:
		color = color.darkened(0.6)
		icon_text = "✓"
		label_text = "완료"
		btn.disabled = true
	elif index == current_index:
		label_text = main._node_type_name(type)
		size += 16
		btn.pressed.connect(Callable(main, "_enter_current_node"))
	else:
		color = color.darkened(0.48)
		btn.disabled = true

	btn.custom_minimum_size = Vector2(size, size)
	btn.size = btn.custom_minimum_size
	btn.position = pos - Vector2(size / 2.0, size / 2.0)
	btn.z_index = 3

	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.07, 0.06, 0.04, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = size/2
	style.corner_radius_top_right = size/2
	style.corner_radius_bottom_left = size/2
	style.corner_radius_bottom_right = size/2
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	style.anti_aliasing = true
	if index == current_index:
		style.bg_color = color.lightened(0.18)
		style.border_color = Color(1.0, 0.9, 0.4, 1.0)
		style.border_width_left = 5
		style.border_width_right = 5
		style.border_width_top = 5
		style.border_width_bottom = 5
	elif index > current_index:
		btn.modulate = Color(0.42, 0.44, 0.48, 0.68)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover = style.duplicate()
	hover.border_color = Color.WHITE
	btn.add_theme_stylebox_override("hover", hover)
	
	var disabled = style.duplicate()
	disabled.bg_color = Color(0.15, 0.15, 0.15)
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.text = "%s\n%s" % [icon_text, label_text]
	btn.add_theme_font_size_override("font_size", 14 if size < 76 else 17)
	btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.54, 0.56, 0.6, 1.0))
	btn.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	btn.add_theme_constant_override("outline_size", 4)
	
	return btn

func _node_icon(node_type: String) -> String:
	match node_type:
		"battle":
			return "⚔"
		"elite":
			return "◆"
		"boss":
			return "♛"
		"event":
			return "?"
		"shop":
			return "▣"
		"rest":
			return "♨"
		_:
			return "•"
