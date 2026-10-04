extends RefCounted
class_name RewardScreen

const ButtonMetrics = preload("res://src/ui/styles/button_metrics.gd")
const Fantasy = preload("res://src/ui/fantasy_components.gd")
const EconomyDetail = preload("res://src/ui/components/economy_detail_view.gd")
var detail_overlay: Control
var selected_card_id := ""
var reference_cards: Dictionary = {}
var reference_claim: Button
var reference_reason: Label
var reference_comparison: Control
var main: Node
var screen_action_dock: PanelContainer = null

func _init(_main: Node) -> void:
	main = _main

func _is_tight_reward_layout() -> bool:
	return not _is_reward_compact_layout() and main._layout_viewport_size().y <= 760.0

func _is_reward_compact_layout() -> bool:
	return main._layout_viewport_size().x < 1100.0

func build(body: VBoxContainer) -> void:
	_build_reference_reward(body)

func _mount_reward_action_dock(body: VBoxContainer, reward: Dictionary) -> void:
	var card: Dictionary = _recommended_reward_card(reward)
	if card.is_empty():
		return
	var reason: String = _reward_choice_reason(card, true)
	var impact: String = main._choice_impact_text(card)
	if main._lesson_stage() < 5:
		reason = "다음 전투에서 아군을 골라 사용하세요" if bool(reward.get("lesson_equipment", false)) else "다음 전투에 쓸 카드 한 장을 고르세요"
		impact = String(card.get("text", ""))
	var dock: Dictionary = main.ui.mount_screen_action_dock(
		main,
		body,
		("추천 카드 · %s" if main._lesson_stage() < 5 else "주력 강화 · %s") % String(card.get("name", "추천 카드")),
		"%s · %s · 골드 +%d" % [reason, impact, int(reward.get("gold_reward", 0))],
		Color(0.42, 0.68, 1.0, 1.0),
		126
	)
	screen_action_dock = dock.get("panel") as PanelContainer
	var actions: BoxContainer = dock.get("actions") as BoxContainer
	var claim_button: Button = main.ui.make_dock_action_button("카드 받기", String(card.get("name", "카드")), Color(0.18, 0.42, 0.72, 1.0), true, 224)
	claim_button.disabled = not _relic_choice_ready(reward)
	claim_button.pressed.connect(Callable(self, "_claim_card_reward").bind(String(card.get("id", ""))))
	actions.add_child(claim_button)
	var skip_button: Button = main.ui.make_dock_action_button("건너뛰기", "덱을 얇게 유지", Color(0.18, 0.22, 0.28, 1.0), false, 144)
	skip_button.disabled = not _relic_choice_ready(reward)
	if bool(reward.get("lesson_equipment", false)):
		skip_button.text = "추천 장비 받기"
	skip_button.pressed.connect(Callable(self, "_skip_card_reward"))
	actions.add_child(skip_button)

func _recommended_reward_card(reward: Dictionary) -> Dictionary:
	var fallback: Dictionary = {}
	var primary_tag: String = main._primary_build_tag(main._current_build_scores())
	for card_id_variant in reward.get("choices", []):
		var card_id := String(card_id_variant)
		if not main.cards_by_id.has(card_id):
			continue
		var card: Dictionary = main.cards_by_id[card_id]
		if fallback.is_empty():
			fallback = card
		if main._card_matches_build_tag(card, primary_tag):
			return card
	return fallback

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
	var reason_chip: PanelContainer = main.ui.make_chip("세 가지 성장 방향", Color(0.24, 0.18, 0.08, 1.0), Color(1.0, 0.9, 0.58, 1.0), 12 if compact else 13)
	box.add_child(reason_chip)
	var reason: Label = main._make_label("%s %s 주력 강화, 보조 연계, 새로운 방향을 비교하세요.\n건너뛰면 덱을 얇게 유지합니다." % [String(meta.get("icon", "")), String(meta.get("name", "현재"))], 11 if compact else 12, Color(0.82, 0.86, 0.92, 1.0))
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(reason)
	var skip_chip: PanelContainer = main.ui.make_chip("선택 안 해도 됨", Color(0.12, 0.14, 0.18, 1.0), Color(0.9, 0.94, 1.0, 1.0), 11 if compact else 12)
	box.add_child(skip_chip)
	var skip_button := Button.new()
	skip_button.text = "건너뛰기"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.custom_minimum_size.x = 132 if compact else 142
	main.ui.style_button(skip_button, Color(0.16, 0.18, 0.21, 1.0))
	ButtonMetrics.apply(skip_button)
	skip_button.disabled = not _relic_choice_ready(reward)
	skip_button.pressed.connect(Callable(self, "_skip_card_reward"))
	box.add_child(skip_button)
	return panel

