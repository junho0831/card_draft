extends RefCounted
class_name MetaUpgradeScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer) -> void:
	var panel: PanelContainer = main._make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 640)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var upgrades: Dictionary = main._profile_upgrades()
	box.add_child(main._make_label("영혼석 %d" % int(main.player_profile.get("soul_stones", 0)), 20, Color(1.0, 0.88, 0.55, 1.0)))
	box.add_child(main._make_label("튼튼한 몸: 시작 최대 체력 +5 (현재 %d)" % int(upgrades.get("start_hp", 0)), 15, Color(0.92, 0.94, 0.98, 1.0)))
	box.add_child(main._make_label("왕실 지원금: 시작 골드 +20 (현재 %d)" % int(upgrades.get("start_gold", 0)), 15, Color(0.92, 0.94, 0.98, 1.0)))
	box.add_child(main._make_label("두 번째 기회: 런당 1회 체력 1로 버팀 (현재 %d)" % int(upgrades.get("second_chance", 0)), 15, Color(0.92, 0.94, 0.98, 1.0)))
	_add_upgrade_button(box, "튼튼한 몸", "start_hp", "_upgrade_start_hp", 3, 50, 25)
	_add_upgrade_button(box, "왕실 지원금", "start_gold", "_upgrade_start_gold", 3, 50, 25)
	_add_upgrade_button(box, "두 번째 기회", "second_chance", "_upgrade_second_chance", 1, 150, 0)
	main._add_menu_button(box, "메인으로", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))

func _add_upgrade_button(box: VBoxContainer, title: String, key: String, callback: String, limit: int, base_cost: int, step: int) -> void:
	var level := int(main._profile_upgrades().get(key, 0))
	var cost := base_cost + level * step
	var stones := int(main.player_profile.get("soul_stones", 0))
	var text := "%s 강화 · 영혼석 %d" % [title, cost]
	if level >= limit:
		text = "%s · 최대 강화" % title
	elif stones < cost:
		text += " (%d 부족)" % (cost - stones)
	var button: Button = main._add_menu_button(box, text, callback, Color(0.18, 0.4, 0.24, 1.0))
	button.disabled = level >= limit or stones < cost
