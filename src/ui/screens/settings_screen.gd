extends RefCounted
class_name SettingsScreen

const UI_SCALE_MODES := ["auto", "large", "small"]
const UI_SCALE_LABELS := ["자동", "크게", "작게"]

var main: Node

func _init(_main: Node) -> void:
	main = _main

func build(body: VBoxContainer) -> void:
	var panel: PanelContainer = main._make_screen_panel(Color(0.12, 0.135, 0.16, 1.0), 480)
	body.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var cutscene_toggle := CheckBox.new()
	cutscene_toggle.text = "전투 연출 켜기"
	cutscene_toggle.button_pressed = bool(main.player_profile["settings"]["battle_cutscene"])
	cutscene_toggle.toggled.connect(Callable(main, "_on_cutscene_toggled"))
	box.add_child(cutscene_toggle)
	var fast_ai_toggle := CheckBox.new()
	fast_ai_toggle.text = "AI 턴 빠르게"
	fast_ai_toggle.button_pressed = bool(main.player_profile["settings"]["fast_ai"])
	fast_ai_toggle.toggled.connect(Callable(main, "_on_fast_ai_toggled"))
	box.add_child(fast_ai_toggle)
	var fullscreen_toggle := CheckBox.new()
	fullscreen_toggle.text = "전체 화면"
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
	scale_selector.custom_minimum_size = Vector2(150, 44)
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
	main._add_menu_button(box, "로컬 프로필 초기화", "_reset_profile", Color(0.35, 0.16, 0.16, 1.0))
	main._add_menu_button(box, "메인으로", "_show_main_menu", Color(0.22, 0.24, 0.28, 1.0))

func _on_ui_scale_selected(index: int) -> void:
	if index < 0 or index >= UI_SCALE_MODES.size():
		return
	main._on_ui_scale_mode_selected(UI_SCALE_MODES[index])
