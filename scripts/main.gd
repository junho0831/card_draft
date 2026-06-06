extends Control

const MAX_HEALTH := 20
const MAX_MANA := 10
const MAX_FIELD := 5
const START_HAND := 4
const DECK_SIZE := 30
const MAX_CARD_COPIES := 3
const PROFILE_PATH := "user://profile.json"
const CARD_DATA_PATH := "res://data/cards.json"
const CARD_ART_SHEET := preload("res://assets/card_art/season1_sample_sheet.png")
const BATTLE_CUTSCENE_SCENE := preload("res://scenes/BattleCutscene.tscn")
const ApiClientScript := preload("res://scripts/api_client.gd")
const CardDatabaseScript := preload("res://scripts/card_database.gd")
const DeckServiceScript := preload("res://scripts/deck_service.gd")
const ProfileStoreScript := preload("res://scripts/profile_store.gd")
const RewardServiceScript := preload("res://scripts/reward_service.gd")
const UiFactoryScript := preload("res://scripts/ui_factory.gd")
const CARD_ART_COLS := 4
const CARD_ART_ROWS := 3

var card_defs: Array[Dictionary] = []
var cards_by_id := {}
var card_db
var deck_service
var profile_store
var reward_service
var ui
var api_client
var player_profile := {}
var working_deck: Array = []
var deck_builder_filter := "전체"
var active_mode := "casual"
var opponent_type := "ai"
var server_enabled := false
var active_match_id := ""
var battle_result := ""
var reward_summary := ""

var player := {}
var opponent := {}
var current_player := "player"
var selected_attacker := -1
var game_over := false
var battle_finished := false
var input_locked := false

var root_box: VBoxContainer
var root_scroll: ScrollContainer
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
var battle_cutscene

func _ready() -> void:
	card_db = CardDatabaseScript.new()
	deck_service = DeckServiceScript.new()
	profile_store = ProfileStoreScript.new()
	reward_service = RewardServiceScript.new()
	ui = UiFactoryScript.new()
	ui.setup(CARD_ART_SHEET, CARD_ART_COLS, CARD_ART_ROWS)
	api_client = ApiClientScript.new()
	add_child(api_client)
	_build_base_ui()
	if not card_db.load_cards(CARD_DATA_PATH):
		_show_error_screen("카드 데이터 로드 실패")
		return
	card_defs = card_db.card_defs
	cards_by_id = card_db.cards_by_id
	player_profile = profile_store.load_or_create(PROFILE_PATH, card_defs, deck_service, DECK_SIZE, MAX_CARD_COPIES)
	await _initialize_backend()
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
	var viewport_size := get_viewport_rect().size
	root_box.custom_minimum_size = Vector2(max(320.0, viewport_size.x - 36.0), max(0.0, viewport_size.y - 36.0))
	root_box.offset_left = 18
	root_box.offset_top = 18
	root_box.offset_right = -18
	root_box.offset_bottom = -18

func _clear_screen() -> void:
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

func _save_profile() -> void:
	profile_store.save(PROFILE_PATH, player_profile)

func _initialize_backend() -> void:
	api_client.configure("http://127.0.0.1:8080", String(player_profile.get("server_user_id", "")))
	server_enabled = false
	if not String(player_profile.get("server_user_id", "")).is_empty():
		if await _sync_profile_from_server():
			server_enabled = true
			return

	var login: Dictionary = await api_client.guest_login(String(player_profile.get("player_name", "플레이어")))
	if not bool(login.get("ok", false)):
		return
	var body: Variant = login.get("body", {})
	if typeof(body) != TYPE_DICTIONARY or not body.has("userId"):
		return
	player_profile["server_user_id"] = String(body["userId"])
	api_client.set_user_id(String(player_profile["server_user_id"]))
	if await _sync_profile_from_server():
		server_enabled = true
		_save_profile()

func _sync_profile_from_server() -> bool:
	var profile_result: Dictionary = await api_client.fetch_profile()
	if not bool(profile_result.get("ok", false)):
		return false
	var collection_result: Dictionary = await api_client.fetch_collection()
	if not bool(collection_result.get("ok", false)):
		return false
	var decks_result: Dictionary = await api_client.fetch_decks()
	if not bool(decks_result.get("ok", false)):
		return false

	var profile_body: Variant = profile_result.get("body", {})
	var collection_body: Variant = collection_result.get("body", {})
	var decks_body: Variant = decks_result.get("body", [])
	if typeof(profile_body) != TYPE_DICTIONARY or typeof(collection_body) != TYPE_DICTIONARY or typeof(decks_body) != TYPE_ARRAY:
		return false

	_apply_server_profile(profile_body, collection_body, decks_body)
	_save_profile()
	return true

