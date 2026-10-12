extends RefCounted

const Builds = preload("res://src/services/build_rules.gd")
const Codec = preload("res://src/battle/battle_snapshot_codec.gd")
const Layout = preload("res://src/ui/layout_policy.gd")
var failures: Array[String] = []
var count := 0

func check(value: bool, message: String) -> void:
	count += 1
	if not value:
		failures.append(message)

func run() -> Dictionary:
	_test_build_rules()
	var source := {"health": 7.0, "hand": [{"id": "militia", "effects": [1]}], "field": [{"battle_unit_id": 4, "health": 3}], "runtime_only": true}
	var saved := Codec.side(source, "적")
	check(saved.name == "적" and typeof(saved.health) == TYPE_INT, "legacy side defaults and JSON numeric normalization")
	check(not saved.has("runtime_only"), "runtime-only fields do not enter save format")
	source.hand[0].effects.append(2)
	source.field[0].health = 0
	check(saved.hand[0].effects == [1] and saved.field[0].health == 3, "snapshot does not alias nested live units or cards")
	var restored := Codec.side(saved)
	restored.hand.clear()
	check(saved.hand.size() == 1, "restored hand does not mutate saved hand")
	var empty := Codec.side({})
	empty.field.append({})
	check(Codec.side({}).field.is_empty(), "legacy default arrays are isolated between battles")
	var flags := Codec.flags({"ai_phase": "attacks", "next_battle_unit_id": 12.0, "draw_combo_mana_claimed": true})
	check(flags.ai_phase == "attacks" and flags.next_battle_unit_id == 12 and flags.draw_combo_mana_claimed, "resume phase, identity counter and refund survive normalization")
	check(Codec.flags({}).ai_phase == "cards" and Codec.flags({}).next_battle_unit_id == 1, "legacy battle defaults remain unchanged")
	var high_density := Vector2(1080, 2340)
	var scale := Layout.render_scale(high_density, Vector2(1280, 720), true, 1.0, 1.5)
	check(is_equal_approx(high_density.x / scale, 390.0), "Android physical resolution becomes phone logical width")
	var landscape := Vector2(2340, 1080)
	check(is_equal_approx(Layout.render_scale(landscape, Vector2(1280, 720), true, 1.0, 1.5), scale), "rotating Android preserves readable button scale")
	check(Layout.landscape_size(Vector2(390, 844)) == Vector2(844, 390), "phone dimensions always select landscape layout")
	check(Layout.landscape_size(Vector2(800, 1200)) == Vector2(1200, 800), "tablet dimensions always select landscape layout")
	return {"count": count, "failures": failures}

func _test_build_rules() -> void:
	# Exercise the rules without a Main scene or rendering dependencies.
	check(Builds.card_tags({"id": "royal_support"}) == ["draw", "buff"], "legacy cards retain inferred tags and tag order")
	check(Builds.relic_tags({"id": "gladiator_helm"}) == ["buff", "summon"], "legacy relics retain inferred tags")
	check(Builds.card_tags({"id": "royal_support", "build_tags": []}).is_empty(), "explicit empty tags suppress legacy inference")
	check(Builds.relic_tags({"id": "gladiator_helm", "build_tags": "invalid"}).is_empty(), "malformed explicit tags do not restore legacy tags")
	check(Builds.tags_from_data({"build_tags": ["draw", "unknown", "draw", "fire"]}) == ["draw", "fire"], "normalization rejects unknown tags and preserves unique source order")
	var cards := {"card": {"id": "card", "build_tags": ["draw", "buff"]}}
	var relics := {"relic": {"id": "relic", "build_tags": ["draw"]}}
	var run_data := {"deck_ids": ["card", "card", "card", "missing"], "relic_ids": ["relic", "missing"]}
	var before := JSON.stringify([run_data, cards, relics])
	seed(83471)
	var expected_random := randi()
	seed(83471)
	var scores := Builds.scores_for_run(run_data, func(id: String) -> Dictionary: return cards.get(id, {}), func(id: String) -> Dictionary: return relics.get(id, {}))
	check(scores.draw == 5 and scores.buff == 3, "each card copy adds one point and relic adds two while missing definitions are skipped")
	check(Builds.active_tags(scores) == ["draw"], "build activates at five points")
	check(Builds.primary_tag({"draw": 5, "fire": 5}) == "fire", "equal primary scores use canonical order rather than dictionary insertion")
	check(Builds.secondary_tag({"fire": 8, "draw": 6, "death": 4}) == "death", "secondary prefers an incomplete build over a stronger active build")
	check(Builds.secondary_tag({"fire": 8, "draw": 6, "death": 5}) == "draw", "secondary falls back to highest other active build")
	check(Builds.primary_tag({}) == "" and Builds.secondary_tag({}) == "", "empty scores have no invented recommendation")
	check(JSON.stringify([run_data, cards, relics]) == before and randi() == expected_random, "build queries preserve run data, definitions and gameplay RNG")
	scores.draw = 99
	var empty := Builds.scores_for_run({}, Callable(), Callable())
	check(empty.draw == 0 and Builds.active_tags(empty).is_empty(), "empty run returns fresh zero scores without needing data lookups")
