extends RefCounted

const MAIN_SCENE := preload("res://src/core/Main.tscn")
const VIEWPORTS := [
	Vector2i(1920, 1080),
	Vector2i(1280, 720),
	Vector2i(1024, 768),
	Vector2i(800, 1280),
]

var _failures: Array[String] = []
var _count := 0

func run() -> Dictionary:
	_failures.clear()
	_count = 0

	var tree := Engine.get_main_loop() as SceneTree
	var main = MAIN_SCENE.instantiate()
	tree.root.add_child(main)

	for viewport_size in VIEWPORTS:
		main.set_meta("layout_viewport_override", viewport_size)
		main._apply_root_layout()
		_check_screen(main, viewport_size, "main_menu", Callable(main, "_show_main_menu"))

		main._start_new_run()
		_check_current_screen(main, viewport_size, "map")

		main._enter_current_node()
		_check_current_screen(main, viewport_size, "battle")

		main.current_run["pending_card_reward"] = {
			"choices": main._roll_card_reward_choices(3, false),
			"gold_reward": 20,
			"bonus_relic": {},
		}
		_check_screen(main, viewport_size, "reward", Callable(main, "_show_card_reward"))

		main.current_run["pending_shop"] = main.shop_run_service.generate_shop_state({
			"roll_card_choices": Callable(main, "_roll_card_choices"),
			"random_relic": Callable(main.relic_service, "random_relic"),
			"relic_ids": main.current_run.get("relic_ids", []),
		})
		_check_screen(main, viewport_size, "shop", Callable(main, "_show_shop"))

		main.current_run["pending_event"] = main.event_service.roll_event()
		_check_screen(main, viewport_size, "event", Callable(main, "_show_event"))

		main._show_rest()
		_check_current_screen(main, viewport_size, "rest")

		main._show_run_result(true)
		_check_current_screen(main, viewport_size, "run_result")

		_check_screen(main, viewport_size, "ui_guide", Callable(main, "_show_ui_guide"))

	main.remove_meta("layout_viewport_override")

	tree.root.remove_child(main)
	main.free()

	return {
		"count": _count,
		"failures": _failures,
	}

func _check_screen(main: Node, viewport_size: Vector2i, screen_name: String, show_callable: Callable) -> void:
	show_callable.call()
	_check_current_screen(main, viewport_size, screen_name)

func _check_current_screen(main: Node, viewport_size: Vector2i, screen_name: String) -> void:
	main._apply_root_layout()
	var viewport_width: float = main._layout_viewport_size().x
	_assert_true(main.root_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "%s root horizontal scroll disabled @ %s" % [screen_name, str(viewport_size)])
	_assert_true(main.root_box.custom_minimum_size.x <= viewport_width + 1.0, "%s root width fits viewport @ %s" % [screen_name, str(viewport_size)])
	_assert_true(main.root_box.get_combined_minimum_size().x <= viewport_width + 1.0, "%s content minimum width fits viewport @ %s: %.1f > %.1f" % [screen_name, str(viewport_size), main.root_box.get_combined_minimum_size().x, viewport_width])
	for index in range(main.root_box.get_child_count()):
		var child := main.root_box.get_child(index) as Control
		if child == null:
			continue
		_assert_true(child.get_combined_minimum_size().x <= viewport_width + 1.0, "%s child %d (%s) minimum width fits viewport @ %s: %.1f > %.1f" % [screen_name, index, child.get_class(), str(viewport_size), child.get_combined_minimum_size().x, viewport_width])
		if child.get_combined_minimum_size().x > viewport_width + 1.0:
			for nested_index in range(child.get_child_count()):
				var nested := child.get_child(nested_index) as Control
				if nested == null:
					continue
				_assert_true(nested.get_combined_minimum_size().x <= viewport_width + 1.0, "%s child %d.%d (%s) minimum width fits viewport @ %s: %.1f > %.1f" % [screen_name, index, nested_index, nested.get_class(), str(viewport_size), nested.get_combined_minimum_size().x, viewport_width])

	for scroll_node in _collect_scroll_containers(main):
		var scroll := scroll_node as ScrollContainer
		_assert_true(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "%s scroll container keeps horizontal scroll disabled @ %s" % [screen_name, str(viewport_size)])

func _collect_scroll_containers(root: Node) -> Array:
	var found: Array = []
	for child in root.get_children():
		if child is ScrollContainer:
			found.append(child)
		found.append_array(_collect_scroll_containers(child))
	return found

func _assert_true(value: bool, message: String) -> void:
	_count += 1
	if not value:
		_failures.append(message)
