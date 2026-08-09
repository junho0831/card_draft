extends RefCounted

const MAIN_SCENE := preload("res://src/core/Main.tscn")
const RewardScreenScript := preload("res://src/ui/screens/reward_screen.gd")
const BattleObjectiveServiceScript := preload("res://src/battle/battle_objective_service.gd")

var _failures: Array[String] = []
var _count := 0

func run() -> Dictionary:
	_failures.clear()
	_count = 0

	var tree := Engine.get_main_loop() as SceneTree
	var main = MAIN_SCENE.instantiate()
	tree.root.add_child(main)

	_test_boots_to_main_menu(main)
	_test_content_scaling(main)
	_test_battle_objective_service()
	_test_run_start_and_battle_entry(main)
	_test_battle_ui_defaults(main)
	_test_hand_card_drag_and_target_line(main)
	_test_race_powers(main)
	_test_secondary_screens(main)
	_test_continue_run_routes(main)
	_test_build_delta_summary(main)
	_test_race_reward_affinity(main)
	_test_reward_claim_advances_node(main)
	_test_boss_victory_provides_boss_card_reward(main)
	_test_shop_leave_advances_node(main)
	_test_rest_complete_advances_node(main)
	_test_event_complete_advances_node(main)

	main._clear_screen()
	main._clear_run()
	tree.root.remove_child(main)
	main.queue_free()

	return {
		"count": _count,
		"failures": _failures,
	}

func _test_boots_to_main_menu(main: Node) -> void:
	_assert_eq(String(main.active_screen), "main_menu", "main scene boots to main menu")
	_assert_true(main.root_box != null, "main scene builds root ui")
	_assert_true(main.card_defs.size() > 0, "main scene loads card data")
	_assert_true(not bool(main.player_profile.get("battle_tutorial_seen", true)), "battle tutorial starts enabled for new profile")
	_assert_eq(int(main.player_profile.get("battle_tutorial_stage", -1)), 0, "battle tutorial starts at stage 0")
	_assert_true(main.audio_manager.streams.has("impact_heavy"), "audio manager provides heavy impact sound")
	_assert_true(main.audio_manager.streams.has("direct_attack"), "audio manager provides direct attack sound")
	_assert_true(FileAccess.file_exists("res://assets/audio/direct_attack.wav"), "runtime direct attack SFX exists")
	_assert_true(main.audio_manager.has_authored_sfx("direct_attack"), "audio manager loads direct attack SFX")
	_assert_true(main.audio_manager.streams.has("victory_burst"), "audio manager provides victory burst sound")
	for sound_name in ["summon_human", "summon_elf", "summon_undead", "summon_common", "hit_human", "hit_elf", "hit_undead", "hit_common", "spell_fire", "spell_draw", "spell_death", "spell_buff", "spell_summon", "spell_low_hp", "spell_common", "equipment_human", "equipment_elf", "equipment_undead", "equipment_common"]:
		_assert_true(main.audio_manager.streams.has(sound_name), "audio manager provides card identity sound: %s" % sound_name)
	for sound_name in main.audio_manager.authored_sfx_keys():
		_assert_true(FileAccess.file_exists("res://assets/audio/%s.wav" % sound_name), "runtime ElevenLabs SFX exists: %s" % sound_name)
		_assert_true(FileAccess.file_exists("res://assets/audio/source/raw/elevenlabs/%s.mp3" % sound_name), "source ElevenLabs SFX exists: %s" % sound_name)
		_assert_true(main.audio_manager.has_authored_sfx(sound_name), "audio manager loads ElevenLabs SFX: %s" % sound_name)
	for music_name in ["battle_base", "battle_tension", "battle_lethal", "battle_low_hp"]:
		_assert_true(main.audio_manager.music_streams.has(music_name), "audio manager provides adaptive battle music: %s" % music_name)
	var sfx_bus := AudioServer.get_bus_index(&"SFX")
	_assert_true(sfx_bus >= 0, "audio manager creates a dedicated SFX bus")
	_assert_true(sfx_bus >= 0 and AudioServer.get_bus_effect_count(sfx_bus) > 0, "SFX bus includes a limiter")
	_assert_true(AudioServer.get_bus_index(&"BGM") >= 0, "audio manager creates a dedicated BGM bus")

