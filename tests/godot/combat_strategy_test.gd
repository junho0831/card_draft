extends RefCounted

const MAIN = preload("res://src/core/Main.tscn")
const Database = preload("res://src/services/card_database.gd")
const Effects = preload("res://src/battle/battle_card_effects.gd")
const Policy = preload("res://src/battle/battle_enemy_policy.gd")
var failures: Array[String] = []
var count := 0

func check(value: bool, message: String) -> void:
	count += 1
	if not value:
		failures.append(message)

func side(units: Array = []) -> Dictionary:
	return {"name": "test", "health": 20, "max_health": 30, "mana": 10, "max_mana": 10, "field": units, "hand": [], "deck": [], "discard_pile": [], "curses": 0, "ritual_stacks": 0}

func unit(id: int, name: String = "bone_soldier", attack: int = 1, health: int = 4) -> Dictionary:
	return {"battle_unit_id": id, "id": name, "name": name, "attack": attack, "health": health, "max_health": health, "can_attack": true, "race": "언데드", "attr": "암흑", "art": 2, "art_id": "bone_soldier"}

func run() -> Dictionary:
	var db = Database.new()
	db.load_cards("res://data/cards.json")
	var effects = Effects.new()
	for card in db.card_defs:
		var upgraded: Dictionary = db.get_card(String(card.id) + "_plus")
		check(upgraded.get("cost") != card.get("cost") or upgraded.get("attack") != card.get("attack") or upgraded.get("text") != card.get("text"), "%s upgrade changes gameplay" % card.id)
	var owner := side([unit(11), unit(12)])
	var enemy := side()
	effects.play_card(owner, enemy, db.get_card("training_sword"), {"target_unit_id": 12})
	check(owner.field[0].attack == 1 and owner.field[1].attack == 3, "equipment selects the correct duplicate unit")
	effects.play_card(owner, enemy, db.get_card("training_sword"), {"target_unit_id": 999})
	check(owner.field[1].attack == 3, "invalid explicit target never falls back to first unit")
	effects.play_card(owner, enemy, db.get_card("corpse_explosion"), {"target_unit_id": 12})
	check(owner.field[0].health == 4 and owner.field[1].health == 0, "sacrifice affects selected unit")
	for id in ["bone_soldier", "grave_knight", "berserker"]:
		var a := side()
		var b := side()
		var c := side()
		var d := side()
		effects.on_unit_died({"id": id}, a, b, {})
		effects.on_unit_died({"id": id + "_plus"}, c, d, {})
		check(a.health == c.health and b.health == d.health, "%s retains upgraded death effect" % id)
	for id in ["small_flame", "funeral_fog", "gale_shot"]:
		var a := side()
		var b := side()
		effects.play_card(a, b, db.get_card(id + "_plus"), {})
		check(b.health == (18 if id == "gale_shot" else 17), "%s upgraded damage resolves" % id)
	var actor := side([unit(1)])
	effects.play_card(actor, side(), db.get_card("battlecry_plus"), {})
	check(actor.field[0].attack == 3 and actor.field[0].health == 6, "battlecry improves both stats")
	check(Policy.attack_target(unit(1), [unit(2, "a", 9, 8), unit(3, "b", 2, 2)], 3) == 1, "AI prefers a safe lethal trade")
	check(Policy.card_priority(db.get_card("fireball"), ["aggressive"], true) > Policy.card_priority(db.get_card("militia"), ["aggressive"], true), "aggressive AI prefers damage")
	check(Policy.card_priority(db.get_card("militia"), ["swarm"], true) > Policy.card_priority(db.get_card("fireball"), ["swarm"], true), "swarm AI prefers summons")
	check(Policy.boss_pattern({"tier": "boss", "id": "undead_king"}, 3, 1).kind == "summon", "third boss turn predicts summon")
	var main = MAIN.instantiate()
	main.set_meta("disable_timed_battle_fx", true)
	main.set_meta("disable_battle_ui_rerender", true)
	main.set_meta("disable_window_mode_changes", true)
	Engine.get_main_loop().root.add_child(main)
	main._init_run("human")
	main.run_flow.prepare_battle("normal")
	var battle = main.battle_screen
	check(battle.player.max_mana == 2, "first turn base mana remains two")
	check(battle.turn_timer.is_stopped(), "turns have no running timer")
	main.current_run["relic_ids"] = []
	battle.player = side([unit(101), unit(102)])
	battle.opponent = side([unit(201, "militia", 3, 10)])
	battle.player.hand = [db.get_card("training_sword"), db.get_card("militia")]
	battle._ensure_hand_visual_slots()
	battle.current_player = "player"
	battle.input_locked = false
	battle._on_hand_card_pressed(0)
	check(not battle.pending_action.is_empty() and battle.player.mana == 10 and battle.player.hand.size() == 2, "opening target selection consumes nothing")
	battle._cancel_ally_selection()
	check(battle.pending_action.is_empty() and battle.player.mana == 10, "cancel preserves resources")
	battle._on_hand_card_pressed(0)
	battle._confirm_ally_target(102)
	check(battle.player.field[0].attack == 1 and battle.player.field[1].attack == 3, "UI target confirmation equips chosen unit")
	check(battle.player.mana == 8 and battle.player.hand.size() == 1, "target confirmation consumes exactly once")
	main.current_run["relic_ids"] = ["knight_banner", "burning_heart"]
	battle.battle_state["active_build_tags"] = ["fire"]
	var enemy_damage: int = battle._calculate_damage(db.get_card("fireball"), true, battle.opponent, 4)
	check(enemy_damage == 4, "enemy does not inherit player's fire bonuses")
	var before_attack: int = battle.opponent.field[0].attack
	main.battle_effects.play_card(battle.opponent, battle.player, db.get_card("militia"), battle._battle_effect_context("opponent"))
	check(battle.opponent.field[-1].attack == 1, "enemy summon ignores player's banner")
	var before := JSON.stringify(battle._serialize_side(battle.opponent))
	battle.battle_state["holy_shield_ready"] = true
	var intent: String = battle._next_enemy_action_text()
	check(intent.contains("미확정") and JSON.stringify(battle._serialize_side(battle.opponent)) == before and battle.battle_state.holy_shield_ready, "intent preview is read-only and labels unknown effects")
	battle.player.deck = [db.get_card("militia"), db.get_card("militia"), db.get_card("militia")]
	battle.player.mana = 0
	battle.battle_state["draw_combo_mana_claimed"] = false
	battle._trigger_combo_bonus("draw", 3)
	battle._trigger_combo_bonus("draw", 4)
	check(battle.player.mana == 1, "draw combo refunds mana only once per turn")
	battle._store_battle_snapshot()
	var snapshot: Dictionary = main.current_run.battle_snapshot.duplicate(true)
	battle._begin_ally_selection({"kind": "power"})
	battle._restore_battle_snapshot(snapshot)
	check(battle.pending_action.is_empty() and battle.battle_state.draw_combo_mana_claimed and battle.turn_timer.is_stopped(), "snapshot restores refund flag and cancels transient targeting")
	check(battle.player.field[1].battle_unit_id == 102, "snapshot preserves unit identity")
	check(battle.battle_state.holy_shield_ready, "snapshot preserves unused holy shield")
	battle.battle_state["active_build_tags"] = ["summon", "draw"]
	var chain_unit: Dictionary = {}
	for candidate in db.card_defs:
		if candidate.get("type") == "unit" and main._card_build_tags(candidate).has("draw") and main._card_build_tags(candidate).has("summon"):
			chain_unit = candidate
			break
	check(not chain_unit.is_empty() and battle._combo_candidate_tags(chain_unit)[0] == "summon", "mixed summon units start a summon chain")
	battle.battle_state["combo_tag"] = "draw"
	battle.battle_state["combo_streak"] = 0
	battle._resolve_card_combo(chain_unit)
	check(battle.battle_state.combo_tag == "draw", "mixed summon units preserve an existing draw chain")
	battle.opponent.field = [unit(301, "militia", 8, 20)]
	check(battle._recommended_attack_target_index(unit(302)) == -1, "recommendation pressures hero when no favorable kill exists")
	battle.opponent.field[0]["is_vanguard"] = true
	check(battle._recommended_attack_target_index(unit(302)) == 0, "recommendation still respects vanguard")
	main._clear_screen()
	main._clear_run()
	Engine.get_main_loop().root.remove_child(main)
	main.queue_free()
	return {"count": count, "failures": failures}
