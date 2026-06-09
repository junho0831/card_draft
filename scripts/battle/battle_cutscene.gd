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
var flash_rect: ColorRect

func _ready() -> void:
	_build_ui()
	hide()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.58)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 120)
	margin.add_theme_constant_override("margin_top", 100)
	margin.add_theme_constant_override("margin_bottom", 100)
	add_child(margin)

	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_style_box(Color(0.12, 0.135, 0.16, 1.0), Color(0.72, 0.62, 0.36, 1.0), 2, 8))
	margin.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(root)

	title_label = Label.new()
	title_label.text = "전투"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.68, 1.0))
	root.add_child(title_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	impact_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	impact_label.add_theme_font_size_override("font_size", 48)
	impact_label.add_theme_color_override("font_color", Color(1.0, 0.74, 0.42, 1.0))
	row.add_child(impact_label)

	var defender_box := _make_side_box()
	defender_art = defender_box.get_node("Art") as TextureRect
	defender_label = defender_box.get_node("Label") as Label
	row.add_child(defender_box)

	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)

func _make_side_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)

	var art := TextureRect.new()
	art.name = "Art"
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	box.add_child(art)

	var label := Label.new()
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(0, 60)
	label.add_theme_font_size_override("font_size", 22)
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

func play_unit_battle(attacker: Dictionary, defender: Dictionary, attack_damage: int, defense_damage: int) -> void:
	title_label.text = "유닛 전투"
	attacker_art.texture = _make_art_texture(int(attacker.art))
	defender_art.texture = _make_art_texture(int(defender.art))
	attacker_label.text = "%s\n공격 %d / 체력 %d" % [attacker.name, attacker.attack, attacker.health]
	defender_label.text = "%s\n공격 %d / 체력 %d" % [defender.name, defender.attack, defender.health]
	impact_label.text = "VS"
	await _play(defense_damage, attack_damage)

func play_hero_attack(attacker: Dictionary, defender_name: String, damage: int) -> void:
	title_label.text = "영웅 공격"
	attacker_art.texture = _make_art_texture(int(attacker.art))
	defender_art.texture = null
	attacker_label.text = "%s\n공격 %d" % [attacker.name, attacker.attack]
	defender_label.text = "%s 영웅\n피해 %d" % [defender_name, damage]
	impact_label.text = "공격"
	await _play(0, damage)

func _play(attacker_takes_damage: int, defender_takes_damage: int) -> void:
	show()
	modulate.a = 0.0
	
	var attacker_orig_pos = attacker_art.position
	var defender_orig_pos = defender_art.position

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
	tween.tween_property(panel, "scale", Vector2(1.05, 1.05), 0.1)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.05)
	await tween.finished

	# 1. 공격자 -> 방어자 공격 연출
	var attack_tween = create_tween()
	attack_tween.tween_property(attacker_art, "position:x", attacker_orig_pos.x + 60, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await attack_tween.finished

	# 이펙트: 화면 번쩍임 (Flash)
	flash_rect.color = Color(1.0, 0.9, 0.9, 0.8)
	var flash_tween := create_tween()
	flash_tween.tween_property(flash_rect, "color:a", 0.0, 0.3)
	
	# 이펙트: 방어자 데미지 텍스트 및 이펙트
	if defender_takes_damage > 0:
		if defender_art.texture != null:
			_spawn_floating_text(defender_art, -defender_takes_damage)
			_play_slash_effect(defender_art)
		else:
			_spawn_floating_text(defender_label, -defender_takes_damage)
			_play_slash_effect(defender_label)

	# 카메라 셰이크
	var orig_pos = panel.position
	for i in range(4):
		panel.position = orig_pos + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		await get_tree().create_timer(0.03).timeout
	panel.position = orig_pos
	
	var retreat_tween = create_tween()
	retreat_tween.tween_property(attacker_art, "position:x", attacker_orig_pos.x, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await retreat_tween.finished

	# 2. 방어자 -> 공격자 반격 연출
	if attacker_takes_damage > 0 and defender_art.texture != null:
		await get_tree().create_timer(0.1).timeout
		
		var counter_tween = create_tween()
		counter_tween.tween_property(defender_art, "position:x", defender_orig_pos.x - 60, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		await counter_tween.finished
		
		flash_rect.color = Color(1.0, 0.9, 0.9, 0.8)
		var counter_flash_tween := create_tween()
		counter_flash_tween.tween_property(flash_rect, "color:a", 0.0, 0.3)
		
		_spawn_floating_text(attacker_art, -attacker_takes_damage)
		_play_slash_effect(attacker_art)
		
		for i in range(4):
			panel.position = orig_pos + Vector2(randf_range(-15, 15), randf_range(-15, 15))
			await get_tree().create_timer(0.03).timeout
		panel.position = orig_pos
		
		var counter_retreat_tween = create_tween()
		counter_retreat_tween.tween_property(defender_art, "position:x", defender_orig_pos.x, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		await counter_retreat_tween.finished

	await get_tree().create_timer(0.4).timeout
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.12)
	await fade.finished
	hide()
	modulate.a = 1.0

func _spawn_floating_text(target: Control, delta: int) -> void:
	if delta == 0:
		return
	var lbl = Label.new()
	var color := Color(1, 0.2, 0.2) if delta < 0 else Color(0.2, 1, 0.2)
	lbl.text = ("%+d" % delta) if delta > 0 else ("%d" % delta)
	lbl.add_theme_font_size_override("font_size", 48)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 8)
	
	# 랜덤한 각도로 회전
	lbl.rotation_degrees = randf_range(-15, 15)
	
	target.add_child(lbl)
	lbl.position = Vector2(target.size.x / 2 - 20, target.size.y / 2 - 20)
	
	var tween = create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 60, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_callback(lbl.queue_free)

func _play_slash_effect(target: Control) -> void:
	var slash = Line2D.new()
	slash.width = 15.0
	slash.default_color = Color(1.0, 1.0, 1.0, 0.9)
	slash.begin_cap_mode = Line2D.LINE_CAP_ROUND
	slash.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	var cx = target.size.x / 2
	var cy = target.size.y / 2
	var p1 = Vector2(cx - 50, cy - 50)
	var p2 = Vector2(cx + 50, cy + 50)
	
	if randi() % 2 == 0:
		p1.y = cy + 50
		p2.y = cy - 50
		
	slash.add_point(p1)
	slash.add_point(p2)
	target.add_child(slash)
	
	var tween = create_tween()
	tween.tween_property(slash, "width", 0.0, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slash, "modulate:a", 0.0, 0.2)
	tween.tween_callback(slash.queue_free)

func _make_art_texture(art_index: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	var cell_width := float(CARD_ART_SHEET.get_width()) / CARD_ART_COLS
	var cell_height := float(CARD_ART_SHEET.get_height()) / CARD_ART_ROWS
	var col := art_index % CARD_ART_COLS
	var row := floori(float(art_index) / CARD_ART_COLS)
	texture.atlas = CARD_ART_SHEET
	texture.region = Rect2(col * cell_width, row * cell_height, cell_width, cell_height)
	return texture
