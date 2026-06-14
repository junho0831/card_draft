extends RefCounted

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const RewardScreenScript := preload("res://scripts/ui/screens/reward_screen.gd")

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
	_test_continue_run_routes(main)
	_test_reward_claim_advances_node(main)
	_test_shop_leave_advances_node(main)
	_test_rest_complete_advances_node(main)
	_test_event_complete_advances_node(main)

	main._clear_screen()
	main._clear_run()
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

func _test_continue_run_routes(main: Node) -> void:
	var acts: Array[Dictionary] = main.run_generator.load_acts()
	var run_data: Dictionary = main.run_store.create_new_run(acts, main.run_generator.starter_deck(), 50, 100)

	run_data["pending_card_reward"] = {"choices": ["militia"], "gold_reward": 0}
	main.current_run = run_data.duplicate(true)
	main._continue_run()
	_assert_eq(String(main.active_screen), "reward", "continue_run routes pending reward")

	run_data = main.run_store.create_new_run(acts, main.run_generator.starter_deck(), 50, 100)
	run_data["pending_event"] = main.event_service.roll_event()
	main.current_run = run_data.duplicate(true)
	main._continue_run()
	_assert_eq(String(main.active_screen), "event", "continue_run routes pending event")

	run_data = main.run_store.create_new_run(acts, main.run_generator.starter_deck(), 50, 100)
	run_data["pending_shop"] = main.shop_run_service.generate_shop_state({
		"roll_card_choices": Callable(main, "_roll_card_choices"),
		"random_relic": Callable(main.relic_service, "random_relic"),
		"relic_ids": [],
	})
	main.current_run = run_data.duplicate(true)
	main._continue_run()
	_assert_eq(String(main.active_screen), "shop", "continue_run routes pending shop")

	run_data = main.run_store.create_new_run(acts, main.run_generator.starter_deck(), 50, 100)
	run_data["pending_subscreen"] = {"type": "remove_card", "reason": "이벤트", "source": "event_complete"}
	main.current_run = run_data.duplicate(true)
	main._continue_run()
	_assert_eq(String(main.active_screen), "remove_card", "continue_run routes pending remove subscreen")

	var enemy: Dictionary = main.enemy_service.pick_enemy(1, "normal")
	var player_card: Dictionary = main.card_db.get_card("militia")
	var opponent_card: Dictionary = main.card_db.get_card(String((enemy.get("deck_ids", []) as Array)[0]))
	run_data = main.run_store.create_new_run(acts, main.run_generator.starter_deck(), 50, 100)
	run_data["active_enemy"] = enemy
	run_data["battle_snapshot"] = {
		"battle_tier": "normal",
		"current_player": "player",
		"selected_attacker": -1,
		"input_locked": false,
		"player": {
			"name": "플레이어",
			"health": 37,
			"max_health": 50,
			"mana": 2,
			"max_mana": 2,
			"deck": [],
			"hand": [player_card.duplicate(true)],
			"field": [],
			"corpse_explosion_stacks": 0,
			"curses": 0,
			"ritual_stacks": 0,
		},
		"opponent": {
			"name": String(enemy.get("name", "적")),
			"health": 14,
			"max_health": int(enemy.get("base_hp", 20)),
			"mana": 1,
			"max_mana": 1,
			"deck": [],
			"hand": [opponent_card.duplicate(true)],
			"field": [],
			"corpse_explosion_stacks": 0,
			"curses": 0,
			"ritual_stacks": 0,
		},
		"log_text": "복원 테스트",
		"turn_timer_left": 12.0,
		"battle_state_flags": {
			"cards_played_this_turn": 1,
			"mana_crystal_bonus": false,
			"first_card_discount_available": false,
			"necromancer_ring_used": false,
			"second_chance_used": false,
			"summon_build_started": false,
		},
	}
	main.current_run = run_data.duplicate(true)
	main._continue_run()
	_assert_eq(String(main.active_screen), "battle", "continue_run routes active battle")
	_assert_eq(int(main.battle_screen.player.get("health", 0)), 37, "battle snapshot restores player health")
	_assert_eq(String(main.battle_screen.log_label.text), "복원 테스트", "battle snapshot restores log text")