func _apply_server_profile(profile_body: Dictionary, collection_body: Dictionary, decks_body: Array) -> void:
	player_profile["player_name"] = String(profile_body.get("playerName", "플레이어"))
	player_profile["gold"] = int(profile_body.get("gold", 0))
	player_profile["rank_points"] = int(profile_body.get("rankPoints", 0))
	player_profile["owned_cards"] = {}
	for card_id in collection_body.keys():
		player_profile["owned_cards"][String(card_id)] = int(collection_body[card_id])
	player_profile["selected_deck_id"] = _string_or_empty(profile_body.get("selectedDeckId", ""))
	for deck in decks_body:
		if typeof(deck) != TYPE_DICTIONARY:
			continue
		if bool(deck.get("selected", false)):
			player_profile["selected_deck_id"] = _string_or_empty(deck.get("id", ""))
			player_profile["selected_deck"] = _string_array(deck.get("cardIds", []))
			return

func _string_array(values: Variant) -> Array:
	var result: Array = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		result.append(String(value))
	return result

func _string_or_empty(value: Variant) -> String:
	if value == null:
		return ""
	return String(value)

func _show_error_screen(message: String) -> void:
	_clear_screen()
	_add_title("CARD DRAFT")
	var label := _make_label(message, 20, Color(1.0, 0.65, 0.65, 1.0))
	root_box.add_child(label)

func _show_main_menu() -> void:
	_clear_screen()
	_add_title("CARD DRAFT")
	root_box.add_child(_make_profile_summary())

	var compact := _is_compact_layout()
	var hub: BoxContainer
	if compact:
		hub = VBoxContainer.new()
	else:
		hub = HBoxContainer.new()
	hub.alignment = BoxContainer.ALIGNMENT_CENTER
	hub.add_theme_constant_override("separation", 14)
	hub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_child(hub)

	var showcase := _make_panel_container(Color(0.105, 0.12, 0.145, 1.0))
	showcase.custom_minimum_size = Vector2(_responsive_width(420), 0)
	showcase.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hub.add_child(showcase)

	var showcase_box := VBoxContainer.new()
	showcase_box.add_theme_constant_override("separation", 12)
	showcase.add_child(showcase_box)

	var season := _make_label("SEASON 1 SAMPLE", 13, Color(0.82, 0.88, 0.95, 1.0))
	season.autowrap_mode = TextServer.AUTOWRAP_OFF
	showcase_box.add_child(season)
	showcase_box.add_child(_make_label("필드를 장악하고 랭크를 올리세요", 20, Color(1.0, 0.88, 0.55, 1.0)))

	var art_row := HBoxContainer.new()
	art_row.alignment = BoxContainer.ALIGNMENT_CENTER
	art_row.add_theme_constant_override("separation", 6)
	showcase_box.add_child(art_row)
	art_row.add_child(_make_showcase_card("인간", 0, compact))
	art_row.add_child(_make_showcase_card("엘프", 4, compact))
	art_row.add_child(_make_showcase_card("언데드", 7, compact))

	var stat_row := HBoxContainer.new()
	stat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stat_row.add_theme_constant_override("separation", 6)
	showcase_box.add_child(stat_row)
	stat_row.add_child(_make_stat_tile("골드", str(int(player_profile["gold"])), Color(0.82, 0.55, 0.18, 1.0), compact))
	stat_row.add_child(_make_stat_tile("랭크", reward_service.rank_name(int(player_profile["rank_points"])), Color(0.34, 0.48, 0.62, 1.0), compact))
	stat_row.add_child(_make_stat_tile("카드", "%d장" % deck_service.total_owned_cards(player_profile["owned_cards"]), Color(0.32, 0.52, 0.42, 1.0), compact))

	var backend_text := "로컬 저장"
	var backend_color := Color(0.38, 0.42, 0.48, 1.0)
	if server_enabled:
		backend_text = "Spring Boot 백엔드"
		backend_color = Color(0.24, 0.5, 0.42, 1.0)
	showcase_box.add_child(_make_status_badge("서버 연결", backend_text, backend_color))

	var menu_panel := _make_panel_container(Color(0.13, 0.15, 0.18, 1.0))
	menu_panel.custom_minimum_size = Vector2(_responsive_width(360), 0)
	menu_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hub.add_child(menu_panel)

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	menu_panel.add_child(menu)
	menu.add_child(_make_label("COMMAND", 13, Color(0.82, 0.88, 0.95, 1.0)))

	_add_menu_button(menu, "게임 시작", "_show_mode_select", Color(0.16, 0.38, 0.54, 1.0))
	_add_menu_button(menu, "덱 구성", "_show_deck_builder", Color(0.22, 0.31, 0.38, 1.0))
	_add_menu_button(menu, "카드 보관함", "_show_collection", Color(0.22, 0.31, 0.38, 1.0))
	_add_menu_button(menu, "설정", "_show_settings", Color(0.22, 0.31, 0.38, 1.0))
	_add_menu_button(menu, "종료", "_quit_game", Color(0.42, 0.18, 0.18, 1.0))

	var note := _make_label("AI 매칭 MVP | 덱 30장 | 영웅 체력 20 | 필드 5칸", 14, Color(0.78, 0.82, 0.9, 1.0))
	root_box.add_child(note)

