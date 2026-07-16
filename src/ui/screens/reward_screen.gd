extends RefCounted
class_name RewardScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func _is_tight_reward_layout() -> bool:
	return not _is_reward_compact_layout() and main._layout_viewport_size().y <= 760.0

func _is_reward_compact_layout() -> bool:
	return main._layout_viewport_size().x < 1100.0

func build(body: VBoxContainer) -> void:
	var reward: Dictionary = main.current_run.get("pending_card_reward", {})
	var compact: bool = _is_reward_compact_layout()
	var tight: bool = _is_tight_reward_layout()
	body.add_child(main._make_run_summary_panel())
	body.add_child(main.ui.make_guidance_banner("다음 행동", "추천 카드 1장만 보고 바로 고르거나 건너뛰세요", Color(0.24, 0.2, 0.12, 1.0), compact))
	var hub: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	hub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub.add_theme_constant_override("separation", 8 if tight else 10)
	body.add_child(hub)

	hub.add_child(_make_build_panel(compact))

	var card_panel: PanelContainer = main.ui.make_surface_panel(Color(0.07, 0.08, 0.1, 1.0), Color(0.2, 0.17, 0.11, 1.0), 1, 12, 14)
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_panel.custom_minimum_size = Vector2(0, 300 if compact else (324 if tight else 340))
	hub.add_child(card_panel)
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 5 if tight else 6)
	card_panel.add_child(card_box)
	var title: Label = main._make_label("카드 1장 선택", 18 if compact else 22, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card_box.add_child(title)
	var subtitle: Label = main._make_label("추천 1장만 보면 됩니다. 선택 즉시 다음 맵으로 넘어갑니다.", 12 if tight else (13 if compact else 14), Color(0.86, 0.9, 0.96, 1.0))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card_box.add_child(subtitle)

	var row: BoxContainer = main.ui.make_responsive_box(compact, 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_box.add_child(row)
	for card_id in reward.get("choices", []):
		if not main.cards_by_id.has(String(card_id)):
			continue
		row.add_child(_make_reward_choice(main.cards_by_id[String(card_id)]))

	hub.add_child(_make_reward_side_panel(reward, compact))

func _make_build_panel(compact: bool) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.08, 0.09, 0.11, 0.96), Color(0.16, 0.18, 0.23, 1.0), 1, 12, 14)
	panel.custom_minimum_size = Vector2(0 if compact else 168, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title: Label = main._make_label("현재 빌드", 16 if compact else 17, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	var scores: Dictionary = main._current_build_scores()
	var meta: Dictionary = main._build_tag_meta()
	var compact_grid: GridContainer = null
	if compact:
		compact_grid = GridContainer.new()
		compact_grid.columns = 3
		compact_grid.add_theme_constant_override("h_separation", 6)
		compact_grid.add_theme_constant_override("v_separation", 6)
		compact_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(compact_grid)
	for tag in main._valid_build_tags():
		var tag_meta: Dictionary = meta.get(tag, {})
		if compact:
			var tag_color: Color = tag_meta.get("color", Color(0.16, 0.18, 0.22, 1.0))
			var compact_chip: PanelContainer = main.ui.make_chip(
				"%s %s  %d" % [String(tag_meta.get("icon", "")), String(tag_meta.get("name", "")), int(scores.get(tag, 0))],
				tag_color.darkened(0.5),
				Color(0.9, 0.94, 1.0, 1.0),
				11
			)
			compact_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			compact_grid.add_child(compact_chip)
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		var label: Label = main._make_label("%s %s" % [String(tag_meta.get("icon", "")), String(tag_meta.get("name", ""))], 11 if compact else 12, Color(0.88, 0.92, 0.96, 1.0))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var value: Label = main._make_label("%d" % int(scores.get(tag, 0)), 12 if compact else 13, Color(1.0, 0.88, 0.55, 1.0))
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
	box.add_child(HSeparator.new())
	var primary_tag: String = main._primary_build_tag(scores)
	if not primary_tag.is_empty():
		var meta_row: Dictionary = meta.get(primary_tag, {})
		var focus_chip: PanelContainer = main.ui.make_chip("추천 방향: %s %s" % [String(meta_row.get("icon", "")), String(meta_row.get("name", ""))], Color(0.24, 0.18, 0.08, 1.0), Color(1.0, 0.9, 0.58, 1.0), 12 if compact else 13)
		box.add_child(focus_chip)
	var active: Label = main._make_label(main._active_build_text(scores), 12 if compact else 13, Color(1.0, 0.82, 0.5, 1.0))
	active.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(active)
	return panel

func _make_reward_side_panel(reward: Dictionary, compact: bool) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.08, 0.09, 0.11, 0.96), Color(0.22, 0.19, 0.11, 1.0), 1, 12, 14)
	panel.custom_minimum_size = Vector2(0 if compact else 192, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	var title: Label = main._make_label("획득 보상", 16 if compact else 17, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	var gold: Label = main._make_label("골드 +%d" % int(reward.get("gold_reward", 0)), 14 if compact else 15, Color(1.0, 0.88, 0.55, 1.0))
	gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(gold)
	var choice_count := (reward.get("choices", []) as Array).size()
	var reward_chip: PanelContainer = main.ui.make_chip("카드 %d장 중 1장" % choice_count, Color(0.16, 0.18, 0.24, 1.0), Color(0.98, 0.98, 0.94, 1.0), 12 if compact else 13)
	box.add_child(reward_chip)
	if typeof(reward.get("bonus_relic", {})) == TYPE_DICTIONARY and not Dictionary(reward.get("bonus_relic", {})).is_empty():
		var relic: Dictionary = reward["bonus_relic"]
		box.add_child(main.ui.make_relic_badge(relic, compact))
		var relic_text: Label = main._make_label(String(relic.get("text", "")), 11 if compact else 12, Color(0.9, 0.86, 0.98, 1.0))
		relic_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(relic_text)
	box.add_child(HSeparator.new())
	var scores: Dictionary = main._current_build_scores()
	var primary_tag: String = main._primary_build_tag(scores)
	var meta: Dictionary = main._build_tag_meta().get(primary_tag, {})
	var reason_title: Label = main._make_label("추천 기준", 13 if compact else 14, Color(1.0, 0.88, 0.55, 1.0))
	reason_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(reason_title)
	var reason_chip: PanelContainer = main.ui.make_chip("현재 빌드 우선", Color(0.24, 0.18, 0.08, 1.0), Color(1.0, 0.9, 0.58, 1.0), 12 if compact else 13)
	box.add_child(reason_chip)
	var reason: Label = main._make_label("%s %s 축에 가장 잘 맞습니다.\n애매하면 건너뛰어 덱을 얇게 유지하세요." % [String(meta.get("icon", "")), String(meta.get("name", "현재"))], 11 if compact else 12, Color(0.82, 0.86, 0.92, 1.0))
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(reason)
	var skip_chip: PanelContainer = main.ui.make_chip("선택 안 해도 됨", Color(0.12, 0.14, 0.18, 1.0), Color(0.9, 0.94, 1.0, 1.0), 11 if compact else 12)
	box.add_child(skip_chip)
	var skip_button := Button.new()
	skip_button.text = "건너뛰기"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.custom_minimum_size = Vector2(132 if compact else 142, 34 if compact else 36)
	main.ui.style_button(skip_button, Color(0.16, 0.18, 0.21, 1.0))
	skip_button.add_theme_font_size_override("font_size", 13)
	skip_button.pressed.connect(Callable(self, "_skip_card_reward"))
	box.add_child(skip_button)
	return panel

func _reward_choice_reason(card: Dictionary, matches_primary: bool) -> String:
	if matches_primary:
		return main._choice_playstyle_text(card)
	var impact: String = main._choice_impact_text(card)
	if impact.contains("바로 활성") or impact.contains("연계 카드"):
		return impact
	var card_type := String(card.get("type", ""))
	var card_id := String(card.get("id", "")).trim_suffix("_plus")
	if card_type == "unit":
		return "즉시 전투 도움"
	if card_type == "equipment":
		return "아군 강화"
	if card_id in ["small_flame", "fireball", "gale_shot", "corpse_explosion", "plague_spread", "vampiric_strike"]:
		return "즉시 전투 도움"
	if card_id in ["first_aid", "healing_potion", "moonwell", "nature_blessing", "battlecry", "captain_order"]:
		return "아군 강화"
	return "덱 압축 후보"

func _reward_growth_summary(card: Dictionary) -> Dictionary:
	return main._build_delta_summary(card)

func _make_reward_choice(card: Dictionary) -> Control:
	var compact: bool = _is_reward_compact_layout()
	var tight: bool = _is_tight_reward_layout()
	var primary_tag: String = main._primary_build_tag(main._current_build_scores())
	var matches_primary: bool = main._card_matches_build_tag(card, primary_tag)
	var matches_race: bool = main._card_matches_current_race(card)
	var race_meta: Dictionary = main._current_race_meta()
	var race_color: Color = race_meta.get("color", Color(0.42, 0.68, 1.0, 1.0))
	var reason_text := _reward_choice_reason(card, matches_primary)
	var growth: Dictionary = _reward_growth_summary(card)
	var growth_plain_text: String = main._plain_build_delta_text(card)
	var impact_text: String = main._choice_impact_text(card)
	var frame: PanelContainer = main.ui.make_surface_panel(
		Color(0.06, 0.085, 0.13, 1.0) if matches_primary else Color(0.055, 0.072, 0.08, 1.0) if matches_race else Color(0.055, 0.065, 0.082, 1.0),
		Color(0.44, 0.7, 1.0, 1.0) if matches_primary else race_color if matches_race else Color(0.24, 0.3, 0.38, 1.0),
		2 if matches_primary or matches_race else 1,
		9,
		10
	)
	frame.custom_minimum_size = Vector2(188 if tight else (160 if compact else 188), 0)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3 if tight else 4)
	frame.add_child(box)

	if matches_primary:
		var recommend: PanelContainer = main.ui.make_chip("추천", Color(0.1, 0.28, 0.56, 1.0), Color(0.82, 0.92, 1.0, 1.0), 12)
		box.add_child(recommend)
	if matches_race:
		var race_badge: PanelContainer = main.ui.make_chip("%s 세력 연계" % String(race_meta.get("name", "현재")), race_color.darkened(0.58), race_color.lightened(0.3), 11 if tight else 12)
		box.add_child(race_badge)
	var reason_badge: PanelContainer = main.ui.make_chip(reason_text, Color(0.12, 0.18, 0.24, 1.0) if not matches_primary else Color(0.1, 0.2, 0.36, 1.0), Color(0.9, 0.96, 1.0, 1.0), 11 if tight else 12)
	box.add_child(reason_badge)
	var impact_badge: PanelContainer = main.ui.make_chip(
		impact_text,
		Color(0.18, 0.13, 0.24, 1.0) if impact_text.contains("활성") else Color(0.1, 0.15, 0.2, 1.0),
		Color(1.0, 0.84, 0.58, 1.0) if impact_text.contains("활성") else Color(0.82, 0.92, 1.0, 1.0),
		10 if tight else 11
	)
	box.add_child(impact_badge)
	var growth_headline := String(growth.get("headline", ""))
	if not growth_headline.is_empty():
		var growth_chip: PanelContainer = main.ui.make_chip(
			"%s  |  %s" % [growth_headline, main._choice_playstyle_text(card)],
			Color(0.12, 0.22, 0.18, 1.0) if bool(growth.get("will_activate", false)) else Color(0.12, 0.14, 0.22, 1.0),
			Color(0.72, 1.0, 0.82, 1.0) if bool(growth.get("will_activate", false)) else Color(0.86, 0.94, 1.0, 1.0),
			10 if tight else 11
		)
		box.add_child(growth_chip)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	header.add_child(main.ui.make_cost_badge("%d" % int(card.get("cost", 0)), compact))
	var name_label: Label = main._make_label(String(card.get("name", "")), 12 if tight else (13 if compact else 15), Color(0.98, 0.98, 0.96, 1.0))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(name_label)
	box.add_child(main._make_card_art_rect(card, Vector2(176, 108) if tight else (Vector2(142, 86) if compact else Vector2(176, 106))))
	var type_label: Label = main._make_label("%s / %s / %s" % [main.deck_service.type_name(String(card.get("type", ""))), String(card.get("race", "")), String(card.get("attr", ""))], 10 if tight else 11, Color(0.82, 0.88, 0.95, 1.0))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(type_label)
	var tag_text: String = main._format_card_tag_text(card)
	if not tag_text.is_empty():
		var tag_label: Label = main._make_label(tag_text, 10 if tight else 11, Color(1.0, 0.82, 0.56, 1.0))
		tag_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 1.0))
		tag_label.add_theme_constant_override("outline_size", 2)
		box.add_child(tag_label)
	var growth_detail := String(growth.get("detail", ""))
	if not growth_detail.is_empty():
		var growth_label: Label = main._make_label(growth_detail, 10 if tight else 11, Color(0.74, 0.92, 0.82, 1.0) if bool(growth.get("will_activate", false)) else Color(0.78, 0.84, 0.92, 1.0))
		growth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(growth_label)
	var summary_label: Label = main._make_label(main._card_effect_summary(card), 11 if tight else 12, Color(0.98, 0.96, 0.84, 1.0))
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.ui.style_card_rules(summary_label, tight, false)
	box.add_child(summary_label)
	if not growth_plain_text.is_empty():
		var plain_label: Label = main._make_label(growth_plain_text, 10 if tight else 11, Color(0.9, 0.94, 0.98, 1.0))
		plain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(plain_label)
	var tag := String(growth.get("primary_tag", ""))
	if not tag.is_empty():
		var effect_label: Label = main._make_label(main._build_activation_effect_text(tag), 10 if tight else 11, Color(1.0, 0.84, 0.62, 1.0))
		effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		main.ui.style_card_rules(effect_label, true, false)
		box.add_child(effect_label)
	var text_label: Label = main._make_label(String(card.get("text", "")), 11 if tight else 11, Color(0.82, 0.88, 0.95, 1.0))
	text_label.custom_minimum_size = Vector2(0, 34 if tight else 24)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.modulate = Color(0.82, 0.88, 0.95, 0.78)
	main.ui.style_card_rules(text_label, true, true)
	box.add_child(text_label)
	var button := Button.new()
	button.text = "덱에 추가 ▶" if matches_primary else "선택"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(98 if tight else (96 if compact else 110), 30 if tight else 32)
	if matches_primary:
		main.ui.style_primary_button(button, Color(0.12, 0.32, 0.66, 1.0))
	else:
		main.ui.style_button(button, Color(0.18, 0.34, 0.48, 1.0))
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(Callable(self, "_claim_card_reward").bind(String(card.get("id", ""))))
	box.add_child(button)
	return frame

func _claim_card_reward(card_id: String) -> void:
	if main.audio_manager != null:
		main.audio_manager.play_sound("click")
	(main.current_run.get("deck_ids", []) as Array).append(card_id)
	_finalize_reward()

func _skip_card_reward() -> void:
	if main.audio_manager != null:
		main.audio_manager.play_sound("click")
	_finalize_reward()

func _finalize_reward() -> void:
	var reward: Dictionary = main.current_run.get("pending_card_reward", {})
	var bonus_relic: Dictionary = reward.get("bonus_relic", {})
	if not bonus_relic.is_empty():
		var relic_id := String(bonus_relic.get("id", ""))
		(main.current_run.get("relic_ids", []) as Array).append(relic_id)
		main.relic_service.apply_on_acquire(main.current_run, relic_id)
	var pending_keys: Array[String] = ["pending_card_reward"]
	main.run_flow.advance_from_current_node(pending_keys)
