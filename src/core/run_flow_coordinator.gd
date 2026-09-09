extends RefCounted
class_name RunFlowCoordinator

const EventScreenScript := preload("res://src/ui/screens/event_screen.gd")
const MapScreenScript := preload("res://src/ui/screens/map_screen.gd")
const RestScreenScript := preload("res://src/ui/screens/rest_screen.gd")
const RewardScreenScript := preload("res://src/ui/screens/reward_screen.gd")
const ShopScreenScript := preload("res://src/ui/screens/shop_screen.gd")
const BattleScreenScript := preload("res://src/ui/screens/battle_screen.gd")

var main: Node

func _init(main_ref: Node) -> void:
	main = main_ref

func _ensure_battle_screen() -> bool:
	if main.battle_screen != null:
		return true
	if BattleScreenScript == null:
		main._show_message("전투 화면을 불러오지 못했습니다.", "_show_main_menu")
		return false
	main.battle_screen = BattleScreenScript.new(main)
	return true

func start_new_run() -> void:
	main._show_race_selection()

func init_run(race_id: String, strategy_id: String = "") -> void:
	race_id = main._normalize_race_id(race_id)
	var strategy: Dictionary = {}
	if not strategy_id.is_empty():
		strategy = main.StartingStrategies.get_strategy(strategy_id)
		if not main.StartingStrategies.is_valid(strategy, race_id, main.card_db, main.relic_service):
			main._show_message("선택한 시작 전략을 사용할 수 없습니다. 세력과 전략을 다시 골라주세요.", "_show_race_selection")
			return
	if main.pending_guided_run and int(main.player_profile.get("learning_stage", 0)) < 5:
		strategy = {}
	var acts: Array[Dictionary] = main.run_generator.load_acts()
	if acts.is_empty():
		main._show_message("Act 데이터를 불러오지 못했습니다.", "_show_main_menu")
		return
	var upgrades: Dictionary = main._profile_upgrades()
	var start_hp := 26 + int(upgrades.get("start_hp", 0)) * 4
	var start_gold := 85 + int(upgrades.get("start_gold", 0)) * 15
	var deck_ids: Array[String] = main.run_generator.starter_deck(race_id)
	if not strategy.is_empty():
		deck_ids.assign(strategy.deck_ids)
	main.current_run = main.run_store.create_new_run(acts, deck_ids, start_hp, start_gold, race_id)
	if not strategy.is_empty():
		main.current_run["strategy_id"] = strategy.id
		main.current_run["strategy_name"] = strategy.name
		main.current_run["strategy_primary_tag"] = strategy.primary_tag
		main.current_run["starting_deck_ids"] = deck_ids.duplicate()
		main.current_run["starting_relic_id"] = strategy.relic_id
	if main.pending_guided_run and int(main.player_profile.get("learning_stage", 0)) < 5:
		main.current_run["guided_run"] = true
		main.current_run["lesson_resume_stage"] = int(main.player_profile.get("learning_stage", 0))
		main.current_run.map_nodes[0]["nodes"] = [["battle"], ["lesson_reward"], ["battle"], ["rest"], ["boss"]]
		var simple: Array[String] = []
		var reserve: Array[String] = []
		for id in deck_ids:
			if String(main.card_db.get_card(id).get("type", "")) == "unit":
				simple.append(id)
			else:
				reserve.append(id)
		while simple.size() < 10:
			simple.append(simple[0])
		main.current_run["deck_ids"] = simple
		main.current_run["lesson_reserve"] = reserve
	var relic_id: String = String(strategy.relic_id) if not strategy.is_empty() else main.run_generator.get_starting_relic(race_id)
	if bool(main.current_run.get("guided_run", false)):
		main.current_run["lesson_starting_relic"] = relic_id
		relic_id = ""
	if not relic_id.is_empty():
		(main.current_run.get("relic_ids", []) as Array).append(relic_id)
		main.relic_service.apply_on_acquire(main.current_run, relic_id)
	main._save_run()
	show_map()

func continue_run() -> void:
	if main.current_run.is_empty():
		main._show_main_menu()
		return
	var result := String(main.current_run.get("result", ""))
	if result == "win":
		main._finish_run(true)
		return
	if result == "loss":
		main._finish_run(false)
		return
	var pending_message: Dictionary = main.current_run.get("pending_message", {})
	if not pending_message.is_empty():
		main._show_message(String(pending_message.get("message", "")), String(pending_message.get("callback_method", "_show_map")))
		return
	var pending_subscreen: Dictionary = main.current_run.get("pending_subscreen", {})
	if not pending_subscreen.is_empty():
		var source := String(pending_subscreen.get("source", ""))
		match String(pending_subscreen.get("type", "")):
			"remove_card":
				main._show_remove_card_screen(String(pending_subscreen.get("reason", "보상")), source)
				return
			"upgrade_card":
				main._show_upgrade_card_screen(source)
				return
	if not Dictionary(main.current_run.get("active_enemy", {})).is_empty():
		if _ensure_battle_screen():
			main.battle_screen.start_battle()
		return
	if not Dictionary(main.current_run.get("pending_card_reward", {})).is_empty():
		show_card_reward()
		return
	if not Dictionary(main.current_run.get("pending_event", {})).is_empty():
		show_event()
		return
	if not Dictionary(main.current_run.get("pending_shop", {})).is_empty():
		show_shop()
		return
	show_map()

