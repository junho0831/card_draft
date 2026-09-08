extends RefCounted

const MAIN_SCENE := preload("res://src/core/Main.tscn")
const RewardScreenScript := preload("res://src/ui/screens/reward_screen.gd")
const GameStorage := preload("res://src/services/game_storage.gd")

var _failures: Array[String] = []
var _count := 0

func run() -> Dictionary:
	_failures.clear()
	_count = 0
	var tree := Engine.get_main_loop() as SceneTree
	var main = MAIN_SCENE.instantiate()
	main.set_meta("disable_window_mode_changes", true)
	main.set_meta("disable_timed_battle_fx", true)
	tree.root.add_child(main)
	var original_profile: Dictionary = main.player_profile.duplicate(true)
	_test_map_compatibility(main)
	_test_card_draft_roles(main)
	_test_relic_draft(main)
	_test_reward_selection_and_resume(main)
	_test_legacy_reward(main)
	_test_branch_rewards_and_settlement(main)
	main.player_profile = original_profile
	main._save_profile()
	main._clear_screen()
	main._clear_run()
	tree.root.remove_child(main)
	main.queue_free()
	return {"count": _count, "failures": _failures}

func _new_run(main: Node, race_id: String = "human") -> Dictionary:
	var run_data: Dictionary = main.run_store.create_new_run(main.run_generator.load_acts(), main.run_generator.starter_deck(race_id), 26, 85, race_id)
	(run_data["relic_ids"] as Array).append(main.run_generator.get_starting_relic(race_id))
	return run_data

func _test_map_compatibility(main: Node) -> void:
	var fresh: Dictionary = _new_run(main)
	_assert_eq((fresh["map_nodes"] as Array).size(), 2, "new run keeps two acts")
	for act_variant in fresh["map_nodes"]:
		_assert_eq((Dictionary(act_variant)["nodes"] as Array).size(), 5, "new act contains five decision layers")
	_assert_true(not String(fresh.get("run_id", "")).is_empty(), "new runs have a settlement identity")
	var legacy_acts: Array[Dictionary] = []
	for act_index in range(2):
		var nodes: Array = []
		for node_index in range(10):
			nodes.append(["boss"] if node_index == 9 else ["battle", "event"])
		legacy_acts.append({"id": act_index + 1, "name": "기존 지도", "nodes": nodes})
	var legacy: Dictionary = main.run_store.create_new_run(legacy_acts, main.run_generator.starter_deck())
	legacy["current_node_index"] = 7
	legacy["current_path_index"] = 1
	var path := GameStorage.path_for("legacy_map_test.json")
	main.run_store.save(path, legacy)
	var restored: Dictionary = main.run_store.load_or_empty(path)
	_assert_eq((restored["map_nodes"][0]["nodes"] as Array).size(), 10, "loading an older save preserves its ten layers")
	_assert_eq(String(main.run_store.current_node(restored).get("type", "")), "event", "legacy chosen path survives load")
	main.run_store.clear(path)

func _test_card_draft_roles(main: Node) -> void:
	for race_id in ["human", "elf", "undead"]:
		main.current_run = _new_run(main, race_id)
		var scores: Dictionary = main._current_build_scores()
		var primary: String = main._primary_build_tag(scores)
		var secondary: String = main._secondary_build_tag(scores)
		for roll_index in range(12):
			var choices: Array[String] = main._roll_card_reward_choices(3)
			_assert_eq(choices.size(), 3, "%s draft offers three cards" % race_id)
			_assert_eq(_unique_ids(choices).size(), 3, "draft candidates are unique")
			_assert_true(main._card_build_tags(main.card_db.get_card(choices[0])).has(primary), "first draft card strengthens the primary build")
			_assert_true(main._card_build_tags(main.card_db.get_card(choices[1])).has(secondary), "second draft card supports another existing build")
			var pivot_tags: Array[String] = main._card_build_tags(main.card_db.get_card(choices[2]))
			_assert_true(not pivot_tags.has(primary) and not pivot_tags.has(secondary), "third draft offers a different direction")
		var boss_choices: Array[String] = main._roll_boss_card_reward_choices("necro_lord")
		_assert_eq(boss_choices.size(), 3, "boss reward keeps three alternatives")
		_assert_eq(boss_choices[0], "necro_lord", "boss reward offers the defeated boss")
		_assert_eq(_unique_ids(boss_choices).size(), 3, "boss reward has no duplicate candidates")

