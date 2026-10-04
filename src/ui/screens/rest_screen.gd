extends RefCounted
class_name RestScreen

const Layout = preload("res://src/ui/screens/screen_layout.gd")
const Tokens = preload("res://src/ui/styles/ui_tokens.gd")

var main: Node
var screen_action_dock: PanelContainer = null

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer) -> void:
	var max_hp: int = int(main.current_run.get("max_hp", 50))
	var hp: int = int(main.current_run.get("hp", max_hp))
	var heal_amount: int = main.run_flow.rest_heal_amount(max_hp)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	body.add_child(row)
	row.add_child(main.ui.make_location_art("camp", Vector2(260, 152)))
	var story := VBoxContainer.new()
	story.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story.add_theme_constant_override("separation", 12)
	row.add_child(story)
	var title: Label = main.ui.make_label("캠프에 도착했습니다", 24, Tokens.TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	story.add_child(title)
	story.add_child(Layout.label(main, "현재 체력 %d / %d · 회복량 +%d" % [hp, max_hp, heal_amount]))
	story.add_child(Layout.label(main, "모닥불 곁에서 숨을 고르고 덱의 핵심 카드를 다듬을 수 있습니다.", true))
	var dock: Dictionary = Layout.dock(main, body)
	screen_action_dock = dock.panel
	var actions: BoxContainer = dock.actions
	var leave: Button = main.ui.make_dock_action_button("떠나기", "정비 없이 진행", Tokens.ACCENT_TEAL, false, 144)
	leave.pressed.connect(Callable(main, "_complete_rest"))
	actions.add_child(leave)
	var heal: Button = main.ui.make_dock_action_button("휴식", "체력 +%d" % heal_amount, Tokens.ACCENT_TEAL, hp * 2 < max_hp, 160)
	heal.disabled = hp >= max_hp
	heal.pressed.connect(Callable(main, "_rest_heal"))
	var upgrade: Button = main.ui.make_dock_action_button("명상", "카드 1장 강화", Tokens.ACCENT_GOLD, hp * 2 >= max_hp, 160)
	upgrade.pressed.connect(Callable(main, "_rest_upgrade_card"))
	actions.add_child(upgrade if hp * 2 < max_hp else heal)
	actions.add_child(heal if hp * 2 < max_hp else upgrade)

func _mount_rest_action_dock(body: VBoxContainer, hp: int, max_hp: int, heal_amount: int) -> void:
	var heal_recommended := hp * 2 < max_hp
	var dock: Dictionary = main.ui.mount_screen_action_dock(
		main,
		body,
		"휴식 행동 · 하나를 선택하세요",
		"현재 체력 %d/%d · 추천: %s" % [hp, max_hp, _rest_guidance_text(hp, max_hp)],
		Color(0.46, 0.62, 0.24, 1.0),
		126
	)
	screen_action_dock = dock.get("panel") as PanelContainer
	var actions: BoxContainer = dock.get("actions") as BoxContainer
	var heal_btn: Button = main.ui.make_dock_action_button("휴식", "체력 +%d" % heal_amount, Color(0.22, 0.5, 0.26, 1.0), heal_recommended, 150)
	heal_btn.disabled = hp >= max_hp
	heal_btn.pressed.connect(Callable(main, "_rest_heal"))
	var upgrade_btn: Button = main.ui.make_dock_action_button("명상", "카드 1장 강화", Color(0.52, 0.34, 0.14, 1.0), not heal_recommended, 166)
	upgrade_btn.pressed.connect(Callable(main, "_rest_upgrade_card"))
	var leave_btn: Button = main.ui.make_dock_action_button("떠나기 ▶", "정비 없이 진행", Color(0.18, 0.36, 0.52, 1.0), false, 156)
	leave_btn.pressed.connect(Callable(main, "_complete_rest"))
	if heal_recommended:
		actions.add_child(heal_btn)
		actions.add_child(upgrade_btn)
	else:
		actions.add_child(upgrade_btn)
		actions.add_child(heal_btn)
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

func _make_rest_story_panel(compact: bool, hp: int, max_hp: int, heal_amount: int, dock_layout: bool = false) -> PanelContainer:
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
	box.add_child(main.ui.make_location_art("camp", Vector2(190, 112) if dock_layout else (Vector2(236, 144) if compact else Vector2(260, 160))))
	var desc: Label = main._make_label("모닥불 곁에서 숨을 고르고 덱의 핵심 카드를 다듬을 수 있습니다.", 13 if compact else 15, Color(0.86, 0.9, 0.96, 1.0))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(desc)
	box.add_child(HSeparator.new())
	box.add_child(_make_rest_info_row("현재 체력", "%d/%d" % [hp, max_hp], Color(1.0, 0.7, 0.7, 1.0), compact))
	box.add_child(_make_rest_info_row("회복량", "+%d" % heal_amount, Color(0.72, 0.94, 0.7, 1.0), compact))
	if not dock_layout:
		box.add_child(_make_rest_info_row("추천", "낮으면 휴식 / 높으면 명상", Color(1.0, 0.88, 0.55, 1.0), compact))
	if not dock_layout:
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
	var icon := "휴식"
	if title == "휴식":
		icon = "회복"
	elif title == "명상":
		icon = "추천"
	elif title.begins_with("떠나기"):
		icon = "➜"
	var button: Button = main.ui.make_large_action_button(title, detail, icon, color, compact)
	button.custom_minimum_size = Vector2(160 if compact else 210, 122 if compact else 144)
	return button

func _rest_guidance_text(hp: int, max_hp: int) -> String:
	if hp * 2 < max_hp:
		return "휴식 우선"
	return "명상 또는 진행"
