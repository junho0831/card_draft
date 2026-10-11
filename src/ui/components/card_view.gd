extends RefCounted
class_name CardView

const UI_TOKENS = preload("res://src/ui/styles/ui_tokens.gd")

static func card_kind(card: Dictionary) -> String:
	var type := String(card.get("type", "unit"))
	if type == "unit": return "unit"
	if type == "equipment": return "equipment"
	for effect in card.get("effects", []):
		if effect.op in ["front_damage", "all_damage", "combo_damage", "low_damage", "curse", "hero_damage"]: return "damage"
	var id := String(card.get("id", "")).trim_suffix("_plus")
	if id in ["small_flame", "gale_shot", "corpse_explosion", "fireball", "death_mark", "plague_spread", "soul_shackle", "funeral_fog", "vampiric_strike"]:
		return "damage"
	return "support"

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
	var title := String(card.get("name", ""))
	if not suffix.is_empty():
		title += " %s" % suffix
	var label: Label = main._make_label(title, int(values.get("title_font", 15)), race_visual.get("text", Color(0.98, 0.98, 0.96, 1.0)))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2(36, 32)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.ui.style_card_title(label, tight)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(row)
	row.add_child(main.ui.make_race_emblem(card, 20 if tight else 26))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
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

static func make_art_rect(main: Node, card: Dictionary, size: Vector2) -> TextureRect:
	return main._make_card_art_rect(card, size)

static func make_art(main: Node, card: Dictionary, size: Vector2, dimmed: bool = false) -> TextureRect:
	var art := make_art_rect(main, card, size)
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