func _test_relic_draft(main: Node) -> void:
	for race_id in ["human", "elf", "undead"]:
		main.current_run = _new_run(main, race_id)
		var choices: Array[Dictionary] = main._roll_relic_reward_choices()
		_assert_eq(choices.size(), 2, "elite/boss relic reward offers two options")
		var active: Array[String] = main._active_build_tags(main._current_build_scores())
		var matches := false
		for tag in main._relic_build_tags(choices[0]):
			matches = matches or active.has(tag)
		_assert_true(matches, "first relic supports an active build when available")
		_assert_true(String(choices[0]["id"]) != String(choices[1]["id"]), "relic candidates are distinct")
		for relic in choices:
			_assert_true(not (main.current_run["relic_ids"] as Array).has(String(relic["id"])), "relic draft excludes owned relics")
	main.current_run["relic_ids"] = []
	for relic in main.relic_service.relics:
		(main.current_run["relic_ids"] as Array).append(String(relic["id"]))
	_assert_true(main._roll_relic_reward_choices().is_empty(), "exhausted relic pool produces no mandatory selection")

func _test_reward_selection_and_resume(main: Node) -> void:
	main.current_run = _new_run(main)
	main.current_run["current_node_index"] = 2
	main.current_run["current_path_index"] = 1
	main.current_run["pending_card_reward"] = {
		"choices": ["fireball", "training_sword", "dark_bargain"],
		"battle_tier": "elite",
		"relic_choices": [main.relic_service.get_relic("burning_heart"), main.relic_service.get_relic("cursed_crown")],
		"selected_relic_id": "",
	}
	var deck_before: int = (main.current_run["deck_ids"] as Array).size()
	var screen = RewardScreenScript.new(main)
	screen._claim_card_reward("fireball")
	_assert_eq((main.current_run["deck_ids"] as Array).size(), deck_before, "card cannot commit before relic selection")
	screen._select_relic_reward("not_offered")
	_assert_eq(String(main.current_run["pending_card_reward"].get("selected_relic_id", "")), "", "invalid relic selection is ignored")
	screen._select_relic_reward("cursed_crown")
	main.current_run = main.run_store.load_or_empty(GameStorage.run_path())
	main._continue_run()
	_assert_eq(String(main.active_screen), "reward", "resume returns to pending reward")
	_assert_eq(String(main.current_run["pending_card_reward"]["selected_relic_id"]), "cursed_crown", "selected relic is persisted")
	_assert_eq(int(main.current_run["max_hp"]), 26, "selecting relic does not acquire it eagerly")
	var resumed = RewardScreenScript.new(main)
	resumed._skip_card_reward()
	_assert_eq(int(main.current_run["max_hp"]), 41, "skipping the card still grants the selected relic")
	_assert_eq((main.current_run["deck_ids"] as Array).size(), deck_before, "card skip keeps deck size")
	_assert_eq(int(main.current_run["current_node_index"]), 3, "reward advances a node once")
	_assert_eq(String(main.current_run["cleared_node_types"].get("1:2", "")), "elite", "cleared record stores the selected elite branch")
	resumed._skip_card_reward()
	screen._claim_card_reward("fireball")
	_assert_eq(int(main.current_run["max_hp"]), 41, "stale reward callback cannot grant relic twice")
	_assert_eq((main.current_run["deck_ids"] as Array).size(), deck_before, "stale reward callback cannot add a card")
	_assert_eq(int(main.current_run["current_node_index"]), 3, "stale callback cannot advance again")

