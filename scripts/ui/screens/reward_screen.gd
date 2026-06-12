extends RefCounted
class_name RewardScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer) -> void:
	var reward: Dictionary = main.current_run.get("pending_card_reward", {})
	var compact: bool = main._is_compact_layout()
	body.add_child(main._make_run_summary_panel())
	body.add_child(main.ui.make_guidance_banner("다음 행동", "카드 1장을 골라 현재 빌드를 강화", Color(0.24, 0.2, 0.12, 1.0), compact))
	var panel = main._make_screen_panel(Color(0.08, 0.09, 0.11, 1.0), 880)
	body.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(main._make_label("전리품 선택", 22, Color(1.0, 0.88, 0.55, 1.0)))
	box.add_child(main._make_label("골드 +%d" % int(reward.get("gold_reward", 0)), 16, Color(1.0, 0.88, 0.55, 1.0)))
	box.add_child(main._make_label("카드 3장 중 1장을 선택해 덱에 추가합니다.", 16, Color(0.9, 0.92, 0.98, 1.0)))
	if typeof(reward.get("bonus_relic", {})) == TYPE_DICTIONARY and not Dictionary(reward.get("bonus_relic", {})).is_empty():
		var relic: Dictionary = reward["bonus_relic"]
		box.add_child(main._make_label("추가 유물 보상: %s - %s" % [String(relic.get("name", "")), String(relic.get("text", ""))], 15, Color(1.0, 0.88, 0.55, 1.0)))
	var row: BoxContainer = main.ui.make_responsive_box(compact, 10)
	box.add_child(row)
	for card_id in reward.get("choices", []):
		if not main.cards_by_id.has(String(card_id)):
			continue
		row.add_child(_make_reward_choice(main.cards_by_id[String(card_id)]))
	main._add_menu_button(box, "건너뛰기", "_skip_card_reward", Color(0.16, 0.18, 0.21, 1.0), self)

func _make_reward_choice(card: Dictionary) -> Control:
	var frame = main._make_card_frame()
	frame.custom_minimum_size = Vector2(170, 0)
	var primary_tag: String = main._primary_build_tag(main._current_build_scores())
	var matches_primary: bool = main._card_matches_build_tag(card, primary_tag)
	if matches_primary:
		frame.add_theme_stylebox_override("panel", main.ui.make_style_box(Color(0.24, 0.2, 0.12, 1.0), Color(1.0, 0.78, 0.32, 1.0), 3, 7))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	frame.add_child(box)
	if matches_primary:
		box.add_child(main._make_label("현재 빌드 추천", 13, Color(1.0, 0.88, 0.55, 1.0)))
	box.add_child(main._make_art_rect(int(card.get("art", 0)), Vector2(150, 102)))
	box.add_child(main._make_label(String(card.get("name", "")), 15, Color(0.98, 0.98, 0.96, 1.0)))
	box.add_child(main._make_label("[%d] %s/%s" % [int(card.get("cost", 0)), String(card.get("race", "")), String(card.get("attr", ""))], 13, Color(0.82, 0.88, 0.95, 1.0)))
	var tag_text: String = main._format_card_tag_text(card)
	if not tag_text.is_empty():
		box.add_child(main._make_label(tag_text, 13, Color(1.0, 0.82, 0.56, 1.0)))
	box.add_child(main._make_label(String(card.get("text", "")), 13, Color(0.82, 0.88, 0.95, 1.0)))
	var button := Button.new()
	button.text = "덱에 추가 ▶" if matches_primary else "선택"
	button.custom_minimum_size = Vector2(120, 40)
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
	main.run_flow.advance_from_current_node(["pending_card_reward"])
