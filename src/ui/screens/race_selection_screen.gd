extends RefCounted
class_name RaceSelectionScreen

var main: Node
var selected_race_id := "human"
var hovered_race_id := ""
var race_panels := {}
var race_buttons := {}
var race_hit_targets := {}
var start_button: Button
var selection_summary: Label
var fixed_footer: PanelContainer

func _init(_main: Node) -> void:
	main = _main
	selected_race_id = main.pending_race_selection_id

func build(body: VBoxContainer) -> void:
	var viewport_size: Vector2 = main._layout_viewport_size()
	var stacked: bool = viewport_size.x < 1100.0
	var short: bool = viewport_size.y <= 760.0 and viewport_size.x > viewport_size.y
	var compact: bool = stacked or short
	var phone: bool = main._is_mobile_phone_layout()
	var mobile_portrait: bool = main._is_phone_portrait_layout()

	body.add_child(main.ui.make_guidance_banner(
		"새 런 준비",
		"세력 하나를 고르면 시작 덱, 유물, 전투 필살기가 함께 정해집니다.",
		Color(0.12, 0.2, 0.3, 1.0),
		compact
	))

	var comparison: BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
	comparison.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comparison.add_theme_constant_override("separation", 10 if phone else 14)
	body.add_child(comparison)

	for race_id in main._valid_race_ids():
		comparison.add_child(_make_race_card(race_id, compact, phone, short))

	var footer: PanelContainer = main.ui.make_surface_panel(
		Color(0.045, 0.055, 0.07, 0.98),
		Color(0.2, 0.32, 0.46, 1.0),
		1,
		8,
		10
	)
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if mobile_portrait:
		fixed_footer = footer
		footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		footer.offset_left = 8
		footer.offset_top = -148
		footer.offset_right = -8
		footer.offset_bottom = -8
		footer.mouse_filter = Control.MOUSE_FILTER_STOP
		main.modal_layer.add_child(footer)
		var footer_spacer := Control.new()
		footer_spacer.custom_minimum_size = Vector2(0, 158)
		body.add_child(footer_spacer)
	else:
		body.add_child(footer)
	var footer_box := VBoxContainer.new()
	footer_box.add_theme_constant_override("separation", 8)
	footer.add_child(footer_box)

	selection_summary = main._make_label("", 13 if compact else 15, Color(0.88, 0.92, 0.98, 1.0))
	selection_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer_box.add_child(selection_summary)

	var actions: BoxContainer = HBoxContainer.new() if mobile_portrait else main.ui.make_action_bar(false, 8)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL if mobile_portrait else Control.SIZE_SHRINK_CENTER
	footer_box.add_child(actions)
	var back_button := Button.new()
	back_button.text = "메인 메뉴"
	back_button.custom_minimum_size = Vector2(104 if mobile_portrait else 150, 64 if mobile_portrait else (58 if short else 66))
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if mobile_portrait else Control.SIZE_FILL
	main.ui.style_button(back_button, Color(0.12, 0.15, 0.2, 1.0))
	back_button.add_theme_font_size_override("font_size", 16 if mobile_portrait else 17)
	back_button.pressed.connect(Callable(main, "_show_main_menu"))
	actions.add_child(back_button)

	start_button = Button.new()
	start_button.custom_minimum_size = Vector2(0 if mobile_portrait else 320, 64 if mobile_portrait else (58 if short else 66))
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.pressed.connect(Callable(self, "_confirm_selection"))
	actions.add_child(start_button)

	_refresh_selection()

