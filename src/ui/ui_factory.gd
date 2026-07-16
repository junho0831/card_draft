extends RefCounted
class_name UiFactory

const UI_STYLES = preload("res://src/ui/styles/ui_styles.gd")

var card_art_sheet: Texture2D
var card_art_cols := 4
var card_art_rows := 3
var card_art_cache := {}
const COMPACT_BREAKPOINT := 860.0
const SCREEN_MARGIN := 10.0
const MIN_RESPONSIVE_WIDTH := 280.0
const THEME_BG := Color(0.025, 0.032, 0.042, 1.0)
const THEME_PANEL := Color(0.065, 0.075, 0.085, 0.98)
const THEME_PANEL_DARK := Color(0.035, 0.045, 0.055, 1.0)
const THEME_GOLD := Color(0.86, 0.65, 0.28, 1.0)
const THEME_GOLD_SOFT := Color(1.0, 0.86, 0.52, 1.0)
const THEME_BLUE := Color(0.12, 0.28, 0.48, 1.0)
const THEME_GREEN := Color(0.15, 0.3, 0.16, 1.0)
const THEME_RED := Color(0.42, 0.13, 0.12, 1.0)
const THEME_TEXT := Color(0.94, 0.96, 0.94, 1.0)
const THEME_TEXT_MUTED := Color(0.72, 0.76, 0.8, 1.0)

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
	root.custom_minimum_size = Vector2(max(320.0, viewport_size.x - SCREEN_MARGIN * 2.0), 0.0)

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
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var panel := make_surface_panel(color.darkened(0.04), color.lightened(0.08), 1, 10, 10)
	panel.custom_minimum_size = Vector2(96 if compact else 126, 68 if compact else 76)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var title_label := make_label(title, 12, Color(0.9, 0.92, 0.94, 1.0))
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var value_label := make_label(value, 19 if compact else 20, Color(1.0, 0.98, 0.9, 1.0))
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

func make_guidance_banner(title: String, value: String, color: Color, compact: bool = false) -> PanelContainer:
	var panel := make_surface_panel(color.darkened(0.08), Color(0.38, 0.34, 0.18, 1.0), 1, 10, 12)
	panel.custom_minimum_size = Vector2(0, 54 if compact else 62)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var title_label := make_label(title, 12 if compact else 13, Color(1.0, 0.88, 0.55, 1.0))
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.custom_minimum_size = Vector2(82 if compact else 110, 0)
	var value_label := make_label(value, 16 if compact else 18, Color(1.0, 0.98, 0.86, 1.0))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	row.add_child(value_label)
	return panel

func add_title(parent: Node, text: String) -> void:
	var title := make_label(text, 40, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.018, 1.0))
	parent.add_child(title)

func begin_screen(root: Node, title: String, summary: Control = null, spacing: int = 12, subtitle: String = "") -> VBoxContainer:
	var sub := subtitle
	if sub.is_empty():
		sub = "지금 무엇을 해야 하는지와 이번 런의 빌드를 확인하세요."
	root.add_child(make_screen_header(title, sub))
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
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	if not callback_method.is_empty():
		button.pressed.connect(Callable(target, callback_method))
	parent.add_child(button)
	return button

