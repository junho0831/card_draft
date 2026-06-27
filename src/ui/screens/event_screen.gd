extends RefCounted
class_name EventScreen

var main: Node

func _init(_main: Node) -> void:
	main = _main

func _event_art_index(event_id: String) -> int:
	match event_id:
		"suspicious_merchant":
			return 9
		"abandoned_cathedral":
			return 11
		"goblin_casino":
			return 4
		"magic_spring":
			return 5
		"battlefield_ruins":
			return 10
		_:
			return 8

func _event_theme_color(event_id: String) -> Color:
	match event_id:
		"suspicious_merchant":
			return Color(0.44, 0.28, 0.12, 1.0)
		"abandoned_cathedral":
			return Color(0.3, 0.3, 0.36, 1.0)
		"goblin_casino":
			return Color(0.46, 0.24, 0.12, 1.0)
		"magic_spring":
			return Color(0.16, 0.36, 0.42, 1.0)
		"battlefield_ruins":
			return Color(0.28, 0.24, 0.16, 1.0)
		_:
			return Color(0.24, 0.24, 0.18, 1.0)

func build(body: VBoxContainer) -> void:
	var event_data: Dictionary = main.current_run.get("pending_event", {})
	var compact: bool = main._is_compact_layout()
	body.add_child(main._make_run_summary_panel())
	body.add_child(main.ui.make_guidance_banner("다음 행동", "선택지 하나를 골라 런의 방향을 바꾸세요", Color(0.18, 0.2, 0.12, 1.0), compact))
	body.add_child(_make_event_status_strip(event_data, compact))

	var hub: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	hub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub.add_theme_constant_override("separation", 12)
	body.add_child(hub)

	hub.add_child(_make_story_panel(event_data, compact))

	var choice_panel: PanelContainer = main.ui.make_surface_panel(Color(0.07, 0.08, 0.1, 1.0), Color(0.2, 0.17, 0.11, 1.0), 1, 12, 14)
	choice_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub.add_child(choice_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	choice_panel.add_child(box)
	var title: Label = main._make_label("무엇을 하시겠습니까?", 22 if compact else 26, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	var subtitle: Label = main._make_label("선택 하나가 이번 런의 체력, 골드, 덱, 유물을 바꿉니다.", 13 if compact else 14, Color(0.84, 0.88, 0.94, 1.0))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(subtitle)
	box.add_child(main.ui.make_objective_panel("이벤트 목표", "지금 빌드에 맞는 대가와 보상을 비교해 가장 효율적인 선택을 고르세요.", compact))
	for option in event_data.get("options", []):
		if typeof(option) != TYPE_DICTIONARY:
			continue
		var option_data: Dictionary = option
		var button: Button = _make_option_button(option_data, compact)
		button.pressed.connect(Callable(self, "_resolve_event_option").bind(String(option.get("effect", ""))))
		box.add_child(button)

	hub.add_child(_make_preview_panel(event_data, compact))

func _make_event_status_strip(event_data: Dictionary, compact: bool) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.07, 0.08, 0.1, 0.98), Color(0.22, 0.18, 0.12, 1.0), 1, 12, 12)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	row.add_child(main.ui.make_chip("이벤트 %s" % String(event_data.get("title", "")), Color(0.2, 0.16, 0.08, 1.0), Color(1.0, 0.9, 0.62, 1.0), 13 if compact else 14))
	row.add_child(main.ui.make_chip("선택지 %d개" % (event_data.get("options", []) as Array).size(), Color(0.12, 0.2, 0.32, 1.0), Color(0.88, 0.92, 1.0, 1.0), 13 if compact else 14))
	row.add_child(main.ui.make_chip("추천 %s" % _event_guidance_text(), Color(0.16, 0.18, 0.1, 1.0), Color(0.96, 0.94, 0.82, 1.0), 13 if compact else 14))
	return panel

