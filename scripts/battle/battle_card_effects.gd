extends RefCounted
class_name BattleCardEffects

func _base_card_id(card_id: String) -> String:
	if card_id.ends_with("_plus"):
		return card_id.trim_suffix("_plus")
	return card_id

func play_card(owner: Dictionary, enemy: Dictionary, card: Dictionary, context: Dictionary) -> void:
	var log: Callable = context.get("log", Callable())
	match String(card.get("type", "")):
		"unit":
			var unit := {
				"id": String(card.get("id", "")),
				"name": String(card.get("name", "")),
				"race": String(card.get("race", "")),
				"attr": String(card.get("attr", "")),
				"attack": int(card.get("attack", 0)),
				"health": int(card.get("health", 0)),
				"max_health": int(card.get("health", 0)),
				"art": int(card.get("art", 0)),
				"can_attack": false,
			}
			var relic_service = context.get("relic_service")
			if relic_service != null:
				relic_service.on_unit_summoned(context.get("run_data", {}), unit)
			owner.field.append(unit)
			var on_unit_summoned: Callable = context.get("on_unit_summoned", Callable())
			if on_unit_summoned.is_valid():
				on_unit_summoned.call(owner, unit)
			if log.is_valid():
				log.call("%s: %s 소환" % [owner.name, card.name])
			_resolve_unit_play(owner, enemy, unit, context)
		"spell":
			_resolve_spell(owner, enemy, card, context)
		"equipment":
			_resolve_equipment(owner, card, context)

func on_unit_died(dead_unit: Dictionary, owner: Dictionary, enemy: Dictionary, context: Dictionary) -> void:
	var log: Callable = context.get("log", Callable())
	var draw_cards: Callable = context.get("draw_cards", Callable())
	if String(dead_unit.get("id", "")) == "grave_knight":
		owner.health = min(int(owner.get("max_health", context.get("max_health", 20))), int(owner.health) + 2)
		if log.is_valid():
			log.call("무덤 기사 사망 효과: %s 영웅 체력 2 회복" % owner.name)
	if String(dead_unit.get("id", "")) == "bone_soldier":
		enemy.health -= 1
		if log.is_valid():
			log.call("해골 병사 사망 효과: %s 영웅에게 피해 1" % enemy.name)
	if int(owner.get("corpse_explosion_stacks", 0)) > 0:
		var damage := 2 * int(owner.corpse_explosion_stacks)
		var cleanup: Callable = context.get("cleanup_dead_units", Callable())
		if enemy.field.is_empty():
			enemy.health -= damage
			if log.is_valid():
				log.call("시체 폭발 효과: %s 영웅에게 피해 %d" % [enemy.name, damage])
		else:
			enemy.field[0].health -= damage
			if log.is_valid():
				log.call("시체 폭발 효과: %s에게 피해 %d" % [enemy.field[0].name, damage])
			if cleanup.is_valid():
				cleanup.call(owner, enemy)
	if String(dead_unit.get("id", "")) == "bone_soldier" and draw_cards.is_valid():
		pass

func _resolve_unit_play(owner: Dictionary, enemy: Dictionary, unit: Dictionary, context: Dictionary) -> void:
	var draw_cards: Callable = context.get("draw_cards", Callable())
	var log: Callable = context.get("log", Callable())
	match _base_card_id(String(unit.get("id", ""))):
		"forest_archer":
			if draw_cards.is_valid():
				draw_cards.call(owner, 1)
			if log.is_valid():
				log.call("숲의 궁수 효과: 카드 1장 드로우")
		"knight_spearman":
			if not owner.field.is_empty():
				owner.field[0]["attack"] = int(owner.field[0].get("attack", 0)) + 1
				if log.is_valid():
					log.call("기사단 창병 효과: 가장 앞의 아군 공격력 +1")
		"thief":
			owner.health -= 1
			var relic_service = context.get("relic_service")
			if relic_service != null:
				relic_service.on_hero_hp_lost(context.get("run_data", {}), context, owner, 1)
			if log.is_valid():
				log.call("도적 효과: 내 영웅 체력 1 잃음")
		"bone_oracle":
			_add_curse(enemy, 1, log, "뼈 점술사")
		"ritual_sapling":
			_add_ritual(owner, 1, log, "의식의 묘목")

