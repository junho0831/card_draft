extends RefCounted
class_name EventScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer) -> void:
	var event_data: Dictionary = main.current_run.get("pending_event", {})
	body.add_child(main._make_run_summary_panel())
	var panel := main._make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 640)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(main._make_label(String(event_data.get("title", "")), 24, Color(1.0, 0.88, 0.55, 1.0)))
	box.add_child(main._make_label(String(event_data.get("description", "")), 16, Color(0.9, 0.92, 0.98, 1.0)))
	for option in event_data.get("options", []):
		if typeof(option) != TYPE_DICTIONARY:
			continue
		var button := main._add_menu_button(box, String(option.get("label", "")), "_noop", Color(0.22, 0.31, 0.38, 1.0))
		button.pressed.connect(Callable(self, "_resolve_event_option").bind(String(option.get("effect", ""))))

func _resolve_event_option(effect: String) -> void:
	match effect:
		"merchant_card":
			main.current_run["hp"] = max(1, int(main.current_run.get("hp", 1)) - 5)
			var premium_choices := main._roll_high_cost_cards(3)
			main.current_run["pending_card_reward"] = {
				"choices": premium_choices,
				"bonus_relic": {},
				"battle_tier": "event",
			}
			main.current_run["pending_event"] = {}
			main._save_run()
			main._show_card_reward()
			return
		"merchant_relic":
			if int(main.current_run.get("gold", 0)) < 50:
				main._show_message("골드가 부족합니다.", "_show_event")
				return
			main.current_run["gold"] = int(main.current_run["gold"]) - 50
			var merchant_relic: Dictionary = main.relic_service.random_relic(main.current_run.get("relic_ids", []))
			if merchant_relic.is_empty():
				main._show_message("얻을 유물이 없습니다.", "_complete_event_and_return", self)
				return
			var merchant_relic_id := String(merchant_relic.get("id", ""))
			(main.current_run.get("relic_ids", []) as Array).append(merchant_relic_id)
			main.relic_service.apply_on_acquire(main.current_run, merchant_relic_id)
			main._show_message("수상한 상인: %s 획득" % String(merchant_relic.get("name", "")), "_complete_event_and_return", self)
			return
		"gamble_small":
			if int(main.current_run.get("gold", 0)) < 30:
				main._show_message("골드가 부족합니다.", "_show_event")
				return
			main.current_run["gold"] = int(main.current_run["gold"]) - 30
			if randi() % 2 == 0:
				main.current_run["gold"] = int(main.current_run["gold"]) + 80
				main._show_message("도박 성공: 골드 80 획득", "_complete_event_and_return", self)
				return
			main._show_message("도박 실패: 골드를 잃었습니다.", "_complete_event_and_return", self)
			return
		"gamble_relic":
			if int(main.current_run.get("gold", 0)) < 60:
				main._show_message("골드가 부족합니다.", "_show_event")
				return
			main.current_run["gold"] = int(main.current_run["gold"]) - 60
			if randi() % 10 < 3:
				var relic: Dictionary = main.relic_service.random_relic(main.current_run.get("relic_ids", []))
				if not relic.is_empty():
					var relic_id := String(relic.get("id", ""))
					(main.current_run.get("relic_ids", []) as Array).append(relic_id)
					main.relic_service.apply_on_acquire(main.current_run, relic_id)
					main._show_message("대박: %s 획득" % String(relic.get("name", "")), "_complete_event_and_return", self)
					return
			main._show_message("도박 실패: 아무것도 얻지 못했습니다.", "_complete_event_and_return", self)
			return
		"remove_card":
			main.pending_return_screen = "event_complete"
			main._show_remove_card_screen("이벤트")
			return
		"heal_10":
			main.current_run["hp"] = min(int(main.current_run.get("max_hp", 50)), int(main.current_run.get("hp", 0)) + 10)
			main._show_message("버려진 성당: 체력 10 회복", "_complete_event_and_return", self)
			return
		"curse_relic":
			main.current_run["max_hp"] = max(10, int(main.current_run.get("max_hp", 50)) - 5)
			main.current_run["hp"] = min(int(main.current_run.get("max_hp", 50)), int(main.current_run.get("hp", 0)))
			var curse_relic: Dictionary = main.relic_service.random_relic(main.current_run.get("relic_ids", []))
			if not curse_relic.is_empty():
				var curse_relic_id := String(curse_relic.get("id", ""))
				(main.current_run.get("relic_ids", []) as Array).append(curse_relic_id)
				main.relic_service.apply_on_acquire(main.current_run, curse_relic_id)
				main._show_message("저주를 받고 %s 획득" % String(curse_relic.get("name", "")), "_complete_event_and_return", self)
				return
			_complete_event_and_return()
			return
		"heal":
			var heal_amount := maxi(1, int(round(float(int(main.current_run.get("max_hp", 50))) * 0.3)))
			main.current_run["hp"] = min(int(main.current_run.get("max_hp", 50)), int(main.current_run.get("hp", 0)) + heal_amount)
			main._show_message("마법 샘: 체력 %d 회복" % heal_amount, "_complete_event_and_return", self)
			return
		"upgrade_card":
			main.pending_return_screen = "event_complete_upgrade"
			main._show_upgrade_card_screen()
			return
		"max_hp_trade":
			main.current_run["max_hp"] = int(main.current_run.get("max_hp", 50)) + 5
			main.current_run["hp"] = max(1, int(main.current_run.get("hp", 1)) - 10)
			main._show_message("마법의 샘: 최대 체력 +5, 현재 체력 -10", "_complete_event_and_return", self)
			return
		"gain_equipment":
			var gain_id := String(main._roll_card_choice_filtered("equipment", ""))
			if gain_id.is_empty():
				_complete_event_and_return()
				return
			(main.current_run.get("deck_ids", []) as Array).append(gain_id)
			main._show_message("전쟁터의 잔해: %s 획득" % String(main.cards_by_id[gain_id].get("name", "")), "_complete_event_and_return", self)
			return
		"gain_human":
			var gain_human_id := String(main._roll_card_choice_filtered("", "인간"))
			if gain_human_id.is_empty():
				_complete_event_and_return()
				return
			(main.current_run.get("deck_ids", []) as Array).append(gain_human_id)
			main._show_message("전쟁터의 잔해: %s 획득" % String(main.cards_by_id[gain_human_id].get("name", "")), "_complete_event_and_return", self)
			return
		"gain_undead":
			var gain_undead_id := String(main._roll_card_choice_filtered("", "언데드"))
			if gain_undead_id.is_empty():
				_complete_event_and_return()
				return
			(main.current_run.get("deck_ids", []) as Array).append(gain_undead_id)
			main._show_message("전쟁터의 잔해: %s 획득" % String(main.cards_by_id[gain_undead_id].get("name", "")), "_complete_event_and_return", self)
			return
		"gain_random_card":
			var gain_id := String(main._roll_card_choices(1)[0])
			(main.current_run.get("deck_ids", []) as Array).append(gain_id)
			main._show_message("전쟁터: %s 획득" % String(main.cards_by_id[gain_id].get("name", "")), "_complete_event_and_return", self)
			return
		_:
			_complete_event_and_return()

func _complete_event_and_return() -> void:
	main.current_run["pending_event"] = {}
	main.run_store.mark_node_cleared(main.current_run)
	main.run_store.advance_after_node(main.current_run)
	main._save_run()
	main._show_map()
