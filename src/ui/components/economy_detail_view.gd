extends RefCounted

const CardView = preload("res://src/ui/components/card_view.gd")
const Fantasy = preload("res://src/ui/fantasy_components.gd")
const Tokens = preload("res://src/ui/styles/ui_tokens.gd")
const ButtonMetrics = preload("res://src/ui/styles/button_metrics.gd")
const DetailDialog = preload("res://src/ui/components/detail_dialog.gd")
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
	var button: Button = main.ui.make_action_button(title, callback, "primary" if primary else "secondary", Tokens.ACCENT_GOLD if primary else Tokens.BORDER, Tokens.SURFACE_RAISED, 16)
	set_action_label(button, title)
	size_action_labels(button, [title], 180 if primary else 120)
	button.set_meta("economy_action", true)
	button.set_meta("economy_primary", primary)
	return button

static func set_action_label(button: Button, title: String) -> void:
	ButtonMetrics.set_label(button, title)

static func size_action_labels(button: Button, titles: Array[String], minimum_width: float) -> void:
	ButtonMetrics.reserve_labels(button, titles, minimum_width)

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
	return CardView.make_offer_label(main, title, name, width, height, font_size, color, wrap)

static func add_offer_selection(main: Node, face: Control) -> void:
	CardView.add_offer_selection(main, face)

static func select_offer(face: Control, selected: bool) -> void:
	face.get_node("EconomyOfferSelection").visible = selected

static func compact_offer_face(main: Node, card: Dictionary, width: int, height: int, price_text: String = "") -> Control:
	return CardView.make_compact_offer(main, card, width, height, price_text)

static func pin_mobile_footer(main: Node, body: VBoxContainer, footer: HBoxContainer) -> PanelContainer:
	var dock: Dictionary = main.ui.mount_actions_only_dock(main, body, Tokens.BORDER, 44)
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
	return preload("res://src/ui/ui_factory.gd").new().make_scroll_column(parent, 8, min_height, ScrollContainer.SCROLL_MODE_DISABLED, "EconomyDetailScroll")

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
	var close_button := action_button(main, "닫기", Callable())
	close_button.name = "EconomyDetailClose"
	size_action_labels(close_button, ["닫기"], 96)
	var overlay = DetailDialog.create(main.modal_layer, DetailDialog.Profile.ECONOMY, comparison_label(main, title, TEXT, 20), close_button, close, main._layout_viewport_size(), main.ui)
	overlay.content.add_child(detail)
	var primary := action_button(main, action_text, action, true)
	primary.name = "EconomyDetailAction"
	primary.disabled = disabled
	size_action_labels(primary, [action_text], 200)
	overlay.actions.add_child(primary)
	overlay.show()
	return overlay
