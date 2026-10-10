extends RefCounted

const Fantasy = preload("res://src/ui/fantasy_components.gd")
const Tokens = preload("res://src/ui/styles/ui_tokens.gd")
const ButtonMetrics = preload("res://src/ui/styles/button_metrics.gd")
const TEXT = Tokens.TEXT_PRIMARY
const MUTED = Tokens.TEXT_SECONDARY
const CHANGED = Tokens.ACCENT_TEAL

static func section(main: Node, title: String, width: int = 0) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = width
	box.add_theme_constant_override("separation", 8)
	box.add_child(comparison_label(main, title, TEXT, 18))
	return box

static func action_button(main: Node, title: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	main.ui.style_role_button(button, "primary" if primary else "secondary", Tokens.ACCENT_GOLD if primary else Tokens.BORDER, Tokens.SURFACE_RAISED, 16)
	set_action_label(button, title)
	size_action_labels(button, [title], 180 if primary else 120)
	button.set_meta("economy_action", true)
	button.set_meta("economy_primary", primary)
	button.pressed.connect(callback)
	return button

static func set_action_label(button: Button, title: String) -> void:
	button.text = title
	button.tooltip_text = title
	button.set_meta("button_label_tooltip", title)

static func size_action_labels(button: Button, titles: Array[String], minimum_width: float) -> void:
	ButtonMetrics.apply(button, "compact", minimum_width)
	button.clip_text = false
	button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	for title in titles:
		var text_width := button.get_theme_font("font").get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
		button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, ceilf(text_width + button.get_theme_stylebox("normal").get_minimum_size().x))

static func offer_face(main: Node, card: Dictionary, width: int, height: int, compact: bool = false, price_text: String = "") -> Control:
	var face: Control
	if compact:
		face = compact_offer_face(main, card, width, height, price_text)
	else:
		face = Fantasy.card(main, card, width, height)
		face.add_theme_stylebox_override("panel", main.ui.make_race_card_style(card, Tokens.SURFACE, 2, 8))
		main.ui.decorate_card_frame(face, card)
	add_offer_selection(main, face)
	return face

static func offer_label(main: Node, title: String, name: String, width: float, height: float, font_size: int, color: Color = TEXT, wrap: bool = false) -> Label:
	var label := comparison_label(main, title, color, font_size)
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

static func add_offer_selection(main: Node, face: Control) -> void:
	var layer := Control.new()
	layer.name = "EconomyOfferSelection"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var badge: PanelContainer = main.ui.make_surface_panel(Tokens.SURFACE_RAISED, Tokens.ACCENT_GOLD, 1, 4, 4)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -70
	badge.offset_right = -4
	badge.offset_top = 4
	badge.offset_bottom = 28
	badge.add_child(offer_label(main, "✓ 선택", "EconomyOfferCheck", 58, 18, 12, Tokens.ACCENT_GOLD))
	layer.hide()

static func select_offer(face: Control, selected: bool) -> void:
	face.get_node("EconomyOfferSelection").visible = selected

static func compact_offer_face(main: Node, card: Dictionary, width: int, height: int, price_text: String = "") -> Control:
	var face := Panel.new()
	face.custom_minimum_size = Vector2(width, height)
	face.add_theme_stylebox_override("panel", main.ui.make_race_card_style(card, Tokens.SURFACE, 2, 8))
	main.ui.decorate_card_frame(face, card)
	var title_height := 32
	var line_height := 24
	var effect_height := 32
	var gap := 2
	# Single-line labels require 24px with the inherited Korean font.
	var info_height := title_height + line_height + effect_height + gap * 2
	if not price_text.is_empty():
		info_height += line_height + gap
	var info_top := height - info_height - 4
	var art: TextureRect = main._make_card_art_rect(card, Vector2.ZERO)
	art.name = "EconomyOfferArt"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.position = Vector2(8, 8)
	art.size = Vector2(width - 16, maxf(0, info_top - 8))
	face.add_child(art)
	var title := offer_label(main, String(card.get("name", "")), "EconomyOfferName", width - 16, title_height, 14, TEXT, true)
	title.position = Vector2(8, info_top)
	face.add_child(title)
	var stats_text := "마나 %d" % int(card.get("cost", 0))
	if String(card.get("type", "")) == "unit":
		stats_text += " · 공격 %d · 체력 %d" % [int(card.get("attack", 0)), int(card.get("health", 0))]
	var stats := offer_label(main, stats_text, "EconomyOfferStats", width - 16, line_height, 12)
	stats.position = Vector2(8, info_top + title_height + gap)
	face.add_child(stats)
	var summary: String = main._card_effect_summary(card)
	var effect := offer_label(main, summary, "EconomyOfferEffect", width - 16, effect_height, 12, MUTED, true)
	effect.position = Vector2(8, stats.position.y + line_height + gap)
	face.add_child(effect)
	if not price_text.is_empty():
		var price := offer_label(main, price_text, "EconomyOfferPrice", width - 16, line_height, 12, Tokens.ACCENT_GOLD)
		price.position = Vector2(8, effect.position.y + effect_height + gap)
		face.add_child(price)
	face.tooltip_text = summary if price_text.is_empty() else "%s\n%s" % [price_text, summary]
	return face

static func pin_mobile_footer(main: Node, body: VBoxContainer, footer: HBoxContainer) -> PanelContainer:
	var dock: Dictionary = main.ui.mount_screen_action_dock(main, body, "", "", Tokens.BORDER, 60)
	dock.title_label.hide()
	dock.detail_label.hide()
	dock.scroll.custom_minimum_size.y = 44
	footer.reparent(dock.actions)
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return dock.panel

