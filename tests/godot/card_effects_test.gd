extends RefCounted

const BattleCardEffectsScript := preload("res://src/battle/battle_card_effects.gd")

var _failures: Array[String] = []
var _count := 0
var _effects = BattleCardEffectsScript.new()

func run() -> Dictionary:
	_failures.clear()
	_count = 0
	_test_militia_hits_front_enemy_on_summon()
	_test_small_flame_draws_when_it_kills()
	_test_first_aid_heals_and_buffs_front_ally()
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
