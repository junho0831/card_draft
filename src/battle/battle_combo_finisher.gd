extends RefCounted
class_name BattleComboFinisher

const THRESHOLD := 3
const MAX_FIELD := 5
const VALID_TAGS := ["fire", "draw", "death", "buff", "low_hp", "summon"]

func try_resolve(tag: String, streak: int, battle_state: Dictionary, owner: Dictionary, enemy: Dictionary, context: Dictionary) -> Dictionary:
	if streak < THRESHOLD or bool(battle_state.get("combo_finisher_used", false)) or not VALID_TAGS.has(tag):
		return {}
	battle_state["combo_finisher_used"] = true
	battle_state["combo_finisher_tag"] = tag
	var result := {"tag": tag, "target": "player", "headline": "연계 피니시", "detail": ""}
	match tag:
		"fire":
			for unit in enemy.get("field", []):
				unit["health"] = int(unit.get("health", 0)) - 2
			enemy["health"] = int(enemy.get("health", 0)) - 2
			var cleanup: Callable = context.get("cleanup_dead_units", Callable())
			if cleanup.is_valid():
				cleanup.call(owner, enemy)
			result.merge({"target": "enemy", "headline": "화염 폭풍", "detail": "적 전체와 영웅에게 피해 2"}, true)
		"draw":
			var draw_cards: Callable = context.get("draw_cards", Callable())
			if draw_cards.is_valid():
				draw_cards.call(owner, 2)
			owner["mana"] = int(owner.get("mana", 0)) + 1
			result.merge({"headline": "바람의 순환", "detail": "드로우 2 / 마나 +1"}, true)
		"death":
			enemy["health"] = int(enemy.get("health", 0)) - 3
			var summoned := _summon_token(owner, {
				"id": "finisher_skeleton_token",
				"name": "복수의 해골",
				"race": "언데드",
				"attr": "암흑",
				"attack": 1,
				"health": 1,
				"max_health": 1,
				"art": 2,
				"art_id": "bone_soldier",
				"can_attack": true,
			}, context)
			result.merge({"target": "enemy", "headline": "망자의 복수", "detail": "적 영웅 피해 3%s" % (" / 해골 소환" if summoned else "")}, true)
		"buff":
			for unit in owner.get("field", []):
				unit["attack"] = int(unit.get("attack", 0)) + 1
				unit["health"] = int(unit.get("health", 0)) + 1
				unit["max_health"] = int(unit.get("max_health", 0)) + 1
			result.merge({"target": "field", "headline": "왕국의 진군", "detail": "모든 아군 +1/+1"}, true)
		"low_hp":
			owner["health"] = min(int(owner.get("max_health", owner.get("health", 0))), int(owner.get("health", 0)) + 3)
			if not owner.get("field", []).is_empty():
				owner.field[0]["attack"] = int(owner.field[0].get("attack", 0)) + 2
				owner.field[0]["can_attack"] = true
			result.merge({"target": "field", "headline": "불굴의 반격", "detail": "영웅 회복 3 / 선봉 공격 +2"}, true)
		"summon":
			var summon_count := 0
			for i in range(2):
				if _summon_token(owner, {
					"id": "finisher_recruit_token",
					"name": "돌격 지원병",
					"race": "중립",
					"attr": "대지",
					"attack": 1,
					"health": 1,
					"max_health": 1,
					"art": 0,
					"art_id": "militia",
					"can_attack": true,
				}, context):
					summon_count += 1
			result.merge({"target": "field", "headline": "군세 폭발", "detail": "즉시 공격 지원병 %d기" % summon_count}, true)
	return result

func _summon_token(owner: Dictionary, token: Dictionary, context: Dictionary) -> bool:
	if (owner.get("field", []) as Array).size() >= MAX_FIELD:
		return false
	var relic_service = context.get("relic_service")
	if relic_service != null:
		relic_service.on_unit_summoned(context.get("run_data", {}), token, context)
	(owner.get("field", []) as Array).append(token)
	var on_unit_summoned: Callable = context.get("on_unit_summoned", Callable())
	if on_unit_summoned.is_valid():
		on_unit_summoned.call(owner, token)
	return true
