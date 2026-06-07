extends Control

const MAX_MANA := 10
const MAX_FIELD := 5
const START_HAND := 4
const PROFILE_PATH := "user://meta_profile.json"
const RUN_PATH := "user://run_state.json"
const CARD_DATA_PATH := "res://data/cards.json"
const CARD_ART_SHEET := preload("res://assets/card_art/season1_sample_sheet.png")
const BATTLE_CUTSCENE_SCENE := preload("res://scenes/BattleCutscene.tscn")
const BattleCardEffectsScript := preload("res://scripts/battle_card_effects.gd")
const CardDatabaseScript := preload("res://scripts/card_database.gd")
const DeckServiceScript := preload("res://scripts/deck_service.gd")
const EnemyServiceScript := preload("res://scripts/enemy_service.gd")
const EventServiceScript := preload("res://scripts/event_service.gd")
const ProfileStoreScript := preload("res://scripts/profile_store.gd")
const RelicServiceScript := preload("res://scripts/relic_service.gd")
const RewardServiceScript := preload("res://scripts/reward_service.gd")
const RunGeneratorScript := preload("res://scripts/run_generator.gd")
const RunStateScript := preload("res://scripts/run_state.gd")
const UiFactoryScript := preload("res://scripts/ui_factory.gd")
const CARD_ART_COLS := 4
const CARD_ART_ROWS := 3
const SHOP_CARD_COST := 40
const SHOP_RELIC_COST := 125
const SHOP_HEAL_COST := 60

var card_db
var deck_service
var enemy_service
var event_service
var profile_store
var relic_service
var reward_service
var run_generator
var run_store
var ui
var battle_effects

var card_defs: Array[Dictionary] = []
var cards_by_id := {}
var player_profile := {}
var current_run := {}
var collection_filter := "전체"
var active_screen := "main_menu"
var pending_return_screen := "map"

var root_box: VBoxContainer
var root_scroll: ScrollContainer
var modal_layer: Control
var battle_cutscene

var status_label: Label
var opponent_info: Label
var opponent_field_box: HBoxContainer
var hero_attack_button: Button
var player_field_box: HBoxContainer
var player_info: Label
var hand_box: HBoxContainer
var deck_count_label: Label
var deck_list_label: RichTextLabel
var log_label: RichTextLabel
var end_turn_button: Button

var player := {}
var opponent := {}
var current_player := "player"
var selected_attacker := -1
var game_over := false
var battle_finished := false
var input_locked := false
var battle_state := {}
var battle_tier := "normal"

func _ready() -> void:
	card_db = CardDatabaseScript.new()
	deck_service = DeckServiceScript.new()
	enemy_service = EnemyServiceScript.new()
	event_service = EventServiceScript.new()
	profile_store = ProfileStoreScript.new()
	relic_service = RelicServiceScript.new()
	reward_service = RewardServiceScript.new()
	run_generator = RunGeneratorScript.new()
	run_store = RunStateScript.new()
	ui = UiFactoryScript.new()
	ui.setup(CARD_ART_SHEET, CARD_ART_COLS, CARD_ART_ROWS)
	battle_effects = BattleCardEffectsScript.new()

	_build_base_ui()
	if not card_db.load_cards(CARD_DATA_PATH):
		_show_error_screen("카드 데이터 로드 실패")
		return
	if not event_service.load_events() or not enemy_service.load_enemies() or not relic_service.load_relics():
		_show_error_screen("런 데이터 로드 실패")
		return

	card_defs = card_db.card_defs
	cards_by_id = card_db.cards_by_id
	player_profile = profile_store.load_or_create(PROFILE_PATH, card_defs, deck_service, 30, 3)
	player_profile = profile_store.apply_local_debug_defaults(player_profile, card_defs)
	_save_profile()
	current_run = run_store.load_or_empty(RUN_PATH)
	_show_main_menu()

func _build_base_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.045, 0.055, 0.065, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	root_scroll = ScrollContainer.new()
	root_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_scroll.follow_focus = true
	add_child(root_scroll)

	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)

	root_box = VBoxContainer.new()
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_theme_constant_override("separation", 12)
	root_scroll.add_child(root_box)
	_apply_root_layout()

	battle_cutscene = BATTLE_CUTSCENE_SCENE.instantiate()
	add_child(battle_cutscene)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_root_layout()

func _apply_root_layout() -> void:
	if root_box == null:
		return
	ui.apply_root_layout(root_box, get_viewport_rect().size)

func _clear_screen() -> void:
	if root_scroll != null:
		root_scroll.scroll_horizontal = 0
		root_scroll.scroll_vertical = 0
	for child in root_box.get_children():
		root_box.remove_child(child)
		child.queue_free()
	status_label = null
	opponent_info = null
	opponent_field_box = null
	hero_attack_button = null
	player_field_box = null
	player_info = null
	hand_box = null
	deck_count_label = null
	deck_list_label = null
	log_label = null
	end_turn_button = null
	_clear_modal()

func _clear_modal() -> void:
	for child in modal_layer.get_children():
		modal_layer.remove_child(child)
		child.queue_free()

func _save_profile() -> void:
	profile_store.save(PROFILE_PATH, player_profile)

func _save_run() -> void:
	if current_run.is_empty():
		run_store.clear(RUN_PATH)
	else:
		run_store.save(RUN_PATH, current_run)

func _clear_run() -> void:
	current_run = {}
	run_store.clear(RUN_PATH)

func _show_error_screen(message: String) -> void:
	_clear_screen()
	var body: VBoxContainer = ui.begin_screen(root_box, "CARD DRAFT")
	body.add_child(_make_label(message, 20, Color(1.0, 0.65, 0.65, 1.0)))

func _show_main_menu() -> void:
	active_screen = "main_menu"
	_clear_screen()
	var compact := _is_compact_layout()
	var body: VBoxContainer = _begin_menu_screen("CARD DRAFT")
	var hub: BoxContainer = ui.make_responsive_box(compact, 14)
	body.add_child(hub)

	var showcase := _make_responsive_panel(Color(0.105, 0.12, 0.145, 1.0), 420)
	hub.add_child(showcase)
	var showcase_box := VBoxContainer.new()
	showcase_box.add_theme_constant_override("separation", 12)
	showcase.add_child(showcase_box)
	showcase_box.add_child(_make_label("RUN BUILD PROTOTYPE", 13, Color(0.82, 0.88, 0.95, 1.0)))
	showcase_box.add_child(_make_label("약한 스타터 덱에서 시작해 빌드를 완성하세요", 20, Color(1.0, 0.88, 0.55, 1.0)))

	var art_row := HBoxContainer.new()
	art_row.alignment = BoxContainer.ALIGNMENT_CENTER
	art_row.add_theme_constant_override("separation", 6)
	showcase_box.add_child(art_row)
	art_row.add_child(ui.make_showcase_card("인간", 0, compact))
	art_row.add_child(ui.make_showcase_card("엘프", 5, compact))
	art_row.add_child(ui.make_showcase_card("언데드", 10, compact))

	var stat_row := HBoxContainer.new()
	stat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stat_row.add_theme_constant_override("separation", 6)
	showcase_box.add_child(stat_row)
	stat_row.add_child(ui.make_stat_tile("카드", "%d종" % card_defs.size(), Color(0.22, 0.42, 0.34, 1.0), compact))
	stat_row.add_child(ui.make_stat_tile("유물", "%d개" % relic_service.relics.size(), Color(0.48, 0.34, 0.18, 1.0), compact))
	stat_row.add_child(ui.make_stat_tile("영혼석", "%d" % int(player_profile.get("soul_stones", 0)), Color(0.34, 0.28, 0.52, 1.0), compact))

	if not current_run.is_empty():
		var run_text := "Act %d | 체력 %d/%d | 골드 %d | 덱 %d장" % [
			int(current_run.get("act", 1)),
			int(current_run.get("hp", 0)),
			int(current_run.get("max_hp", 0)),
			int(current_run.get("gold", 0)),
			(current_run.get("deck_ids", []) as Array).size(),
		]
		showcase_box.add_child(ui.make_status_badge("이어하기", run_text, Color(0.18, 0.38, 0.28, 1.0)))

	var menu_panel := _make_responsive_panel(Color(0.13, 0.15, 0.18, 1.0), 360)
	hub.add_child(menu_panel)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	menu_panel.add_child(menu)
	menu.add_child(_make_label("COMMAND", 13, Color(0.82, 0.88, 0.95, 1.0)))
	if not current_run.is_empty():
		_add_menu_button(menu, "이어하기", "_continue_run", Color(0.18, 0.45, 0.28, 1.0))
	_add_menu_button(menu, "새 런 시작", "_start_new_run", Color(0.16, 0.38, 0.54, 1.0))
	_add_menu_button(menu, "메타 강화", "_show_meta_upgrade", Color(0.34, 0.28, 0.52, 1.0))
	_add_menu_button(menu, "카드 도감", "_show_compendium", Color(0.22, 0.31, 0.38, 1.0))
	_add_menu_button(menu, "카드 보관함", "_show_collection", Color(0.22, 0.31, 0.38, 1.0))
	_add_menu_button(menu, "설정", "_show_settings", Color(0.22, 0.31, 0.38, 1.0))
	_add_menu_button(menu, "종료", "_quit_game", Color(0.42, 0.18, 0.18, 1.0))

	body.add_child(_make_label("MVP 구조: Act 1 국경지대 -> Act 2 죽음의 성", 14, Color(0.78, 0.82, 0.9, 1.0)))

