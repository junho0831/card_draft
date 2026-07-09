extends Control

const MAX_MANA := 10
const MAX_FIELD := 5
const START_HAND := 4
const PROFILE_PATH := "user://meta_profile.json"
const RUN_PATH := "user://run_state.json"
const CARD_DATA_PATH := "res://data/cards.json"
const CARD_ART_SHEET := preload("res://assets/card_art/season1_sample_sheet.png")
const BATTLE_CUTSCENE_SCENE := preload("res://src/battle/BattleCutscene.tscn")
const BattleCardEffectsScript := preload("res://src/battle/battle_card_effects.gd")
const CardDatabaseScript := preload("res://src/services/card_database.gd")
const DeckServiceScript := preload("res://src/services/deck_service.gd")
const EnemyServiceScript := preload("res://src/services/enemy_service.gd")
const EventRunServiceScript := preload("res://src/services/event_run_service.gd")
const EventServiceScript := preload("res://src/services/event_service.gd")
const ProfileStoreScript := preload("res://src/core/profile_store.gd")
const RelicServiceScript := preload("res://src/services/relic_service.gd")
const ShopRunServiceScript := preload("res://src/services/shop_run_service.gd")
const RunFlowCoordinatorScript := preload("res://src/core/run_flow_coordinator.gd")
const RunGeneratorScript := preload("res://src/services/run_generator.gd")
const RunStateScript := preload("res://src/services/run_state.gd")
const CollectionScreenScript := preload("res://src/ui/screens/collection_screen.gd")
const CompendiumScreenScript := preload("res://src/ui/screens/compendium_screen.gd")
const DeckEditScreenScript := preload("res://src/ui/screens/deck_edit_screen.gd")
const MessageScreenScript := preload("res://src/ui/screens/message_screen.gd")
const MetaUpgradeScreenScript := preload("res://src/ui/screens/meta_upgrade_screen.gd")
const RunResultScreenScript := preload("res://src/ui/screens/run_result_screen.gd")
const SettingsScreenScript := preload("res://src/ui/screens/settings_screen.gd")
const UiGuideScreenScript := preload("res://src/ui/screens/ui_guide_screen.gd")
const UiFactoryScript := preload("res://src/ui/ui_factory.gd")
const AudioManagerScript := preload("res://src/services/audio_manager.gd")
const CARD_ART_COLS := 4
const CARD_ART_ROWS := 3

var card_db
var deck_service
var enemy_service
var event_service
var event_run_service
var profile_store
var relic_service
var shop_run_service
var run_generator
var run_store
var ui
var audio_manager
var battle_effects
var run_flow
var battle_screen
var active_screen_controller: RefCounted

var card_defs: Array[Dictionary] = []
var cards_by_id := {}
var player_profile := {}
var current_run := {}
var collection_filter := "전체"
var active_screen := "main_menu"

var root_box: VBoxContainer
var root_scroll: ScrollContainer
var modal_layer: Control
var battle_cutscene

func _configure_runtime_performance() -> void:
	Engine.max_fps = 60


func _ready() -> void:
	_configure_runtime_performance()
	card_db = CardDatabaseScript.new()
	deck_service = DeckServiceScript.new()
	enemy_service = EnemyServiceScript.new()
	event_service = EventServiceScript.new()
	event_run_service = EventRunServiceScript.new()
	profile_store = ProfileStoreScript.new()
	relic_service = RelicServiceScript.new()
	shop_run_service = ShopRunServiceScript.new()
	run_generator = RunGeneratorScript.new()
	run_store = RunStateScript.new()
	ui = UiFactoryScript.new()
	ui.setup(CARD_ART_SHEET, CARD_ART_COLS, CARD_ART_ROWS)
	audio_manager = AudioManagerScript.new()
	add_child(audio_manager)
	battle_effects = BattleCardEffectsScript.new()
	run_flow = RunFlowCoordinatorScript.new(self)
	battle_screen = null
	active_screen_controller = null

	_build_base_ui()
	if not card_db.load_cards(CARD_DATA_PATH):
		_show_error_screen("카드 데이터 로드 실패")
		return
	if not event_service.load_events() or not enemy_service.load_enemies() or not relic_service.load_relics():
		_show_error_screen("런 데이터 로드 실패")
		return

	card_defs = card_db.card_defs
	cards_by_id = card_db.cards_by_id
	player_profile = profile_store.load_or_create(PROFILE_PATH, card_defs)
	player_profile = profile_store.apply_local_debug_defaults(player_profile, card_defs)
	_save_profile()
	_apply_window_mode()
	current_run = run_store.load_or_empty(RUN_PATH)
	_show_main_menu()

func _create_premium_background() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = [0.0, 0.6, 1.0]
	gradient.colors = [
		Color(0.06, 0.09, 0.15, 1.0),
		Color(0.02, 0.03, 0.05, 1.0),
		Color(0.008, 0.01, 0.015, 1.0)
	]
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.85, 0.85)
	tex.width = 512
	tex.height = 512
	return tex

func _build_base_ui() -> void:
	var background := TextureRect.new()
	var bg_tex := load("res://assets/backgrounds/game_board_bg.png") as Texture2D
	if bg_tex != null:
		background.texture = bg_tex
	else:
		background.texture = _create_premium_background()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var backdrop := Control.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_build_backdrop_layer(backdrop)

	var top_shadow := ColorRect.new()
	top_shadow.color = Color(0.0, 0.0, 0.0, 0.36)
	top_shadow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_shadow.offset_bottom = 92
	add_child(top_shadow)

	root_scroll = ScrollContainer.new()
	root_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_scroll.offset_left = 10
	root_scroll.offset_top = 10
	root_scroll.offset_right = -10
	root_scroll.offset_bottom = -10
	root_scroll.follow_focus = true
	root_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(root_scroll)

	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)

	root_box = VBoxContainer.new()
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_theme_constant_override("separation", 12)
	root_scroll.add_child(root_box)
	_apply_root_layout()

	battle_cutscene = BATTLE_CUTSCENE_SCENE.instantiate()
	add_child(battle_cutscene)

func _build_backdrop_layer(parent: Control) -> void:
	var viewport_size: Vector2 = _layout_viewport_size()
	
	var hero_texture := preload("res://assets/card_art/novice_swordsman.png")
	var hero_art := TextureRect.new()
	hero_art.texture = hero_texture
	hero_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_art.custom_minimum_size = Vector2(520, 520)
	hero_art.modulate = Color(1.0, 1.0, 1.0, 0.4) # Make it more visible
	hero_art.position = Vector2(max(260.0, viewport_size.x * 0.52), max(70.0, viewport_size.y * 0.08))
	hero_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(hero_art)

	var enemy_texture := preload("res://assets/portraits/skeleton_swarm.png")
	var player_art := TextureRect.new()
	player_art.texture = enemy_texture
	player_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_art.custom_minimum_size = Vector2(360, 360)
	player_art.modulate = Color(1.0, 1.0, 1.0, 0.3)
	player_art.position = Vector2(max(24.0, viewport_size.x * 0.05), max(240.0, viewport_size.y * 0.42))
	player_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(player_art)

	for i in range(12):
		var line := ColorRect.new()
		line.color = Color(0.36, 0.3, 0.18, 0.055)
		line.custom_minimum_size = Vector2(max(1280.0, viewport_size.x), 1)
		line.position = Vector2(0, 86 + i * 58)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(line)

	for i in range(9):
		var seam := ColorRect.new()
		seam.color = Color(0.0, 0.0, 0.0, 0.12)
		seam.custom_minimum_size = Vector2(1, max(720.0, viewport_size.y))
		seam.position = Vector2(84 + i * 180, 0)
		seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(seam)

	var bottom_fade := ColorRect.new()
	bottom_fade.color = Color(0.0, 0.0, 0.0, 0.34)
	bottom_fade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_fade.offset_top = -180
	bottom_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bottom_fade)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_root_layout()

func _apply_root_layout() -> void:
	if root_box == null:
		return
	ui.apply_root_layout(root_box, _layout_viewport_size())


func _clear_screen() -> void:
	active_screen_controller = null
	if root_scroll != null:
		root_scroll.scroll_horizontal = 0
		root_scroll.scroll_vertical = 0
	for child in root_box.get_children():
		child.free()

	_clear_modal()

func _clear_modal() -> void:
	for child in modal_layer.get_children():
		child.free()

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

func _retain_screen_controller(controller: RefCounted) -> RefCounted:
	active_screen_controller = controller
	return controller

func _show_main_menu() -> void:
	active_screen = "main_menu"
	_clear_screen()
	var compact := _is_main_menu_compact_layout()
	root_box.add_theme_constant_override("separation", 14)
	root_box.add_child(_make_main_menu_top_bar(compact))
	root_box.add_child(_make_main_menu_content(compact))
	root_box.add_child(_make_main_menu_footer(compact))

func _start_new_run() -> void:
	run_flow.start_new_run()

func _init_run(race_id: String) -> void:
	run_flow.init_run(race_id)

func _continue_run() -> void:
	run_flow.continue_run()

