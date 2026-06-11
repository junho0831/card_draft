extends RefCounted
class_name CompendiumScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer) -> void:
	var compact := main._is_compact_layout()
	var panel := main._make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 620 if not compact else 420)
	body.add_child(panel)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	panel.add_child(list)

	var stats := main.player_profile.get("stats", {})
	list.add_child(main._make_label("플레이 통계", 18, Color(1.0, 0.9, 0.5, 1.0)))
	var stat_grid := GridContainer.new()
	stat_grid.columns = 2
	stat_grid.add_theme_constant_override("h_separation", 24)
	stat_grid.add_theme_constant_override("v_separation", 12)
	list.add_child(stat_grid)

	var stat_items = [
		["총 플레이", "%d 런" % int(stats.get("runs_played", 0))],
		["승리", "%d 회" % int(stats.get("runs_won", 0))],
		["처치한 엘리트", "%d 마리" % int(stats.get("elites_killed", 0))],
		["수집한 카드", "%d 장" % main.player_profile.get("owned_cards", {}).size()]
	]

	for item in stat_items:
		var name_lbl := main._make_label(item[0], 14, Color(0.7, 0.75, 0.8, 1.0))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var val_lbl := main._make_label(item[1], 16, Color(0.9, 0.95, 1.0, 1.0))
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_grid.add_child(name_lbl)
		stat_grid.add_child(val_lbl)

	var actions: BoxContainer = main.ui.make_action_bar(compact, 10)
	body.add_child(actions)
	main._add_menu_button(actions, "돌아가기", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))