func _show_mode_select() -> void:
	_clear_screen()
	_add_title("매칭 모드")
	root_box.add_child(_make_profile_summary())

	var panel := _make_center_panel(Color(0.12, 0.135, 0.16, 1.0), 520)
	root_box.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var guide := _make_label("덱이 30장이고 동일 카드가 3장 이하일 때만 매칭할 수 있습니다.", 15, Color(0.84, 0.88, 0.95, 1.0))
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(guide)
	_add_menu_button(box, "일반전 - 보상만 획득", "_on_casual_pressed", Color(0.18, 0.34, 0.48, 1.0))
	_add_menu_button(box, "랭크전 - 점수 변동", "_on_ranked_pressed", Color(0.26, 0.24, 0.46, 1.0))
	_add_menu_button(box, "뒤로", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))

func _on_casual_pressed() -> void:
	_start_matching("casual")

func _on_ranked_pressed() -> void:
	_start_matching("ranked")

func _start_matching(mode: String) -> void:
	if not deck_service.is_deck_valid(player_profile["selected_deck"], cards_by_id, player_profile["owned_cards"], DECK_SIZE, MAX_CARD_COPIES):
		_show_message("덱이 유효하지 않습니다. 덱 구성에서 30장 덱을 먼저 저장하세요.", "_show_deck_builder")
		return
	active_mode = mode
	opponent_type = "ai"
	active_match_id = ""
	_clear_screen()
	_add_title("상대 찾는 중...")
	root_box.add_child(_make_profile_summary())
	var panel := _make_center_panel(Color(0.12, 0.135, 0.16, 1.0), 520)
	root_box.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_make_label("%s AI 상대를 찾고 있습니다." % _mode_name(active_mode), 20, Color(0.96, 0.88, 0.68, 1.0)))
	box.add_child(_make_label("매칭 방식: AI 연출 / 실제 PvP는 서버 단계에서 구현", 14, Color(0.78, 0.82, 0.9, 1.0)))
	if server_enabled:
		var match_result: Dictionary = await api_client.create_ai_match(active_mode, String(player_profile.get("selected_deck_id", "")))
		if bool(match_result.get("ok", false)) and typeof(match_result.get("body", {})) == TYPE_DICTIONARY:
			active_match_id = String(match_result["body"].get("matchId", ""))
		else:
			server_enabled = false
			box.add_child(_make_label("서버 매칭 실패. 이번 전투는 로컬 보상으로 진행합니다.", 14, Color(1.0, 0.68, 0.62, 1.0)))
	await get_tree().create_timer(1.0).timeout
	_start_battle(active_mode)

func _show_deck_builder() -> void:
	working_deck.clear()
	for id in player_profile["selected_deck"]:
		working_deck.append(String(id))
	deck_builder_filter = "전체"
	_render_deck_builder()

func _render_deck_builder() -> void:
	_clear_screen()
	_add_title("덱 구성")
	var validation: String = deck_service.validation_message(working_deck, cards_by_id, player_profile["owned_cards"], DECK_SIZE, MAX_CARD_COPIES)
	var validation_color := Color(1.0, 0.68, 0.62, 1.0)
	if validation == "저장 가능":
		validation_color = Color(0.62, 1.0, 0.72, 1.0)
	root_box.add_child(_make_label("현재 %d/%d장 | %s" % [working_deck.size(), DECK_SIZE, validation], 17, validation_color))

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	root_box.add_child(actions)
	for filter in ["전체", "인간", "엘프", "언데드", "중립"]:
		var button := Button.new()
		button.text = filter
		button.custom_minimum_size = Vector2(86, 34)
		var filter_button_color := Color(0.18, 0.24, 0.3, 1.0)
		if filter == deck_builder_filter:
			filter_button_color = Color(0.38, 0.31, 0.12, 1.0)
		_style_button(button, filter_button_color)
		button.pressed.connect(Callable(self, "_set_deck_filter").bind(filter))
		actions.add_child(button)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	root_box.add_child(content)

	var card_panel := _make_panel_container(Color(0.105, 0.115, 0.135, 1.0))
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(card_panel)
	var card_scroll := ScrollContainer.new()
	card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_panel.add_child(card_scroll)
	var card_list := VBoxContainer.new()
	card_list.add_theme_constant_override("separation", 6)
	card_scroll.add_child(card_list)

	for card in card_defs:
		if deck_builder_filter != "전체" and String(card.race) != deck_builder_filter:
			continue
		card_list.add_child(_make_deck_builder_card_row(card))

	var deck_panel := _make_panel_container(Color(0.12, 0.135, 0.16, 1.0))
	deck_panel.custom_minimum_size = Vector2(330, 0)
	deck_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(deck_panel)
	var deck_box := VBoxContainer.new()
	deck_box.add_theme_constant_override("separation", 8)
	deck_panel.add_child(deck_box)
	deck_box.add_child(_make_label("선택한 덱", 20, Color(0.96, 0.88, 0.68, 1.0)))
	deck_box.add_child(_make_label(deck_service.deck_summary_text(working_deck, cards_by_id), 14, Color(0.9, 0.92, 0.95, 1.0)))

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 10)
	root_box.add_child(bottom)
	_add_menu_button(bottom, "덱 저장", "_save_working_deck", Color(0.18, 0.34, 0.48, 1.0))
	_add_menu_button(bottom, "메인으로", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))

