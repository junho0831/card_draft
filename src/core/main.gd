extends Control

const LayoutPolicy = preload("res://src/ui/layout_policy.gd")

const MAX_MANA := 10
const MAX_FIELD := 5
const START_HAND := 4
const GameStorage := preload("res://src/services/game_storage.gd")
const CARD_DATA_PATH := "res://data/cards.json"
const CARD_LORE_DATA_PATH := "res://data/card_lore.json"
const CARD_ART_SHEET := preload("res://assets/card_art/season1_sample_sheet.png")
const BATTLE_CUTSCENE_SCENE := preload("res://src/battle/BattleCutscene.tscn")
const BattleCardEffectsScript := preload("res://src/battle/battle_card_effects.gd")
const CardDatabaseScript := preload("res://src/services/card_database.gd")
const CardLoreServiceScript := preload("res://src/services/card_lore_service.gd")
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
const RaceSelectionScreenScript := preload("res://src/ui/screens/race_selection_screen.gd")
const RunResultScreenScript := preload("res://src/ui/screens/run_result_screen.gd")
const SettingsScreenScript := preload("res://src/ui/screens/settings_screen.gd")
const UiGuideScreenScript := preload("res://src/ui/screens/ui_guide_screen.gd")
const UiFactoryScript := preload("res://src/ui/ui_factory.gd")
const AudioManagerScript := preload("res://src/services/audio_manager.gd")
const CARD_ART_COLS := 4
const CARD_ART_ROWS := 3
const BASE_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const MAX_AUTO_UI_SCALE := 1.45

var card_db
var card_lore_service
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
const Onboarding = preload("res://src/services/onboarding_service.gd")
const StartingStrategies = preload("res://src/services/starting_strategy_service.gd")
var pending_strategy_id := ""
var pending_guided_run := false
var pending_race_selection_id := "human"

var root_box: VBoxContainer
var touch_input_active := OS.has_feature("mobile")
var touch_scroll_router = preload("res://src/ui/touch_scroll_router.gd").new()
var mobile_bottom_inset := 0.0
var root_scroll: ScrollContainer
var root_center: CenterContainer
var modal_layer: Control
var battle_cutscene
var layout_resize_timer: Timer
var last_layout_signature := ""
var pending_layout_signature := ""
var active_message_text := ""
var active_message_callback := ""

func _configure_runtime_performance() -> void:
	Engine.max_fps = 60


func _ready() -> void:
	if not GameStorage.test_directory().is_empty() and not GameStorage.prepare_test_directory():
		push_error("테스트 저장 경로를 준비하지 못했습니다. 실행을 중단합니다.")
		get_tree().quit(2)
		return
	_configure_runtime_performance()
	_configure_content_scale()
	card_db = CardDatabaseScript.new()
	card_lore_service = CardLoreServiceScript.new()
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
	if not card_lore_service.load_lore(CARD_LORE_DATA_PATH):
		_show_error_screen("카드 스토리 데이터 로드 실패")
		return
	if not event_service.load_events() or not enemy_service.load_enemies() or not relic_service.load_relics():
		_show_error_screen("런 데이터 로드 실패")
		return

	card_defs = card_db.card_defs
	cards_by_id = card_db.cards_by_id
	player_profile = profile_store.load_or_create(GameStorage.profile_path(), card_defs)
	player_profile = profile_store.apply_local_debug_defaults(player_profile, card_defs)
	_save_profile()
	_apply_root_layout()
	_apply_window_mode()
	current_run = run_store.load_or_empty(GameStorage.run_path())
	_show_main_menu()
	last_layout_signature = _layout_signature(_layout_viewport_size())
	var game_window := get_window()
	if game_window != null and not game_window.size_changed.is_connected(Callable(self, "_on_window_size_changed")):
		game_window.size_changed.connect(Callable(self, "_on_window_size_changed"))

func _create_premium_background() -> Texture2D:
	if ResourceLoader.exists("res://assets/backgrounds/siege_castle_v1.png"):
		return load("res://assets/backgrounds/siege_castle_v1.png") as Texture2D
	var gradient := Gradient.new()
	gradient.offsets = [0.0, 0.48, 1.0]
	gradient.colors = [
		Color(0.075, 0.09, 0.12, 1.0),
		Color(0.026, 0.033, 0.046, 1.0),
		Color(0.012, 0.016, 0.025, 1.0)
	]
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 512
	tex.height = 512
	return tex

func _build_base_ui() -> void:
	var interface_theme := Theme.new()
	var interface_font := SystemFont.new()
	interface_font.font_names = PackedStringArray(["Noto Sans CJK KR", "Noto Sans", "sans-serif"])
	interface_font.font_weight = 500
	interface_theme.default_font = interface_font
	interface_theme.default_font_size = 14
	theme = interface_theme
	var background := TextureRect.new()
	background.name = "WorldBackground"
	background.texture = _create_premium_background()
	background.modulate = Color.WHITE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var ambient_scrim := ColorRect.new()
	ambient_scrim.color = Color(0.01, 0.018, 0.03, 0.12)
	ambient_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ambient_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ambient_scrim)

	var bottom_fade := ColorRect.new()
	bottom_fade.color = Color(0.0, 0.0, 0.0, 0.18)
	bottom_fade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_fade.offset_top = -180
	bottom_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_fade)

	var top_shadow := ColorRect.new()
	top_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_shadow.color = Color(0.0, 0.0, 0.0, 0.2)
	top_shadow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_shadow.offset_bottom = 92
	add_child(top_shadow)

	root_scroll = ScrollContainer.new()
	root_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_scroll.offset_left = 8
	root_scroll.offset_top = 8
	root_scroll.offset_right = -8
	root_scroll.offset_bottom = -8
	root_scroll.follow_focus = true
	root_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(root_scroll)

	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)

	root_center = CenterContainer.new()
	root_center.mouse_filter = Control.MOUSE_FILTER_PASS
	root_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root_scroll.add_child(root_center)

	root_box = VBoxContainer.new()
	root_box.mouse_filter = Control.MOUSE_FILTER_PASS
	root_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root_box.add_theme_constant_override("separation", 12)
	root_center.add_child(root_box)
	_apply_root_layout()

	battle_cutscene = BATTLE_CUTSCENE_SCENE.instantiate()
	add_child(battle_cutscene)

	layout_resize_timer = Timer.new()
	layout_resize_timer.one_shot = true
	layout_resize_timer.wait_time = 0.2
	layout_resize_timer.timeout.connect(Callable(self, "_on_layout_resize_timeout"))
	add_child(layout_resize_timer)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and active_screen == "battle" and battle_screen != null:
		if is_instance_valid(battle_screen.landscape_view):
			battle_screen.landscape_view.handle_back()
	if what == NOTIFICATION_RESIZED:
		_on_window_size_changed()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.device != -1 and not touch_input_active:
		touch_input_active = true
		call_deferred("_on_window_size_changed")
	if not (touch_input_active or _layout_viewport_size().x <= 900):
		return
	if touch_scroll_router.handle(event, self):
		get_viewport().set_input_as_handled()

