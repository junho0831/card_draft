extends RefCounted
class_name SettingsScreen

const ButtonMetrics = preload("res://src/ui/styles/button_metrics.gd")
const Tokens = preload("res://src/ui/styles/ui_tokens.gd")
const Preview = preload("res://src/ui/components/settings_impact_preview.gd")
const Presentation = preload("res://src/ui/components/battle_presentation.gd")
const EFFECT_MODES := ["rich", "compact", "minimal"]
const FOCUS_MODES := ["always", "outside", "off"]

const UI_SCALE_MODES := ["auto", "large", "small"]
const UI_SCALE_LABELS := ["자동", "크게", "작게"]

var main: Node
var reset_confirmation: ConfirmationDialog
var preview: Control
var preview_button: Button
var preview_overlay: Control
var preview_replay: Button
var preview_close: Button

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer) -> void:
	var panel: PanelContainer = main._make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 480)
	body.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_add_volume(box, "배경음악", "bgm_volume")
	_add_volume(box, "효과음", "sfx_volume")
	_add_choice(box, "전투 연출", ["풍부하게", "간결하게", "최소화"], EFFECT_MODES.find(Presentation.effect_mode(main.player_profile.settings)), _on_effects_selected, "EffectsMode")
	_add_hint(box, "최소화는 타격 숫자·소리를 유지하고 돌진·섬광을 줄입니다.")
	preview_button = Button.new()
	preview_button.name = "ImpactPreviewButton"
	preview_button.text = "타격 효과·소리 미리보기"
	preload("res://src/ui/styles/battle_styles.gd").apply_compact_button(preview_button, Color("d5b779"))
	preview_button.pressed.connect(show_preview)
	box.add_child(preview_button)
	_add_choice(box, "전장 자동 이동", ["항상 따라가기", "화면 밖 대상만", "끄기"], FOCUS_MODES.find(String(main.player_profile.settings.get("battle_auto_focus", "outside"))), _on_focus_selected, "AutoFocusMode")
	_add_hint(box, "가로 전장에 적용됩니다. 꺼도 전열 이동 버튼과 손 스크롤은 사용할 수 있습니다.")
	var fast_ai_toggle := CheckBox.new()
	fast_ai_toggle.text = "AI 턴 빠르게"
	ButtonMetrics.apply(fast_ai_toggle)
	fast_ai_toggle.button_pressed = bool(main.player_profile["settings"]["fast_ai"])
	fast_ai_toggle.toggled.connect(Callable(main, "_on_fast_ai_toggled"))
	box.add_child(fast_ai_toggle)
	var fullscreen_toggle := CheckBox.new()
	fullscreen_toggle.text = "전체 화면"
	ButtonMetrics.apply(fullscreen_toggle)
	fullscreen_toggle.button_pressed = bool(main.player_profile["settings"].get("fullscreen", true))
	fullscreen_toggle.toggled.connect(Callable(main, "_on_fullscreen_toggled"))
	box.add_child(fullscreen_toggle)

	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 12)
	box.add_child(scale_row)
	var scale_label: Label = main._make_label("UI 크기", 15, Color(0.9, 0.93, 0.98, 1.0))
	scale_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	scale_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_row.add_child(scale_label)
	var scale_selector := OptionButton.new()
	ButtonMetrics.apply(scale_selector, "action", 150)
	for label in UI_SCALE_LABELS:
		scale_selector.add_item(label)
	var current_mode := String(main.player_profile["settings"].get("ui_scale_mode", "auto"))
	scale_selector.select(maxi(0, UI_SCALE_MODES.find(current_mode)))
	scale_selector.item_selected.connect(Callable(self, "_on_ui_scale_selected"))
	scale_row.add_child(scale_selector)
	var scale_hint: Label = main._make_label("1280px 이상 큰 화면에서 카드와 버튼 크기를 조절합니다.", 12, Color(0.66, 0.72, 0.8, 1.0))
	scale_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	scale_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(scale_hint)
	var reset_button: Button = main._add_menu_button(box, "로컬 프로필 초기화", "_request_profile_reset", Color(0.35, 0.16, 0.16, 1.0))
	main.ui.style_role_button(reset_button, "danger", Color(0.9, 0.3, 0.28, 1.0), Color(0.24, 0.07, 0.08, 1.0))
	main._add_menu_button(box, "메인으로", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))

func _on_ui_scale_selected(index: int) -> void:
	if index < 0 or index >= UI_SCALE_MODES.size():
		return
	main._on_ui_scale_mode_selected(UI_SCALE_MODES[index])