func _test_content_scaling(main: Node) -> void:
	var original_scale_mode := String(main.player_profile["settings"].get("ui_scale_mode", "auto"))
	main.player_profile["settings"]["ui_scale_mode"] = "auto"
	_assert_eq(String(ProjectSettings.get_setting("display/window/stretch/mode", "")), "canvas_items", "project uses Canvas Items stretch mode")
	_assert_eq(String(ProjectSettings.get_setting("display/window/stretch/aspect", "")), "expand", "project uses Expand stretch aspect")
	_assert_eq(int(ProjectSettings.get_setting("display/window/handheld/orientation", -1)), DisplayServer.SCREEN_SENSOR_LANDSCAPE, "mobile app stays in sensor landscape orientation")
	_assert_eq(main._layout_size_for_physical_size(Vector2(390, 844)), Vector2(390, 844), "phone layout keeps native logical pixels")
	_assert_eq(main._layout_size_for_physical_size(Vector2(800, 1280)), Vector2(800, 1280), "tablet layout keeps native logical pixels")
	var full_hd_layout: Vector2 = main._layout_size_for_physical_size(Vector2(1920, 1080))
	_assert_true(is_equal_approx(full_hd_layout.x, 1324.1379) and is_equal_approx(full_hd_layout.y, 744.8276), "full HD uses the roomy desktop UI scale")
	_assert_true(is_equal_approx(main._content_scale_factor_for_physical_size(Vector2(1920, 1080)), 0.9666667), "full HD keeps Canvas Items close to native size")
	var ultrawide_layout: Vector2 = main._layout_size_for_physical_size(Vector2(2560, 1080))
	_assert_true(is_equal_approx(ultrawide_layout.x, 1765.5172) and is_equal_approx(ultrawide_layout.y, 744.8276), "ultrawide keeps extra horizontal layout space with larger UI")
	main.player_profile["settings"]["ui_scale_mode"] = "large"
	_assert_true(is_equal_approx(main._render_scale_for_physical_size(Vector2(1920, 1080)), 1.566), "large mode increases desktop UI scale")
	_assert_eq(main._layout_size_for_physical_size(Vector2(390, 844)), Vector2(390, 844), "large mode does not shrink phone layout")
	main.player_profile["settings"]["ui_scale_mode"] = "small"
	_assert_true(is_equal_approx(main._render_scale_for_physical_size(Vector2(1920, 1080)), 1.305), "small mode reduces desktop UI scale")
	main.player_profile["settings"]["ui_scale_mode"] = original_scale_mode

func _test_battle_objective_service() -> void:
	var service = BattleObjectiveServiceScript.new()
	var combo: Dictionary = service.create_objective(1, "normal", false)
	_assert_eq(String(combo.get("id", "")), "combo", "objective seed selects a deterministic challenge")
	_assert_true(not service.record_event(combo, "combo", 1), "combo objective stays pending below target")
	_assert_true(service.record_event(combo, "combo", 2), "combo objective completes at two cards")
	_assert_true(String(service.status_text(combo)).contains("+10G"), "completed objective exposes its gold reward")
	var untouched: Dictionary = service.create_objective(2, "normal", false)
	service.record_event(untouched, "hero_damage", 1)
	_assert_true(not service.resolve_victory(untouched), "taking hero damage fails the untouched objective")

func _test_run_start_and_battle_entry(main: Node) -> void:
	var run_before_selection: Dictionary = main.current_run.duplicate(true)
	main._start_new_run()
	_assert_eq(String(main.active_screen), "race_selection", "start_new_run opens race selection")
	_assert_eq(main.current_run, run_before_selection, "race selection preserves the current run until confirmation")
	_assert_true(main.active_screen_controller != null, "race selection controller is retained")
	_assert_eq(main.active_screen_controller.race_hit_targets.size(), 3, "race selection exposes a full-card hit target for every race")
	var elf_hit_target: Button = main.active_screen_controller.race_hit_targets.get("elf")
	elf_hit_target.pressed.emit()
	_assert_eq(String(main.pending_race_selection_id), "elf", "clicking the elf card surface selects the elf race")
	main.active_screen_controller._select_race("human")
	_test_race_starters(main)
	main._init_run("human")
	_assert_eq(String(main.active_screen), "map", "confirming race opens map")
	_assert_true(not main.current_run.is_empty(), "confirming race creates run data")
	_assert_eq(String(main.current_run.get("race_id", "")), "human", "new run stores selected race")
	_assert_eq(String(main.run_store.current_node(main.current_run).get("type", "")), "battle", "new run starts on battle node")

	main._enter_current_node()
	_assert_eq(String(main.active_screen), "battle", "enter_current_node opens battle screen")
	_assert_true(not Dictionary(main.current_run.get("active_enemy", {})).is_empty(), "battle entry selects enemy")
	_assert_true(main.battle_screen != null, "battle screen is instantiated")

func _test_race_starters(main: Node) -> void:
	var expected_builds := {
		"human": ["summon", "buff"],
		"elf": ["draw", "summon"],
		"undead": ["death", "summon"],
	}
	for race_id in main._valid_race_ids():
		var deck: Array[String] = main.run_generator.starter_deck(race_id)
		_assert_eq(deck.size(), 10, "%s starter deck has 10 cards" % race_id)
		var expected_race := String(main._race_meta().get(race_id, {}).get("data_race", ""))
		var common_count := 0
		var starter_matches_pool := true
		for card_id in deck:
			var card_race := String(main.card_db.get_card(card_id).get("race", ""))
			if card_race == "중립":
				common_count += 1
			elif card_race != expected_race:
				starter_matches_pool = false
				break
		_assert_true(starter_matches_pool, "%s starter cards use faction or common cards" % race_id)
		_assert_eq(common_count, 1, "%s starter deck includes one common card" % race_id)
		var representative_id := String(main._race_meta().get(race_id, {}).get("representative_card_id", ""))
		_assert_eq(String(main.card_db.get_card(representative_id).get("race", "")), expected_race, "%s selection art matches its faction" % race_id)
		var run_data: Dictionary = main.run_store.create_new_run(main.run_generator.load_acts(), deck, 26, 85, race_id)
		(run_data.get("relic_ids", []) as Array).append(main.run_generator.get_starting_relic(race_id))
		main.current_run = run_data
		var active: Array[String] = main._active_build_tags(main._current_build_scores())
		for tag in expected_builds[race_id]:
			_assert_true(active.has(String(tag)), "%s starter activates %s build" % [race_id, tag])
	main.current_run = {}

