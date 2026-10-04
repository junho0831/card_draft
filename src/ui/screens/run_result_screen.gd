extends RefCounted
class_name RunResultScreen

const BATTLE_FX_LAYER = preload("res://src/ui/effects/battle_fx_layer.gd")

const Layout = preload("res://src/ui/screens/screen_layout.gd")
const Tokens = preload("res://src/ui/styles/ui_tokens.gd")

var main: Node
var screen_action_dock: PanelContainer = null

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer, is_win: bool, play_audio: bool = true) -> void:
	var suppress_victory_audio := is_win and bool(main.get_meta("suppress_next_result_victory_audio", false))
	if play_audio and main.has_meta("suppress_next_result_victory_audio"):
		main.remove_meta("suppress_next_result_victory_audio")
	if play_audio and main.audio_manager != null and not suppress_victory_audio:
		main.audio_manager.play_sound("victory_burst" if is_win else "defeat")
	var race_meta: Dictionary = main._current_race_meta()
	var scores: Dictionary = main._current_build_scores()
	var primary_tag: String = main._primary_build_tag(scores)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	body.add_child(row)
	var representative_card: Dictionary = main.card_db.get_card(String(race_meta.get("representative_card_id", "")))
	var representative_art: Control = main._make_card_art_rect(representative_card, Vector2(220, 160))
	row.add_child(representative_art)
	if is_win and play_audio and not suppress_victory_audio and DisplayServer.get_name() != "headless":
		var result_fx: Control = BATTLE_FX_LAYER.new()
		main.modal_layer.add_child(result_fx)
		var race_color: Color = race_meta.get("color", Tokens.ACCENT_GOLD)
		main.get_tree().create_timer(0.08).timeout.connect(Callable(self, "_start_result_victory_fx").bind(result_fx, race_color, representative_art))
	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override("separation", 8)
	row.add_child(summary)
	var title: Label = main.ui.make_label("승리!" if is_win else "패배", 24, Tokens.ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	summary.add_child(title)
	summary.add_child(Layout.label(main, "Act %d · %s · %s" % [main.current_run.get("act", 1), race_meta.get("name", ""), _format_run_duration()]))
	summary.add_child(Layout.label(main, "영혼석 +%d · 보유 %d" % [main.current_run.get("earned_soul_stones", 0), main.player_profile.get("soul_stones", 0)]))
	summary.add_child(Layout.label(main, "처치 %d · 방문 %d · 획득 골드 %d" % [main.current_run.get("enemies_defeated", 0), main.current_run.get("visited_nodes", []).size(), main.current_run.get("gold_earned", 0)], true))
	summary.add_child(Layout.label(main, "덱 %d장 · 유물 %d개" % [main.current_run.get("deck_ids", []).size(), main.current_run.get("relic_ids", []).size()], true))
	body.add_child(HSeparator.new())
	body.add_child(Layout.label(main, main._build_status_text(scores)))
	body.add_child(Layout.label(main, main._active_build_text(scores), true))
	body.add_child(Layout.label(main, "주요 카드 · %s     주요 유물 · %s" % [_run_key_card_name(primary_tag), _run_key_relic_name(primary_tag)], true))
	var dock: Dictionary = Layout.dock(main, body)
	screen_action_dock = dock.panel
	var menu: Button = main.ui.make_dock_action_button("메인 메뉴", "", Tokens.ACCENT_TEAL, false, 144)
	menu.pressed.connect(Callable(main, "_return_to_main_after_run"))
	dock.actions.add_child(menu)
	var start: Button = main.ui.make_dock_action_button("새로운 런", "", Tokens.ACCENT_GOLD, true, 160)
	start.pressed.connect(Callable(main, "_start_new_run"))
	dock.actions.add_child(start)

func _mount_result_action_dock(body: VBoxContainer, is_win: bool) -> void:
	var dock: Dictionary = main.ui.mount_screen_action_dock(
		main,
		body,
		"런 %s · 다음 행동" % ("클리어" if is_win else "종료"),
		"영혼석 +%d · 바로 새 세력을 선택하거나 메뉴로 돌아갈 수 있습니다." % int(main.current_run.get("earned_soul_stones", 0)),
		Color(0.78, 0.56, 0.22, 1.0) if is_win else Color(0.62, 0.26, 0.24, 1.0),
		126
	)
	screen_action_dock = dock.get("panel") as PanelContainer
	var actions: BoxContainer = dock.get("actions") as BoxContainer
	var new_run_button: Button = main.ui.make_dock_action_button("새로운 런 ▶", "세력부터 다시 선택", Color(0.56, 0.38, 0.12, 1.0), true, 202)
	new_run_button.pressed.connect(Callable(main, "_start_new_run"))
	actions.add_child(new_run_button)
	var menu_button: Button = main.ui.make_dock_action_button("메인 메뉴", "결과 저장 후 이동", Color(0.2, 0.24, 0.3, 1.0), false, 166)
	menu_button.pressed.connect(Callable(main, "_return_to_main_after_run"))
	actions.add_child(menu_button)

func _is_run_result_compact_layout() -> bool:
	return main._is_compact_layout_for(1180.0, 800.0)

func _start_result_victory_fx(result_fx: Control, color: Color, anchor: Control) -> void:
	if main.active_screen != "run_result":
		return
	if result_fx == null or not is_instance_valid(result_fx) or anchor == null or not is_instance_valid(anchor):
		return
	result_fx.play_victory(color, false, anchor)

func _format_run_duration() -> String:
	var started_at := int(main.current_run.get("started_at", 0))
	var finished_at := int(main.current_run.get("finished_at", 0))
	if started_at <= 0:
		return "--:--"
	if finished_at <= 0:
		finished_at = int(Time.get_unix_time_from_system())
	var elapsed: int = max(0, finished_at - started_at)
	var minutes := int(elapsed / 60)
	var seconds := elapsed % 60
	return "%02d:%02d" % [minutes, seconds]

func _run_key_card_name(primary_tag: String) -> String:
	for card_id_variant in main.current_run.get("deck_ids", []):
		var card: Dictionary = main.card_db.get_card(String(card_id_variant))
		if card.is_empty():
			continue
		if primary_tag.is_empty() or main._card_build_tags(card).has(primary_tag):
			return String(card.get("name", card_id_variant))
	return "없음"

func _run_key_relic_name(primary_tag: String) -> String:
	for relic_id_variant in main.current_run.get("relic_ids", []):
		var relic: Dictionary = main.relic_service.get_relic(String(relic_id_variant))
		if relic.is_empty():
			continue
		if primary_tag.is_empty() or main._relic_build_tags(relic).has(primary_tag):
			return String(relic.get("name", relic_id_variant))
	return "없음"

func _run_result_headline(is_win: bool) -> String:
	if is_win:
		return "현재 빌드가 이번 런의 보스전까지 통했다는 뜻입니다."
	var scores: Dictionary = main._current_build_scores()
	var primary: String = main._primary_build_tag(scores)
	if primary.is_empty():
		return "초반 탐색 단계에서 런이 종료되었습니다. 다음 런에서 방향을 더 빠르게 고정하세요."
	var meta: Dictionary = main._build_tag_meta().get(primary, {})
	return "이번 런은 %s %s 축을 중심으로 굴렀습니다. 다음에는 보완 카드나 유물을 더 일찍 확보하세요." % [String(meta.get("icon", "")), String(meta.get("name", ""))]