func show_map() -> void:
	if main.current_run.is_empty():
		main._show_main_menu()
		return
	_unlock_lesson_content()
	var act_data: Dictionary = main._current_act()
	if act_data.is_empty():
		main._show_message("진행 중인 지도를 불러오지 못했습니다.", "_show_main_menu")
		return
	main.active_screen = "map"
	main._clear_screen()
	var body: VBoxContainer = main._begin_menu_screen("Act %d 지도" % int(main.current_run.get("act", 1)))
	var screen = main._retain_screen_controller(MapScreenScript.new(main))
	screen.build(body, act_data)

func enter_current_node() -> void:
	var node: Dictionary = main.run_store.current_node(main.current_run)
	match String(node.get("type", "")):
		"battle":
			prepare_battle("normal")
		"elite":
			prepare_battle("elite")
		"boss":
			prepare_battle("boss")
		"lesson_reward":
			if Dictionary(main.current_run.get("pending_card_reward", {})).is_empty():
				main.current_run["pending_card_reward"] = {"choices": main.Onboarding.equipment_choices(), "lesson_equipment": true, "gold_reward": 0}
				main._save_run()
			show_card_reward()
		"event":
			if Dictionary(main.current_run.get("pending_event", {})).is_empty():
				main.current_run["pending_event"] = main.event_service.roll_event()
				main._save_run()
			show_event()
		"shop":
			show_shop()
		"rest":
			show_rest()
		_:
			show_map()

func show_card_reward() -> void:
	main.active_screen = "reward"
	main._clear_screen()
	var body: VBoxContainer = main._begin_menu_screen("보상 선택")
	var screen = main._retain_screen_controller(RewardScreenScript.new(main))
	screen.build(body)

func show_event() -> void:
	main.active_screen = "event"
	main._clear_screen()
	var body: VBoxContainer = main._begin_menu_screen("이벤트")
	var screen = main._retain_screen_controller(EventScreenScript.new(main))
	screen.build(body)

func advance_from_current_node(pending_keys: Array[String] = []) -> void:
	for key in pending_keys:
		main.current_run[String(key)] = {}
	_record_lesson_completion()
	main.run_store.mark_node_cleared(main.current_run)
	main.run_store.advance_after_node(main.current_run)
	main._save_run()
	if String(main.current_run.get("result", "")) == "win":
		main._finish_run(true)
		return
	show_map()

func complete_event_and_return() -> void:
	var pending_keys: Array[String] = ["pending_event", "pending_message"]
	advance_from_current_node(pending_keys)

func show_shop() -> void:
	if Dictionary(main.current_run.get("pending_shop", {})).is_empty():
		main.current_run["pending_shop"] = main.shop_run_service.generate_shop_state({
			"roll_card_choices": Callable(main, "_roll_card_choices"),
			"random_relic": Callable(main.relic_service, "random_relic"),
			"relic_ids": main.current_run.get("relic_ids", []),
		})
		main._save_run()
	main.active_screen = "shop"
	main._clear_screen()
	var body: VBoxContainer = main._begin_menu_screen("상점")
	var screen = main._retain_screen_controller(ShopScreenScript.new(main))
	screen.build(body)

func show_rest() -> void:
	main.active_screen = "rest"
	main._clear_screen()
	var body: VBoxContainer = main._begin_menu_screen("휴식")
	var screen = main._retain_screen_controller(RestScreenScript.new(main))
	screen.build(body)

func leave_shop() -> void:
	main.shop_run_service.leave_shop(main.current_run)
	advance_from_current_node()

func rest_heal_amount(max_hp: int) -> int:
	return maxi(1, int(round(float(max_hp) * 0.45)))

func rest_heal() -> void:
	var max_hp := int(main.current_run.get("max_hp", 50))
	main.current_run["hp"] = min(max_hp, int(main.current_run.get("hp", 0)) + rest_heal_amount(max_hp))
	main._save_run()
	complete_rest()

func rest_upgrade_card() -> void:
	main._show_upgrade_card_screen("rest_upgrade")

func complete_rest() -> void:
	advance_from_current_node()

func prepare_battle(tier: String) -> void:
	if _ensure_battle_screen():
		main.battle_screen._prepare_battle(tier)

func _record_lesson_completion() -> void:
	if bool(main.current_run.get("guided_run", false)) and int(main.current_run.get("act", 1)) == 1:
		main.player_profile["learning_stage"] = maxi(int(main.player_profile.get("learning_stage", 0)), int(main.current_run.get("current_node_index", 0)) + 1)
		main._save_profile()

func _unlock_lesson_content() -> void:
	if main._lesson_stage() >= 4 and main.current_run.has("lesson_reserve"):
		main.current_run.deck_ids.append_array(main.current_run.lesson_reserve)
		main.current_run.erase("lesson_reserve")
	if main._lesson_stage() >= 5 and main.current_run.has("lesson_starting_relic"):
		var id := String(main.current_run.lesson_starting_relic)
		if not main.current_run.relic_ids.has(id):
			main.current_run.relic_ids.append(id)
			main.relic_service.apply_on_acquire(main.current_run, id)
		main.current_run.erase("lesson_starting_relic")
	main._save_run()