func _test_battle_ui_defaults(main: Node) -> void:
	var battle = main.battle_screen
	_assert_true(battle.detail_panel != null, "battle detail panel exists")
	_assert_true(not bool(battle.detail_panel.visible), "battle detail panel starts collapsed")
	_assert_true(battle.tutorial_panel != null, "battle tutorial panel exists")
	_assert_true(bool(battle.tutorial_panel.visible), "battle tutorial starts visible on first battle")
	_assert_true(battle.recommended_action_button != null, "battle recommends a primary action button")
	_assert_eq(String(battle._battle_guidance_mode()), "auto", "first battle keeps one-button automatic guidance")
	_assert_true(battle.race_power_button != null, "battle shows the race power button")
	_assert_true(battle.end_turn_button != null, "battle keeps end turn button visible")
	_assert_true(battle.battle_fx_layer != null, "battle mounts the combat fx layer")
	_assert_true(battle.battle_fx_layer.has_method("fly_card") and battle.battle_fx_layer.has_method("finish_card"), "battle fx layer provides card flight actions")
	_assert_true(FileAccess.file_exists("res://assets/fx/impact_heavy_v1.png"), "battle ships the generated additive impact texture")
	_assert_true(not Dictionary(battle.battle_state.get("battle_objective", {})).is_empty(), "battle creates one optional objective")
	_assert_true(battle.battle_objective_label != null, "battle displays objective progress beside guidance")
	battle._dismiss_battle_tutorial()
	_assert_eq(int(main.player_profile.get("battle_tutorial_stage", -1)), 1, "dismissing tutorial advances tutorial stage")
	_assert_true(not bool(battle.tutorial_panel.visible), "dismissing tutorial hides panel")

	battle.player = {
		"name": "플레이어",
		"health": 26,
		"max_health": 26,
		"mana": 3,
		"max_mana": 3,
		"hand": [main.card_db.get_card("militia")],
		"deck": [],
		"discard_pile": [],
		"field": [{
			"id": "militia",
			"name": "민병대",
			"attack": 1,
			"health": 1,
			"max_health": 1,
			"can_attack": true,
			"race": "중립",
			"attr": "화염",
		}],
	}
	battle.opponent = {
		"name": "적",
		"health": 10,
		"max_health": 10,
		"mana": 0,
		"max_mana": 0,
		"hand": [],
		"deck": [],
		"discard_pile": [],
		"field": [{
			"id": "enemy_token",
			"name": "표적",
			"attack": 1,
			"health": 1,
			"max_health": 1,
			"can_attack": false,
			"race": "중립",
			"attr": "대지",
		}],
	}
	battle.selected_attacker = -1
	battle.current_player = "player"
	battle.input_locked = false
	battle.game_over = false
	battle.battle_state["cards_played_this_turn"] = 0
	var recommended: Dictionary = battle._recommended_action_state()
	_assert_eq(String(recommended.get("kind", "")), "unit_attack_direct", "recommended action prioritizes attack over another card play")
	battle.player["health"] = 10
	battle.opponent["field"][0]["attack"] = 5
	battle.opponent["field"][0]["can_attack"] = true
	_assert_eq(String(battle._battle_music_state().get("mode", "")), "tension", "battle music enters tension when enemy damage threatens a small hero")
	battle.player["health"] = 26
	battle.opponent["field"][0]["attack"] = 1
	battle.opponent["field"][0]["can_attack"] = false

	battle.opponent["field"] = []
	battle.selected_attacker = 0
	battle._refresh_action_buttons()
	var direct_attack: Dictionary = battle._recommended_action_state()
	_assert_eq(String(direct_attack.get("kind", "")), "hero_attack_selected", "selected attacker exposes direct hero attack")
	_assert_true(String(direct_attack.get("guidance", "")).contains("큰 버튼") and String(direct_attack.get("guidance", "")).contains("피해"), "direct attack guidance points to the single primary action and its result")
	_assert_true(not bool(battle.hero_attack_button.disabled), "enemy hero target becomes clickable after selecting an attacker")
	_assert_true(String(battle.opponent_hero_target_badge_label.text).contains("클릭") and String(battle.opponent_hero_target_badge_label.text).contains("피해"), "enemy hero badge names the click result")
	_assert_true(String(battle.recommended_action_button.text).begins_with("다음 행동"), "primary action button is explicitly labeled as the next action")
	battle.opponent["health"] = 1
	battle._refresh_action_buttons()
	var lethal_attack: Dictionary = battle._recommended_action_state()
	_assert_eq(String(lethal_attack.get("outcome", "")), "victory", "lethal hero attack exposes a victory outcome")
	_assert_eq(String(battle._battle_music_state().get("mode", "")), "lethal", "battle music enters lethal when the player can win now")
	_assert_true(String(battle.recommended_action_button.text).contains("승리"), "lethal primary action states that it wins")
	_assert_true(String(battle.opponent_hero_target_badge_label.text).contains("승리"), "lethal enemy hero target states that clicking wins")
	battle.selected_attacker = -1
	battle._refresh_action_buttons()
	battle.player["health"] = 4
	_assert_eq(String(battle._battle_music_state().get("mode", "")), "low_hp", "battle music prioritizes player low hp over kill pressure")
	battle.player["health"] = 26

	var original_node_index := int(main.current_run.get("current_node_index", 0))
	main.current_run["current_node_index"] = 2
	battle.opponent["health"] = 10
	battle._refresh_ui()
	_assert_eq(String(battle._battle_guidance_mode()), "guided", "second battle changes recommendation to guided manual targeting")
	_assert_true(String(battle.recommended_action_button.text).begins_with("1단계"), "guided recommendation names the attacker-selection step")
	_assert_true(String(battle._manual_battle_guidance_text(battle._recommended_action_state())).contains("자동"), "guided attack hint explains that direct enemy clicks auto-pick the attacker")
	_assert_eq(String(battle._card_play_sfx({"type": "unit", "race": "인간", "build_tags": ["summon"]})), "summon_human", "human unit cards use human summon audio")
	_assert_eq(String(battle._card_play_sfx({"type": "unit", "race": "엘프", "build_tags": ["draw"]})), "summon_elf", "elf unit cards use elf summon audio")
	_assert_eq(String(battle._card_play_sfx({"type": "spell", "race": "언데드", "build_tags": ["death"]})), "spell_death", "death-tag spells use death audio")
	_assert_eq(String(battle._card_play_sfx({"type": "equipment", "race": "중립", "build_tags": ["buff"]})), "equipment_common", "common equipment cards use common equipment audio")
	_assert_eq(String(battle._attack_impact_sfx({"race": "엘프"}, 2, false)), "hit_elf", "elf attackers use elf hit audio")
	_assert_true(battle._card_exhausts_after_play(main.card_db.get_card("world_tree_ritual")), "pure self-setup ritual spells exhaust instead of cycling forever")
	_assert_true(not battle._card_exhausts_after_play(main.card_db.get_card("nature_communion")), "ritual spells with card draw keep normal discard cycling")
	_assert_true(not battle._card_exhausts_after_play({"id": "new_setup_attack", "type": "spell", "text": "효과", "build_tags": ["buff"]}), "non-ritual setup spells are not exhausted by id or tag alone")
	var guided_enemy_health := int(battle.opponent.get("health", 0))
	battle._on_recommended_action_pressed()
	_assert_eq(int(battle.selected_attacker), 0, "guided recommendation selects only the suggested attacker")
	_assert_eq(int(battle.opponent.get("health", 0)), guided_enemy_health, "guided recommendation does not execute the final attack")
	_assert_true(String(battle.recommended_action_button.text).begins_with("2단계"), "guided recommendation advances to direct target selection")
	_assert_true(bool(battle.battle_focus_panel.visible), "guided attack displays the source-to-target route strip")
	var auto_test_player: Dictionary = battle.player.duplicate(true)
	var auto_test_opponent: Dictionary = battle.opponent.duplicate(true)
	battle.selected_attacker = -1
	battle.opponent["field"] = [_power_test_unit("자동 대상", 1, 1)]
	var auto_enemy_health := int(Dictionary(battle.opponent["field"][0]).get("health", 0))
	await battle._on_opponent_unit_pressed(0)
	_assert_eq(int(battle.opponent["field"].size()), 0, "clicking an enemy card with no attacker selected auto-executes the best player attack")
	_assert_eq(int(battle.selected_attacker), -1, "auto enemy attack clears attacker selection after resolving")
	_assert_true(auto_enemy_health > 0, "enemy test target starts alive")
	battle.opponent["field"] = []
	battle.opponent["health"] = 5
	battle.player["field"] = [_power_test_unit("자동 영웅 공격자", 2, 3)]
	battle.player["field"][0]["can_attack"] = true
	battle.selected_attacker = -1
	battle._refresh_ui()
	_assert_true(not bool(battle.hero_attack_button.disabled), "enemy hero target remains clickable before selecting an attacker")
	_assert_true(battle.opponent_field_slots.size() > 0 and battle.opponent_field_slots[0] is Button and not bool((battle.opponent_field_slots[0] as Button).disabled), "empty enemy board slots also act as loose direct-attack hit areas")
	await battle._attack_opponent_hero()
	_assert_eq(int(battle.opponent.get("health", 0)), 3, "clicking enemy hero with no attacker selected auto-selects and attacks the hero")
	_assert_eq(int(battle.selected_attacker), -1, "auto hero attack also clears attacker selection")
	battle.player = auto_test_player.duplicate(true)
	battle.opponent = auto_test_opponent.duplicate(true)
	battle.selected_attacker = -1
	battle.game_over = false
	battle.battle_finished = false
	battle.input_locked = false
	battle._refresh_ui()

	battle.selected_attacker = -1
	main.current_run["current_node_index"] = 4
	battle._refresh_ui()
	_assert_eq(String(battle._battle_guidance_mode()), "hint", "boss battle reduces recommendation to a positional hint")
	_assert_true(String(battle.recommended_action_button.text).begins_with("힌트 위치 보기"), "boss recommendation is labeled as a hint")
	battle._on_recommended_action_pressed()
	_assert_eq(int(battle.selected_attacker), -1, "hint mode does not select or execute an attacker")
	_assert_eq(int(battle.opponent.get("health", 0)), guided_enemy_health, "hint mode leaves combat state unchanged")
	main.current_run["current_node_index"] = original_node_index
	battle._refresh_ui()

