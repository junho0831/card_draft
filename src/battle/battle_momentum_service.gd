extends RefCounted
class_name BattleMomentumService

const MANA_CLAIMED_KEY := "breakthrough_mana_claimed"
const TRIGGER_COUNT_KEY := "breakthrough_count"
const DAMAGE_TOTAL_KEY := "breakthrough_damage"


func deploy_vanguard(side: Dictionary, preferred_card_ids: Array, card_lookup: Callable) -> Dictionary:
	if not card_lookup.is_valid():
		return {}
	for card_id_variant in preferred_card_ids:
		var card_id := String(card_id_variant)
		var card_variant = card_lookup.call(card_id)
		if typeof(card_variant) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = card_variant
		if String(card.get("type", "")) != "unit":
			continue
		var unit := {
			"id": String(card.get("id", card_id)),
			"name": String(card.get("name", "적 선봉")),
			"race": String(card.get("race", "중립")),
			"attr": String(card.get("attr", "")),
			"attack": int(card.get("attack", 0)),
			"health": int(card.get("health", 1)),
			"max_health": int(card.get("health", 1)),
			"art": int(card.get("art", 0)),
			"art_id": String(card.get("art_id", "")),
			"can_attack": false,
			"is_vanguard": true,
		}
		side.field.append(unit)
		return unit
	return {}


func reset_player_turn(state: Dictionary) -> void:
	state[MANA_CLAIMED_KEY] = false


func preview(damage: int, target_health: int, state: Dictionary, player_source: bool = true) -> Dictionary:
	var lethal := player_source and target_health > 0 and damage >= target_health
	return {
		"lethal": lethal,
		"overflow": maxi(0, damage - target_health) if lethal else 0,
		"mana_gain": 1 if lethal and not bool(state.get(MANA_CLAIMED_KEY, false)) else 0,
	}


func resolve(
	attacker_side: Dictionary,
	defender_side: Dictionary,
	damage: int,
	target_health: int,
	state: Dictionary,
	player_source: bool = true
) -> Dictionary:
	var result := preview(damage, target_health, state, player_source)
	if not bool(result.get("lethal", false)):
		return result

	var overflow := int(result.get("overflow", 0))
	var mana_gain := int(result.get("mana_gain", 0))
	if overflow > 0:
		defender_side["health"] = int(defender_side.get("health", 0)) - overflow
	if mana_gain > 0:
		attacker_side["mana"] = int(attacker_side.get("mana", 0)) + mana_gain
		state[MANA_CLAIMED_KEY] = true

	state[TRIGGER_COUNT_KEY] = int(state.get(TRIGGER_COUNT_KEY, 0)) + 1
	state[DAMAGE_TOTAL_KEY] = int(state.get(DAMAGE_TOTAL_KEY, 0)) + overflow
	return result
