extends RefCounted
class_name EnemyService

const ENEMIES_PATH := "res://data/enemies.json"

var enemies: Array[Dictionary] = []

func load_enemies() -> bool:
	var json_text := FileAccess.get_file_as_string(ENEMIES_PATH)
	if json_text.is_empty():
		return false
	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_ARRAY:
		return false
	enemies.clear()
	for raw_enemy in parsed:
		if typeof(raw_enemy) == TYPE_DICTIONARY:
			enemies.append((raw_enemy as Dictionary).duplicate(true))
	return not enemies.is_empty()

func pick_enemy(act: int, tier: String) -> Dictionary:
	var pool: Array[Dictionary] = []
	for enemy in enemies:
		if String(enemy.get("tier", "")) != tier:
			continue
		var act_pool: Variant = enemy.get("act_pool", [])
		if typeof(act_pool) != TYPE_ARRAY:
			continue
		if not act_pool.has(act):
			continue
		pool.append(enemy)
	if pool.is_empty():
		for enemy in enemies:
			if String(enemy.get("tier", "")) == tier:
				pool.append(enemy)
	if pool.is_empty() and tier != "normal":
		for enemy in enemies:
			if String(enemy.get("tier", "")) == "normal":
				pool.append(enemy)
	if pool.is_empty():
		return {}
	return pool[randi() % pool.size()].duplicate(true)

func enemy_by_id(enemy_id: String) -> Dictionary:
	for enemy in enemies:
		if String(enemy.get("id", "")) == enemy_id:
			return enemy.duplicate(true)
	return {}
