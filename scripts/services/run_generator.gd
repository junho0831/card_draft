extends RefCounted
class_name RunGenerator

const ACTS_PATH := "res://data/acts.json"

func load_acts() -> Array[Dictionary]:
	var json_text := FileAccess.get_file_as_string(ACTS_PATH)
	if json_text.is_empty():
		return []
	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_ARRAY:
		return []
	var acts: Array[Dictionary] = []
	for raw_act in parsed:
		if typeof(raw_act) == TYPE_DICTIONARY:
			acts.append((raw_act as Dictionary).duplicate(true))
	return acts

func starter_deck(race_id: String = "") -> Array[String]:
	if race_id == "elf":
		return [
			"elf_ranger", "elf_ranger", "elf_ranger",
			"forest_archer", "forest_archer", "forest_archer",
			"elven_insight", "elven_insight",
			"nature_blessing", "nature_communion",
		]
	if race_id == "undead":
		return [
			"bone_soldier", "bone_soldier", "bone_soldier",
			"grave_knight", "grave_knight", "grave_knight",
			"dark_bargain", "dark_bargain",
			"call_of_dead", "plague_spread",
		]
	
	# Default (Human or empty)
	return [
		"militia", "militia", "militia",
		"trainee_swordsman", "trainee_swordsman", "trainee_swordsman",
		"small_flame", "small_flame",
		"first_aid", "first_aid",
	]

func get_starting_relic(race_id: String) -> String:
	match race_id:
		"human": return "knight_banner"
		"elf": return "world_tree_leaf"
		"undead": return "necromancer_ring"
		_: return ""

func create_map_nodes(acts: Array[Dictionary]) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	for act_index in range(acts.size()):
		var act: Dictionary = acts[act_index]
		var raw_nodes: Variant = act.get("nodes", [])
		if typeof(raw_nodes) != TYPE_ARRAY:
			continue
		for node_index in range(raw_nodes.size()):
			nodes.append({
				"act": act_index + 1,
				"index": node_index,
				"type": String(raw_nodes[node_index]),
				"label": _node_label(String(raw_nodes[node_index])),
			})
	return nodes

func _node_label(node_type: String) -> String:
	match node_type:
		"battle":
			return "일반전투"
		"elite":
			return "엘리트"
		"event":
			return "이벤트"
		"shop":
			return "상점"
		"rest":
			return "휴식"
		"boss":
			return "보스"
		_:
			return node_type
