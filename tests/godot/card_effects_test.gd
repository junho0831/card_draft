extends RefCounted

const BattleCardEffectsScript := preload("res://src/battle/battle_card_effects.gd")
const BattleComboFinisherScript := preload("res://src/battle/battle_combo_finisher.gd")

var _failures: Array[String] = []
var _count := 0
var _effects = BattleCardEffectsScript.new()
var _combo_finisher = BattleComboFinisherScript.new()

func run() -> Dictionary:
	_failures.clear()
	_count = 0
	_test_militia_hits_front_enemy_on_summon()
	_test_small_flame_draws_when_it_kills()
	_test_first_aid_heals_and_buffs_front_ally()
	_test_signature_equipment_effects()
	_test_combo_finishers()
	return {
		"count": _count,
		"failures": _failures,
	}

func _test_militia_hits_front_enemy_on_summon() -> void:
	var owner := _side("player")
	var enemy := _side("enemy")
	enemy.field.append(_unit("target", "표적", 1, 1))
	_effects.play_card(owner, enemy, {
		"id": "militia",
		"name": "민병대",
		"type": "unit",
		"race": "중립",
		"attr": "대지",
		"attack": 1,
		"health": 1,
		"art": 0,
	}, _context())
	_assert_eq(owner.field.size(), 1, "militia is summoned")
	_assert_eq(enemy.field.size(), 0, "militia summon damage kills a 1 hp front enemy")

func _test_small_flame_draws_when_it_kills() -> void:
	var owner := _side("player")
	var enemy := _side("enemy")
	owner.deck.append({"id": "drawn", "name": "드로우 카드", "type": "spell"})
	enemy.field.append(_unit("target", "표적", 1, 2))
	_effects.play_card(owner, enemy, {
		"id": "small_flame",
		"name": "작은 불꽃",
		"type": "spell",
	}, _context())
	_assert_eq(enemy.field.size(), 0, "small flame kills a 2 hp front enemy")
	_assert_eq(owner.hand.size(), 1, "small flame draws 1 card on kill")

func _test_first_aid_heals_and_buffs_front_ally() -> void:
	var owner := _side("player")
	var enemy := _side("enemy")
	owner.health = 10
	owner.max_health = 20
	owner.field.append(_unit("ally", "아군", 1, 2))
	_effects.play_card(owner, enemy, {
		"id": "first_aid",
		"name": "응급 치료",
		"type": "spell",
	}, _context())
	_assert_eq(int(owner.health), 13, "first aid heals hero for 3")
	_assert_eq(int(owner.field[0].health), 3, "first aid buffs front ally health")
	_assert_eq(int(owner.field[0].max_health), 3, "first aid buffs front ally max health")

func _test_signature_equipment_effects() -> void:
	var owner := _side("player")
	var enemy := _side("enemy")
	owner.field.append(_unit("ally", "아군", 1, 2))
	_effects.play_card(owner, enemy, _equipment("ember_blade", "잿불 검"), _context())
	_assert_eq(int(owner.field[0].attack), 2, "ember blade buffs attack")
	var attack_result: Dictionary = _effects.on_unit_attacked(owner.field[0], owner, enemy, _context())
	_assert_eq(int(enemy.health), 19, "ember blade deals hero damage after attack")
	_assert_eq(int(attack_result.get("hero_damage", 0)), 1, "ember blade reports its bonus damage")

	owner = _side("player")
	enemy = _side("enemy")
	owner.field.append(_unit("ally", "아군", 1, 2))
	owner.deck.append({"id": "drawn", "name": "드로우 카드", "type": "spell"})
	_effects.play_card(owner, enemy, _equipment("wind_quiver", "바람깃 화살통"), _context())
	_effects.on_unit_attacked(owner.field[0], owner, enemy, _context())
	_assert_eq(int(owner.field[0].attack), 2, "wind quiver buffs attack")
	_assert_eq(owner.hand.size(), 1, "wind quiver draws after attack")

	owner = _side("player")
	enemy = _side("enemy")
	owner.field.append(_unit("ally", "아군", 1, 2))
	_effects.play_card(owner, enemy, _equipment("bone_armor", "뼈 갑옷"), _context())
	_assert_eq(int(owner.field[0].health), 5, "bone armor buffs health")
	_effects.on_unit_died(owner.field[0], owner, enemy, _context())
	_assert_eq(int(enemy.health), 18, "bone armor damages the enemy hero on death")

	owner = _side("player")
	enemy = _side("enemy")
	owner.field.append(_unit("front", "선봉", 1, 2))
	owner.field.append(_unit("back", "후열", 2, 3))
	_effects.play_card(owner, enemy, _equipment("royal_standard", "왕가의 군기"), _context())
	_assert_eq([int(owner.field[0].attack), int(owner.field[0].health)], [2, 3], "royal standard buffs the front ally")
	_assert_eq([int(owner.field[1].attack), int(owner.field[1].health)], [3, 4], "royal standard buffs every ally")

	owner = _side("player")
	enemy = _side("enemy")
	owner.field.append(_unit("ally", "아군", 1, 2))
	_effects.play_card(owner, enemy, _equipment("blood_blade", "피의 칼날"), _context())
	_assert_eq(int(owner.health), 18, "blood blade costs hero health")
	_assert_eq(int(owner.field[0].attack), 3, "blood blade grants a large attack buff")
	attack_result = _effects.on_unit_attacked(owner.field[0], owner, enemy, _context())
	_assert_eq(int(owner.health), 19, "blood blade heals after attack")

	owner = _side("player")
	enemy = _side("enemy")
	owner.field.append(_unit("ally", "아군", 1, 2))
	_effects.play_card(owner, enemy, _equipment("war_horn", "돌격의 뿔피리"), _context())
	_assert_eq(int(owner.field[0].attack), 2, "war horn buffs the front ally")
	_assert_eq(owner.field.size(), 2, "war horn summons a support token")
	_assert_eq(bool(owner.field[1].can_attack), true, "war horn token can attack immediately")
	_assert_eq((owner.field[0].get("equipment_names", []) as Array).size(), 1, "equipment is exposed for field UI")