func _on_window_size_changed() -> void:
	_apply_root_layout()
	_schedule_layout_rebuild()

func _layout_signature(viewport_size: Vector2) -> String:
	return "%s|%s|%s|%s|%s|%s|%s" % [
		"phone" if LayoutPolicy.is_mobile_landscape(viewport_size) else "desktop",
		"compact860" if viewport_size.x < 860.0 else "wide860",
		"compact1080" if viewport_size.x < 1080.0 else "wide1080",
		"compact1400" if viewport_size.x < 1400.0 else "wide1400",
		"desktop" if viewport_size.x < 1600.0 else "wide_desktop",
		"short" if viewport_size.y <= 760.0 else "tall",
		_ui_scale_mode(),
	]

func _schedule_layout_rebuild() -> void:
	if layout_resize_timer == null or not is_instance_valid(layout_resize_timer):
		return
	pending_layout_signature = _layout_signature(_layout_viewport_size())
	if pending_layout_signature == last_layout_signature:
		return
	layout_resize_timer.start()

func _on_layout_resize_timeout() -> void:
	var next_signature := _layout_signature(_layout_viewport_size())
	if next_signature == last_layout_signature:
		return
	if active_screen == "battle" and battle_screen != null and bool(battle_screen.input_locked):
		pending_layout_signature = next_signature
		layout_resize_timer.start()
		return
	last_layout_signature = next_signature
	pending_layout_signature = next_signature
	_rebuild_active_screen_for_layout()

func _rebuild_active_screen_for_layout() -> void:
	var scroll_ratio := 0.0
	if root_scroll != null and is_instance_valid(root_scroll):
		var scroll_bar := root_scroll.get_v_scroll_bar()
		var scroll_range := maxf(1.0, scroll_bar.max_value - scroll_bar.page)
		scroll_ratio = clampf(float(root_scroll.scroll_vertical) / scroll_range, 0.0, 1.0)
	match active_screen:
		"main_menu":
			_show_main_menu()
		"race_selection":
			_show_race_selection()
		"map":
			_show_map()
		"battle":
			if battle_screen != null:
				battle_screen.rebuild_layout()
		"reward":
			_show_card_reward()
		"event":
			_show_event()
		"shop":
			_show_shop()
		"rest":
			_show_rest()
		"remove_card":
			var pending_remove: Dictionary = current_run.get("pending_subscreen", {})
			_show_remove_card_screen(String(pending_remove.get("reason", "카드 정리")))
		"upgrade_card":
			_show_upgrade_card_screen()
		"run_result":
			_show_run_result(String(current_run.get("result", "")) == "win", false)
		"collection":
			_show_collection()
		"compendium":
			_show_compendium()
		"meta_upgrade":
			_show_meta_upgrade()
		"settings":
			_show_settings()
		"ui_guide":
			_show_ui_guide()
		"message":
			if not active_message_text.is_empty() and not active_message_callback.is_empty():
				_show_message(active_message_text, active_message_callback)
	_restore_scroll_after_layout(scroll_ratio)

func _restore_scroll_after_layout(scroll_ratio: float) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if root_scroll == null or not is_instance_valid(root_scroll):
		return
	var scroll_bar := root_scroll.get_v_scroll_bar()
	var scroll_range := maxf(0.0, scroll_bar.max_value - scroll_bar.page)
	root_scroll.scroll_vertical = int(round(scroll_range * scroll_ratio))

func _apply_root_layout() -> void:
	if root_box == null:
		return
	_configure_content_scale()
	var viewport_size := _layout_viewport_size()
	var safe_rect := _safe_layout_rect()
	var canvas_size := _layout_size_for_physical_size(_physical_viewport_size())
	var trailing_inset := canvas_size - safe_rect.end
	if modal_layer != null:
		modal_layer.offset_left = safe_rect.position.x
		modal_layer.offset_top = safe_rect.position.y
		modal_layer.offset_right = -trailing_inset.x
		modal_layer.offset_bottom = -trailing_inset.y
	if root_scroll != null:
		var outer_margin := 4.0 if viewport_size.x <= 600.0 else 8.0
		root_scroll.offset_left = safe_rect.position.x + outer_margin
		root_scroll.offset_top = safe_rect.position.y + outer_margin
		root_scroll.offset_right = -trailing_inset.x - outer_margin
		root_scroll.offset_bottom = -trailing_inset.y - outer_margin - mobile_bottom_inset
		if root_center != null:
			root_center.custom_minimum_size = Vector2(maxf(300.0, viewport_size.x - outer_margin * 2.0), 0.0)
	ui.apply_root_layout(root_box, viewport_size)


func _clear_screen() -> void:
	if battle_screen != null and battle_screen.presentation != null:
		battle_screen.presentation.dispose()
	mobile_bottom_inset = 0.0
	_apply_root_layout()
	if audio_manager != null:
		audio_manager.set_screen_music(active_screen)
	var world := get_node_or_null("WorldBackground") as TextureRect
	if world != null:
		var backdrop := "merchant_hall_v1" if active_screen == "shop" else ("campaign_valley_v1" if active_screen == "map" else "siege_castle_v1")
		world.texture = load("res://assets/backgrounds/%s.png" % backdrop)
	active_screen_controller = null
	if root_scroll != null:
		root_scroll.scroll_horizontal = 0
		root_scroll.scroll_vertical = 0
	for child in root_box.get_children():
		# A button may be dispatching the event that switches screens.
		if child is CanvasItem: child.hide()
		child.queue_free()

	_clear_modal()

func _clear_modal() -> void:
	for child in modal_layer.get_children():
		if child is CanvasItem: child.hide()
		child.queue_free()

func _save_profile() -> void:
	if is_instance_valid(audio_manager):
		audio_manager.apply_settings(player_profile.get("settings", {}))
	profile_store.save(GameStorage.profile_path(), player_profile)

func _save_run() -> void:
	if current_run.is_empty():
		run_store.clear(GameStorage.run_path())
	else:
		run_store.save(GameStorage.run_path(), current_run)