func _reward_choice_reason(card: Dictionary, matches_primary: bool) -> String:
	if main._lesson_stage() < 5:
		return "아군 한 명을 골라 장착" if String(card.get("type", "")) == "equipment" else "카드 효과를 보고 골라보세요"
	if matches_primary:
		return main._choice_playstyle_text(card)
	if String(card.get("race", "")) == "중립":
		return "어느 세력에도 활용"
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
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", main.ui.make_race_card_style(card, Color(0.035, 0.05, 0.07, 0.94), 2, 8, 0.12, Color(0.94, 0.72, 0.3) if matches_primary else Color.TRANSPARENT))
	main.ui.decorate_card_frame(frame, card)
	frame.custom_minimum_size = Vector2(188, 0)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.tooltip_text = main._card_economy_comparison_text(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	frame.add_child(box)
	var role: Label = main._make_label(_card_choice_role(String(card.get("id", ""))), 13, Color(1.0, 0.83, 0.48))
	box.add_child(role)
	box.add_child(main.ui.make_card_header(main, card, "reward", compact, tight, int(card.get("cost", 0))))
	box.add_child(main.ui.make_card_art(main, card, Vector2(180, 156)))
	box.add_child(main.ui.make_card_identity_label(main, card, "reward", compact, tight, false, true))
	box.add_child(main.ui.make_card_rules_block(main, card, main._card_effect_summary(card), "", "reward", compact, tight, 40.0))
	var reason: Label = main._make_label(_reward_choice_reason(card, matches_primary), 13, Color(0.78, 0.86, 0.93))
	reason.custom_minimum_size.y = 36
	box.add_child(reason)
	var inspect := Fantasy.action(main, "덱 변화 보기", _show_card_comparison.bind(String(card.get("id", ""))), false)
	inspect.name = "EconomyInspect_" + String(card.get("id", ""))
	ButtonMetrics.apply(inspect)
	box.add_child(inspect)
	var button := Button.new()
	button.text = "덱에 추가 ▶" if matches_primary else "선택"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.x = 120
	if matches_primary:
		main.ui.style_role_button(button, "primary", Color(0.96, 0.74, 0.3, 1.0), Color(0.24, 0.18, 0.07, 1.0), 14)
	else:
		main.ui.style_role_button(button, "secondary", Color(0.42, 0.62, 0.82, 1.0), Color(0.12, 0.2, 0.3, 1.0), 12)
	ButtonMetrics.apply(button)
	button.disabled = not _relic_choice_ready(main.current_run.get("pending_card_reward", {}))
	button.pressed.connect(Callable(self, "_claim_card_reward").bind(String(card.get("id", ""))))
	box.add_child(button)
	return frame

func _has_relic_choice(reward: Dictionary) -> bool:
	return not (reward.get("relic_choices", []) as Array).is_empty()

func _selected_reward_relic(reward: Dictionary) -> Dictionary:
	var choices: Array = reward.get("relic_choices", [])
	if choices.is_empty():
		return Dictionary(reward.get("bonus_relic", {}))
	if choices.size() == 1:
		return Dictionary(choices[0])
	var selected_id := String(reward.get("selected_relic_id", ""))
	for relic_variant in choices:
		var relic: Dictionary = relic_variant
		if String(relic.get("id", "")) == selected_id:
			return relic
	return {}

func _relic_choice_ready(reward: Dictionary) -> bool:
	return not _has_relic_choice(reward) or not _selected_reward_relic(reward).is_empty()

func _select_relic_reward(relic_id: String) -> void:
	var reward: Dictionary = main.current_run.get("pending_card_reward", {})
	for relic_variant in reward.get("relic_choices", []):
		if String(Dictionary(relic_variant).get("id", "")) == relic_id:
			reward["selected_relic_id"] = relic_id
			main.current_run["pending_card_reward"] = reward
			main._save_run()
			main._show_card_reward()
			return

func _make_relic_choices(reward: Dictionary, compact: bool) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(EconomyDetail.Tokens.SURFACE, EconomyDetail.Tokens.BORDER, 1, 8, 8)
	panel.name = "EconomyRelicChoices"
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var selected: Dictionary = _selected_reward_relic(reward)
	for relic_variant in reward.get("relic_choices", []):
		var relic: Dictionary = relic_variant
		var id := String(relic.get("id", ""))
		var chosen := String(selected.get("id", "")) == id
		var button := EconomyDetail.action_button(main, String(relic.get("name", "유물")), _show_relic_comparison.bind(relic))
		button.name = "RelicChoice_" + id
		button.tooltip_text = String(relic.get("text", ""))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main.ui.style_role_button(button, "primary" if chosen else "secondary", EconomyDetail.Tokens.ACCENT_GOLD if chosen else EconomyDetail.Tokens.BORDER, EconomyDetail.Tokens.SURFACE_RAISED, 14)
		ButtonMetrics.apply(button, "compact", button.custom_minimum_size.x)
		row.add_child(button)
	return panel

func _show_relic_comparison(relic: Dictionary) -> void:
	_close_card_comparison()
	detail_overlay = EconomyDetail.show_relic(main, relic, _select_relic_reward.bind(String(relic.get("id", ""))), _close_card_comparison)

func _card_choice_role(card_id: String) -> String:
	if bool(Dictionary(main.current_run.get("pending_card_reward", {})).get("lesson_equipment", false)):
		return "아군 한 명 강화 · 다음 전투에서 사용"
	var reward: Dictionary = main.current_run.get("pending_card_reward", {})
	var index := (reward.get("choices", []) as Array).find(card_id)
	if String(reward.get("battle_tier", "")) == "boss":
		return ["보스 영입", "주력 강화", "보조 연계"][clampi(index, 0, 2)]
	return ["주력 강화", "보조 연계", "새로운 방향"][clampi(index, 0, 2)]

func _claim_card_reward(card_id: String) -> void:
	var reward: Dictionary = main.current_run.get("pending_card_reward", {})
	if reward.is_empty() or not (reward.get("choices", []) as Array).has(card_id) or not main.cards_by_id.has(card_id) or not _relic_choice_ready(reward):
		return
	if main.audio_manager != null:
		main.audio_manager.play_sound("click")
	(main.current_run.get("deck_ids", []) as Array).append(card_id)
	if bool(reward.get("lesson_equipment", false)):
		main.current_run["lesson_equipment_id"] = card_id
	_finalize_reward()

func _skip_card_reward() -> void:
	if bool(Dictionary(main.current_run.get("pending_card_reward", {})).get("lesson_equipment", false)):
		_claim_card_reward("training_sword")
		return
	var reward: Dictionary = main.current_run.get("pending_card_reward", {})
	if reward.is_empty() or not _relic_choice_ready(reward):
		return
	if main.audio_manager != null:
		main.audio_manager.play_sound("click")
	_finalize_reward()

func _finalize_reward() -> void:
	var reward: Dictionary = main.current_run.get("pending_card_reward", {})
	if reward.is_empty() or not _relic_choice_ready(reward):
		return
	var relic := _selected_reward_relic(reward)
	if not relic.is_empty():
		var relic_id := String(relic.get("id", ""))
		var owned: Array = main.current_run.get("relic_ids", [])
		if not owned.has(relic_id):
			owned.append(relic_id)
			main.current_run["relic_ids"] = owned
			main.relic_service.apply_on_acquire(main.current_run, relic_id)
	var pending_keys: Array[String] = ["pending_card_reward"]
	main.run_flow.advance_from_current_node(pending_keys)

func _build_reference_reward(body: VBoxContainer) -> void:
	var reward: Dictionary = main.current_run.get("pending_card_reward", {})
	var desktop: bool = main._layout_viewport_size().x >= 1100
	body.add_theme_constant_override("separation", 8)
	var resources := HBoxContainer.new()
	resources.add_theme_constant_override("separation", 8)
	body.add_child(resources)
	if _has_relic_choice(reward):
		var relic_choices := _make_relic_choices(reward, true)
		relic_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resources.add_child(relic_choices)
	var gold := EconomyDetail.comparison_label(main, ("전투 승리   ·   골드 +%d" if desktop else "골드 +%d") % int(reward.get("gold_reward", 0)), EconomyDetail.TEXT, 20 if desktop else 14)
	gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold.tooltip_text = main._lesson_description()
	resources.add_child(gold)
	if desktop and not main._lesson_description().is_empty():
		body.add_child(EconomyDetail.comparison_label(main, main._lesson_description(), EconomyDetail.MUTED, 14))
	if not _has_relic_choice(reward) and not _selected_reward_relic(reward).is_empty():
		body.add_child(main.ui.make_relic_badge(_selected_reward_relic(reward), true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	body.add_child(row)
	var recommended := _recommended_reward_card(reward)
	selected_card_id = String(recommended.get("id", ""))
	var cards := HBoxContainer.new()
	cards.name = "EconomyOffers"
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 12)
	row.add_child(cards)
	for id in reward.get("choices", []):
		var card: Dictionary = main.card_db.get_card(String(id))
		if card.is_empty():
			continue
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 6)
		cards.add_child(stack)
		stack.add_child(EconomyDetail.comparison_label(main, _card_choice_role(String(id)), EconomyDetail.MUTED, 14))
		var reserved_height := 238 if _has_relic_choice(reward) else 206
		var face := EconomyDetail.offer_face(main, card, 208 if desktop else 180, 320 if desktop else int(clampf(main._layout_viewport_size().y - reserved_height, 120, 300)), not desktop)
		face.name = "EconomyOffer_" + String(id)
		stack.add_child(face)
		reference_cards[String(id)] = face
		var inspect := _select_reference_reward.bind(String(id)) if desktop else _inspect_reference_reward.bind(String(id))
		Fantasy.clickable_card(face, inspect)
		if desktop:
			var pick := EconomyDetail.action_button(main, "카드 확인", inspect)
			pick.name = "EconomyInspect_" + String(id)
			stack.add_child(pick)
	var details := EconomyDetail.section(main, "덱 변화", 290 if desktop else 0)
	details.visible = desktop
	row.add_child(details)
	var detail_content := EconomyDetail.add_scroll(details, 180 if desktop else 0)
	reference_reason = EconomyDetail.comparison_label(main, "", EconomyDetail.TEXT, 16)
	reference_reason.name = "EconomyCardRole"
	detail_content.add_child(reference_reason)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	body.add_child(footer)
	footer.add_child(EconomyDetail.action_button(main, "덱 보기", Callable(main, "_show_collection")))
	var skip := EconomyDetail.action_button(main, "추천 장비 받기" if bool(reward.get("lesson_equipment", false)) else "건너뛰기", _skip_card_reward)
	skip.disabled = not _relic_choice_ready(reward)
	footer.add_child(skip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	reference_claim = EconomyDetail.action_button(main, "선택한 카드 받기", _claim_reference_reward, true)
	reference_claim.name = "EconomyPreviewClaim"
	ButtonMetrics.apply(reference_claim, "compact", 250)
	reference_claim.disabled = not _relic_choice_ready(reward)
	footer.add_child(reference_claim)
	_select_reference_reward(selected_card_id)
	if not desktop:
		screen_action_dock = EconomyDetail.pin_mobile_footer(main, body, footer)

func _inspect_reference_reward(card_id: String) -> void:
	_select_reference_reward(card_id)
	_show_card_comparison(card_id)

func _select_reference_reward(card_id: String) -> void:
	selected_card_id = card_id
	for id in reference_cards:
		reference_cards[id].modulate = Color.WHITE if id == card_id else Color(0.82, 0.82, 0.82)
	var card: Dictionary = main.card_db.get_card(card_id)
	reference_reason.text = "%s\n\n%s" % [card.get("name", ""), _card_choice_role(card_id)]
	var detail_content := reference_reason.get_parent() as VBoxContainer
	if is_instance_valid(reference_comparison):
		detail_content.remove_child(reference_comparison)
		reference_comparison.queue_free()
	reference_comparison = EconomyDetail.make_comparison(main, card, true)
	detail_content.add_child(reference_comparison)
	(detail_content.get_parent() as ScrollContainer).scroll_vertical = 0
	reference_claim.tooltip_text = "%s · 카드 받기" % card.get("name", "카드")

func _claim_reference_reward() -> void:
	_claim_card_reward(selected_card_id)

func _show_card_comparison(card_id: String) -> void:
	_close_card_comparison()
	var card: Dictionary = main.card_db.get_card(card_id)
	detail_overlay = EconomyDetail.show_card(main, card, "카드 받기", _claim_card_reward.bind(card_id), not _relic_choice_ready(main.current_run.get("pending_card_reward", {})), _close_card_comparison)

func _close_card_comparison() -> void:
	if is_instance_valid(detail_overlay):
		detail_overlay.hide()
		detail_overlay.queue_free()
	detail_overlay = null
