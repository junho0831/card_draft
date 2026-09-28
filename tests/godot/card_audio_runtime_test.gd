extends SceneTree
const Storage = preload("res://src/services/game_storage.gd")
const MAIN = preload("res://src/core/Main.tscn")
const Fixture = preload("res://tests/godot/combat_strategy_test.gd")
var failures: Array[String] = []
func _init() -> void:
	if not Storage.prepare_test_directory(): quit(2); return
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	var main = MAIN.instantiate()
	main.set_meta("disable_window_mode_changes", true)
	root.add_child(main)
	current_scene = main
	main._init_run("human")
	main.current_run.relic_ids = []
	main.run_flow.prepare_battle("normal")
	var battle = main.battle_screen
	var f = Fixture.new()
	for entry in [["fireball","fire"],["gale_shot","arrow"],["vampiric_strike","blood"],["funeral_fog","shadow"],["plague_spread","poison"],["corpse_explosion","fire"],["militia","metal"]]:
		battle.player = f.side([f.unit(101,"mercenary",1,20)])
		battle.opponent = f.side([f.unit(201,"mercenary",1,20)])
		battle.player.hand = [main.card_db.get_card(entry[0])]
		battle.player.deck = [main.card_db.get_card("militia")]
		battle.current_player = "player"
		battle.input_locked = false
		battle._ensure_hand_visual_slots()
		main.audio_manager.last_sound_at_msec.clear()
		main.audio_manager.last_stream_at_msec.clear()
		await battle._work_on_hand_card_pressed(0,101,true)
		check(battle.player.hand.is_empty(), "actual card consumed " + entry[0])
		check(main.audio_manager.last_sound_at_msec.has("impact_" + entry[1]), "real audio player reached " + entry[0])
		await create_timer(0.15).timeout
	battle.player = f.side([f.unit(101,"mercenary",1,20)])
	battle.opponent = f.side([])
	battle.player.hand = [main.card_db.get_card("ember_blade")]
	battle.current_player = "player"
	battle.input_locked = false
	battle._ensure_hand_visual_slots()
	await battle._work_on_hand_card_pressed(0,101,true)
	check(battle._attack_impact_sfx(battle.player.field[0],2,false) == "impact_fire", "equipped weapon changes real attack sound")
	main.audio_manager.last_sound_at_msec.clear()
	main.audio_manager.last_stream_at_msec.clear()
	var old_hp: int = battle.opponent.health
	main.battle_effects.play_card(battle.player,battle.opponent,main.card_db.get_card("fireball"),battle._battle_effect_context("player"))
	battle._apply_damage_juice(battle.player.health,old_hp)
	check(main.audio_manager.last_sound_at_msec.has("impact_fire"), "hero receives element sound")
	check(not main.audio_manager.last_sound_at_msec.has("hit"), "generic hero hit is not doubled")
	await create_timer(2.0).timeout
	main._clear_screen()
	main._clear_run()
	main.queue_free()
	await process_frame
	print("PASS actual card-use route, audio playback, weapon identity, hero duplicate suppression" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
