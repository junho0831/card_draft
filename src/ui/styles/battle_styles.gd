extends RefCounted
class_name BattleStyles

const BATTLE_BASE := Color(0.035, 0.045, 0.06, 1.0)
const BATTLE_BORDER := Color(0.2, 0.26, 0.34, 1.0)
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

static func _load_texture(path: String) -> Texture2D:
	return ResourceLoader.load(path) as Texture2D

static func _panel_texture_for_accent(accent_color: Color) -> Texture2D:
	var texture := _load_texture(PANEL_GOLD_PATH if accent_color.r > accent_color.b + 0.08 else PANEL_BLUE_PATH)
	return texture if texture != null else _load_texture(PANEL_BLUE_PATH)

static func _make_panel_texture_style(bg_color: Color, accent_color: Color, margin: int, large: bool = false) -> StyleBox:
	return make_modern_style(bg_color, BATTLE_BORDER, 1, 10, margin)

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
	var base := Color(0.085, 0.105, 0.14)
	var accent := Color(0.25, 0.31, 0.39)
	if role == "turn":
		base = Color(0.15, 0.32, 0.37)
		accent = Color(0.35, 0.65, 0.65)
	elif role == "power":
		base = Color(0.18, 0.15, 0.105)
		accent = Color(0.5, 0.4, 0.23)
	elif active:
		base = Color(0.10, 0.18, 0.24)
		accent = Color(0.29, 0.47, 0.56)
	var normal := make_modern_style(base, accent, 1, 8, 8)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = base.lightened(0.08)
	hover.border_color = accent.lightened(0.18)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = base.darkened(0.15)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.05, 0.06, 0.08)
	disabled.border_color = Color(0.12, 0.15, 0.19)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.94, 0.96, 0.98))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.51, 0.58))
	button.add_theme_constant_override("outline_size", 0)

static func make_field_slot_style(bg_color: Color, border_color: Color, border_width: int = 2) -> StyleBoxFlat:
	var neutral_bg := Color(0.025, 0.032, 0.044, bg_color.a).lerp(bg_color, 0.3)
	var style := make_modern_style(neutral_bg, border_color, border_width, 8, 5)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style