func _make_race_card(race_id: String, compact: bool, phone: bool, short: bool) -> PanelContainer:
	var meta: Dictionary = main._race_meta().get(race_id, {})
	var accent: Color = meta.get("color", Color(0.42, 0.68, 1.0, 1.0))
	var frame: PanelContainer = main.ui.make_surface_panel(
		Color(0.05, 0.06, 0.075, 1.0),
		accent.darkened(0.28),
		1,
		8,
		8 if short else (10 if phone else 12)
	)
	frame.custom_minimum_size = Vector2(0 if compact else 300, 0)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.set_meta("short_layout", short)
	race_panels[race_id] = frame

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5 if short else (7 if phone else 9))
	frame.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	var title: Label = main._make_label(String(meta.get("name", race_id)), 20 if compact else 24, accent.lightened(0.22))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var style_chip: PanelContainer = main.ui.make_chip(
		String(meta.get("style", "전투")),
		accent.darkened(0.58),
		Color(0.96, 0.98, 1.0, 1.0),
		11 if compact else 12
	)
	header.add_child(style_chip)

	var representative_card: Dictionary = main.card_db.get_card(String(meta.get("representative_card_id", "")))
	box.add_child(main._make_card_art_rect(
		representative_card,
		Vector2(0, 106 if short else (126 if phone else (142 if compact else 172)))
	))

	var description: Label = main._make_label(String(meta.get("description", "")), 12 if compact else 14, Color(0.88, 0.92, 0.96, 1.0))
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)

	var power_panel: PanelContainer = main.ui.make_surface_panel(accent.darkened(0.7), accent.darkened(0.14), 1, 7, 6 if short else 8)
	box.add_child(power_panel)
	var power_box := VBoxContainer.new()
	power_box.add_theme_constant_override("separation", 3)
	power_panel.add_child(power_box)
	var power_name: Label = main._make_label("필살기 · %s" % String(meta.get("power_name", "")), 13 if compact else 15, accent.lightened(0.28))
	power_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	power_box.add_child(power_name)
	var power_text: Label = main._make_label(String(meta.get("power_text", "")), 11 if compact else 12, Color(0.86, 0.9, 0.96, 1.0))
	power_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	power_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	power_box.add_child(power_text)

	var relic: Dictionary = main.relic_service.get_relic(String(meta.get("relic_id", "")))
	var relic_row := HBoxContainer.new()
	relic_row.add_theme_constant_override("separation", 7)
	box.add_child(relic_row)
	var relic_label: Label = main._make_label("시작 유물", 11 if compact else 12, Color(0.68, 0.74, 0.82, 1.0))
	relic_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	relic_row.add_child(relic_label)
	relic_row.add_child(main.ui.make_relic_badge(relic, compact))

	var cards_label: Label = main._make_label("대표 카드 · %s" % " · ".join(meta.get("representative_card_names", [])), 11 if compact else 12, Color(0.78, 0.84, 0.92, 1.0))
	cards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(cards_label)

	var select_button := Button.new()
	select_button.text = "%s 선택" % String(meta.get("name", race_id))
	select_button.custom_minimum_size = Vector2(0, 56 if short else (64 if compact else 68))
	select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_button.set_meta("selection_font_size", 17 if compact else 19)
	select_button.pressed.connect(Callable(self, "_select_race").bind(race_id))
	box.add_child(select_button)
	race_buttons[race_id] = select_button

	var card_hit_target := Button.new()
	card_hit_target.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_hit_target.focus_mode = Control.FOCUS_NONE
	card_hit_target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card_hit_target.tooltip_text = "%s 선택" % String(meta.get("name", race_id))
	card_hit_target.z_index = 20
	var empty_style := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		card_hit_target.add_theme_stylebox_override(state, empty_style)
	card_hit_target.pressed.connect(Callable(self, "_select_race").bind(race_id))
	card_hit_target.mouse_entered.connect(Callable(self, "_set_race_hovered").bind(race_id, true))
	card_hit_target.mouse_exited.connect(Callable(self, "_set_race_hovered").bind(race_id, false))
	frame.add_child(card_hit_target)
	race_hit_targets[race_id] = card_hit_target
	return frame

func _set_race_hovered(race_id: String, hovered: bool) -> void:
	var previous_race_id := hovered_race_id
	if hovered:
		hovered_race_id = race_id
	elif hovered_race_id == race_id:
		hovered_race_id = ""
	if not previous_race_id.is_empty() and previous_race_id != hovered_race_id:
		_apply_race_panel_style(previous_race_id)
	_apply_race_panel_style(race_id)

func _apply_race_panel_style(race_id: String) -> void:
	var meta: Dictionary = main._race_meta().get(race_id, {})
	var accent: Color = meta.get("color", Color(0.42, 0.68, 1.0, 1.0))
	var selected: bool = race_id == selected_race_id
	var hovered: bool = race_id == hovered_race_id
	var panel: PanelContainer = race_panels.get(race_id)
	if panel == null:
		return
	var panel_margin := 8 if bool(panel.get_meta("short_layout", false)) else 12
	var style: StyleBoxFlat = main.ui.make_style_box(
		Color(0.055, 0.07, 0.09, 1.0).lerp(accent, 0.1 if selected else (0.065 if hovered else 0.02)),
		accent if selected else (accent.darkened(0.2) if hovered else accent.darkened(0.48)),
		3 if selected else (2 if hovered else 1),
		8
	)
	style.content_margin_left = panel_margin
	style.content_margin_top = panel_margin
	style.content_margin_right = panel_margin
	style.content_margin_bottom = panel_margin
	panel.add_theme_stylebox_override("panel", style)

func _select_race(race_id: String) -> void:
	selected_race_id = main._normalize_race_id(race_id)
	main.pending_race_selection_id = selected_race_id
	if main.audio_manager != null:
		main.audio_manager.play_sound("click")
	_refresh_selection()

func _refresh_selection() -> void:
	for race_id in main._valid_race_ids():
		var meta: Dictionary = main._race_meta().get(race_id, {})
		var accent: Color = meta.get("color", Color(0.42, 0.68, 1.0, 1.0))
		var selected: bool = race_id == selected_race_id
		_apply_race_panel_style(race_id)
		var button: Button = race_buttons.get(race_id)
		if button != null:
			button.text = "선택됨" if selected else "%s 선택" % String(meta.get("name", race_id))
			if selected:
				main.ui.style_primary_button(button, accent.darkened(0.42))
			else:
				main.ui.style_button(button, Color(0.12, 0.15, 0.2, 1.0))
			button.add_theme_font_size_override("font_size", int(button.get_meta("selection_font_size", 17)))

	var selected_meta: Dictionary = main._race_meta().get(selected_race_id, {})
	var selected_accent: Color = selected_meta.get("color", Color(0.42, 0.68, 1.0, 1.0))
	if selection_summary != null:
		selection_summary.text = "%s · %s · 전투마다 %s 1회" % [
			String(selected_meta.get("name", "인간")),
			String(selected_meta.get("builds", "소환 · 버프")),
			String(selected_meta.get("power_name", "필살기")),
		]
	if start_button != null:
		start_button.text = String(selected_meta.get("start_text", "인간으로 시작"))
		main.ui.style_primary_button(start_button, selected_accent.darkened(0.38))
		start_button.add_theme_font_size_override("font_size", 18)

func _confirm_selection() -> void:
	if main.audio_manager != null:
		main.audio_manager.play_sound("click")
	main._init_run(selected_race_id)