func _test_hand_card_drag_and_target_line(main: Node) -> void:
	var battle = main.battle_screen
	if battle == null or not is_instance_valid(battle):
		return
	
	_assert_true(not battle.is_dragging_hand_card, "battle starts with hand card drag inactive")
	_assert_true(battle.battle_fx_layer != null, "battle screen has fx layer")
	
	battle._start_hand_card_drag(0, Vector2(200, 500))
	_assert_true(battle.is_dragging_hand_card, "hand card drag activates")
	_assert_true(battle.drag_preview_card != null, "drag preview card created")
	_assert_true(battle.battle_fx_layer.drag_line != null, "drag target line created on fx layer")
	_assert_true(battle.battle_fx_layer.drag_target_reticle != null, "drag reticle created on fx layer")
	
	battle._update_hand_card_drag(Vector2(200, 300), 0)
	_assert_true(battle.battle_fx_layer.drag_line.points.size() > 0, "drag target line has curve points")
	
	battle._finish_hand_card_drag(Vector2(200, 500), 0)
	_assert_true(not battle.is_dragging_hand_card, "hand card drag finishes cleanly")
	_assert_true(battle.drag_preview_card == null, "drag preview card cleaned up")
	_assert_true(battle.battle_fx_layer.drag_line == null, "drag line cleaned up")
	_assert_true(battle.battle_fx_layer.drag_target_reticle == null, "drag reticle cleaned up")