func _test_reward_claim_advances_node(main: Node) -> void:
	var acts: Array[Dictionary] = main.run_generator.load_acts()
	var run_data: Dictionary = main.run_store.create_new_run(acts, main.run_generator.starter_deck(), 50, 100)
	var deck_before: int = (run_data.get("deck_ids", []) as Array).size()
	run_data["pending_card_reward"] = {
		"choices": ["militia"],
		"gold_reward": 0,
		"bonus_relic": {},
	}
	main.current_run = run_data
	var reward_screen: RefCounted = RewardScreenScript.new(main)
	reward_screen._claim_card_reward("militia")
	_assert_eq(String(main.active_screen), "map", "claiming reward returns to map")
	_assert_eq(int(main.current_run.get("current_node_index", -1)), 1, "claiming reward advances node")
	_assert_eq((main.current_run.get("deck_ids", []) as Array).size(), deck_before + 1, "claiming reward adds card to deck")
	_assert_true(Dictionary(main.current_run.get("pending_card_reward", {})).is_empty(), "claiming reward clears pending reward")

func _test_shop_leave_advances_node(main: Node) -> void:
	var acts: Array[Dictionary] = main.run_generator.load_acts()
	var run_data: Dictionary = main.run_store.create_new_run(acts, main.run_generator.starter_deck(), 50, 100)
	run_data["current_node_index"] = 4
	run_data["pending_shop"] = main.shop_run_service.generate_shop_state({
		"roll_card_choices": Callable(main, "_roll_card_choices"),
		"random_relic": Callable(main.relic_service, "random_relic"),
		"relic_ids": [],
	})
	main.current_run = run_data
	main.run_flow.leave_shop()
	_assert_eq(String(main.active_screen), "map", "leaving shop returns to map")
	_assert_eq(int(main.current_run.get("current_node_index", -1)), 5, "leaving shop advances node")
	_assert_true(Dictionary(main.current_run.get("pending_shop", {})).is_empty(), "leaving shop clears pending shop")

func _test_rest_complete_advances_node(main: Node) -> void:
	var acts: Array[Dictionary] = main.run_generator.load_acts()
	var run_data: Dictionary = main.run_store.create_new_run(acts, main.run_generator.starter_deck(), 50, 100)
	run_data["current_node_index"] = 6
	main.current_run = run_data
	main.run_flow.complete_rest()
	_assert_eq(String(main.active_screen), "map", "completing rest returns to map")
	_assert_eq(int(main.current_run.get("current_node_index", -1)), 7, "completing rest advances node")

func _test_event_complete_advances_node(main: Node) -> void:
	var acts: Array[Dictionary] = main.run_generator.load_acts()
	var run_data: Dictionary = main.run_store.create_new_run(acts, main.run_generator.starter_deck(), 50, 100)
	run_data["current_node_index"] = 2
	run_data["pending_event"] = main.event_service.roll_event()
	run_data["pending_message"] = {
		"message": "이벤트 완료",
		"callback_method": "_complete_event_and_return",
	}
	main.current_run = run_data
	main._complete_event_and_return()
	_assert_eq(String(main.active_screen), "map", "completing event returns to map")
	_assert_eq(int(main.current_run.get("current_node_index", -1)), 3, "completing event advances node")
	_assert_true(Dictionary(main.current_run.get("pending_event", {})).is_empty(), "completing event clears pending event")
	_assert_true(Dictionary(main.current_run.get("pending_message", {})).is_empty(), "completing event clears pending message")

func _assert_true(value: bool, message: String) -> void:
	_count += 1
	if not value:
		_failures.append(message)

func _assert_eq(actual, expected, message: String) -> void:
	_count += 1
	if actual != expected:
		_failures.append("%s | expected=%s actual=%s" % [message, str(expected), str(actual)])