func make_panel_container(color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := make_style_box(color, color.lightened(0.14), 1, 10)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func make_premium_panel(min_height: int = 0, prominent: bool = false) -> PanelContainer:
	var border_color := THEME_GOLD if prominent else Color(0.24, 0.21, 0.15, 1.0)
	var border_width := 2 if prominent else 1
	var panel := make_surface_panel(THEME_PANEL, border_color, border_width, 12, 16)
	if min_height > 0:
		panel.custom_minimum_size = Vector2(0, min_height)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel

func make_screen_header(title: String, subtitle: String, compact: bool = false) -> PanelContainer:
	var panel := make_surface_panel(THEME_PANEL_DARK, Color(0.34, 0.27, 0.15, 1.0), 1, 12, 14)
	panel.custom_minimum_size = Vector2(0, 58 if compact else 66)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 4)
	row.add_child(title_box)
	var title_label := make_label(title, 22 if compact else 26, THEME_GOLD_SOFT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.add_theme_color_override("font_outline_color", Color(0.01, 0.012, 0.014, 1.0))
	title_label.add_theme_constant_override("outline_size", 5)
	title_box.add_child(title_label)
	if not subtitle.is_empty():
		var subtitle_label := make_label(subtitle, 12 if compact else 13, THEME_TEXT_MUTED)
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_box.add_child(subtitle_label)
	return panel

func make_large_action_button(title: String, subtitle: String, icon_text: String, base_color: Color, compact: bool = false) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 82 if compact else 96)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = "%s  %s\n%s" % [icon_text, title, subtitle]
	button.add_theme_font_size_override("font_size", 16 if compact else 18)
	
	var accent := base_color.lightened(0.46)
	var style_normal := make_action_button_style(base_color.darkened(0.06), accent, true, 5)
	style_normal.content_margin_left = 20
	style_normal.content_margin_top = 12
	style_normal.content_margin_right = 16
	style_normal.content_margin_bottom = 12
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = base_color.lightened(0.08)
	style_hover.border_color = accent.lightened(0.14)
	style_hover.border_width_bottom = 4
	
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = base_color.darkened(0.18)
	style_pressed.shadow_size = 4
	style_pressed.shadow_offset = Vector2(0, 1)
	
	var style_disabled = style_normal.duplicate()
	style_disabled.bg_color = Color(base_color.r, base_color.g, base_color.b, 0.38)
	style_disabled.border_color = Color(accent.r, accent.g, accent.b, 0.28)
	
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_stylebox_override("disabled", style_disabled)
	button.add_theme_color_override("font_color", THEME_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.52, 0.56, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.01, 0.012, 0.014, 1.0))
	button.add_theme_constant_override("outline_size", 4)
	_apply_hover_feedback(button)
	return button

func make_objective_panel(title: String, objective: String, compact: bool = false) -> PanelContainer:
	var panel := make_surface_panel(Color(0.09, 0.11, 0.08, 0.98), Color(0.48, 0.4, 0.18, 1.0), 1, 10, 12)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title_label := make_label(title, 12 if compact else 13, THEME_GOLD_SOFT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(title_label)
	var objective_label := make_label(objective, 15 if compact else 17, Color(0.98, 0.96, 0.82, 1.0))
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(objective_label)
	return panel

func make_surface_panel(bg_color: Color, border_color: Color = Color(0.32, 0.35, 0.4, 1.0), border_width: int = 1, radius: int = 10, margins: int = 12) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := make_style_box(bg_color, border_color, border_width, min(radius, 8))
	style.content_margin_left = margins
	style.content_margin_top = margins
	style.content_margin_right = margins
	style.content_margin_bottom = margins
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func make_fantasy_card_panel(tint: Color, margins: int = 10) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := make_style_box(Color(0.055, 0.065, 0.078, 0.98), tint, 2, 8)
	style.content_margin_left = margins
	style.content_margin_top = margins
	style.content_margin_right = margins
	style.content_margin_bottom = margins
	panel.add_theme_stylebox_override("panel", style)
	return panel

func style_card_title(label: Label, compact: bool = false) -> void:
	label.add_theme_font_size_override("font_size", 13 if compact else 15)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.07, 0.04, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 3 if compact else 4)

func style_card_rules(label: Label, compact: bool = false, muted: bool = false) -> void:
	label.add_theme_font_size_override("font_size", 10 if compact else 12)
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84, 0.72) if muted else Color(0.98, 0.95, 0.86, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.025, 0.02, 0.9))
	label.add_theme_constant_override("outline_size", 2)

