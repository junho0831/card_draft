extends RefCounted
class_name RaceSelectionScreen
const ButtonMetrics = preload("res://src/ui/styles/button_metrics.gd")

var main: Node
var selected_race_id := "human"
var hovered_race_id := ""
var race_panels := {}
var race_buttons := {}
var race_hit_targets := {}
var start_button: Button
var selection_summary: Label
var fixed_footer: PanelContainer
var dock_title_label: Label
var strategy_box: VBoxContainer
var strategy_cards: BoxContainer
var strategy_error: Label
var learning_toggle: CheckButton
var expanded_strategy_id := ""
var selected_race_details: Label

func _init(_main: Node) -> void:
	main = _main
	selected_race_id = main.pending_race_selection_id

func build(body: VBoxContainer) -> void:
	var viewport_size: Vector2 = main._layout_viewport_size()
	var short: bool = viewport_size.y <= 760.0 and viewport_size.x > viewport_size.y
	var stacked: bool = viewport_size.x < 1100.0 and not short
	var compact: bool = stacked or short
	var phone: bool = main.ui.mobile_layout
	var mobile_portrait: bool = main._is_phone_portrait_layout()

	var guidance: PanelContainer = main.ui.make_guidance_banner(
		"새 런 준비",
		"세력을 고른 뒤 시작 전략을 선택하세요. 학습 모드에서는 기본 덱으로 차근차근 배웁니다.",
		Color(0.12, 0.2, 0.3, 1.0),
		compact
	)
	if not short:
		body.add_child(guidance)
	else:
		guidance.free()
	var modes: BoxContainer = HBoxContainer.new() if short else VBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	body.add_child(modes)

	var learning := CheckButton.new()
	if phone:
		learning.custom_minimum_size.y = 56
		learning.add_theme_font_size_override("font_size", 16)
	learning_toggle = learning
	learning.text = "단계별로 배우기" if int(main.player_profile.get("learning_stage", 0)) == 0 else "단계별 안내 이어서 배우기"
	if int(main.player_profile.get("learning_stage", 0)) >= 5:
		learning.text = "기본 조작 학습 완료"
		learning.disabled = true
	learning.button_pressed = main.pending_guided_run
	learning.toggled.connect(_set_guided_mode)
	learning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_child(learning)
	var skip := Button.new()
	skip.text = "바로 시작 · 전략 고르기"
	if phone:
		skip.custom_minimum_size.y = 56
		skip.add_theme_font_size_override("font_size", 16)
	skip.pressed.connect(func():
		learning.set_pressed_no_signal(false)
		_set_guided_mode(false)
	)
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_child(skip)
	if short and phone:
		learning.text = "학습" if not learning.disabled else "학습 완료"
		skip.text = "일반 · 전략 선택"
		ButtonMetrics.apply(learning, "compact", 120)
		ButtonMetrics.apply(skip, "compact", 160)
		modes.reparent(body.get_parent().get_node("RaceSelectionHeader"))
	var comparison: BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
	comparison.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comparison.add_theme_constant_override("separation", 10 if phone else 14)
	body.add_child(comparison)

	for race_id in main._valid_race_ids():
		comparison.add_child(_make_race_card(race_id, compact, phone, short))
	if short and not phone:
		body.move_child(comparison, 0)
	if short and phone:
		selected_race_details = main._make_label("", 14, Color(0.88, 0.92, 0.96))
		selected_race_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		selected_race_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.add_child(selected_race_details)

	strategy_box = VBoxContainer.new()
	strategy_box.add_theme_constant_override("separation", 8)
	body.add_child(strategy_box)
	strategy_box.add_child(main._make_label("시작 전략 선택", 20, Color(1.0, 0.88, 0.55)))
	strategy_cards = VBoxContainer.new() if mobile_portrait else HBoxContainer.new()
	strategy_cards.add_theme_constant_override("separation", 10)
	strategy_box.add_child(strategy_cards)
	strategy_error = main._make_label("", 14, Color(1.0, 0.5, 0.4))
	strategy_box.add_child(strategy_error)
	_render_strategies()
	var actions: BoxContainer
	var dock: Dictionary = main.ui.mount_screen_action_dock(
		main,
		body,
		"2. 선택한 세력으로 시작",
		"",
		Color(0.42, 0.68, 1.0, 1.0),
		78 if short else 126
	)
	fixed_footer = dock.get("panel") as PanelContainer
	dock_title_label = dock.get("title_label") as Label
	selection_summary = dock.get("detail_label") as Label
	actions = dock.get("actions") as BoxContainer
	if short:
		dock_title_label.hide()
		selection_summary.hide()

	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back_button := Button.new()
	back_button.text = "메인 메뉴"
	back_button.custom_minimum_size = Vector2(104 if mobile_portrait else 150, 64 if mobile_portrait else (58 if short else 66))
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if mobile_portrait else Control.SIZE_FILL
	main.ui.style_button(back_button, Color(0.12, 0.15, 0.2, 1.0))
	ButtonMetrics.apply(back_button)
	back_button.pressed.connect(Callable(main, "_show_main_menu"))
	actions.add_child(back_button)

	start_button = Button.new()
	start_button.custom_minimum_size = Vector2(0 if mobile_portrait else 320, 64 if mobile_portrait else (58 if short else 66))
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if mobile_portrait else Control.SIZE_FILL
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

	var cards_label: Label = main._make_label("대표 카드 · %s\n시작 덱과 유물은 아래 전략에서 선택" % " · ".join(meta.get("representative_card_names", [])), 11 if compact else 12, Color(0.78, 0.84, 0.92, 1.0))
	cards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(cards_label)
	if short and phone:
		# Keep all three choices and their touch targets visible above the fold.
		description.hide()
		power_panel.hide()
		cards_label.hide()
		frame.tooltip_text = "%s\n%s · %s" % [description.text, power_name.text, power_text.text]

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
	var changed: bool = selected_race_id != main._normalize_race_id(race_id)
	selected_race_id = main._normalize_race_id(race_id)
	if changed:
		main.pending_strategy_id = ""
		expanded_strategy_id = ""
	main.pending_race_selection_id = selected_race_id
	_render_strategies()
	if main.audio_manager != null:
		main.audio_manager.play_sound("click")
	_refresh_selection()
	if not main.pending_guided_run and is_instance_valid(strategy_box):
		Callable(self, "_scroll_to_strategies").call_deferred()

