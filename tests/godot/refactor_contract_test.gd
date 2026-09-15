extends RefCounted

const Codec = preload("res://src/battle/battle_snapshot_codec.gd")
const Layout = preload("res://src/ui/layout_policy.gd")
var failures: Array[String] = []
var count := 0

func check(value: bool, message: String) -> void:
	count += 1
	if not value:
		failures.append(message)

func run() -> Dictionary:
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
	check(Layout.is_mobile_portrait(Vector2(390, 844)) and not Layout.is_mobile_portrait(Vector2(844, 390)), "mobile layout does not leak into landscape")
	check(Layout.is_touch_portrait(Vector2(800, 1200)) and not Layout.is_mobile_portrait(Vector2(800, 1200)), "portrait tablet retains distinct card confirmation and phone layout thresholds")
	return {"count": count, "failures": failures}
