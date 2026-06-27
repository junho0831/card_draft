extends RefCounted
class_name RelicService

const RELICS_PATH := "res://data/relics.json"

var relics: Array[Dictionary] = []
var relics_by_id := {}

func load_relics() -> bool:
	var json_text := FileAccess.get_file_as_string(RELICS_PATH)
	if json_text.is_empty():
		return false
	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_ARRAY:
		return false
	relics.clear()
	relics_by_id.clear()
	for raw_relic in parsed:
		if typeof(raw_relic) != TYPE_DICTIONARY:
			continue
		var relic: Dictionary = (raw_relic as Dictionary).duplicate(true)
		relics.append(relic)
		relics_by_id[String(relic.get("id", ""))] = relic
	return not relics.is_empty()

func get_relic(id: String) -> Dictionary:
	if relics_by_id.has(id):
		return relics_by_id[id].duplicate(true)
	return {}

func random_relic(excluded_ids: Array) -> Dictionary:
	var pool: Array[Dictionary] = []
	for relic in relics:
		var id := String(relic.get("id", ""))
		if excluded_ids.has(id):
			continue
		pool.append(relic)
	if pool.is_empty():
		return {}
	return pool[randi() % pool.size()].duplicate(true)

func apply_on_acquire(run_data: Dictionary, relic_id: String) -> void:
	if relic_id == "cursed_crown":
		run_data["max_hp"] = int(run_data.get("max_hp", 50)) + 15
		run_data["hp"] = int(run_data.get("hp", 50)) + 15

func on_battle_start(run_data: Dictionary, player_state: Dictionary, battle_state: Dictionary) -> void:
	var relic_ids: Array = run_data.get("relic_ids", [])
	battle_state["holy_shield_ready"] = relic_ids.has("holy_shield")
	if relic_ids.has("mana_crystal"):
		battle_state["mana_crystal_bonus"] = true
	if relic_ids.has("cursed_crown"):
		run_data["hp"] = max(1, int(run_data.get("hp", 1)) - 3)
		player_state["health"] = int(run_data["hp"])
	if relic_ids.has("tactical_manual"):
		battle_state["first_card_discount_available"] = true
	if relic_ids.has("war_drum"):
		var draw_cards: Callable = battle_state.get("draw_cards", Callable())
		if draw_cards.is_valid():
			draw_cards.call(player_state, 1)
		player_state["mana"] = int(player_state.get("mana", 0)) + 1
		player_state["max_mana"] = int(player_state.get("max_mana", 0)) + 1
		var log: Callable = battle_state.get("log", Callable())
		if log.is_valid():
			log.call("전장의 북 효과: 카드 1장 드로우, 마나 +1")

func on_turn_start(run_data: Dictionary, battle_state: Dictionary, player_state: Dictionary) -> void:
	var relic_ids: Array = run_data.get("relic_ids", [])
	battle_state["first_card_discount_available"] = relic_ids.has("tactical_manual")
	if relic_ids.has("world_tree_leaf"):
		var draw_cards: Callable = battle_state.get("draw_cards", Callable())
		if draw_cards.is_valid():
			draw_cards.call(player_state, 1)
		var log: Callable = battle_state.get("log", Callable())
		if log.is_valid():
			log.call("세계수 잎 효과: 카드 1장 추가 드로우")
	if relic_ids.has("gladiator_helm") and player_state.field.size() >= 3 and not player_state.field.is_empty():
		player_state.field[0]["attack"] = int(player_state.field[0].get("attack", 0)) + 1
		var log: Callable = battle_state.get("log", Callable())
		if log.is_valid():
			log.call("검투사 투구 효과: 가장 앞의 아군 공격력 +1")

func modify_card_cost(run_data: Dictionary, battle_state: Dictionary, card: Dictionary, owner_name: String) -> int:
	var cost := int(card.get("cost", 0))
	var relic_ids: Array = run_data.get("relic_ids", [])
	if owner_name != "player":
		return cost
	if relic_ids.has("dark_heart") and String(card.get("id", "")) in ["dark_bargain", "dark_bargain_plus", "thief", "thief_plus"]:
		cost -= 1
	if bool(battle_state.get("first_card_discount_available", false)):
		cost -= 1
	return max(0, cost)

