extends SceneTree

const Economy = preload("res://src/services/reward_economy.gd")
const Storage = preload("res://src/services/game_storage.gd")
const RunStore = preload("res://src/services/run_state.gd")
const MainScene = preload("res://src/core/Main.tscn")
var count := 0
var failures: Array[String] = []

func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	count += 1
	if not ok:
		failures.append(message)

func run() -> void:
	seed(271828)
	check(Economy.available(["a", "b", "c"], [], [["a_plus"], ["b"]]) == ["c"], "both recent batches exclude base IDs")
	check(Economy.available(["a", "a_plus", "b"], ["a_plus"]) == ["b"], "base variants cannot duplicate a selected candidate")
	check(Economy.available(["a", "b"], [], [["a"], ["b"]]) == ["a", "b"], "exhausted role falls back to its original candidates")
	check(Economy.available(["a", "b", "c"], [], [["a"], ["b"], ["c"]]) == ["a"], "only two latest batches exclude candidates")
	var store := RunStore.new()
	var data := store.create_new_run([], [])
	check(data.reward_offer_history == [], "new runs start with empty history")
	for batch in [["a_plus", "a", "b"], ["c"], ["d"]]:
		data.pending_card_reward = {"choices": batch}
		store.save(Storage.run_path(), data)
		var once: Array = data.reward_offer_history.duplicate(true)
		if String(batch[0]) == "a_plus":
			check(once == [["a", "b"]], "stored batches collapse upgrades and duplicates")
		store.save(Storage.run_path(), data)
		check(data.reward_offer_history == once, "repeated saves never record a batch twice")
	check(data.reward_offer_history == [["c"], ["d"]], "history retains exactly the last two offers")
	data.pending_card_reward = {"choices": ["training_sword"], "lesson_equipment": true}
	store.save(Storage.run_path(), data)
	check(data.reward_offer_history == [["c"], ["d"]], "fixed tutorial reward is exempt")
	var legacy := {"deck_ids": [], "pending_card_reward": {"choices": ["a"]}, "pending_shop": {"cards": ["x", "y", "z"]}}
	var file := FileAccess.open(Storage.run_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var restored := store.load_or_empty(Storage.run_path())
	store.save(Storage.run_path(), restored)
	check(restored.reward_offer_history == [], "legacy pending reward is not counted retroactively")
	check(restored.pending_card_reward.choices == ["a"] and restored.pending_shop == legacy.pending_shop, "legacy offers restore unchanged")
	store.clear(Storage.run_path())
	var main = MainScene.instantiate()
	main.set_meta("disable_timed_battle_fx", true)
	main.set_meta("disable_battle_ui_rerender", true)
	main.set_meta("disable_window_mode_changes", true)
	root.add_child(main)
	main.pending_guided_run = false
	main.player_profile.learning_stage = 5
	main._init_run("human", "human_elite")
	main.current_run.deck_ids = ["small_flame", "small_flame", "small_flame", "small_flame", "elven_insight"]
	main.current_run.relic_ids = []
	var primary: String = main._primary_build_tag(main._current_build_scores())
	var secondary: String = main._secondary_build_tag(main._current_build_scores())
	var old_defs: Array = main.card_defs.duplicate(true)
	var primary_pool: Array = main._reward_card_pool(primary)
	var support_pool: Array = main._reward_card_pool(secondary)
	var pivot_pool: Array = []
	for id in main._reward_card_pool():
		var tags: Array = main._card_build_tags(main.card_db.get_card(id))
		if not tags.has(primary) and not tags.has(secondary):
			pivot_pool.append(id)
	var first: Array = main._roll_card_reward_choices(3)
	check(main.current_run.reward_offer_history.is_empty(), "speculative rolls never record unpresented offers")
	check(primary_pool.has(first[0]) and support_pool.has(first[1]) and pivot_pool.has(first[2]), "primary support and pivot keep their roles")
	main.current_run.pending_card_reward = {"choices": first}
	main._save_run()
	var history: Array = main.current_run.reward_offer_history.duplicate(true)
	var second: Array = main._roll_card_reward_choices(3)
	check(not first.has(second[0]) and primary_pool.has(second[0]), "primary avoids previous offers with same-role alternatives")
	check(not first.has(second[1]) and support_pool.has(second[1]), "support avoids previous offers with same-role alternatives")
	check(not first.has(second[2]) and pivot_pool.has(second[2]), "pivot avoids previous offers with same-role alternatives")
	main.current_run.pending_card_reward = {"choices": second}
	main._save_run()
	var third: Array = main._roll_card_reward_choices(3)
	for index in range(3):
		var role_pool: Array = [primary_pool, support_pool, pivot_pool][index]
		var eligible: Array = Economy.available(role_pool, third.slice(0, index), [first, second])
		check(eligible.has(third[index]), "third batch respects both histories within role %d" % index)
	main.current_run.pending_card_reward = {"choices": first, "offer_history_recorded": true}
	main.current_run.reward_offer_history = history.duplicate(true)
	main._save_run()
	main._show_card_reward()
	main._show_card_reward()
	check(main.current_run.reward_offer_history == history, "reward UI redraw does not append history")
	main.current_run = store.load_or_empty(Storage.run_path())
	main.run_flow.continue_run()
	check(main.current_run.pending_card_reward.choices == first and main.current_run.reward_offer_history == history, "pending reward restore does not reroll or append history")
	var deck_before: Array = main.current_run.deck_ids.duplicate()
	main.active_screen_controller._skip_card_reward()
	check(main.current_run.deck_ids == deck_before and main.current_run.reward_offer_history == history, "skip retains offer history without adding a card")
	main.current_run.pending_card_reward = {"choices": first, "gold_reward": 20}
	main._save_run()
	main._show_card_reward()
	var reward_screen = main.active_screen_controller
	var gold_before: int = main.current_run.gold
	reward_screen._claim_card_reward(String(first[0]))
	reward_screen._claim_card_reward(String(first[0]))
	check(main.current_run.deck_ids.size() == deck_before.size() + 1 and main.current_run.gold == gold_before, "reward claim adds one card once and does not duplicate victory gold")
	main.current_run.deck_ids = deck_before.duplicate()
	main.current_run.reward_offer_history = [["border_guardian_plus"], ["border_guardian"]]
	var boss: Array = main._roll_boss_card_reward_choices("border_guardian", 3)
	check(boss[0] == "border_guardian" and boss.size() == 3, "fixed boss remains offered even in recent history")
	main.current_run.pending_card_reward = {"choices": boss, "battle_tier": "boss"}
	main._save_run()
	check(main.current_run.reward_offer_history == [["border_guardian"], boss], "only finalized boss batch is recorded")
	main.current_run.pending_card_reward = {}
	main.current_run.pending_shop = {}
	main._show_shop()
	var shop: Dictionary = main.current_run.pending_shop.duplicate(true)
	check(shop.cards.size() == 3 and primary_pool.has(shop.cards[0]), "first shop slot aligns with primary build")
	check(Economy.available(shop.cards, []).size() == 3, "shop candidates are unique")
	main.current_run = store.load_or_empty(Storage.run_path())
	main.run_flow.continue_run()
	main._show_shop()
	check(JSON.parse_string(JSON.stringify(main.current_run.pending_shop)) == JSON.parse_string(JSON.stringify(shop)), "shop redraw and restore retain all offers")
	var card: Dictionary = main.card_db.get_card("small_flame")
	var comparison: Dictionary = main._card_economy_comparison(card)
	check(comparison.after_scores.fire == comparison.before_scores.fire + 1, "comparison uses factual score increments")
	check(not comparison.before_active.has("fire") and comparison.after_active.has("fire"), "comparison reports activation threshold crossing")
	var bucket: String = Economy.cost_bucket(int(card.cost))
	check(comparison.after_costs[bucket] == comparison.before_costs[bucket] + 1, "comparison adds exactly one card to its cost bucket")
	var costs := Economy.cost_buckets(["0", "1", "2", "3", "4", "8"], func(id: String): return {"cost": int(id)})
	check(costs == {"0-1": 2, "2-3": 2, "4+": 2}, "cost bucket boundaries are 0-1, 2-3 and 4+")
	var same_race: Dictionary = main.card_db.get_card(String(primary_pool[0]))
	var other_race: Dictionary = main.card_db.get_card(String(primary_pool[1]))
	same_race.race = "인간"
	other_race.race = "엘프"
	main.card_defs.assign([same_race, other_race])
	main.current_run.reward_offer_history = [[same_race.id]]
	check(main._roll_card_reward_choices(1) == [other_race.id], "fresh same-role card from another race avoids recent own-race card")
	check(main._roll_shop_card_choices(1) == [same_race.id], "shop first slot retains own-race primary preference independent of reward history")
	main.card_defs.assign([other_race])
	check(main._roll_shop_card_choices(1) == [other_race.id], "shop falls back to primary tag from another race")
	main.card_defs.assign([main.card_db.get_card(String(pivot_pool[0]))])
	check(main._roll_shop_card_choices(1) == [pivot_pool[0]], "shop falls back to unrestricted pool when primary tag is unavailable")
	main.card_defs.assign([main.card_db.get_card(String(primary_pool[0]))])
	var small: Array = main._roll_card_reward_choices(3)
	check(small.size() == 1, "insufficient pool falls back and terminates without duplicates")
	check(main._roll_shop_card_choices(3).size() == 1, "shop handles insufficient pool without duplicates")
	main.card_defs.clear()
	check(main._roll_card_reward_choices(3).is_empty() and main._roll_shop_card_choices(3).is_empty(), "empty pools terminate cleanly")
	main.card_defs.assign(old_defs)
	_test_transactions(main.shop_run_service)
	main._clear_run()
	main._clear_screen()
	main.queue_free()
	await process_frame
	for script in [preload("res://tests/godot/shop_run_service_test.gd"), preload("res://tests/godot/starting_strategy_test.gd"), preload("res://tests/godot/run_state_test.gd")]:
		var result: Dictionary = await script.new().run()
		count += int(result.count)
		failures.append_array(result.failures)
	await process_frame
	await process_frame
	for failure in failures:
		printerr(failure)
	print("%s reward/economy + shop + starting strategy + run state: %d assertions, %d failures" % ["PASS" if failures.is_empty() else "FAIL", count, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_transactions(service) -> void:
	var data := {"gold": 300, "hp": 10, "max_hp": 26, "deck_ids": [], "relic_ids": [],
		"pending_shop": {"cards": ["a", "b", "c"], "purchased_cards": [], "relic": {"id": "r"}, "remove_count": 0}}
	check(service.buy_card(data, "a").ok and data.gold == 265 and data.deck_ids == ["a"], "35 gold card transaction")
	check(not service.buy_card(data, "a").ok and data.gold == 265, "repeated card purchase is rejected")
	check(service.buy_relic(data, func(_data, _id): pass).ok and data.gold == 155, "110 gold relic transaction")
	check(service.buy_heal(data).ok and data.gold == 110 and data.hp == 26, "45 gold heal caps at max HP")
	check(service.begin_remove(data).ok and data.gold == 110, "remove preview does not charge")
	check(service.confirm_remove(data).ok and data.gold == 65 and service.remove_cost(data.pending_shop) == 65, "first removal costs 45 and escalates to 65")
	check(service.confirm_remove(data).ok and data.gold == 0 and service.remove_cost(data.pending_shop) == 85, "second removal costs 65 and escalates to 85")
	var before := JSON.stringify(data)
	check(not service.buy_card(data, "b").ok and not service.confirm_remove(data).ok and not service.buy_heal(data).ok, "insufficient funds reject transactions")
	check(JSON.stringify(data) == before, "rejected transactions preserve all state")
