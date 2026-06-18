extends RefCounted
class_name RunResultScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer, is_win: bool) -> void:
	var compact: bool = main._is_compact_layout()
	var scores: Dictionary = main._current_build_scores()
	var primary_tag: String = main._primary_build_tag(scores)
	var tag_meta: Dictionary = main._build_tag_meta().get(primary_tag, {})
	var hub: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	hub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub.add_theme_constant_override("separation", 10)
	body.add_child(hub)

	var hero_panel: PanelContainer = main.ui.make_surface_panel(Color(0.06, 0.07, 0.09, 1.0), Color(0.2, 0.17, 0.11, 1.0), 1, 14, 16)
	hero_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_panel.custom_minimum_size = Vector2(0, 310 if compact else 390)
	hub.add_child(hero_panel)
	var hero_box := VBoxContainer.new()
	hero_box.add_theme_constant_override("separation", 8)
	hero_panel.add_child(hero_box)
	hero_box.add_child(main._make_label("런 종료", 13 if compact else 14, Color(1.0, 0.86, 0.48, 1.0)))
	var result_banner: PanelContainer = main.ui.make_chip("런 %s" % ("클리어" if is_win else "패배"), Color(0.18, 0.3, 0.18, 1.0) if is_win else Color(0.36, 0.14, 0.14, 1.0), Color(1.0, 0.96, 0.88, 1.0), 13 if compact else 14)
	hero_box.add_child(result_banner)
	hero_box.add_child(main._make_art_rect(8 if is_win else 11, Vector2(260, 190) if compact else Vector2(340, 250)))
	hero_box.add_child(main._make_label("승리!" if is_win else "패배", 30 if compact else 38, Color(1.0, 0.88, 0.55, 1.0) if is_win else Color(1.0, 0.68, 0.62, 1.0)))
	hero_box.add_child(main._make_label("이번 런의 최종 빌드와 보상을 확인하세요.", 13 if compact else 15, Color(0.86, 0.9, 0.96, 1.0)))
	var hero_result_panel: PanelContainer = main.ui.make_objective_panel("런 평가", _run_result_headline(is_win), compact)
	hero_box.add_child(hero_result_panel)
	var hero_chips: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	hero_chips.add_theme_constant_override("separation", 8)
	hero_box.add_child(hero_chips)
	hero_chips.add_child(main.ui.make_chip("최종 Act %d" % int(main.current_run.get("act", 1)), Color(0.14, 0.22, 0.34, 1.0), Color(0.86, 0.92, 1.0, 1.0), 13 if compact else 14))
	hero_chips.add_child(main.ui.make_chip("%s %s" % [String(tag_meta.get("icon", "")), String(tag_meta.get("name", "빌드"))], Color(0.32, 0.22, 0.08, 1.0), Color(1.0, 0.88, 0.55, 1.0), 13 if compact else 14))
	var hero_metrics: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	hero_metrics.add_theme_constant_override("separation", 8)
	hero_box.add_child(hero_metrics)
	hero_metrics.add_child(main.ui.make_stat_tile("덱", str((main.current_run.get("deck_ids", []) as Array).size()), Color(0.14, 0.18, 0.24, 1.0), compact))
	hero_metrics.add_child(main.ui.make_stat_tile("유물", str((main.current_run.get("relic_ids", []) as Array).size()), Color(0.2, 0.16, 0.28, 1.0), compact))
	hero_metrics.add_child(main.ui.make_stat_tile("영혼석", str(int(main.current_run.get("earned_soul_stones", 0))), Color(0.18, 0.14, 0.3, 1.0), compact))

	var summary_panel: PanelContainer = main.ui.make_surface_panel(Color(0.08, 0.09, 0.11, 0.96), Color(0.22, 0.19, 0.11, 1.0), 1, 12, 16)
	summary_panel.custom_minimum_size = Vector2(0 if compact else 320, 0)
	hub.add_child(summary_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	summary_panel.add_child(box)
	box.add_child(main._make_label("런 정보", 18 if compact else 20, Color(1.0, 0.88, 0.55, 1.0)))
	var metric_row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	metric_row.add_theme_constant_override("separation", 6)
	box.add_child(metric_row)
	metric_row.add_child(main.ui.make_chip("Act %d" % int(main.current_run.get("act", 1)), Color(0.12, 0.22, 0.34, 1.0), Color(0.86, 0.92, 1.0, 1.0), 13 if compact else 14))
	metric_row.add_child(main.ui.make_chip("덱 %d" % (main.current_run.get("deck_ids", []) as Array).size(), Color(0.12, 0.18, 0.28, 1.0), Color(0.86, 0.92, 1.0, 1.0), 13 if compact else 14))
	metric_row.add_child(main.ui.make_chip("유물 %d" % (main.current_run.get("relic_ids", []) as Array).size(), Color(0.22, 0.16, 0.32, 1.0), Color(0.92, 0.84, 1.0, 1.0), 13 if compact else 14))
	box.add_child(HSeparator.new())
	box.add_child(main._make_label("런 정보", 16 if compact else 18, Color(1.0, 0.88, 0.55, 1.0)))
	var run_info_grid: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	run_info_grid.add_theme_constant_override("separation", 6)
	box.add_child(run_info_grid)
	run_info_grid.add_child(main.ui.make_stat_tile("플레이 시간", _format_run_duration(), Color(0.14, 0.18, 0.24, 1.0), compact))
	run_info_grid.add_child(main.ui.make_stat_tile("처치한 적", "%d" % int(main.current_run.get("enemies_defeated", 0)), Color(0.22, 0.13, 0.12, 1.0), compact))
	var run_info_grid_2: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	run_info_grid_2.add_theme_constant_override("separation", 6)
	box.add_child(run_info_grid_2)
	run_info_grid_2.add_child(main.ui.make_stat_tile("획득 골드", "%d" % int(main.current_run.get("gold_earned", 0)), Color(0.32, 0.24, 0.08, 1.0), compact))
	run_info_grid_2.add_child(main.ui.make_stat_tile("방문 노드", "%d" % (main.current_run.get("visited_nodes", []) as Array).size(), Color(0.12, 0.2, 0.24, 1.0), compact))
	box.add_child(HSeparator.new())
	box.add_child(main._make_label("핵심 결과", 16 if compact else 18, Color(1.0, 0.88, 0.55, 1.0)))
	box.add_child(main.ui.make_chip("상태: %s" % ("클리어" if is_win else "실패"), Color(0.18, 0.3, 0.18, 1.0) if is_win else Color(0.36, 0.14, 0.14, 1.0), Color(1.0, 0.96, 0.88, 1.0), 13 if compact else 14))
	box.add_child(main._make_label(_run_result_headline(is_win), 13 if compact else 14, Color(0.86, 0.9, 0.96, 1.0)))
	box.add_child(main._make_label("획득 보상", 17 if compact else 19, Color(1.0, 0.88, 0.55, 1.0)))
	box.add_child(main.ui.make_chip("카드 %d장  |  유물 %d개  |  골드 +%d" % [
		(main.current_run.get("deck_ids", []) as Array).size(),
		(main.current_run.get("relic_ids", []) as Array).size(),
		int(main.current_run.get("gold_earned", 0)),
	], Color(0.16, 0.18, 0.24, 1.0), Color(0.92, 0.96, 1.0, 1.0), 13 if compact else 14))
	box.add_child(main.ui.make_chip("영혼석 +%d  |  보유 %d" % [int(main.current_run.get("earned_soul_stones", 0)), int(main.player_profile.get("soul_stones", 0))], Color(0.22, 0.16, 0.34, 1.0), Color(0.9, 0.78, 1.0, 1.0), 13 if compact else 14))
	var reward_hint: Label = main._make_label("이번 런의 핵심 성과가 메타 진행에 바로 반영됩니다.", 13 if compact else 14, Color(0.84, 0.88, 0.94, 1.0))
	reward_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(reward_hint)
	box.add_child(HSeparator.new())
	box.add_child(main._make_label("최종 빌드", 17 if compact else 19, Color(1.0, 0.88, 0.55, 1.0)))
	var build_text: String = main._build_status_text(scores).replace("현재 빌드  ", "")
	box.add_child(main._make_label(build_text, 12 if compact else 13, Color(0.86, 0.9, 0.96, 1.0)))
	box.add_child(main._make_label(main._active_build_text(scores), 13 if compact else 14, Color(1.0, 0.82, 0.5, 1.0)))
	box.add_child(main.ui.make_chip("주요 카드: %s  |  주요 유물: %s" % [_run_key_card_name(primary_tag), _run_key_relic_name(primary_tag)], Color(0.12, 0.16, 0.2, 1.0), Color(0.86, 0.92, 1.0, 1.0), 12 if compact else 13))
	var build_chip_row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	build_chip_row.add_theme_constant_override("separation", 6)
	box.add_child(build_chip_row)
	for tag in main._valid_build_tags():
		var meta: Dictionary = main._build_tag_meta().get(tag, {})
		build_chip_row.add_child(main.ui.make_chip("%s %d" % [String(meta.get("icon", "")), int(scores.get(tag, 0))], Color(0.14, 0.16, 0.2, 1.0), Color(0.88, 0.92, 0.98, 1.0), 12 if compact else 13))
	box.add_child(HSeparator.new())
	box.add_child(main._make_label("다음 행동", 16 if compact else 18, Color(1.0, 0.88, 0.55, 1.0)))
	var actions: BoxContainer = main.ui.make_action_bar(compact, 10)
	box.add_child(actions)
	main._add_menu_button(actions, "메인 메뉴", "_return_to_main_after_run", Color(0.22, 0.24, 0.28, 1.0))
	main._add_menu_button(actions, "새로운 런", "_start_new_run", Color(0.55, 0.36, 0.1, 1.0))

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