func _start_new_run() -> void:
	var acts: Array[Dictionary] = run_generator.load_acts()
	var upgrades := _profile_upgrades()
	var start_hp := 50 + int(upgrades.get("start_hp", 0)) * 5
	var start_gold := 100 + int(upgrades.get("start_gold", 0)) * 20
	current_run = run_store.create_new_run(acts, run_generator.starter_deck(), start_hp, start_gold)
	_save_run()
	_show_map()

func _continue_run() -> void:
	current_run = run_store.load_or_empty(RUN_PATH)
	if current_run.is_empty():
		_show_main_menu()
		return
	if String(current_run.get("result", "")) == "win":
		_show_run_result(true)
		return
	if String(current_run.get("result", "")) == "loss":
		_show_run_result(false)
		return
	if not Dictionary(current_run.get("pending_card_reward", {})).is_empty():
		_show_card_reward()
		return
	if not Dictionary(current_run.get("pending_event", {})).is_empty():
		_show_event()
		return
	if not Dictionary(current_run.get("pending_shop", {})).is_empty():
		_show_shop()
		return
	if not Dictionary(current_run.get("active_enemy", {})).is_empty():
		_start_battle()
		return
	_show_map()

func _show_meta_upgrade() -> void:
	active_screen = "meta_upgrade"
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("메타 강화")
	var panel := _make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 640)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var upgrades := _profile_upgrades()
	box.add_child(_make_label("영혼석 %d" % int(player_profile.get("soul_stones", 0)), 20, Color(1.0, 0.88, 0.55, 1.0)))
	box.add_child(_make_label("튼튼한 몸: 시작 최대 체력 +5 (현재 %d)" % int(upgrades.get("start_hp", 0)), 15, Color(0.92, 0.94, 0.98, 1.0)))
	box.add_child(_make_label("왕실 지원금: 시작 골드 +20 (현재 %d)" % int(upgrades.get("start_gold", 0)), 15, Color(0.92, 0.94, 0.98, 1.0)))
	box.add_child(_make_label("두 번째 기회: 런당 1회 체력 1로 버팀 (현재 %d)" % int(upgrades.get("second_chance", 0)), 15, Color(0.92, 0.94, 0.98, 1.0)))
	_add_menu_button(box, "튼튼한 몸 강화", "_upgrade_start_hp", Color(0.18, 0.4, 0.24, 1.0))
	_add_menu_button(box, "왕실 지원금 강화", "_upgrade_start_gold", Color(0.34, 0.28, 0.52, 1.0))
	_add_menu_button(box, "두 번째 기회 강화", "_upgrade_second_chance", Color(0.46, 0.26, 0.18, 1.0))
	_add_menu_button(box, "메인으로", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))

func _show_compendium() -> void:
	active_screen = "compendium"
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("카드 도감")
	var panel := _make_screen_panel(Color(0.105, 0.115, 0.135, 1.0), 760)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_make_label("현재 카드 %d종 / 유물 %d개" % [card_defs.size(), relic_service.relics.size()], 16, Color(0.92, 0.94, 0.98, 1.0)))
	for card in card_defs:
		box.add_child(_make_label("%s [%s/%s] 비용 %d" % [String(card.get("name", "")), String(card.get("race", "")), String(card.get("attr", "")), int(card.get("cost", 0))], 14, Color(0.84, 0.88, 0.95, 1.0)))
	box.add_child(HSeparator.new())
	for relic in relic_service.relics:
		box.add_child(_make_label("%s - %s" % [String(relic.get("name", "")), String(relic.get("text", ""))], 14, Color(1.0, 0.88, 0.55, 1.0)))
	_add_menu_button(box, "메인으로", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))

func _upgrade_start_hp() -> void:
	var upgrades: Dictionary = player_profile.get("upgrades", {})
	var level := int(upgrades.get("start_hp", 0))
	var cost := 50 + level * 25
	if level >= 3 or int(player_profile.get("soul_stones", 0)) < cost:
		_show_meta_upgrade()
		return
	player_profile["soul_stones"] = int(player_profile.get("soul_stones", 0)) - cost
	upgrades["start_hp"] = level + 1
	player_profile["upgrades"] = upgrades
	_save_profile()
	_show_meta_upgrade()

func _upgrade_start_gold() -> void:
	var upgrades: Dictionary = player_profile.get("upgrades", {})
	var level := int(upgrades.get("start_gold", 0))
	var cost := 50 + level * 25
	if level >= 3 or int(player_profile.get("soul_stones", 0)) < cost:
		_show_meta_upgrade()
		return
	player_profile["soul_stones"] = int(player_profile.get("soul_stones", 0)) - cost
	upgrades["start_gold"] = level + 1
	player_profile["upgrades"] = upgrades
	_save_profile()
	_show_meta_upgrade()

func _upgrade_second_chance() -> void:
	var upgrades: Dictionary = _profile_upgrades()
	var level := int(upgrades.get("second_chance", 0))
	var cost := 150
	if level >= 1 or int(player_profile.get("soul_stones", 0)) < cost:
		_show_meta_upgrade()
		return
	player_profile["soul_stones"] = int(player_profile.get("soul_stones", 0)) - cost
	upgrades["second_chance"] = 1
	player_profile["upgrades"] = upgrades
	_save_profile()
	_show_meta_upgrade()

func _show_map() -> void:
	active_screen = "map"
	_clear_screen()
	var compact := _is_compact_layout()
	var body: VBoxContainer = _begin_menu_screen(String(_current_act().get("name", "맵")))
	body.add_child(_make_run_summary_panel())

	var panel := _make_screen_panel(Color(0.105, 0.115, 0.135, 1.0), 760 if not compact else 420)
	body.add_child(panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	panel.add_child(list)

	var current_act := _current_act()
	var nodes: Array = current_act.get("nodes", [])
	var current_index := int(current_run.get("current_node_index", 0))
	for index in range(nodes.size()):
		var node_type := String(nodes[index])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		list.add_child(row)
		var label := _make_label("%d. %s" % [index + 1, _node_type_name(node_type)], 16, Color(0.9, 0.92, 0.98, 1.0))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(120, 40)
		if index < current_index:
			button.text = "완료"
			button.disabled = true
			ui.style_button(button, Color(0.15, 0.18, 0.22, 1.0))
		elif index == current_index:
			button.text = "진입"
			ui.style_button(button, Color(0.18, 0.34, 0.48, 1.0))
			button.pressed.connect(Callable(self, "_enter_current_node"))
		else:
			button.text = "잠김"
			button.disabled = true
			ui.style_button(button, Color(0.15, 0.18, 0.22, 1.0))
		row.add_child(button)

	var relic_panel := _make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 760 if not compact else 420)
	body.add_child(relic_panel)
	var relic_box := VBoxContainer.new()
	relic_box.add_theme_constant_override("separation", 8)
	relic_panel.add_child(relic_box)
	relic_box.add_child(_make_label("보유 유물", 18, Color(1.0, 0.88, 0.55, 1.0)))
	if (current_run.get("relic_ids", []) as Array).is_empty():
		relic_box.add_child(_make_label("아직 유물이 없습니다.", 14, Color(0.82, 0.88, 0.95, 1.0)))
	else:
		for relic_id in current_run.get("relic_ids", []):
			var relic: Dictionary = relic_service.get_relic(String(relic_id))
			relic_box.add_child(_make_label("%s - %s" % [String(relic.get("name", relic_id)), String(relic.get("text", ""))], 14, Color(0.9, 0.92, 0.98, 1.0)))

	var actions: BoxContainer = ui.make_action_bar(compact, 10)
	body.add_child(actions)
	_add_menu_button(actions, "메인 메뉴", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))
	_add_menu_button(actions, "런 포기", "_abandon_run", Color(0.42, 0.18, 0.18, 1.0))

func _enter_current_node() -> void:
	var node: Dictionary = run_store.current_node(current_run)
	match String(node.get("type", "")):
		"battle":
			_prepare_battle("normal")
		"elite":
			_prepare_battle("elite")
		"boss":
			_prepare_battle("boss")
		"event":
			current_run["pending_event"] = event_service.roll_event()
			_save_run()
			_show_event()
		"shop":
			current_run["pending_shop"] = _generate_shop_state()
			_save_run()
			_show_shop()
		"rest":
			_show_rest()

func _prepare_battle(tier: String) -> void:
	var enemy: Dictionary = enemy_service.pick_enemy(int(current_run.get("act", 1)), tier)
	if enemy.is_empty():
		_show_message("적 데이터를 준비하지 못했습니다. 런을 다시 시작해주세요.", "_show_main_menu")
		return
	current_run["active_enemy"] = enemy
	_save_run()
	_start_battle()