func _main_menu_level() -> Dictionary:
	var soul_stones := int(player_profile.get("soul_stones", 0))
	var level := 1 + int(floor(float(soul_stones) / 150.0))
	var current := soul_stones % 150
	return {
		"level": max(1, level),
		"current": current,
		"target": 150,
	}

func _today_key() -> String:
	return Time.get_date_string_from_system()

func _can_claim_daily_reward() -> bool:
	return String(player_profile.get("last_daily_reward_day", "")) != _today_key()

func _claim_daily_reward() -> void:
	if not _can_claim_daily_reward():
		_show_message("오늘의 데일리 보상은 이미 받았습니다.", "_show_main_menu")
		return
	player_profile["last_daily_reward_day"] = _today_key()
	player_profile["gold"] = int(player_profile.get("gold", 0)) + 100
	player_profile["soul_stones"] = int(player_profile.get("soul_stones", 0)) + 25
	_save_profile()
	_show_message("데일리 보상 획득\n골드 +100\n영혼석 +25", "_show_main_menu")

func _show_achievements() -> void:
	_show_message("업적 화면은 다음 단계에서 연결합니다.", "_show_main_menu")

func _hero_build_name() -> String:
	var primary := _primary_build_tag(_current_build_scores())
	if primary.is_empty():
		return "탐색 빌드"
	var meta: Dictionary = _build_tag_meta().get(primary, {})
	return "%s 빌드" % String(meta.get("name", "탐색"))

func _recent_runs() -> Array:
	if not player_profile.has("recent_runs") or typeof(player_profile["recent_runs"]) != TYPE_ARRAY:
		player_profile["recent_runs"] = []
	return player_profile["recent_runs"]

func _record_recent_run(is_win: bool) -> void:
	var recent: Array = _recent_runs()
	var act_data: Dictionary = _current_act()
	recent.insert(0, {
		"result": "승리" if is_win else "패배",
		"act_name": String(act_data.get("name", "런 종료")),
		"build_name": _hero_build_name(),
		"timestamp": Time.get_unix_time_from_system(),
	})
	while recent.size() > 5:
		recent.pop_back()
	player_profile["recent_runs"] = recent
	_save_profile()

func _relative_time_text(unix_time: int) -> String:
	var delta: int = max(0, int(Time.get_unix_time_from_system()) - unix_time)
	if delta < 60:
		return "방금 전"
	if delta < 3600:
		return "%d분 전" % int(delta / 60)
	if delta < 86400:
		return "%d시간 전" % int(delta / 3600)
	return "%d일 전" % int(delta / 86400)

func _run_summary_lines() -> Array[String]:
	if current_run.is_empty():
		return [
			"새 런을 시작해 빌드를 완성하세요.",
			"전투 -> 이벤트 -> 상점 -> 휴식 -> 보스 흐름으로 진행됩니다.",
		]
	return [
		"Act %d - %s" % [int(current_run.get("act", 1)), String(_current_act().get("name", ""))],
		"체력 %d/%d | 골드 %d" % [int(current_run.get("hp", 0)), int(current_run.get("max_hp", 0)), int(current_run.get("gold", 0))],
		"덱 %d장 | 유물 %d개" % [(current_run.get("deck_ids", []) as Array).size(), (current_run.get("relic_ids", []) as Array).size()],
	]

func _main_menu_next_action_text() -> String:
	if current_run.is_empty():
		return "다음 행동: 새 런 시작"
	var node_index := int(current_run.get("current_node_index", 0))
	var act_data: Dictionary = _current_act()
	var nodes: Array = act_data.get("nodes", [])
	if node_index >= 0 and node_index < nodes.size():
		var node_data_variant: Variant = nodes[node_index]
		if typeof(node_data_variant) == TYPE_DICTIONARY:
			var node_data: Dictionary = node_data_variant
			return "다음 행동: %s 진입" % _node_type_name(String(node_data.get("type", "")))
	return "다음 행동: 이어하기"

func _main_menu_recent_stats() -> Dictionary:
	var recent: Array = _recent_runs()
	var wins := 0
	for entry_variant in recent:
		var entry: Dictionary = entry_variant
		if String(entry.get("result", "")) == "승리":
			wins += 1
	var total: int = recent.size()
	var losses: int = max(0, total - wins)
	var win_rate: int = 0
	if total > 0:
		win_rate = int(round((float(wins) / float(total)) * 100.0))
	return {
		"total": total,
		"wins": wins,
		"losses": losses,
		"win_rate": win_rate,
	}

func _menu_nav_button(parent: Node, title: String, subtitle: String, callback_method: String, color: Color, icon_text: String = "◆", compact: bool = false) -> Button:
	var button: Button = ui.make_large_action_button(title, subtitle, icon_text, color, compact)
	if compact and not _is_phone_portrait_layout():
		button.custom_minimum_size = Vector2(460, 66)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		button.custom_minimum_size = Vector2(0, 78 if compact else 86)
	button.pressed.connect(Callable(self, callback_method))
	parent.add_child(button)
	return button

func _small_hub_button(parent: Node, title: String, callback_method: String, icon_text: String) -> void:
	var button := Button.new()
	button.text = "%s\n%s" % [icon_text, title]
	button.custom_minimum_size = Vector2(58, 62)
	ui.style_button(button, Color(0.1, 0.12, 0.16, 1.0))
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(Callable(self, callback_method))
	parent.add_child(button)

func _small_hub_button_config(parent: Node, title: String, callback_method: String, icon_text: String, width: int = 58, height: int = 62, font_size: int = 13) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [icon_text, title]
	button.custom_minimum_size = Vector2(width, height)
	ui.style_flat_button(button, Color(0.08, 0.11, 0.16, 1.0), Color(0.44, 0.6, 0.82, 1.0), font_size, 2)
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(Callable(self, callback_method))
	parent.add_child(button)
	return button

func _format_large_number(value: int) -> String:
	var sign := "-" if value < 0 else ""
	var abs_value := absi(value)
	if abs_value >= 10000000000000000:
		return "%s%.1f경" % [sign, float(abs_value) / 10000000000000000.0]
	if abs_value >= 1000000000000:
		return "%s%.1f조" % [sign, float(abs_value) / 1000000000000.0]
	if abs_value >= 100000000:
		return "%s%.1f억" % [sign, float(abs_value) / 100000000.0]
	if abs_value >= 10000:
		return "%s%.1f만" % [sign, float(abs_value) / 10000.0]
	return "%s%d" % [sign, abs_value]

func _make_top_resource_chip(icon_text: String, value_text: String, compact: bool) -> PanelContainer:
	var chip: PanelContainer = ui.make_chip("%s %s" % [icon_text, value_text], Color(0.08, 0.1, 0.14, 1.0), Color(0.96, 0.97, 0.94, 1.0), 13 if compact else 14)
	chip.custom_minimum_size = Vector2(0, 38)
	return chip

