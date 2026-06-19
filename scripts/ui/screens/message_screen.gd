extends RefCounted
class_name MessageScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer, message: String, callback_method: String, target: Object = null) -> void:
	var panel: PanelContainer = main._make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 520)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(main._make_label(message, 18, Color(0.92, 0.94, 0.98, 1.0)))
	main._add_menu_button(box, "확인", callback_method, Color(0.18, 0.34, 0.48, 1.0), target)