func make_chip(text: String, bg_color: Color, text_color: Color = Color(0.96, 0.97, 0.94, 1.0), font_size: int = 14) -> PanelContainer:
	var panel := make_surface_panel(bg_color, bg_color.lightened(0.22), 1, 8, 10)
	panel.custom_minimum_size = Vector2(0, 44)
	var label := make_label(text, font_size, text_color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel.add_child(label)
	return panel

func race_color(race: String) -> Color:
	match race:
		"인간":
			return Color(0.92, 0.68, 0.24, 1.0)
		"엘프":
			return Color(0.28, 0.74, 0.38, 1.0)
		"언데드":
			return Color(0.58, 0.34, 0.92, 1.0)
		"정령":
			return Color(0.18, 0.74, 0.78, 1.0)
		"중립":
			return Color(0.62, 0.66, 0.7, 1.0)
		_:
			return Color(0.62, 0.66, 0.7, 1.0)

func card_race_color(card: Dictionary) -> Color:
	return race_color(String(card.get("race", "")))

func relic_visual_meta(relic: Dictionary) -> Dictionary:
	var tags: Array = relic.get("build_tags", [])
	var tag := ""
	for tag_value in tags:
		var candidate := String(tag_value)
		if candidate in ["fire", "draw", "buff", "summon", "death", "low_hp"]:
			tag = candidate
			break
	match tag:
		"fire":
			return {"icon": "◆", "bg": Color(0.36, 0.12, 0.06, 1.0), "accent": Color(1.0, 0.36, 0.14, 1.0)}
		"draw":
			return {"icon": "▣", "bg": Color(0.08, 0.18, 0.34, 1.0), "accent": Color(0.38, 0.68, 1.0, 1.0)}
		"buff":
			return {"icon": "⚑", "bg": Color(0.28, 0.2, 0.06, 1.0), "accent": Color(1.0, 0.78, 0.24, 1.0)}
		"summon":
			return {"icon": "✦", "bg": Color(0.08, 0.24, 0.16, 1.0), "accent": Color(0.38, 0.86, 0.56, 1.0)}
		"death":
			return {"icon": "☠", "bg": Color(0.18, 0.1, 0.28, 1.0), "accent": Color(0.72, 0.42, 1.0, 1.0)}
		"low_hp":
			return {"icon": "♥", "bg": Color(0.3, 0.08, 0.1, 1.0), "accent": Color(1.0, 0.36, 0.42, 1.0)}
		_:
			return {"icon": "◆", "bg": Color(0.14, 0.14, 0.18, 1.0), "accent": Color(0.7, 0.66, 0.9, 1.0)}

func make_relic_badge(relic: Dictionary, compact: bool = false, show_text: bool = true) -> PanelContainer:
	var meta := relic_visual_meta(relic)
	var bg: Color = meta["bg"]
	var accent: Color = meta["accent"]
	var panel := make_surface_panel(bg, accent, 1, 8, 8 if compact else 10)
	panel.custom_minimum_size = Vector2((118 if compact else 144) if show_text else 38, 38 if compact else 44)
	panel.tooltip_text = String(relic.get("text", ""))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6 if compact else 8)
	panel.add_child(row)
	var icon := make_label(String(meta.get("icon", "◆")), 14 if compact else 16, accent.lightened(0.2))
	icon.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(icon)
	if show_text:
		var label := make_label(String(relic.get("name", "유물")), 12 if compact else 13, Color(0.96, 0.94, 1.0, 1.0))
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = true
		label.custom_minimum_size = Vector2(72 if compact else 92, 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
	return panel

func make_cost_badge(value: String, compact: bool = false) -> PanelContainer:
	var size := 32 if compact else 38
	var panel := make_surface_panel(Color(0.08, 0.24, 0.48, 1.0), Color(0.9, 0.72, 0.32, 1.0), 2, size / 2, 4)
	panel.custom_minimum_size = Vector2(size, size)
	var label := make_label(value, 16 if compact else 19, Color(1.0, 0.96, 0.84, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.04, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	panel.add_child(label)
	return panel

func make_stat_badge(value: String, bg_color: Color, compact: bool = false) -> PanelContainer:
	var panel := make_surface_panel(bg_color, bg_color.lightened(0.2), 1, 8, 6)
	panel.custom_minimum_size = Vector2(42 if compact else 48, 28 if compact else 32)
	var label := make_label(value, 13 if compact else 15, Color(1.0, 0.96, 0.86, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 2)
	panel.add_child(label)
	return panel

func make_style_box(bg_color: Color, border_color: Color, border_width: int = 1, radius: int = 6) -> StyleBoxFlat:
	return UI_STYLES.make_style_box(bg_color, border_color, border_width, radius)

func make_action_button_style(bg_color: Color, accent_color: Color, active: bool = false, radius: int = 5) -> StyleBoxFlat:
	return UI_STYLES.make_action_button_style(bg_color, accent_color, active, radius)

func style_flat_button(button: Button, base_color: Color, accent_color: Color = Color(0.96, 0.82, 0.46, 1.0), font_size: int = 16, outline_size: int = 3) -> void:
	UI_STYLES.apply_flat_button(button, base_color, accent_color, font_size, outline_size)
	_apply_hover_feedback(button)

func style_button(button: Button, base_color: Color) -> void:
	UI_STYLES.apply_button(button, base_color)
	_apply_hover_feedback(button)

func style_primary_button(button: Button, base_color: Color = Color(0.55, 0.36, 0.1, 1.0)) -> void:
	UI_STYLES.apply_primary_button(button, base_color)
	_apply_hover_feedback(button)

func make_card_frame() -> PanelContainer:
	var frame := make_fantasy_card_panel(Color(0.88, 0.74, 0.44, 1.0), 10)
	return frame

func make_art_rect(art_index: int, size: Vector2) -> TextureRect:
	return _make_texture_rect(_make_sheet_art_texture(art_index), size)

func make_card_art_rect(card: Dictionary, size: Vector2) -> TextureRect:
	return _make_texture_rect(card_art_texture(card), size)

func card_art_texture(card: Dictionary) -> Texture2D:
	var art_id := String(card.get("art_id", ""))
	if not art_id.is_empty():
		var path := "res://assets/card_art/cards/%s.png" % art_id
		if card_art_cache.has(path):
			return card_art_cache[path]
		if FileAccess.file_exists(path):
			var texture := ResourceLoader.load(path) as Texture2D
			if texture != null:
				card_art_cache[path] = texture
				return texture
	return _make_sheet_art_texture(int(card.get("art", 0)))

func _make_sheet_art_texture(art_index: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	var cell_width := float(card_art_sheet.get_width()) / card_art_cols
	var cell_height := float(card_art_sheet.get_height()) / card_art_rows
	var col := art_index % card_art_cols
	var row := floori(float(art_index) / card_art_cols)
	texture.atlas = card_art_sheet
	texture.region = Rect2(col * cell_width, row * cell_height, cell_width, cell_height)
	return texture

func _make_texture_rect(texture: Texture2D, size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = size
	return rect

func _apply_hover_feedback(button: Button) -> void:
	button.pivot_offset = button.size / 2.0
	button.mouse_entered.connect(func():
		if button == null or not is_instance_valid(button):
			return
		var root = Engine.get_main_loop().current_scene
		if root != null and root.get("audio_manager") != null:
			root.audio_manager.play_sound("hover")
		button.pivot_offset = button.size / 2.0
		var tween := button.create_tween()
		tween.tween_property(button, "scale", Vector2(1.02, 1.02), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	button.mouse_exited.connect(func():
		if button == null or not is_instance_valid(button):
			return
		var tween := button.create_tween()
		tween.tween_property(button, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
