extends RefCounted
class_name RestScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer) -> void:
	var compact: bool = main._is_compact_layout_for(1180.0, 760.0)
	body.add_child(main._make_run_summary_panel())
	body.add_child(main.ui.make_guidance_banner("다음 행동", "회복하거나 카드를 강화해 다음 전투를 준비하세요", Color(0.18, 0.2, 0.12, 1.0), compact))

	var max_hp: int = int(main.current_run.get("max_hp", 50))
	var hp: int = int(main.current_run.get("hp", max_hp))
	var heal_amount: int = main.run_flow.rest_heal_amount(max_hp)
	body.add_child(_make_rest_status_strip(compact, hp, max_hp, heal_amount))

	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.07, 0.08, 0.1, 1.0), Color(0.22, 0.18, 0.11, 1.0), 1, 12, 14)
	panel.custom_minimum_size = Vector2(0, 300 if compact else 340)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(panel)

	var hub: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	hub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub.add_theme_constant_override("separation", 12)
	panel.add_child(hub)

	hub.add_child(_make_rest_story_panel(compact, hp, max_hp, heal_amount))

	var action_panel: PanelContainer = main.ui.make_surface_panel(Color(0.08, 0.09, 0.11, 0.96), Color(0.18, 0.2, 0.12, 1.0), 1, 12, 14)
	action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub.add_child(action_panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	action_panel.add_child(list)
	var title: Label = main._make_label("어떤 행동을 하시겠습니까?", 20 if compact else 22, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	list.add_child(title)
	var desc: Label = main._make_label("회복으로 안정성을 챙기거나, 카드 강화를 통해 다음 전투를 준비하세요.", 12 if compact else 14, Color(0.84, 0.88, 0.94, 1.0))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	list.add_child(desc)
	list.add_child(main.ui.make_objective_panel("휴식 목표", "체력 상태와 현재 빌드를 보고 회복, 강화, 진행 중 하나를 선택하세요.", compact))

	var actions: BoxContainer = main.ui.make_responsive_box(compact, 10)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(actions)

	var heal_btn: Button = _make_rest_action("휴식", "체력 %d 회복\n현재 %d / %d" % [heal_amount, hp, max_hp], Color(0.25, 0.5, 0.25, 1.0), compact)
	if hp >= max_hp:
		heal_btn.disabled = true
	heal_btn.pressed.connect(Callable(main, "_rest_heal"))
	actions.add_child(heal_btn)

	var upgrade_btn: Button = _make_rest_action("명상", "카드 1장 강화\n빌드 핵심 카드를 키움", Color(0.55, 0.34, 0.12, 1.0), compact)
	upgrade_btn.pressed.connect(Callable(main, "_rest_upgrade_card"))
	actions.add_child(upgrade_btn)

	var leave_btn: Button = _make_rest_action("떠나기 ▶", "정비 없이 다음 노드로 이동", Color(0.18, 0.34, 0.48, 1.0), compact)
	main.ui.style_primary_button(leave_btn, Color(0.18, 0.34, 0.48, 1.0))
	leave_btn.pressed.connect(Callable(main, "_complete_rest"))
	actions.add_child(leave_btn)

func _make_rest_status_strip(compact: bool, hp: int, max_hp: int, heal_amount: int) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.07, 0.08, 0.1, 0.98), Color(0.22, 0.18, 0.12, 1.0), 1, 12, 12)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	row.add_child(main.ui.make_chip("현재 체력 %d/%d" % [hp, max_hp], Color(0.34, 0.14, 0.14, 1.0), Color(1.0, 0.84, 0.84, 1.0), 13 if compact else 14))
	row.add_child(main.ui.make_chip("회복량 +%d" % heal_amount, Color(0.16, 0.28, 0.16, 1.0), Color(0.84, 1.0, 0.84, 1.0), 13 if compact else 14))
	row.add_child(main.ui.make_chip("추천 %s" % _rest_guidance_text(hp, max_hp), Color(0.16, 0.18, 0.1, 1.0), Color(0.96, 0.94, 0.82, 1.0), 13 if compact else 14))
	return panel

func _make_rest_story_panel(compact: bool, hp: int, max_hp: int, heal_amount: int) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.08, 0.09, 0.11, 0.96), Color(0.22, 0.18, 0.11, 1.0), 1, 12, 14)
	panel.custom_minimum_size = Vector2(0 if compact else 320, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var eyebrow: Label = main._make_label("안전 구역", 13 if compact else 14, Color(1.0, 0.86, 0.48, 1.0))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(eyebrow)
	var title: Label = main._make_label("캠프에 도착했습니다", 22 if compact else 24, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	box.add_child(main._make_art_rect(11, Vector2(236, 144) if compact else Vector2(260, 160)))
	var desc: Label = main._make_label("모닥불 곁에서 숨을 고르고 덱의 핵심 카드를 다듬을 수 있습니다.", 13 if compact else 15, Color(0.86, 0.9, 0.96, 1.0))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(desc)
	box.add_child(HSeparator.new())
	box.add_child(_make_rest_info_row("현재 체력", "%d/%d" % [hp, max_hp], Color(1.0, 0.7, 0.7, 1.0), compact))
	box.add_child(_make_rest_info_row("회복량", "+%d" % heal_amount, Color(0.72, 0.94, 0.7, 1.0), compact))
	box.add_child(_make_rest_info_row("추천", "낮으면 휴식 / 높으면 명상", Color(1.0, 0.88, 0.55, 1.0), compact))
	box.add_child(main.ui.make_chip("다음 전투 전 정비 구간", Color(0.16, 0.16, 0.1, 1.0), Color(0.96, 0.94, 0.82, 1.0), 12 if compact else 13))
	return panel

func _make_rest_info_row(title: String, value: String, color: Color, compact: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label: Label = main._make_label(title, 12 if compact else 13, Color(0.76, 0.82, 0.9, 1.0))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	var value_label: Label = main._make_label(value, 12 if compact else 14, color)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_label.custom_minimum_size = Vector2(110 if compact else 128, 0)
	row.add_child(value_label)
	return row

func _make_rest_action(title: String, detail: String, color: Color, compact: bool) -> Button:
	var icon := "◆"
	if title == "휴식":
		icon = "♥"
	elif title == "명상":
		icon = "✦"
	elif title.begins_with("떠나기"):
		icon = "➜"
	var button: Button = main.ui.make_large_action_button(title, detail, icon, color, compact)
	button.custom_minimum_size = Vector2(160 if compact else 210, 122 if compact else 144)
	return button

func _rest_guidance_text(hp: int, max_hp: int) -> String:
	if hp * 2 < max_hp:
		return "휴식 우선"
	return "명상 또는 진행"
