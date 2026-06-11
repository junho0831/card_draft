extends RefCounted
class_name MainMenuScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer) -> void:
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 16)
	body.add_child(menu)

	var is_run_active := not main.current_run.is_empty() and main.current_run.get("result", "") == ""

	if is_run_active:
		main._add_menu_button(menu, "이어하기", "_continue_run", Color(0.18, 0.42, 0.22, 1.0))
		main._add_menu_button(menu, "런 포기", "_abandon_run", Color(0.42, 0.18, 0.18, 1.0))
	else:
		main._add_menu_button(menu, "새 런 시작", "_start_new_run", Color(0.16, 0.38, 0.54, 1.0))
	main._add_menu_button(menu, "메타 강화", "_show_meta_upgrade", Color(0.34, 0.28, 0.52, 1.0))
	main._add_menu_button(menu, "카드 도감", "_show_compendium", Color(0.22, 0.31, 0.38, 1.0))
	main._add_menu_button(menu, "카드 보관함", "_show_collection", Color(0.22, 0.31, 0.38, 1.0))
	main._add_menu_button(menu, "설정", "_show_settings", Color(0.22, 0.31, 0.38, 1.0))
	main._add_menu_button(menu, "종료", "_quit_game", Color(0.42, 0.18, 0.18, 1.0))

	body.add_child(main._make_label("MVP 구조: Act 1 국경지대 -> Act 2 죽음의 성", 14, Color(0.78, 0.82, 0.9, 1.0)))
