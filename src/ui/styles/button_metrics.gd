extends RefCounted
## Shared action geometry. Card faces and illustrated choice tiles keep their own layout.
const Tokens = preload("res://src/ui/styles/ui_tokens.gd")

static func apply(button: Button, kind: String = "action", minimum_width: float = -1) -> void:
	var resolved := kind
	if kind == "action" and button.text.contains("\n"): resolved = "multiline"
	var height := Tokens.BUTTON_HEIGHT_MD
	var font_size := Tokens.BUTTON_FONT
	if resolved in ["compact", "icon"]:
		height = Tokens.BUTTON_HEIGHT_SM
		font_size = Tokens.BUTTON_FONT_COMPACT
	elif resolved == "multiline":
		height = Tokens.BUTTON_HEIGHT_LG
	button.set_meta("button_kind", kind)
	button.set_meta("standard_action_metrics", true)
	# OptionButton defaults to opening on press, before a mobile swipe can begin.
	if button is OptionButton:
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	var width := button.custom_minimum_size.x if minimum_width < 0 else minimum_width
	button.custom_minimum_size = Vector2(Tokens.BUTTON_HEIGHT_SM if resolved == "icon" else width, height)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", font_size)
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if button.tooltip_text.is_empty() or button.tooltip_text == String(button.get_meta("button_label_tooltip", "")):
		button.tooltip_text = button.text
		button.set_meta("button_label_tooltip", button.text)
	button.scale = Vector2.ONE
	# Identical state padding prevents press/disabled/selection from resizing a row.
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style: StyleBox = button.get_theme_stylebox(state).duplicate()
		style.content_margin_left = 6 if resolved in ["compact", "icon"] else 12
		style.content_margin_right = style.content_margin_left
		style.content_margin_top = 4 if resolved == "multiline" else 6
		style.content_margin_bottom = style.content_margin_top
		button.add_theme_stylebox_override(state, style)