func _start_battle() -> void:
	active_screen = "battle"
	_clear_screen()
	var enemy: Dictionary = current_run.get("active_enemy", {})
	if enemy.is_empty():
		_show_map()
		return
	battle_tier = String(enemy.get("tier", "normal"))
	player = _new_side("플레이어", card_db.build_deck_from_ids(current_run.get("deck_ids", [])), int(current_run.get("hp", 50)), int(current_run.get("max_hp", 50)))
	opponent = _new_side(String(enemy.get("name", "적")), card_db.build_deck_from_ids(enemy.get("deck_ids", [])), int(enemy.get("base_hp", 20)), int(enemy.get("base_hp", 20)))
	_draw_cards(player, START_HAND)
	_draw_cards(opponent, START_HAND)
	current_player = "player"
	selected_attacker = -1
	game_over = false
	battle_finished = false
	input_locked = false
	battle_state = {
		"draw_cards": Callable(self, "_draw_cards"),
		"log": Callable(self, "_add_log"),
		"cleanup_dead_units": Callable(self, "_cleanup_dead_units"),
		"calculate_damage": Callable(self, "_calculate_damage"),
		"relic_service": relic_service,
		"run_data": current_run,
		"max_health": int(current_run.get("max_hp", 50)),
		"player_state": player,
		"first_card_discount_available": false,
		"mana_crystal_bonus": false,
		"cards_played_this_turn": 0,
		"necromancer_ring_used": false,
		"second_chance_used": false,
	}
	_build_battle_ui()
	_start_turn(player, true)
	relic_service.on_battle_start(current_run, player, battle_state)
	player.health = int(current_run.get("hp", player.health))
	_add_log("%s 전투 시작. 적 영웅 체력을 0으로 만드세요." % _node_type_name(String(run_store.current_node(current_run).get("type", "battle"))))
	_refresh_ui()

func _new_side(display_name: String, deck: Array, hp: int, max_hp: int) -> Dictionary:
	deck.shuffle()
	return {
		"name": display_name,
		"health": hp,
		"max_health": max_hp,
		"mana": 0,
		"max_mana": 0,
		"deck": deck,
		"hand": [],
		"field": [],
		"corpse_explosion_stacks": 0,
	}

func _build_battle_ui() -> void:
	_add_title("CARD DRAFT")
	status_label = _make_label("", 18, Color(0.82, 0.9, 1.0, 1.0))
	root_box.add_child(status_label)

	var content_row := HBoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 14)
	root_box.add_child(content_row)

	var board_panel := _make_panel_container(Color(0.12, 0.135, 0.16, 1.0))
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(board_panel)

	var board_box := VBoxContainer.new()
	board_box.add_theme_constant_override("separation", 10)
	board_panel.add_child(board_box)

	opponent_info = _make_label("", 16, Color(1.0, 0.78, 0.78, 1.0))
	board_box.add_child(opponent_info)
	opponent_field_box = HBoxContainer.new()
	opponent_field_box.alignment = BoxContainer.ALIGNMENT_CENTER
	opponent_field_box.custom_minimum_size = Vector2(0, 124)
	board_box.add_child(opponent_field_box)

	hero_attack_button = Button.new()
	hero_attack_button.text = "상대 영웅 공격"
	hero_attack_button.custom_minimum_size = Vector2(160, 42)
	ui.style_button(hero_attack_button, Color(0.5, 0.13, 0.13, 1.0))
	hero_attack_button.pressed.connect(Callable(self, "_attack_opponent_hero"))
	board_box.add_child(hero_attack_button)
	board_box.add_child(HSeparator.new())

	player_field_box = HBoxContainer.new()
	player_field_box.alignment = BoxContainer.ALIGNMENT_CENTER
	player_field_box.custom_minimum_size = Vector2(0, 124)
	board_box.add_child(player_field_box)
	player_info = _make_label("", 16, Color(0.78, 0.9, 1.0, 1.0))
	board_box.add_child(player_info)
	board_box.add_child(_make_label("내 손패", 16, Color(0.96, 0.88, 0.55, 1.0)))

	hand_box = HBoxContainer.new()
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_box.custom_minimum_size = Vector2(0, 166)
	board_box.add_child(hand_box)

	end_turn_button = Button.new()
	end_turn_button.text = "턴 종료"
	end_turn_button.custom_minimum_size = Vector2(150, 44)
	ui.style_button(end_turn_button, Color(0.18, 0.34, 0.48, 1.0))
	end_turn_button.pressed.connect(Callable(self, "_on_end_turn_pressed"))
	board_box.add_child(end_turn_button)

	var side_panel := _make_panel_container(Color(0.105, 0.115, 0.135, 1.0))
	side_panel.custom_minimum_size = Vector2(330, 0)
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(side_panel)
	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 10)
	side_panel.add_child(side_box)

	side_box.add_child(_make_label("내 덱", 20, Color(0.96, 0.88, 0.55, 1.0)))
	deck_count_label = _make_label("", 14, Color(0.82, 0.9, 1.0, 1.0))
	side_box.add_child(deck_count_label)

	var deck_scroll := ScrollContainer.new()
	deck_scroll.custom_minimum_size = Vector2(0, 230)
	deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_box.add_child(deck_scroll)

	deck_list_label = RichTextLabel.new()
	deck_list_label.custom_minimum_size = Vector2(290, 220)
	deck_list_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_list_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_list_label.bbcode_enabled = false
	deck_list_label.fit_content = false
	deck_list_label.scroll_active = false
	deck_list_label.add_theme_color_override("default_color", Color(0.9, 0.92, 0.95, 1.0))
	deck_scroll.add_child(deck_list_label)

	side_box.add_child(_make_label("게임 로그", 20, Color(0.96, 0.88, 0.55, 1.0)))
	log_label = RichTextLabel.new()
	log_label.custom_minimum_size = Vector2(0, 180)
	log_label.bbcode_enabled = false
	log_label.fit_content = false
	log_label.add_theme_color_override("default_color", Color(0.9, 0.92, 0.95, 1.0))
	side_box.add_child(log_label)

func _start_turn(side: Dictionary, is_player_turn: bool) -> void:
	side.max_mana = min(MAX_MANA, int(side.max_mana) + 1)
	side.mana = side.max_mana
	if is_player_turn and bool(battle_state.get("mana_crystal_bonus", false)):
		side.mana += 1
		side.max_mana += 1
		battle_state["mana_crystal_bonus"] = false
	for unit in side.field:
		unit.can_attack = true
	_draw_cards(side, 1)
	if is_player_turn:
		battle_state["cards_played_this_turn"] = 0
		relic_service.on_turn_start(current_run, battle_state, player)
	_add_log("%s 턴 시작: 마나 %d/%d" % [side.name, side.mana, side.max_mana])

func _draw_cards(side: Dictionary, count: int) -> void:
	for i in range(count):
		if side.deck.is_empty():
			side.health -= 1
			_add_log("%s 덱 고갈: 피해 1" % side.name)
			continue
		side.hand.append(side.deck.pop_back())

func _on_hand_card_pressed(index: int) -> void:
	if input_locked or game_over or current_player != "player":
		return
	if index < 0 or index >= player.hand.size():
		return
	var card: Dictionary = player.hand[index]
	var cost: int = relic_service.modify_card_cost(current_run, battle_state, card, "player")
	if cost > int(player.mana):
		_add_log("마나가 부족합니다.")
		return
	if String(card.get("type", "")) == "unit" and player.field.size() >= MAX_FIELD:
		_add_log("필드가 가득 찼습니다.")
		return
	if String(card.get("type", "")) == "equipment" and player.field.is_empty():
		_add_log("장착할 아군 유닛이 없습니다.")
		return
	player.mana -= cost
	player.hand.remove_at(index)
	relic_service.consume_card_discount(battle_state)
	battle_state["cards_played_this_turn"] = int(battle_state.get("cards_played_this_turn", 0)) + 1
	battle_effects.play_card(player, opponent, card, _battle_effect_context())
	relic_service.on_card_played(current_run, battle_state, player)
	_check_game_over()
	_refresh_ui()

func _battle_effect_context() -> Dictionary:
	return {
		"draw_cards": Callable(self, "_draw_cards"),
		"log": Callable(self, "_add_log"),
		"cleanup_dead_units": Callable(self, "_cleanup_dead_units"),
		"calculate_damage": Callable(self, "_calculate_damage"),
		"relic_service": relic_service,
		"run_data": current_run,
		"max_health": int(current_run.get("max_hp", 50)),
	}

func _calculate_damage(card_or_unit: Dictionary, is_spell: bool, owner_state: Dictionary, base_damage: int) -> int:
	return base_damage + relic_service.damage_bonus(current_run, card_or_unit, is_spell, owner_state)

func _on_player_unit_pressed(index: int) -> void:
	if input_locked or game_over or current_player != "player":
		return
	if index < 0 or index >= player.field.size():
		return
	if not bool(player.field[index].can_attack):
		_add_log("이 유닛은 이번 턴 공격할 수 없습니다.")
		return
	selected_attacker = index
	_add_log("%s 공격 대상 선택 중" % player.field[index].name)
	_refresh_ui()

func _on_opponent_unit_pressed(index: int) -> void:
	if input_locked or game_over or current_player != "player" or selected_attacker == -1:
		return
	if index < 0 or index >= opponent.field.size():
		return
	await _combat(player, opponent, selected_attacker, index)
	selected_attacker = -1
	_check_game_over()
	_refresh_ui()

