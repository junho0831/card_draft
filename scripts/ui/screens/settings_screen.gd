extends RefCounted
class_name SettingsScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer) -> void:
	var panel: PanelContainer = main._make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 480)
	body.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var cutscene_toggle := CheckBox.new()
	cutscene_toggle.text = "전투 연출 켜기"
	cutscene_toggle.button_pressed = bool(main.player_profile["settings"]["battle_cutscene"])
	cutscene_toggle.toggled.connect(Callable(main, "_on_cutscene_toggled"))
	box.add_child(cutscene_toggle)
	var fast_ai_toggle := CheckBox.new()
	fast_ai_toggle.text = "AI 턴 빠르게"
	fast_ai_toggle.button_pressed = bool(main.player_profile["settings"]["fast_ai"])
	fast_ai_toggle.toggled.connect(Callable(main, "_on_fast_ai_toggled"))
	box.add_child(fast_ai_toggle)
	var fullscreen_toggle := CheckBox.new()
	fullscreen_toggle.text = "전체 화면"
	fullscreen_toggle.button_pressed = bool(main.player_profile["settings"].get("fullscreen", true))
	fullscreen_toggle.toggled.connect(Callable(main, "_on_fullscreen_toggled"))
	box.add_child(fullscreen_toggle)
	main._add_menu_button(box, "로컬 프로필 초기화", "_reset_profile", Color(0.35, 0.16, 0.16, 1.0))
	main._add_menu_button(box, "메인으로", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))
