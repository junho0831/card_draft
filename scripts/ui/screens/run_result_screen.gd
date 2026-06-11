extends RefCounted
class_name RunResultScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer, is_win: bool) -> void:
	var compact := main._is_compact_layout()
	var panel := main._make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 620 if not compact else 420)
	body.add_child(panel)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 24)
	panel.add_child(list)

	var msg := "세계수를 타락으로부터 구했습니다!" if is_win else "영웅은 쓰러졌고 세계수의 빛이 사그라집니다..."
	var color := Color(0.4, 0.8, 0.4, 1.0) if is_win else Color(0.8, 0.4, 0.4, 1.0)
	list.add_child(main._make_label(msg, 18, color))

	var soul_stones := main._run_soul_stones(is_win)
	list.add_child(main._make_label("획득한 영혼석: %d" % soul_stones, 24, Color(0.65, 0.45, 0.85, 1.0)))

	var actions: BoxContainer = main.ui.make_action_bar(compact, 10)
	body.add_child(actions)
	main._add_menu_button(actions, "메인 메뉴로", "_return_to_main_after_run", Color(0.22, 0.24, 0.28, 1.0))