func _add_hint(box: VBoxContainer, text: String) -> void:
	var hint: Label = main._make_label(text, 13, Color("b4c0d0"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

func _add_choice(box: VBoxContainer, title: String, options: Array, selected: int, callback: Callable, node_name: String) -> void:
	_add_hint(box, title)
	var selector := OptionButton.new()
	selector.name = node_name
	ButtonMetrics.apply(selector)
	for option in options: selector.add_item(option)
	selector.select(maxi(0, selected))
	selector.item_selected.connect(callback)
	box.add_child(selector)

func _add_volume(box: VBoxContainer, title: String, key: String) -> void:
	var value := float(main.player_profile.settings.get(key, 1.0))
	var heading: Label = main._make_label("%s  %d%%" % [title, roundi(value * 100)], 16, Color.WHITE)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(heading)
	var slider := HSlider.new()
	slider.name = key
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = value * 100
	slider.custom_minimum_size = Vector2(0, Tokens.BUTTON_HEIGHT_MD)
	slider.value_changed.connect(func(amount: float):
		heading.text = "%s  %d%%" % [title, roundi(amount)]
		main.player_profile.settings[key] = amount / 100.0
		main.audio_manager.apply_settings(main.player_profile.settings)
	)
	# Commit once at the end of a drag; keyboard changes save on focus exit.
	slider.drag_ended.connect(func(_changed: bool): main._save_profile())
	slider.focus_exited.connect(func(): main._save_profile())
	slider.tree_exiting.connect(func(): main._save_profile())
	box.add_child(slider)

func _on_effects_selected(index: int) -> void:
	if index < 0 or index >= EFFECT_MODES.size(): return
	main.player_profile.settings.battle_cutscene = EFFECT_MODES[index] == "rich"
	main.player_profile.settings.reduced_battle_fx = EFFECT_MODES[index] == "minimal"
	main._save_profile()

func _on_focus_selected(index: int) -> void:
	if index < 0 or index >= FOCUS_MODES.size(): return
	main.player_profile.settings.battle_auto_focus = FOCUS_MODES[index]
	main._save_profile()

func request_reset() -> void:
	if not is_instance_valid(reset_confirmation):
		reset_confirmation = ConfirmationDialog.new()
		reset_confirmation.title = "프로필 초기화"
		reset_confirmation.dialog_autowrap = true
		reset_confirmation.add_theme_constant_override("buttons_min_width", 120)
		reset_confirmation.add_theme_constant_override("buttons_min_height", Tokens.BUTTON_HEIGHT_MD)
		for button in [reset_confirmation.get_ok_button(), reset_confirmation.get_cancel_button()]:
			button.add_theme_font_size_override("font_size", 18)
			preload("res://src/ui/styles/battle_styles.gd").apply_compact_button(button, Color("d77b70") if button == reset_confirmation.get_ok_button() else Color("8497ac"))
		reset_confirmation.dialog_text = "카드 보유·강화·학습 기록과 설정을 초기화합니다.\n초기화한 프로필은 되돌릴 수 없습니다."
		reset_confirmation.ok_button_text = "초기화"
		reset_confirmation.cancel_button_text = "취소"
		reset_confirmation.confirmed.connect(Callable(main, "_reset_profile"))
		main.modal_layer.add_child(reset_confirmation)
	reset_confirmation.popup_centered(Vector2i(mini(360, int(main._layout_viewport_size().x) - 24), 180))

func show_preview() -> void:
	if is_instance_valid(preview_overlay): return
	preview_overlay = Control.new()
	preview_overlay.name = "ImpactPreviewOverlay"
	preview_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	main.modal_layer.add_child(preview_overlay)
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.005, 0.01, 0.02, 0.92)
	preview_overlay.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = minf(520, main._layout_viewport_size().x - 24)
	panel.add_theme_stylebox_override("panel", preload("res://src/ui/styles/battle_styles.gd").make_modern_style(Color("081320"), Color("b69a60"), 1, 8, 12))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title: Label = main._make_label("타격 미리보기", 22, Color("f1ce83"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(title)
	var mode := EFFECT_MODES.find(Presentation.effect_mode(main.player_profile.settings))
	_add_hint(box, "%s · 효과음 %d%% · 실제 전투에는 영향을 주지 않습니다." % [["풍부하게", "간결하게", "최소화"][mode], roundi(float(main.player_profile.settings.get("sfx_volume", 1.0)) * 100)])
	preview = Preview.new()
	box.add_child(preview)
	preview.setup(main)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	preview_replay = Button.new()
	preview_replay.text = "다시 재생"
	preview_replay.disabled = true
	preview_close = Button.new()
	preview_close.text = "닫기"
	for button in [preview_replay, preview_close]:
		button.custom_minimum_size.x = 120
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preload("res://src/ui/styles/battle_styles.gd").apply_compact_button(button, Color("b69a60") if button == preview_replay else Color("8497ac"))
		actions.add_child(button)
	preview_replay.pressed.connect(func():
		preview_replay.disabled = true
		preview.play()
	)
	preview.finished.connect(func():
		if is_instance_valid(preview_replay): preview_replay.disabled = false
	)
	preview_close.pressed.connect(close_preview)
	preview.call_deferred("play")

func close_preview() -> void:
	if is_instance_valid(preview_overlay):
		preview_overlay.hide()
		preview_overlay.queue_free()
	preview_overlay = null
	preview = null
	preview_button.grab_focus()
