extends RefCounted
class_name EventRunService

func resolve_effect(run_data: Dictionary, effect: String, context: Dictionary) -> Dictionary:
	match effect:
		"merchant_card":
			run_data["hp"] = max(1, int(run_data.get("hp", 1)) - 5)
			run_data["pending_card_reward"] = {
				"choices": context.get("roll_high_cost_cards", Callable()).call(3),
				"bonus_relic": {},
				"battle_tier": "event",
			}
			run_data["pending_event"] = {}
			return {"action": "show_card_reward"}
		"merchant_relic":
			if int(run_data.get("gold", 0)) < 50:
				return {"action": "show_event", "message": "골드가 부족합니다."}
			var merchant_relic: Dictionary = context.get("random_relic", Callable()).call(run_data.get("relic_ids", []))
			if merchant_relic.is_empty():
				return {"action": "persisted_message", "message": "얻을 유물이 없습니다.", "callback_method": "_complete_event_and_return"}
			run_data["gold"] = int(run_data["gold"]) - 50
			var merchant_relic_id := String(merchant_relic.get("id", ""))
			(run_data.get("relic_ids", []) as Array).append(merchant_relic_id)
			context.get("apply_relic", Callable()).call(run_data, merchant_relic_id)
			return {"action": "persisted_message", "message": "수상한 상인: %s 획득" % String(merchant_relic.get("name", "")), "callback_method": "_complete_event_and_return"}
		"gamble_small":
			if int(run_data.get("gold", 0)) < 30:
				return {"action": "show_event", "message": "골드가 부족합니다."}
			run_data["gold"] = int(run_data["gold"]) - 30
			if randi() % 2 == 0:
				run_data["gold"] = int(run_data["gold"]) + 80
				return {"action": "persisted_message", "message": "도박 성공: 골드 80 획득", "callback_method": "_complete_event_and_return"}
			return {"action": "persisted_message", "message": "도박 실패: 골드를 잃었습니다.", "callback_method": "_complete_event_and_return"}
		"gamble_relic":
			if int(run_data.get("gold", 0)) < 60:
				return {"action": "show_event", "message": "골드가 부족합니다."}
			run_data["gold"] = int(run_data["gold"]) - 60
			if randi() % 10 < 3:
				var relic: Dictionary = context.get("random_relic", Callable()).call(run_data.get("relic_ids", []))
				if not relic.is_empty():
					var relic_id := String(relic.get("id", ""))
					(run_data.get("relic_ids", []) as Array).append(relic_id)
					context.get("apply_relic", Callable()).call(run_data, relic_id)
					return {"action": "persisted_message", "message": "대박: %s 획득" % String(relic.get("name", "")), "callback_method": "_complete_event_and_return"}
			return {"action": "persisted_message", "message": "도박 실패: 아무것도 얻지 못했습니다.", "callback_method": "_complete_event_and_return"}
		"remove_card":
			return {"action": "show_remove_card", "reason": "이벤트", "source": "event_complete"}
		"heal_10":
			run_data["hp"] = min(int(run_data.get("max_hp", 50)), int(run_data.get("hp", 0)) + 10)
			return {"action": "persisted_message", "message": "버려진 성당: 체력 10 회복", "callback_method": "_complete_event_and_return"}
		"curse_relic":
			run_data["max_hp"] = max(10, int(run_data.get("max_hp", 50)) - 5)
			run_data["hp"] = min(int(run_data.get("max_hp", 50)), int(run_data.get("hp", 0)))
			var curse_relic: Dictionary = context.get("random_relic", Callable()).call(run_data.get("relic_ids", []))
			if not curse_relic.is_empty():
				var curse_relic_id := String(curse_relic.get("id", ""))
				(run_data.get("relic_ids", []) as Array).append(curse_relic_id)
				context.get("apply_relic", Callable()).call(run_data, curse_relic_id)
				return {"action": "persisted_message", "message": "저주를 받고 %s 획득" % String(curse_relic.get("name", "")), "callback_method": "_complete_event_and_return"}
			return {"action": "complete_event"}
		"heal":
			var heal_amount := maxi(1, int(round(float(int(run_data.get("max_hp", 50))) * 0.3)))
			run_data["hp"] = min(int(run_data.get("max_hp", 50)), int(run_data.get("hp", 0)) + heal_amount)
			return {"action": "persisted_message", "message": "마법 샘: 체력 %d 회복" % heal_amount, "callback_method": "_complete_event_and_return"}
		"upgrade_card":
			return {"action": "show_upgrade_card", "source": "event_complete_upgrade"}
		"max_hp_trade":
			run_data["max_hp"] = int(run_data.get("max_hp", 50)) + 5
			run_data["hp"] = max(1, int(run_data.get("hp", 1)) - 10)
			return {"action": "persisted_message", "message": "마법의 샘: 최대 체력 +5, 현재 체력 -10", "callback_method": "_complete_event_and_return"}
		"gain_equipment":
			var gain_equipment_id := String(context.get("roll_card_choice_filtered", Callable()).call("equipment", ""))
			if gain_equipment_id.is_empty():
				return {"action": "complete_event"}
			(run_data.get("deck_ids", []) as Array).append(gain_equipment_id)
			return {"action": "persisted_message", "message": "전쟁터의 잔해: %s 획득" % String(context.get("card_name", Callable()).call(gain_equipment_id)), "callback_method": "_complete_event_and_return"}
		"gain_human":
			var gain_human_id := String(context.get("roll_card_choice_filtered", Callable()).call("", "인간"))
			if gain_human_id.is_empty():
				return {"action": "complete_event"}
			(run_data.get("deck_ids", []) as Array).append(gain_human_id)
			return {"action": "persisted_message", "message": "전쟁터의 잔해: %s 획득" % String(context.get("card_name", Callable()).call(gain_human_id)), "callback_method": "_complete_event_and_return"}
		"gain_undead":
			var gain_undead_id := String(context.get("roll_card_choice_filtered", Callable()).call("", "언데드"))
			if gain_undead_id.is_empty():
				return {"action": "complete_event"}
			(run_data.get("deck_ids", []) as Array).append(gain_undead_id)
			return {"action": "persisted_message", "message": "전쟁터의 잔해: %s 획득" % String(context.get("card_name", Callable()).call(gain_undead_id)), "callback_method": "_complete_event_and_return"}
		"gain_random_card":
			var choices: Array = context.get("roll_card_choices", Callable()).call(1)
			if choices.is_empty():
				return {"action": "complete_event"}
			var gain_id := String(choices[0])
			(run_data.get("deck_ids", []) as Array).append(gain_id)
			return {"action": "persisted_message", "message": "전쟁터: %s 획득" % String(context.get("card_name", Callable()).call(gain_id)), "callback_method": "_complete_event_and_return"}
		_:
			return {"action": "complete_event"}
