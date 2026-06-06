extends Control

const CARD_ART_SHEET := preload("res://assets/card_art/season1_sample_sheet.png")
const CARD_ART_COLS := 4
const CARD_ART_ROWS := 3

var panel: PanelContainer
var title_label: Label
var attacker_art: TextureRect
var defender_art: TextureRect
var attacker_label: Label
var defender_label: Label
var impact_label: Label

func _ready() -> void:
	_build_ui()
	hide()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.58)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 340)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -320
	panel.offset_top = -170
	panel.offset_right = 320
	panel.offset_bottom = 170
	panel.add_theme_stylebox_override("panel", _make_style_box(Color(0.12, 0.135, 0.16, 1.0), Color(0.72, 0.62, 0.36, 1.0), 2, 8))
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	title_label = Label.new()
	title_label.text = "전투"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.68, 1.0))
	root.add_child(title_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	root.add_child(row)

	var attacker_box := _make_side_box()
	attacker_art = attacker_box.get_node("Art") as TextureRect
	attacker_label = attacker_box.get_node("Label") as Label
	row.add_child(attacker_box)

	impact_label = Label.new()
	impact_label.text = "VS"
	impact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	impact_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	impact_label.custom_minimum_size = Vector2(80, 180)
	impact_label.add_theme_font_size_override("font_size", 34)
	impact_label.add_theme_color_override("font_color", Color(1.0, 0.74, 0.42, 1.0))
	row.add_child(impact_label)

	var defender_box := _make_side_box()
	defender_art = defender_box.get_node("Art") as TextureRect
	defender_label = defender_box.get_node("Label") as Label
	row.add_child(defender_box)

func _make_side_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(210, 220)
	box.add_theme_constant_override("separation", 8)

	var art := TextureRect.new()
	art.name = "Art"
	art.custom_minimum_size = Vector2(210, 150)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	box.add_child(art)

	var label := Label.new()
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(210, 50)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 1.0))
	box.add_child(label)
	return box

func _make_style_box(bg_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
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
	style.content_margin_top = 14
	style.content_margin_right = 14
	style.content_margin_bottom = 14
	return style

func play_unit_battle(attacker: Dictionary, defender: Dictionary) -> void:
	title_label.text = "유닛 전투"
	attacker_art.texture = _make_art_texture(int(attacker.art))
	defender_art.texture = _make_art_texture(int(defender.art))
	attacker_label.text = "%s\n공격 %d / 체력 %d" % [attacker.name, attacker.attack, attacker.health]
	defender_label.text = "%s\n공격 %d / 체력 %d" % [defender.name, defender.attack, defender.health]
	impact_label.text = "VS"
	await _play()

func play_hero_attack(attacker: Dictionary, defender_name: String, damage: int) -> void:
	title_label.text = "영웅 공격"
	attacker_art.texture = _make_art_texture(int(attacker.art))
	defender_art.texture = null
	attacker_label.text = "%s\n공격 %d" % [attacker.name, attacker.attack]
	defender_label.text = "%s 영웅\n피해 %d" % [defender_name, damage]
	impact_label.text = "공격"
	await _play()

func _play() -> void:
	show()
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
	tween.tween_property(panel, "scale", Vector2(1.04, 1.04), 0.12)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.12)
	await tween.finished
	await get_tree().create_timer(0.42).timeout
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.12)
	await fade.finished
	hide()
	modulate.a = 1.0

func _make_art_texture(art_index: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	var cell_width := float(CARD_ART_SHEET.get_width()) / CARD_ART_COLS
	var cell_height := float(CARD_ART_SHEET.get_height()) / CARD_ART_ROWS
	var col := art_index % CARD_ART_COLS
	var row := floori(float(art_index) / CARD_ART_COLS)
	texture.atlas = CARD_ART_SHEET
	texture.region = Rect2(col * cell_width, row * cell_height, cell_width, cell_height)
	return texture
