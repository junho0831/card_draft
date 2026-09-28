extends SceneTree
const Storage = preload("res://src/services/game_storage.gd")
const Profiles = preload("res://src/battle/card_impact_profiles.gd")
const Effects = preload("res://src/battle/battle_card_effects.gd")
const DB = preload("res://src/services/card_database.gd")
const Audio = preload("res://src/services/audio_manager.gd")
var failures: Array[String] = []
var hits := 0
func _init() -> void:
	if not Storage.prepare_test_directory(): quit(2); return
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func run() -> void:
	var db := DB.new()
	check(db.load_cards("res://data/cards.json"), "database loads")
	check(db.card_defs.size() == 147, "147 cards retained")
	for card in db.card_defs:
		check(not Profiles.key(card).is_empty(), "profile " + card.id)
		check(Profiles.key(db.get_card(String(card.id) + "_plus")) == Profiles.key(card), "upgraded identity " + card.id)
	var audio := Audio.new()
	root.add_child(audio)
	var paths := {}
	var motifs := {}
	for name in Profiles.PROFILES:
		var profile: Dictionary = Profiles.PROFILES[name]
		var path := audio._sfx_path("impact_" + name)
		check(not path.is_empty() and not paths.has(path), "distinct sound " + name)
		check(not motifs.has(profile.motif), "distinct motion " + name)
		paths[path] = true
		motifs[profile.motif] = true
	var engine := Effects.new()
	for id in ["small_flame", "fireball", "gale_shot"]:
		for hero in [true, false]:
			var owner := {"name":"ally", "health":20, "max_health":20, "field":[], "hand":[]}
			var enemy := {"name":"enemy", "health":20, "field":[] if hero else [{"health":20, "name":"target"}]}
			var before := hits
			var card: Dictionary = db.get_card(id)
			engine.play_card(owner, enemy, card, {"frontier_impact": func(_o,_e,source,amount,_area,_hero):
				hits += 1
				check(Profiles.key(source) == Profiles.key(card), "spell identity retained")
				check(amount > 0 and (enemy.health == 20 if hero else enemy.field[0].health == 20), "feedback precedes damage/cleanup")})
			check(hits == before + 1, "single impact per spell")
			check((enemy.health if hero else enemy.field[0].health) == 20 - (2 if id == "small_flame" else (4 if id == "fireball" else 1)), "spell damage unchanged")
	for entry in [["stormfeather_quiver","lightning",false],["bloodcourt_sword","blood",false],["martyrs_plate","holy",true]]:
		var owner := {"name":"ally", "health":20, "max_health":30, "field":[{"id":"mercenary", "name":"target", "attack":1,"health":20,"max_health":20}]}
		var enemy := {"name":"enemy", "health":20,"field":[]}
		engine.play_card(owner, enemy, db.get_card(entry[0]), {})
		var restored: Dictionary = JSON.parse_string(JSON.stringify(owner.field[0]))
		var events: Array = []
		var ctx := {"frontier_impact":func(_o,_e,source,_a,_area,hero): events.append([source.impact_profile,hero])}
		if entry[2]: engine.on_unit_died(restored,owner,enemy,ctx)
		else: engine.on_unit_attacked(restored,owner,enemy,ctx)
		check(events == [[entry[1],true]], "saved equipment proc keeps source identity " + entry[0])
	audio.queue_free()
	await process_frame
	print("PASS 147 card identities, 12 distinct sounds/motifs, upgrade and spell impact timing" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