func _resolve_spell(owner: Dictionary, enemy: Dictionary, card: Dictionary, context: Dictionary) -> void:
	var draw_cards: Callable = context.get("draw_cards", Callable())
	var log: Callable = context.get("log", Callable())
	var cleanup: Callable = context.get("cleanup_dead_units", Callable())
	var calc_damage: Callable = context.get("calculate_damage", Callable())
	var card_id := _base_card_id(String(card.get("id", "")))
	match card_id:
		"death_mark":
			_add_curse(enemy, 1, log, "죽음의 낙인")
		"plague_spread":
			for unit in enemy.field:
				unit.health -= 1
				if log.is_valid():
					log.call("역병 확산! %s에게 피해 1" % unit.name)
			if cleanup.is_valid():
				cleanup.call(owner, enemy)
			_add_curse(enemy, 2, log, "역병 확산")
		"soul_shackle":
			_add_curse(enemy, 2, log, "영혼 족쇄")
			if draw_cards.is_valid():
				draw_cards.call(owner, 1)
		"funeral_fog":
			if enemy.field.is_empty():
				enemy.health -= 1
				if log.is_valid():
					log.call("장례 안개! %s 영웅에게 피해 1" % enemy.name)
			else:
				enemy.field[0].health -= 1
				if log.is_valid():
					log.call("장례 안개! %s에게 피해 1" % enemy.field[0].name)
				if cleanup.is_valid():
					cleanup.call(owner, enemy)
			_add_curse(enemy, 1, log, "장례 안개")
		"world_tree_ritual":
			_add_ritual(owner, 1, log, "세계수 의식")
		"nature_communion":
			_add_ritual(owner, 1, log, "자연의 교감")
			if draw_cards.is_valid():
				draw_cards.call(owner, 1)
		"moonwell":
			owner.health = min(int(context.get("max_health", 20)), int(owner.health) + 2)
			_add_ritual(owner, 1, log, "달샘")
		"ancient_oath":
			_add_ritual(owner, 2, log, "고대의 맹세")
			if draw_cards.is_valid():
				draw_cards.call(owner, 1)
		"captain_order":
			var bonus := 1
			if String(card.get("id", "")).ends_with("_plus"):
				bonus = 2
			for unit in owner.field:
				unit.attack += bonus
			if log.is_valid():
				log.call("%s: 지휘관의 명령, 아군 전체 공격력 +%d" % [owner.name, bonus])
		"royal_support":
			if draw_cards.is_valid():
				draw_cards.call(owner, 1)
			if not owner.field.is_empty():
				for unit in owner.field:
					if String(unit.get("race", "")) == "인간":
						owner.field[0].health += 1
						owner.field[0].max_health += 1
						break
			if log.is_valid():
				log.call("%s: 왕실 지원, 카드 1장 드로우" % owner.name)
		"elven_insight":
			if draw_cards.is_valid():
				draw_cards.call(owner, 2)
			if log.is_valid():
				log.call("%s: 엘프의 통찰, 카드 2장 드로우" % owner.name)
		"nature_blessing":
			if not owner.field.is_empty():
				owner.field[0].health += 3
				owner.field[0].max_health += 3
				if log.is_valid():
					log.call("%s: 자연의 축복, %s 체력 +3" % [owner.name, owner.field[0].name])
		"dark_bargain":
			var hp_loss := 2
			if String(card.get("id", "")).ends_with("_plus"):
				hp_loss = 1
			owner.health -= hp_loss
			var relic_service = context.get("relic_service")
			if relic_service != null:
				relic_service.on_hero_hp_lost(context.get("run_data", {}), context, owner, hp_loss)
			if draw_cards.is_valid():
				draw_cards.call(owner, 2)
			if log.is_valid():
				log.call("%s: 어둠의 거래, 체력 %d 지불 후 카드 2장 드로우" % [owner.name, hp_loss])
		"call_of_dead":
			for i in range(2):
				if owner.field.size() >= 5:
					break
				play_card(owner, enemy, {
					"id": "bone_soldier",
					"name": "해골 병사",
					"type": "unit",
					"race": "언데드",
					"attr": "암흑",
					"attack": 1,
					"health": 1,
					"art": 2,
				}, context)
		"corpse_explosion":
			if not owner.field.is_empty():
				owner.field[0].health = 0
			if enemy.field.is_empty():
				enemy.health -= 2
				if log.is_valid():
					log.call("%s: 시체 폭발, 적 영웅 전체 피해 2" % owner.name)
			else:
				for unit in enemy.field:
					unit.health -= 2
				if log.is_valid():
					log.call("%s: 시체 폭발, 모든 적 유닛 피해 2" % owner.name)
				if cleanup.is_valid():
					cleanup.call(owner, enemy)
		"small_flame", "fireball", "gale_shot":
			var base_damage := 4
			if card_id == "small_flame":
				base_damage = 2
			elif card_id == "gale_shot":
				var played_count := int(context.get("cards_played_this_turn", 0))
				base_damage = 4 if played_count >= 3 else 1
			var damage := base_damage
			if calc_damage.is_valid():
				damage = int(calc_damage.call(card, true, owner, base_damage))
			if enemy.field.is_empty():
				enemy.health -= damage
				if log.is_valid():
					log.call("%s: %s로 %s 영웅에게 피해 %d" % [owner.name, card.name, enemy.name, damage])
			else:
				enemy.field[0].health -= damage
				if log.is_valid():
					log.call("%s: %s로 %s에게 피해 %d" % [owner.name, card.name, enemy.field[0].name, damage])
				if cleanup.is_valid():
					cleanup.call(owner, enemy)
		"first_aid":
			owner.health = min(int(context.get("max_health", 20)), int(owner.health) + 3)
			if log.is_valid():
				log.call("%s: 응급 치료, 영웅 체력 3 회복" % owner.name)
		"healing_potion":
			owner.health = min(int(context.get("max_health", 20)), int(owner.health) + 5)
			if log.is_valid():
				log.call("%s: 회복 물약, 영웅 체력 5 회복" % owner.name)

func _resolve_equipment(owner: Dictionary, card: Dictionary, context: Dictionary) -> void:
	var log: Callable = context.get("log", Callable())
	if owner.field.is_empty():
		return
	owner.field[0].attack += 2
	if log.is_valid():
		log.call("%s: %s 장착, %s 공격력 +2" % [owner.name, card.name, owner.field[0].name])

func _add_curse(enemy: Dictionary, amount: int, log: Callable, source: String) -> void:
	enemy["curses"] = int(enemy.get("curses", 0)) + amount
	if log.is_valid():
		log.call("%s! 적 영웅에게 저주 +%d (현재: %d)" % [source, amount, int(enemy.get("curses", 0))])

func _add_ritual(owner: Dictionary, amount: int, log: Callable, source: String) -> void:
	owner["ritual_stacks"] = int(owner.get("ritual_stacks", 0)) + amount
	if log.is_valid():
		log.call("%s! 의식 스택 +%d (현재: %d)" % [source, amount, int(owner.get("ritual_stacks", 0))])