func _clear_run() -> void:
	current_run = {}
	run_store.clear(GameStorage.run_path())

func _show_error_screen(message: String) -> void:
	_clear_screen()
	var body: VBoxContainer = ui.begin_screen(root_box, "CARD DRAFT")
	body.add_child(_make_label(message, 20, Color(1.0, 0.65, 0.65, 1.0)))

func _retain_screen_controller(controller: RefCounted) -> RefCounted:
	active_screen_controller = controller
	return controller

func _show_main_menu() -> void:
	if active_screen == "battle" and battle_screen != null:
		await battle_screen.prepare_to_leave()
	active_screen = "main_menu"
	_clear_screen()
	if LayoutPolicy.is_mobile_landscape(_layout_viewport_size()):
		_build_phone_home()
		return
	if _layout_viewport_size().x >= 1100:
		preload("res://src/ui/screens/cinematic_menu.gd").new(self).build(root_box)
		return
	root_box.add_theme_constant_override("separation", 12)
	_build_phone_home()

func _build_phone_home() -> void:
	var surface: PanelContainer = ui.make_surface_panel(Color(0.025, 0.035, 0.05, 0.94), Color(0.42, 0.34, 0.19), 1, 8, 12)
	root_box.add_child(surface)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	surface.add_child(content)
	var title := _make_label("Card Draft · " + _home_status_text(), 22, Color(0.98, 0.94, 0.84))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	content.add_child(row)
	var actions := VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 10)
	row.add_child(actions)
	var primary := _make_home_action_button("이어하기" if not current_run.is_empty() else "새 런 시작", "진행 중인 전투와 경로로" if not current_run.is_empty() else "세력과 플레이 방식 선택", "_continue_run" if not current_run.is_empty() else "_start_new_run", Color(0.17, 0.31, 0.56), true)
	actions.add_child(primary)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	actions.add_child(grid)
	for entry in [["카드", "보유 카드", "_show_collection"], ["강화", "영구 보너스", "_show_meta_upgrade"], ["도감", "카드 / 유물", "_show_compendium"], ["설정", "소리 / 화면", "_show_settings"]]:
		grid.add_child(_make_home_action_button(entry[0], entry[1], entry[2], Color(0.12, 0.15, 0.2), false))
	var art := _make_card_art_rect(cards_by_id.get("flame_swordsman", {}), Vector2(180, 210))
	row.add_child(art)
	var stats := _make_label("카드 %d · 골드 %s · 영혼석 %s · 기록 %d" % [card_defs.size(), _format_large_number(int(player_profile.get("gold", 0))), _format_large_number(int(player_profile.get("soul_stones", 0))), _recent_runs().size()], 14, Color(0.82, 0.87, 0.94))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(stats)

func _home_status_text() -> String:
	if current_run.is_empty():
		return "대기 중"
	return "Act %d 진행 중" % int(current_run.get("act", 1))

func _home_headline_text() -> String:
	if current_run.is_empty():
		return "오늘의 덱을 시작하세요"
	return "%s 이어서 플레이" % String(_current_act().get("name", "현재 런"))