func _make_deck_builder_card_row(card: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 72)
	row.add_theme_constant_override("separation", 8)

	row.add_child(_make_art_rect(int(card.art), Vector2(84, 54)))
	var id := String(card.id)
	var owned := int(player_profile["owned_cards"].get(id, 0))
	var selected: int = deck_service.count_in_array(working_deck, id)
	var info := _make_label("[%d] %s  %s/%s  보유 %d | 덱 %d" % [card.cost, card.name, card.race, card.attr, owned, selected], 15, Color(0.92, 0.94, 0.98, 1.0))
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(38, 34)
	_style_button(minus, Color(0.35, 0.16, 0.16, 1.0))
	minus.disabled = selected <= 0
	minus.pressed.connect(Callable(self, "_remove_from_working_deck").bind(id))
	row.add_child(minus)

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(38, 34)
	_style_button(plus, Color(0.18, 0.34, 0.48, 1.0))
	plus.disabled = working_deck.size() >= DECK_SIZE or selected >= MAX_CARD_COPIES or selected >= owned
	plus.pressed.connect(Callable(self, "_add_to_working_deck").bind(id))
	row.add_child(plus)
	return row

func _set_deck_filter(filter: String) -> void:
	deck_builder_filter = filter
	_render_deck_builder()

func _add_to_working_deck(id: String) -> void:
	if working_deck.size() >= DECK_SIZE:
		return
	if deck_service.count_in_array(working_deck, id) >= MAX_CARD_COPIES:
		return
	if deck_service.count_in_array(working_deck, id) >= int(player_profile["owned_cards"].get(id, 0)):
		return
	working_deck.append(id)
	_render_deck_builder()

func _remove_from_working_deck(id: String) -> void:
	var index := working_deck.find(id)
	if index != -1:
		working_deck.remove_at(index)
	_render_deck_builder()

func _save_working_deck() -> void:
	if not deck_service.is_deck_valid(working_deck, cards_by_id, player_profile["owned_cards"], DECK_SIZE, MAX_CARD_COPIES):
		_show_message("덱 저장 실패: 30장, 동일 카드 최대 3장, 보유 수량 이하로 구성해야 합니다.", "_show_deck_builder")
		return
	if server_enabled:
		var save_result: Dictionary
		var selected_deck_id := String(player_profile.get("selected_deck_id", ""))
		if selected_deck_id.is_empty():
			save_result = await api_client.create_deck("내 덱", working_deck)
		else:
			save_result = await api_client.update_deck(selected_deck_id, "내 덱", working_deck)
		if bool(save_result.get("ok", false)) and typeof(save_result.get("body", {})) == TYPE_DICTIONARY:
			var deck_body: Dictionary = save_result["body"]
			player_profile["selected_deck_id"] = String(deck_body.get("id", selected_deck_id))
			player_profile["selected_deck"] = _string_array(deck_body.get("cardIds", working_deck))
			await _sync_profile_from_server()
			_show_message("서버에 덱을 저장했습니다.", "_show_main_menu")
			return
		server_enabled = false
	player_profile["selected_deck"] = working_deck.duplicate()
	_save_profile()
	_show_message("덱을 저장했습니다.", "_show_main_menu")

func _show_collection() -> void:
	_clear_screen()
	_add_title("카드 보관함")
	root_box.add_child(_make_profile_summary())
	var panel := _make_panel_container(Color(0.105, 0.115, 0.135, 1.0))
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for card in card_defs:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_make_art_rect(int(card.art), Vector2(96, 62)))
		var stat := ""
		if card.type == "unit":
			stat = " %d/%d" % [card.attack, card.health]
			row.add_child(_make_label("%s%s | 비용 %d | %s/%s | %s | 보유 %d장\n%s" % [card.name, stat, card.cost, card.race, card.attr, deck_service.type_name(String(card.type)), int(player_profile["owned_cards"].get(String(card.id), 0)), card.text], 15, Color(0.92, 0.94, 0.98, 1.0)))
		list.add_child(row)
	_add_menu_button(root_box, "메인으로", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))