func consume_card_discount(battle_state: Dictionary) -> void:
	if bool(battle_state.get("first_card_discount_available", false)):
		battle_state["first_card_discount_available"] = false

func on_unit_summoned(run_data: Dictionary, unit: Dictionary) -> void:
	var relic_ids: Array = run_data.get("relic_ids", [])
	if relic_ids.has("knight_banner"):
		unit["attack"] = int(unit.get("attack", 0)) + 1

func damage_bonus(run_data: Dictionary, source: Dictionary, is_spell: bool, owner_state: Dictionary) -> int:
	var relic_ids: Array = run_data.get("relic_ids", [])
	var bonus := 0
	if relic_ids.has("burning_heart") and String(source.get("attr", "")) == "화염":
		bonus += 2
	return bonus

func on_ally_unit_died(run_data: Dictionary, battle_state: Dictionary, dead_unit: Dictionary) -> void:
	var relic_ids: Array = run_data.get("relic_ids", [])
	if relic_ids.has("book_of_death"):
		var draw_cards: Callable = battle_state.get("draw_cards", Callable())
		if draw_cards.is_valid():
			draw_cards.call(battle_state.get("player_state", {}), 1)
		var log: Callable = battle_state.get("log", Callable())
		if log.is_valid():
			log.call("죽음의 서 효과: 카드 1장 드로우")
	if relic_ids.has("necromancer_ring") and not bool(battle_state.get("necromancer_ring_used", false)):
		var player_state: Dictionary = battle_state.get("player_state", {})
		if player_state.field.size() < 5:
			player_state.field.append({
				"id": "bone_soldier",
				"name": "해골 병사",
				"race": "언데드",
				"attr": "암흑",
				"attack": 1,
				"health": 1,
				"max_health": 1,
				"art": 2,
				"art_id": "bone_soldier",
				"can_attack": false,
			})
			battle_state["necromancer_ring_used"] = true
			if log.is_valid():
				log.call("사령술사의 반지 효과: 1/1 해골 부활")

func on_card_played(run_data: Dictionary, battle_state: Dictionary, player_state: Dictionary) -> void:
	var relic_ids: Array = run_data.get("relic_ids", [])
	if relic_ids.has("wind_feather") and int(battle_state.get("cards_played_this_turn", 0)) == 3:
		var draw_cards: Callable = battle_state.get("draw_cards", Callable())
		if draw_cards.is_valid():
			draw_cards.call(player_state, 1)
		var log: Callable = battle_state.get("log", Callable())
		if log.is_valid():
			log.call("바람의 깃털 효과: 카드 1장 드로우")

func on_hero_hp_lost(run_data: Dictionary, battle_state: Dictionary, owner_state: Dictionary, amount: int) -> void:
	if amount <= 0:
		return
	var relic_ids: Array = run_data.get("relic_ids", [])
	if relic_ids.has("blood_chalice") and not owner_state.field.is_empty():
		owner_state.field[0]["attack"] = int(owner_state.field[0].get("attack", 0)) + 1
		var log: Callable = battle_state.get("log", Callable())
		if log.is_valid():
			log.call("피의 성배 효과: 가장 앞의 아군 공격력 +1")

func mitigate_hero_damage(run_data: Dictionary, battle_state: Dictionary, amount: int, is_player_hero: bool) -> int:
	if not is_player_hero:
		return amount
	var relic_ids: Array = run_data.get("relic_ids", [])
	if relic_ids.has("holy_shield") and bool(battle_state.get("holy_shield_ready", false)):
		battle_state["holy_shield_ready"] = false
		var log: Callable = battle_state.get("log", Callable())
		if log.is_valid():
			log.call("성스러운 방패 효과: 첫 영웅 피해를 막았습니다.")
		return 0
	return amount

func victory_gold_bonus(run_data: Dictionary) -> int:
	var relic_ids: Array = run_data.get("relic_ids", [])
	if relic_ids.has("alchemy_bag"):
		return 10
	return 0
