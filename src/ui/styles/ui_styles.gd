extends RefCounted
class_name UiStyles

const ARCANE_BUTTON_ORNAMENT = preload("res://src/ui/styles/arcane_button_ornament.gd")

static func _game_button_base(color: Color) -> Color:
	return Color(0.025, 0.03, 0.034, color.a).lerp(color.darkened(0.3), 0.34)

static func _game_button_accent(color: Color) -> Color:
	return color.darkened(0.12).lerp(Color(0.46, 0.68, 0.66, color.a), 0.1)

static func make_style_box(bg_color: Color, border_color: Color, border_width: int = 1, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = max(2, radius - 4)
	style.corner_radius_bottom_left = max(2, radius - 4)
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.0
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	return style

static func make_action_button_style(bg_color: Color, accent_color: Color, active: bool = false, radius: int = 5) -> StyleBoxFlat:
	var base := _game_button_base(bg_color)
	var accent := _game_button_accent(accent_color)
	var corner: int = max(radius, 11 if active else 9)
	var style := make_style_box(base, accent, 1, corner)
	style.corner_radius_top_left = corner
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = corner
	style.border_width_left = 2 if active else 1
	style.border_width_top = 1
	style.border_width_right = 2 if active else 1
	style.border_width_bottom = 3 if active else 2
	style.border_color = accent
	style.content_margin_left = 15 if active else 13
	style.content_margin_top = 9
	style.content_margin_right = 15 if active else 13
	style.content_margin_bottom = 9
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = 11 if active else 7
	style.shadow_offset = Vector2(0, 4 if active else 3)
	return style

static func apply_flat_button(button: Button, base_color: Color, accent_color: Color = Color(0.96, 0.82, 0.46, 1.0), font_size: int = 16, outline_size: int = 3) -> void:
	var base := _game_button_base(base_color)
	var accent := _game_button_accent(accent_color)
	var style_normal := make_style_box(base, accent, 2, 8)
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.shadow_size = 6
	style_normal.shadow_offset = Vector2(0, 2)
	var style_hover := style_normal.duplicate()
	style_hover.bg_color = base.lightened(0.07)
	style_hover.border_color = accent.lightened(0.12)
	var style_pressed := style_normal.duplicate()
	style_pressed.bg_color = base.darkened(0.12)
	var style_disabled := style_normal.duplicate()
	style_disabled.bg_color = Color(base.r, base.g, base.b, 0.45)
	style_disabled.border_color = Color(accent.r, accent.g, accent.b, 0.35)
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_stylebox_override("disabled", style_disabled)
	button.add_theme_color_override("font_color", Color(0.98, 0.98, 0.96, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.57, 0.62, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.03, 1.0))
	button.add_theme_constant_override("outline_size", outline_size)
	button.add_theme_font_size_override("font_size", font_size)
	ARCANE_BUTTON_ORNAMENT.attach_to(button, accent, false)

static func apply_button(button: Button, base_color: Color) -> void:
	var accent := _game_button_accent(base_color.lightened(0.42))
	var base := _game_button_base(base_color)
	var style_normal := make_action_button_style(base, accent, false, 4)
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = base.lightened(0.07)
	style_hover.border_color = accent.lightened(0.12)
	style_hover.border_width_bottom = 3
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = base.darkened(0.16)
	style_pressed.shadow_size = 3
	style_pressed.shadow_offset = Vector2(0, 1)
	var style_disabled = style_normal.duplicate()
	style_disabled.bg_color = Color(base.r, base.g, base.b, 0.38)
	style_disabled.border_color = Color(accent.r, accent.g, accent.b, 0.28)
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_stylebox_override("disabled", style_disabled)
	button.add_theme_color_override("font_color", Color(0.98, 0.98, 0.96, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.57, 0.62, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.03, 1.0))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_font_size_override("font_size", 16)
	ARCANE_BUTTON_ORNAMENT.attach_to(button, accent, false)

static func apply_primary_button(button: Button, base_color: Color = Color(0.55, 0.36, 0.1, 1.0)) -> void:
	var accent := _game_button_accent(base_color.lightened(0.48))
	var base := _game_button_base(base_color)
	var style_normal := make_action_button_style(base, accent, true, 4)
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = base.lightened(0.08)
	style_hover.border_color = accent.lightened(0.14)
	style_hover.border_width_bottom = 4
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = base.darkened(0.16)
	style_pressed.shadow_size = 4
	style_pressed.shadow_offset = Vector2(0, 1)
	var style_disabled = style_normal.duplicate()
	style_disabled.bg_color = Color(base.r, base.g, base.b, 0.38)
	style_disabled.border_color = Color(accent.r, accent.g, accent.b, 0.28)
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_stylebox_override("disabled", style_disabled)
	button.add_theme_color_override("font_color", Color(1.0, 0.98, 0.88, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.57, 0.62, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.03, 1.0))
	button.add_theme_constant_override("outline_size", 4)
	button.add_theme_font_size_override("font_size", 17)
	ARCANE_BUTTON_ORNAMENT.attach_to(button, accent, true)
