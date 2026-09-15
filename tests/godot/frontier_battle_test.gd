extends RefCounted
const MAIN = preload("res://src/core/Main.tscn")
const DB = preload("res://src/services/card_database.gd")
const Fixture = preload("res://tests/godot/combat_strategy_test.gd")
var count := 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok: failures.append(message)
func run() -> Dictionary:
	var tree = Engine.get_main_loop()
	var main = MAIN.instantiate()
	main.set_meta("disable_timed_battle_fx", true)
	main.set_meta("disable_battle_ui_rerender", true)
	main.set_meta("disable_window_mode_changes", true)
	tree.root.add_child(main)
	main._init_run("human")
	main.run_flow.prepare_battle("normal")
	main.current_run.relic_ids = []
	var db = DB.new()
	db.load_cards("res://data/frontier_cards.json")
	var f = Fixture.new()
	var battle = main.battle_screen
	battle.player = f.side([f.unit(101), f.unit(102)])
	battle.opponent = f.side([f.unit(201, "militia", 1, 20)])
	battle.player.hand = [db.get_card("bloodcourt_sword")]
	battle.player.deck = [db.get_card("caravan_guard"), db.get_card("dew_scout")]
	battle.current_player = "player"
	battle.input_locked = false
	battle._ensure_hand_visual_slots()
	var before := JSON.stringify(battle._serialize_side(battle.player))
	battle._on_hand_card_pressed(0)
	check(not battle.pending_action.is_empty(), "new equipment requests ally target")
	check(JSON.stringify(battle._serialize_side(battle.player)) == before, "new equipment selection does not spend health mana or card")
	battle._cancel_ally_selection()
	check(JSON.stringify(battle._serialize_side(battle.player)) == before, "cancel new equipment is read-only")
	battle._on_hand_card_pressed(0)
	battle._confirm_ally_target(102)
	check(battle.player.field[0].attack == 1 and battle.player.field[1].attack == 3, "new equipment affects selected duplicate only")
	check(battle.player.health == 18 and battle.player.hand.is_empty(), "new equipment payment happens exactly once")
	check(battle.player.field[1].impact_profile == "blood", "equipment changes actual unit impact profile")
	battle.player.field[1].death_effects = [{"op":"hero_damage", "amount":2}]
	battle._store_battle_snapshot()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(main.current_run.battle_snapshot))
	battle._restore_battle_snapshot(snapshot)
	check(battle.player.field[1].impact_profile == "blood" and battle.player.field[1].death_effects.size() == 1, "JSON battle restore keeps new impact and death effects")
	battle.player.hand = [db.get_card("funeral_tithe")]
	battle._ensure_hand_visual_slots()
	battle._on_hand_card_pressed(0)
	check(not battle.pending_action.is_empty(), "new sacrifice requests ally target")
	var sacrifices_before := int(battle.battle_state.strategy_metrics.get("sacrifices", 0))
	battle._confirm_ally_target(102)
	check(int(battle.battle_state.strategy_metrics.sacrifices) == sacrifices_before + 1, "successful new sacrifice counts in playthrough metrics")
	check(battle.player.field.size() == 1 and battle.player.field[0].battle_unit_id == 101, "sacrifice removes selected duplicate only")
	check(battle.opponent.health == 17, "restored death effect and original bone-soldier death effect execute on sacrifice")
	check(battle.player.hand.size() == 2, "sacrifice draws two real cards")
	battle.player.field.clear()
	check(not battle._can_play_card(battle.player, db.get_card("funeral_tithe"), "player"), "empty field blocks sacrifice")
	battle.player.mana = 0
	check(not battle._can_play_card(battle.player, db.get_card("volley_order"), "player"), "insufficient mana blocks new damage spell")
	battle.battle_state.cards_played_this_turn = 1
	check(battle._direct_damage_preview(db.get_card("frostseed_burst")) == 2, "second card previews base combo damage")
	battle.battle_state.cards_played_this_turn = 2
	check(battle._direct_damage_preview(db.get_card("frostseed_burst")) == 5, "third card previews its own contribution to combo threshold")
	check(battle._direct_damage_preview(main.card_db.get_card("gale_shot")) == 4, "legacy third-card spell uses the same preview threshold")
	var collection = preload("res://src/ui/screens/collection_screen.gd").new(main)
	main.collection_filter = "변경 원정"
	check(collection._filtered_collection_cards().size() == 100, "collection expansion filter shows exactly the new hundred cards")
	var panel: Control = collection._make_collection_card(db.get_card("ember_gate_sentinel"), true)
	tree.root.add_child(panel)
	panel.size = Vector2(260, 700)
	await tree.process_frame
	await tree.process_frame
	var inspect: Button = panel.find_children("*", "Button", true, false)[0]
	var face: Control = inspect.get_parent().get_child(0)
	check(not face.get_global_rect().intersects(inspect.get_global_rect()), "collection inspect button does not cover the card face")
	panel.queue_free()
	main._clear_screen()
	main._clear_run()
	tree.root.remove_child(main)
	main.queue_free()
	await tree.process_frame
	return {"count":count, "failures":failures}