func _refresh_selection() -> void:
	for race_id in main._valid_race_ids():
		var meta: Dictionary = main._race_meta().get(race_id, {})
		var accent: Color = meta.get("color", Color(0.42, 0.68, 1.0, 1.0))
		var selected: bool = race_id == selected_race_id
		_apply_race_panel_style(race_id)
		var button: Button = race_buttons.get(race_id)
		if button != null:
			button.text = "✓ 선택됨 · %s" % String(meta.get("name", race_id)) if selected else "%s 선택" % String(meta.get("name", race_id))
			if selected:
				main.ui.style_primary_button(button, accent.darkened(0.42))
			else:
				main.ui.style_button(button, Color(0.12, 0.15, 0.2, 1.0))
			ButtonMetrics.apply(button)

	var selected_meta: Dictionary = main._race_meta().get(selected_race_id, {})
	if selected_race_details != null:
		selected_race_details.text = "%s\n필살기 · %s\n%s" % [selected_meta.get("description", ""), selected_meta.get("power_name", ""), selected_meta.get("power_text", "")]
	var selected_accent: Color = selected_meta.get("color", Color(0.42, 0.68, 1.0, 1.0))
	if selection_summary != null:
		selection_summary.text = "세력 선택 완료 · %s · %s · %s 1회" % [
			String(selected_meta.get("name", "인간")),
			String(selected_meta.get("builds", "소환 · 버프")),
			String(selected_meta.get("power_name", "필살기")),
		]
	if dock_title_label != null:
		dock_title_label.text = ("학습 시작 · " if main.pending_guided_run else "전략 선택 후 시작 · ") + String(selected_meta.get("start_text", "인간으로 시작"))
		dock_title_label.add_theme_color_override("font_color", selected_accent.lightened(0.28))
	if fixed_footer != null:
		var dock_style: StyleBoxFlat = main.ui.make_style_box(Color(0.025, 0.034, 0.048, 0.99), selected_accent.darkened(0.12), 2, 8)
		dock_style.content_margin_left = 8
		dock_style.content_margin_top = 8
		dock_style.content_margin_right = 8
		dock_style.content_margin_bottom = 8
		fixed_footer.add_theme_stylebox_override("panel", dock_style)
	if start_button != null:
		start_button.text = "%s" % String(selected_meta.get("start_text", "인간으로 시작"))
		main.ui.style_primary_button(start_button, selected_accent.darkened(0.38))
		start_button.add_theme_font_size_override("font_size", 18)
		if not main.pending_guided_run:
			var chosen: Dictionary = main.StartingStrategies.get_strategy(main.pending_strategy_id)
			start_button.disabled = chosen.is_empty()
			start_button.text = "%s · %s 시작" % [String(selected_meta.get("name", "")), String(chosen.get("name", "전략 선택"))]
		else:
			start_button.disabled = false

