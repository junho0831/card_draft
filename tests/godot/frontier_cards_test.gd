extends RefCounted
const DB = preload("res://src/services/card_database.gd")
const Effects = preload("res://src/battle/battle_card_effects.gd")
const Profiles = preload("res://src/battle/card_impact_profiles.gd")
var failures: Array[String] = []
var count := 0
var db = DB.new()
var engine = Effects.new()
var drawn := 0
func check(ok: bool, label: String) -> void:
	count += 1
	if not ok: failures.append(label)
func side() -> Dictionary:
	return {"name":"검증", "health":10, "max_health":20, "field":[{"id":"fixture", "name":"표적", "health":10, "max_health":10, "attack":2, "battle_unit_id":1}], "hand":[], "deck":[], "discard_pile":[], "mana":5, "max_mana":5}
func cleanup(owner: Dictionary, enemy: Dictionary) -> void:
	for pair in [[owner, enemy], [enemy, owner]]:
		var dead: Array = pair[0].field.filter(func(u): return int(u.health) <= 0)
		pair[0].field = pair[0].field.filter(func(u): return int(u.health) > 0)
		for unit in dead: engine.on_unit_died(unit, pair[0], pair[1], context())
func draw(owner: Dictionary, amount: int) -> void:
	drawn += amount
	for i in range(amount): owner.hand.append({"id":"drawn"})
func context() -> Dictionary:
	return {"draw_cards":draw, "cleanup_dead_units":cleanup, "owner_key":"player", "target_unit_id":1, "calculate_damage":func(_c,_s,_o,a): return a}
func play(id: String, owner: Dictionary, enemy: Dictionary, ctx: Dictionary = {}) -> void:
	engine.play_card(owner, enemy, db.get_card(id), context() if ctx.is_empty() else ctx)
func run() -> Dictionary:
	check(db.load_cards("res://data/frontier_cards.json"), "frontier definitions load")
	check(db.card_defs.size() == 100, "exactly 100 additional cards")
	var races := {}
	var ids := {}
	for card in db.card_defs:
		check(not ids.has(card.id), "unique id " + card.id)
		ids[card.id] = true
		races[card.race] = int(races.get(card.race, 0)) + 1
		check(Profiles.PROFILES.has(card.impact_profile), "impact exists " + card.id)
		check(not card.build_tags.is_empty(), "build direction " + card.id)
		var owner := side(); var enemy := side()
		engine.play_card(owner, enemy, card, context())
		check(owner.field.size() <= 5 and int(owner.health) <= 20, "bounded effect " + card.id)
		if card.type == "unit":
			check(owner.field.size() >= 2, "unit summons " + card.id)
			check(owner.field[1].impact_profile == card.impact_profile, "attack profile persists " + card.id)
		var upgraded: Dictionary = db.get_card(String(card.id) + "_plus")
		check(not upgraded.is_empty(), "upgrade available " + card.id)
		# Actual snapshot round-trip and death effects are covered by frontier_battle_test.
	for race in races: check(races[race] == 25, "25 per faction " + race)
	var owner := side(); var enemy := side()
	play("ember_gate_sentinel", owner, enemy)
	check(enemy.field[0].health == 9, "entry damage hits enemy frontline")
	owner = side(); enemy = side()
	play("ash_lancer", owner, enemy)
	check(owner.field[1].can_attack, "rush can attack immediately")
	owner = side(); enemy = side()
	play("sunforge_sabre", owner, enemy)
	engine.on_unit_attacked(owner.field[0], owner, enemy, context())
	check(owner.field[0].attack == 3 and enemy.health == 9, "equipped attack and after-hit fire")
	owner = side(); enemy = side()
	owner.field[0].death_effects = [{"op":"hero_damage", "amount":2}]
	play("funeral_tithe", owner, enemy)
	check(owner.field.is_empty() and enemy.health == 8 and owner.hand.size() == 2, "sacrifice invokes death effect before drawing")
	owner = side(); enemy = side()
	play("marrow_detonation", owner, enemy)
	check(owner.field.is_empty() and enemy.field[0].health == 7, "sacrifice area damage")
	owner = side(); enemy = side()
	var ctx := context(); ctx.cards_played_this_turn = 3
	play("frostseed_burst", owner, enemy, ctx)
	check(enemy.field[0].health == 5, "combo damage threshold")
	owner = side(); enemy = side()
	play("red_moon_executor", owner, enemy)
	check(enemy.field[0].health == 7, "low health conditional damage")
	owner = side(); enemy = side(); enemy.field.clear()
	play("volley_order", owner, enemy)
	check(enemy.health == 6, "empty frontline damages hero")
	owner = side(); enemy = side(); ctx = context(); ctx.target_unit_id = 999
	var before := JSON.stringify(owner)
	play("sentinel_tower_shield", owner, enemy, ctx)
	check(JSON.stringify(owner) == before, "invalid equipment target changes nothing")
	play("bloodcourt_sword", owner, enemy, ctx)
	check(JSON.stringify(owner) == before, "invalid blood equipment target never charges self damage")
	owner = side(); enemy = side()
	play("funeral_tithe_plus", owner, enemy)
	check(owner.hand.size() == 3, "cost-one upgrade improves draw not sacrifice")
	check(db.get_card("funeral_tithe_plus").text.contains("3장"), "upgraded text matches draw")
	return {"count":count, "failures":failures}