func _test_race_powers(main: Node) -> void:
	var battle = main.battle_screen
	var original_run: Dictionary = main.current_run.duplicate(true)
	var original_player: Dictionary = battle.player.duplicate(true)
	var original_opponent: Dictionary = battle.opponent.duplicate(true)
	main.set_meta("disable_battle_ui_rerender", true)

	main.current_run = original_run.duplicate(true)
	main.current_run["race_id"] = "human"
	main.current_run["deck_ids"] = []
	main.current_run["relic_ids"] = []
	battle.player = _power_test_side("왕국 지휘관", 2)
	battle.player["field"] = [_power_test_unit("전열 병사", 1, 2)]
	battle.opponent = _power_test_side("표적", 0)
	battle._reset_battle_state()
	battle._on_race_power_pressed()
	_assert_true(bool(battle.battle_state.get("race_power_used", false)), "human power is marked used")
	_assert_true(bool(Dictionary(battle.battle_state.get("battle_objective", {})).get("completed", false)), "first battle power completes its teaching objective")
	_assert_true(not Dictionary(main.current_run.get("battle_snapshot", {})).get("battle_objective", {}).is_empty(), "battle snapshot preserves objective progress")
	_assert_eq(battle.player.field.size(), 2, "human power summons one guard")
	_assert_eq(int(battle.player.field[0].get("attack", 0)), 2, "human power buffs existing ally attack")
	_assert_true(bool(battle.player.field[1].get("can_attack", false)), "human guard can attack immediately")
	_assert_eq(int(battle.player.get("mana", 0)), 2, "human power spends no mana")
	_assert_eq(int(battle.battle_state.get("cards_played_this_turn", -1)), 0, "race power does not count as a card")
	_assert_eq(int(battle.battle_state.get("combo_streak", -1)), 0, "race power does not advance combo")
	var human_field_size: int = battle.player.field.size()
	battle._on_race_power_pressed()
	_assert_eq(battle.player.field.size(), human_field_size, "race power cannot be used twice")

	main.current_run = original_run.duplicate(true)
	main.current_run["race_id"] = "elf"
	main.current_run["deck_ids"] = []
	main.current_run["relic_ids"] = []
	battle.player = _power_test_side("숲의 인도자", 1)
	battle.player["deck"] = [main.card_db.get_card("elf_ranger"), main.card_db.get_card("forest_archer")]
	battle.opponent = _power_test_side("표적", 0)
	battle._reset_battle_state()
	battle._on_race_power_pressed()
	_assert_eq(battle.player.hand.size(), 2, "elf power draws two cards")
	_assert_eq(int(battle.player.get("mana", 0)), 3, "elf power grants two mana")

	main.current_run = original_run.duplicate(true)
	main.current_run["race_id"] = "undead"
	main.current_run["deck_ids"] = []
	main.current_run["relic_ids"] = []
	battle.player = _power_test_side("묘지의 군주", 2)
	battle.player["field"] = [_power_test_unit("희생 제물", 1, 1)]
	battle.opponent = _power_test_side("표적", 0)
	battle.opponent["health"] = 10
	battle.opponent["max_health"] = 10
	battle._reset_battle_state()
	battle._on_race_power_pressed()
	_assert_eq(int(battle.opponent.get("health", 0)), 7, "undead power deals three hero damage")
	_assert_eq(battle.player.field.size(), 1, "undead power replaces sacrifice with a skeleton")
	_assert_eq(String(battle.player.field[0].get("id", "")), "grave_skeleton_token", "undead power summons its token")
	_assert_true(bool(battle.player.field[0].get("can_attack", false)), "undead skeleton can attack immediately")

	battle.player = _power_test_side("묘지의 군주", 2)
	battle.opponent = _power_test_side("표적", 0)
	battle._reset_battle_state()
	_assert_true(not battle._can_use_race_power(), "undead power requires an ally to sacrifice")
	battle._on_race_power_pressed()
	_assert_true(not bool(battle.battle_state.get("race_power_used", false)), "blocked undead power remains unused")

	main.current_run = original_run
	battle.player = original_player
	battle.opponent = original_opponent
	battle._reset_battle_state()
	main.remove_meta("disable_battle_ui_rerender")

