extends Control

const MAX_MANA := 10
const MAX_FIELD := 5
const START_HAND := 4
const PROFILE_PATH := "user://meta_profile.json"
const RUN_PATH := "user://run_state.json"
const CARD_DATA_PATH := "res://data/cards.json"
const CARD_ART_SHEET := preload("res://assets/card_art/season1_sample_sheet.png")
const BATTLE_CUTSCENE_SCENE := preload("res://scenes/BattleCutscene.tscn")
const BattleCardEffectsScript := preload("res://scripts/battle/battle_card_effects.gd")
const CardDatabaseScript := preload("res://scripts/services/card_database.gd")
const DeckServiceScript := preload("res://scripts/services/deck_service.gd")
const EnemyServiceScript := preload("res://scripts/services/enemy_service.gd")
const EventServiceScript := preload("res://scripts/services/event_service.gd")
const ProfileStoreScript := preload("res://scripts/core/profile_store.gd")
const RelicServiceScript := preload("res://scripts/services/relic_service.gd")
const RewardServiceScript := preload("res://scripts/services/reward_service.gd")
const RunGeneratorScript := preload("res://scripts/services/run_generator.gd")
const RunStateScript := preload("res://scripts/services/run_state.gd")
const UiFactoryScript := preload("res://scripts/ui/ui_factory.gd")
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
		var bs = load("res://scripts/ui/screens/battle_screen.gd").new(self)
		bs.start_battle()
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
	var body: VBoxContainer = _begin_menu_screen(String(_current_act().get("name", "맵")))
	var MapScreenClass = load("res://scripts/ui/screens/map_screen.gd")
	var map_screen = MapScreenClass.new(self)
	map_screen.build(body, _current_act())

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
			var ShopScreenClass = load("res://scripts/ui/screens/shop_screen.gd")
			current_run["pending_shop"] = ShopScreenClass.generate_shop_state(self)
			_save_run()
			_show_shop()
		"rest":
			_show_rest()

func _show_card_reward() -> void:
	active_screen = "card_reward"
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("전투 보상")
	var RewardScreenClass = load("res://scripts/ui/screens/reward_screen.gd")
	var screen = RewardScreenClass.new(self)
	screen.build(body)

func _show_event() -> void:
	active_screen = "event"
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("이벤트")
	var EventScreenClass = load("res://scripts/ui/screens/event_screen.gd")
	var screen = EventScreenClass.new(self)
	screen.build(body)

func _complete_event_and_return() -> void:
	current_run["pending_event"] = {}
	run_store.mark_node_cleared(current_run)
	run_store.advance_after_node(current_run)
	_save_run()
	_show_map()

func _show_shop() -> void:
	active_screen = "shop"
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("상점")
	var ShopScreenClass = load("res://scripts/ui/screens/shop_screen.gd")
	var screen = ShopScreenClass.new(self)
	screen.build(body)

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
	var body: VBoxContainer = _begin_menu_screen("카드 보관함")
	var CollectionScreenClass = load("res://scripts/ui/screens/collection_screen.gd")
	var screen = CollectionScreenClass.new(self)
	screen.build(body)

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

func _quit_game() -> void:
	get_tree().quit()

func _prepare_battle(tier: String) -> void:
	active_screen = "battle"
	_clear_screen()
	var BattleScreenClass = load("res://scripts/ui/screens/battle_screen.gd")
	var battle_screen = BattleScreenClass.new(self)
	battle_screen._prepare_battle(tier)
