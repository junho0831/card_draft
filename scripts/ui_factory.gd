extends RefCounted
class_name UiFactory

var card_art_sheet: Texture2D
var card_art_cols := 4
var card_art_rows := 3

func setup(art_sheet: Texture2D, cols: int, rows: int) -> void:
	card_art_sheet = art_sheet
	card_art_cols = cols
	card_art_rows = rows

func make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func add_title(parent: Node, text: String) -> void:
	var title := make_label(text, 40, Color(1.0, 0.88, 0.55, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.075, 0.07, 1.0))
	parent.add_child(title)

func add_menu_button(parent: Node, target: Object, text: String, callback_method: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_button(button, color)
	button.pressed.connect(Callable(target, callback_method))
	parent.add_child(button)
	return button

func make_panel_container(color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", make_style_box(color, Color(0.38, 0.43, 0.5, 1.0), 2, 8))
	return panel

func make_style_box(bg_color: Color, border_color: Color, border_width: int = 1, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	return style

func style_button(button: Button, base_color: Color) -> void:
	button.add_theme_stylebox_override("normal", make_style_box(base_color, Color(0.58, 0.64, 0.72, 1.0), 1, 6))
	button.add_theme_stylebox_override("hover", make_style_box(base_color.lightened(0.14), Color(1.0, 0.78, 0.34, 1.0), 2, 6))
	button.add_theme_stylebox_override("pressed", make_style_box(base_color.darkened(0.14), Color(1.0, 0.88, 0.55, 1.0), 2, 6))
	button.add_theme_stylebox_override("disabled", make_style_box(Color(0.16, 0.17, 0.19, 1.0), Color(0.28, 0.3, 0.34, 1.0), 1, 6))
	button.add_theme_color_override("font_color", Color(0.98, 0.98, 0.96, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.57, 0.62, 1.0))
	button.add_theme_font_size_override("font_size", 16)

func make_card_frame() -> PanelContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", make_style_box(Color(0.16, 0.18, 0.21, 1.0), Color(0.43, 0.38, 0.25, 1.0), 1, 7))
	return frame

func make_art_rect(art_index: int, size: Vector2) -> TextureRect:
	var texture := AtlasTexture.new()
	var cell_width := float(card_art_sheet.get_width()) / card_art_cols
	var cell_height := float(card_art_sheet.get_height()) / card_art_rows
	var col := art_index % card_art_cols
	var row := floori(float(art_index) / card_art_cols)
	texture.atlas = card_art_sheet
	texture.region = Rect2(col * cell_width, row * cell_height, cell_width, cell_height)

	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.custom_minimum_size = size
	return rect
