extends RefCounted
class_name CardRaceStyles

static func visual_meta(race: String) -> Dictionary:
	match race:
		"인간":
			return {
				"mark": "⚜",
				"display_name": "인간",
				"lineage": "왕국",
				"accent": Color(0.96, 0.69, 0.22, 1.0),
				"surface": Color(0.11, 0.075, 0.025, 1.0),
				"band": Color(0.23, 0.145, 0.035, 1.0),
				"rules": Color(0.145, 0.095, 0.035, 0.98),
				"text": Color(1.0, 0.88, 0.54, 1.0),
				"radius": 4,
			}
		"엘프":
			return {
				"mark": "❧",
				"display_name": "엘프",
				"lineage": "숲",
				"accent": Color(0.25, 0.82, 0.52, 1.0),
				"surface": Color(0.022, 0.085, 0.064, 1.0),
				"band": Color(0.032, 0.18, 0.115, 1.0),
				"rules": Color(0.03, 0.12, 0.085, 0.98),
				"text": Color(0.68, 1.0, 0.82, 1.0),
				"radius": 8,
			}
		"언데드":
			return {
				"mark": "☠",
				"display_name": "언데드",
				"lineage": "망자",
				"accent": Color(0.72, 0.4, 1.0, 1.0),
				"surface": Color(0.078, 0.034, 0.11, 1.0),
				"band": Color(0.17, 0.055, 0.25, 1.0),
				"rules": Color(0.115, 0.042, 0.165, 0.98),
				"text": Color(0.9, 0.7, 1.0, 1.0),
				"radius": 2,
			}
		"정령":
			return {
				"mark": "✦",
				"display_name": "정령",
				"lineage": "원소",
				"accent": Color(0.2, 0.8, 0.86, 1.0),
				"surface": Color(0.025, 0.075, 0.095, 1.0),
				"band": Color(0.03, 0.145, 0.18, 1.0),
				"rules": Color(0.025, 0.1, 0.13, 0.98),
				"text": Color(0.68, 0.96, 1.0, 1.0),
				"radius": 6,
			}
		"중립":
			return {
				"mark": "◆",
				"display_name": "공용",
				"lineage": "모든 세력",
				"accent": Color(0.68, 0.76, 0.86, 1.0),
				"surface": Color(0.045, 0.057, 0.073, 1.0),
				"band": Color(0.09, 0.115, 0.145, 1.0),
				"rules": Color(0.058, 0.077, 0.1, 0.98),
				"text": Color(0.86, 0.92, 0.98, 1.0),
				"radius": 5,
			}
		_:
			return visual_meta("중립")

static func make_frame_style(
	race: String,
	state_tint: Color = Color(0.0, 0.0, 0.0, 0.0),
	border_width: int = 2,
	margin: int = 7,
	emphasis: float = 0.0,
	accent_override: Color = Color(0.0, 0.0, 0.0, 0.0)
) -> StyleBoxFlat:
	var meta := visual_meta(race)
	var accent: Color = accent_override if accent_override.a > 0.0 else meta["accent"]
	var surface: Color = meta["surface"]
	if state_tint.a > 0.0:
		surface = surface.lerp(state_tint, 0.34)
	surface = surface.lerp(accent, clampf(emphasis, 0.0, 0.24))
	var style := StyleBoxFlat.new()
	style.bg_color = surface
	style.border_color = accent.lightened(clampf(emphasis, 0.0, 0.2))
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width + (2 if race == "인간" else 1)
	if race == "언데드":
		style.border_width_left = border_width + 1
		style.border_width_right = maxi(1, border_width - 1)
	elif race == "엘프":
		style.border_width_left = border_width + 1
		style.border_width_right = border_width + 1
	elif race == "중립":
		style.border_width_top = border_width + 1
		style.border_width_bottom = border_width + 2
	var radius := int(meta["radius"])
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = margin
	style.content_margin_top = margin
	style.content_margin_right = margin
	style.content_margin_bottom = margin + 1
	style.shadow_color = Color(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, 0.72)
	style.shadow_size = 7 if emphasis > 0.0 else 5
	style.shadow_offset = Vector2(0, 3)
	style.anti_aliasing = true
	return style

static func make_band_style(race: String, margin: int = 3) -> StyleBoxFlat:
	var meta := visual_meta(race)
	var style := StyleBoxFlat.new()
	style.bg_color = meta["band"]
	style.border_color = Color(meta["accent"]).lightened(0.08)
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	var radius := int(meta["radius"])
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = margin + 3
	style.content_margin_top = margin
	style.content_margin_right = margin + 2
	style.content_margin_bottom = margin
	return style

static func make_rules_style(race: String, margin: int = 6) -> StyleBoxFlat:
	var meta := visual_meta(race)
	var style := StyleBoxFlat.new()
	style.bg_color = meta["rules"]
	style.border_color = Color(meta["accent"]).darkened(0.2)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	var radius := mini(5, int(meta["radius"]))
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = margin
	style.content_margin_top = margin
	style.content_margin_right = margin
	style.content_margin_bottom = margin
	return style