static func make_title(main: Node, text: String, font_size: int = 24) -> Label:
	var title: Label = main._make_label(text, mini(font_size, UI_TOKENS.FONT_TITLE), UI_TOKENS.TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return title

static func make_illustrated_face(main: Node, data: Dictionary, width: int, height: int, selected: bool = false) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	frame.custom_minimum_size = Vector2(width, height)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var face := make_compact_offer(main, data, width, height)
	frame.add_child(face)
	if selected:
		add_outline(face, UI_TOKENS.ACCENT_GOLD, -2, 2, "SelectionOutline")
	return frame

static func make_gem(main: Node, value: int, red: bool) -> PanelContainer:
	var frame := PanelContainer.new()
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/ui/fantasy/gem_red.svg" if red else "res://assets/ui/fantasy/gem_blue.svg")
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	frame.add_theme_stylebox_override("panel", style)
	frame.custom_minimum_size = Vector2(40, 44)
	frame.add_child(main._make_label(str(value), 22, Color.WHITE))
	return frame

static func make_offer_label(main: Node, title: String, name: String, width: float, height: float, font_size: int, color: Color = UI_TOKENS.TEXT_PRIMARY, wrap: bool = false) -> Label:
	var label: Label = main._make_label(title, font_size, color)
	label.theme = main.theme
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.name = name
	label.size = Vector2(width, height)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.max_lines_visible = 2 if wrap else 1
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

static func _offer_label_height(label: Label) -> float:
	# Measure the wrapped text before Label's height-dependent ellipsis is applied.
	var paragraph := TextParagraph.new()
	paragraph.width = label.size.x
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.add_string(label.text, label.get_theme_font("font"), label.get_theme_font_size("font_size"))
	var lines := mini(2, paragraph.get_line_count())
	var height := 8.0 + maxf(0, lines - 1) * label.get_theme_constant("line_spacing")
	for line in range(lines): height += paragraph.get_line_size(line).y
	return ceilf(height)

static func add_offer_selection(main: Node, face: Control) -> void:
	var layer := Control.new()
	layer.name = "EconomyOfferSelection"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var badge: PanelContainer = main.ui.make_surface_panel(UI_TOKENS.SURFACE_RAISED, UI_TOKENS.ACCENT_GOLD, 1, 4, 4)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -70
	badge.offset_right = -4
	badge.offset_top = 4
	badge.offset_bottom = 28
	badge.add_child(make_offer_label(main, "✓ 선택", "EconomyOfferCheck", 58, 18, 12, UI_TOKENS.ACCENT_GOLD))
	add_outline(layer, UI_TOKENS.ACCENT_GOLD, -2, 2, "SelectionOutline")
	layer.hide()

static func make_compact_offer(main: Node, card: Dictionary, width: int, height: int, price_text: String = "") -> Control:
	var face := Control.new()
	face.custom_minimum_size = Vector2(width, height + (28 if not price_text.is_empty() else 0))
	face.size = face.custom_minimum_size
	face.set_meta("portrait_height", height)
	var plate := Panel.new()
	plate.name = "CardPlate"
	plate.size = Vector2(width, height)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = main.ui.make_race_card_style(card, Color.TRANSPARENT, 1, 0)
	style.set_border_width_all(1)
	plate.add_theme_stylebox_override("panel", style)
	face.add_child(plate)
	var art := make_art(main, card, Vector2.ZERO)
	art.name = "EconomyOfferArt"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.position = Vector2(6, 6)
	var name_font := 14 if width < 200 else 16
	var title := make_offer_label(main, String(card.get("name", "")), "EconomyOfferName", width - 16, 0, name_font, UI_TOKENS.TEXT_PRIMARY, true)
	var title_height := _offer_label_height(title)
	var effect := make_offer_label(main, main._card_effect_summary(card), "EconomyOfferEffect", width - 24, 0, 14, UI_TOKENS.TEXT_SECONDARY, true)
	var show_effect := height >= 200 and not effect.text.is_empty()
	var effect_height := _offer_label_height(effect) if show_effect else 0.0
	var art_height := floorf(height - title_height - effect_height - 42)
	art.size = Vector2(width - 12, art_height)
	face.add_child(art)
	var title_y := art_height + 6
	var band := Panel.new()
	band.name = "EconomyOfferNameBand"
	band.position = Vector2(6, title_y)
	band.size = Vector2(width - 12, title_height)
	var name_style: StyleBoxFlat = main.ui.make_race_band_style(card)
	name_style.set_border_width_all(0)
	name_style.border_width_top = 1
	name_style.set_corner_radius_all(0)
	band.add_theme_stylebox_override("panel", name_style)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(band)
	title.size.y = title_height
	title.position = Vector2(8, title_y)
	face.add_child(title)
	var effect_y := title_y + title_height
	var rules := Panel.new()
	rules.name = "EconomyOfferRules"
	rules.position = Vector2(6, effect_y)
	rules.size = Vector2(width - 12, height - effect_y - 6)
	rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rules_style := StyleBoxFlat.new()
	rules_style.bg_color = Color(UI_TOKENS.SURFACE, 0.92)
	rules.add_theme_stylebox_override("panel", rules_style)
	face.add_child(rules)
	effect.size.y = effect_height
	effect.position = Vector2(12, effect_y)
	effect.visible = show_effect
	face.add_child(effect)
	var stats_text := "마나 %d" % int(card.get("cost", 0))
	if String(card.get("type", "")) == "unit":
		stats_text += " · 공격 %d · 체력 %d" % [int(card.get("attack", 0)), int(card.get("health", 0))]
	var stats := make_offer_label(main, stats_text, "EconomyOfferStats", width - 16, 24, 14)
	stats.hide()
	face.add_child(stats)
	main.ui.decorate_card_frame(plate, card)
	make_stamp(main, face, "Cost", str(int(card.get("cost", 0))), Vector2(3, 3), Vector2(32, 30), UI_TOKENS.SURFACE, 20)
	if card.has("attack"):
		make_stamp(main, face, "Attack", str(int(card.attack)), Vector2(4, height - 30), Vector2(32, 28), UI_TOKENS.SURFACE, 20)
		make_stamp(main, face, "Health", str(int(card.get("health", 0))), Vector2(width - 36, height - 30), Vector2(32, 28), UI_TOKENS.SURFACE, 20)
	var emblem: TextureRect = main.ui.make_race_emblem(card, 22)
	emblem.position = Vector2((width - 22) * 0.5, height - 26)
	face.add_child(emblem)
	var kind := card_kind(card)
	var icon := TextureRect.new()
	icon.name = "TypeIcon"
	icon.texture = load("res://assets/ui/fantasy/type_%s.svg" % kind)
	icon.position = Vector2(width - 25, 5)
	icon.size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(icon)
	if not price_text.is_empty():
		var price := make_offer_label(main, price_text, "EconomyOfferPrice", width, 26, 14, UI_TOKENS.ACCENT_GOLD)
		price.position = Vector2(0, height + 2)
		face.add_child(price)
	face.tooltip_text = "%s\n%s" % [String(card.get("name", "")), main._card_effect_summary(card)]
	return face

static func make_inspection_face(main: Node, card: Dictionary) -> Control:
	var face := make_compact_offer(main, card, 284, 426)
	face.theme = main.theme
	face.set_meta("type_edge_color", main.ui.make_race_card_style(card).border_color)
	return face

static func make_stamp(main: Node, parent: Control, node_name: String, value: String, at: Vector2, extent: Vector2, color: Color, font_size: int = 16) -> Label:
	var existing := parent.get_node_or_null(node_name) as Label
	if existing != null:
		existing.text = value
		return existing
	var band := Panel.new()
	band.name = node_name + "Band"
	band.position = at
	band.size = extent
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	if node_name in ["Cost", "Attack", "Health"]:
		var gem := StyleBoxTexture.new()
		gem.texture = load("res://assets/ui/fantasy/gem_red.svg" if node_name == "Attack" else "res://assets/ui/fantasy/gem_blue.svg")
		band.add_theme_stylebox_override("panel", gem)
	else:
		band.add_theme_stylebox_override("panel", style)
	parent.add_child(band)
	var text: Label = main._make_label(value, font_size, Color.WHITE)
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_color_override("font_color", Color.WHITE)
	text.add_theme_constant_override("line_spacing", 0)
	text.name = node_name
	text.position = at
	text.size = extent
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.clip_text = true
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(text)
	return text

static func add_outline(parent: Control, color: Color, inset: float, width: int, node_name: String) -> void:
	var edge := Panel.new()
	edge.name = node_name
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edge.offset_left = inset
	edge.offset_top = inset
	edge.offset_right = -inset
	edge.offset_bottom = -inset
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	edge.add_theme_stylebox_override("panel", style)
	parent.add_child(edge)

static func make_race_emblem(card: Dictionary, edge: float = 24) -> TextureRect:
	var race := String(card.get("race", "중립"))
	var key: String = {"인간": "human", "엘프": "elf", "언데드": "undead", "정령": "spirit"}.get(race, "neutral")
	var emblem := TextureRect.new()
	emblem.name = "RaceEmblem"
	emblem.texture = load("res://assets/ui/fantasy/race_%s.svg" % key)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.custom_minimum_size = Vector2(edge, edge)
	emblem.size = Vector2(edge, edge)
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.tooltip_text = race
	return emblem

static func decorate_frame(frame: Control, card: Dictionary, accent: Color) -> void:
	var ornament := preload("res://src/ui/components/card_frame_ornaments.gd").new()
	ornament.name = "RaceOrnaments"
	ornament.race = String(card.get("race", "중립"))
	ornament.card_type = String(card.get("type", "unit"))
	ornament.accent = accent
	ornament.z_index = 0
	frame.add_child(ornament)