func _show_settings() -> void:
	_clear_screen()
	_add_title("설정")
	var panel := _make_panel_container(Color(0.12, 0.135, 0.16, 1.0))
	panel.custom_minimum_size = Vector2(480, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root_box.add_child(panel)
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

	_add_menu_button(box, "로컬 진행 데이터 초기화", "_reset_profile", Color(0.35, 0.16, 0.16, 1.0))
	_add_menu_button(box, "메인으로", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))

func _on_cutscene_toggled(enabled: bool) -> void:
	player_profile["settings"]["battle_cutscene"] = enabled
	_save_profile()

func _on_fast_ai_toggled(enabled: bool) -> void:
	player_profile["settings"]["fast_ai"] = enabled
	_save_profile()

func _reset_profile() -> void:
	player_profile = profile_store.make_default_profile(card_defs, DECK_SIZE)
	_save_profile()
	_show_message("로컬 진행 데이터를 초기화했습니다.", "_show_main_menu")

func _show_message(message: String, callback_method: String) -> void:
	_clear_screen()
	_add_title("알림")
	var panel := _make_center_panel(Color(0.12, 0.135, 0.16, 1.0), 520)
	root_box.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_make_label(message, 18, Color(0.92, 0.94, 0.98, 1.0)))
	_add_menu_button(box, "확인", callback_method, Color(0.18, 0.34, 0.48, 1.0))

func _start_battle(mode: String) -> void:
	_clear_screen()
	active_mode = mode
	opponent_type = "ai"
	player = _new_player("플레이어", card_db.build_deck_from_ids(player_profile["selected_deck"]))
	opponent = _new_player("AI 상대", card_db.build_starter_deck(DECK_SIZE))
	_draw_cards(player, START_HAND)
	_draw_cards(opponent, START_HAND)
	current_player = "player"
	game_over = false
	battle_finished = false
	input_locked = false
	selected_attacker = -1
	_build_battle_ui()
	_start_turn(player)
	_add_log("%s 시작. 상대 영웅 체력을 0으로 만드세요." % _mode_name(active_mode))
	_refresh_ui()

func _build_battle_ui() -> void:
	_add_title("CARD DRAFT")

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0, 1.0))
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

	opponent_info = Label.new()
	opponent_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opponent_info.add_theme_color_override("font_color", Color(1.0, 0.78, 0.78, 1.0))
	board_box.add_child(opponent_info)

	opponent_field_box = HBoxContainer.new()
	opponent_field_box.alignment = BoxContainer.ALIGNMENT_CENTER
	opponent_field_box.custom_minimum_size = Vector2(0, 124)
	board_box.add_child(opponent_field_box)

	hero_attack_button = Button.new()
	hero_attack_button.text = "상대 영웅 공격"
	hero_attack_button.custom_minimum_size = Vector2(160, 42)
	_style_button(hero_attack_button, Color(0.5, 0.13, 0.13, 1.0))
	hero_attack_button.pressed.connect(Callable(self, "_attack_opponent_hero"))
	board_box.add_child(hero_attack_button)

	board_box.add_child(HSeparator.new())

	player_field_box = HBoxContainer.new()
	player_field_box.alignment = BoxContainer.ALIGNMENT_CENTER
	player_field_box.custom_minimum_size = Vector2(0, 124)
	board_box.add_child(player_field_box)

	player_info = Label.new()
	player_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_info.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0, 1.0))
	board_box.add_child(player_info)

	var hand_title := _make_label("내 손패", 16, Color(0.96, 0.88, 0.68, 1.0))
	board_box.add_child(hand_title)

	hand_box = HBoxContainer.new()
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_box.custom_minimum_size = Vector2(0, 166)
	board_box.add_child(hand_box)

	end_turn_button = Button.new()
	end_turn_button.text = "턴 종료"
	end_turn_button.custom_minimum_size = Vector2(150, 44)
	_style_button(end_turn_button, Color(0.18, 0.34, 0.48, 1.0))
	end_turn_button.pressed.connect(Callable(self, "_on_end_turn_pressed"))
	board_box.add_child(end_turn_button)

	var side_panel := _make_panel_container(Color(0.105, 0.115, 0.135, 1.0))
	side_panel.custom_minimum_size = Vector2(330, 0)
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(side_panel)

	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 10)
	side_panel.add_child(side_box)

	side_box.add_child(_make_label("내 덱", 20, Color(0.96, 0.88, 0.68, 1.0)))
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

	side_box.add_child(_make_label("게임 로그", 20, Color(0.96, 0.88, 0.68, 1.0)))
	log_label = RichTextLabel.new()
	log_label.custom_minimum_size = Vector2(0, 180)
	log_label.bbcode_enabled = false
	log_label.fit_content = false
	log_label.add_theme_color_override("default_color", Color(0.9, 0.92, 0.95, 1.0))
	side_box.add_child(log_label)

