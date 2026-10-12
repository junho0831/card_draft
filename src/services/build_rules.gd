extends RefCounted
## Build rules without scene, profile, RNG or presentation dependencies.
## Keep tag order stable: it breaks equal-score ties and orders active builds.

static func threshold() -> int:
	return 5

static func valid_tags() -> Array[String]:
	return ["fire", "draw", "death", "buff", "low_hp", "summon"]

static func tags_from_data(source: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	var raw_tags: Variant = source.get("build_tags", [])
	if typeof(raw_tags) != TYPE_ARRAY:
		return tags
	var allowed := valid_tags()
	for raw_tag in raw_tags:
		var tag := String(raw_tag)
		if allowed.has(tag) and not tags.has(tag):
			tags.append(tag)
	return tags

static func card_tags(card: Dictionary) -> Array[String]:
	var data_tags := tags_from_data(card)
	if not data_tags.is_empty() or card.has("build_tags"):
		return data_tags
	var id := String(card.get("id", ""))
	var tags: Array[String] = []
	var attr := String(card.get("attr", ""))
	if attr == "화염":
		tags.append("fire")
	if id in ["forest_archer", "elven_insight", "royal_support", "nature_communion", "wind_feather"]:
		tags.append("draw")
	if id in ["bone_soldier", "grave_knight", "dark_bargain", "call_of_dead", "corpse_explosion", "death_mark", "plague_spread", "bone_oracle", "soul_shackle", "funeral_fog"]:
		tags.append("death")
	if id in ["captain_order", "knight_spearman", "royal_support", "nature_blessing", "training_sword", "shield_guard"]:
		tags.append("buff")
	if id in ["dark_bargain", "thief", "healing_potion", "first_aid", "moonwell"]:
		tags.append("low_hp")
	if id in ["call_of_dead", "bone_soldier", "elf_ranger", "ritual_sapling", "mercenary", "militia"]:
		tags.append("summon")
	return tags

static func relic_tags(relic: Dictionary) -> Array[String]:
	var data_tags := tags_from_data(relic)
	if not data_tags.is_empty() or relic.has("build_tags"):
		return data_tags
	var id := String(relic.get("id", ""))
	var tags: Array[String] = []
	if id in ["burning_heart"]:
		tags.append("fire")
	if id in ["world_tree_leaf", "wind_feather", "tactical_manual", "war_drum"]:
		tags.append("draw")
	if id in ["book_of_death", "necromancer_ring"]:
		tags.append("death")
	if id in ["knight_banner", "gladiator_helm"]:
		tags.append("buff")
	if id in ["blood_chalice", "dark_heart", "cursed_crown", "holy_shield"]:
		tags.append("low_hp")
	if id in ["necromancer_ring", "gladiator_helm"]:
		tags.append("summon")
	return tags

static func scores_for_run(run_data: Dictionary, get_card: Callable, get_relic: Callable) -> Dictionary:
	var scores := {
		"fire": 0,
		"draw": 0,
		"death": 0,
		"buff": 0,
		"low_hp": 0,
		"summon": 0,
	}
	if run_data.is_empty():
		return scores
	for card_id_variant in run_data.get("deck_ids", []):
		var card: Dictionary = get_card.call(String(card_id_variant))
		if card.is_empty():
			continue
		for tag in card_tags(card):
			scores[tag] = int(scores.get(tag, 0)) + 1
	for relic_id_variant in run_data.get("relic_ids", []):
		var relic: Dictionary = get_relic.call(String(relic_id_variant))
		if relic.is_empty():
			continue
		for tag in relic_tags(relic):
			scores[tag] = int(scores.get(tag, 0)) + 2
	return scores

static func active_tags(scores: Dictionary) -> Array[String]:
	var active: Array[String] = []
	for tag in valid_tags():
		if int(scores.get(tag, 0)) >= threshold():
			active.append(String(tag))
	return active

static func primary_tag(scores: Dictionary) -> String:
	var best_tag := ""
	var best_score := 0
	for tag in valid_tags():
		var score := int(scores.get(tag, 0))
		if score > best_score:
			best_score = score
			best_tag = String(tag)
	return best_tag

static func secondary_tag(scores: Dictionary) -> String:
	var primary := primary_tag(scores)
	var best_tag := ""
	var best_score := 0
	# Prefer a build that this reward can bring closer to activation.
	for tag in valid_tags():
		var score := int(scores.get(tag, 0))
		if tag != primary and score > best_score and score < threshold():
			best_tag = tag
			best_score = score
	if not best_tag.is_empty():
		return best_tag
	for tag in valid_tags():
		var score := int(scores.get(tag, 0))
		if tag != primary and score > best_score:
			best_tag = tag
			best_score = score
	return best_tag
