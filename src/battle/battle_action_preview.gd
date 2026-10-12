extends RefCounted

# Read-only battle forecasts shared by card hover, target comparison and guidance.
# Context is supplied per call and never retained: player, opponent, battle_state,
# run_data, momentum, relic_service, calculate_damage and card_effect_summary.
# Damage calculation stays shared with resolution; forecasts must not consume
# relics, invoke presentation callbacks or advance gameplay RNG.

static func attack_payoff_text(attacker: Dictionary, target_index: int, context: Dictionary) -> String:
	var player: Dictionary = context.player
	var opponent: Dictionary = context.opponent
	if target_index < 0 or target_index >= opponent.field.size():
		return "전장 정리"
	var prediction := predict_unit_attack(attacker, opponent.field[target_index], player, opponent, context)
	if not bool(prediction.get("lethal", false)):
		return "피해 %d · 반격 %d" % [int(prediction.get("damage", 0)), int(prediction.get("counter", 0))]
	var overflow := int(prediction.get("overflow", 0))
	if overflow > 0:
		return "처치 · 영웅 돌파 %d" % overflow
	if int(prediction.get("mana_gain", 0)) > 0:
		return "처치 · 마나 +1"
	return "처치 후 영웅 압박"


static func predict_unit_attack(attacker: Dictionary, defender: Dictionary, attacker_side: Dictionary, defender_side: Dictionary, context: Dictionary) -> Dictionary:
	var player: Dictionary = context.player
	var opponent: Dictionary = context.opponent
	var battle_state: Dictionary = context.battle_state
	if attacker.is_empty() or defender.is_empty():
		return {}
	var attack_damage = int(context.calculate_damage.call(attacker, false, attacker_side, int(attacker.get("attack", 0))))
	var counter_damage = int(context.calculate_damage.call(defender, false, defender_side, int(defender.get("attack", 0))))
	var defender_health := int(defender.get("health", 0))
	var lethal = defender_health - attack_damage <= 0
	var momentum_preview: Dictionary = context.momentum.preview(
		attack_damage,
		defender_health,
		battle_state,
		attacker_side == player and defender_side == opponent
	)
	if lethal:
		counter_damage = 0
	return {
		"damage": attack_damage,
		"counter": counter_damage,
		"attacker_health": maxi(0, int(attacker.get("health", 0)) - counter_damage),
		"defender_health": maxi(0, defender_health - attack_damage),
		"lethal": lethal,
		"overflow": int(momentum_preview.get("overflow", 0)),
		"mana_gain": int(momentum_preview.get("mana_gain", 0)),
	}


static func predict_hero_attack_damage(attacker: Dictionary, attacker_side: Dictionary, target_is_player: bool, context: Dictionary) -> int:
	var battle_state: Dictionary = context.battle_state
	if attacker.is_empty():
		return 0
	var damage = int(context.calculate_damage.call(attacker, false, attacker_side, int(attacker.get("attack", 0))))
	# Mitigation can consume a shield and invoke live presentation callbacks.
	var preview_state := battle_state.duplicate(true)
	preview_state.erase("log")
	preview_state.erase("relic_trigger")
	damage = context.relic_service.mitigate_hero_damage(context.run_data, preview_state, damage, target_is_player)
	return damage


static func attack_prediction_text(prediction: Dictionary) -> String:
	if prediction.is_empty():
		return ""
	var parts: Array[String] = []
	if bool(prediction.get("lethal", false)):
		parts.append("처치")
		var overflow := int(prediction.get("overflow", 0))
		if overflow > 0:
			parts.append("돌파 %d" % overflow)
		if int(prediction.get("mana_gain", 0)) > 0:
			parts.append("마나 +%d" % int(prediction.mana_gain))
	else:
		parts.append("피해 %d" % int(prediction.get("damage", 0)))
	if int(prediction.get("counter", 0)) > 0:
		parts.append("반격 %d" % int(prediction.get("counter", 0)))
	return " · ".join(parts)


static func frontline_damage_prediction_text(damage: int, context: Dictionary) -> String:
	var opponent: Dictionary = context.opponent
	var battle_state: Dictionary = context.battle_state
	if opponent.field.is_empty():
		return "영웅 피해 %d" % damage
	var target_health := int(Dictionary(opponent.field[0]).get("health", 0))
	var prediction: Dictionary = context.momentum.preview(damage, target_health, battle_state, true)
	prediction["damage"] = damage
	prediction["counter"] = 0
	return attack_prediction_text(prediction)