func _test_legacy_reward(main: Node) -> void:
	main.current_run = _new_run(main)
	main.current_run["pending_card_reward"] = {"choices": ["fireball"], "bonus_relic": main.relic_service.get_relic("cursed_crown")}
	var screen = RewardScreenScript.new(main)
	screen._claim_card_reward("not_offered")
	_assert_eq(int(main.current_run["current_node_index"]), 0, "unoffered card cannot claim reward")
	screen._claim_card_reward("fireball")
	_assert_eq(int(main.current_run["max_hp"]), 41, "legacy single bonus relic is granted on claim")
	_assert_eq(int(main.current_run["current_node_index"]), 1, "legacy reward retains direct claim flow")

func _test_branch_rewards_and_settlement(main: Node) -> void:
	main.player_profile = main.profile_store.make_default_profile(main.card_defs)
	main.current_run = _new_run(main)
	main.current_run["current_node_index"] = 4
	main.current_run["pending_card_reward"] = {"choices": ["border_guardian"]}
	var screen = RewardScreenScript.new(main)
	screen._skip_card_reward()
	_assert_eq(int(main.current_run["act"]), 2, "first boss reward enters the second act")
	_assert_eq(int(main.player_profile["soul_stones"]), 0, "first boss does not settle the entire run")
	main.current_run["current_node_index"] = 4
	main.current_run["visited_nodes"] = ["1:0", "1:2", "1:4", "2:0", "2:2", "1:0"]
	main.current_run["cleared_node_types"] = {"1:0": "battle", "1:2": "elite", "1:4": "boss", "2:0": "battle", "2:2": "battle"}
	_assert_eq(main._run_soul_stones(false), 60, "loss awards cleared battles and elites without double counting")
	main.current_run["pending_card_reward"] = {"choices": ["undead_king"]}
	var final_screen = RewardScreenScript.new(main)
	final_screen._claim_card_reward("undead_king")
	_assert_eq(String(main.active_screen), "run_result", "final boss claim completes the run")
	_assert_eq(int(main.current_run["earned_soul_stones"]), 190, "win includes both bosses plus the clear bonus")
	_assert_eq(int(main.player_profile["soul_stones"]), 190, "win settlement credits profile")
	_assert_eq((main.player_profile["recent_runs"] as Array).size(), 1, "win writes one recent run")
	var settled_profile: Dictionary = main.player_profile.duplicate(true)
	var interrupted_run: Dictionary = main.current_run.duplicate(true)
	interrupted_run.erase("earned_soul_stones")
	interrupted_run["finished_at"] = 0
	main.current_run = interrupted_run
	main.player_profile = settled_profile
	main._continue_run()
	_assert_eq(int(main.player_profile["soul_stones"]), 190, "profile ledger prevents duplicate payout after interrupted run save")
	_assert_eq((main.player_profile["recent_runs"] as Array).size(), 1, "resumed settlement does not duplicate history")
	main._continue_run()
	_assert_eq(int(main.player_profile["soul_stones"]), 190, "reopening result is idempotent")
	main.current_run = _new_run(main)
	main.current_run["visited_nodes"] = ["1:0", "1:2"]
	main.current_run["cleared_node_types"] = {"1:0": "battle", "1:2": "elite"}
	main._finish_run(false)
	_assert_eq(int(main.player_profile["soul_stones"]), 210, "partial loss credits completed node rewards")
	main._continue_run()
	_assert_eq(int(main.player_profile["soul_stones"]), 210, "loss result reopening does not pay twice")
	main.current_run = _new_run(main)
	main.current_run.erase("run_id")
	main.current_run["result"] = "loss"
	main.current_run["earned_soul_stones"] = 5
	main.current_run["finished_at"] = 1234
	main._continue_run()
	_assert_eq(int(main.player_profile["soul_stones"]), 210, "already settled legacy results are migrated without paying twice")

func _unique_ids(ids: Array[String]) -> Dictionary:
	var result := {}
	for id in ids:
		result[id] = true
	return result

func _assert_true(value: bool, message: String) -> void:
	_count += 1
	if not value:
		_failures.append(message)

func _assert_eq(actual, expected, message: String) -> void:
	_assert_true(actual == expected, "%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
