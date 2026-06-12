extends RefCounted
class_name UiFactory

var card_art_sheet: Texture2D
var card_art_cols := 4
var card_art_rows := 3
const COMPACT_BREAKPOINT := 860.0
const SCREEN_MARGIN := 18.0
const MIN_RESPONSIVE_WIDTH := 280.0

func setup(art_sheet: Texture2D, cols: int, rows: int) -> void:
	card_art_sheet = art_sheet
	card_art_cols = cols
	card_art_rows = rows

func make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func is_compact(viewport_width: float) -> bool:
	return viewport_width < COMPACT_BREAKPOINT

func responsive_width(viewport_width: float, preferred_width: int) -> float:
	return min(float(preferred_width), max(MIN_RESPONSIVE_WIDTH, viewport_width - (SCREEN_MARGIN * 2.0 + 12.0)))

func apply_root_layout(root: Control, viewport_size: Vector2) -> void:
	root.custom_minimum_size = Vector2(max(320.0, viewport_size.x - SCREEN_MARGIN * 2.0), max(0.0, viewport_size.y - SCREEN_MARGIN * 2.0))
	root.offset_left = SCREEN_MARGIN
	root.offset_top = SCREEN_MARGIN
	root.offset_right = -SCREEN_MARGIN
	root.offset_bottom = -SCREEN_MARGIN

func make_responsive_box(compact: bool, separation: int = 14) -> BoxContainer:
	var box: BoxContainer
	if compact:
		box = VBoxContainer.new()
	else:
		box = HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", separation)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return box

func make_center_panel(color: Color, viewport_width: float, preferred_width: int) -> PanelContainer:
	var panel := make_panel_container(color)
	panel.custom_minimum_size = Vector2(responsive_width(viewport_width, preferred_width), 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return panel

func make_responsive_panel(color: Color, viewport_width: float, preferred_width: int, min_height: int = 0) -> PanelContainer:
	var panel := make_panel_container(color)
	panel.custom_minimum_size = Vector2(responsive_width(viewport_width, preferred_width), min_height)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return panel

func make_filter_bar(filters: Array, active_filter: String, target: Object, callback_method: String, compact: bool) -> Container:
	var actions: Container
	if compact:
		var grid := GridContainer.new()
		grid.columns = 3
		actions = grid
	else:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		actions = row
	actions.add_theme_constant_override("separation", 8)
	actions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for filter in filters:
		var button := Button.new()
		button.text = String(filter)
		button.custom_minimum_size = Vector2(92 if compact else 86, 34)
		var color := Color(0.18, 0.24, 0.3, 1.0)
		if String(filter) == active_filter:
			color = Color(0.38, 0.31, 0.12, 1.0)
		style_button(button, color)
		button.pressed.connect(Callable(target, callback_method).bind(String(filter)))
		actions.add_child(button)
	return actions

func make_showcase_card(title: String, art_index: int, compact: bool = false) -> PanelContainer:
	var panel := make_panel_container(Color(0.14, 0.16, 0.19, 1.0))
	var card_width := 120
	var art_size := Vector2(96, 112)
	if compact:
		card_width = 92
		art_size = Vector2(70, 86)
	panel.custom_minimum_size = Vector2(card_width, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(make_art_rect(art_index, art_size))
	var label := make_label(title, 15, Color(0.95, 0.96, 0.93, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(label)
	return panel

func make_stat_tile(title: String, value: String, color: Color, compact: bool = false) -> PanelContainer:
	var panel := make_panel_container(color)
	panel.custom_minimum_size = Vector2(96 if compact else 126, 64 if compact else 72)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var title_label := make_label(title, 12, Color(0.88, 0.9, 0.92, 1.0))
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var value_label := make_label(value, 18, Color(1.0, 0.98, 0.9, 1.0))
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(title_label)
	box.add_child(value_label)
	return panel

func make_status_badge(title: String, value: String, color: Color) -> PanelContainer:
	var panel := make_panel_container(color)
	panel.custom_minimum_size = Vector2(0, 58)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var title_label := make_label(title, 13, Color(0.9, 0.94, 0.96, 1.0))
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var value_label := make_label(value, 15, Color(1.0, 0.98, 0.88, 1.0))
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(title_label)
	row.add_child(value_label)
	return panel

func add_title(parent: Node, text: String) -> void:
	var title := make_label(text, 40, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.075, 0.07, 1.0))
	parent.add_child(title)

func begin_screen(root: Node, title: String, summary: Control = null, spacing: int = 12) -> VBoxContainer:
	add_title(root, title)
	if summary != null:
		root.add_child(summary)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", spacing)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(body)
	return body

func make_screen_panel(color: Color, viewport_width: float, preferred_width: int, min_height: int = 0) -> PanelContainer:
	var panel := make_responsive_panel(color, viewport_width, preferred_width, min_height)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return panel

func make_scroll_panel(color: Color, viewport_width: float, preferred_width: int, content_separation: int = 8, min_height: int = 0) -> Dictionary:
	var panel := make_screen_panel(color, viewport_width, preferred_width, min_height)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", content_separation)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return {
		"panel": panel,
		"scroll": scroll,
		"content": content,
	}

func make_action_bar(compact: bool, separation: int = 10) -> BoxContainer:
	var bar := make_responsive_box(compact, separation)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return bar

func make_info_row(compact: bool, separation: int = 8, min_height: int = 0) -> BoxContainer:
	var row := make_responsive_box(compact, separation)
	row.custom_minimum_size = Vector2(0, min_height)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row

func add_menu_button(parent: Node, target: Object, text: String, callback_method: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_button(button, color)
	button.pressed.connect(Callable(target, callback_method))
	parent.add_child(button)
	return button

func make_panel_container(color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", make_style_box(color, Color(0.38, 0.43, 0.5, 1.0), 2, 8))
	return panel

func make_style_box(bg_color: Color, border_color: Color, border_width: int = 1, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	return style

func style_button(button: Button, base_color: Color) -> void:
	button.add_theme_stylebox_override("normal", make_style_box(base_color, Color(0.58, 0.64, 0.72, 1.0), 1, 6))
	button.add_theme_stylebox_override("hover", make_style_box(base_color.lightened(0.14), Color(1.0, 0.78, 0.34, 1.0), 2, 6))
	button.add_theme_stylebox_override("pressed", make_style_box(base_color.darkened(0.14), Color(1.0, 0.88, 0.55, 1.0), 2, 6))
	button.add_theme_stylebox_override("disabled", make_style_box(Color(0.16, 0.17, 0.19, 1.0), Color(0.28, 0.3, 0.34, 1.0), 1, 6))
	button.add_theme_color_override("font_color", Color(0.98, 0.98, 0.96, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.57, 0.62, 1.0))
	button.add_theme_font_size_override("font_size", 16)

func make_card_frame() -> PanelContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", make_style_box(Color(0.16, 0.18, 0.21, 1.0), Color(0.43, 0.38, 0.25, 1.0), 1, 7))
	return frame

func make_art_rect(art_index: int, size: Vector2) -> TextureRect:
	var texture := AtlasTexture.new()
	var cell_width := float(card_art_sheet.get_width()) / card_art_cols
	var cell_height := float(card_art_sheet.get_height()) / card_art_rows
	var col := art_index % card_art_cols
	var row := floori(float(art_index) / card_art_cols)
	texture.atlas = card_art_sheet
	texture.region = Rect2(col * cell_width, row * cell_height, cell_width, cell_height)

	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = size
	return rect
