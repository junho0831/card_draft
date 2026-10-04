extends RefCounted
class_name MessageScreen

const Layout = preload("res://src/ui/screens/screen_layout.gd")
const Tokens = preload("res://src/ui/styles/ui_tokens.gd")

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer, message: String, callback_method: String, target: Object = null) -> void:
	body.add_child(Layout.label(main, message))
	var dock: Dictionary = Layout.dock(main, body)
	var button: Button = main.ui.make_dock_action_button("확인", "", Tokens.ACCENT_GOLD, true, 160)
	button.pressed.connect(Callable(main if target == null else target, callback_method))
	dock.actions.add_child(button)