func _make_story_panel(event_data: Dictionary, compact: bool) -> PanelContainer:
	var event_id: String = String(event_data.get("id", ""))
	var theme: Color = _event_theme_color(event_id)
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.08, 0.09, 0.11, 0.96), theme.lightened(0.12), 1, 12, 14)
	panel.custom_minimum_size = Vector2(0 if compact else 260, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var eyebrow: Label = main._make_label("이벤트", 13 if compact else 14, Color(1.0, 0.86, 0.48, 1.0))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(eyebrow)
	var title: Label = main._make_label(String(event_data.get("title", "")), 22 if compact else 24, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	box.add_child(main._make_art_rect(_event_art_index(event_id), Vector2(220, 132) if compact else Vector2(236, 148)))
	var description: Label = main._make_label(String(event_data.get("description", "")), 15 if compact else 16, Color(0.9, 0.92, 0.98, 1.0))
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(description)
	box.add_child(HSeparator.new())
	box.add_child(main.ui.make_chip("런 변수를 크게 바꾸는 구간", Color(0.16, 0.16, 0.1, 1.0), Color(0.96, 0.94, 0.82, 1.0), 12 if compact else 13))
	var hint: Label = main._make_label("이벤트는 전투 사이의 변수입니다. 체력, 골드, 카드, 유물을 교환합니다.", 13 if compact else 14, Color(0.82, 0.86, 0.92, 1.0))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(hint)
	return panel

func _make_preview_panel(event_data: Dictionary, compact: bool) -> PanelContainer:
	var panel: PanelContainer = main.ui.make_surface_panel(Color(0.08, 0.09, 0.11, 0.96), Color(0.22, 0.19, 0.11, 1.0), 1, 12, 14)
	panel.custom_minimum_size = Vector2(0 if compact else 240, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title: Label = main._make_label("보상 미리보기", 18 if compact else 20, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	var summary: Label = main._make_label("각 선택이 어떤 대가와 보상을 갖는지 먼저 확인하세요.", 12 if compact else 13, Color(0.82, 0.86, 0.92, 1.0))
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(summary)
	box.add_child(main.ui.make_chip("위험과 보상을 비교하세요", Color(0.16, 0.16, 0.1, 1.0), Color(0.96, 0.94, 0.82, 1.0), 12 if compact else 13))
	for option in event_data.get("options", []):
		if typeof(option) != TYPE_DICTIONARY:
			continue
		var option_data: Dictionary = option
		box.add_child(_make_preview_card(option_data, compact))
	return panel

func _make_preview_card(option: Dictionary, compact: bool) -> PanelContainer:
	var effect: String = String(option.get("effect", ""))
	var color: Color = _effect_color(effect)
	var panel: PanelContainer = main.ui.make_surface_panel(color.darkened(0.18), color.lightened(0.06), 1, 8, 8)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var label: Label = main._make_label(String(option.get("label", "")), 13 if compact else 14, Color(1.0, 0.92, 0.76, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(label)
	var preview: Label = main._make_label(_effect_preview(effect), 12 if compact else 13, Color(0.86, 0.9, 0.96, 1.0))
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(preview)
	return panel

func _make_option_button(option: Dictionary, compact: bool) -> Button:
	var effect := String(option.get("effect", ""))
	var button: Button = main.ui.make_large_action_button(
		String(option.get("label", "")),
		_effect_preview(effect),
		_effect_icon(effect),
		_effect_color(effect),
		compact
	)
	button.custom_minimum_size = Vector2(0, 82 if compact else 96)
	if effect in ["merchant_relic", "merchant_card", "upgrade_card", "gain_equipment", "gain_human", "gain_undead"]:
		main.ui.style_primary_button(button, _effect_color(effect))
	return button

func _effect_icon(effect: String) -> String:
	if effect in ["merchant_card", "gain_equipment", "gain_human", "gain_undead", "upgrade_card"]:
		return "✦"
	if effect in ["merchant_relic", "curse_relic", "gamble_relic"]:
		return "◆"
	if effect in ["heal", "heal_10", "max_hp_trade"]:
		return "♥"
	if effect in ["remove_card"]:
		return "⌫"
	if effect in ["gamble_small"]:
		return "?"
	return "•"

func _effect_color(effect: String) -> Color:
	if effect in ["merchant_card", "merchant_relic", "gain_equipment", "gain_human", "gain_undead", "upgrade_card", "heal", "heal_10"]:
		return Color(0.24, 0.32, 0.22, 1.0)
	if effect in ["gamble_small", "gamble_relic", "curse_relic", "max_hp_trade"]:
		return Color(0.38, 0.28, 0.12, 1.0)
	if effect in ["remove_card", "leave"]:
		return Color(0.18, 0.22, 0.28, 1.0)
	return Color(0.22, 0.31, 0.38, 1.0)

func _effect_preview(effect: String) -> String:
	match effect:
		"merchant_card":
			return "체력 -5, 강한 카드 선택"
		"merchant_relic":
			return "골드 -50, 유물 획득"
		"remove_card":
			return "덱에서 카드 1장 제거"
		"heal_10":
			return "체력 +10"
		"curse_relic":
			return "최대 체력 -5, 유물 획득"
		"gamble_small":
			return "골드 -30, 50% 확률로 골드 +80"
		"gamble_relic":
			return "골드 -60, 30% 확률로 유물"
		"heal":
			return "체력 30% 회복"
		"upgrade_card":
			return "카드 1장 강화"
		"max_hp_trade":
			return "최대 체력 +5, 현재 체력 -10"
		"gain_equipment":
			return "무작위 장착 카드 획득"
		"gain_human":
			return "무작위 인간 카드 획득"
		"gain_undead":
			return "무작위 언데드 카드 획득"
		"leave":
			return "아무 일 없이 떠남"
		_:
			return "선택 결과 적용"

func _event_guidance_text() -> String:
	var scores: Dictionary = main._current_build_scores()
	var primary: String = main._primary_build_tag(scores)
	if primary.is_empty():
		return "손해 적은 선택 우선"
	var meta: Dictionary = main._build_tag_meta().get(primary, {})
	return "%s %s와 맞는 보상 확인" % [String(meta.get("icon", "")), String(meta.get("name", ""))]

func _resolve_event_option(effect: String) -> void:
	var result: Dictionary = main.event_run_service.resolve_effect(main.current_run, effect, {
		"roll_high_cost_cards": Callable(main, "_roll_high_cost_cards"),
		"roll_card_choices": Callable(main, "_roll_card_choices"),
		"roll_card_choice_filtered": Callable(main, "_roll_card_choice_filtered"),
		"random_relic": Callable(main.relic_service, "random_relic"),
		"apply_relic": Callable(main.relic_service, "apply_on_acquire"),
		"card_name": Callable(self, "_card_name"),
	})
	match String(result.get("action", "")):
		"show_card_reward":
			main._save_run()
			main._show_card_reward()
		"show_event":
			main._show_message(String(result.get("message", "")), "_show_event")
		"persisted_message":
			_show_persisted_message(String(result.get("message", "")), String(result.get("callback_method", "_complete_event_and_return")))
		"show_remove_card":
			main._show_remove_card_screen(String(result.get("reason", "이벤트")), String(result.get("source", "event_complete")))
		"show_upgrade_card":
			main._show_upgrade_card_screen(String(result.get("source", "event_complete_upgrade")))
		"complete_event":
			main._complete_event_and_return()
		_:
			main._complete_event_and_return()

func _card_name(card_id: String) -> String:
	var card: Dictionary = main.card_db.get_card(card_id)
	if card.is_empty():
		return card_id
	return String(card.get("name", ""))

func _show_persisted_message(message: String, callback_method: String) -> void:
	main.current_run["pending_event"] = {}
	main.current_run["pending_message"] = {
		"message": message,
		"callback_method": callback_method,
	}
	main._save_run()
	main._show_message(message, callback_method)
