extends RefCounted

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _failures: Array[String] = []
var _count := 0

func run() -> Dictionary:
	_failures.clear()
	_count = 0

	var tree := Engine.get_main_loop() as SceneTree
	var main = MAIN_SCENE.instantiate()
	tree.root.add_child(main)

	_test_boots_to_main_menu(main)
	_test_run_start_and_battle_entry(main)
	_test_secondary_screens(main)

	tree.root.remove_child(main)
	main.free()

	return {
		"count": _count,
		"failures": _failures,
	}

func _test_boots_to_main_menu(main: Node) -> void:
	_assert_eq(String(main.active_screen), "main_menu", "main scene boots to main menu")
	_assert_true(main.root_box != null, "main scene builds root ui")
	_assert_true(main.card_defs.size() > 0, "main scene loads card data")

func _test_run_start_and_battle_entry(main: Node) -> void:
	main._start_new_run()
	_assert_eq(String(main.active_screen), "map", "start_new_run opens map")
	_assert_true(not main.current_run.is_empty(), "start_new_run creates run data")
	_assert_eq(String(main.run_store.current_node(main.current_run).get("type", "")), "battle", "new run starts on battle node")

	main._enter_current_node()
	_assert_eq(String(main.active_screen), "battle", "enter_current_node opens battle screen")
	_assert_true(not Dictionary(main.current_run.get("active_enemy", {})).is_empty(), "battle entry selects enemy")
	_assert_true(main.battle_screen != null, "battle screen is instantiated")

func _test_secondary_screens(main: Node) -> void:
	main.current_run["pending_card_reward"] = {"choices": ["militia"], "gold_reward": 0}
	main._show_card_reward()
	_assert_eq(String(main.active_screen), "reward", "reward screen opens")

	main.current_run["pending_event"] = main.event_service.roll_event()
	main._show_event()
	_assert_eq(String(main.active_screen), "event", "event screen opens")

	main.current_run["pending_shop"] = main.shop_run_service.generate_shop_state({
		"roll_card_choices": Callable(main, "_roll_card_choices"),
		"random_relic": Callable(main.relic_service, "random_relic"),
		"relic_ids": main.current_run.get("relic_ids", []),
	})
	main._show_shop()
	_assert_eq(String(main.active_screen), "shop", "shop screen opens")

	main._show_rest()
	_assert_eq(String(main.active_screen), "rest", "rest screen opens")

	main._show_collection()
	_assert_eq(String(main.active_screen), "collection", "collection screen opens")

	main._show_settings()
	_assert_eq(String(main.active_screen), "settings", "settings screen opens")

	main._show_compendium()
	_assert_eq(String(main.active_screen), "compendium", "compendium screen opens")

	main._show_meta_upgrade()
	_assert_eq(String(main.active_screen), "meta_upgrade", "meta upgrade screen opens")

	main._show_run_result(false)
	_assert_eq(String(main.active_screen), "run_result", "run result screen opens")

func _assert_true(value: bool, message: String) -> void:
	_count += 1
	if not value:
		_failures.append(message)

func _assert_eq(actual, expected, message: String) -> void:
	_count += 1
	if actual != expected:
		_failures.append("%s | expected=%s actual=%s" % [message, str(expected), str(actual)])
