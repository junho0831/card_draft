extends RefCounted
class_name BattleStyles

const BATTLE_BASE := Color(0.035, 0.045, 0.06, 1.0)
const BATTLE_BORDER := Color(0.2, 0.26, 0.34, 1.0)

static func _battle_button_base(color: Color) -> Color:
	var neutral := Color(BATTLE_BASE.r, BATTLE_BASE.g, BATTLE_BASE.b, color.a)
	return neutral.lerp(color, 0.2)

static func _battle_button_accent(color: Color) -> Color:
	return BATTLE_BORDER.lerp(color, 0.58)

static func make_modern_style(bg_color: Color, border_color: Color, border_width: int = 1, radius: int = 8, margin: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	var corner := mini(radius, 8)
	style.corner_radius_top_left = corner
	style.corner_radius_top_right = corner
	style.corner_radius_bottom_left = corner
	style.corner_radius_bottom_right = corner
	style.content_margin_left = margin
	style.content_margin_top = margin
	style.content_margin_right = margin
	style.content_margin_bottom = margin
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style

static func make_hand_card_style(bg_color: Color, border_color: Color, border_width: int = 2) -> StyleBoxFlat:
	var neutral_bg := Color(0.055, 0.062, 0.075, bg_color.a).lerp(bg_color, 0.22)
	var style := make_modern_style(neutral_bg, border_color, border_width, 8, 7)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 3)
	return style

static func make_battle_surface(bg_color: Color, accent_color: Color, border_width: int = 1, radius: int = 8, margin: int = 10) -> PanelContainer:
	var panel := PanelContainer.new()
	var neutral_bg := Color(0.025, 0.035, 0.048, bg_color.a).lerp(bg_color, 0.28)
	var neutral_border := BATTLE_BORDER.lerp(accent_color, 0.34)
	var style := make_modern_style(neutral_bg, neutral_border, border_width, radius, margin)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 1)
	panel.add_theme_stylebox_override("panel", style)
	return panel

static func apply_battle_button(button: Button, bg_color: Color, accent_color: Color, active: bool = false) -> void:
	var base := _battle_button_base(bg_color)
	var accent := _battle_button_accent(accent_color)
	var normal := make_modern_style(base, accent, 1, 7, 7)
	normal.border_width_left = 3 if active else 1
	normal.content_margin_left = 12 if active else 10
	normal.content_margin_right = 10
	normal.shadow_size = 5 if active else 2
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = base.lightened(0.08)
	hover.border_color = accent.lightened(0.12)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = base.darkened(0.1)
	pressed.shadow_size = 1
	pressed.shadow_offset = Vector2(0, 1)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(base.r, base.g, base.b, 0.48)
	disabled.border_color = Color(accent.r, accent.g, accent.b, 0.26)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.5, 0.58, 1.0))
	button.add_theme_constant_override("outline_size", 0)

static func make_field_slot_style(bg_color: Color, border_color: Color, border_width: int = 2) -> StyleBoxFlat:
	var neutral_bg := Color(0.025, 0.032, 0.044, bg_color.a).lerp(bg_color, 0.3)
	var style := make_modern_style(neutral_bg, border_color, border_width, 8, 5)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style
