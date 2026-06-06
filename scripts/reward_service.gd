extends RefCounted
class_name RewardService

const SHOP_PRODUCTS := {
	"random_card": {
		"name": "랜덤 카드 1장",
		"price": 50,
		"card_count": 1,
		"race_selectable": false,
	},
	"race_card": {
		"name": "종족 카드 1장",
		"price": 80,
		"card_count": 1,
		"race_selectable": true,
	},
	"mini_pack": {
		"name": "미니 팩 3장",
		"price": 120,
		"card_count": 3,
		"race_selectable": false,
	},
}

func apply_reward(profile: Dictionary, mode: String, battle_result: String, card_defs: Array) -> Dictionary:
	var gold_delta := 0
	var rank_delta := 0
	var card_reward := ""
	var did_win := battle_result == "win"
	if mode == "ranked":
		if did_win:
			gold_delta = 20
			rank_delta = 25
			card_reward = grant_random_card(profile, card_defs)
		else:
			gold_delta = 10
			rank_delta = -10
	else:
		if did_win:
			gold_delta = 30
			card_reward = grant_random_card(profile, card_defs)
		else:
			gold_delta = 10

	profile["gold"] = int(profile["gold"]) + gold_delta
	profile["rank_points"] = max(0, int(profile["rank_points"]) + rank_delta)

	var result_text := "패배"
	if did_win:
		result_text = "승리"
	var summary := "%s %s\n골드 +%d\n" % [mode_name(mode), result_text, gold_delta]
	if mode == "ranked":
		var rank_delta_text := "%d" % rank_delta
		if rank_delta >= 0:
			rank_delta_text = "+%d" % rank_delta
		summary += "랭크 점수 %s\n" % rank_delta_text
	if not card_reward.is_empty():
		summary += "카드 획득: %s\n" % card_reward
	return {
		"profile": profile,
		"summary": summary,
	}

func grant_random_card(profile: Dictionary, card_defs: Array) -> String:
	if card_defs.is_empty():
		return ""
	var card: Dictionary = card_defs[randi() % card_defs.size()]
	var id := String(card["id"])
	profile["owned_cards"][id] = int(profile["owned_cards"].get(id, 0)) + 1
	return String(card["name"])

func shop_products() -> Array:
	return [
		_shop_product("random_card"),
		_shop_product("race_card"),
		_shop_product("mini_pack"),
	]

func buy_random_cards(profile: Dictionary, card_defs: Array, product_id: String, race_filter: String = "") -> Dictionary:
	if not SHOP_PRODUCTS.has(product_id):
		return _shop_error("알 수 없는 상품입니다.")
	if card_defs.is_empty():
		return _shop_error("구매 가능한 카드가 없습니다.")

	var product: Dictionary = SHOP_PRODUCTS[product_id]
	var price := int(product["price"])
	if int(profile.get("gold", 0)) < price:
		return _shop_error("골드가 부족합니다.")

	var pool := _shop_card_pool(card_defs, bool(product["race_selectable"]), race_filter)
	if pool.is_empty():
		return _shop_error("선택한 조건에 맞는 카드가 없습니다.")

	var gained_cards: Array = []
	for i in range(int(product["card_count"])):
		var card: Dictionary = pool[randi() % pool.size()]
		var id := String(card["id"])
		profile["owned_cards"][id] = int(profile["owned_cards"].get(id, 0)) + 1
		gained_cards.append({
			"id": id,
			"name": String(card["name"]),
		})

	profile["gold"] = int(profile["gold"]) - price
	var gained_names := []
	for card in gained_cards:
		gained_names.append(String(card["name"]))
	var summary := "%s 구매\n골드 -%d\n카드 획득: %s\n" % [String(product["name"]), price, _join_names(gained_names)]
	return {
		"ok": true,
		"profile": profile,
		"summary": summary,
		"gold_delta": -price,
		"cards": gained_cards,
	}

func rank_name(points: int) -> String:
	if points >= 2000:
		return "다이아"
	if points >= 1500:
		return "플래티넘"
	if points >= 1000:
		return "골드"
	if points >= 500:
		return "실버"
	return "브론즈"

func mode_name(mode: String) -> String:
	if mode == "ranked":
		return "랭크전"
	return "일반전"

func _shop_product(product_id: String) -> Dictionary:
	var product: Dictionary = SHOP_PRODUCTS[product_id]
	return {
		"id": product_id,
		"name": String(product["name"]),
		"price": int(product["price"]),
		"card_count": int(product["card_count"]),
		"race_selectable": bool(product["race_selectable"]),
	}

func _shop_card_pool(card_defs: Array, race_selectable: bool, race_filter: String) -> Array:
	var pool := []
	for card in card_defs:
		if race_selectable and String(card.get("race", "")) != race_filter:
			continue
		pool.append(card)
	return pool

func _shop_error(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
	}

func _join_names(names: Array) -> String:
	var text := ""
	for name in names:
		if not text.is_empty():
			text += ", "
		text += String(name)
	return text