func _attack_opponent_hero() -> void:
	if input_locked or game_over or current_player != "player" or selected_attacker == -1:
		return
	var attacker: Dictionary = player.field[selected_attacker]
	var damage := _calculate_damage(attacker, false, player, int(attacker.attack))
	input_locked = true
	_refresh_ui()
	await _play_hero_cutscene(attacker, opponent.name, damage)
	damage = relic_service.mitigate_hero_damage(current_run, battle_state, damage, false)
	opponent.health -= damage
	attacker.can_attack = false
	_add_log("%s가 상대 영웅에게 피해 %d" % [attacker.name, damage])
	selected_attacker = -1
	input_locked = false
	_check_game_over()
	_refresh_ui()

func _combat(attacker_side: Dictionary, defender_side: Dictionary, attacker_index: int, defender_index: int) -> void:
	var attacker: Dictionary = attacker_side.field[attacker_index]
	var defender: Dictionary = defender_side.field[defender_index]
	var attack_damage := _calculate_damage(attacker, false, attacker_side, int(attacker.attack))
	var defense_damage := _calculate_damage(defender, false, defender_side, int(defender.attack))
	input_locked = true
	_refresh_ui()
	await _play_unit_cutscene(attacker, defender)
	attacker.health -= defense_damage
	defender.health -= attack_damage
	attacker.can_attack = false
	_add_log("%s(%d/%d) vs %s(%d/%d)" % [attacker.name, attack_damage, attacker.health, defender.name, defense_damage, defender.health])
	_cleanup_dead_units(attacker_side, defender_side)
	input_locked = false

func _play_unit_cutscene(attacker: Dictionary, defender: Dictionary) -> void:
	if bool(player_profile["settings"]["battle_cutscene"]):
		await battle_cutscene.play_unit_battle(attacker, defender)

func _play_hero_cutscene(attacker: Dictionary, defender_name: String, damage: int) -> void:
	if bool(player_profile["settings"]["battle_cutscene"]):
		await battle_cutscene.play_hero_attack(attacker, defender_name, damage)

func _cleanup_dead_units(side_a: Dictionary, side_b: Dictionary) -> void:
	_cleanup_side_dead(side_a, side_b)
	_cleanup_side_dead(side_b, side_a)

func _cleanup_side_dead(owner: Dictionary, enemy: Dictionary) -> void:
	for i in range(owner.field.size() - 1, -1, -1):
		if int(owner.field[i].health) <= 0:
			var dead_unit: Dictionary = owner.field[i]
			owner.field.remove_at(i)
			battle_effects.on_unit_died(dead_unit, owner, enemy, _battle_effect_context())
			if owner == player:
				relic_service.on_ally_unit_died(current_run, battle_state, dead_unit)
			_add_log("%s 사망" % String(dead_unit.get("name", "")))

func _on_end_turn_pressed() -> void:
	if input_locked or game_over or current_player != "player":
		return
	current_player = "opponent"
	selected_attacker = -1
	_start_turn(opponent, false)
	_refresh_ui()
	var ai_wait := 0.5
	if bool(player_profile["settings"]["fast_ai"]):
		ai_wait = 0.08
	await get_tree().create_timer(ai_wait).timeout
	await _run_ai_turn()

func _run_ai_turn() -> void:
	if game_over:
		return
	var played := true
	while played:
		played = false
		for i in range(opponent.hand.size()):
			var card: Dictionary = opponent.hand[i]
			if int(card.get("cost", 0)) <= int(opponent.mana):
				if String(card.get("type", "")) == "unit" and opponent.field.size() >= MAX_FIELD:
					continue
				if String(card.get("type", "")) == "equipment" and opponent.field.is_empty():
					continue
				opponent.mana -= int(card.cost)
				opponent.hand.remove_at(i)
				battle_effects.play_card(opponent, player, card, _battle_effect_context())
				played = true
				if not bool(player_profile["settings"]["fast_ai"]):
					await get_tree().create_timer(0.2).timeout
				break

	var i := 0
	while i < opponent.field.size():
		if not bool(opponent.field[i].can_attack):
			i += 1
			continue
		if not player.field.is_empty():
			await _combat(opponent, player, i, 0)
		elif i < opponent.field.size():
			var unit: Dictionary = opponent.field[i]
			var damage := _calculate_damage(unit, false, opponent, int(unit.attack))
			input_locked = true
			_refresh_ui()
			await _play_hero_cutscene(unit, player.name, damage)
			damage = relic_service.mitigate_hero_damage(current_run, battle_state, damage, true)
			player.health -= damage
			if damage > 0:
				relic_service.on_hero_hp_lost(current_run, battle_state, player, damage)
			unit.can_attack = false
			_add_log("%s가 내 영웅에게 피해 %d" % [unit.name, damage])
			input_locked = false
		_check_game_over()
		if game_over:
			break
		if i < opponent.field.size() and not bool(opponent.field[i].can_attack):
			i += 1

	if not game_over:
		current_player = "player"
		_start_turn(player, true)
	_refresh_ui()

func _check_game_over() -> void:
	if battle_finished:
		return
	if int(player.health) <= 0:
		var upgrades := _profile_upgrades()
		if int(upgrades.get("second_chance", 0)) > 0 and not bool(battle_state.get("second_chance_used", false)):
			battle_state["second_chance_used"] = true
			player.health = 1
			_add_log("두 번째 기회 발동: 체력 1로 버팁니다.")
			_refresh_ui()
			return
		game_over = true
		battle_finished = true
		current_run["hp"] = 0
		current_run["result"] = "loss"
		_finish_run(false)
	elif int(opponent.health) <= 0:
		game_over = true
		battle_finished = true
		current_run["hp"] = int(player.health)
		await _finish_battle_victory()

func _finish_battle_victory() -> void:
	current_run["active_enemy"] = {}
	var bonus_relic := {}
	var gold_reward := randi_range(15, 25)
	if battle_tier in ["elite", "boss"]:
		bonus_relic = relic_service.random_relic(current_run.get("relic_ids", []))
		gold_reward = randi_range(30, 50) if battle_tier == "elite" else 50
	if battle_tier == "boss":
		current_run["max_hp"] = int(current_run.get("max_hp", 0)) + 5
		current_run["hp"] = min(int(current_run.get("max_hp", 0)), int(player.health) + 5)
	else:
		current_run["hp"] = int(player.health)
	gold_reward += relic_service.victory_gold_bonus(current_run)
	current_run["gold"] = int(current_run.get("gold", 0)) + gold_reward
	current_run["pending_card_reward"] = {
		"choices": _roll_high_cost_cards(3) if battle_tier == "boss" else _roll_card_choices(3),
		"bonus_relic": bonus_relic,
		"battle_tier": battle_tier,
		"gold_reward": gold_reward,
	}
	_save_run()
	_show_card_reward()

func _show_card_reward() -> void:
	active_screen = "card_reward"
	_clear_screen()
	var reward: Dictionary = current_run.get("pending_card_reward", {})
	var body: VBoxContainer = _begin_menu_screen("전투 보상")
	body.add_child(_make_run_summary_panel())
	var panel := _make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 760)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_make_label("골드 +%d" % int(reward.get("gold_reward", 0)), 16, Color(1.0, 0.88, 0.55, 1.0)))
	box.add_child(_make_label("카드 3장 중 1장을 선택해 덱에 추가합니다.", 16, Color(0.9, 0.92, 0.98, 1.0)))
	if typeof(reward.get("bonus_relic", {})) == TYPE_DICTIONARY and not Dictionary(reward.get("bonus_relic", {})).is_empty():
		var relic: Dictionary = reward["bonus_relic"]
		box.add_child(_make_label("추가 유물 보상: %s - %s" % [String(relic.get("name", "")), String(relic.get("text", ""))], 15, Color(1.0, 0.88, 0.55, 1.0)))
	var row: BoxContainer = ui.make_responsive_box(_is_compact_layout(), 10)
	box.add_child(row)
	for card_id in reward.get("choices", []):
		if not cards_by_id.has(String(card_id)):
			continue
		row.add_child(_make_reward_choice(cards_by_id[String(card_id)]))
	_add_menu_button(box, "건너뛰기", "_skip_card_reward", Color(0.22, 0.24, 0.28, 1.0))