func _make_home_action_button(title: String, detail: String, callback_method: String, color: Color, primary: bool) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [title, detail]
	button.custom_minimum_size = Vector2(0, 78 if primary else 58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	if primary:
		ui.style_primary_button(button, color)
	else:
		ui.style_flat_button(button, color, color.lightened(0.35), 14, 1)
	button.pressed.connect(Callable(self, callback_method))
	return button

func _make_home_route_panel(compact: bool) -> Control:
	var panel: PanelContainer = ui.make_surface_panel(Color(0.045, 0.052, 0.062, 1.0), Color(0.18, 0.22, 0.28, 1.0), 1, 8, 12)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := _make_label("진행 흐름", 16 if compact else 18, Color(0.98, 0.94, 0.82, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	var route := GridContainer.new()
	route.columns = 4
	route.mouse_filter = Control.MOUSE_FILTER_PASS
	route.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	route.add_theme_constant_override("h_separation", 8)
	route.add_theme_constant_override("v_separation", 8)
	box.add_child(route)
	var node_types: Array = ["battle", "event", "shop", "boss"]
	for node_type in node_types:
		route.add_child(ui.make_chip(_node_type_name(String(node_type)), Color(0.1, 0.12, 0.15, 1.0), Color(0.9, 0.94, 1.0, 1.0), 12 if compact else 13))
	return panel

func _lesson_stage() -> int:
	return Onboarding.stage(current_run)

func _lesson_description() -> String:
	return Onboarding.description(current_run)

func _start_new_run() -> void:
	pending_guided_run = int(player_profile.get("learning_stage", 0)) < 5
	pending_race_selection_id = "human"
	pending_strategy_id = ""
	run_flow.start_new_run()

func _init_run(race_id: String, strategy_id: String = "") -> void:
	run_flow.init_run(race_id, strategy_id)

func _show_race_selection() -> void:
	active_screen = "race_selection"
	_clear_screen()
	var body: VBoxContainer
	var viewport := _layout_viewport_size()
	if ui.mobile_layout and viewport.x > viewport.y:
		# The full two-line heading consumes too much of a phone's short viewport.
		var header := HBoxContainer.new()
		header.name = "RaceSelectionHeader"
		root_box.add_child(header)
		var title := _make_label("세력 선택", 21, Color.WHITE)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title)
		body = VBoxContainer.new()
		body.add_theme_constant_override("separation", 8)
		root_box.add_child(body)
	else:
		body = _begin_menu_screen("세력 선택", false, "짧은 런의 시작 덱과 전투 필살기를 정합니다.")
	_retain_screen_controller(RaceSelectionScreenScript.new(self)).build(body)

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

func _race_meta() -> Dictionary:
	return {
		"human": {
			"name": "인간",
			"start_text": "인간으로 시작",
			"data_race": "인간",
			"hero_name": "왕국 지휘관",
			"style": "안정적인 전열",
			"builds": "소환 · 버프",
			"description": "병사를 빠르게 전개하고 전열 전체를 성장시키는 가장 직관적인 세력입니다.",
			"color": Color(0.78, 0.58, 0.24, 1.0),
			"relic_id": "knight_banner",
			"representative_card_id": "militia",
			"representative_card_names": ["민병대", "초보 검병", "화염구"],
			"power_name": "왕국의 집결",
			"power_text": "근위대를 소환하고 모든 아군 공격력을 1 올립니다.",
			"power_short": "근위대 · 전열 공격 +1",
			"power_sfx": "power_human",
		},
		"elf": {
			"name": "엘프",
			"start_text": "엘프로 시작",
			"data_race": "엘프",
			"hero_name": "숲의 인도자",
			"style": "빠른 연속 전개",
			"builds": "드로우 · 소환",
			"description": "손패와 마나를 순환시켜 한 턴에 여러 카드를 이어 쓰는 세력입니다.",
			"color": Color(0.22, 0.68, 0.54, 1.0),
			"relic_id": "world_tree_leaf",
			"representative_card_id": "forest_archer",
			"representative_card_names": ["숲의 궁수", "엘프의 통찰", "의식의 묘목"],
			"power_name": "바람의 순환",
			"power_text": "카드 2장을 뽑고 이번 턴에 사용할 마나를 2 얻습니다.",
			"power_short": "드로우 2 · 마나 +2",
			"power_sfx": "power_elf",
		},
		"undead": {
			"name": "언데드",
			"start_text": "언데드로 시작",
			"data_race": "언데드",
			"hero_name": "묘지의 군주",
			"style": "희생과 압박",
			"builds": "사망 · 소환",
			"description": "약한 아군의 죽음을 영웅 피해와 새로운 해골 전열로 바꾸는 세력입니다.",
			"color": Color(0.62, 0.38, 0.82, 1.0),
			"relic_id": "necromancer_ring",
			"representative_card_id": "bone_soldier",
			"representative_card_names": ["해골 병사", "어둠의 거래", "망자의 부름"],
			"power_name": "죽음의 계약",
			"power_text": "가장 약한 아군을 희생해 적 영웅에게 피해 3을 주고 해골을 소환합니다.",
			"power_short": "아군 희생 · 영웅 피해 3",
			"power_sfx": "power_undead",
		},
	}

func _valid_race_ids() -> Array[String]:
	return ["human", "elf", "undead"]

func _normalize_race_id(race_id: String) -> String:
	return race_id if _valid_race_ids().has(race_id) else "human"

func _current_race_id() -> String:
	return _normalize_race_id(String(current_run.get("race_id", "human")))

func _current_race_meta() -> Dictionary:
	return _race_meta().get(_current_race_id(), _race_meta()["human"])

func _current_race_name() -> String:
	return String(_current_race_meta().get("name", "인간"))

func _current_race_hero_name() -> String:
	return String(_current_race_meta().get("hero_name", "왕국 지휘관"))

func _card_matches_current_race(card: Dictionary) -> bool:
	return String(card.get("race", "")) == String(_current_race_meta().get("data_race", "인간"))

func _hero_build_name() -> String:
	var primary := _primary_build_tag(_current_build_scores())
	if primary.is_empty():
		return "%s · 탐색 빌드" % _current_race_name()
	var meta: Dictionary = _build_tag_meta().get(primary, {})
	return "%s · %s 빌드" % [_current_race_name(), String(meta.get("name", "탐색"))]

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
			"두 막, 총 10개 지점. 갈림길에서 다음 장소를 고릅니다.",
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

func _menu_nav_button(parent: Node, title: String, subtitle: String, callback_method: String, color: Color, icon_text: String = "-", compact: bool = false) -> Button:
	var button: Button = ui.make_large_action_button(title, subtitle, icon_text, color, compact)
	if compact:
		button.custom_minimum_size = Vector2(300, 62)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		button.custom_minimum_size = Vector2(0, 78 if compact else 86)
	button.pressed.connect(Callable(self, callback_method))
	parent.add_child(button)
	return button

func _small_hub_button(parent: Node, title: String, callback_method: String, icon_text: String) -> void:
	var button := Button.new()
	button.text = icon_text
	button.tooltip_text = title
	button.custom_minimum_size = Vector2(42, 42)
	ui.style_button(button, Color(0.1, 0.12, 0.16, 1.0))
	ui.ButtonMetrics.apply(button, "icon")
	button.pressed.connect(Callable(self, callback_method))
	parent.add_child(button)

func _small_hub_button_config(parent: Node, title: String, callback_method: String, icon_text: String, width: int = 58, height: int = 62, font_size: int = 13) -> Button:
	var button := Button.new()
	button.text = title if ui.mobile_layout else "%s\n%s" % [icon_text, title]
	button.custom_minimum_size = Vector2(width, height)
	ui.style_flat_button(button, Color(0.08, 0.11, 0.16, 1.0), Color(0.44, 0.6, 0.82, 1.0), font_size, 2)
	ui.ButtonMetrics.apply(button, "action" if button.text.contains("\n") else "compact", width)
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
	chip.custom_minimum_size = Vector2(0, 34)
	return chip

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
			if node_data_variant is Array:
				node_data_variant = {"type": node_data_variant[0]}
			elif node_data_variant is String:
				node_data_variant = {"type": node_data_variant}
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
	var node_row := HFlowContainer.new()
	node_row.add_theme_constant_override("separation", 8)
	box.add_child(node_row)
	var node_types: Array = _current_act().get("nodes", []) if not current_run.is_empty() else ["battle", ["event", "shop"], ["battle", "elite"], ["rest", "shop"], "boss"]
	var current_index := int(current_run.get("current_node_index", 0)) if not current_run.is_empty() else -1
	for i in range(node_types.size()):
		var layer: Variant = node_types[i]
		var node_name := _node_type_name(String(layer[0])) + " / " + _node_type_name(String(layer[1])) if layer is Array and layer.size() > 1 else _node_type_name(String(layer[0] if layer is Array else layer))
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

func _show_run_result(is_win: bool, play_audio: bool = true) -> void:
	active_screen = "run_result"
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("런 결과", false, "이번 모험이 종료되었습니다. 최종 달성 기록과 통계를 확인하세요.")
	_retain_screen_controller(RunResultScreenScript.new(self)).build(body, is_win, play_audio)

func _finish_run(is_win: bool) -> void:
	if current_run.is_empty():
		return
	var run_id := String(current_run.get("run_id", ""))
	if run_id.is_empty():
		# Stable across reloads, including a crash between profile and run saves.
		run_id = "legacy-" + JSON.stringify([current_run.get("seed", 0), current_run.get("started_at", 0), current_run.get("race_id", "human")]).sha256_text()
		current_run["run_id"] = run_id
	var ledger: Dictionary = player_profile.get("settled_run_ids", {})
	var already_settled := ledger.has(run_id)
	var legacy_settled := not already_settled and current_run.has("earned_soul_stones") and float(current_run.get("finished_at", 0)) > 0.0
	current_run["result"] = "win" if is_win else "loss"
	if float(current_run.get("finished_at", 0)) <= 0.0:
		current_run["finished_at"] = Time.get_unix_time_from_system()
	var earned_soul_stones := int(ledger.get(run_id, current_run.get("earned_soul_stones", _run_soul_stones(is_win))))
	current_run["earned_soul_stones"] = earned_soul_stones
	if not already_settled:
		ledger[run_id] = earned_soul_stones
		player_profile["settled_run_ids"] = ledger
		if not legacy_settled:
			player_profile["soul_stones"] = int(player_profile.get("soul_stones", 0)) + earned_soul_stones
			_record_recent_run(is_win)
		# Balance, history and ledger are committed in the same profile write.
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
	player_profile["settings"]["reduced_battle_fx"] = false
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

func _on_ui_scale_mode_selected(mode: String) -> void:
	var normalized_mode := mode if ["auto", "large", "small"].has(mode) else "auto"
	if _ui_scale_mode() == normalized_mode:
		return
	player_profile["settings"]["ui_scale_mode"] = normalized_mode
	_save_profile()
	_apply_root_layout()
	last_layout_signature = _layout_signature(_layout_viewport_size())
	pending_layout_signature = last_layout_signature
	call_deferred("_rebuild_active_screen_for_layout")

func _request_profile_reset() -> void:
	if active_screen == "settings" and active_screen_controller != null:
		active_screen_controller.request_reset()

func _reset_profile() -> void:
	player_profile = profile_store.make_default_profile(card_defs)
	player_profile = profile_store.apply_local_debug_defaults(player_profile, card_defs)
	_save_profile()
	_apply_window_mode()
	_show_message("로컬 프로필을 초기화했습니다.", "_show_main_menu")

func _show_message(message: String, callback_method: String, target: Object = null) -> void:
	active_screen = "message"
	active_message_text = message
	active_message_callback = callback_method
	_clear_screen()
	var body: VBoxContainer = _begin_menu_screen("알림", false, "게임 진행에 필요한 안내 메시지입니다.")
	_retain_screen_controller(MessageScreenScript.new(self)).build(body, message, callback_method, target)

func _make_run_summary_panel() -> Control:
	if _lesson_stage() < 5:
		return ui.make_guidance_banner("내 상태", "체력 %d/%d · 골드 %d · 덱 %d장" % [int(current_run.get("hp", 0)), int(current_run.get("max_hp", 0)), int(current_run.get("gold", 0)), current_run.get("deck_ids", []).size()], Color(0.12, 0.2, 0.3, 1.0), true)
	var compact := _is_compact_layout()
	var viewport_size := _layout_viewport_size()
	var phone := _is_mobile_phone_layout()
	var short_landscape := viewport_size.y <= 760.0 and viewport_size.x > viewport_size.y
	var panel: PanelContainer = ui.make_surface_panel(Color(0.055, 0.065, 0.075, 0.98), Color(0.25, 0.21, 0.12, 1.0), 1, 8 if phone else 10, 6 if phone or short_landscape else 10)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 4 if phone or short_landscape else 6)
	panel.add_child(wrapper)
	var row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(row)
	var act_label: Label = _make_label("Act %d · %s" % [int(current_run.get("act", 1)), String(_current_act().get("name", "런"))], 13 if phone else (14 if compact else 15), Color(1.0, 0.88, 0.55, 1.0))
	act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	act_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(act_label)
	var resource_row: BoxContainer
	if compact:
		resource_row = HBoxContainer.new()
		resource_row.add_theme_constant_override("separation", 6)
		resource_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(resource_row)
	else:
		resource_row = row
	var chip_font_size := 12 if phone else (13 if compact else 14)
	var hp_chip: PanelContainer = ui.make_chip("HP %d/%d" % [int(current_run.get("hp", 0)), int(current_run.get("max_hp", 0))], Color(0.34, 0.12, 0.12, 1.0), Color(1.0, 0.82, 0.82, 1.0), chip_font_size)
	var gold_chip: PanelContainer = ui.make_chip("골드 %s" % _format_large_number(int(current_run.get("gold", 0))), Color(0.38, 0.28, 0.1, 1.0), Color(1.0, 0.9, 0.56, 1.0), chip_font_size)
	var deck_chip: PanelContainer = ui.make_chip("덱 %d" % (current_run.get("deck_ids", []) as Array).size(), Color(0.12, 0.22, 0.34, 1.0), Color(0.86, 0.92, 1.0, 1.0), chip_font_size)
	var race_meta: Dictionary = _current_race_meta()
	var race_color: Color = race_meta.get("color", Color(0.42, 0.68, 1.0, 1.0))
	var race_chip: PanelContainer = ui.make_chip(String(race_meta.get("name", "인간")), race_color.darkened(0.58), race_color.lightened(0.28), chip_font_size)
	for chip in [hp_chip, gold_chip, deck_chip, race_chip]:
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
		resource_row.add_child(chip)
	var relics: Array = current_run.get("relic_ids", [])
	if short_landscape:
		for relic_id in relics:
			var relic_def: Dictionary = relic_service.get_relic(String(relic_id))
			row.add_child(ui.make_relic_badge(relic_def, true))
	var scores := _current_build_scores()
	var build_summary := "빌드 탐색 중"
	if phone:
		var primary_tag := _primary_build_tag(scores)
		if not primary_tag.is_empty():
			var primary_meta: Dictionary = _build_tag_meta().get(primary_tag, {})
			var active_suffix := " · 활성" if int(scores.get(primary_tag, 0)) >= _build_threshold() else ""
			build_summary = "%s %s %d%s" % [String(primary_meta.get("icon", "")), String(primary_meta.get("name", "")), int(scores.get(primary_tag, 0)), active_suffix]
	else:
		var build_line := _build_status_text(scores).replace("현재 빌드  ", "")
		var active_line := _active_build_text(scores)
		build_summary = "%s  |  %s" % [build_line, active_line]
	var build_label: Label = _make_label(build_summary, 12 if compact else 13, Color(0.86, 0.9, 0.96, 1.0))
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	build_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	build_label.clip_text = phone
	wrapper.add_child(build_label)
	if not relics.is_empty() and not short_landscape and not phone:
		var relic_row := HFlowContainer.new()
		relic_row.add_theme_constant_override("h_separation", 6)
		relic_row.add_theme_constant_override("v_separation", 6)
		var relic_title := _make_label("보유 유물", 12 if compact else 13, Color(0.8, 0.8, 0.8, 1.0))
		relic_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		relic_title.custom_minimum_size = Vector2(66 if compact else 76, 38 if compact else 44)
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
		"fire": {"icon": "화염", "name": "화염", "color": Color(0.84, 0.34, 0.16, 1.0), "bonus": "화염 피해 +2 / 연계 시 폭발 피해"},
		"draw": {"icon": "드로우", "name": "드로우", "color": Color(0.24, 0.46, 0.82, 1.0), "bonus": "추가 드로우 / 연계 시 마나 회복"},
		"death": {"icon": "사망", "name": "사망", "color": Color(0.48, 0.28, 0.58, 1.0), "bonus": "아군 사망 시 적 영웅 피해"},
		"buff": {"icon": "버프", "name": "버프", "color": Color(0.7, 0.58, 0.18, 1.0), "bonus": "소환 유닛 체력 +1 / 연계 시 선봉 성장"},
		"low_hp": {"icon": "위험", "name": "저체력", "color": Color(0.76, 0.22, 0.28, 1.0), "bonus": "위험 체력에서 공격 피해 +1 / 연계 회복"},
		"summon": {"icon": "소환", "name": "소환", "color": Color(0.22, 0.58, 0.32, 1.0), "bonus": "전투 시작 토큰 / 연계 시 즉시 공격"},
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
	if card.has("effects"): return String(card.get("text", ""))
	if int(card.get("effect_bonus", 0)) > 0 and not String(card.get("text", "")).is_empty():
		return String(card["text"])
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
			"ember_blade":
				return "앞 아군 공격 +1 · 공격 후 영웅 피해 1"
			"wind_quiver":
				return "앞 아군 공격 +1 · 공격 후 1드로우"
			"bone_armor":
				return "앞 아군 체력 +3 · 사망 시 영웅 피해 2"
			"royal_standard":
				return "모든 아군 +1/+1"
			"blood_blade":
				return "앞 아군 공격 +2 · 공격 후 회복 1"
			"war_horn":
				return "앞 아군 공격 +1 · 즉시 공격 1/1 소환"
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
			return "화염 2연계부터 폭발 피해가 터집니다."
		"draw":
			return "드로우 2연계부터 손패가 다시 차오릅니다."
		"death":
			return "희생과 사망이 적 영웅 피해로 바뀝니다."
		"buff":
			return "선봉을 키워 교환과 보스 압박을 이깁니다."
		"low_hp":
			return "위험 체력에서 피해와 회복이 같이 켜집니다."
		"summon":
			return "소환 2연계부터 방금 낸 유닛이 바로 공격합니다."
		_:
			return "이번 덱 방향을 더 선명하게 만듭니다."

func _build_playstyle_text(tag: String) -> String:
	match tag:
		"fire":
			return "화염 폭발 빨라짐"
		"draw":
			return "연속 플레이 강화"
		"death":
			return "희생 덱 핵심"
		"buff":
			return "필드 성장"
		"low_hp":
			return "위험 반격"
		"summon":
			return "물량 전개"
		_:
			return "전투 방향 선명"

func _build_progress_text_for_tags(tags: Array[String]) -> String:
	if tags.is_empty():
		return "전투 보조"
	var scores := _current_build_scores()
	var meta := _build_tag_meta()
	var best_tag := String(tags[0])
	var best_after := -1
	for tag in tags:
		var after_score := int(scores.get(tag, 0)) + 1
		if after_score > best_after:
			best_after = after_score
			best_tag = tag
	var current := int(scores.get(best_tag, 0))
	var next := current + 1
	var tag_meta: Dictionary = meta.get(best_tag, {})
	if current < _build_threshold() and next >= _build_threshold():
		return "%s 활성" % String(tag_meta.get("name", best_tag))
	return "%s %d/%d" % [String(tag_meta.get("name", best_tag)), mini(next, _build_threshold()), _build_threshold()]

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

func _choice_playstyle_text(source: Dictionary) -> String:
	var tags := _build_tags_from_data(source)
	if tags.is_empty() and source.has("id"):
		if source.has("cost"):
			tags = _card_build_tags(source)
		else:
			tags = _relic_build_tags(source)
	if tags.is_empty():
		return "즉시 전투 도움"
	var primary := String(tags[0])
	return "%s · %s" % [_build_playstyle_text(primary), _build_progress_text_for_tags(tags)]

func _build_activation_effect_text(tag: String) -> String:
	match tag:
		"fire":
			return "활성 후: 화염 피해 +2, 2번째 화염 더 강함"
		"draw":
			return "활성 후: 턴 시작 추가 드로우, 첫 카드 마나 보강"
		"death":
			return "활성 후: 아군 사망이 적 영웅 피해"
		"buff":
			return "활성 후: 소환 유닛 체력 +1, 선봉 성장"
		"low_hp":
			return "활성 후: 위험 체력에서 공격 피해 +1"
		"summon":
			return "활성 후: 시작 토큰, 즉시 공격 소환 연계"
		_:
			return "활성 후: 전투 리듬이 더 선명해집니다."

func _choice_impact_text(source: Dictionary) -> String:
	var tags := _build_tags_from_data(source)
	if tags.is_empty() and source.has("id"):
		if source.has("cost"):
			tags = _card_build_tags(source)
		else:
			tags = _relic_build_tags(source)
	if tags.is_empty():
		return "즉시 전투 안정"
	var scores := _current_build_scores()
	var best_tag := String(tags[0])
	var best_after := -1
	for tag in tags:
		var after_score := int(scores.get(tag, 0)) + (2 if not source.has("cost") else 1)
		if after_score > best_after:
			best_after = after_score
			best_tag = String(tag)
	var current := int(scores.get(best_tag, 0))
	var gain := 2 if not source.has("cost") else 1
	var next_score := current + gain
	var meta: Dictionary = _build_tag_meta().get(best_tag, {})
	if current < _build_threshold() and next_score >= _build_threshold():
		return "%s %s 바로 활성" % [String(meta.get("icon", "")), String(meta.get("name", best_tag))]
	if next_score >= _build_threshold():
		return "%s 연계 카드 확보" % String(meta.get("name", best_tag))
	return "%s 활성까지 %d" % [String(meta.get("name", best_tag)), max(0, _build_threshold() - next_score)]

func _run_soul_stones(is_win: bool) -> int:
	var stones := 100 if is_win else 0
	var counted := {}
	var cleared_types: Dictionary = current_run.get("cleared_node_types", {})
	var acts: Array = current_run.get("map_nodes", [])
	for key_variant in current_run.get("visited_nodes", []):
		var key := String(key_variant)
		if counted.has(key):
			continue
		counted[key] = true
		var node_type := String(cleared_types.get(key, ""))
		if node_type.is_empty():
			# Legacy runs did not record the selected path; retain the saved map.
			var parts := key.split(":")
			if parts.size() != 2:
				continue
			var act_index := int(parts[0]) - 1
			var node_index := int(parts[1])
			if act_index < 0 or act_index >= acts.size():
				continue
			var nodes: Array = Dictionary(acts[act_index]).get("nodes", [])
			if node_index < 0 or node_index >= nodes.size():
				continue
			var node_value: Variant = nodes[node_index]
			if typeof(node_value) == TYPE_ARRAY:
				if not (node_value as Array).is_empty():
					node_type = String(node_value[0])
			else:
				node_type = String(node_value)
		match node_type:
			"battle": stones += 5
			"elite": stones += 15
			"boss": stones += 30
	return stones

func _roll_card_choices(count: int) -> Array[String]:
	var ids: Array[String] = []
	var pool: Array[String] = _reward_card_pool()
	while ids.size() < count and not pool.is_empty():
		var index := randi() % pool.size()
		ids.append(pool[index])
		pool.remove_at(index)
	return ids

func _secondary_build_tag(scores: Dictionary) -> String:
	var primary := _primary_build_tag(scores)
	var best_tag := ""
	var best_score := 0
	# Prefer a build that this reward can bring closer to activation.
	for tag in _valid_build_tags():
		var score := int(scores.get(tag, 0))
		if tag != primary and score > best_score and score < _build_threshold():
			best_tag = tag
			best_score = score
	if not best_tag.is_empty():
		return best_tag
	for tag in _valid_build_tags():
		var score := int(scores.get(tag, 0))
		if tag != primary and score > best_score:
			best_tag = tag
			best_score = score
	return best_tag

func _roll_card_reward_choices(count: int, high_cost_only: bool = false) -> Array[String]:
	var ids: Array[String] = []
	var scores := _current_build_scores()
	var primary_tag := _primary_build_tag(scores)
	var secondary_tag := _secondary_build_tag(scores)
	var race_name := String(_current_race_meta().get("data_race", "인간"))
	var full_pool := _reward_card_pool("", high_cost_only)
	if count > 0:
		var focused_pool := _reward_card_pool(primary_tag, high_cost_only, race_name)
		if focused_pool.is_empty():
			focused_pool = _reward_card_pool(primary_tag, high_cost_only)
		if focused_pool.is_empty():
			focused_pool = full_pool
		_append_random_reward_choice(ids, focused_pool)
	if ids.size() < count:
		var support_pool: Array[String] = []
		if not secondary_tag.is_empty():
			support_pool = _reward_card_pool(secondary_tag, high_cost_only)
		if support_pool.is_empty():
			support_pool = _reward_card_pool("", high_cost_only, "중립")
		_append_random_reward_choice(ids, support_pool)
	if ids.size() < count:
		var pivot_pool: Array[String] = []
		for card_id in full_pool:
			var tags := _card_build_tags(card_db.get_card(card_id))
			if not tags.has(primary_tag) and (secondary_tag.is_empty() or not tags.has(secondary_tag)):
				pivot_pool.append(card_id)
		_append_random_reward_choice(ids, pivot_pool)
	while ids.size() < count:
		var before_size := ids.size()
		_append_random_reward_choice(ids, full_pool)
		if ids.size() == before_size:
			break
	return ids

func _roll_boss_card_reward_choices(boss_id: String, count: int = 3) -> Array[String]:
	var ids: Array[String] = []
	if count > 0 and not card_db.get_card(boss_id).is_empty():
		ids.append(boss_id)
	for card_id in _roll_card_reward_choices(count):
		if ids.size() >= count:
			break
		if not ids.has(card_id):
			ids.append(card_id)
	var pool := _reward_card_pool()
	while ids.size() < count:
		var before_size := ids.size()
		_append_random_reward_choice(ids, pool)
		if before_size == ids.size():
			break
	return ids

func _roll_relic_reward_choices(count: int = 2) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	var pool: Array[Dictionary] = []
	var matching: Array[Dictionary] = []
	var owned: Array = current_run.get("relic_ids", [])
	var active := _active_build_tags(_current_build_scores())
	for raw_relic in relic_service.relics:
		var relic: Dictionary = raw_relic
		if owned.has(String(relic.get("id", ""))):
			continue
		pool.append(relic)
		for tag in _relic_build_tags(relic):
			if active.has(tag):
				matching.append(relic)
				break
	if count > 0 and not matching.is_empty():
		var first: Dictionary = matching[randi() % matching.size()]
		choices.append(first.duplicate(true))
		pool.erase(first)
	while choices.size() < count and not pool.is_empty():
		var index := randi() % pool.size()
		choices.append(pool[index].duplicate(true))
		pool.remove_at(index)
	return choices

func _append_random_reward_choice(ids: Array[String], source_pool: Array[String]) -> void:
	var pool := source_pool.duplicate()
	for picked_id in ids:
		pool.erase(picked_id)
	if pool.is_empty():
		return
	ids.append(String(pool[randi() % pool.size()]))

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

func _reward_card_pool(tag_filter: String = "", high_cost_only: bool = false, race_filter: String = "") -> Array[String]:
	var pool: Array[String] = []
	for card in card_defs:
		var card_id := String(card.get("id", ""))
		if bool(card.get("starter", false)) or card_id.ends_with("_plus"):
			continue
		if high_cost_only and int(card.get("cost", 0)) < 3:
			continue
		if not tag_filter.is_empty() and not _card_build_tags(card).has(tag_filter):
			continue
		if not race_filter.is_empty() and String(card.get("race", "")) != race_filter:
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
	if node_type == "lesson_reward":
		return "장비 배우기"
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
	return _layout_viewport_size().x < 1150.0

func _is_mobile_phone_layout() -> bool:
	var viewport_size: Vector2 = _layout_viewport_size()
	return LayoutPolicy.is_mobile_landscape(viewport_size)

func _is_compact_layout_for(width_breakpoint: float = 860.0, height_breakpoint: float = 0.0) -> bool:
	return LayoutPolicy.is_compact(_layout_viewport_size(), width_breakpoint, height_breakpoint)

func _physical_viewport_size() -> Vector2:
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
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x > 0 and window_size.y > 0:
		return Vector2(window_size.x, window_size.y)
	if not is_inside_tree():
		return BASE_VIEWPORT_SIZE
	if get_window().size.x > 0 and get_window().size.y > 0:
		return Vector2(get_window().size)
	var viewport_size := get_viewport_rect().size
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		return viewport_size
	return BASE_VIEWPORT_SIZE

func _native_canvas_scale_for_physical_size(physical_size: Vector2) -> float:
	return LayoutPolicy.native_scale(physical_size, BASE_VIEWPORT_SIZE)

func _content_scale_factor_for_physical_size(physical_size: Vector2) -> float:
	var native_scale := _native_canvas_scale_for_physical_size(physical_size)
	if native_scale <= 0.0:
		return 1.0
	return _render_scale_for_physical_size(physical_size) / native_scale

func _ui_scale_mode() -> String:
	var mode := String(player_profile.get("settings", {}).get("ui_scale_mode", "auto"))
	return mode if ["auto", "large", "small"].has(mode) else "auto"

func _ui_scale_multiplier() -> float:
	match _ui_scale_mode():
		"large":
			return 1.1
		"small":
			return 0.9
	return 1.0

func _render_scale_for_physical_size(physical_size: Vector2) -> float:
	return LayoutPolicy.render_scale(physical_size, BASE_VIEWPORT_SIZE, touch_input_active, _ui_scale_multiplier(), MAX_AUTO_UI_SCALE)

func _layout_size_for_physical_size(physical_size: Vector2) -> Vector2:
	return LayoutPolicy.landscape_size(physical_size) / _render_scale_for_physical_size(physical_size)

func _layout_viewport_size() -> Vector2:
	return _safe_layout_rect().size

func _safe_layout_rect() -> Rect2:
	var physical_size := _physical_viewport_size()
	var physical_rect := Rect2(Vector2.ZERO, physical_size)
	var safe_rect := physical_rect
	if has_meta("display_safe_area_override"):
		safe_rect = get_meta("display_safe_area_override")
	elif OS.has_feature("ios") or OS.has_feature("android"):
		safe_rect = Rect2(DisplayServer.get_display_safe_area())
	var clipped := physical_rect.intersection(safe_rect)
	if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
		clipped = physical_rect
	if physical_size.y > physical_size.x:
		clipped = Rect2(Vector2(clipped.position.y, clipped.position.x), Vector2(clipped.size.y, clipped.size.x))
	var render_scale := _render_scale_for_physical_size(physical_size)
	return Rect2(clipped.position / render_scale, clipped.size / render_scale)

func _configure_content_scale() -> void:
	var game_window := get_window()
	if game_window == null:
		return
	# Keep a landscape canvas even while iOS is reporting its startup dimensions.
	var canvas_size := Vector2i(_layout_size_for_physical_size(_physical_viewport_size()))
	if game_window.content_scale_size != canvas_size:
		game_window.content_scale_size = canvas_size
	if game_window.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_KEEP:
		game_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	if not is_equal_approx(game_window.content_scale_factor, 1.0):
		game_window.content_scale_factor = 1.0

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
	if _should_show_run_escape_actions():
		var header := _make_run_escape_bar()
		var row := header.get_child(0) as BoxContainer
		var heading := row.get_child(0) as Label
		if heading == null:
			heading = _make_label(title, 18, Color(1.0, 0.88, 0.55))
			row.add_child(heading)
			row.move_child(heading, 0)
		heading.text = title
		if _is_mobile_phone_layout():
			heading.custom_minimum_size.x = 80
			heading.autowrap_mode = TextServer.AUTOWRAP_OFF
			heading.clip_text = true
			heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		heading.add_theme_font_size_override("font_size", 18 if _is_mobile_phone_layout() else 22)
		heading.tooltip_text = subtitle
		root_box.add_child(header)
		var compact_body := VBoxContainer.new()
		compact_body.add_theme_constant_override("separation", 10)
		compact_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_box.add_child(compact_body)
		if with_profile:
			compact_body.add_child(_make_run_summary_panel())
		return compact_body
	var summary: Control = null
	if with_profile and not current_run.is_empty():
		summary = _make_run_summary_panel()
	var body: VBoxContainer = ui.begin_screen(root_box, title, summary, 10 if _is_mobile_phone_layout() else 12, subtitle, _is_compact_layout())
	if _should_show_run_escape_actions():
		body.add_child(_make_run_escape_bar())
	return body

func _should_show_run_escape_actions() -> bool:
	if current_run.is_empty():
		return false
	return active_screen not in ["main_menu", "run_result", "battle"]

func _make_run_escape_bar() -> PanelContainer:
	var compact := _is_compact_layout_for(1180.0, 760.0)
	var phone := _is_mobile_phone_layout()
	var panel: PanelContainer = ui.make_surface_panel(Color(0.055, 0.065, 0.08, 0.98), Color(0.24, 0.2, 0.12, 1.0), 1, 8 if phone else 10, 6 if phone else 10)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: BoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	if not phone:
		var hint: Label = _make_label("런 메뉴", 12 if compact else 13, Color(1.0, 0.88, 0.55, 1.0))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(hint)

	var actions: BoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(actions)

	_add_escape_action_button(actions, "메인 메뉴", "_show_main_menu", Color(0.16, 0.2, 0.26, 1.0), compact, phone)
	_add_escape_action_button(actions, "런 포기", "_abandon_run", Color(0.34, 0.14, 0.14, 1.0), compact, phone)
	if not phone and not OS.has_feature("web"):
		_add_escape_action_button(actions, "게임 종료", "_quit_game", Color(0.18, 0.18, 0.18, 1.0), compact, false)
	return panel

func _add_escape_action_button(parent: Node, text: String, callback_method: String, color: Color, compact: bool, phone: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0 if phone else (96 if compact else 108), 48 if phone else (34 if compact else 36))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone else Control.SIZE_FILL
	var role := "danger" if callback_method == "_abandon_run" else "secondary"
	var accent := Color(0.9, 0.3, 0.28, 1.0) if role == "danger" else color.lightened(0.34)
	ui.style_role_button(button, role, accent, color, 13 if phone else (12 if compact else 13))
	button.add_theme_font_size_override("font_size", 13 if phone else (12 if compact else 13))
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

func _unhandled_input(event: InputEvent) -> void:
	if active_screen != "battle" or battle_screen == null or battle_screen.pending_action.is_empty():
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		battle_screen._cancel_ally_selection()
		get_viewport().set_input_as_handled()