func _new_player(display_name: String, deck: Array) -> Dictionary:
	deck.shuffle()
	return {
		"name": display_name,
		"health": MAX_HEALTH,
		"mana": 0,
		"max_mana": 0,
		"deck": deck,
		"hand": [],
		"field": [],
	}

func _start_turn(side: Dictionary) -> void:
	side.max_mana = min(MAX_MANA, int(side.max_mana) + 1)
	side.mana = side.max_mana
	for unit in side.field:
		unit.can_attack = true
	_draw_cards(side, 1)
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
	if int(card.cost) > int(player.mana):
		_add_log("마나가 부족합니다.")
		return
	if card.type == "unit" and player.field.size() >= MAX_FIELD:
		_add_log("필드가 가득 찼습니다.")
		return
	if card.type == "equipment" and player.field.is_empty():
		_add_log("장착할 아군 유닛이 없습니다.")
		return

	player.mana -= int(card.cost)
	player.hand.remove_at(index)
	_play_card(player, opponent, card)
	_check_game_over()
	_refresh_ui()

func _play_card(owner: Dictionary, enemy: Dictionary, card: Dictionary) -> void:
	match String(card.type):
		"unit":
			var unit := {
				"name": card.name,
				"race": card.race,
				"attr": card.attr,
				"attack": int(card.attack),
				"health": int(card.health),
				"max_health": int(card.health),
				"art": int(card.art),
				"can_attack": false,
			}
			owner.field.append(unit)
			_add_log("%s: %s 소환" % [owner.name, card.name])
			if card.id == "forest_archer":
				_draw_cards(owner, 1)
				_add_log("숲의 궁수 효과: 카드 1장 드로우")
		"spell":
			_resolve_spell(owner, enemy, card)
		"equipment":
			owner.field[0].attack += 2
			_add_log("%s: 엘프의 활 장착, %s 공격력 +2" % [owner.name, owner.field[0].name])

func _resolve_spell(owner: Dictionary, enemy: Dictionary, card: Dictionary) -> void:
	match String(card.id):
		"captain_order":
			for unit in owner.field:
				unit.attack += 1
			_add_log("%s: 지휘관의 명령, 아군 전체 공격력 +1" % owner.name)
		"elven_insight":
			_draw_cards(owner, 2)
			_add_log("%s: 엘프의 통찰, 카드 2장 드로우" % owner.name)
		"dark_bargain":
			owner.health -= 2
			_draw_cards(owner, 2)
			_add_log("%s: 어둠의 거래, 체력 2 지불 후 카드 2장 드로우" % owner.name)
		"fireball":
			if enemy.field.is_empty():
				enemy.health -= 4
				_add_log("%s: 화염구로 %s 영웅에게 피해 4" % [owner.name, enemy.name])
			else:
				enemy.field[0].health -= 4
				_add_log("%s: 화염구로 %s에게 피해 4" % [owner.name, enemy.field[0].name])
				_cleanup_dead_units(owner, enemy)
		"healing_spring":
			owner.health = min(MAX_HEALTH, int(owner.health) + 3)
			_add_log("%s: 치유의 샘, 영웅 체력 3 회복" % owner.name)

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
	input_locked = true
	_refresh_ui()
	await _play_hero_cutscene(attacker, opponent.name, int(attacker.attack))
	opponent.health -= int(attacker.attack)
	attacker.can_attack = false
	_add_log("%s가 상대 영웅에게 피해 %d" % [attacker.name, attacker.attack])
	selected_attacker = -1
	input_locked = false
	_check_game_over()
	_refresh_ui()

func _combat(attacker_side: Dictionary, defender_side: Dictionary, attacker_index: int, defender_index: int) -> void:
	var attacker: Dictionary = attacker_side.field[attacker_index]
	var defender: Dictionary = defender_side.field[defender_index]
	input_locked = true
	_refresh_ui()
	await _play_unit_cutscene(attacker, defender)
	attacker.health -= int(defender.attack)
	defender.health -= int(attacker.attack)
	attacker.can_attack = false
	_add_log("%s(%d/%d) vs %s(%d/%d)" % [attacker.name, attacker.attack, attacker.health, defender.name, defender.attack, defender.health])
	_cleanup_dead_units(attacker_side, defender_side)
	input_locked = false

func _play_unit_cutscene(attacker: Dictionary, defender: Dictionary) -> void:
	if bool(player_profile["settings"]["battle_cutscene"]):
		await battle_cutscene.play_unit_battle(attacker, defender)

func _play_hero_cutscene(attacker: Dictionary, defender_name: String, damage: int) -> void:
	if bool(player_profile["settings"]["battle_cutscene"]):
		await battle_cutscene.play_hero_attack(attacker, defender_name, damage)