func _make_reward_choice(card: Dictionary) -> Control:
	var frame := _make_card_frame()
	frame.custom_minimum_size = Vector2(170, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	frame.add_child(box)
	box.add_child(_make_art_rect(int(card.get("art", 0)), Vector2(150, 102)))
	box.add_child(_make_label(String(card.get("name", "")), 15, Color(0.98, 0.98, 0.96, 1.0)))
	box.add_child(_make_label("[%d] %s/%s" % [int(card.get("cost", 0)), String(card.get("race", "")), String(card.get("attr", ""))], 13, Color(0.82, 0.88, 0.95, 1.0)))
	box.add_child(_make_label(String(card.get("text", "")), 13, Color(0.82, 0.88, 0.95, 1.0)))
	var button := Button.new()
	button.text = "선택"
	button.custom_minimum_size = Vector2(120, 40)
	ui.style_button(button, Color(0.18, 0.34, 0.48, 1.0))
	button.pressed.connect(Callable(self, "_claim_card_reward").bind(String(card.get("id", ""))))
	box.add_child(button)
	return frame

func _claim_card_reward(card_id: String) -> void:
	var reward: Dictionary = current_run.get("pending_card_reward", {})
	(current_run.get("deck_ids", []) as Array).append(card_id)
	var bonus_relic: Dictionary = reward.get("bonus_relic", {})
	if not bonus_relic.is_empty():
		var relic_id := String(bonus_relic.get("id", ""))
		(current_run.get("relic_ids", []) as Array).append(relic_id)
		relic_service.apply_on_acquire(current_run, relic_id)
	run_store.mark_node_cleared(current_run)
	run_store.advance_after_node(current_run)
	current_run["pending_card_reward"] = {}
	if current_run.get("result", "") == "win":
		_save_run()
		_show_run_result(true)
		return
	_save_run()
	_show_map()

func _skip_card_reward() -> void:
	var reward: Dictionary = current_run.get("pending_card_reward", {})
	var bonus_relic: Dictionary = reward.get("bonus_relic", {})
	if not bonus_relic.is_empty():
		var relic_id := String(bonus_relic.get("id", ""))
		(current_run.get("relic_ids", []) as Array).append(relic_id)
		relic_service.apply_on_acquire(current_run, relic_id)
	run_store.mark_node_cleared(current_run)
	run_store.advance_after_node(current_run)
	current_run["pending_card_reward"] = {}
	if current_run.get("result", "") == "win":
		_save_run()
		_show_run_result(true)
		return
	_save_run()
	_show_map()

func _show_event() -> void:
	active_screen = "event"
	_clear_screen()
	var event_data: Dictionary = current_run.get("pending_event", {})
	var body: VBoxContainer = _begin_menu_screen("이벤트")
	body.add_child(_make_run_summary_panel())
	var panel := _make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 640)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_make_label(String(event_data.get("title", "")), 24, Color(1.0, 0.88, 0.55, 1.0)))
	box.add_child(_make_label(String(event_data.get("description", "")), 16, Color(0.9, 0.92, 0.98, 1.0)))
	for option in event_data.get("options", []):
		if typeof(option) != TYPE_DICTIONARY:
			continue
		var button := _add_menu_button(box, String(option.get("label", "")), "_noop", Color(0.22, 0.31, 0.38, 1.0))
		button.pressed.connect(Callable(self, "_resolve_event_option").bind(String(option.get("effect", ""))))

func _resolve_event_option(effect: String) -> void:
	match effect:
		"merchant_card":
			current_run["hp"] = max(1, int(current_run.get("hp", 1)) - 5)
			var premium_choices := _roll_high_cost_cards(3)
			current_run["pending_card_reward"] = {
				"choices": premium_choices,
				"bonus_relic": {},
				"battle_tier": "event",
			}
			current_run["pending_event"] = {}
			_save_run()
			_show_card_reward()
			return
		"merchant_relic":
			if int(current_run.get("gold", 0)) < 50:
				_show_message("골드가 부족합니다.", "_show_event")
				return
			current_run["gold"] = int(current_run["gold"]) - 50
			var merchant_relic: Dictionary = relic_service.random_relic(current_run.get("relic_ids", []))
			if merchant_relic.is_empty():
				_show_message("얻을 유물이 없습니다.", "_complete_event_and_return")
				return
			var merchant_relic_id := String(merchant_relic.get("id", ""))
			(current_run.get("relic_ids", []) as Array).append(merchant_relic_id)
			relic_service.apply_on_acquire(current_run, merchant_relic_id)
			_show_message("수상한 상인: %s 획득" % String(merchant_relic.get("name", "")), "_complete_event_and_return")
			return
		"gamble_small":
			if int(current_run.get("gold", 0)) < 30:
				_show_message("골드가 부족합니다.", "_show_event")
				return
			current_run["gold"] = int(current_run["gold"]) - 30
			if randi() % 2 == 0:
				current_run["gold"] = int(current_run["gold"]) + 80
				_show_message("도박 성공: 골드 80 획득", "_complete_event_and_return")
				return
			_show_message("도박 실패: 골드를 잃었습니다.", "_complete_event_and_return")
			return
		"gamble_relic":
			if int(current_run.get("gold", 0)) < 60:
				_show_message("골드가 부족합니다.", "_show_event")
				return
			current_run["gold"] = int(current_run["gold"]) - 60
			if randi() % 10 < 3:
				var relic: Dictionary = relic_service.random_relic(current_run.get("relic_ids", []))
				if not relic.is_empty():
					var relic_id := String(relic.get("id", ""))
					(current_run.get("relic_ids", []) as Array).append(relic_id)
					relic_service.apply_on_acquire(current_run, relic_id)
					_show_message("대박: %s 획득" % String(relic.get("name", "")), "_complete_event_and_return")
					return
			_show_message("도박 실패: 아무것도 얻지 못했습니다.", "_complete_event_and_return")
			return
		"remove_card":
			pending_return_screen = "event_complete"
			_show_remove_card_screen("이벤트")
			return
		"heal_10":
			current_run["hp"] = min(int(current_run.get("max_hp", 50)), int(current_run.get("hp", 0)) + 10)
			_show_message("버려진 성당: 체력 10 회복", "_complete_event_and_return")
			return
		"curse_relic":
			current_run["max_hp"] = max(10, int(current_run.get("max_hp", 50)) - 5)
			current_run["hp"] = min(int(current_run.get("max_hp", 50)), int(current_run.get("hp", 0)))
			var curse_relic: Dictionary = relic_service.random_relic(current_run.get("relic_ids", []))
			if not curse_relic.is_empty():
				var curse_relic_id := String(curse_relic.get("id", ""))
				(current_run.get("relic_ids", []) as Array).append(curse_relic_id)
				relic_service.apply_on_acquire(current_run, curse_relic_id)
				_show_message("저주를 받고 %s 획득" % String(curse_relic.get("name", "")), "_complete_event_and_return")
				return
			_complete_event_and_return()
			return
		"heal":
			var heal_amount := maxi(1, int(round(float(int(current_run.get("max_hp", 50))) * 0.3)))
			current_run["hp"] = min(int(current_run.get("max_hp", 50)), int(current_run.get("hp", 0)) + heal_amount)
			_show_message("마법 샘: 체력 %d 회복" % heal_amount, "_complete_event_and_return")
			return
		"upgrade_card":
			pending_return_screen = "event_complete_upgrade"
			_show_upgrade_card_screen()
			return
		"max_hp_trade":
			current_run["max_hp"] = int(current_run.get("max_hp", 50)) + 5
			current_run["hp"] = max(1, int(current_run.get("hp", 1)) - 10)
			_show_message("마법의 샘: 최대 체력 +5, 현재 체력 -10", "_complete_event_and_return")
			return
		"gain_equipment":
			var gain_id := String(_roll_card_choice_filtered("equipment", ""))
			if gain_id.is_empty():
				_complete_event_and_return()
				return
			(current_run.get("deck_ids", []) as Array).append(gain_id)
			_show_message("전쟁터의 잔해: %s 획득" % String(cards_by_id[gain_id].get("name", "")), "_complete_event_and_return")
			return
		"gain_human":
			var gain_human_id := String(_roll_card_choice_filtered("", "인간"))
			if gain_human_id.is_empty():
				_complete_event_and_return()
				return
			(current_run.get("deck_ids", []) as Array).append(gain_human_id)
			_show_message("전쟁터의 잔해: %s 획득" % String(cards_by_id[gain_human_id].get("name", "")), "_complete_event_and_return")
			return
		"gain_undead":
			var gain_undead_id := String(_roll_card_choice_filtered("", "언데드"))
			if gain_undead_id.is_empty():
				_complete_event_and_return()
				return
			(current_run.get("deck_ids", []) as Array).append(gain_undead_id)
			_show_message("전쟁터의 잔해: %s 획득" % String(cards_by_id[gain_undead_id].get("name", "")), "_complete_event_and_return")
			return
		"gain_random_card":
			var gain_id := String(_roll_card_choices(1)[0])
			(current_run.get("deck_ids", []) as Array).append(gain_id)
			_show_message("전쟁터: %s 획득" % String(cards_by_id[gain_id].get("name", "")), "_complete_event_and_return")
			return
		_:
			_complete_event_and_return()

func _complete_event_and_return() -> void:
	current_run["pending_event"] = {}
	run_store.mark_node_cleared(current_run)
	run_store.advance_after_node(current_run)
	_save_run()
	_show_map()

func _generate_shop_state() -> Dictionary:
	return {
		"cards": _roll_card_choices(3),
		"relic": relic_service.random_relic(current_run.get("relic_ids", [])),
		"remove_used": false,
		"purchased_cards": [],
		"relic_bought": false,
	}

