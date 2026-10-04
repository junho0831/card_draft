extends RefCounted
class_name BattleStyles
const ButtonMetrics = preload("res://src/ui/styles/button_metrics.gd")
const UiStyles = preload("res://src/ui/styles/ui_styles.gd")
const Tokens = preload("res://src/ui/styles/ui_tokens.gd")

const BATTLE_BASE := Tokens.SURFACE
const BATTLE_BORDER := Tokens.BORDER
const BUTTON_GOLD_PATH := "res://assets/ui/generated/slices/button_gold.png"
const BUTTON_BLUE_PATH := "res://assets/ui/generated/slices/button_blue.png"
const BUTTON_RED_PATH := "res://assets/ui/generated/slices/button_red.png"
const BUTTON_DARK_PATH := "res://assets/ui/generated/slices/button_dark.png"
const PANEL_GOLD_PATH := "res://assets/ui/generated/slices/panel_gold.png"
const PANEL_BLUE_PATH := "res://assets/ui/generated/slices/panel_blue.png"

static func _battle_button_base(color: Color) -> Color:
	var neutral := Color(BATTLE_BASE.r, BATTLE_BASE.g, BATTLE_BASE.b, color.a)
	return neutral.lerp(color, 0.2)

static func _battle_button_accent(color: Color) -> Color:
	return BATTLE_BORDER.lerp(color, 0.58)

static func make_flat_style(bg_color: Color, border_color: Color, border_width: int = 1, radius: int = 6, margin: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(mini(radius, 8))
	style.set_content_margin_all(margin)
	return style

static func apply_compact_button(button: Button, accent: Color) -> void:
	UiStyles.apply_role_button(button, "secondary", accent, Color.TRANSPARENT, 14)
	ButtonMetrics.apply(button, String(button.get_meta("button_kind", "action")))

static func make_modern_style(bg_color: Color, border_color: Color, border_width: int = 1, radius: int = 8, margin: int = 10) -> StyleBoxFlat:
	var style := make_flat_style(bg_color, border_color, border_width, radius, margin)
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

static func _load_texture(path: String) -> Texture2D:
	return ResourceLoader.load(path) as Texture2D

static func _panel_texture_for_accent(accent_color: Color) -> Texture2D:
	var texture := _load_texture(PANEL_GOLD_PATH if accent_color.r > accent_color.b + 0.08 else PANEL_BLUE_PATH)
	return texture if texture != null else _load_texture(PANEL_BLUE_PATH)

static func _make_panel_texture_style(bg_color: Color, accent_color: Color, margin: int, large: bool = false) -> StyleBox:
	return UiStyles.make_textured_panel_style(Tokens.SURFACE, BATTLE_BORDER, margin)

static func make_battle_surface(bg_color: Color, accent_color: Color, border_width: int = 1, radius: int = 8, margin: int = 10) -> PanelContainer:
	var panel := PanelContainer.new()
	var neutral_bg := Color(0.025, 0.035, 0.048, bg_color.a).lerp(bg_color, 0.28)
	var neutral_border := BATTLE_BORDER.lerp(accent_color, 0.34)
	var style: StyleBox = _make_panel_texture_style(neutral_bg, neutral_border, margin, radius >= 10 and margin >= 8) if radius >= 8 and margin >= 6 else make_modern_style(neutral_bg, neutral_border, border_width, radius, margin)
	if style is StyleBoxFlat:
		var flat_style := style as StyleBoxFlat
		flat_style.shadow_size = 3
		flat_style.shadow_offset = Vector2(0, 1)
	panel.add_theme_stylebox_override("panel", style)
	return panel

static func make_action_dock_style(accent_color: Color, margin: int = 8) -> StyleBox:
	var style: StyleBox = _make_panel_texture_style(Color(0.02, 0.027, 0.038, 0.98), BATTLE_BORDER.lerp(accent_color, 0.42), margin + 2, true)
	if style is StyleBoxFlat:
		var flat_style := style as StyleBoxFlat
		flat_style.border_width_top = 3
		flat_style.border_width_bottom = 1
		flat_style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
		flat_style.shadow_size = 9
		flat_style.shadow_offset = Vector2(0, 4)
	return style

static func _button_texture_for_role(role: String, accent_color: Color) -> Texture2D:
	var path := BUTTON_DARK_PATH
	match role:
		"primary", "power":
			path = BUTTON_GOLD_PATH
		"turn":
			path = BUTTON_BLUE_PATH
		_:
			if accent_color.r > accent_color.b + 0.1 and accent_color.r > accent_color.g:
				path = BUTTON_RED_PATH
			elif accent_color.b > accent_color.r + 0.06:
				path = BUTTON_BLUE_PATH
	var texture := _load_texture(path)
	return texture if texture != null else _load_texture(BUTTON_DARK_PATH)

static func _make_battle_button_texture_style(texture: Texture2D, tint: Color, active: bool, role: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 76
	style.texture_margin_top = 42
	style.texture_margin_right = 76
	style.texture_margin_bottom = 42
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = 18 if role == "power" else (16 if active else 14)
	style.content_margin_top = 9
	style.content_margin_right = 18 if role == "turn" else (16 if active else 14)
	style.content_margin_bottom = 12
	style.modulate_color = tint
	return style

static func apply_battle_button(button: Button, bg_color: Color, accent_color: Color, active: bool = false, role: String = "action") -> void:
	UiStyles.apply_role_button(button, "primary" if role == "turn" else "secondary", accent_color, Color.TRANSPARENT, 16)

static func make_field_slot_style(bg_color: Color, border_color: Color, border_width: int = 2) -> StyleBoxFlat:
	var neutral_bg := Color(0.025, 0.032, 0.044, bg_color.a).lerp(bg_color, 0.3)
	var style := make_modern_style(neutral_bg, border_color, border_width, 8, 5)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


static func add_active_outline(frame: Control, color: Color) -> void:
	var outline := Panel.new()
	outline.name = "ActiveOutline"
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outline.offset_left = -3
	outline.offset_top = -3
	outline.offset_right = 3
	outline.offset_bottom = 3
	outline.z_index = 2
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.draw_center = false
	style.set_border_width_all(2)
	style.border_color = color
	style.set_corner_radius_all(7)
	style.shadow_color = Color(color, 0.38)
	style.shadow_size = 6
	outline.add_theme_stylebox_override("panel", style)
	frame.add_child(outline)


static func make_button_flat_style(bg_color: Color, border_color: Color, border_width: int, radius: int, margin_x: int, margin_y: int, shadow_size: int = 5) -> StyleBoxFlat:
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
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.44)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, maxi(1, shadow_size / 3))
	return style


