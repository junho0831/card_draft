extends RefCounted
class_name SettingsScreen

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

	var fast_ai := CheckButton.new()
	fast_ai.text = "AI 턴 빠른 진행 (애니메이션 스킵)"
	fast_ai.button_pressed = bool(main.player_profile.get("fast_ai", false))
	fast_ai.toggled.connect(Callable(main, "_on_fast_ai_toggled"))
	list.add_child(fast_ai)

	var cutscene := CheckButton.new()
	cutscene.text = "전투 컷신 애니메이션 재생"
	cutscene.button_pressed = bool(main.player_profile.get("battle_cutscene", true))
	cutscene.toggled.connect(Callable(main, "_on_cutscene_toggled"))
	list.add_child(cutscene)

	list.add_child(main._make_label("기타", 16, Color(0.9, 0.9, 0.9, 1.0)))
	main._add_menu_button(list, "데이터 초기화", "_reset_profile", Color(0.42, 0.18, 0.18, 1.0))

	var actions: BoxContainer = main.ui.make_action_bar(compact, 10)
	body.add_child(actions)
	main._add_menu_button(actions, "돌아가기", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))
