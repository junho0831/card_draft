extends RefCounted
## Pure presentation policy. Callers supply state; no combat or save mutation.

static func field_size(mobile: bool, wide: bool, roomy: bool) -> Vector2:
	if mobile:
		return Vector2(112, 112)
	if wide:
		return Vector2(164, 144) if roomy else Vector2(154, 140)
	return Vector2.ZERO

static func hand_size(mobile: bool, wide: bool, roomy: bool) -> Vector2:
	if mobile:
		return Vector2(164, 202)
	if wide:
		return Vector2(208, 210) if roomy else Vector2(194, 204)
	return Vector2.ZERO

static func open_surface(panel: PanelContainer, padding: int = 0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.022, 0.034, 0.15)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, padding)
	panel.add_theme_stylebox_override("panel", style)

static func make_detail_overlay(host: Control, content: Control, close: Callable) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 300
	host.add_child(overlay)
	var scrim := ColorRect.new()
	scrim.color = Color(0.006, 0.01, 0.02, 0.9)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(scrim)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_right = -16
	box.offset_top = 16
	box.offset_bottom = -16
	overlay.add_child(box)
	var button := Button.new()
	button.text = "전투로 돌아가기"
	button.custom_minimum_size.y = 44
	button.pressed.connect(close)
	box.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	content.reparent(scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay.visible = false
	return overlay

# Shared by the turn action and the compact header; priority must stay identical.
static func phase_state(game_over: bool, player_turn: bool, locked: bool) -> Dictionary:
	if game_over:
		return {"badge": "전투 종료", "text": "전투 종료", "hint": "결과 확인 중", "disabled": true, "exhausted": false}
	if not player_turn:
		return {"badge": "상대 턴", "text": "상대 턴", "hint": "상대 행동이 끝나면 내 턴입니다", "disabled": true, "exhausted": false}
	if locked:
		return {"badge": "행동 중", "text": "행동 처리 중", "hint": "효과가 끝날 때까지 기다리세요", "disabled": true, "exhausted": false}
	return {"badge": "내 턴", "disabled": false}

# Differences between layouts are data, not separate animation pipelines.
static func attack_motion(landscape: bool, damage: int, counter: bool) -> Dictionary:
	return {
		"windup": 0.055 if landscape else 0.0,
		"distance": (66.0 if damage >= 4 else 54.0) if landscape else 58.0,
		"approach": 0.07 if counter else 0.085,
		"hit_stop": (0.025 if counter else (0.065 if damage >= 4 else 0.04)) if landscape else (0.035 if counter else (0.07 if damage >= 4 else 0.045)),
		"recoil": 0.025 if landscape else 0.055,
		"recover": 0.10 if landscape else 0.15,
	}

static func effect_mode(settings: Dictionary) -> String:
	if bool(settings.get("reduced_battle_fx", false)): return "minimal"
	return "rich" if bool(settings.get("battle_cutscene", false)) else "compact"