func _power_test_side(display_name: String, mana: int) -> Dictionary:
	return {
		"name": display_name,
		"health": 26,
		"max_health": 26,
		"mana": mana,
		"max_mana": mana,
		"hand": [],
		"deck": [],
		"discard_pile": [],
		"field": [],
		"corpse_explosion_stacks": 0,
		"curses": 0,
		"ritual_stacks": 0,
	}

func _power_test_unit(display_name: String, attack: int, health: int) -> Dictionary:
	return {
		"id": "power_test_unit",
		"name": display_name,
		"race": "중립",
		"attr": "대지",
		"attack": attack,
		"health": health,
		"max_health": health,
		"can_attack": false,
	}

func _test_secondary_screens(main: Node) -> void:
	main.current_run["pending_card_reward"] = {"choices": ["militia"], "gold_reward": 0}
	main._show_card_reward()
	_assert_eq(String(main.active_screen), "reward", "reward screen opens")
	_assert_true(main.active_screen_controller != null, "reward screen controller is retained")

	main.current_run["pending_event"] = main.event_service.roll_event()
	main._show_event()
	_assert_eq(String(main.active_screen), "event", "event screen opens")

	main.current_run["pending_shop"] = main.shop_run_service.generate_shop_state({
		"roll_card_choices": Callable(main, "_roll_card_choices"),
		"random_relic": Callable(main.relic_service, "random_relic"),
		"relic_ids": main.current_run.get("relic_ids", []),
	})
	main._show_shop()
	_assert_eq(String(main.active_screen), "shop", "shop screen opens")

	main._show_rest()
	_assert_eq(String(main.active_screen), "rest", "rest screen opens")

	main._show_collection()
	_assert_eq(String(main.active_screen), "collection", "collection screen opens")

	main._show_settings()
	_assert_eq(String(main.active_screen), "settings", "settings screen opens")

	main._show_compendium()
	_assert_eq(String(main.active_screen), "compendium", "compendium screen opens")

	main._show_meta_upgrade()
	_assert_eq(String(main.active_screen), "meta_upgrade", "meta upgrade screen opens")

	main._show_run_result(false)
	_assert_eq(String(main.active_screen), "run_result", "run result screen opens")

