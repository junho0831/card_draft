extends RefCounted

const Tokens = preload("res://src/ui/styles/ui_tokens.gd")
const Styles = preload("res://src/ui/styles/ui_styles.gd")
const TEXT := Tokens.TEXT_PRIMARY
const MUTED := Tokens.TEXT_SECONDARY
const SUCCESS := Tokens.ACCENT_TEAL
const WARNING := Tokens.ACCENT_GOLD

static func show_dialog(main: Node, data: Dictionary) -> Control:
	var overlay := Control.new()
	overlay.name = "BattleChoiceDialog"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 350
	main.modal_layer.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Tokens.SURFACE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var horizontal := maxi(24, int((main._layout_viewport_size().x - 960) / 2))
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, horizontal)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	overlay.add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Styles.make_textured_panel_style(Tokens.SURFACE_RAISED, Tokens.ACCENT_GOLD, 16, true))
	margin.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(text("전투 정보", 20))
	var close := Button.new()
	close.name = "BattleChoiceClose"
	close.text = "닫기"
	Styles.apply_role_button(close, "secondary", Tokens.BORDER, Color.TRANSPARENT, 16)
	preload("res://src/ui/styles/button_metrics.gd").apply(close, "action", 96)
	close.clip_text = false
	header.add_child(close)
	close.pressed.connect(overlay.queue_free)
	var scroll := ScrollContainer.new()
	scroll.name = "CardDetailScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	scroll.add_child(build(data))
	close.gui_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			close.accept_event()
			overlay.queue_free()
	)
	close.grab_focus()
	return overlay

static func text(value: String, size: int = 16, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

static func section(parent: VBoxContainer, title: String) -> void:
	parent.add_child(text(title, 18, WARNING))
	parent.add_child(HSeparator.new())

static func build(data: Dictionary) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.name = "BattleChoiceComparison"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	section(content, "현재 위협 · 현재 전장 기준")
	for threat in data.threats:
		content.add_child(text("%s → %s  ·  피해 %d" % [threat.source_name, threat.target_name, threat.damage]))
	if data.threats.is_empty():
		content.add_child(text("공격 없음", 16, MUTED))
	if not String(data.boss).is_empty():
		content.add_child(text("보스  ·  " + String(data.boss), 16, WARNING))
	if not data.targets.is_empty():
		section(content, String(data.attacker) + " · 공격 결과")
		for target in data.targets:
			var row := VBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			content.add_child(row)
			row.add_child(text(String(target.name), 16))
			var health := HBoxContainer.new()
			health.add_theme_constant_override("separation", 16)
			row.add_child(health)
			health.add_child(text("적 체력  %d → %d" % [target.before_hp, target.after_hp], 16, SUCCESS if target.after_hp == 0 else TEXT))
			health.add_child(text("내 체력  %d → %d" % [target.ally_before_hp, target.ally_after_hp], 16, Color("ffa6a6") if target.ally_after_hp == 0 else TEXT))
			row.add_child(text(String(target.outcome) + (" · 반격 없음" if target.counter == 0 else ""), 16, WARNING))
			if target.ally_after_hp == 0:
				row.add_child(text("내 유닛 사망", 14, Color("ffa6a6")))
			if target.lethal:
				for removed in target.removed_threats:
					row.add_child(text("위협 제거  ·  " + String(removed), 14, SUCCESS))
			if target.overflow > 0:
				row.add_child(text("적 영웅 체력  %d" % target.hero_after_hp, 14, MUTED))
			row.add_child(HSeparator.new())
	content.add_child(text("현재 전장 기준 · 미확정 효과", 16, WARNING))
	content.add_child(text("추가 카드·사망·장비·연계 효과와 대상 변경은 미확정입니다. 다른 적의 공격은 다음 턴 확정 피해로 합산하지 않습니다.", 14, MUTED))
	return content
