extends RefCounted
## Serializes accepted attacks; rules remain in the existing synchronous resolvers.
var owner: WeakRef
var busy := false
var active_presentation

func _init(battle_owner) -> void:
	owner = weakref(battle_owner)

func index_of(side: Dictionary, id: int) -> int:
	for i in range(side.field.size()):
		if int(side.field[i].get("battle_unit_id", -2)) == id:
			return i
	return -1

func execute(side_key: String, attacker_id: int, target: Dictionary) -> bool:
	var battle = owner.get_ref()
	if battle == null or busy or battle.leaving_battle or battle.game_over or battle.battle_finished:
		return false
	if side_key not in ["player", "opponent"] or battle.current_player != side_key:
		return false
	if side_key == "player" and (battle.input_locked or not battle.pending_action.is_empty()):
		return false
	var attacker_side: Dictionary = battle.player if side_key == "player" else battle.opponent
	var defender_side: Dictionary = battle.opponent if side_key == "player" else battle.player
	var attacker_index := index_of(attacker_side, attacker_id)
	if attacker_index < 0 or int(attacker_side.field[attacker_index].health) <= 0 or not bool(attacker_side.field[attacker_index].get("can_attack", false)):
		return false
	var target_index := -1
	if target.get("kind") == "unit":
		target_index = index_of(defender_side, int(target.get("id", -1)))
		if target_index < 0 or int(defender_side.field[target_index].health) <= 0: return false
	elif target.get("kind") == "hero":
		if side_key == "player" and battle._enemy_vanguard_blocks_hero(): return false
		if side_key == "opponent" and not defender_side.field.is_empty(): return false
	else:
		return false
	busy = true
	active_presentation = battle.presentation
	battle.input_locked = true
	if target_index >= 0:
		if side_key == "player":
			await battle._resolve_player_unit_attack(attacker_index, target_index)
		else:
			await battle._resolve_unit_combat(attacker_side, defender_side, attacker_index, target_index)
	elif side_key == "player":
		await battle._resolve_player_hero_attack(attacker_index)
	else:
		await battle._resolve_ai_hero_attack(attacker_index)
	battle.input_locked = battle.current_player != "player" or battle.game_over or battle.leaving_battle
	battle._store_battle_snapshot()
	busy = false
	active_presentation = null
	return true