func _make_main_menu_top_bar(compact: bool) -> Control:
	var phone_portrait := _is_phone_portrait_layout()
	var panel: PanelContainer = ui.make_surface_panel(Color(0.025, 0.035, 0.05, 1.0), Color(0.28, 0.22, 0.13, 1.0), 1, 12, 14)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var profile_row := HBoxContainer.new()
	profile_row.custom_minimum_size = Vector2(290 if compact else 340, 0)
	profile_row.add_theme_constant_override("separation", 12)
	row.add_child(profile_row)
	profile_row.add_child(_make_art_rect(8, Vector2(56, 56) if compact else Vector2(64, 64)))

	var profile_box := VBoxContainer.new()
	profile_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_box.add_theme_constant_override("separation", 8)
	profile_row.add_child(profile_box)
	var title := _make_label("Card Draft", 19 if compact else 21, Color(1.0, 0.9, 0.72, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	profile_box.add_child(title)
	var level_data: Dictionary = _main_menu_level()
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 12)
	profile_box.add_child(level_row)
	var level_label := _make_label("Lv. %d" % int(level_data.get("level", 1)), 15 if compact else 16, Color(0.96, 0.97, 0.94, 1.0))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	level_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	level_row.add_child(level_label)
	var progress_bar := ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.min_value = 0
	progress_bar.max_value = max(1, int(level_data.get("target", 1)))
	progress_bar.value = int(level_data.get("current", 0))
	progress_bar.custom_minimum_size = Vector2(98 if compact else 126, 10)
	progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_row.add_child(progress_bar)
	var progress_label := _make_label("%d / %d" % [int(level_data.get("current", 0)), int(level_data.get("target", 1))], 13 if compact else 14, Color(0.96, 0.88, 0.62, 1.0))
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	progress_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	level_row.add_child(progress_label)

	var resources_row: Control
	if compact:
		var resource_grid := GridContainer.new()
		resource_grid.columns = 2
		resource_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resource_grid.add_theme_constant_override("h_separation", 10)
		resource_grid.add_theme_constant_override("v_separation", 10)
		resources_row = resource_grid
	else:
		var resource_bar := HBoxContainer.new()
		resource_bar.add_theme_constant_override("separation", 10)
		resources_row = resource_bar
	row.add_child(resources_row)
	resources_row.add_child(_make_top_resource_chip("🔥", "%d/%d" % [1 if current_run.is_empty() else int(current_run.get("hp", 0)), 1 if current_run.is_empty() else int(current_run.get("max_hp", 0))], compact))
	resources_row.add_child(_make_top_resource_chip("🗂", "%d" % card_defs.size(), compact))
	resources_row.add_child(_make_top_resource_chip("🪙", _format_large_number(int(player_profile.get("gold", 0))), compact))
	resources_row.add_child(_make_top_resource_chip("🔷", _format_large_number(int(player_profile.get("soul_stones", 0))), compact))

	var actions: Control
	if compact:
		var action_grid := GridContainer.new()
		action_grid.columns = 3 if phone_portrait else 5
		action_grid.size_flags_horizontal = Control.SIZE_SHRINK_END
		action_grid.add_theme_constant_override("h_separation", 8)
		action_grid.add_theme_constant_override("v_separation", 8)
		actions = action_grid
	else:
		var action_bar := HBoxContainer.new()
		action_bar.alignment = BoxContainer.ALIGNMENT_END
		action_bar.add_theme_constant_override("separation", 8)
		actions = action_bar
	row.add_child(actions)
	if phone_portrait:
		_small_hub_button_config(actions, "가이드", "_show_ui_guide", "🗺", 54, 54, 11)
		_small_hub_button_config(actions, "설정", "_show_settings", "⚙", 54, 54, 11)
		_small_hub_button_config(actions, "종료", "_quit_game", "⏻", 54, 54, 11)
	else:
		_small_hub_button(actions, "도감", "_show_compendium", "📖")
		_small_hub_button(actions, "가이드", "_show_ui_guide", "🗺")
		_small_hub_button(actions, "업적", "_show_achievements", "🏆")
		_small_hub_button(actions, "설정", "_show_settings", "⚙")
		_small_hub_button(actions, "종료", "_quit_game", "⏻")
	return panel

func _make_main_menu_node_summary(compact: bool) -> Control:
	var panel: PanelContainer = ui.make_surface_panel(Color(0.09, 0.1, 0.12, 0.94), Color(0.22, 0.19, 0.11, 1.0), 1, 12, 16)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := _make_label("현재 런 정보", 22 if compact else 24, Color(1.0, 0.96, 0.9, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	var headline_text := "새 런을 시작해 빌드를 완성하세요."
	if not current_run.is_empty():
		headline_text = "Act %d 진행 중 - %s" % [int(current_run.get("act", 1)), String(_current_act().get("name", ""))]
	var headline_chip: PanelContainer = ui.make_chip(headline_text, Color(0.15, 0.18, 0.1, 1.0), Color(0.96, 0.94, 0.82, 1.0), 14 if compact else 15)
	box.add_child(headline_chip)
	for line_text in _run_summary_lines():
		var line_label := _make_label(line_text, 15 if compact else 16, Color(0.86, 0.92, 0.78, 1.0))
		line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(line_label)
	var status_row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	box.add_child(status_row)
	var node_value := "준비"
	var objective_value := "첫 런 시작"
	var reward_value := "카드 보상"
	if not current_run.is_empty():
		var act_data: Dictionary = _current_act()
		var nodes: Array = act_data.get("nodes", [])
		node_value = "%d / %d" % [int(current_run.get("current_node_index", 0)) + 1, max(1, nodes.size())]
		var node_index := int(current_run.get("current_node_index", 0))
		if node_index >= 0 and node_index < nodes.size():
			var node_data_variant: Variant = nodes[node_index]
			if typeof(node_data_variant) == TYPE_DICTIONARY:
				var node_data: Dictionary = node_data_variant
				objective_value = _node_type_name(String(node_data.get("type", "")))
				match String(node_data.get("type", "")):
					"battle":
						reward_value = "골드 + 카드"
					"elite":
						reward_value = "유물 + 카드"
					"event":
						reward_value = "선택 이벤트"
					"shop":
						reward_value = "구매 / 제거"
					"rest":
						reward_value = "회복 / 강화"
					"boss":
						reward_value = "최종 결과"
	status_row.add_child(ui.make_stat_tile("현재 노드", node_value, Color(0.14, 0.18, 0.24, 1.0), compact))
	status_row.add_child(ui.make_stat_tile("다음 목표", objective_value, Color(0.18, 0.17, 0.09, 1.0), compact))
	status_row.add_child(ui.make_stat_tile("예상 보상", reward_value, Color(0.12, 0.18, 0.14, 1.0), compact))
	var node_row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	node_row.add_theme_constant_override("separation", 8)
	box.add_child(node_row)
	var node_types: Array = ["battle", "battle", "event", "battle", "shop", "elite", "rest", "boss"]
	var current_index := int(current_run.get("current_node_index", 0)) if not current_run.is_empty() else -1
	for i in range(node_types.size()):
		var node_name := _node_type_name(String(node_types[i]))
		var color := Color(0.12, 0.14, 0.18, 1.0)
		if not current_run.is_empty() and i == current_index:
			color = Color(0.36, 0.34, 0.14, 1.0)
		elif not current_run.is_empty() and i < current_index:
			color = Color(0.18, 0.24, 0.18, 1.0)
		elif current_run.is_empty() and i == 0:
			color = Color(0.18, 0.22, 0.3, 1.0)
		var chip: PanelContainer = ui.make_chip(node_name, color, Color(0.96, 0.97, 0.94, 1.0), 13 if compact else 14)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node_row.add_child(chip)
	return panel

func _make_main_menu_recent_runs(compact: bool) -> Control:
	var panel: PanelContainer = ui.make_surface_panel(Color(0.09, 0.1, 0.12, 0.94), Color(0.16, 0.18, 0.22, 1.0), 1, 12, 16)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := _make_label("최근 런 기록", 22 if compact else 24, Color(1.0, 0.96, 0.9, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	var stats: Dictionary = _main_menu_recent_stats()
	var stats_row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 8)
	box.add_child(stats_row)
	stats_row.add_child(ui.make_stat_tile("승리", str(int(stats.get("wins", 0))), Color(0.14, 0.22, 0.16, 1.0), compact))
	stats_row.add_child(ui.make_stat_tile("패배", str(int(stats.get("losses", 0))), Color(0.24, 0.14, 0.14, 1.0), compact))
	stats_row.add_child(ui.make_stat_tile("승률", "%d%%" % int(stats.get("win_rate", 0)), Color(0.16, 0.18, 0.25, 1.0), compact))
	var recent: Array = _recent_runs()
	if recent.is_empty():
		var empty_label := _make_label("아직 기록이 없습니다. 첫 런을 시작하세요.", 15 if compact else 16, Color(0.8, 0.84, 0.9, 1.0))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(empty_label)
		return panel
	for entry_variant in recent:
		var entry: Dictionary = entry_variant
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		var result_text := String(entry.get("result", "승리"))
		var result_color := Color(0.54, 0.8, 0.42, 1.0) if result_text == "승리" else Color(0.9, 0.42, 0.36, 1.0)
		var badge: PanelContainer = ui.make_chip(result_text, Color(0.12, 0.14, 0.18, 1.0), result_color, 15 if compact else 16)
		badge.custom_minimum_size = Vector2(92, 40)
		row.add_child(badge)
		var info_box := VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_box.add_theme_constant_override("separation", 2)
		row.add_child(info_box)
		var act_label := _make_label(String(entry.get("act_name", "")), 15 if compact else 16, Color(0.94, 0.96, 0.92, 1.0))
		act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		info_box.add_child(act_label)
		var build_label := _make_label(String(entry.get("build_name", "")), 14 if compact else 15, Color(0.72, 0.84, 1.0, 1.0))
		build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		info_box.add_child(build_label)
		var time_label := _make_label(_relative_time_text(int(entry.get("timestamp", 0))), 14 if compact else 15, Color(0.86, 0.84, 0.72, 1.0))
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(time_label)
	return panel

func _make_main_menu_build_panel(compact: bool) -> Control:
	var panel: PanelContainer = ui.make_surface_panel(Color(0.08, 0.09, 0.11, 0.95), Color(0.16, 0.18, 0.22, 1.0), 1, 12, 16)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := _make_label("빌드 통계", 20 if compact else 22, Color(1.0, 0.96, 0.9, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var chip_row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 8)
	box.add_child(chip_row)
	var scores: Dictionary = _current_build_scores()
	var order := ["fire", "draw", "death", "buff", "low_hp", "summon"]
	for tag in order:
		var meta: Dictionary = _build_tag_meta().get(tag, {})
		var chip: PanelContainer = ui.make_chip("%s\n%d" % [String(meta.get("name", "")), int(scores.get(tag, 0))], Color(meta.get("color", Color(0.2, 0.2, 0.2, 1.0))).darkened(0.5), Color(0.96, 0.97, 0.94, 1.0), 15 if compact else 16)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip_row.add_child(chip)
	var active_label := _make_label(_active_build_text(scores), 16 if compact else 18, Color(1.0, 0.86, 0.52, 1.0))
	active_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(active_label)
	return panel

func _make_main_menu_content(compact: bool) -> Control:
	var phone_portrait := _is_phone_portrait_layout()
	var content: BoxContainer = VBoxContainer.new() if compact or phone_portrait else HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)

	var continue_subtitle := "진행 중인 런이 없습니다.\n새 런을 시작해 흐름을 여세요."
	if not current_run.is_empty():
		continue_subtitle = "Act %d - %s\n노드 %d / 8" % [int(current_run.get("act", 1)), String(_current_act().get("name", "")), int(current_run.get("current_node_index", 0)) + 1]
	if not phone_portrait:
		var left_column := VBoxContainer.new()
		left_column.custom_minimum_size = Vector2(250 if not compact else 0, 0)
		left_column.add_theme_constant_override("separation", 8)
		content.add_child(left_column)
		var continue_button := _menu_nav_button(left_column, "이어하기", continue_subtitle, "_continue_run", Color(0.18, 0.34, 0.16, 1.0), "✦", compact)
		continue_button.disabled = current_run.is_empty()
		_menu_nav_button(left_column, "새 런 시작", "새로운 모험을 시작합니다.", "_start_new_run", Color(0.16, 0.32, 0.58, 1.0), "⚔", compact)
		_menu_nav_button(left_column, "카드 컬렉션", "카드 도감과 보유 카드를 확인합니다.", "_show_collection", Color(0.12, 0.14, 0.18, 1.0), "🃏", compact)
		_menu_nav_button(left_column, "유물", "현재 유물과 해금 유물을 확인합니다.", "_show_compendium", Color(0.12, 0.14, 0.18, 1.0), "🜂", compact)
		_menu_nav_button(left_column, "메타 강화", "영혼석으로 시작 보너스를 강화합니다.", "_show_meta_upgrade", Color(0.12, 0.14, 0.18, 1.0), "🌿", compact)
		_menu_nav_button(left_column, "UI 설계 가이드", "8개 핵심 화면과 역할을 한 장으로 봅니다.", "_show_ui_guide", Color(0.12, 0.14, 0.18, 1.0), "🗺", compact)

	var center_column := VBoxContainer.new()
	center_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_column.add_theme_constant_override("separation", 10)
	content.add_child(center_column)
	var hero_panel: PanelContainer = ui.make_surface_panel(Color(0.045, 0.052, 0.06, 1.0), Color(0.36, 0.29, 0.16, 1.0), 1, 14, 0)
	hero_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_column.add_child(hero_panel)
	var hero_layer := MarginContainer.new()
	hero_layer.add_theme_constant_override("margin_left", 14)
	hero_layer.add_theme_constant_override("margin_top", 14)
	hero_layer.add_theme_constant_override("margin_right", 14)
	hero_layer.add_theme_constant_override("margin_bottom", 14)
	hero_panel.add_child(hero_layer)
	var hero_stack: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	hero_stack.add_theme_constant_override("separation", 12)
	hero_layer.add_child(hero_stack)
	var hero_text_box := VBoxContainer.new()
	hero_text_box.custom_minimum_size = Vector2(240 if not compact else 0, 0)
	hero_text_box.add_theme_constant_override("separation", 10)
	hero_stack.add_child(hero_text_box)
	var hero_kicker: PanelContainer = ui.make_chip("빌드 중심 로그라이크 덱빌딩", Color(0.14, 0.18, 0.1, 1.0), Color(0.98, 0.92, 0.72, 1.0), 12 if compact else 13)
	hero_text_box.add_child(hero_kicker)
	var logo_label := _make_label("CARD\nDRAFT", 34 if phone_portrait else (42 if compact else 60), Color(0.95, 0.92, 0.86, 1.0))
	logo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hero_text_box.add_child(logo_label)
	var tag_label := _make_label("약한 시작 덱으로 출발해\n이번 런만의 빌드를 완성하세요.", 15 if phone_portrait else (16 if compact else 19), Color(0.88, 0.9, 0.94, 1.0))
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hero_text_box.add_child(tag_label)
	if phone_portrait:
		var primary_title := "이어하기" if not current_run.is_empty() else "새 런 시작"
		var primary_subtitle := "바로 이어서 다음 전투로 갑니다." if not current_run.is_empty() else "바로 첫 전투 흐름으로 들어갑니다."
		var primary_method := "_continue_run" if not current_run.is_empty() else "_start_new_run"
		var primary_action: Button = ui.make_large_action_button(primary_title, primary_subtitle, "▶" if not current_run.is_empty() else "⚔", Color(0.16, 0.32, 0.58, 1.0), true)
		primary_action.custom_minimum_size = Vector2(0, 96)
		ui.style_flat_button(primary_action, Color(0.12, 0.24, 0.42, 1.0), Color(0.98, 0.82, 0.42, 1.0), 15, 3)
		primary_action.pressed.connect(Callable(self, primary_method))
		hero_text_box.add_child(primary_action)
		var immediate_hint := _make_label("지금은 큰 버튼 하나만 누르면 됩니다.", 13, Color(1.0, 0.9, 0.62, 1.0))
		immediate_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hero_text_box.add_child(immediate_hint)
		var quick_row := GridContainer.new()
		quick_row.columns = 2
		quick_row.add_theme_constant_override("h_separation", 8)
		quick_row.add_theme_constant_override("v_separation", 8)
		hero_text_box.add_child(quick_row)
		var collection_button := _small_hub_button_config(quick_row, "카드", "_show_collection", "🃏", 0, 48, 11)
		collection_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var meta_button := _small_hub_button_config(quick_row, "메타", "_show_meta_upgrade", "🌿", 0, 48, 11)
		meta_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var relic_button := _small_hub_button_config(quick_row, "유물", "_show_compendium", "🜂", 0, 48, 11)
		relic_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var guide_button := _small_hub_button_config(quick_row, "가이드", "_show_ui_guide", "🗺", 0, 48, 11)
		guide_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hero_objective: PanelContainer = ui.make_objective_panel("다음 행동", _main_menu_next_action_text().replace("다음 행동: ", ""), compact)
	hero_text_box.add_child(hero_objective)
	if not phone_portrait:
		var hero_summary_panel: PanelContainer = ui.make_surface_panel(Color(0.08, 0.1, 0.12, 0.98), Color(0.22, 0.2, 0.12, 1.0), 1, 10, 12)
		hero_text_box.add_child(hero_summary_panel)
		var hero_summary_box := VBoxContainer.new()
		hero_summary_box.add_theme_constant_override("separation", 6)
		hero_summary_panel.add_child(hero_summary_box)
		var hero_summary_title := _make_label("이번 런 핵심", 13 if compact else 14, Color(1.0, 0.88, 0.55, 1.0))
		hero_summary_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hero_summary_box.add_child(hero_summary_title)
		var hero_summary := _make_label(_hero_build_name(), 15 if compact else 17, Color(0.74, 0.84, 1.0, 1.0))
		hero_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hero_summary_box.add_child(hero_summary)
		var hero_active := _make_label(_active_build_text(_current_build_scores()), 13 if compact else 14, Color(0.94, 0.92, 0.78, 1.0))
		hero_active.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hero_summary_box.add_child(hero_active)
	var hero_stat_row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	hero_stat_row.add_theme_constant_override("separation", 8)
	hero_text_box.add_child(hero_stat_row)
	var deck_size := 10 if current_run.is_empty() else (current_run.get("deck_ids", []) as Array).size()
	var relic_count := 0 if current_run.is_empty() else (current_run.get("relic_ids", []) as Array).size()
	var gold_amount := int(player_profile.get("gold", 0)) if current_run.is_empty() else int(current_run.get("gold", 0))
	hero_stat_row.add_child(ui.make_stat_tile("덱", str(deck_size), Color(0.16, 0.18, 0.24, 1.0), compact))
	hero_stat_row.add_child(ui.make_stat_tile("유물", str(relic_count), Color(0.18, 0.16, 0.1, 1.0), compact))
	hero_stat_row.add_child(ui.make_stat_tile("골드", _format_large_number(gold_amount), Color(0.12, 0.18, 0.14, 1.0), compact))
	var hero_art_panel: PanelContainer = ui.make_surface_panel(Color(0.05, 0.055, 0.06, 1.0), Color(0.46, 0.38, 0.2, 1.0), 1, 12, 12)
	hero_art_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not phone_portrait:
		hero_stack.add_child(hero_art_panel)
	var hero_art_box := VBoxContainer.new()
	hero_art_box.add_theme_constant_override("separation", 8)
	hero_art_panel.add_child(hero_art_box)
	var hero_art_header: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	hero_art_header.add_theme_constant_override("separation", 8)
	hero_art_box.add_child(hero_art_header)
	hero_art_header.add_child(ui.make_chip("필드전 중심", Color(0.18, 0.16, 0.08, 1.0), Color(1.0, 0.92, 0.7, 1.0), 12 if compact else 13))
	hero_art_header.add_child(ui.make_chip("적 영웅 HP 0", Color(0.16, 0.09, 0.09, 1.0), Color(1.0, 0.84, 0.82, 1.0), 12 if compact else 13))
	if phone_portrait:
		hero_art_header.visible = false
	var hero_art := _make_art_rect(11, Vector2(360 if not compact else (220 if phone_portrait else 260), 290 if not compact else (180 if phone_portrait else 220)))
	hero_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_art_box.add_child(hero_art)
	if phone_portrait:
		center_column.add_child(_make_main_menu_node_summary(compact))
		var build_panel: Control = _make_main_menu_build_panel(compact)
		build_panel.visible = false
		center_column.add_child(build_panel)
	else:
		center_column.add_child(_make_main_menu_build_panel(compact))

	if not phone_portrait:
		var right_column := VBoxContainer.new()
		right_column.custom_minimum_size = Vector2(270 if not compact else 0, 0)
		right_column.add_theme_constant_override("separation", 10)
		content.add_child(right_column)
		right_column.add_child(_make_main_menu_node_summary(compact))
		right_column.add_child(_make_main_menu_recent_runs(compact))
	return content

func _make_main_menu_footer(compact: bool) -> Control:
	var phone_portrait := _is_phone_portrait_layout()
	var footer: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_theme_constant_override("separation", 14)

	if not phone_portrait:
		var tip_panel: PanelContainer = ui.make_surface_panel(Color(0.09, 0.1, 0.12, 0.95), Color(0.16, 0.18, 0.22, 1.0), 1, 12, 16)
		tip_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		footer.add_child(tip_panel)
		var tip_box := VBoxContainer.new()
		tip_box.add_theme_constant_override("separation", 8)
		tip_panel.add_child(tip_box)
		var tip_title := _make_label("오늘의 팁", 18 if compact else 20, Color(1.0, 0.9, 0.56, 1.0))
		tip_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		tip_box.add_child(tip_title)
		var tip_chip_row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
		tip_chip_row.add_theme_constant_override("separation", 8)
		tip_box.add_child(tip_chip_row)
		tip_chip_row.add_child(ui.make_chip("🔥 화염", Color(0.22, 0.12, 0.08, 1.0), Color(1.0, 0.88, 0.76, 1.0), 12 if compact else 13))
		tip_chip_row.add_child(ui.make_chip("💀 사망", Color(0.16, 0.1, 0.22, 1.0), Color(0.92, 0.88, 1.0, 1.0), 12 if compact else 13))
		var tip_text := _make_label("일부 카드와 유물은 특정 빌드 시너지를 강하게 만듭니다.", 15 if compact else 16, Color(0.86, 0.9, 0.96, 1.0))
		tip_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		tip_box.add_child(tip_text)

		var challenge_panel: PanelContainer = ui.make_surface_panel(Color(0.09, 0.1, 0.12, 0.95), Color(0.16, 0.18, 0.22, 1.0), 1, 12, 16)
		challenge_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		footer.add_child(challenge_panel)
		var challenge_box := VBoxContainer.new()
		challenge_box.add_theme_constant_override("separation", 10)
		challenge_panel.add_child(challenge_box)
		var challenge_title := _make_label("일일 도전", 18 if compact else 20, Color(1.0, 0.9, 0.56, 1.0))
		challenge_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		challenge_box.add_child(challenge_title)
		var progress: int = min(30, (current_run.get("visited_nodes", []) as Array).size() * 4) if not current_run.is_empty() else 0
		var challenge_text := _make_label("적 30마리 처치", 15 if compact else 16, Color(0.9, 0.94, 0.98, 1.0))
		challenge_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		challenge_box.add_child(challenge_text)
		var reward_preview_chip: PanelContainer = ui.make_chip("보상 100 골드", Color(0.18, 0.16, 0.08, 1.0), Color(1.0, 0.92, 0.72, 1.0), 13 if compact else 14)
		challenge_box.add_child(reward_preview_chip)
		var progress_bar_bg := ColorRect.new()
		progress_bar_bg.color = Color(0.16, 0.18, 0.22, 1.0)
		progress_bar_bg.custom_minimum_size = Vector2(0, 12)
		challenge_box.add_child(progress_bar_bg)
		var progress_bar_fill := ColorRect.new()
		progress_bar_fill.color = Color(0.88, 0.7, 0.24, 1.0)
		progress_bar_fill.custom_minimum_size = Vector2(max(8.0, (float(progress) / 30.0) * 220.0), 12)
		progress_bar_bg.add_child(progress_bar_fill)
		var progress_label := _make_label("%d / 30" % progress, 14 if compact else 15, Color(1.0, 0.9, 0.56, 1.0))
		progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		challenge_box.add_child(progress_label)

	var reward_panel: PanelContainer = ui.make_surface_panel(Color(0.09, 0.1, 0.12, 0.95), Color(0.16, 0.18, 0.22, 1.0), 1, 12, 16)
	reward_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(reward_panel)
	var reward_box := VBoxContainer.new()
	reward_box.add_theme_constant_override("separation", 12)
	reward_panel.add_child(reward_box)
	var reward_title := _make_label("데일리 보상", 18 if compact else 20, Color(1.0, 0.9, 0.56, 1.0))
	reward_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	reward_box.add_child(reward_title)
	var reward_text := _make_label("골드 100 / 영혼석 25", 15 if compact else 16, Color(0.9, 0.94, 0.98, 1.0))
	reward_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	reward_box.add_child(reward_text)
	var reward_hint := _make_label("런 준비 전에 한 번 챙길 수 있는 무료 보상입니다.", 13 if compact else 14, Color(0.84, 0.88, 0.94, 1.0))
	reward_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	reward_box.add_child(reward_hint)
	var claim_button := Button.new()
	claim_button.text = "데일리 보상 받기" if _can_claim_daily_reward() else "오늘은 수령 완료"
	claim_button.custom_minimum_size = Vector2(0, 64)
	ui.style_primary_button(claim_button, Color(0.28, 0.28, 0.12, 1.0))
	claim_button.disabled = not _can_claim_daily_reward()
	claim_button.pressed.connect(Callable(self, "_claim_daily_reward"))
	reward_box.add_child(claim_button)
	if phone_portrait:
		var reward_tip := _make_label("모바일에서는 먼저 이 버튼만 눌러도 됩니다.", 12, Color(0.84, 0.88, 0.94, 1.0))
		reward_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		reward_box.add_child(reward_tip)
		reward_panel.visible = false
	return footer

func _show_meta_upgrade() -> void:
	active_screen = "meta_upgrade"
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("메타 강화", false, "영혼석을 소모하여 영웅의 기초 능력치를 영구히 강화하세요.")
	_retain_screen_controller(MetaUpgradeScreenScript.new(self)).build(body)

func _show_compendium() -> void:
	active_screen = "compendium"
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("카드 도감", false, "게임에 존재하는 모든 영웅 카드와 유물들을 한눈에 살펴보세요.")
	_retain_screen_controller(CompendiumScreenScript.new(self)).build(body)

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
	run_flow.show_map()

func _enter_current_node(path_index: int = 0) -> void:
	if audio_manager != null:
		audio_manager.play_sound("click")
	current_run["current_path_index"] = path_index
	run_flow.enter_current_node()

func _show_card_reward() -> void:
	run_flow.show_card_reward()

func _show_event() -> void:
	run_flow.show_event()

func _complete_event_and_return() -> void:
	if audio_manager != null:
		audio_manager.play_sound("click")
	run_flow.complete_event_and_return()

func _show_shop() -> void:
	run_flow.show_shop()

func _show_rest() -> void:
	run_flow.show_rest()

func _rest_heal() -> void:
	if audio_manager != null:
		audio_manager.play_sound("click")
	run_flow.rest_heal()

func _rest_upgrade_card() -> void:
	if audio_manager != null:
		audio_manager.play_sound("click")
	run_flow.rest_upgrade_card()

func _complete_rest() -> void:
	if audio_manager != null:
		audio_manager.play_sound("click")
	run_flow.complete_rest()

func _show_remove_card_screen(reason: String, source: String = "") -> void:
	if not source.is_empty():
		current_run["pending_subscreen"] = {
			"type": "remove_card",
			"reason": reason,
			"source": source,
		}
		_save_run()
	active_screen = "remove_card"
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("%s - 카드 제거" % reason, false, "덱을 압축하여 원하는 핵심 카드를 더 자주 드로우할 수 있게 만듭니다.")
	_retain_screen_controller(DeckEditScreenScript.new(self)).build_remove(body, reason)

func _show_upgrade_card_screen(source: String = "") -> void:
	if not source.is_empty():
		current_run["pending_subscreen"] = {
			"type": "upgrade_card",
			"source": source,
		}
		_save_run()
	active_screen = "upgrade_card"
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("휴식 - 카드 강화", false, "소장 중인 카드를 명상으로 연마하여 상위 능력으로 각성시킵니다.")
	_retain_screen_controller(DeckEditScreenScript.new(self)).build_upgrade(body)

func _remove_card_from_run(card_id: String) -> void:
	var pending_subscreen: Dictionary = current_run.get("pending_subscreen", {})
	var source := String(pending_subscreen.get("source", ""))
	if source == "shop":
		var charge_result: Dictionary = shop_run_service.confirm_remove(current_run)
		if not bool(charge_result.get("ok", false)):
			current_run["pending_subscreen"] = {}
			_save_run()
			_show_shop()
			return
	var deck_ids: Array = current_run.get("deck_ids", [])
	var index := deck_ids.find(card_id)
	if index != -1:
		deck_ids.remove_at(index)
	current_run["deck_ids"] = deck_ids
	current_run["pending_subscreen"] = {}
	_save_run()
	match source:
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
	if card_id.ends_with("_plus"):
		return
	var deck_ids: Array = current_run.get("deck_ids", [])
	var upgraded_id := card_id
	var plus_id := "%s_plus" % card_id
	if not card_db.get_card(plus_id).is_empty():
		upgraded_id = plus_id
	var index := deck_ids.find(card_id)
	if index != -1:
		deck_ids[index] = upgraded_id
	current_run["deck_ids"] = deck_ids
	var pending_subscreen: Dictionary = current_run.get("pending_subscreen", {})
	var source := String(pending_subscreen.get("source", ""))
	current_run["pending_subscreen"] = {}
	_save_run()
	if source == "event_complete_upgrade":
		_complete_event_and_return()
		return
	_complete_rest()

func _cancel_pending_subscreen() -> void:
	var pending_subscreen: Dictionary = current_run.get("pending_subscreen", {})
	var source := String(pending_subscreen.get("source", ""))
	current_run["pending_subscreen"] = {}
	_save_run()
	match source:
		"event_complete", "event_complete_upgrade":
			_complete_event_and_return()
		"rest", "rest_upgrade":
			_complete_rest()
		_:
			_show_shop()

func _show_run_result(is_win: bool) -> void:
	active_screen = "run_result"
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("런 결과", false, "이번 모험이 종료되었습니다. 최종 달성 기록과 통계를 확인하세요.")
	_retain_screen_controller(RunResultScreenScript.new(self)).build(body, is_win)

func _finish_run(is_win: bool) -> void:
	current_run["result"] = "win" if is_win else "loss"
	current_run["finished_at"] = Time.get_unix_time_from_system()
	var earned_soul_stones := _run_soul_stones(is_win)
	current_run["earned_soul_stones"] = earned_soul_stones
	player_profile["soul_stones"] = int(player_profile.get("soul_stones", 0)) + earned_soul_stones
	_record_recent_run(is_win)
	_save_profile()
	current_run["active_enemy"] = {}
	current_run["battle_snapshot"] = {}
	current_run["pending_event"] = {}
	current_run["pending_message"] = {}
	current_run["pending_shop"] = {}
	current_run["pending_subscreen"] = {}
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
	var body: VBoxContainer = _begin_menu_screen("카드 보관함", false, "현재 덱을 구성하고 있는 소장 카드들의 목록입니다.")
	var screen = _retain_screen_controller(CollectionScreenScript.new(self))
	screen.build(body)

func _show_ui_guide() -> void:
	active_screen = "ui_guide"
	_clear_screen()
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root_box.add_child(body)
	var screen = _retain_screen_controller(UiGuideScreenScript.new(self))
	screen.build(body)

func _show_settings() -> void:
	active_screen = "settings"
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("설정", false, "게임 해상도 및 속도 등 편의 기능을 변경하고 튜닝할 수 있습니다.")
	_retain_screen_controller(SettingsScreenScript.new(self)).build(body)

func _on_cutscene_toggled(enabled: bool) -> void:
	player_profile["settings"]["battle_cutscene"] = enabled
	_save_profile()

func _on_fast_ai_toggled(enabled: bool) -> void:
	player_profile["settings"]["fast_ai"] = enabled
	_save_profile()

func _on_fullscreen_toggled(enabled: bool) -> void:
	if OS.has_feature("web"):
		player_profile["settings"]["fullscreen"] = false
		player_profile["settings"]["fullscreen_setting_initialized"] = true
		_save_profile()
		_show_settings()
		return
	player_profile["settings"]["fullscreen"] = enabled
	player_profile["settings"]["fullscreen_setting_initialized"] = true
	_save_profile()
	_apply_window_mode()

func _reset_profile() -> void:
	player_profile = profile_store.make_default_profile(card_defs)
	player_profile = profile_store.apply_local_debug_defaults(player_profile, card_defs)
	_save_profile()
	_apply_window_mode()
	_show_message("로컬 프로필을 초기화했습니다.", "_show_main_menu")

func _show_message(message: String, callback_method: String, target: Object = null) -> void:
	active_screen = "message"
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("알림", false, "게임 진행에 필요한 안내 메시지입니다.")
	_retain_screen_controller(MessageScreenScript.new(self)).build(body, message, callback_method, target)

func _make_run_summary_panel() -> Control:
	var compact := _is_compact_layout()
	var panel: PanelContainer = ui.make_surface_panel(Color(0.055, 0.065, 0.075, 0.98), Color(0.25, 0.21, 0.12, 1.0), 1, 10, 10)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 6)
	panel.add_child(wrapper)
	var row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(row)
	var act_label: Label = _make_label("Act %d · %s" % [int(current_run.get("act", 1)), String(_current_act().get("name", "런"))], 14 if compact else 15, Color(1.0, 0.88, 0.55, 1.0))
	act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	act_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(act_label)
	row.add_child(ui.make_chip("HP %d/%d" % [int(current_run.get("hp", 0)), int(current_run.get("max_hp", 0))], Color(0.34, 0.12, 0.12, 1.0), Color(1.0, 0.82, 0.82, 1.0), 13 if compact else 14))
	row.add_child(ui.make_chip("골드 %s" % _format_large_number(int(current_run.get("gold", 0))), Color(0.38, 0.28, 0.1, 1.0), Color(1.0, 0.9, 0.56, 1.0), 13 if compact else 14))
	row.add_child(ui.make_chip("덱 %d" % (current_run.get("deck_ids", []) as Array).size(), Color(0.12, 0.22, 0.34, 1.0), Color(0.86, 0.92, 1.0, 1.0), 13 if compact else 14))
	var scores := _current_build_scores()
	var build_line := _build_status_text(scores).replace("현재 빌드  ", "")
	var active_line := _active_build_text(scores)
	var build_label: Label = _make_label("%s  |  %s" % [build_line, active_line], 12 if compact else 13, Color(0.86, 0.9, 0.96, 1.0))
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	wrapper.add_child(build_label)
	var relics: Array = current_run.get("relic_ids", [])
	if not relics.is_empty():
		var relic_row = HBoxContainer.new()
		relic_row.add_theme_constant_override("separation", 6)
		var relic_title = _make_label("보유 유물:", 12 if compact else 13, Color(0.8, 0.8, 0.8, 1.0))
		relic_row.add_child(relic_title)
		for relic_id in relics:
			var relic_def = relic_service.get_relic(String(relic_id))
			relic_row.add_child(ui.make_relic_badge(relic_def, compact))
		wrapper.add_child(relic_row)
	return panel

func _profile_upgrades() -> Dictionary:
	if not player_profile.has("upgrades") or typeof(player_profile["upgrades"]) != TYPE_DICTIONARY:
		player_profile["upgrades"] = {
			"start_hp": 0,
			"start_gold": 0,
			"second_chance": 0,
		}
	return player_profile["upgrades"]

func _build_tag_meta() -> Dictionary:
	return {
		"fire": {"icon": "🔥", "name": "화염", "color": Color(0.84, 0.34, 0.16, 1.0), "bonus": "화염 피해 +2"},
		"draw": {"icon": "📖", "name": "드로우", "color": Color(0.24, 0.46, 0.82, 1.0), "bonus": "드로우 엔진 성장"},
		"death": {"icon": "💀", "name": "사망", "color": Color(0.48, 0.28, 0.58, 1.0), "bonus": "사망 시너지 성장"},
		"buff": {"icon": "⚔", "name": "버프", "color": Color(0.7, 0.58, 0.18, 1.0), "bonus": "필드 강화 시너지 성장"},
		"low_hp": {"icon": "❤️", "name": "저체력", "color": Color(0.76, 0.22, 0.28, 1.0), "bonus": "위험할수록 강해짐"},
		"summon": {"icon": "👥", "name": "소환", "color": Color(0.22, 0.58, 0.32, 1.0), "bonus": "토큰/물량 시너지 성장"},
	}

func _build_threshold() -> int:
	return 5

func _valid_build_tags() -> Array[String]:
	return ["fire", "draw", "death", "buff", "low_hp", "summon"]

func _build_tags_from_data(source: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	var raw_tags: Variant = source.get("build_tags", [])
	if typeof(raw_tags) != TYPE_ARRAY:
		return tags
	var allowed := _valid_build_tags()
	for raw_tag in raw_tags:
		var tag := String(raw_tag)
		if allowed.has(tag) and not tags.has(tag):
			tags.append(tag)
	return tags

func _card_build_tags(card: Dictionary) -> Array[String]:
	var data_tags := _build_tags_from_data(card)
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

func _base_card_id(card_id: String) -> String:
	if card_id.ends_with("_plus"):
		return card_id.trim_suffix("_plus")
	return card_id

func _card_effect_summary(card: Dictionary) -> String:
	var card_id := _base_card_id(String(card.get("id", "")))
	var card_type := String(card.get("type", ""))
	if card_type == "unit":
		var unit_parts: Array[String] = ["%d/%d 유닛 소환" % [int(card.get("attack", 0)), int(card.get("health", 0))]]
		match card_id:
			"militia":
				unit_parts.append("앞 적 1 피해")
			"trainee_swordsman":
				unit_parts.append("자신 체력 +1")
			"forest_archer":
				unit_parts.append("카드 1장 뽑기")
			"knight_spearman":
				unit_parts.append("앞 아군 공격 +1")
			"thief":
				unit_parts.append("내 HP 1 잃음")
			"bone_oracle":
				unit_parts.append("적 영웅 저주 +1")
			"ritual_sapling":
				unit_parts.append("의식 +1")
			"stone_golem":
				unit_parts.append("내 HP 2 회복")
			"bone_soldier":
				unit_parts.append("죽으면 적 영웅 1 피해")
			"grave_knight":
				unit_parts.append("죽으면 내 HP 2 회복")
			"berserker":
				unit_parts.append("죽으면 내 HP 2 잃음")
		return " · ".join(unit_parts.slice(0, 2))
	if card_type == "equipment":
		match card_id:
			"training_sword":
				return "앞 아군 공격 +2"
		return "아군 장비 강화"
	var parts: Array[String] = []
	match card_id:
		"small_flame":
			parts.append("앞 적 2 피해")
			parts.append("처치 시 1드로우")
		"fireball":
			parts.append("앞 적 또는 영웅 4 피해")
		"gale_shot":
			parts.append("앞 적 1 피해")
			parts.append("3장째면 4 피해")
		"first_aid":
			parts.append("내 HP 3 회복")
			parts.append("앞 아군 체력 +1")
		"captain_order":
			parts.append("아군 전체 공격 +1")
		"royal_support":
			parts.append("카드 1장 뽑기")
			parts.append("인간 있으면 체력 +1")
		"elven_insight":
			parts.append("카드 2장 뽑기")
		"nature_blessing":
			parts.append("앞 아군 체력 +3")
		"dark_bargain":
			parts.append("내 HP 2 잃음")
			parts.append("카드 2장 뽑기")
		"call_of_dead":
			parts.append("1/1 해골 2마리 소환")
		"corpse_explosion":
			parts.append("아군 하나 처치")
			parts.append("모든 적 2 피해")
		"healing_potion":
			parts.append("내 HP 5 회복")
		"death_mark":
			parts.append("적 영웅 저주 +1")
		"plague_spread":
			parts.append("모든 적 유닛 1 피해")
			parts.append("적 영웅 저주 +2")
		"world_tree_ritual":
			parts.append("의식 +1")
		"nature_communion":
			parts.append("의식 +1")
			parts.append("카드 1장 뽑기")
		"moonwell":
			parts.append("내 HP 4 회복")
			parts.append("의식 +1")
		"ancient_oath":
			parts.append("의식 +2")
			parts.append("카드 1장 뽑기")
		"soul_shackle":
			parts.append("적 영웅 저주 +2")
			parts.append("카드 1장 뽑기")
		"funeral_fog":
			parts.append("앞 적 또는 영웅 2 피해")
			parts.append("적 영웅 저주 +1")
		"vampiric_strike":
			parts.append("앞 적 또는 영웅 2 피해")
			parts.append("내 HP 2 회복")
		"battlecry":
			parts.append("아군 전체 +1/+1")
	if parts.is_empty():
		var raw_text := String(card.get("text", "")).strip_edges()
		if not raw_text.is_empty() and raw_text != "효과 없음":
			return raw_text
		return "기본 전투용 카드"
	return " · ".join(parts.slice(0, 2))

func _card_detail_text(card: Dictionary) -> String:
	var summary := _card_effect_summary(card)
	var raw_text := String(card.get("text", "")).strip_edges()
	if raw_text.is_empty() or raw_text == summary:
		return summary
	if raw_text == "효과 없음":
		return "%s\n효과 없음" % summary
	return "%s\n%s" % [summary, raw_text]

func _relic_build_tags(relic: Dictionary) -> Array[String]:
	var data_tags := _build_tags_from_data(relic)
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

func _current_build_scores() -> Dictionary:
	var scores := {
		"fire": 0,
		"draw": 0,
		"death": 0,
		"buff": 0,
		"low_hp": 0,
		"summon": 0,
	}
	if current_run.is_empty():
		return scores
	for card_id_variant in current_run.get("deck_ids", []):
		var card: Dictionary = card_db.get_card(String(card_id_variant))
		if card.is_empty():
			continue
		for tag in _card_build_tags(card):
			scores[tag] = int(scores.get(tag, 0)) + 1
	for relic_id_variant in current_run.get("relic_ids", []):
		var relic: Dictionary = relic_service.get_relic(String(relic_id_variant))
		if relic.is_empty():
			continue
		for tag in _relic_build_tags(relic):
			scores[tag] = int(scores.get(tag, 0)) + 2
	return scores

func _active_build_tags(scores: Dictionary) -> Array[String]:
	var active: Array[String] = []
	for tag in _build_tag_meta().keys():
		if int(scores.get(tag, 0)) >= _build_threshold():
			active.append(String(tag))
	return active

func _primary_build_tag(scores: Dictionary) -> String:
	var best_tag := ""
	var best_score := 0
	for tag in _build_tag_meta().keys():
		var score := int(scores.get(tag, 0))
		if score > best_score:
			best_score = score
			best_tag = String(tag)
	return best_tag

func _build_status_text(scores: Dictionary) -> String:
	var meta := _build_tag_meta()
	var order := ["fire", "draw", "death", "buff", "low_hp", "summon"]
	var parts: Array[String] = []
	for tag in order:
		var tag_meta: Dictionary = meta.get(tag, {})
		parts.append("%s %s %d" % [String(tag_meta.get("icon", "")), String(tag_meta.get("name", "")), int(scores.get(tag, 0))])
	return "현재 빌드  " + " | ".join(parts)

func _active_build_text(scores: Dictionary) -> String:
	var active := _active_build_tags(scores)
	if active.is_empty():
		var primary := _primary_build_tag(scores)
		if primary.is_empty():
			return "지금은 초반 빌드 탐색 구간입니다."
		var meta: Dictionary = _build_tag_meta().get(primary, {})
		return "추천 방향: %s %s" % [String(meta.get("icon", "")), String(meta.get("name", ""))]
	var lines: Array[String] = []
	for tag in active:
		var meta: Dictionary = _build_tag_meta().get(tag, {})
		lines.append("%s %s 빌드 활성 - %s" % [String(meta.get("icon", "")), String(meta.get("name", "")), String(meta.get("bonus", ""))])
	return "\n".join(lines)

func _make_build_status_panel() -> Control:
	var compact := _is_compact_layout()
	var panel := _make_screen_panel(Color(0.1, 0.115, 0.145, 1.0), 960 if not compact else 420)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var scores := _current_build_scores()
	var status := _make_label(_build_status_text(scores), 13 if compact else 14, Color(0.92, 0.94, 0.98, 1.0))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(status)
	var active_text := _make_label(_active_build_text(scores), 13 if compact else 14, Color(1.0, 0.88, 0.55, 1.0))
	active_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(active_text)
	var goal := _make_label("현재 목표: 적 영웅 체력을 0으로 만드세요.", 13 if compact else 14, Color(0.78, 0.84, 0.94, 1.0))
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(goal)
	return panel

func _format_card_tag_text(card: Dictionary) -> String:
	var tags := _card_build_tags(card)
	if tags.is_empty():
		return ""
	var meta := _build_tag_meta()
	var parts: Array[String] = []
	for tag in tags:
		var tag_meta: Dictionary = meta.get(tag, {})
		parts.append("%s %s" % [String(tag_meta.get("icon", "")), String(tag_meta.get("name", ""))])
	return " / ".join(parts)

func _battle_build_hint_text() -> String:
	var scores := _current_build_scores()
	var active := _active_build_tags(scores)
	if not active.is_empty():
		var primary := active[0]
		var meta: Dictionary = _build_tag_meta().get(primary, {})
		return "%s %s 활성" % [String(meta.get("icon", "")), String(meta.get("name", ""))]
	return _build_status_text(scores)

func _build_active_in_current_run(tag: String) -> bool:
	return _active_build_tags(_current_build_scores()).has(tag)

func _card_matches_build_tag(card: Dictionary, tag: String) -> bool:
	return not tag.is_empty() and _card_build_tags(card).has(tag)

func _build_score_delta_for_card(card: Dictionary) -> Dictionary:
	var delta := {}
	for tag in _card_build_tags(card):
		delta[tag] = int(delta.get(tag, 0)) + 1
	return delta

func _build_delta_summary(card: Dictionary) -> Dictionary:
	var before_scores: Dictionary = _current_build_scores()
	var delta: Dictionary = _build_score_delta_for_card(card)
	if delta.is_empty():
		return {
			"headline": "시너지 변화 없음",
			"detail": "",
			"primary_tag": "",
			"will_activate": false,
		}
	var best_tag := ""
	var best_after := -1
	for tag in delta.keys():
		var after_score := int(before_scores.get(tag, 0)) + int(delta.get(tag, 0))
		if after_score > best_after:
			best_after = after_score
			best_tag = String(tag)
	var tag_meta: Dictionary = _build_tag_meta().get(best_tag, {})
	var before_score := int(before_scores.get(best_tag, 0))
	var after_score := before_score + int(delta.get(best_tag, 0))
	var will_activate := before_score < _build_threshold() and after_score >= _build_threshold()
	var headline := "%s %s %+d" % [String(tag_meta.get("icon", "")), String(tag_meta.get("name", "")), int(delta.get(best_tag, 0))]
	var detail := "%d -> %d" % [before_score, after_score]
	if will_activate:
		detail += "  |  활성화"
	elif after_score >= _build_threshold() - 1:
		detail += "  |  핵심 직전"
	return {
		"headline": headline,
		"detail": detail,
		"primary_tag": best_tag,
		"will_activate": will_activate,
	}

func _plain_build_help(tag: String) -> String:
	match tag:
		"fire":
			return "화염 카드가 더 세집니다."
		"draw":
			return "카드를 더 빨리 돌릴 수 있습니다."
		"death":
			return "죽으면서도 피해를 더 벌 수 있습니다."
		"buff":
			return "내 유닛을 더 크게 키울 수 있습니다."
		"low_hp":
			return "위험할 때 버티면서 반격하기 쉬워집니다."
		"summon":
			return "유닛을 많이 깔고 몰아치기 쉬워집니다."
		_:
			return "이번 덱 방향을 더 선명하게 만듭니다."

func _plain_build_delta_text(card: Dictionary) -> String:
	var summary: Dictionary = _build_delta_summary(card)
	var tag := String(summary.get("primary_tag", ""))
	if tag.is_empty():
		return "지금 전투를 바로 돕는 카드입니다."
	var text := _plain_build_help(tag)
	if bool(summary.get("will_activate", false)):
		return "%s 이번 선택으로 바로 켜집니다." % text
	var detail := String(summary.get("detail", ""))
	if detail.contains("핵심 직전"):
		return "%s 거의 완성 직전입니다." % text
	return text

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
	var pool: Array[String] = _reward_card_pool()
	while ids.size() < count and not pool.is_empty():
		var index := randi() % pool.size()
		ids.append(pool[index])
		pool.remove_at(index)
	return ids

func _roll_card_reward_choices(count: int, high_cost_only: bool = false) -> Array[String]:
	var ids: Array[String] = []
	var primary_tag := _primary_build_tag(_current_build_scores())
	if not primary_tag.is_empty():
		var tagged_pool := _reward_card_pool(primary_tag, high_cost_only)
		if not tagged_pool.is_empty():
			var tagged_index := randi() % tagged_pool.size()
			ids.append(tagged_pool[tagged_index])
	var pool: Array[String] = _reward_card_pool("", high_cost_only)
	for picked_id in ids:
		pool.erase(picked_id)
	while ids.size() < count and not pool.is_empty():
		var index := randi() % pool.size()
		ids.append(pool[index])
		pool.remove_at(index)
	return ids

func _roll_high_cost_cards(count: int) -> Array[String]:
	var pool: Array[String] = _reward_card_pool("", true)
	if pool.is_empty():
		return _roll_card_choices(count)
	var ids: Array[String] = []
	while ids.size() < count and not pool.is_empty():
		var index := randi() % pool.size()
		ids.append(pool[index])
		pool.remove_at(index)
	return ids

func _reward_card_pool(tag_filter: String = "", high_cost_only: bool = false) -> Array[String]:
	var pool: Array[String] = []
	for card in card_defs:
		var card_id := String(card.get("id", ""))
		if bool(card.get("starter", false)) or card_id.ends_with("_plus"):
			continue
		if high_cost_only and int(card.get("cost", 0)) < 3:
			continue
		if not tag_filter.is_empty() and not _card_build_tags(card).has(tag_filter):
			continue
		pool.append(card_id)
	return pool

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

func _is_compact_layout() -> bool:
	return _is_compact_layout_for()

func _is_main_menu_compact_layout() -> bool:
	return _is_compact_layout_for(1480.0, 860.0)

func _is_phone_portrait_layout() -> bool:
	var viewport_size: Vector2 = _layout_viewport_size()
	return viewport_size.x <= 900.0 and viewport_size.y > viewport_size.x

func _is_compact_layout_for(width_breakpoint: float = 860.0, height_breakpoint: float = 0.0) -> bool:
	var viewport_size: Vector2 = _layout_viewport_size()
	if viewport_size.x < width_breakpoint:
		return true
	return height_breakpoint > 0.0 and viewport_size.y < height_breakpoint

func _layout_viewport_size() -> Vector2:
	if has_meta("layout_viewport_override"):
		var layout_override: Variant = get_meta("layout_viewport_override")
		if layout_override is Vector2i:
			return Vector2(layout_override)
		if layout_override is Vector2:
			return layout_override
	var env_override := OS.get_environment("CARD_DRAFT_LAYOUT_OVERRIDE")
	if not env_override.is_empty():
		var parts := env_override.split("x", false)
		if parts.size() == 2:
			var override_width := int(parts[0])
			var override_height := int(parts[1])
			if override_width > 0 and override_height > 0:
				return Vector2(override_width, override_height)
	var viewport_size := get_viewport_rect().size
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		return viewport_size
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x > 0 and window_size.y > 0:
		return Vector2(window_size.x, window_size.y)
	return Vector2(1920, 1080)

func _apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless" or bool(get_meta("disable_window_mode_changes", false)):
		return
	if OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		return
	var fullscreen_enabled := bool(player_profile.get("settings", {}).get("fullscreen", false))
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)

func _begin_menu_screen(title: String, with_profile: bool = false, subtitle: String = "") -> VBoxContainer:
	var summary: Control = null
	if with_profile and not current_run.is_empty():
		summary = _make_run_summary_panel()
	var body: VBoxContainer = ui.begin_screen(root_box, title, summary, 12, subtitle)
	if _should_show_run_escape_actions():
		body.add_child(_make_run_escape_bar())
	return body

func _should_show_run_escape_actions() -> bool:
	if current_run.is_empty():
		return false
	return active_screen not in ["main_menu", "run_result", "battle"]

func _make_run_escape_bar() -> PanelContainer:
	var compact := _is_compact_layout_for(1180.0, 760.0)
	var panel: PanelContainer = ui.make_surface_panel(Color(0.055, 0.065, 0.08, 0.98), Color(0.24, 0.2, 0.12, 1.0), 1, 10, 10)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var hint: Label = _make_label("중간 종료", 12 if compact else 13, Color(1.0, 0.88, 0.55, 1.0))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)

	var actions: BoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(actions)

	_add_escape_action_button(actions, "메인 메뉴", "_show_main_menu", Color(0.16, 0.2, 0.26, 1.0), compact)
	_add_escape_action_button(actions, "런 포기", "_abandon_run", Color(0.34, 0.14, 0.14, 1.0), compact)
	_add_escape_action_button(actions, "게임 종료", "_quit_game", Color(0.18, 0.18, 0.18, 1.0), compact)
	return panel

func _add_escape_action_button(parent: Node, text: String, callback_method: String, color: Color, compact: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(96 if compact else 108, 34 if compact else 36)
	ui.style_button(button, color)
	button.add_theme_font_size_override("font_size", 12 if compact else 13)
	button.pressed.connect(Callable(self, callback_method))
	parent.add_child(button)
	return button

func _make_screen_panel(color: Color, preferred_width: int, min_height: int = 0) -> PanelContainer:
	return ui.make_screen_panel(color, _layout_viewport_size().x, preferred_width, min_height)

func _make_responsive_panel(color: Color, preferred_width: int, min_height: int = 0) -> PanelContainer:
	return ui.make_responsive_panel(color, _layout_viewport_size().x, preferred_width, min_height)

func _make_panel_container(color: Color) -> PanelContainer:
	return ui.make_panel_container(color)

func _make_card_frame() -> PanelContainer:
	return ui.make_card_frame()

func _make_art_rect(art_index: int, size: Vector2) -> TextureRect:
	return ui.make_art_rect(art_index, size)

func _make_card_art_rect(card: Dictionary, size: Vector2) -> TextureRect:
	return ui.make_card_art_rect(card, size)

func _make_label(text: String, font_size: int, color: Color) -> Label:
	return ui.make_label(text, font_size, color)

func _add_menu_button(parent: Node, text: String, callback_method: String, color: Color, target: Object = null) -> Button:
	var callback_target: Object = self if target == null else target
	return ui.add_menu_button(parent, callback_target, text, callback_method, color)

func _add_title(text: String) -> void:
	ui.add_title(root_box, text)

func _quit_game() -> void:
	get_tree().quit()

func _prepare_battle(tier: String) -> void:
	run_flow.prepare_battle(tier)
