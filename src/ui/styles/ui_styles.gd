extends RefCounted
class_name UiStyles

const UI_TOKENS = preload("res://src/ui/styles/ui_tokens.gd")

const NEUTRAL_BASE := Color(0.035, 0.042, 0.055, 1.0)
const NEUTRAL_BORDER := Color(0.28, 0.32, 0.4, 1.0)

static func _game_button_base(color: Color) -> Color:
	var neutral := Color(NEUTRAL_BASE.r, NEUTRAL_BASE.g, NEUTRAL_BASE.b, color.a)
	return neutral.lerp(color, 0.3)

static func _game_button_accent(color: Color) -> Color:
	return NEUTRAL_BORDER.lerp(color, 0.52)

static func make_style_box(bg_color: Color, border_color: Color, border_width: int = 1, radius: int = 6) -> StyleBoxFlat:
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
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.0
	style.content_margin_left = 12
	style.content_margin_top = 9
	style.content_margin_right = 12
	style.content_margin_bottom = 9
	return style

static func make_action_button_style(bg_color: Color, accent_color: Color, active: bool = false, radius: int = 6) -> StyleBoxFlat:
	var base := _game_button_base(bg_color)
	var accent := _game_button_accent(accent_color)
	var style := make_style_box(base, accent, 1, clampi(radius, 4, 6))
	style.border_width_left = 2 if active else 1
	style.border_width_right = 2 if active else 1
	style.border_width_top = 1
	style.border_width_bottom = 4 if active else 3
	style.content_margin_left = 15 if active else 13
	style.content_margin_top = 9
	style.content_margin_right = 15 if active else 13
	style.content_margin_bottom = 11
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = 8 if active else 5
	style.shadow_offset = Vector2(0, 3)
	return style

static func _apply_button_text(button: Button, font_size: int, outline_size: int = 0) -> void:
	button.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.91, 0.94, 0.98, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.47, 0.5, 0.57, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	button.add_theme_constant_override("outline_size", maxi(0, outline_size))
	button.add_theme_font_size_override("font_size", font_size)

static func _button_state_styles(base_color: Color, accent_color: Color, active: bool) -> Array[StyleBoxFlat]:
	var normal := make_action_button_style(base_color, accent_color, active, 5)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.09)
	hover.border_color = normal.border_color.lightened(0.18)
	hover.shadow_size = normal.shadow_size + 2
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = normal.bg_color.darkened(0.12)
	pressed.border_width_top = 3
	pressed.border_width_bottom = 1
	pressed.content_margin_top = 12
	pressed.content_margin_bottom = 8
	pressed.shadow_size = 0
	pressed.shadow_offset = Vector2.ZERO
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(normal.bg_color.r, normal.bg_color.g, normal.bg_color.b, 0.52)
	disabled.border_color = Color(normal.border_color.r, normal.border_color.g, normal.border_color.b, 0.28)
	return [normal, hover, pressed, disabled]

static func _apply_button_styles(button: Button, styles: Array[StyleBoxFlat]) -> void:
	button.add_theme_stylebox_override("normal", styles[0])
	button.add_theme_stylebox_override("hover", styles[1])
	button.add_theme_stylebox_override("pressed", styles[2])
	button.add_theme_stylebox_override("disabled", styles[3])

static func apply_flat_button(button: Button, base_color: Color, accent_color: Color = Color(0.38, 0.62, 1.0, 1.0), font_size: int = 16, outline_size: int = 0) -> void:
	_apply_button_styles(button, _button_state_styles(base_color, accent_color, false))
	_apply_button_text(button, font_size, mini(outline_size, 1))

static func apply_button(button: Button, base_color: Color) -> void:
	var accent := _game_button_accent(base_color.lightened(0.34))
	_apply_button_styles(button, _button_state_styles(base_color, accent, false))
	_apply_button_text(button, 16)

static func apply_primary_button(button: Button, base_color: Color = Color(0.16, 0.34, 0.66, 1.0)) -> void:
	var accent := Color(0.46, 0.7, 1.0, 1.0).lerp(base_color.lightened(0.28), 0.28)
	_apply_button_styles(button, _button_state_styles(base_color, accent, true))
	_apply_button_text(button, 17)

static func apply_role_button(
	button: Button,
	role: String,
	accent_color: Color = Color(0.42, 0.68, 1.0, 1.0),
	base_override: Color = Color(0.0, 0.0, 0.0, 0.0),
	font_size: int = -1
) -> void:
	var base := Color(0.07, 0.085, 0.11, 1.0)
	var accent := Color(0.3, 0.38, 0.5, 1.0)
	var active := false
	match role:
		"primary":
			base = Color(0.09, 0.2, 0.38, 1.0)
			accent = Color(0.46, 0.7, 1.0, 1.0)
			active = true
		"danger":
			base = Color(0.24, 0.065, 0.075, 1.0)
			accent = Color(0.88, 0.28, 0.26, 1.0)
		"power":
			base = accent_color.darkened(0.72)
			accent = accent_color
			active = true
		_:
			accent = NEUTRAL_BORDER.lerp(accent_color, 0.34)
	if base_override.a > 0.0:
		base = base_override
	if role != "power" and accent_color != Color(0.42, 0.68, 1.0, 1.0):
		accent = accent.lerp(accent_color, 0.42)
	_apply_button_styles(button, _button_state_styles(base, accent, active))
	var resolved_font := font_size if font_size > 0 else UI_TOKENS.FONT_ACTION if role in ["primary", "power"] else 16
	_apply_button_text(button, resolved_font)
