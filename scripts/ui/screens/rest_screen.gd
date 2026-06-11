extends RefCounted
class_name RestScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer) -> void:
	var compact = main._is_compact_layout()
	var panel = main._make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 620 if not compact else 420)
	body.add_child(panel)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 24)
	panel.add_child(list)

	var max_hp = int(main.current_run.get("max_hp", 50))
	var hp = int(main.current_run.get("hp", max_hp))
	var heal_amount = main.run_flow.rest_heal_amount(max_hp)

	list.add_child(main._make_label("현재 체력: %d / %d" % [hp, max_hp], 16, Color(1.0, 0.8, 0.8, 1.0)))

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	list.add_child(actions)

	var heal_btn = main._add_menu_button(actions, "휴식 (체력 %d 회복)" % heal_amount, "_rest_heal", Color(0.25, 0.65, 0.25, 1.0))
	if hp >= max_hp:
		heal_btn.disabled = true

	main._add_menu_button(actions, "단련 (카드 1장 강화)", "_rest_upgrade_card", Color(0.8, 0.5, 0.2, 1.0))

	var nav: BoxContainer = main.ui.make_action_bar(compact, 10)
	body.add_child(nav)
	main._add_menu_button(nav, "계속 진행", "_complete_rest", Color(0.22, 0.24, 0.28, 1.0))
