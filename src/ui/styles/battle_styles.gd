extends RefCounted
class_name BattleStyles

const ARCANE_BUTTON_ORNAMENT = preload("res://src/ui/styles/arcane_button_ornament.gd")

static func _battle_button_base(color: Color) -> Color:
	return Color(0.018, 0.026, 0.03, color.a).lerp(color.darkened(0.3), 0.38)

static func _battle_button_accent(color: Color) -> Color:
	return color.darkened(0.12).lerp(Color(0.4, 0.68, 0.68, color.a), 0.08)

static func make_modern_style(bg_color: Color, border_color: Color, border_width: int = 1, radius: int = 8, margin: int = 10) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = max(2, radius - 5)
	style.corner_radius_bottom_left = max(2, radius - 5)
	style.corner_radius_bottom_right = radius
	style.content_margin_left = margin
	style.content_margin_top = margin
	style.content_margin_right = margin
	style.content_margin_bottom = margin
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 5)
	return style

static func make_hand_card_style(bg_color: Color, border_color: Color, border_width: int = 2) -> StyleBoxFlat:
	var style = make_modern_style(bg_color, border_color, border_width, 8, 8)
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style

static func make_battle_surface(bg_color: Color, accent_color: Color, border_width: int = 1, radius: int = 8, margin: int = 10) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = make_modern_style(bg_color, accent_color, border_width, min(radius, 8), margin)
	style.content_margin_left = margin
	style.content_margin_top = margin
	style.content_margin_right = margin
	style.content_margin_bottom = margin
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)
	return panel

static func apply_battle_button(button: Button, bg_color: Color, accent_color: Color, active: bool = false) -> void:
	var base := _battle_button_base(bg_color)
	var accent := _battle_button_accent(accent_color)
	var corner := 11 if active else 9
	var normal = make_modern_style(base, accent, 1, corner, 8)
	normal.corner_radius_top_right = 2
	normal.corner_radius_bottom_left = 2
	normal.border_width_left = 2 if active else 1
	normal.border_width_top = 1
	normal.border_width_right = 2 if active else 1
	normal.border_width_bottom = 3 if active else 2
	normal.content_margin_left = 13 if active else 11
	normal.content_margin_top = 8
	normal.content_margin_right = 13 if active else 11
	normal.content_margin_bottom = 8
	normal.shadow_size = 11 if active else 6
	normal.shadow_offset = Vector2(0, 4 if active else 3)
	var hover = normal.duplicate()
	hover.bg_color = base.lightened(0.08)
	hover.border_color = accent.lightened(0.14)
	hover.border_width_bottom = 4 if active else 3
	var pressed = normal.duplicate()
	pressed.bg_color = base.darkened(0.16)
	pressed.shadow_size = 3
	pressed.shadow_offset = Vector2(0, 1)
	var disabled = normal.duplicate()
	disabled.bg_color = Color(base.r, base.g, base.b, 0.42)
	disabled.border_color = Color(accent.r, accent.g, accent.b, 0.34)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.5, 0.58, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.65))
	button.add_theme_constant_override("outline_size", 2)
	ARCANE_BUTTON_ORNAMENT.attach_to(button, accent, active)

static func make_field_slot_style(bg_color: Color, border_color: Color, border_width: int = 2) -> StyleBoxFlat:
	var style: StyleBoxFlat = make_modern_style(bg_color, border_color, border_width, 8, 6)
	style.content_margin_left = 6
	style.content_margin_top = 5
	style.content_margin_right = 6
	style.content_margin_bottom = 5
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 3)
	return style