func _cleanup_dead_units(side_a: Dictionary, side_b: Dictionary) -> void:
	_cleanup_side_dead(side_a)
	_cleanup_side_dead(side_b)

func _cleanup_side_dead(side: Dictionary) -> void:
	for i in range(side.field.size() - 1, -1, -1):
		if int(side.field[i].health) <= 0:
			var dead_name: String = side.field[i].name
			if dead_name == "무덤 기사":
				side.health = min(MAX_HEALTH, int(side.health) + 2)
				_add_log("무덤 기사 사망 효과: %s 영웅 체력 2 회복" % side.name)
			side.field.remove_at(i)
			_add_log("%s 사망" % dead_name)

func _on_end_turn_pressed() -> void:
	if input_locked or game_over or current_player != "player":
		return
	current_player = "opponent"
	selected_attacker = -1
	_start_turn(opponent)
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
			if int(card.cost) <= int(opponent.mana):
				if card.type == "unit" and opponent.field.size() >= MAX_FIELD:
					continue
				if card.type == "equipment" and opponent.field.is_empty():
					continue
				opponent.mana -= int(card.cost)
				opponent.hand.remove_at(i)
				_play_card(opponent, player, card)
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
			input_locked = true
			_refresh_ui()
			await _play_hero_cutscene(unit, player.name, int(unit.attack))
			player.health -= int(unit.attack)
			unit.can_attack = false
			_add_log("%s가 내 영웅에게 피해 %d" % [unit.name, unit.attack])
			input_locked = false
		_check_game_over()
		if game_over:
			break
		if i < opponent.field.size() and not bool(opponent.field[i].can_attack):
			i += 1

	if not game_over:
		current_player = "player"
		_start_turn(player)
	_refresh_ui()

func _check_game_over() -> void:
	if battle_finished:
		return
	if int(player.health) <= 0:
		game_over = true
		battle_finished = true
		battle_result = "loss"
		_add_log("패배: 내 영웅 체력이 0이 되었습니다.")
		_finish_battle()
	elif int(opponent.health) <= 0:
		game_over = true
		battle_finished = true
		battle_result = "win"
		_add_log("승리: 상대 영웅 체력이 0이 되었습니다.")
		_finish_battle()

func _finish_battle() -> void:
	input_locked = true
	_refresh_ui()
	await get_tree().create_timer(0.8).timeout
	await _apply_reward()
	_save_profile()
	_show_reward_screen()

func _apply_reward() -> void:
	if server_enabled and not active_match_id.is_empty():
		var result_from_server: Dictionary = await api_client.submit_match_result(active_match_id, battle_result)
		if bool(result_from_server.get("ok", false)) and typeof(result_from_server.get("body", {})) == TYPE_DICTIONARY:
			var body: Dictionary = result_from_server["body"]
			reward_summary = String(body.get("summary", ""))
			if typeof(body.get("profile", {})) == TYPE_DICTIONARY and typeof(body.get("collection", {})) == TYPE_DICTIONARY:
				var decks_result: Dictionary = await api_client.fetch_decks()
				var decks_body: Array = []
				if bool(decks_result.get("ok", false)) and typeof(decks_result.get("body", [])) == TYPE_ARRAY:
					decks_body = decks_result["body"]
				_apply_server_profile(body["profile"], body["collection"], decks_body)
			active_match_id = ""
			return
		server_enabled = false
	var result: Dictionary = reward_service.apply_reward(player_profile, active_mode, battle_result, card_defs)
	player_profile = result["profile"]
	reward_summary = String(result["summary"])

func _show_reward_screen() -> void:
	_clear_screen()
	_add_title("전투 결과")
	root_box.add_child(_make_profile_summary())
	var panel := _make_center_panel(Color(0.12, 0.135, 0.16, 1.0), 520)
	root_box.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_make_label(reward_summary, 20, Color(0.92, 0.94, 0.98, 1.0)))
	box.add_child(_make_label("현재 랭크: %s / %d점" % [reward_service.rank_name(int(player_profile["rank_points"])), int(player_profile["rank_points"])], 16, Color(0.96, 0.88, 0.68, 1.0)))
	_add_menu_button(box, "메인으로", "_show_main_menu", Color(0.18, 0.34, 0.48, 1.0))