func _confirm_selection() -> void:
	if main.audio_manager != null:
		main.audio_manager.play_sound("click")
	main._init_run(selected_race_id, "" if main.pending_guided_run else main.pending_strategy_id)

func _set_guided_mode(enabled: bool) -> void:
	main.pending_guided_run = enabled
	_render_strategies()
	_refresh_selection()
	if not enabled:
		Callable(self, "_scroll_to_strategies").call_deferred()

func _choose_strategy(id: String) -> void:
	var strategy: Dictionary = main.StartingStrategies.get_strategy(id)
	if not main.StartingStrategies.is_valid(strategy, selected_race_id, main.card_db, main.relic_service):
		return
	main.pending_strategy_id = id
	_render_strategies()
	_refresh_selection()

func _toggle_strategy_deck(id: String) -> void:
	expanded_strategy_id = "" if expanded_strategy_id == id else id
	_render_strategies()

func _render_strategies() -> void:
	if not is_instance_valid(strategy_box):
		return
	strategy_box.visible = not main.pending_guided_run
	for child in strategy_cards.get_children():
		strategy_cards.remove_child(child)
		child.queue_free()
	var choices: Array[Dictionary] = main.StartingStrategies.for_race(selected_race_id)
	if not choices.any(func(entry): return String(entry.id) == main.pending_strategy_id):
		main.pending_strategy_id = String(choices[0].id) if not choices.is_empty() else ""
	strategy_error.text = "전략 데이터를 불러오지 못했습니다." if choices.is_empty() else ""
	for strategy in choices:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var selected: bool = String(strategy.id) == main.pending_strategy_id
		panel.add_theme_stylebox_override("panel", main.ui.make_style_box(Color(0.06, 0.1, 0.16), Color(0.5, 0.75, 1.0) if selected else Color(0.2, 0.3, 0.4), 2, 8))
		strategy_cards.add_child(panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		panel.add_child(box)
		var relic: Dictionary = main.relic_service.get_relic(String(strategy.relic_id))
		var tag: Dictionary = main._build_tag_meta().get(String(strategy.primary_tag), {})
		for line in [strategy.name, strategy.description, "장점 · " + String(strategy.strength), "약점 · " + String(strategy.weakness), "첫 행동 · " + String(strategy.opening), "주력 · " + String(tag.get("name", strategy.primary_tag)), "시작 유물 · " + String(relic.get("name", "")) + " — " + String(relic.get("text", ""))]:
			var label: Label = main._make_label(String(line), 14, Color(0.92, 0.95, 1.0))
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			box.add_child(label)
		var choose := Button.new()
		choose.text = ("✓ 선택됨 · " if selected else "이 전략 선택 · ") + String(strategy.name)
		ButtonMetrics.apply(choose)
		choose.pressed.connect(_choose_strategy.bind(String(strategy.id)))
		box.add_child(choose)
		var expand := Button.new()
		expand.text = "덱 10장 접기" if expanded_strategy_id == String(strategy.id) else "덱 10장 펼쳐보기"
		ButtonMetrics.apply(expand)
		expand.pressed.connect(_toggle_strategy_deck.bind(String(strategy.id)))
		box.add_child(expand)
		if expanded_strategy_id == String(strategy.id):
			var counts := {}
			for id in strategy.deck_ids:
				counts[id] = int(counts.get(id, 0)) + 1
			for id in counts:
				var card: Dictionary = main.card_db.get_card(String(id))
				var label: Label = main._make_label("%s ×%d · 마나 %d\n%s" % [card.name, counts[id], card.cost, card.text], 13, Color(0.9, 0.95, 1.0))
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				box.add_child(label)

func _scroll_to_strategies() -> void:
	if not is_instance_valid(main) or not main.is_inside_tree():
		return
	var tree: SceneTree = main.get_tree()
	await tree.process_frame
	await tree.process_frame
	if is_instance_valid(main) and is_instance_valid(strategy_box) and main.root_scroll.is_ancestor_of(strategy_box):
		main.root_scroll.scroll_vertical += int(strategy_box.global_position.y - main.root_scroll.global_position.y)