func _test_continue_run_routes(main: Node) -> void:
	var acts: Array[Dictionary] = main.run_generator.load_acts()
	var run_data: Dictionary = main.run_store.create_new_run(acts, main.run_generator.starter_deck(), 50, 100)

	run_data.erase("race_id")
	run_data["pending_card_reward"] = {"choices": ["militia"], "gold_reward": 0}
	main.current_run = run_data.duplicate(true)
	main._continue_run()
	_assert_eq(String(main.active_screen), "reward", "continue_run routes pending reward")
	_assert_eq(main._current_race_id(), "human", "legacy run without race falls back to human")

	run_data = main.run_store.create_new_run(acts, main.run_generator.starter_deck("elf"), 50, 100, "elf")
	run_data["pending_event"] = main.event_service.roll_event()
	main.current_run = run_data.duplicate(true)
	main._continue_run()
	_assert_eq(String(main.active_screen), "event", "continue_run routes pending event")

	run_data = main.run_store.create_new_run(acts, main.run_generator.starter_deck(), 50, 100)
	run_data["pending_shop"] = main.shop_run_service.generate_shop_state({
		"roll_card_choices": Callable(main, "_roll_card_choices"),
		"random_relic": Callable(main.relic_service, "random_relic"),
		"relic_ids": [],
	})
	main.current_run = run_data.duplicate(true)
	main._continue_run()
	_assert_eq(String(main.active_screen), "shop", "continue_run routes pending shop")

	run_data = main.run_store.create_new_run(acts, main.run_generator.starter_deck(), 50, 100)
	run_data["pending_subscreen"] = {"type": "remove_card", "reason": "이벤트", "source": "event_complete"}
	main.current_run = run_data.duplicate(true)
	main._continue_run()
	_assert_eq(String(main.active_screen), "remove_card", "continue_run routes pending remove subscreen")

	var enemy: Dictionary = main.enemy_service.pick_enemy(1, "normal")
	var player_card: Dictionary = main.card_db.get_card("militia")
	var opponent_card: Dictionary = main.card_db.get_card(String((enemy.get("deck_ids", []) as Array)[0]))
	run_data = main.run_store.create_new_run(acts, main.run_generator.starter_deck("elf"), 50, 100, "elf")
	run_data["active_enemy"] = enemy
	run_data["battle_snapshot"] = {
		"battle_tier": "normal",
		"current_player": "player",
		"selected_attacker": -1,
		"input_locked": false,
		"player": {
			"name": "플레이어",
			"health": 37,
			"max_health": 50,
			"mana": 2,
			"max_mana": 2,
			"deck": [],
			"hand": [player_card.duplicate(true)],
			"field": [],
			"corpse_explosion_stacks": 0,
			"curses": 0,
			"ritual_stacks": 0,
		},
		"opponent": {
			"name": String(enemy.get("name", "적")),
			"health": 14,
			"max_health": int(enemy.get("base_hp", 20)),
			"mana": 1,
			"max_mana": 1,
			"deck": [],
			"hand": [opponent_card.duplicate(true)],
			"field": [],
			"corpse_explosion_stacks": 0,
			"curses": 0,
			"ritual_stacks": 0,
		},
		"log_text": "복원 테스트",
		"turn_timer_left": 12.0,
		"battle_state_flags": {
			"cards_played_this_turn": 1,
			"combo_tag": "fire",
			"combo_streak": 3,
			"combo_finisher_used": true,
			"combo_finisher_tag": "fire",
			"mana_crystal_bonus": false,
			"first_card_discount_available": false,
			"necromancer_ring_used": false,
			"second_chance_used": false,
			"summon_build_started": false,
			"race_power_used": true,
		},
	}
	main.current_run = run_data.duplicate(true)
	main._continue_run()
	_assert_eq(String(main.active_screen), "battle", "continue_run routes active battle")
	_assert_eq(main._current_race_id(), "elf", "continue_run preserves selected race")
	_assert_eq(int(main.battle_screen.player.get("health", 0)), 37, "battle snapshot restores player health")
	_assert_eq(String(main.battle_screen.log_label.text), "복원 테스트", "battle snapshot restores log text")
	_assert_true(bool(main.battle_screen.battle_state.get("race_power_used", false)), "battle snapshot restores race power usage")
	_assert_true(bool(main.battle_screen.battle_state.get("combo_finisher_used", false)), "battle snapshot restores combo finisher usage")
	_assert_eq(String(main.battle_screen.battle_state.get("combo_finisher_tag", "")), "fire", "battle snapshot restores combo finisher tag")

func _test_reward_claim_advances_node(main: Node) -> void:
	var acts: Array[Dictionary] = main.run_generator.load_acts()
	var run_data: Dictionary = main.run_store.create_new_run(acts, main.run_generator.starter_deck(), 50, 100)
	var deck_before: int = (run_data.get("deck_ids", []) as Array).size()
	run_data["pending_card_reward"] = {
		"choices": ["militia"],
		"gold_reward": 0,
		"bonus_relic": {},
	}
	main.current_run = run_data
	var reward_screen: RefCounted = RewardScreenScript.new(main)
	reward_screen._claim_card_reward("militia")
	_assert_eq(String(main.active_screen), "map", "claiming reward returns to map")
	_assert_true(main.active_screen_controller != null, "claiming reward rebuilds map controller")
	_assert_eq(int(main.current_run.get("current_node_index", -1)), 1, "claiming reward advances node")
	_assert_eq((main.current_run.get("deck_ids", []) as Array).size(), deck_before + 1, "claiming reward adds card to deck")
	_assert_true(Dictionary(main.current_run.get("pending_card_reward", {})).is_empty(), "claiming reward clears pending reward")

func _test_build_delta_summary(main: Node) -> void:
	var summary: Dictionary = main._build_delta_summary(main.card_db.get_card("fireball"))
	_assert_eq(String(summary.get("primary_tag", "")), "fire", "build delta summary identifies the primary tag")
	_assert_true(String(summary.get("headline", "")).contains("화염"), "build delta summary includes readable growth headline")

