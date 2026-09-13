extends RefCounted
## Presentation-only layout policy. No battle state is read or modified here.

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
