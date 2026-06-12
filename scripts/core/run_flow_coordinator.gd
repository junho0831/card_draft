extends RefCounted
class_name RunFlowCoordinator

const ClassSelectionScreenScript := preload("res://scripts/ui/screens/class_selection_screen.gd")
const EventScreenScript := preload("res://scripts/ui/screens/event_screen.gd")
const MapScreenScript := preload("res://scripts/ui/screens/map_screen.gd")
const RestScreenScript := preload("res://scripts/ui/screens/rest_screen.gd")
const RewardScreenScript := preload("res://scripts/ui/screens/reward_screen.gd")
const ShopScreenScript := preload("res://scripts/ui/screens/shop_screen.gd")

var main: Node

func _init(main_ref: Node) -> void:
	main = main_ref

func _ensure_battle_screen() -> bool:
	if main.battle_screen != null:
		return true
	var battle_screen_script = load("res://scripts/ui/screens/battle_screen.gd")
	if battle_screen_script == null:
		main._show_message("전투 화면을 불러오지 못했습니다.", "_show_main_menu")
		return false
	main.battle_screen = battle_screen_script.new(main)
	return true

func start_new_run() -> void:
	main.active_screen = "class_selection"
	main._clear_screen()
	var body: VBoxContainer = main._begin_menu_screen("출신 선택")
	var screen = ClassSelectionScreenScript.new(main)
	screen.build(body)

func init_run(race_id: String) -> void:
	var acts: Array[Dictionary] = main.run_generator.load_acts()
	if acts.is_empty():
		main._show_message("Act 데이터를 불러오지 못했습니다.", "_show_main_menu")
		return
	var upgrades: Dictionary = main._profile_upgrades()
	var start_hp := 50 + int(upgrades.get("start_hp", 0)) * 5
	var start_gold := 100 + int(upgrades.get("start_gold", 0)) * 20
	var deck_ids: Array[String] = main.run_generator.starter_deck(race_id)
	main.current_run = main.run_store.create_new_run(acts, deck_ids, start_hp, start_gold)
	var relic_id: String = main.run_generator.get_starting_relic(race_id)
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
		main._show_run_result(true)
		return
	if result == "loss":
		main._show_run_result(false)
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
	var act_data: Dictionary = main._current_act()
	if act_data.is_empty():
		main._show_message("진행 중인 지도를 불러오지 못했습니다.", "_show_main_menu")
		return
	main.active_screen = "map"
	main._clear_screen()
	var body: VBoxContainer = main._begin_menu_screen("Act %d 지도" % int(main.current_run.get("act", 1)))
	var screen = MapScreenScript.new(main)
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
	var screen = RewardScreenScript.new(main)
	screen.build(body)

func show_event() -> void:
	main.active_screen = "event"
	main._clear_screen()
	var body: VBoxContainer = main._begin_menu_screen("이벤트")
	var screen = EventScreenScript.new(main)
	screen.build(body)

func advance_from_current_node(pending_keys: Array[String] = []) -> void:
	for key in pending_keys:
		main.current_run[String(key)] = {}
	main.run_store.mark_node_cleared(main.current_run)
	main.run_store.advance_after_node(main.current_run)
	main._save_run()
	if String(main.current_run.get("result", "")) == "win":
		main._show_run_result(true)
		return
	show_map()

func complete_event_and_return() -> void:
	advance_from_current_node(["pending_event", "pending_message"])

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
	var screen = ShopScreenScript.new(main)
	screen.build(body)

func show_rest() -> void:
	main.active_screen = "rest"
	main._clear_screen()
	var body: VBoxContainer = main._begin_menu_screen("휴식")
	var screen = RestScreenScript.new(main)
	screen.build(body)

func leave_shop() -> void:
	main.shop_run_service.leave_shop(main.current_run)
	advance_from_current_node()

func rest_heal_amount(max_hp: int) -> int:
	return maxi(1, int(round(float(max_hp) * 0.3)))

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