func _show_shop() -> void:
	active_screen = "shop"
	_clear_screen()
	var shop_state: Dictionary = current_run.get("pending_shop", {})
	var body: VBoxContainer = _begin_menu_screen("상점")
	body.add_child(_make_run_summary_panel())
	var panel := _make_screen_panel(Color(0.105, 0.115, 0.135, 1.0), 760)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_make_label("카드 구매, 유물 구매, 카드 제거를 할 수 있습니다.", 15, Color(0.84, 0.88, 0.95, 1.0)))

	for card_id in shop_state.get("cards", []):
		if not cards_by_id.has(String(card_id)):
			continue
		box.add_child(_make_shop_card_row(cards_by_id[String(card_id)], shop_state))

	var relic: Dictionary = shop_state.get("relic", {})
	if not relic.is_empty():
		box.add_child(_make_shop_relic_row(relic, shop_state))

	var remove_row := HBoxContainer.new()
	remove_row.add_theme_constant_override("separation", 10)
	box.add_child(remove_row)
	var remove_cost := _shop_remove_cost()
	var remove_label := _make_label("카드 제거 - 골드 %d" % remove_cost, 15, Color(0.92, 0.94, 0.98, 1.0))
	remove_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	remove_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remove_row.add_child(remove_label)
	var remove_button := Button.new()
	remove_button.text = "제거"
	remove_button.custom_minimum_size = Vector2(96, 40)
	ui.style_button(remove_button, Color(0.32, 0.18, 0.18, 1.0))
	remove_button.disabled = int(current_run.get("gold", 0)) < remove_cost
	remove_button.pressed.connect(Callable(self, "_begin_shop_remove"))
	remove_row.add_child(remove_button)

	var heal_row := HBoxContainer.new()
	heal_row.add_theme_constant_override("separation", 10)
	box.add_child(heal_row)
	var heal_label := _make_label("체력 20 회복 - 골드 %d" % SHOP_HEAL_COST, 15, Color(0.92, 0.94, 0.98, 1.0))
	heal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heal_row.add_child(heal_label)
	var heal_button := Button.new()
	heal_button.text = "회복"
	heal_button.custom_minimum_size = Vector2(96, 40)
	ui.style_button(heal_button, Color(0.18, 0.4, 0.24, 1.0))
	heal_button.disabled = int(current_run.get("gold", 0)) < SHOP_HEAL_COST
	heal_button.pressed.connect(Callable(self, "_buy_shop_heal"))
	heal_row.add_child(heal_button)

	var actions: BoxContainer = ui.make_action_bar(_is_compact_layout(), 10)
	box.add_child(actions)
	_add_menu_button(actions, "지도 복귀", "_leave_shop", Color(0.18, 0.34, 0.48, 1.0))

func _make_shop_card_row(card: Dictionary, shop_state: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var frame := _make_card_frame()
	frame.custom_minimum_size = Vector2(0, 0)
	row.add_child(frame)
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	frame.add_child(inner)
	inner.add_child(_make_art_rect(int(card.get("art", 0)), Vector2(72, 52)))
	var label := _make_label("[%d] %s - %s" % [int(card.get("cost", 0)), String(card.get("name", "")), String(card.get("text", ""))], 14, Color(0.92, 0.94, 0.98, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(label)
	var button := Button.new()
	button.text = "구매"
	button.custom_minimum_size = Vector2(96, 40)
	ui.style_button(button, Color(0.38, 0.3, 0.14, 1.0))
	button.disabled = int(current_run.get("gold", 0)) < SHOP_CARD_COST or (shop_state.get("purchased_cards", []) as Array).has(String(card.get("id", "")))
	button.pressed.connect(Callable(self, "_buy_shop_card").bind(String(card.get("id", ""))))
	row.add_child(button)
	return row

func _make_shop_relic_row(relic: Dictionary, shop_state: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := _make_label("%s - %s (골드 %d)" % [String(relic.get("name", "")), String(relic.get("text", "")), SHOP_RELIC_COST], 14, Color(1.0, 0.88, 0.55, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button := Button.new()
	button.text = "유물 구매"
	button.custom_minimum_size = Vector2(110, 40)
	ui.style_button(button, Color(0.38, 0.3, 0.14, 1.0))
	button.disabled = int(current_run.get("gold", 0)) < SHOP_RELIC_COST or bool(shop_state.get("relic_bought", false))
	button.pressed.connect(Callable(self, "_buy_shop_relic"))
	row.add_child(button)
	return row

func _buy_shop_card(card_id: String) -> void:
	if int(current_run.get("gold", 0)) < SHOP_CARD_COST:
		return
	current_run["gold"] = int(current_run["gold"]) - SHOP_CARD_COST
	(current_run.get("deck_ids", []) as Array).append(card_id)
	var shop_state: Dictionary = current_run.get("pending_shop", {})
	(shop_state.get("purchased_cards", []) as Array).append(card_id)
	current_run["pending_shop"] = shop_state
	_save_run()
	_show_shop()

func _buy_shop_relic() -> void:
	var shop_state: Dictionary = current_run.get("pending_shop", {})
	var relic: Dictionary = shop_state.get("relic", {})
	if relic.is_empty() or int(current_run.get("gold", 0)) < SHOP_RELIC_COST:
		return
	current_run["gold"] = int(current_run["gold"]) - SHOP_RELIC_COST
	(current_run.get("relic_ids", []) as Array).append(String(relic.get("id", "")))
	relic_service.apply_on_acquire(current_run, String(relic.get("id", "")))
	shop_state["relic_bought"] = true
	current_run["pending_shop"] = shop_state
	_save_run()
	_show_shop()

func _begin_shop_remove() -> void:
	var remove_cost := _shop_remove_cost()
	if int(current_run.get("gold", 0)) < remove_cost:
		return
	current_run["gold"] = int(current_run["gold"]) - remove_cost
	var shop_state: Dictionary = current_run.get("pending_shop", {})
	shop_state["remove_count"] = int(shop_state.get("remove_count", 0)) + 1
	current_run["pending_shop"] = shop_state
	pending_return_screen = "shop"
	_save_run()
	_show_remove_card_screen("상점")

func _buy_shop_heal() -> void:
	if int(current_run.get("gold", 0)) < SHOP_HEAL_COST:
		return
	current_run["gold"] = int(current_run["gold"]) - SHOP_HEAL_COST
	current_run["hp"] = min(int(current_run.get("max_hp", 50)), int(current_run.get("hp", 0)) + 20)
	_save_run()
	_show_shop()

func _leave_shop() -> void:
	current_run["pending_shop"] = {}
	run_store.mark_node_cleared(current_run)
	run_store.advance_after_node(current_run)
	_save_run()
	_show_map()

func _show_rest() -> void:
	active_screen = "rest"
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("휴식")
	body.add_child(_make_run_summary_panel())
	var panel := _make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 520)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_make_label("체력을 회복하거나 카드 1장을 강화할 수 있습니다.", 16, Color(0.92, 0.94, 0.98, 1.0)))
	_add_menu_button(box, "체력 30% 회복", "_rest_heal", Color(0.18, 0.4, 0.24, 1.0))
	_add_menu_button(box, "카드 1장 강화", "_rest_upgrade_card", Color(0.32, 0.18, 0.18, 1.0))
	_add_menu_button(box, "그냥 쉰다", "_complete_rest", Color(0.22, 0.24, 0.28, 1.0))

func _rest_heal() -> void:
	var heal_amount := maxi(1, int(round(float(int(current_run.get("max_hp", 50))) * 0.3)))
	current_run["hp"] = min(int(current_run.get("max_hp", 50)), int(current_run.get("hp", 0)) + heal_amount)
	_complete_rest()

func _rest_upgrade_card() -> void:
	pending_return_screen = "rest_upgrade"
	_show_upgrade_card_screen()

func _complete_rest() -> void:
	run_store.mark_node_cleared(current_run)
	run_store.advance_after_node(current_run)
	_save_run()
	_show_map()

func _show_remove_card_screen(reason: String) -> void:
	active_screen = "remove_card"
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("%s - 카드 제거" % reason)
	body.add_child(_make_run_summary_panel())
	var panel := _make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 760)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_make_label("덱에서 제거할 카드 1장을 고르세요.", 16, Color(0.92, 0.94, 0.98, 1.0)))
	var unique_ids := {}
	for card_id in current_run.get("deck_ids", []):
		unique_ids[String(card_id)] = true
	for card_id in unique_ids.keys():
		if not cards_by_id.has(String(card_id)):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		var count: int = deck_service.count_in_array(current_run.get("deck_ids", []), String(card_id))
		var label := _make_label("%s x%d" % [String(cards_by_id[String(card_id)].get("name", "")), count], 15, Color(0.92, 0.94, 0.98, 1.0))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.text = "제거"
		button.custom_minimum_size = Vector2(96, 40)
		ui.style_button(button, Color(0.32, 0.18, 0.18, 1.0))
		button.pressed.connect(Callable(self, "_remove_card_from_run").bind(String(card_id)))
		row.add_child(button)

func _show_upgrade_card_screen() -> void:
	active_screen = "upgrade_card"
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("휴식 - 카드 강화")
	body.add_child(_make_run_summary_panel())
	var panel := _make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 760)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_make_label("강화할 카드 1장을 고르세요.", 16, Color(0.92, 0.94, 0.98, 1.0)))
	var unique_ids := {}
	for card_id in current_run.get("deck_ids", []):
		unique_ids[String(card_id)] = true
	for card_id in unique_ids.keys():
		if not cards_by_id.has(String(card_id)):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		var label := _make_label("%s" % String(cards_by_id[String(card_id)].get("name", "")), 15, Color(0.92, 0.94, 0.98, 1.0))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.text = "강화"
		button.custom_minimum_size = Vector2(96, 40)
		ui.style_button(button, Color(0.32, 0.18, 0.18, 1.0))
		button.pressed.connect(Callable(self, "_upgrade_card_in_run").bind(String(card_id)))
		row.add_child(button)

