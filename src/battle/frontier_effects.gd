extends RefCounted
## Data-defined effects for the Frontier set. Existing cards keep their original resolvers.
static func apply(engine, owner: Dictionary, enemy: Dictionary, source: Dictionary, effects: Array, context: Dictionary, summoned: Dictionary = {}) -> void:
	if source.get("type") == "equipment" or source.get("target") == "ally":
		if engine._selected_ally(owner, context).is_empty(): return
	var draw: Callable = context.get("draw_cards", Callable())
	var log: Callable = context.get("log", Callable())
	var impact: Callable = context.get("frontier_impact", Callable())
	var cleanup: Callable = context.get("cleanup_dead_units", Callable())
	for effect in effects:
		var amount := int(effect.get("amount", 0))
		var extra := int(effect.get("extra", 0))
		var target: Dictionary = engine._selected_ally(owner, context)
		match String(effect.get("op", "")):
			"front_damage", "combo_damage", "low_damage":
				if effect.op == "combo_damage" and int(context.get("cards_played_this_turn", 0)) >= 3: amount = extra
				if effect.op == "low_damage" and int(owner.health) * 2 <= int(owner.max_health): amount = extra
				if impact.is_valid(): impact.call(owner, enemy, source, amount, false, false)
				engine._deal_frontline_damage(owner, enemy, source, amount, context, String(source.name))
			"all_damage":
				var calc: Callable = context.get("calculate_damage", Callable())
				if calc.is_valid(): amount = int(calc.call(source, source.get("type") == "spell", owner, amount))
				if impact.is_valid(): impact.call(owner, enemy, source, amount, true, false)
				if enemy.field.is_empty(): enemy.health -= amount
				else:
					for unit in enemy.field: unit.health -= amount
				if cleanup.is_valid(): cleanup.call(owner, enemy)
			"hero_damage":
				if impact.is_valid(): impact.call(owner, enemy, source, amount, false, true)
				enemy.health -= amount
			"draw":
				if draw.is_valid(): draw.call(owner, amount)
			"heal": owner.health = mini(int(owner.max_health), int(owner.health) + amount)
			"self_damage":
				owner.health -= amount
				var relic = context.get("relic_service") if context.get("owner_key", "player") == "player" else null
				if relic != null: relic.on_hero_hp_lost(context.get("run_data", {}), context, owner, amount)
			"curse": engine._add_curse(enemy, amount, log, source.name)
			"ritual": engine._add_ritual(owner, amount, log, source.name)
			"ready":
				if not summoned.is_empty(): summoned.can_attack = true
			"tokens":
				for i in range(amount): engine._summon_war_horn_token(owner, context)
			"front_buff":
				if not owner.field.is_empty(): buff(owner.field[0], amount, extra)
			"all_buff":
				for unit in owner.field: buff(unit, amount, extra)
			"target_buff":
				if not target.is_empty(): buff(target, amount, extra)
			"weaken":
				if not enemy.field.is_empty(): enemy.field[0].attack = maxi(0, int(enemy.field[0].attack) - amount)
			"sacrifice":
				if target.is_empty(): return
				target.health = 0
				if cleanup.is_valid(): cleanup.call(owner, enemy)
			"gear_hit", "gear_heal", "gear_draw", "gear_death":
				if not target.is_empty():
					var key: String = {"gear_hit":"ember_blade_damage", "gear_heal":"blood_blade_heal", "gear_draw":"wind_quiver_draw", "gear_death":"bone_armor_death_damage"}[effect.op]
					target[key] = int(target.get(key, 0)) + amount
		if log.is_valid(): log.call("%s: %s" % [source.name, describe(effect)])
	if source.get("type") == "equipment":
		var target: Dictionary = engine._selected_ally(owner, context)
		if not target.is_empty():
			engine._add_equipment_name(target, source.name)
			target["impact_profile"] = source.get("impact_profile", "metal")

static func buff(unit: Dictionary, attack: int, health: int) -> void:
	unit.attack += attack
	unit.health += health
	unit.max_health += health

static func buff_text(attack: int, health: int) -> String:
	var changes: Array[String] = []
	if attack != 0: changes.append("공격 +%d" % attack)
	if health != 0: changes.append("체력 +%d" % health)
	return ", ".join(changes)

static func describe(e: Dictionary) -> String:
	var a := int(e.get("amount", 0))
	var b := int(e.get("extra", 0))
	match String(e.get("op", "")):
		"front_damage": return "앞 적에게 피해 %d" % a
		"hero_damage": return "적 영웅에게 피해 %d" % a
		"all_damage": return "모든 적 유닛 피해 %d (적 필드가 비면 영웅 피해 %d)" % [a,a]
		"draw": return "카드 %d장 드로우" % a
		"heal": return "내 영웅 체력 %d 회복" % a
		"self_damage": return "내 영웅 체력 %d 잃음" % a
		"curse": return "적 저주 +%d" % a
		"ritual": return "의식 +%d" % a
		"ready": return "즉시 공격 가능"
		"tokens": return "즉시 공격 가능한 1/1 지원병 %d장 소환 (빈 칸만)" % a
		"front_buff": return "앞 아군 " + buff_text(a, b)
		"all_buff": return "모든 아군 " + buff_text(a, b)
		"target_buff": return "선택한 아군 " + buff_text(a, b)
		"weaken": return "앞 적 공격력 %d 감소 (최소 0)" % a
		"combo_damage": return "앞 적 피해 %d, 이번 턴 카드 3장 이상 사용 시 %d" % [a,b]
		"low_damage": return "앞 적 피해 %d, 내 영웅 체력이 절반 이하라면 %d" % [a,b]
		"sacrifice": return "선택한 아군 하나 희생"
		"gear_hit": return "공격 후 적 영웅 피해 %d" % a
		"gear_heal": return "공격 후 내 영웅 회복 %d" % a
		"gear_draw": return "공격 후 카드 %d장 드로우" % a
		"gear_death": return "사망 시 적 영웅 피해 %d" % a
	return ""

static func text(card: Dictionary) -> String:
	var parts: Array[String] = []
	for effect in card.get("effects", []): parts.append(describe(effect))
	var result := ("소환 시 " if card.get("type") == "unit" and not parts.is_empty() else "") + "; ".join(parts)
	for effect in card.get("death_effects", []): result += (" / " if not result.is_empty() else "") + "사망 시 " + describe(effect)
	return result if not result.is_empty() else "전열을 오래 지키는 방어 유닛"

static func upgrade(card: Dictionary) -> void:
	# Cost-one spell upgrades improve the first beneficial effect, never its sacrifice/payment.
	for effect in card.get("effects", []):
		if effect.op in ["self_damage", "sacrifice"]: continue
		effect.amount = int(effect.amount) + 1
		if effect.op in ["all_buff", "target_buff", "front_buff", "combo_damage", "low_damage"]:
			effect.extra = int(effect.get("extra", 0)) + 1
		break
	card.text = text(card)