func _refresh_ui() -> void:
	if status_label == null:
		return
	var turn_text := "상대"
	if current_player == "player":
		turn_text = "플레이어"
	status_label.text = "%s | 현재 턴: %s" % [_mode_name(active_mode), turn_text]
	opponent_info.text = "상대 영웅 HP %d | 마나 %d/%d | 손패 %d | 덱 %d" % [opponent.health, opponent.mana, opponent.max_mana, opponent.hand.size(), opponent.deck.size()]
	player_info.text = "내 영웅 HP %d | 마나 %d/%d | 덱 %d" % [player.health, player.mana, player.max_mana, player.deck.size()]
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
		_style_button(button, Color(0.2, 0.23, 0.28, 1.0))
		if i < side.field.size():
			var unit: Dictionary = side.field[i]
			slot.add_child(_make_art_rect(int(unit.art), Vector2(130, 68)))
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
		card_box.add_child(_make_art_rect(int(card.art), Vector2(145, 82)))
		var button := Button.new()
		button.custom_minimum_size = Vector2(145, 68)
		button.text = "%s\n비용 %d | %s\n%s" % [card.name, card.cost, deck_service.type_name(String(card.type)), card.text]
		button.disabled = input_locked or game_over or current_player != "player" or int(card.cost) > int(player.mana)
		_style_button(button, Color(0.18, 0.24, 0.3, 1.0))
		button.pressed.connect(Callable(self, "_on_hand_card_pressed").bind(i))
		card_box.add_child(button)
		hand_box.add_child(frame)

func _render_battle_deck() -> void:
	if deck_count_label == null or deck_list_label == null:
		return
	deck_count_label.text = "남은 카드 %d장 / 시작 %d장" % [player.deck.size(), DECK_SIZE]
	deck_list_label.text = deck_service.deck_summary_from_cards(player.deck)

func _make_showcase_card(title: String, art_index: int, compact: bool = false) -> PanelContainer:
	var panel := _make_panel_container(Color(0.14, 0.16, 0.19, 1.0))
	var card_width := 120
	var art_size := Vector2(96, 112)
	if compact:
		card_width = 92
		art_size = Vector2(70, 86)
	panel.custom_minimum_size = Vector2(card_width, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(_make_art_rect(art_index, art_size))
	var label := _make_label(title, 15, Color(0.95, 0.96, 0.93, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(label)
	return panel

func _make_stat_tile(title: String, value: String, color: Color, compact: bool = false) -> PanelContainer:
	var panel := _make_panel_container(color)
	panel.custom_minimum_size = Vector2(96 if compact else 126, 64 if compact else 72)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var title_label := _make_label(title, 12, Color(0.88, 0.9, 0.92, 1.0))
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var value_label := _make_label(value, 18, Color(1.0, 0.98, 0.9, 1.0))
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(title_label)
	box.add_child(value_label)
	return panel

func _make_status_badge(title: String, value: String, color: Color) -> PanelContainer:
	var panel := _make_panel_container(color)
	panel.custom_minimum_size = Vector2(0, 58)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var title_label := _make_label(title, 13, Color(0.9, 0.94, 0.96, 1.0))
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var value_label := _make_label(value, 15, Color(1.0, 0.98, 0.88, 1.0))
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(title_label)
	row.add_child(value_label)
	return panel

func _is_compact_layout() -> bool:
	return get_viewport_rect().size.x < 860.0

func _responsive_width(preferred_width: int) -> float:
	var viewport_width := get_viewport_rect().size.x
	return min(float(preferred_width), max(280.0, viewport_width - 48.0))

func _make_center_panel(color: Color, preferred_width: int) -> PanelContainer:
	var panel := _make_panel_container(color)
	panel.custom_minimum_size = Vector2(_responsive_width(preferred_width), 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return panel

func _make_profile_summary() -> PanelContainer:
	var panel := _make_panel_container(Color(0.105, 0.115, 0.135, 1.0))
	panel.custom_minimum_size = Vector2(_responsive_width(560), 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label := _make_label("%s | 골드 %d | %s %d점 | 보유 카드 %d장" % [
		String(player_profile["player_name"]),
		int(player_profile["gold"]),
		reward_service.rank_name(int(player_profile["rank_points"])),
		int(player_profile["rank_points"]),
		deck_service.total_owned_cards(player_profile["owned_cards"]),
	], 16, Color(0.9, 0.92, 0.95, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(label)
	return panel

func _mode_name(mode: String) -> String:
	return reward_service.mode_name(mode)

func _add_title(text: String) -> void:
	ui.add_title(root_box, text)

func _make_label(text: String, font_size: int, color: Color) -> Label:
	return ui.make_label(text, font_size, color)

func _add_menu_button(parent: Node, text: String, callback_method: String, color: Color) -> Button:
	return ui.add_menu_button(parent, self, text, callback_method, color)

func _make_panel_container(color: Color) -> PanelContainer:
	return ui.make_panel_container(color)

func _style_button(button: Button, base_color: Color) -> void:
	ui.style_button(button, base_color)

func _make_card_frame() -> PanelContainer:
	return ui.make_card_frame()

func _make_art_rect(art_index: int, size: Vector2) -> TextureRect:
	return ui.make_art_rect(art_index, size)

func _add_log(message: String) -> void:
	if log_label == null:
		return
	log_label.text = message + "\n" + log_label.text

func _quit_game() -> void:
	get_tree().quit()