static func card_heal_preview(card: Dictionary) -> int:
	for effect in card.get("effects", []):
		if effect.op == "heal": return int(effect.amount)
	var card_id = String(card.get("id", "")).trim_suffix("_plus")
	match card_id:
		"first_aid":
			return 3 + int(card.get("effect_bonus", 0))
		"healing_potion":
			return 5
		"vampiric_strike":
			return 2
		"moonwell":
			return 4
	return 0


static func direct_damage_preview(card: Dictionary, context: Dictionary) -> int:
	var player: Dictionary = context.player
	var battle_state: Dictionary = context.battle_state
	var prospective_count: int = int(battle_state.get("cards_played_this_turn", 0)) + 1
	for effect in card.get("effects", []):
		if effect.op in ["front_damage", "all_damage", "combo_damage", "low_damage"]:
			var amount := int(effect.amount)
			if effect.op == "combo_damage" and int(battle_state.get("cards_played_this_turn", 0)) + 1 >= 3: amount = int(effect.extra)
			if effect.op == "low_damage" and int(player.health) * 2 <= int(player.max_health): amount = int(effect.extra)
			return int(context.calculate_damage.call(card, card.get("type") == "spell", player, amount, prospective_count))
	var card_id = String(card.get("id", "")).trim_suffix("_plus")
	var base_damage = 0
	match card_id:
		"small_flame", "funeral_fog", "vampiric_strike":
			base_damage = 2
		"fireball":
			base_damage = 4
		"gale_shot":
			base_damage = 4 if int(battle_state.get("cards_played_this_turn", 0)) + 1 >= 3 else 1
		"corpse_explosion":
			base_damage = 2
		"plague_spread":
			base_damage = 1
	if base_damage <= 0:
		return 0
	return int(context.calculate_damage.call(card, true, player, base_damage + int(card.get("effect_bonus", 0)), prospective_count))


static func card_result_preview(card: Dictionary, context: Dictionary) -> String:
	if card.has("effects"):
		return ("소환 %d/%d · " % [int(card.attack), int(card.health)] if card.type == "unit" else "") + String(card.text)
	if int(card.get("effect_bonus", 0)) > 0:
		return String(card.get("text", ""))
	var default_summary: String = String(context.card_effect_summary.call(card))
	var card_type = String(card.get("type", ""))
	var card_id = String(card.get("id", "")).trim_suffix("_plus")
	var parts: Array[String] = []
	if card_type == "unit":
		parts.append("소환 %d/%d" % [int(card.get("attack", 0)), int(card.get("health", 0))])
		match card_id:
			"militia":
				parts.append(frontline_damage_prediction_text(1, context))
			"trainee_swordsman":
				parts.append("체력 +1")
			"forest_archer":
				parts.append("드로우 +1")
			"knight_spearman":
				parts.append("선봉 공격 +1")
			"thief":
				parts.append("내 HP -1")
			"bone_oracle":
				parts.append("저주 +1")
			"ritual_sapling":
				parts.append("의식 +1")
			"stone_golem":
				parts.append("회복 +2")
		return " · ".join(parts.slice(0, 2))
	if card_type == "equipment":
		return default_summary
	var damage = direct_damage_preview(card, context)
	if damage > 0:
		if card_id == "corpse_explosion":
			parts.append("광역 피해 %d" % damage)
		elif card_id == "plague_spread":
			parts.append("전체 피해 %d" % damage)
		else:
			parts.append(frontline_damage_prediction_text(damage, context))
	var heal = card_heal_preview(card)
	if heal > 0:
		parts.append("영웅 회복 %d" % heal)
		if card_id == "first_aid":
			parts.append("앞 아군 체력 +1")
	if card_id in ["elven_insight", "dark_bargain"]:
		parts.append("드로우 +2")
	if card_id in ["royal_support", "soul_shackle", "nature_communion", "ancient_oath"]:
		parts.append("드로우 +1")
	if card_id == "battlecry":
		parts.append("아군 강화")
	if card_id == "captain_order":
		parts.append("아군 강화")
	if card_id == "nature_blessing":
		parts.append("아군 강화")
	if card_id == "call_of_dead":
		parts.append("소환 1/1 x2")
	if card_id in ["death_mark", "bone_oracle", "funeral_fog"]:
		parts.append("저주 +1")
	if card_id in ["soul_shackle", "plague_spread"]:
		parts.append("저주 +2")
	if card_id in ["world_tree_ritual", "nature_communion"]:
		parts.append("의식 +1")
	if card_id == "ancient_oath":
		parts.append("의식 +2")
	if card_id == "corpse_explosion":
		parts.append("아군 희생")
	if parts.is_empty():
		parts.append(default_summary)
	return " · ".join(parts.slice(0, 2))
