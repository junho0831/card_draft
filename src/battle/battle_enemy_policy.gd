extends RefCounted
class_name BattleEnemyPolicy

static func attack_target(attacker: Dictionary, defenders: Array, damage: int) -> int:
	var best := -1
	var best_score := -100000
	for i in range(defenders.size()):
		var unit: Dictionary = defenders[i]
		if int(unit.get("health", 0)) <= 0:
			continue
		var score := (10000 if damage >= int(unit.health) else 0) + int(unit.get("attack", 0)) * 10 - int(unit.health)
		if score > best_score:
			best = i
			best_score = score
	return best

static func card_priority(card: Dictionary, tags: Array, has_allies: bool) -> int:
	var type := String(card.get("type", ""))
	var id := String(card.get("id", "")).trim_suffix("_plus")
	var damage_card := id in ["small_flame", "fireball", "gale_shot", "funeral_fog", "vampiric_strike", "plague_spread", "death_mark", "soul_shackle", "corpse_explosion"]
	if tags.any(func(tag): return tag in ["defense", "defensive", "field_test", "spell_resist", "buff"]):
		if type == "unit":
			return 200 + int(card.get("health", 0))
		if has_allies and (type == "equipment" or id in ["captain_order", "battlecry", "nature_blessing"]):
			return 300
	elif tags.any(func(tag): return tag in ["swarm", "summon_heavy", "death", "revive"]):
		if type == "unit" or id == "call_of_dead":
			return 300 - int(card.get("cost", 0))
	elif tags.any(func(tag): return tag in ["aggressive", "direct_damage", "spell_only", "curse", "punish_combo"]):
		if damage_card:
			return 300
	return 100

static func boss_pattern(enemy: Dictionary, next_turn: int, field_size: int) -> Dictionary:
	if String(enemy.get("tier", "")) != "boss":
		return {}
	match String(enemy.get("id", "")):
		"border_guardian":
			return {"kind": "buff", "text": "선봉 공격 +1" if field_size > 0 else "선봉 없음 · 강화 불가"}
		"undead_king":
			var summon := next_turn % 3 == 0 and field_size < 3
			return {"kind": "summon" if summon else "wait", "text": "해골 지원" if summon else ("지원 공간 부족" if next_turn % 3 == 0 else "해골 지원까지 %d턴" % (3 - (next_turn % 3)))}
		"necro_lord":
			return {"kind": "curse", "text": "저주 +1"}
	return {}
