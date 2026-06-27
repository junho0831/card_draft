extends RefCounted
class_name RewardScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func _is_tight_reward_layout() -> bool:
	return not _is_reward_compact_layout() and main._layout_viewport_size().y <= 760.0

func _is_reward_compact_layout() -> bool:
	return main._is_compact_layout_for(1360.0, 900.0)

func build(body: VBoxContainer) -> void:
	var reward: Dictionary = main.current_run.get("pending_card_reward", {})
	var compact: bool = _is_reward_compact_layout()
	body.add_child(main._make_run_summary_panel())
	body.add_child(main.ui.make_guidance_banner("다음 행동", "카드 1장을 골라 현재 빌드를 강화", Color(0.24, 0.2, 0.12, 1.0), compact))
	var hub: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	hub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub.add_theme_constant_override("separation", 10)
	body.add_child(hub)

	hub.add_child(_make_build_panel(compact))

	var card_panel: PanelContainer = main.ui.make_surface_panel(Color(0.07, 0.08, 0.1, 1.0), Color(0.2, 0.17, 0.11, 1.0), 1, 12, 14)
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_panel.custom_minimum_size = Vector2(0, 330 if compact else 360)
	hub.add_child(card_panel)
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 7)
	card_panel.add_child(card_box)
	var title: Label = main._make_label("카드를 선택하세요", 20 if compact else 24, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card_box.add_child(title)
	var subtitle: Label = main._make_label("추천 카드는 현재 빌드와 가장 잘 맞습니다. 선택한 카드는 즉시 덱에 추가됩니다.", 13 if compact else 14, Color(0.86, 0.9, 0.96, 1.0))
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
	panel.custom_minimum_size = Vector2(0 if compact else 190, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	var title: Label = main._make_label("현재 빌드", 17 if compact else 18, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	var scores: Dictionary = main._current_build_scores()
	var meta: Dictionary = main._build_tag_meta()
	for tag in main._valid_build_tags():
		var tag_meta: Dictionary = meta.get(tag, {})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		var label: Label = main._make_label("%s %s" % [String(tag_meta.get("icon", "")), String(tag_meta.get("name", ""))], 12 if compact else 13, Color(0.88, 0.92, 0.96, 1.0))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var value: Label = main._make_label("%d" % int(scores.get(tag, 0)), 13 if compact else 14, Color(1.0, 0.88, 0.55, 1.0))
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
	box.add_child(HSeparator.new())
	var primary_tag: String = main._primary_build_tag(scores)
	if not primary_tag.is_empty():
		var meta_row: Dictionary = meta.get(primary_tag, {})
		var focus_chip: PanelContainer = main.ui.make_chip("추천 방향: %s %s" % [String(meta_row.get("icon", "")), String(meta_row.get("name", ""))], Color(0.24, 0.18, 0.08, 1.0), Color(1.0, 0.9, 0.58, 1.0), 13 if compact else 14)
		box.add_child(focus_chip)
	var active: Label = main._make_label(main._active_build_text(scores), 13 if compact else 14, Color(1.0, 0.82, 0.5, 1.0))
	active.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(active)
	return panel

func _make_reward_side_panel(reward: Dictionary, compact: bool) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.08, 0.09, 0.11, 0.96), Color(0.22, 0.19, 0.11, 1.0), 1, 12, 14)
	panel.custom_minimum_size = Vector2(0 if compact else 210, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)
	var title: Label = main._make_label("획득 보상", 17 if compact else 18, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	var gold: Label = main._make_label("골드 +%d" % int(reward.get("gold_reward", 0)), 15 if compact else 16, Color(1.0, 0.88, 0.55, 1.0))
	gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(gold)
	var reward_chip: PanelContainer = main.ui.make_chip("카드 3장 중 1장", Color(0.16, 0.18, 0.24, 1.0), Color(0.98, 0.98, 0.94, 1.0), 13 if compact else 14)
	box.add_child(reward_chip)
	if typeof(reward.get("bonus_relic", {})) == TYPE_DICTIONARY and not Dictionary(reward.get("bonus_relic", {})).is_empty():
		var relic: Dictionary = reward["bonus_relic"]
		var relic_label: Label = main._make_label("유물: %s\n%s" % [String(relic.get("name", "")), String(relic.get("text", ""))], 14 if compact else 15, Color(0.9, 0.86, 0.66, 1.0))
		relic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(relic_label)
	box.add_child(HSeparator.new())
	var scores: Dictionary = main._current_build_scores()
	var primary_tag: String = main._primary_build_tag(scores)
	var meta: Dictionary = main._build_tag_meta().get(primary_tag, {})
	var reason_title: Label = main._make_label("추천 기준", 14 if compact else 15, Color(1.0, 0.88, 0.55, 1.0))
	reason_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(reason_title)
	var reason_chip: PanelContainer = main.ui.make_chip("%s %s 시너지 우선" % [String(meta.get("icon", "")), String(meta.get("name", "현재"))], Color(0.24, 0.18, 0.08, 1.0), Color(1.0, 0.9, 0.58, 1.0), 13 if compact else 14)
	box.add_child(reason_chip)
	var reason: Label = main._make_label("%s %s 빌드 점수가 가장 높습니다.\n같은 태그 카드를 고르면 빌드가 더 빨리 활성화됩니다." % [String(meta.get("icon", "")), String(meta.get("name", "현재"))], 12 if compact else 13, Color(0.82, 0.86, 0.92, 1.0))
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(reason)
	var skip_button := Button.new()
	skip_button.text = "건너뛰기"
	skip_button.custom_minimum_size = Vector2(160, 44)
	main.ui.style_button(skip_button, Color(0.16, 0.18, 0.21, 1.0))
	skip_button.pressed.connect(Callable(self, "_skip_card_reward"))
	box.add_child(skip_button)
	return panel

func _make_reward_choice(card: Dictionary) -> Control:
	var compact: bool = _is_reward_compact_layout()
	var tight: bool = _is_tight_reward_layout()
	var primary_tag: String = main._primary_build_tag(main._current_build_scores())
	var matches_primary: bool = main._card_matches_build_tag(card, primary_tag)
	var frame: PanelContainer = main.ui.make_surface_panel(
		Color(0.24, 0.2, 0.12, 1.0) if matches_primary else Color(0.065, 0.07, 0.08, 1.0),
		Color(1.0, 0.78, 0.28, 1.0) if matches_primary else Color(0.38, 0.3, 0.18, 1.0),
		3 if matches_primary else 1,
		9,
		10
	)
	frame.custom_minimum_size = Vector2(178 if tight else (172 if compact else 208), 0)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4 if tight else 5)
	frame.add_child(box)

	if matches_primary:
		var recommend: PanelContainer = main.ui.make_chip("추천 카드", Color(0.58, 0.36, 0.08, 1.0), Color(1.0, 0.94, 0.62, 1.0), 13)
		box.add_child(recommend)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	header.add_child(main.ui.make_cost_badge("%d" % int(card.get("cost", 0)), compact))
	var name_label: Label = main._make_label(String(card.get("name", "")), 13 if tight else (14 if compact else 16), Color(0.98, 0.98, 0.96, 1.0))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(name_label)
	box.add_child(main._make_card_art_rect(card, Vector2(166, 98) if tight else (Vector2(154, 98) if compact else Vector2(196, 124))))
	var type_label: Label = main._make_label("%s / %s / %s" % [main.deck_service.type_name(String(card.get("type", ""))), String(card.get("race", "")), String(card.get("attr", ""))], 11 if tight else 12, Color(0.82, 0.88, 0.95, 1.0))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(type_label)
	var tag_text: String = main._format_card_tag_text(card)
	if not tag_text.is_empty():
		var tag_label: Label = main._make_label(tag_text, 11 if tight else 12, Color(1.0, 0.82, 0.56, 1.0))
		tag_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 1.0))
		tag_label.add_theme_constant_override("outline_size", 2)
		box.add_child(tag_label)
	if matches_primary:
		var synergy_note: Label = main._make_label("현재 빌드와 가장 잘 맞는 선택입니다.", 11 if tight else 12, Color(1.0, 0.9, 0.62, 1.0))
		synergy_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(synergy_note)
	var text_label: Label = main._make_label(String(card.get("text", "")), 11 if tight else 12, Color(0.82, 0.88, 0.95, 1.0))
	text_label.custom_minimum_size = Vector2(0, 28 if tight else 34)
	text_label.clip_text = true
	box.add_child(text_label)
	var button := Button.new()
	button.text = "덱에 추가 ▶" if matches_primary else "선택"
	button.custom_minimum_size = Vector2(120, 36 if tight else 38)
	if matches_primary:
		main.ui.style_primary_button(button, Color(0.52, 0.34, 0.1, 1.0))
	else:
		main.ui.style_button(button, Color(0.18, 0.34, 0.48, 1.0))
	button.pressed.connect(Callable(self, "_claim_card_reward").bind(String(card.get("id", ""))))
	box.add_child(button)
	return frame

func _claim_card_reward(card_id: String) -> void:
	(main.current_run.get("deck_ids", []) as Array).append(card_id)
	_finalize_reward()

func _skip_card_reward() -> void:
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
