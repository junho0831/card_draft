extends RefCounted
class_name BattleObjectiveService

const OBJECTIVE_IDS := ["use_power", "combo", "untouched"]


func create_objective(seed_value: int, battle_tier: String, first_battle: bool = false) -> Dictionary:
	var objective_id := "use_power" if first_battle else String(OBJECTIVE_IDS[posmod(seed_value, OBJECTIVE_IDS.size())])
	var reward_gold := 15 if battle_tier == "boss" else 10
	match objective_id:
		"combo":
			return _objective(objective_id, "연계 점화", "같은 빌드 카드로 2연계를 달성하세요.", 2, reward_gold)
		"untouched":
			return _objective(objective_id, "완벽 방어", "영웅 피해 없이 승리하세요.", 1, reward_gold)
		_:
			return _objective("use_power", "세력의 힘", "이번 전투에서 필살기를 사용하세요.", 1, reward_gold)


func record_event(objective: Dictionary, event_name: String, amount: int = 1) -> bool:
	if objective.is_empty() or bool(objective.get("completed", false)):
		return false
	var was_completed := bool(objective.get("completed", false))
	match String(objective.get("id", "")):
		"use_power":
			if event_name == "race_power":
				objective["progress"] = 1
		"combo":
			if event_name == "combo":
				objective["progress"] = maxi(int(objective.get("progress", 0)), amount)
		"untouched":
			if event_name == "hero_damage" and amount > 0:
				objective["failed"] = true
	objective["completed"] = not bool(objective.get("failed", false)) and int(objective.get("progress", 0)) >= int(objective.get("target", 1))
	return not was_completed and bool(objective.get("completed", false))


func resolve_victory(objective: Dictionary) -> bool:
	if objective.is_empty():
		return false
	if String(objective.get("id", "")) == "untouched" and not bool(objective.get("failed", false)):
		objective["progress"] = 1
		objective["completed"] = true
	return bool(objective.get("completed", false))


func status_text(objective: Dictionary) -> String:
	if objective.is_empty():
		return ""
	var reward_gold := int(objective.get("reward_gold", 0))
	if bool(objective.get("completed", false)):
		return "도전 달성 · +%dG" % reward_gold
	if bool(objective.get("failed", false)):
		return "도전 종료 · 다음 전투에 재도전"
	var progress := int(objective.get("progress", 0))
	var target := int(objective.get("target", 1))
	match String(objective.get("id", "")):
		"combo":
			return "도전 · 2연계 %d/%d · +%dG" % [progress, target, reward_gold]
		"untouched":
			return "도전 · 영웅 피해 0 유지 · +%dG" % reward_gold
		_:
			return "도전 · 필살기 %d/%d · +%dG" % [progress, target, reward_gold]


func _objective(objective_id: String, title: String, description: String, target: int, reward_gold: int) -> Dictionary:
	return {
		"id": objective_id,
		"title": title,
		"description": description,
		"target": target,
		"progress": 0,
		"reward_gold": reward_gold,
		"completed": false,
		"failed": false,
		"reward_claimed": false,
	}