func _test_race_reward_affinity(main: Node) -> void:
	var original_run: Dictionary = main.current_run.duplicate(true)
	var acts: Array[Dictionary] = main.run_generator.load_acts()
	var elf_deck: Array[String] = main.run_generator.starter_deck("elf")
	main.current_run = main.run_store.create_new_run(acts, elf_deck, 26, 85, "elf")
	(main.current_run.get("relic_ids", []) as Array).append(main.run_generator.get_starting_relic("elf"))
	var choices: Array[String] = main._roll_card_reward_choices(3, false)
	_assert_eq(choices.size(), 3, "race-aware reward still offers three cards")
	if choices.size() >= 1:
		var focused_card: Dictionary = main.card_db.get_card(choices[0])
		_assert_eq(String(focused_card.get("race", "")), "엘프", "first reward card matches selected race")
		_assert_true(main._card_build_tags(focused_card).has(main._primary_build_tag(main._current_build_scores())), "first reward card matches primary build")
	if choices.size() >= 2:
		var affinity_card: Dictionary = main.card_db.get_card(choices[1])
		_assert_eq(String(affinity_card.get("race", "")), "중립", "second reward card is a common option")
		_assert_eq(main.ui.card_race_display_name(affinity_card), "공용", "neutral data is presented as common to players")
	main.current_run = original_run

func _test_boss_victory_provides_boss_card_reward(main: Node) -> void:
	var acts: Array[Dictionary] = [{
		"id": 1,
		"name": "보스 테스트",
		"nodes": [["boss"]],
	}]
	var run_data: Dictionary = main.run_store.create_new_run(acts, main.run_generator.starter_deck(), 50, 100)
	var enemy: Dictionary = main.enemy_service.pick_enemy(1, "boss")
	run_data["active_enemy"] = enemy
	main.current_run = run_data
	var battle_screen_script = load("res://src/ui/screens/battle_screen.gd")
	main.battle_screen = battle_screen_script.new(main)
	main.battle_screen.battle_tier = "boss"
	main.battle_screen.player = {"health": 42}
	main.battle_screen._finish_battle_victory()
	_assert_eq(String(main.active_screen), "reward", "boss victory redirects to card reward selection")
	var pending_reward: Dictionary = main.current_run.get("pending_card_reward", {})
	_assert_true(not pending_reward.is_empty(), "boss victory stages pending card reward")
	var choices: Array = pending_reward.get("choices", [])
	_assert_true(choices.size() > 0, "boss card is provided in reward choices")

func _test_shop_leave_advances_node(main: Node) -> void:
	var acts: Array[Dictionary] = _flow_test_acts()
	var run_data: Dictionary = main.run_store.create_new_run(acts, main.run_generator.starter_deck(), 50, 100)
	run_data["current_node_index"] = 4
	run_data["pending_shop"] = main.shop_run_service.generate_shop_state({
		"roll_card_choices": Callable(main, "_roll_card_choices"),
		"random_relic": Callable(main.relic_service, "random_relic"),
		"relic_ids": [],
	})
	main.current_run = run_data
	main.run_flow.leave_shop()
	_assert_eq(String(main.active_screen), "map", "leaving shop returns to map")
	_assert_eq(int(main.current_run.get("current_node_index", -1)), 5, "leaving shop advances node")
	_assert_true(Dictionary(main.current_run.get("pending_shop", {})).is_empty(), "leaving shop clears pending shop")

func _test_rest_complete_advances_node(main: Node) -> void:
	var acts: Array[Dictionary] = _flow_test_acts()
	var run_data: Dictionary = main.run_store.create_new_run(acts, main.run_generator.starter_deck(), 50, 100)
	run_data["current_node_index"] = 6
	main.current_run = run_data
	main.run_flow.complete_rest()
	_assert_eq(String(main.active_screen), "map", "completing rest returns to map")
	_assert_eq(int(main.current_run.get("current_node_index", -1)), 7, "completing rest advances node")

func _test_event_complete_advances_node(main: Node) -> void:
	var acts: Array[Dictionary] = _flow_test_acts()
	var run_data: Dictionary = main.run_store.create_new_run(acts, main.run_generator.starter_deck(), 50, 100)
	run_data["current_node_index"] = 2
	run_data["pending_event"] = main.event_service.roll_event()
	run_data["pending_message"] = {
		"message": "이벤트 완료",
		"callback_method": "_complete_event_and_return",
	}
	main.current_run = run_data
	main._complete_event_and_return()
	_assert_eq(String(main.active_screen), "map", "completing event returns to map")
	_assert_eq(int(main.current_run.get("current_node_index", -1)), 3, "completing event advances node")
	_assert_true(Dictionary(main.current_run.get("pending_event", {})).is_empty(), "completing event clears pending event")
	_assert_true(Dictionary(main.current_run.get("pending_message", {})).is_empty(), "completing event clears pending message")

func _flow_test_acts() -> Array[Dictionary]:
	return [{
		"id": 99,
		"name": "플로우 테스트",
		"nodes": [
			["battle"],
			["battle"],
			["event"],
			["battle"],
			["shop"],
			["elite"],
			["rest"],
			["boss"],
		],
	}]

func _assert_true(value: bool, message: String) -> void:
	_count += 1
	if not value:
		_failures.append(message)

func _assert_eq(actual, expected, message: String) -> void:
	_count += 1
	if actual != expected:
		_failures.append("%s | expected=%s actual=%s" % [message, str(expected), str(actual)])