func _remove_card_from_run(card_id: String) -> void:
	var deck_ids: Array = current_run.get("deck_ids", [])
	var index := deck_ids.find(card_id)
	if index != -1:
		deck_ids.remove_at(index)
	current_run["deck_ids"] = deck_ids
	_save_run()
	match pending_return_screen:
		"event_complete":
			_complete_event_and_return()
		"event_complete_upgrade":
			_complete_event_and_return()
		"rest":
			_complete_rest()
		"rest_upgrade":
			_complete_rest()
		_:
			_show_shop()

func _upgrade_card_in_run(card_id: String) -> void:
	var deck_ids: Array = current_run.get("deck_ids", [])
	var upgraded_id := card_id
	if cards_by_id.has(card_id):
		var card: Dictionary = cards_by_id[card_id]
		var plus_id := "%s_plus" % card_id
		if not cards_by_id.has(plus_id):
			var plus_card := card.duplicate(true)
			plus_card["id"] = plus_id
			plus_card["name"] = "%s+" % String(card.get("name", ""))
			if String(card.get("type", "")) == "unit":
				plus_card["attack"] = int(card.get("attack", 0)) + 1
				plus_card["health"] = int(card.get("health", 0)) + 1
			elif String(card.get("id", "")) == "captain_order":
				plus_card["text"] = "내 모든 유닛 공격력 +2"
			elif String(card.get("id", "")) == "elven_insight":
				plus_card["cost"] = max(0, int(card.get("cost", 0)) - 1)
			elif String(card.get("id", "")) == "dark_bargain":
				plus_card["text"] = "내 영웅 체력 1 잃음. 카드 2장 드로우"
			cards_by_id[plus_id] = plus_card
			card_defs.append(plus_card)
		upgraded_id = plus_id
	var index := deck_ids.find(card_id)
	if index != -1:
		deck_ids[index] = upgraded_id
	current_run["deck_ids"] = deck_ids
	_save_run()
	if pending_return_screen == "event_complete_upgrade":
		_complete_event_and_return()
		return
	_complete_rest()

func _show_run_result(is_win: bool) -> void:
	active_screen = "run_result"
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("런 결과")
	var panel := _make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 540)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_make_label("런 클리어" if is_win else "런 실패", 28, Color(1.0, 0.88, 0.55, 1.0) if is_win else Color(1.0, 0.68, 0.62, 1.0)))
	box.add_child(_make_label("최종 Act %d | 덱 %d장 | 유물 %d개" % [
		int(current_run.get("act", 1)),
		(current_run.get("deck_ids", []) as Array).size(),
		(current_run.get("relic_ids", []) as Array).size(),
	], 16, Color(0.92, 0.94, 0.98, 1.0)))
	box.add_child(_make_label("이번 런 영혼석 +%d" % int(current_run.get("earned_soul_stones", 0)), 16, Color(0.88, 0.76, 1.0, 1.0)))
	box.add_child(_make_label("보유 영혼석 %d" % int(player_profile.get("soul_stones", 0)), 16, Color(1.0, 0.88, 0.55, 1.0)))
	_add_menu_button(box, "메인 메뉴", "_return_to_main_after_run", Color(0.18, 0.34, 0.48, 1.0))

func _finish_run(is_win: bool) -> void:
	current_run["result"] = "win" if is_win else "loss"
	var earned_soul_stones := _run_soul_stones(is_win)
	current_run["earned_soul_stones"] = earned_soul_stones
	player_profile["soul_stones"] = int(player_profile.get("soul_stones", 0)) + earned_soul_stones
	_save_profile()
	current_run["active_enemy"] = {}
	current_run["pending_event"] = {}
	current_run["pending_shop"] = {}
	current_run["pending_card_reward"] = {}
	_save_run()
	_show_run_result(is_win)

func _return_to_main_after_run() -> void:
	_clear_run()
	_show_main_menu()

func _abandon_run() -> void:
	_clear_run()
	_show_main_menu()

func _show_collection() -> void:
	active_screen = "collection"
	_clear_screen()
	var compact := _is_compact_layout()
	var body: VBoxContainer = _begin_menu_screen("카드 보관함")
	var panel := _make_screen_panel(Color(0.105, 0.115, 0.135, 1.0), 760 if not compact else 420)
	body.add_child(panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(list)
	list.add_child(_make_label("카드 %d종 | 보유 카드는 밝게, 미보유 카드는 어둡게 표시됩니다." % card_defs.size(), 14, Color(0.82, 0.88, 0.95, 1.0)))
	list.add_child(ui.make_filter_bar(["전체", "보유", "미보유", "인간", "엘프", "언데드", "중립"], collection_filter, self, "_set_collection_filter", compact))
	var filtered_cards := _filtered_collection_cards()
	var columns := 2 if compact else 4
	var row: HBoxContainer = null
	for index in range(filtered_cards.size()):
		if index % columns == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 10)
			list.add_child(row)
		row.add_child(_make_collection_card(filtered_cards[index], compact))
	var actions: BoxContainer = ui.make_action_bar(compact, 10)
	body.add_child(actions)
	_add_menu_button(actions, "메인으로", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))

func _set_collection_filter(filter: String) -> void:
	collection_filter = filter
	_show_collection()

func _filtered_collection_cards() -> Array:
	var filtered: Array = []
	for card in card_defs:
		var owned := int(player_profile["owned_cards"].get(String(card.get("id", "")), 0))
		if collection_filter == "보유" and owned <= 0:
			continue
		if collection_filter == "미보유" and owned > 0:
			continue
		if collection_filter not in ["전체", "보유", "미보유"] and String(card.get("race", "")) != collection_filter:
			continue
		filtered.append(card)
	return filtered

func _show_settings() -> void:
	active_screen = "settings"
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("설정")
	var panel := _make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 480)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var cutscene_toggle := CheckBox.new()
	cutscene_toggle.text = "전투 연출 켜기"
	cutscene_toggle.button_pressed = bool(player_profile["settings"]["battle_cutscene"])
	cutscene_toggle.toggled.connect(Callable(self, "_on_cutscene_toggled"))
	box.add_child(cutscene_toggle)
	var fast_ai_toggle := CheckBox.new()
	fast_ai_toggle.text = "AI 턴 빠르게"
	fast_ai_toggle.button_pressed = bool(player_profile["settings"]["fast_ai"])
	fast_ai_toggle.toggled.connect(Callable(self, "_on_fast_ai_toggled"))
	box.add_child(fast_ai_toggle)
	_add_menu_button(box, "로컬 프로필 초기화", "_reset_profile", Color(0.35, 0.16, 0.16, 1.0))
	_add_menu_button(box, "메인으로", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))

func _on_cutscene_toggled(enabled: bool) -> void:
	player_profile["settings"]["battle_cutscene"] = enabled
	_save_profile()

func _on_fast_ai_toggled(enabled: bool) -> void:
	player_profile["settings"]["fast_ai"] = enabled
	_save_profile()

func _reset_profile() -> void:
	player_profile = profile_store.make_default_profile(card_defs, 30)
	player_profile = profile_store.apply_local_debug_defaults(player_profile, card_defs)
	_save_profile()
	_show_message("로컬 프로필을 초기화했습니다.", "_show_main_menu")

func _show_message(message: String, callback_method: String) -> void:
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("알림", false)
	var panel := _make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 520)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_make_label(message, 18, Color(0.92, 0.94, 0.98, 1.0)))
	_add_menu_button(box, "확인", callback_method, Color(0.18, 0.34, 0.48, 1.0))

func _make_run_summary_panel() -> Control:
	var compact := _is_compact_layout()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.add_child(ui.make_stat_tile("Act", "%d" % int(current_run.get("act", 1)), Color(0.34, 0.46, 0.64, 1.0), compact))
	row.add_child(ui.make_stat_tile("체력", "%d/%d" % [int(current_run.get("hp", 0)), int(current_run.get("max_hp", 0))], Color(0.46, 0.2, 0.2, 1.0), compact))
	row.add_child(ui.make_stat_tile("골드", "%d" % int(current_run.get("gold", 0)), Color(0.52, 0.38, 0.16, 1.0), compact))
	row.add_child(ui.make_stat_tile("덱", "%d장" % (current_run.get("deck_ids", []) as Array).size(), Color(0.22, 0.42, 0.34, 1.0), compact))
	return row

func _profile_upgrades() -> Dictionary:
	if not player_profile.has("upgrades") or typeof(player_profile["upgrades"]) != TYPE_DICTIONARY:
		player_profile["upgrades"] = {
			"start_hp": 0,
			"start_gold": 0,
			"second_chance": 0,
		}
	return player_profile["upgrades"]

func _shop_remove_cost() -> int:
	var shop_state: Dictionary = current_run.get("pending_shop", {})
	return 50 + int(shop_state.get("remove_count", 0)) * 25

func _run_soul_stones(is_win: bool) -> int:
	var stones := 0
	var visited: Array = current_run.get("visited_nodes", [])
	var acts: Array = current_run.get("map_nodes", [])
	for key in visited:
		var parts := String(key).split(":")
		if parts.size() != 2:
			continue
		var act_index := int(parts[0]) - 1
		var node_index := int(parts[1])
		if act_index < 0 or act_index >= acts.size():
			continue
		var nodes: Array = Dictionary(acts[act_index]).get("nodes", [])
		if node_index < 0 or node_index >= nodes.size():
			continue
		match String(nodes[node_index]):
			"battle":
				stones += 5
			"elite":
				stones += 15
			"boss":
				stones += 30
	if is_win:
		stones += 100
	return stones

