extends RefCounted
class_name ShopRunService

const SHOP_CARD_COST := 40
const SHOP_RELIC_COST := 125
const SHOP_HEAL_COST := 60

func generate_shop_state(context: Dictionary) -> Dictionary:
	return {
		"cards": context.get("roll_card_choices", Callable()).call(3),
		"relic": context.get("random_relic", Callable()).call(context.get("relic_ids", [])),
		"purchased_cards": [],
		"relic_bought": false,
		"remove_count": 0,
	}

func remove_cost(shop_state: Dictionary) -> int:
	return 50 + int(shop_state.get("remove_count", 0)) * 25

func buy_card(run_data: Dictionary, card_id: String) -> Dictionary:
	var shop_state: Dictionary = run_data.get("pending_shop", {})
	var offered_cards: Array = shop_state.get("cards", [])
	var purchased_cards: Array = shop_state.get("purchased_cards", [])
	if not offered_cards.has(card_id) or purchased_cards.has(card_id):
		return {"ok": false}
	if int(run_data.get("gold", 0)) < SHOP_CARD_COST:
		return {"ok": false}
	run_data["gold"] = int(run_data["gold"]) - SHOP_CARD_COST
	(run_data.get("deck_ids", []) as Array).append(card_id)
	purchased_cards.append(card_id)
	shop_state["purchased_cards"] = purchased_cards
	run_data["pending_shop"] = shop_state
	return {"ok": true}

func buy_relic(run_data: Dictionary, apply_relic: Callable) -> Dictionary:
	var shop_state: Dictionary = run_data.get("pending_shop", {})
	var relic: Dictionary = shop_state.get("relic", {})
	if bool(shop_state.get("relic_bought", false)) or relic.is_empty() or int(run_data.get("gold", 0)) < SHOP_RELIC_COST:
		return {"ok": false}
	run_data["gold"] = int(run_data["gold"]) - SHOP_RELIC_COST
	var relic_id := String(relic.get("id", ""))
	(run_data.get("relic_ids", []) as Array).append(relic_id)
	apply_relic.call(run_data, relic_id)
	shop_state["relic_bought"] = true
	run_data["pending_shop"] = shop_state
	return {"ok": true}

func begin_remove(run_data: Dictionary) -> Dictionary:
	var shop_state: Dictionary = run_data.get("pending_shop", {})
	if int(run_data.get("gold", 0)) < remove_cost(shop_state):
		return {"ok": false}
	return {"ok": true, "reason": "상점", "source": "shop"}

func confirm_remove(run_data: Dictionary) -> Dictionary:
	var shop_state: Dictionary = run_data.get("pending_shop", {})
	var cost := remove_cost(shop_state)
	if int(run_data.get("gold", 0)) < cost:
		return {"ok": false}
	run_data["gold"] = int(run_data["gold"]) - cost
	shop_state["remove_count"] = int(shop_state.get("remove_count", 0)) + 1
	run_data["pending_shop"] = shop_state
	return {"ok": true}

func buy_heal(run_data: Dictionary) -> Dictionary:
	if int(run_data.get("gold", 0)) < SHOP_HEAL_COST:
		return {"ok": false}
	var max_hp := int(run_data.get("max_hp", 50))
	if int(run_data.get("hp", 0)) >= max_hp:
		return {"ok": false}
	run_data["gold"] = int(run_data["gold"]) - SHOP_HEAL_COST
	run_data["hp"] = min(max_hp, int(run_data.get("hp", 0)) + 20)
	return {"ok": true}

func leave_shop(run_data: Dictionary) -> void:
	run_data["pending_shop"] = {}
