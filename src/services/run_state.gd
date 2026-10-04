extends RefCounted
class_name RunState

const RewardEconomy = preload("res://src/services/reward_economy.gd")

func load_or_empty(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		return {}
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var run_data: Dictionary = (json.data as Dictionary).duplicate(true)
	if run_data.is_empty():
		return {}
	if not run_data.has("reward_offer_history"):
		run_data["reward_offer_history"] = []
	# 복원된 제안은 다시 생성하거나 과거 기록에 추가하지 않습니다.
	var pending: Dictionary = run_data.get("pending_card_reward", {})
	if not pending.is_empty():
		pending["offer_history_recorded"] = true
	return run_data

func has_saved_run(path: String) -> bool:
	return not load_or_empty(path).is_empty()

func create_new_run(acts: Array[Dictionary], deck_ids: Array[String], start_hp: int = 50, start_gold: int = 100, race_id: String = "human") -> Dictionary:
	return {
		"seed": randi(),
		"run_id": "%d-%d-%d" % [int(Time.get_unix_time_from_system() * 1000000.0), Time.get_ticks_usec(), randi()],
		"race_id": race_id if race_id in ["human", "elf", "undead"] else "human",
		"act": 1,
		"current_node_index": 0,
		"max_hp": start_hp,
		"hp": start_hp,
		"gold": start_gold,
		"gold_earned": 0,
		"enemies_defeated": 0,
		"started_at": Time.get_unix_time_from_system(),
		"finished_at": 0,
		"deck_ids": deck_ids.duplicate(),
		"relic_ids": [],
		"map_nodes": acts.duplicate(true),
		"visited_nodes": [],
		"cleared_node_types": {},
		"pending_shop": {},
		"reward_offer_history": [],
		"pending_event": {},
		"pending_message": {},
		"pending_subscreen": {},
		"active_enemy": {},
		"battle_snapshot": {},
		"result": "",
	}

func save(path: String, run_data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("런 저장 실패: %s" % path)
		return
	# 생성 직후 저장되는 최종 보상만 기록합니다. 보스의 임시 추첨은 제외합니다.
	RewardEconomy.record_pending(run_data)
	file.store_string(JSON.stringify(run_data, "\t"))

func clear(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func mark_node_cleared(run_data: Dictionary) -> void:
	var key := _node_key(int(run_data.get("act", 1)), int(run_data.get("current_node_index", 0)))
	var visited: Array = run_data.get("visited_nodes", [])
	if not visited.has(key):
		visited.append(key)
	run_data["visited_nodes"] = visited
	var cleared_types: Dictionary = run_data.get("cleared_node_types", {})
	if not cleared_types.has(key):
		cleared_types[key] = String(current_node(run_data).get("type", ""))
	run_data["cleared_node_types"] = cleared_types

func advance_after_node(run_data: Dictionary) -> void:
	var current_act := int(run_data.get("act", 1))
	var current_node_index := int(run_data.get("current_node_index", 0))
	var acts: Array = run_data.get("map_nodes", [])
	if current_act < 1 or current_act > acts.size():
		return
	var act: Dictionary = acts[current_act - 1]
	var nodes: Array = act.get("nodes", [])
	if current_node_index >= nodes.size() - 1:
		if current_act >= acts.size():
			run_data["result"] = "win"
		else:
			run_data["act"] = current_act + 1
			run_data["current_node_index"] = 0
	else:
		run_data["current_node_index"] = current_node_index + 1
	run_data["current_path_index"] = 0

func current_node(run_data: Dictionary) -> Dictionary:
	var current_act := int(run_data.get("act", 1))
	var current_node_index := int(run_data.get("current_node_index", 0))
	var current_path_index := int(run_data.get("current_path_index", 0))
	var acts: Array = run_data.get("map_nodes", [])
	if current_act < 1 or current_act > acts.size():
		return {}
	var act: Dictionary = acts[current_act - 1]
	var nodes: Variant = act.get("nodes", [])
	if typeof(nodes) != TYPE_ARRAY or current_node_index < 0 or current_node_index >= nodes.size():
		return {}
	
	var layer: Variant = nodes[current_node_index]
	var node_type: String = "unknown"
	if typeof(layer) == TYPE_ARRAY:
		if layer.is_empty():
			return {}
		if current_path_index >= 0 and current_path_index < layer.size():
			node_type = String(layer[current_path_index])
		else:
			node_type = String(layer[0])
	else:
		node_type = String(layer)

	return {
		"act": current_act,
		"index": current_node_index,
		"type": node_type,
	}

func _node_key(act: int, node_index: int) -> String:
	return "%d:%d" % [act, node_index]
