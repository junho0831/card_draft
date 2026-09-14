extends RefCounted
## Save-format normalization only. Never mutates live battle data.
const SIDE_DEFAULTS := {
	"name": "", "health": 0, "max_health": 0, "mana": 0, "max_mana": 0,
	"deck": [], "discard_pile": [], "hand": [], "field": [],
	"corpse_explosion_stacks": 0, "curses": 0, "ritual_stacks": 0,
}
const FLAG_DEFAULTS := {
	"player_turn_count": 0,
	"next_battle_unit_id": 1,
	"holy_shield_ready": false,
	"draw_combo_mana_claimed": false,
	"ai_phase": "cards",
	"cards_played_this_turn": 0,
	"combo_tag": "",
	"combo_streak": 0,
	"combo_finisher_used": false,
	"combo_finisher_tag": "",
	"mana_crystal_bonus": false,
	"first_card_discount_available": false,
	"necromancer_ring_used": false,
	"second_chance_used": false,
	"summon_build_started": false,
	"boss_turn_count": 0,
	"race_power_used": false,
	"breakthrough_mana_claimed": false,
	"breakthrough_count": 0,
	"breakthrough_damage": 0,
}

static func side(source: Dictionary, fallback_name: String = "") -> Dictionary:
	var result := _normalize(source, SIDE_DEFAULTS)
	result.name = String(source.get("name", fallback_name))
	return result

static func flags(source: Dictionary) -> Dictionary:
	return _normalize(source, FLAG_DEFAULTS)

static func _normalize(source: Dictionary, schema: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in schema:
		var value: Variant = source.get(key, schema[key])
		match typeof(schema[key]):
			TYPE_INT:
				result[key] = int(value)
			TYPE_BOOL:
				result[key] = bool(value)
			TYPE_STRING:
				result[key] = String(value)
			TYPE_ARRAY:
				result[key] = (value as Array).duplicate(true)
	return result