static func apply_custom_button_style(button: Button, bg_color: Color, border_color: Color, font_color: Color, border_width: int, radius: int, margin_x: int, margin_y: int, shadow_size: int, outline_size: int = 2) -> void:
	var normal := make_button_flat_style(bg_color, border_color, border_width, radius, margin_x, margin_y, shadow_size)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = bg_color.lightened(0.08)
	hover.border_color = border_color.lightened(0.16)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = bg_color.darkened(0.1)
	pressed.shadow_size = maxi(1, shadow_size - 3)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(bg_color.r * 0.62, bg_color.g * 0.62, bg_color.b * 0.62, bg_color.a * 0.78)
	disabled.border_color = Color(border_color.r * 0.5, border_color.g * 0.5, border_color.b * 0.5, 0.72)
	disabled.shadow_size = 1
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color.lightened(0.08))
	button.add_theme_color_override("font_pressed_color", font_color.darkened(0.06))
	button.add_theme_color_override("font_disabled_color", Color(0.52, 0.56, 0.62, 1.0))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
	button.add_theme_constant_override("outline_size", outline_size)
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true


static func make_card_frame(border_color: Color, margin: int = 7) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/ui/fantasy/panel_gold.svg" if border_color.r > border_color.b else "res://assets/ui/fantasy/panel_blue.svg")
	style.modulate_color = border_color.lightened(0.25)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 12)
		style.set_content_margin(side, margin)
	return style