static func comparison_label(main: Node, text: String, color: Color = TEXT, font_size: int = 16) -> Label:
	var label: Label = main._make_label(text, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

static func comparison_grid(main: Node, parent: Control, title: String, compact: bool = false) -> GridContainer:
	parent.add_child(comparison_label(main, title, TEXT, 14 if compact else 18))
	var grid := GridContainer.new()
	grid.set_meta("compact", compact)
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4 if compact else 16)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	for text in ["", "현재", "", "추가 후"]:
		grid.add_child(comparison_label(main, text, MUTED, 12 if compact else 14))
	return grid

static func add_comparison_row(main: Node, grid: GridContainer, key: String, title: String, before: String, after: String, before_state: String = "", after_state: String = "") -> void:
	var compact: bool = grid.get_meta("compact", false)
	var name_label := comparison_label(main, title, TEXT, 14 if compact else 16)
	name_label.custom_minimum_size.x = 64 if compact else 88
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	grid.add_child(name_label)
	for side in ["Before", "After"]:
		if side == "After":
			var arrow := comparison_label(main, "→", MUTED, 12 if compact else 16)
			arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			grid.add_child(arrow)
		var values := VBoxContainer.new()
		values.name = key + side
		values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		values.add_theme_constant_override("separation", 2)
		grid.add_child(values)
		var changed: bool = side == "After" and (before != after or before_state != after_state)
		var value := comparison_label(main, before if side == "Before" else after, CHANGED if changed else TEXT, 14 if compact else 16)
		value.name = "Value"
		values.add_child(value)
		var state := before_state if side == "Before" else after_state
		if not state.is_empty():
			var status := comparison_label(main, state, CHANGED if changed else MUTED, 12 if compact else 14)
			status.name = "State"
			values.add_child(status)

static func make_comparison(main: Node, card: Dictionary, compact: bool = false) -> VBoxContainer:
	var comparison: Dictionary = main._card_economy_comparison(card)
	var section := VBoxContainer.new()
	section.name = "EconomyComparison"
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 12)
	var builds := comparison_grid(main, section, "빌드 점수 · 활성 상태", compact)
	builds.name = "BuildRows"
	for tag in main._valid_build_tags():
		add_comparison_row(main, builds, String(tag), String(main._build_tag_meta()[tag].get("name", tag)),
			str(comparison.before_scores[tag]), str(comparison.after_scores[tag]),
			"활성" if comparison.before_active.has(tag) else "미활성",
			"활성" if comparison.after_active.has(tag) else "미활성")
	section.add_child(HSeparator.new())
	var costs := comparison_grid(main, section, "덱 비용 분포", compact)
	costs.name = "CostRows"
	for bucket in ["0-1", "2-3", "4+"]:
		add_comparison_row(main, costs, bucket, "비용 " + bucket,
			"%d장" % comparison.before_costs[bucket], "%d장" % comparison.after_costs[bucket])
	return section

static func add_scroll(parent: Control, min_height: float = 0.0) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "EconomyDetailScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size.y = min_height
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	return content

static func show_card(main: Node, card: Dictionary, action_text: String, action: Callable, disabled: bool, close: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var narrow: bool = main._layout_viewport_size().x < 600
	var face := offer_face(main, card, 128 if narrow else 190, 220 if narrow else 300)
	face.name = "EconomyDetailCard"
	face.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(face)
	row.add_child(make_comparison(main, card, narrow))
	return show_detail(main, String(card.get("name", "")), row, "%s · %s" % [String(card.get("name", "카드")), action_text], action, disabled, close)

static func show_relic(main: Node, relic: Dictionary, action: Callable, close: Callable) -> Control:
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 16)
	details.add_child(comparison_label(main, String(relic.get("text", "")), TEXT, 18))
	details.add_child(comparison_label(main, main._choice_impact_text(relic), MUTED, 16))
	return show_detail(main, String(relic.get("name", "유물")), details, "유물 선택", action, false, close)

static func show_detail(main: Node, title: String, detail: Control, action_text: String, action: Callable, disabled: bool, close: Callable) -> Control:
	var overlay := Control.new()
	overlay.name = "EconomyDetailOverlay"
	main.modal_layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scene_backdrop := TextureRect.new()
	scene_backdrop.name = "DetailSceneBackdrop"
	scene_backdrop.texture = load(Tokens.DETAIL_BACKGROUND_PATH)
	scene_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scene_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(scene_backdrop)
	var scrim := ColorRect.new()
	scrim.color = Color(Tokens.SURFACE, 0.46)
	overlay.add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = main.ui.make_surface_panel(Tokens.SURFACE, Tokens.BORDER, 1, 8, 12)
	panel.name = "EconomyDetailPanel"
	overlay.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport: Vector2 = main._layout_viewport_size()
	var inset_x := maxf(12, (viewport.x - 1040) * 0.5)
	var inset_y := maxf(8, (viewport.y - 620) * 0.5)
	panel.offset_left = inset_x
	panel.offset_right = -inset_x
	panel.offset_top = inset_y
	panel.offset_bottom = -inset_y
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(comparison_label(main, title, TEXT, 20))
	var close_button := action_button(main, "닫기", close)
	close_button.name = "EconomyDetailClose"
	size_action_labels(close_button, ["닫기"], 96)
	header.add_child(close_button)
	var content := add_scroll(box)
	content.add_child(detail)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(footer)
	var primary := action_button(main, action_text, action, true)
	primary.name = "EconomyDetailAction"
	primary.disabled = disabled
	size_action_labels(primary, [action_text], 200)
	footer.add_child(primary)
	overlay.show()
	return overlay
