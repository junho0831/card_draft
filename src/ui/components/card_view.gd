extends RefCounted
class_name CardView

const UI_TOKENS = preload("res://src/ui/styles/ui_tokens.gd")

static func metrics(mode: String, compact: bool = false, tight: bool = false) -> Dictionary:
	return UI_TOKENS.card_metrics(mode, compact, tight)

static func make_name_band(
	main: Node,
	card: Dictionary,
	mode: String,
	compact: bool = false,
	tight: bool = false,
	suffix: String = ""
) -> PanelContainer:
	var values := metrics(mode, compact, tight)
	var race_visual: Dictionary = main.ui.card_race_visual_meta(card)
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", main.ui.make_race_band_style(card, 3))
	band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := "%s %s" % [String(race_visual.get("mark", "◆")), String(card.get("name", ""))]
	if not suffix.is_empty():
		title += " %s" % suffix
	var label: Label = main._make_label(title, int(values.get("title_font", 15)), race_visual.get("text", Color(0.98, 0.98, 0.96, 1.0)))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.ui.style_card_title(label, tight)
	band.add_child(label)
	return band

static func make_header(
	main: Node,
	card: Dictionary,
	mode: String,
	compact: bool = false,
	tight: bool = false,
	cost: int = -1,
	suffix: String = "",
	status_badge: Control = null
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UI_TOKENS.SPACE_XS)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if cost >= 0:
		var cost_badge: PanelContainer = main.ui.make_cost_badge("%d" % cost, mode == "hand" or compact or tight)
		cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cost_badge)
	if status_badge != null:
		status_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(status_badge)
	row.add_child(make_name_band(main, card, mode, compact, tight, suffix))
	return row

static func make_identity_label(
	main: Node,
	card: Dictionary,
	mode: String,
	compact: bool = false,
	tight: bool = false,
	include_lineage: bool = false,
	include_stats: bool = false
) -> Label:
	var values := metrics(mode, compact, tight)
	var race_visual: Dictionary = main.ui.card_race_visual_meta(card)
	var parts: Array[String] = []
	if include_lineage:
		parts.append(String(race_visual.get("lineage", main.ui.card_race_display_name(card))))
	else:
		parts.append(main.deck_service.type_name(String(card.get("type", ""))))
	parts.append(main.ui.card_race_display_name(card))
	var attribute := String(card.get("attr", ""))
	if not attribute.is_empty():
		parts.append(attribute)
	if include_stats and String(card.get("type", "")) == "unit":
		parts.append("%d/%d" % [int(card.get("attack", 0)), int(card.get("health", 0))])
	var label: Label = main._make_label(" · ".join(parts), int(values.get("identity_font", 11)), race_visual.get("text", Color(0.84, 0.88, 0.95, 1.0)))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if mode in ["hand", "collection"] else HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.03, 1.0))
	label.add_theme_constant_override("outline_size", 1)
	return label

static func make_art(main: Node, card: Dictionary, size: Vector2, dimmed: bool = false) -> TextureRect:
	var art: TextureRect = main._make_card_art_rect(card, size)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dimmed:
		art.modulate = Color(0.3, 0.3, 0.34, 1.0)
	return art

static func make_rules_block(
	main: Node,
	card: Dictionary,
	summary_text: String,
	detail_text: String,
	mode: String,
	compact: bool = false,
	tight: bool = false,
	minimum_height: float = 0.0
) -> PanelContainer:
	var values := metrics(mode, compact, tight)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", main.ui.make_race_rules_style(card, 6 if tight else UI_TOKENS.SPACE_SM))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(0, minimum_height)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	if not summary_text.is_empty():
		var summary: Label = main._make_label(summary_text, int(values.get("summary_font", 12)), Color(0.98, 0.95, 0.86, 1.0))
		summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main.ui.style_card_rules(summary, tight, false)
		box.add_child(summary)
	if not detail_text.is_empty() and detail_text != summary_text:
		var detail: Label = main._make_label(detail_text, int(values.get("detail_font", 11)), Color(0.82, 0.88, 0.95, 0.78))
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.clip_text = true
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main.ui.style_card_rules(detail, true, true)
		box.add_child(detail)
	return panel

static func make_face(main: Node, card: Dictionary, mode: String, options: Dictionary = {}) -> VBoxContainer:
	var compact := bool(options.get("compact", false))
	var tight := bool(options.get("tight", false))
	var values := metrics(mode, compact, tight)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(values.get("separation", UI_TOKENS.SPACE_XS)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var suffix := String(options.get("suffix", ""))
	var cost := int(options.get("cost", int(card.get("cost", 0)))) if bool(options.get("show_cost", true)) else -1
	box.add_child(make_header(main, card, mode, compact, tight, cost, suffix))
	var art_size: Vector2 = options.get("art_size", Vector2(150, 96))
	box.add_child(make_art(main, card, art_size, bool(options.get("dim_art", false))))
	if bool(options.get("show_identity", true)):
		box.add_child(make_identity_label(main, card, mode, compact, tight, bool(options.get("include_lineage", false)), bool(options.get("include_stats", true))))
	if bool(options.get("show_rules", true)):
		var summary := String(options.get("summary_text", main._card_effect_summary(card)))
		var detail := String(options.get("detail_text", card.get("text", ""))) if bool(options.get("show_detail", true)) else ""
		box.add_child(make_rules_block(main, card, summary, detail, mode, compact, tight, float(options.get("rules_min_height", 0.0))))
	return box