func _test_combo_finishers() -> void:
	var state := {"combo_finisher_used": false, "combo_finisher_tag": ""}
	var owner := _side("player")
	var enemy := _side("enemy")
	enemy.field.append(_unit("target", "표적", 1, 2))
	var result: Dictionary = _combo_finisher.try_resolve("fire", 3, state, owner, enemy, _context())
	_assert_eq(String(result.get("headline", "")), "화염 폭풍", "fire chain resolves its finisher")
	_assert_eq(int(enemy.health), 18, "fire finisher damages the enemy hero")
	_assert_eq(enemy.field.size(), 0, "fire finisher clears a two health enemy")
	_assert_eq(bool(state.get("combo_finisher_used", false)), true, "combo finisher is marked used")
	_combo_finisher.try_resolve("fire", 4, state, owner, enemy, _context())
	_assert_eq(int(enemy.health), 18, "combo finisher cannot trigger twice in one battle")

	state = {"combo_finisher_used": false}
	owner = _side("player")
	enemy = _side("enemy")
	owner.deck = [{"id": "draw_1"}, {"id": "draw_2"}]
	_combo_finisher.try_resolve("draw", 3, state, owner, enemy, _context())
	_assert_eq([owner.hand.size(), int(owner.mana)], [2, 1], "draw finisher grants cards and mana")

	state = {"combo_finisher_used": false}
	owner = _side("player")
	enemy = _side("enemy")
	_combo_finisher.try_resolve("death", 3, state, owner, enemy, _context())
	_assert_eq(int(enemy.health), 17, "death finisher pressures the enemy hero")
	_assert_eq(bool(owner.field[0].can_attack), true, "death finisher summons an immediate attacker")

	state = {"combo_finisher_used": false}
	owner = _side("player")
	enemy = _side("enemy")
	owner.field.append(_unit("ally", "아군", 1, 2))
	_combo_finisher.try_resolve("buff", 3, state, owner, enemy, _context())
	_assert_eq([int(owner.field[0].attack), int(owner.field[0].health)], [2, 3], "buff finisher grows the whole field")

	state = {"combo_finisher_used": false}
	owner = _side("player")
	enemy = _side("enemy")
	owner.health = 5
	owner.field.append(_unit("ally", "아군", 1, 2))
	_combo_finisher.try_resolve("low_hp", 3, state, owner, enemy, _context())
	_assert_eq(int(owner.health), 8, "low hp finisher heals the hero")
	_assert_eq([int(owner.field[0].attack), bool(owner.field[0].can_attack)], [3, true], "low hp finisher readies the front ally")

	state = {"combo_finisher_used": false}
	owner = _side("player")
	enemy = _side("enemy")
	_combo_finisher.try_resolve("summon", 3, state, owner, enemy, _context())
	_assert_eq(owner.field.size(), 2, "summon finisher fills two slots")
	_assert_eq(bool(owner.field[0].can_attack) and bool(owner.field[1].can_attack), true, "summon finisher tokens attack immediately")

func _side(display_name: String) -> Dictionary:
	return {
		"name": display_name,
		"health": 20,
		"max_health": 20,
		"field": [],
		"hand": [],
		"deck": [],
		"discard_pile": [],
	}

func _unit(id: String, display_name: String, attack: int, health: int) -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"race": "중립",
		"attr": "대지",
		"attack": attack,
		"health": health,
		"max_health": health,
		"art": 0,
		"can_attack": false,
	}

func _equipment(id: String, display_name: String) -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"type": "equipment",
	}

func _context() -> Dictionary:
	return {
		"log": Callable(self, "_ignore_log"),
		"draw_cards": Callable(self, "_draw_cards"),
		"cleanup_dead_units": Callable(self, "_cleanup_dead_units"),
		"calculate_damage": Callable(self, "_calculate_damage"),
		"max_health": 20,
	}

func _draw_cards(side: Dictionary, amount: int) -> void:
	for i in range(amount):
		if side.deck.is_empty():
			return
		side.hand.append(side.deck.pop_front())

func _cleanup_dead_units(side_a: Dictionary, side_b: Dictionary) -> void:
	_cleanup_side(side_a)
	_cleanup_side(side_b)

func _cleanup_side(side: Dictionary) -> void:
	for i in range(side.field.size() - 1, -1, -1):
		if int(side.field[i].health) <= 0:
			side.field.remove_at(i)

func _calculate_damage(_card_or_unit: Dictionary, _is_spell: bool, _owner_state: Dictionary, base_damage: int) -> int:
	return base_damage

func _ignore_log(_message: String) -> void:
	pass

func _assert_eq(actual, expected, message: String) -> void:
	_count += 1
	if actual != expected:
		_failures.append("%s | expected=%s actual=%s" % [message, str(expected), str(actual)])
