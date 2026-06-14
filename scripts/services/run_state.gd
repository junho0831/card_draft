extends RefCounted
class_name RunState

func load_or_empty(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		return {}
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return (json.data as Dictionary).duplicate(true)

func has_saved_run(path: String) -> bool:
	return not load_or_empty(path).is_empty()

func create_new_run(acts: Array[Dictionary], deck_ids: Array[String], start_hp: int = 50, start_gold: int = 100) -> Dictionary:
	return {
		"seed": randi(),
		"act": 1,
		"current_node_index": 0,
		"max_hp": start_hp,
		"hp": start_hp,
		"gold": start_gold,
		"deck_ids": deck_ids.duplicate(),
		"relic_ids": [],
		"map_nodes": acts.duplicate(true),
		"visited_nodes": [],
		"pending_shop": {},
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

func current_node(run_data: Dictionary) -> Dictionary:
	var current_act := int(run_data.get("act", 1))
	var current_node_index := int(run_data.get("current_node_index", 0))
	var acts: Array = run_data.get("map_nodes", [])
	if current_act < 1 or current_act > acts.size():
		return {}
	var act: Dictionary = acts[current_act - 1]
	var nodes: Variant = act.get("nodes", [])
	if typeof(nodes) != TYPE_ARRAY or current_node_index < 0 or current_node_index >= nodes.size():
		return {}
	return {
		"act": current_act,
		"index": current_node_index,
		"type": String(nodes[current_node_index]),
	}

func _node_key(act: int, node_index: int) -> String:
	return "%d:%d" % [act, node_index]