func _roll_card_choices(count: int) -> Array[String]:
	var ids: Array[String] = []
	var pool: Array[String] = []
	for card in card_defs:
		var card_id := String(card.get("id", ""))
		if bool(card.get("starter", false)):
			continue
		if card_id.ends_with("_plus"):
			continue
		pool.append(card_id)
	while ids.size() < count and not pool.is_empty():
		var index := randi() % pool.size()
		ids.append(pool[index])
		pool.remove_at(index)
	return ids

func _roll_high_cost_cards(count: int) -> Array[String]:
	var pool: Array[String] = []
	for card in card_defs:
		var card_id := String(card.get("id", ""))
		if bool(card.get("starter", false)) or card_id.ends_with("_plus"):
			continue
		if int(card.get("cost", 0)) >= 3:
			pool.append(card_id)
	if pool.is_empty():
		return _roll_card_choices(count)
	var ids: Array[String] = []
	while ids.size() < count and not pool.is_empty():
		var index := randi() % pool.size()
		ids.append(pool[index])
		pool.remove_at(index)
	return ids

func _roll_card_choice_filtered(type_filter: String, race_filter: String) -> String:
	var pool: Array[String] = []
	for card in card_defs:
		var card_id := String(card.get("id", ""))
		if bool(card.get("starter", false)) or card_id.ends_with("_plus"):
			continue
		if not type_filter.is_empty() and String(card.get("type", "")) != type_filter:
			continue
		if not race_filter.is_empty() and String(card.get("race", "")) != race_filter:
			continue
		pool.append(card_id)
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]

func _current_act() -> Dictionary:
	var acts: Array = current_run.get("map_nodes", [])
	var act_index := int(current_run.get("act", 1)) - 1
	if act_index < 0 or act_index >= acts.size():
		return {}
	return acts[act_index]

func _node_type_name(node_type: String) -> String:
	match node_type:
		"battle":
			return "일반전투"
		"elite":
			return "엘리트"
		"event":
			return "이벤트"
		"shop":
			return "상점"
		"rest":
			return "휴식"
		"boss":
			return "보스"
		_:
			return node_type

func _refresh_ui() -> void:
	if status_label == null:
		return
	status_label.text = "%s | 현재 턴: %s" % [_node_type_name(String(run_store.current_node(current_run).get("type", "battle"))), "플레이어" if current_player == "player" else "상대"]
	opponent_info.text = "%s HP %d/%d | 마나 %d/%d | 손패 %d | 덱 %d" % [opponent.name, opponent.health, opponent.max_health, opponent.mana, opponent.max_mana, opponent.hand.size(), opponent.deck.size()]
	player_info.text = "내 영웅 HP %d/%d | 마나 %d/%d | 덱 %d" % [player.health, player.max_health, player.mana, player.max_mana, player.deck.size()]
	hero_attack_button.disabled = input_locked or game_over or current_player != "player" or selected_attacker == -1
	end_turn_button.disabled = input_locked or game_over or current_player != "player"
	_render_field(opponent_field_box, opponent, false)
	_render_field(player_field_box, player, true)
	_render_hand()
	_render_battle_deck()

func _render_field(container: HBoxContainer, side: Dictionary, is_player_field: bool) -> void:
	for child in container.get_children():
		child.queue_free()
	for i in range(MAX_FIELD):
		var frame := _make_card_frame()
		frame.custom_minimum_size = Vector2(138, 122)
		var slot := VBoxContainer.new()
		slot.custom_minimum_size = Vector2(132, 116)
		slot.add_theme_constant_override("separation", 3)
		frame.add_child(slot)
		var button := Button.new()
		button.custom_minimum_size = Vector2(130, 42)
		ui.style_button(button, Color(0.2, 0.23, 0.28, 1.0))
		if i < side.field.size():
			var unit: Dictionary = side.field[i]
			slot.add_child(_make_art_rect(int(unit.get("art", 0)), Vector2(130, 68)))
			button.text = "%s %s/%s" % [unit.name, unit.attack, unit.health]
			if is_player_field:
				button.disabled = input_locked or game_over or current_player != "player" or not bool(unit.can_attack)
				button.pressed.connect(Callable(self, "_on_player_unit_pressed").bind(i))
				if i == selected_attacker:
					button.text = "[선택] " + button.text
			else:
				button.disabled = input_locked or game_over or current_player != "player" or selected_attacker == -1
				button.pressed.connect(Callable(self, "_on_opponent_unit_pressed").bind(i))
		else:
			var placeholder := ColorRect.new()
			placeholder.color = Color(0.09, 0.1, 0.12, 1.0)
			placeholder.custom_minimum_size = Vector2(130, 68)
			slot.add_child(placeholder)
			button.text = "빈 슬롯"
			button.disabled = true
		slot.add_child(button)
		container.add_child(frame)

func _render_hand() -> void:
	for child in hand_box.get_children():
		child.queue_free()
	for i in range(player.hand.size()):
		var card: Dictionary = player.hand[i]
		var frame := _make_card_frame()
		frame.custom_minimum_size = Vector2(151, 160)
		var card_box := VBoxContainer.new()
		card_box.custom_minimum_size = Vector2(145, 154)
		card_box.add_theme_constant_override("separation", 4)
		frame.add_child(card_box)
		card_box.add_child(_make_art_rect(int(card.get("art", 0)), Vector2(145, 82)))
		var button := Button.new()
		var cost: int = relic_service.modify_card_cost(current_run, battle_state, card, "player")
		button.custom_minimum_size = Vector2(145, 68)
		button.text = "%s\n비용 %d | %s\n%s" % [String(card.get("name", "")), cost, deck_service.type_name(String(card.get("type", ""))), String(card.get("text", ""))]
		button.disabled = input_locked or game_over or current_player != "player" or cost > int(player.mana)
		ui.style_button(button, Color(0.18, 0.24, 0.3, 1.0))
		button.pressed.connect(Callable(self, "_on_hand_card_pressed").bind(i))
		card_box.add_child(button)
		hand_box.add_child(frame)

func _render_battle_deck() -> void:
	if deck_count_label == null or deck_list_label == null:
		return
	deck_count_label.text = "남은 카드 %d장" % player.deck.size()
	deck_list_label.text = deck_service.deck_summary_from_cards(player.deck)

func _make_collection_card(card: Dictionary, compact: bool) -> Control:
	var owned := int(player_profile["owned_cards"].get(String(card.get("id", "")), 0))
	var panel := _make_card_frame()
	panel.custom_minimum_size = Vector2(170 if compact else 220, 0)
	if owned <= 0:
		panel.modulate = Color(0.45, 0.45, 0.5, 1.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var art := _make_art_rect(int(card.get("art", 0)), Vector2(132, 92) if compact else Vector2(150, 108))
	if owned <= 0:
		art.modulate = Color(0.3, 0.3, 0.34, 1.0)
	box.add_child(art)
	box.add_child(_make_label("%s x%d" % [String(card.get("name", "")), owned], 14 if compact else 15, Color(0.98, 0.98, 0.96, 1.0)))
	var stat_text := "[%d] %s/%s | %s" % [int(card.get("cost", 0)), String(card.get("race", "")), String(card.get("attr", "")), deck_service.type_name(String(card.get("type", "")))]
	if String(card.get("type", "")) == "unit":
		stat_text += " | %d/%d" % [int(card.get("attack", 0)), int(card.get("health", 0))]
	var stat := _make_label(stat_text, 12 if compact else 13, Color(0.84, 0.88, 0.95, 1.0))
	box.add_child(stat)
	var text := _make_label(String(card.get("text", "")), 12 if compact else 13, Color(0.82, 0.88, 0.95, 1.0))
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(text)
	return panel

func _noop() -> void:
	pass

func _is_compact_layout() -> bool:
	return ui.is_compact(get_viewport_rect().size.x)

func _begin_menu_screen(title: String, with_profile: bool = false) -> VBoxContainer:
	var summary: Control = null
	if with_profile and not current_run.is_empty():
		summary = _make_run_summary_panel()
	return ui.begin_screen(root_box, title, summary)

func _make_screen_panel(color: Color, preferred_width: int, min_height: int = 0) -> PanelContainer:
	return ui.make_screen_panel(color, get_viewport_rect().size.x, preferred_width, min_height)

func _make_responsive_panel(color: Color, preferred_width: int, min_height: int = 0) -> PanelContainer:
	return ui.make_responsive_panel(color, get_viewport_rect().size.x, preferred_width, min_height)

func _make_panel_container(color: Color) -> PanelContainer:
	return ui.make_panel_container(color)

func _make_card_frame() -> PanelContainer:
	return ui.make_card_frame()

func _make_art_rect(art_index: int, size: Vector2) -> TextureRect:
	return ui.make_art_rect(art_index, size)

func _make_label(text: String, font_size: int, color: Color) -> Label:
	return ui.make_label(text, font_size, color)

func _add_menu_button(parent: Node, text: String, callback_method: String, color: Color) -> Button:
	return ui.add_menu_button(parent, self, text, callback_method, color)

func _add_title(text: String) -> void:
	ui.add_title(root_box, text)

func _add_log(message: String) -> void:
	if log_label == null:
		return
	log_label.text = message + "\n" + log_label.text

func _quit_game() -> void:
	get_tree().quit()
