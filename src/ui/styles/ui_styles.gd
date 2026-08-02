extends RefCounted
class_name UiStyles

const UI_TOKENS = preload("res://src/ui/styles/ui_tokens.gd")
const BUTTON_GOLD_PATH := "res://assets/ui/generated/slices/button_gold.png"
const BUTTON_BLUE_PATH := "res://assets/ui/generated/slices/button_blue.png"
const BUTTON_RED_PATH := "res://assets/ui/generated/slices/button_red.png"
const BUTTON_DARK_PATH := "res://assets/ui/generated/slices/button_dark.png"
const PANEL_GOLD_PATH := "res://assets/ui/generated/slices/panel_gold.png"
const PANEL_BLUE_PATH := "res://assets/ui/generated/slices/panel_blue.png"

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

static func _load_texture(path: String) -> Texture2D:
	return ResourceLoader.load(path) as Texture2D

static func _panel_texture_for_accent(accent_color: Color) -> Texture2D:
	var path := PANEL_GOLD_PATH if accent_color.r >= accent_color.b else PANEL_BLUE_PATH
	var texture := _load_texture(path)
	return texture if texture != null else _load_texture(PANEL_BLUE_PATH)

static func make_textured_panel_style(bg_color: Color, accent_color: Color, margin: int = 12, gold_bias: bool = false) -> StyleBox:
	var texture := _load_texture(PANEL_GOLD_PATH) if gold_bias else _panel_texture_for_accent(accent_color)
	if texture == null:
		return make_style_box(bg_color, accent_color, 1, 8)
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 112
	style.texture_margin_top = 84
	style.texture_margin_right = 112
	style.texture_margin_bottom = 84
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = margin + 6
	style.content_margin_top = margin + 4
	style.content_margin_right = margin + 6
	style.content_margin_bottom = margin + 4
	style.modulate_color = Color(0.9, 0.92, 0.96, bg_color.a)
	return style

static func _button_texture_for_role(role: String, accent_color: Color) -> Texture2D:
	var path := BUTTON_DARK_PATH
	match role:
		"primary", "power":
			path = BUTTON_GOLD_PATH
		"danger":
			path = BUTTON_RED_PATH
		"turn":
			path = BUTTON_BLUE_PATH
		_:
			if accent_color.r > accent_color.b + 0.12 and accent_color.r > accent_color.g:
				path = BUTTON_RED_PATH
			elif accent_color.b > accent_color.r + 0.08:
				path = BUTTON_BLUE_PATH
	var texture := _load_texture(path)
	return texture if texture != null else _load_texture(BUTTON_DARK_PATH)

static func _make_textured_button_style(texture: Texture2D, tint: Color, active: bool = false) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 76
	style.texture_margin_top = 42
	style.texture_margin_right = 76
	style.texture_margin_bottom = 42
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = 18 if active else 15
	style.content_margin_top = 10
	style.content_margin_right = 18 if active else 15
	style.content_margin_bottom = 12
	style.modulate_color = tint
	return style

static func _textured_button_state_styles(role: String, accent_color: Color, active: bool) -> Array[StyleBox]:
	var texture := _button_texture_for_role(role, accent_color)
	var normal := _make_textured_button_style(texture, Color(0.92, 0.94, 0.98, 1.0), active)
	var hover: StyleBoxTexture = normal.duplicate()
	hover.modulate_color = Color(1.08, 1.08, 1.1, 1.0)
	var pressed: StyleBoxTexture = normal.duplicate()
	pressed.modulate_color = Color(0.78, 0.8, 0.84, 1.0)
	pressed.content_margin_top = 13
	pressed.content_margin_bottom = 9
	var disabled: StyleBoxTexture = normal.duplicate()
	disabled.modulate_color = Color(0.52, 0.55, 0.6, 0.62)
	return [normal, hover, pressed, disabled]

static func _apply_button_text(button: Button, font_size: int, outline_size: int = 0) -> void:
	button.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.91, 0.94, 0.98, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.47, 0.5, 0.57, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	button.add_theme_constant_override("outline_size", maxi(0, outline_size))
	button.add_theme_font_size_override("font_size", font_size)

static func _button_state_styles(base_color: Color, accent_color: Color, active: bool) -> Array[StyleBox]:
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

static func _apply_button_styles(button: Button, styles: Array[StyleBox]) -> void:
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
	_apply_button_styles(button, _textured_button_state_styles(role, accent, active))
	var resolved_font := font_size if font_size > 0 else UI_TOKENS.FONT_ACTION if role in ["primary", "power"] else 16
	_apply_button_text(button, resolved_font, 2 if role in ["primary", "power"] else 1)
