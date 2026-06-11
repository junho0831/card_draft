extends RefCounted
class_name MetaUpgradeScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer) -> void:
	var compact := main._is_compact_layout()
	body.add_child(main._make_label("보유 영혼석: %d" % int(main.player_profile.get("soul_stones", 0)), 18, Color(0.65, 0.45, 0.85, 1.0)))

	var panel := main._make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 620 if not compact else 420)
	body.add_child(panel)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	panel.add_child(list)

	var upgrades := main._profile_upgrades()
	var hp_level := int(upgrades.get("start_hp", 0))
	var hp_cost := (hp_level + 1) * 10
	var hp_btn := main._add_menu_button(list, "시작 체력 증가 (Lv.%d) - %d 영혼석" % [hp_level, hp_cost], "_upgrade_start_hp", Color(0.28, 0.38, 0.28, 1.0))
	if int(main.player_profile.get("soul_stones", 0)) < hp_cost or hp_level >= 5:
		hp_btn.disabled = true

	var gold_level := int(upgrades.get("start_gold", 0))
	var gold_cost := (gold_level + 1) * 15
	var gold_btn := main._add_menu_button(list, "시작 골드 증가 (Lv.%d) - %d 영혼석" % [gold_level, gold_cost], "_upgrade_start_gold", Color(0.48, 0.38, 0.18, 1.0))
	if int(main.player_profile.get("soul_stones", 0)) < gold_cost or gold_level >= 5:
		gold_btn.disabled = true

	var chance_level := int(upgrades.get("second_chance", 0))
	var chance_cost := 100
	var chance_btn := main._add_menu_button(list, "두 번째 기회 (체력 1 버티기) - %d 영혼석" % chance_cost, "_upgrade_second_chance", Color(0.58, 0.28, 0.28, 1.0))
	if int(main.player_profile.get("soul_stones", 0)) < chance_cost or chance_level >= 1:
		chance_btn.disabled = true

	var actions: BoxContainer = main.ui.make_action_bar(compact, 10)
	body.add_child(actions)
	main._add_menu_button(actions, "돌아가기", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))
