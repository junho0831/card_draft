extends Control
## Landscape-only presentation. Combat remains owned by BattleScreen.
var battle
var session
var card_dialog: Control
var confirm_button: Button
var detail_slot := -1
var confirm_in_progress := false
var unit_width := 80.0
var hand_size := Vector2(80, 112)
var hero_bars: Array[ProgressBar] = []
var center_guidance: Label
var intent_detail: Label
var enemy_lane_button: Button
var ally_lane_button: Button
# Overrides follow the existing art identity; other portraits use the default focus.
const PORTRAIT_FOCUS := {
	"trainee_swordsman": Vector2(0.5, 0.2),
	"shield_guard": Vector2(0.5, 0.2),
	"flame_swordsman": Vector2(0.5, 0.2),
	"mercenary": Vector2(0.5, 0.2),
	"bone_soldier": Vector2(0.5, 0.2),
}
var board_scroll: ScrollContainer
var lanes: VBoxContainer
var focus_pending: bool:
	get: return session.focus_pending
var previous_back_quit := true

func setup(owner_battle, old_root: Control, action_panel: Control) -> void:
	battle = owner_battle
	session = battle.presentation
	session.attach(self)
	previous_back_quit = get_tree().quit_on_go_back
	get_tree().quit_on_go_back = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var viewport: Vector2 = battle.main._layout_viewport_size()
	unit_width = floorf((viewport.x - 120 - 24 - 68 - 40) / 5.0)
	hand_size = Vector2(76, 106) if viewport.y <= 375 else Vector2(80, 112)
	old_root.hide()
	action_panel.hide()
	battle.main.mobile_bottom_inset = 0
	battle.main._apply_root_layout()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 4)
	margin.add_child(page)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 44
	page.add_child(header)
	var title := label("전투 · " + String(battle.opponent.name), 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(title)
	battle.reference_mana_label = label("", 18)
	header.add_child(battle.reference_mana_label)
	battle.detail_toggle_button.reparent(header)
	header.add_child(action("메뉴", func():
		cancel_focus()
		battle.main._show_main_menu(), 44))
	battle.battle_guidance_label.hide()
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	var board := VBoxContainer.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.add_theme_constant_override("separation", 4)
	body.add_child(board)
	board_scroll = ScrollContainer.new()
	board_scroll.name = "BattlefieldScroll"
	board_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	board_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	board_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_child(board_scroll)
	lanes = VBoxContainer.new()
	lanes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lanes.add_theme_constant_override("separation", 12)
	board_scroll.add_child(lanes)
	lane(lanes, battle.opponent_field_box, true)
	lane(lanes, battle.player_field_box, false)
	battle.main.touch_scroll_router.gesture_started.connect(_gesture_started)
	battle.main.touch_scroll_router.gesture_ended.connect(_gesture_ended)
	call_deferred("_initial_focus")
	var fx_clip := Control.new()
	fx_clip.name = "BattlefieldEffectsClip"
	fx_clip.clip_contents = true
	fx_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_clip)
	battle.battle_fx_layer.reparent(fx_clip)
	board_scroll.resized.connect(func():
		fx_clip.position = board_scroll.global_position - global_position
		fx_clip.size = board_scroll.size
	)
	board_scroll.item_rect_changed.connect(func():
		fx_clip.position = board_scroll.global_position - global_position
		fx_clip.size = board_scroll.size
	)
	center_guidance = label("", 14)
	center_guidance.custom_minimum_size.y = 20
	center_guidance.clip_text = true
	center_guidance.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	board.add_child(center_guidance)
	intent_detail = label("", 16)
	intent_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle.deck_list_label.get_parent().add_child(intent_detail)
	battle.hand_scroll.reparent(board)
	battle.hand_scroll.custom_minimum_size = Vector2(0, hand_size.y + 6)
	battle.hand_scroll.size_flags_vertical = Control.SIZE_SHRINK_END
	var rail := VBoxContainer.new()
	rail.custom_minimum_size.x = 120
	rail.add_theme_constant_override("separation", 6)
	body.add_child(rail)
	for button in [battle.recommended_action_button, battle.race_power_button, battle.end_turn_button]:
		button.reparent(rail)
		button.custom_minimum_size = Vector2(120, 52)
		button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		button.add_theme_font_size_override("font_size", 16)
	enemy_lane_button = action("", func(): _navigate_lane(false), 44)
	enemy_lane_button.name = "EnemyLaneNavigation"
	rail.add_child(enemy_lane_button)
	ally_lane_button = action("", func(): _navigate_lane(true), 44)
	ally_lane_button.name = "AllyLaneNavigation"
	rail.add_child(ally_lane_button)
	for navigation in [enemy_lane_button, ally_lane_button]:
		navigation.add_theme_font_size_override("font_size", 14)
	board_scroll.get_v_scroll_bar().value_changed.connect(func(_value): _refresh_lane_navigation())
	call_deferred("_refresh_lane_navigation")

func _navigate_lane(ally: bool) -> void:
	# Android may dispatch Button.pressed before the touch router sees release.
	await get_tree().process_frame
	if is_inside_tree():
		await focus_targets([{"player": ally, "hero": true}])

func _refresh_lane_navigation() -> void:
	if not is_instance_valid(enemy_lane_button) or not is_instance_valid(ally_lane_button): return
	var bar := board_scroll.get_v_scroll_bar()
	var at_enemy := bar.value <= maxf(0, bar.max_value - bar.page) * 0.5
	for button in [enemy_lane_button, ally_lane_button]:
		var active: bool = (button == enemy_lane_button) == at_enemy
		style_rail_button(button, Color("d5b779") if active else Color("66788e"))
		var style: StyleBoxFlat = button.get_theme_stylebox("normal").duplicate()
		style.bg_color = Color(0.17, 0.14, 0.08, 0.98) if active else Color(0.025, 0.04, 0.06, 0.96)
		style.set_border_width_all(2 if active else 1)
		button.add_theme_stylebox_override("normal", style)
		button.tooltip_text = "현재 보고 있는 전열" if active else "눌러서 전열로 이동"

func label(value: String, font_size: int = 16) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func action(value: String, callback: Callable, height: int = 52) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(60, height)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(callback)
	return button

func lane(parent: Control, cards: HBoxContainer, enemy: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.custom_minimum_size.y = 144
	parent.add_child(row)
	var hero := Button.new()
	hero.custom_minimum_size = Vector2(68, 144)
	hero.clip_text = true
	hero.add_theme_font_size_override("font_size", 16)
	row.add_child(hero)
	hero.clip_contents = true
	var portrait: TextureRect = battle._make_battle_hero_art(int(battle.main.current_run.get("active_enemy", {}).get("art", 0)), Vector2.ZERO, enemy)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(portrait)
	var bar := ProgressBar.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -6
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(bar)
	hero_bars.append(bar)
	var hp := label("", 16)
	hp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hp.offset_bottom = -7
	hp.add_theme_color_override("font_outline_color", Color.BLACK)
	hp.add_theme_constant_override("outline_size", 5)
	hero.add_child(hp)
	if enemy:
		battle.opponent_hero_target = hero
		battle.hero_attack_button = hero
		battle.opponent_hero_target_hp_label = hp
		battle.enemy_hero_hp_label = hp
		battle.opponent_info = hp
		hero.pressed.connect(func(): battle._attack_opponent_hero())
	else:
		battle.player_hero_target = hero
		battle.player_hero_target_hp_label = hp
		battle.player_hero_hp_label = hp
		battle.player_info = hp
	cards.reparent(row)
	cards.custom_minimum_size = Vector2(0, 144)
	cards.add_theme_constant_override("separation", 4)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func stamp(parent: Control, node_name: String, value: String, at: Vector2, extent: Vector2, color: Color, font_size: int = 16) -> Label:
	var band := Panel.new()
	band.name = node_name + "Band"
	band.position = at
	band.size = extent
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	if node_name in ["Cost", "Attack", "Health"]:
		var gem := StyleBoxTexture.new()
		gem.texture = load("res://assets/ui/fantasy/gem_red.svg" if node_name == "Attack" else "res://assets/ui/fantasy/gem_blue.svg")
		band.add_theme_stylebox_override("panel", gem)
	else:
		band.add_theme_stylebox_override("panel", style)
	parent.add_child(band)
	var text := label(value, font_size)
	text.name = node_name
	text.position = at
	text.size = extent
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.clip_text = true
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(text)
	return text

static func card_kind(card: Dictionary) -> String:
	var type := String(card.get("type", "unit"))
	if type == "unit": return "unit"
	if type == "equipment": return "equipment"
	for effect in card.get("effects", []):
		if effect.op in ["front_damage", "all_damage", "combo_damage", "low_damage", "curse", "hero_damage"]: return "damage"
	var id := String(card.get("id", "")).trim_suffix("_plus")
	if id in ["small_flame", "gale_shot", "corpse_explosion", "fireball", "death_mark", "plague_spread", "soul_shackle", "funeral_fog", "vampiric_strike"]:
		return "damage"
	return "support"

static func kind_color(kind: String) -> Color:
	return {"unit": Color("7299bb"), "damage": Color("d35b52"), "support": Color("57aa7b"), "equipment": Color("d8ae54")}[kind]

func outline(parent: Control, color: Color, inset: float, width: int, node_name: String) -> void:
	var edge := Panel.new()
	edge.name = node_name
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edge.offset_left = inset
	edge.offset_top = inset
	edge.offset_right = -inset
	edge.offset_bottom = -inset
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	edge.add_theme_stylebox_override("panel", style)
	parent.add_child(edge)

func portrait_texture(card: Dictionary, target_size: Vector2) -> Texture2D:
	var source: Texture2D = battle.main.ui.card_art_texture(card)
	if source == null: return null
	var texture: Texture2D = source
	var region := Rect2(Vector2.ZERO, source.get_size())
	if source is AtlasTexture:
		texture = source.atlas
		region = source.region
	var art_id := String(card.get("art_id", card.get("id", ""))).trim_suffix("_plus")
	if art_id == "thief": art_id = "mercenary"
	var focus: Vector2 = PORTRAIT_FOCUS.get(art_id, Vector2(0.5, 0.3))
	var crop_size := region.size
	var ratio := target_size.x / target_size.y
	if crop_size.x / crop_size.y > ratio:
		crop_size.x = crop_size.y * ratio
	else:
		crop_size.y = crop_size.x / ratio
	var offset := region.size * focus - crop_size * 0.5
	offset.x = clampf(offset.x, 0, region.size.x - crop_size.x)
	offset.y = clampf(offset.y, 0, region.size.y - crop_size.y)
	var result := AtlasTexture.new()
	result.atlas = texture
	result.region = Rect2(region.position + offset, crop_size)
	return result

func field_card(unit: Dictionary, status: String, accent: Color) -> Button:
	return tile(unit, status, unit_width, accent, 144, true)

func tile(card: Dictionary, bottom: String, width: float, accent: Color, height: float = 72, field: bool = false) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(width, height)
	button.size = button.custom_minimum_size
	button.clip_contents = true
	button.add_theme_stylebox_override("normal", battle.BATTLE_STYLES.make_card_frame(accent, 2))
	if card.is_empty():
		button.modulate.a = 0.32
		return button
	var kind := card_kind(card)
	var tint := kind_color(kind)
	button.set_meta("card_kind", kind)
	button.add_theme_stylebox_override("normal", battle.BATTLE_STYLES.make_card_frame(tint, 2))
	var art: TextureRect = battle.main._make_card_art_rect(card, Vector2.ZERO)
	art.name = "Illustration"
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 3
	art.offset_right = -3
	art.offset_top = 3
	art.offset_bottom = -3
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if field:
		art.texture = portrait_texture(card, Vector2(width - 6, 102))
		art.anchor_bottom = 0
		art.offset_bottom = 102
	button.add_child(art)
	stamp(button, "CardName", String(card.get("name", "")), Vector2(3, 102 if field else height - 43), Vector2(width - 6, 18 if field else 20), Color(tint.r * 0.35, tint.g * 0.35, tint.b * 0.35, 0.96), 14)
	if card.has("attack"):
		stamp(button, "Attack", str(int(card.attack)), Vector2(3, height - 24), Vector2(26, 22), Color(0.48, 0.12, 0.09))
		stamp(button, "Health", str(int(card.get("health", 0))), Vector2(width - 29, height - 24), Vector2(26, 22), Color(0.08, 0.25, 0.48))
	if not bottom.is_empty():
		stamp(button, "Status", bottom, Vector2(3, 3), Vector2(minf(width - 6, 34), 19), Color(0.025, 0.04, 0.06, 0.75), 12)
	outline(button, tint, 1, 2, "TypeBorder")
	var icon := TextureRect.new()
	icon.name = "TypeIcon"
	icon.texture = load("res://assets/ui/fantasy/type_%s.svg" % kind)
	icon.position = Vector2(width - 24, 4)
	icon.size = Vector2(19, 19)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	button.tooltip_text = {"unit":"유닛", "damage":"피해·저주 주문", "support":"회복·지원 주문", "equipment":"장비"}[kind]
	return button

func field_slot(side: Dictionary, index: int, ally: bool) -> Control:
	if index >= side.field.size():
		var empty := field_card({}, "", Color(0.2, 0.27, 0.33))
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return empty
	var unit: Dictionary = side.field[index]
	var ready: bool = not battle._is_player_input_locked() and (bool(unit.get("can_attack", false)) or not battle.pending_action.is_empty()) if ally else not battle._is_player_input_locked() and battle.selected_attacker >= 0
	var accent := Color(0.3, 0.38, 0.48)
	if ready:
		accent = Color(0.3, 1.0, 0.65) if ally else Color(1.0, 0.35, 0.3)
	if ally and battle.selected_attacker == index:
		accent = Color(1.0, 0.8, 0.25)
	var status := "선봉" if unit.get("is_vanguard", false) else ("◆" if ready and ally else "")
	var prediction: Dictionary = {}
	if not ally and ready:
		var attacker: Dictionary = battle._selected_player_attacker()
		prediction = battle._predict_unit_attack(attacker, unit, battle.player, battle.opponent)
	var button := field_card(unit, status, accent)
	if ally and battle.selected_attacker == index:
		outline(button, Color.WHITE, 4, 2, "SelectionBorder")
	elif ready and (not ally or not battle.pending_action.is_empty()):
		outline(button, Color.WHITE, 4, 1, "TargetBorder")
	if not prediction.is_empty():
		button.set_meta("attack_prediction", prediction)
		for node_name in ["Attack", "AttackBand", "Health", "HealthBand"]:
			var node := button.get_node_or_null(node_name)
			if node != null: node.hide()
		stamp(button, "CombatPrediction", "적%d · 내%d" % [prediction.defender_health, prediction.attacker_health], Vector2(2, 120), Vector2(unit_width - 4, 24), Color(0.03, 0.08, 0.12, 0.98), 16)
		if prediction.defender_health <= 0:
			button.get_node("CardName").size.x = unit_width - 38
			stamp(button, "Lethal", "처치", Vector2(unit_width - 34, 102), Vector2(32, 18), Color(0.45, 0.08, 0.05), 12)
		button.tooltip_text = "공격 후 적 체력 / 내 체력 (장비·사망 효과 별도)"
	button.pressed.connect(func():
		if button.get_meta("hold_consumed", false) or not ready: return
		if ally: battle._on_player_unit_pressed(index)
		else: battle._on_opponent_unit_pressed(index)
	)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 0.4
	button.add_child(timer)
	battle.main.touch_scroll_router.swipe_started.connect(timer.stop)
	timer.timeout.connect(func():
		button.set_meta("hold_consumed", true)
		show_unit(unit, ally)
	)
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				button.set_meta("hold_consumed", false)
				button.set_meta("hold_origin", event.position)
				timer.start()
			else: timer.stop()
		elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if event.position.distance_to(button.get_meta("hold_origin", event.position)) >= 12:
				timer.stop()
				button.set_meta("hold_consumed", true)
	)
	return button

func render_hand() -> void:
	for i in range(battle.player.hand.size()):
		var card: Dictionary = battle.player.hand[i]
		var cost: int = battle.main.relic_service.modify_card_cost(battle.main.current_run, battle.battle_state, card, "player")
		var playable: bool = not battle._is_player_input_locked() and battle._can_play_card(battle.player, card, "player")
		var button := tile(card, "", hand_size.x, Color(0.25, 0.7, 0.6) if playable else Color(0.3, 0.36, 0.42), hand_size.y)
		stamp(button, "Cost", str(cost), Vector2(3, 3), Vector2(26, 26), Color(0.06, 0.26, 0.55), 18)
		if int(card.get("_hand_slot", i)) == battle.selected_hand_slot:
			outline(button, Color.WHITE, 4, 2, "SelectionBorder")
		if playable:
			stamp(button, "Playable", "◆", Vector2(hand_size.x - 20, 27), Vector2(16, 16), Color(0.03, 0.09, 0.08, 0.8), 12)
		button.set_meta("hand_slot", int(card.get("_hand_slot", i)))
		if not playable: button.get_node("Illustration").modulate = Color(0.42, 0.42, 0.42)
		button.pressed.connect(battle._on_hand_card_pressed.bind(i))
		battle.hand_box.add_child(button)
	battle._layout_hand_cards()

func close_detail() -> void:
	if battle != null and is_instance_valid(battle.hand_box):
		for card in battle.hand_box.get_children():
			var edge: Node = card.get_node_or_null("SelectionBorder")
			if edge != null:
				card.remove_child(edge)
				edge.queue_free()
	if is_instance_valid(card_dialog):
		card_dialog.hide()
		card_dialog.queue_free()
	card_dialog = null
	confirm_button = null
	detail_slot = -1

func dialog(title: String, text: String, card: Dictionary = {}) -> HBoxContainer:
	close_detail()
	card_dialog = Control.new()
	card_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_dialog.z_index = 350
	battle.main.modal_layer.add_child(card_dialog)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.04, 0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_dialog.add_child(shade)
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = 12
	panel.offset_bottom = -12
	card_dialog.add_child(panel)
	var heading := label(title, 20)
	heading.clip_text = true
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	panel.add_child(heading)
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 20)
	panel.add_child(content)
	if not card.is_empty():
		var face := preload("res://src/ui/components/card_inspection_view.gd").make_face(battle.main, card)
		var viewer := preload("res://src/ui/components/card_inspection_view.gd").new()
		var available_height: float = battle.main._layout_viewport_size().y - 116.0
		viewer.setup(face, Vector2(available_height * 284.0 / 396.0, available_height))
		content.add_child(viewer)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.name = "CardDetailScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var description := label(text, 18)
	description.add_theme_constant_override("line_spacing", 5)
	description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(description)
	var buttons := HBoxContainer.new()
	right.add_child(buttons)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var close := action("닫기", close_detail)
	style_rail_button(close, Color("8497ac"))
	buttons.add_child(close)
	return buttons

func show_card(index: int) -> void:
	if index < 0 or index >= battle.player.hand.size(): return
	var card: Dictionary = battle.player.hand[index]
	var cost: int = battle.main.relic_service.modify_card_cost(battle.main.current_run, battle.battle_state, card, "player")
	var playable: bool = not battle._is_player_input_locked() and battle._can_play_card(battle.player, card, "player")
	var info: String = battle._card_result_preview(card) + "\n\n" + battle._combo_card_preview(card) + "\n\n좌우로 밀어 기울이기 · 위아래로 스크롤"
	if battle._requires_ally_target(card):
		info = info.replace("앞 아군", "선택할 아군")
	if not playable: info += "\n" + battle._unplayable_card_hint(card, cost)
	var display_card := card.duplicate(true)
	display_card["cost"] = cost
	var buttons := dialog("%s · 비용 %d" % [card.get("name", "카드"), cost], info, display_card)
	var source: Control = battle._hand_card_control(int(card.get("_hand_slot", index)))
	if is_instance_valid(source) and not source.has_node("SelectionBorder"):
		outline(source, Color.WHITE, 4, 2, "SelectionBorder")
	card_dialog.modulate.a = 0.65
	card_dialog.create_tween().tween_property(card_dialog, "modulate:a", 1.0, 0.1)
	detail_slot = int(card.get("_hand_slot", index))
	confirm_button = action("사용 · 마나 %d" % cost, confirm_card)
	confirm_button.disabled = not playable
	confirm_button.custom_minimum_size.x = 164
	confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	style_rail_button(confirm_button, Color("dfba68"))
	var primary_style: StyleBoxFlat = confirm_button.get_theme_stylebox("normal").duplicate()
	primary_style.bg_color = Color(0.22, 0.16, 0.065, 0.98)
	primary_style.set_border_width_all(2)
	confirm_button.add_theme_stylebox_override("normal", primary_style)
	buttons.add_child(confirm_button)

func confirm_card() -> void:
	if confirm_in_progress: return
	for index in range(battle.player.hand.size()):
		var card: Dictionary = battle.player.hand[index]
		if int(card.get("_hand_slot", index)) != detail_slot: continue
		if battle._is_player_input_locked() or not battle._can_play_card(battle.player, card, "player"):
			show_card(index)
			return
		close_detail()
		confirm_in_progress = true
		await battle._on_hand_card_pressed(index, -1, true)
		confirm_in_progress = false
		return
	close_detail()

func show_unit(unit: Dictionary, ally: bool) -> void:
	var definition: Dictionary = battle.main.card_db.get_card(String(unit.get("id", "")))
	dialog(String(unit.get("name", "유닛")), battle._compact_unit_hover_text(unit, definition, ally), unit)

func handle_back() -> bool:
	if is_instance_valid(card_dialog):
		close_detail()
		return true
	if not battle.pending_action.is_empty():
		battle._cancel_ally_selection()
		return true
	if battle.selected_attacker >= 0:
		battle.selected_attacker = -1
		battle._refresh_ui()
		return true
	if battle.battle_detail_visible:
		battle._toggle_battle_details()
		return true
	return false

func refresh_labels() -> void:
	battle.opponent_info.text = "%d/%d" % [battle.opponent.health, battle.opponent.max_health]
	battle.player_info.text = "%d/%d" % [battle.player.health, battle.player.max_health]
	for i in range(hero_bars.size()):
		var side: Dictionary = battle.opponent if i == 0 else battle.player
		hero_bars[i].max_value = side.max_health
		hero_bars[i].value = side.health
	battle.reference_mana_label.text = "마나 %d/%d" % [battle.player.mana, battle.player.max_mana]
	enemy_lane_button.text = "적 전열 ↑ %d/%d" % [battle.opponent.health, battle.opponent.max_health]
	ally_lane_button.text = "아군 전열 ↓ %d/%d" % [battle.player.health, battle.player.max_health]
	center_guidance.text = battle._next_enemy_action_text(true)
	if battle.main.Onboarding.first_battle(battle.main.current_run):
		center_guidance.text = battle._current_battle_guidance_text()
		center_guidance.text = center_guidance.text.replace("손패 카드를 눌러 확인한 뒤 다시 눌러 소환하세요.", "카드를 확인하고 ‘사용’을 눌러 소환하세요.")
	if not battle.pending_action.is_empty():
		center_guidance.text = "아군을 눌러 대상 확정 · 선택 취소 가능"
	elif battle.selected_attacker >= 0:
		center_guidance.text = "공격 후 체력 · 대상을 누르면 공격"
	center_guidance.tooltip_text = center_guidance.text
	intent_detail.text = "적 공격 예고\n" + battle._next_enemy_action_text()
	style_rail_button(battle.recommended_action_button, Color("526170"))
	style_rail_button(battle.race_power_button, Color("b69a60"))
	style_rail_button(battle.end_turn_button, Color("71ac88") if battle._turn_action_state().exhausted else Color("8497ac"))

func style_rail_button(button: Button, accent: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.025, 0.04, 0.06, 0.9)
		style.border_color = accent.darkened(0.5) if state == "disabled" else accent
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_disabled_color", Color("bac1c9"))
	button.add_theme_color_override("font_color", Color("e1e5e9"))

func _exit_tree() -> void:
	session.dispose()
	get_tree().quit_on_go_back = previous_back_quit

func show_help() -> void:
	dialog("전투 도움", center_guidance.text + "\n\n" + battle._next_enemy_action_text() + "\n\n카드를 누르면 효과와 비용을 확인합니다. 사용 버튼으로 확정하세요.\n아군을 누른 뒤 강조된 적을 누르면 공격합니다. 선봉을 처치하면 적 영웅을 공격할 수 있습니다.\n카드 숫자는 공격 / 체력입니다. 유닛을 길게 누르면 효과를 확인합니다.\n대상을 고르는 중에는 선택 취소로 돌아갈 수 있습니다.")

# Camera movement is presentation only; cancelling it never cancels combat.
func cancel_focus() -> void:
	session.cancel_focus()

func _gesture_started(point: Vector2) -> void:
	session.gesture_started(point)

func _gesture_ended() -> void:
	session.gesture_ended()

func _initial_focus() -> void:
	await get_tree().process_frame
	if is_inside_tree():
		# Start with the enemy lane fully visible. Following the player hero here
		# scrolls past the enemy before the player has taken any action.
		await focus_targets([{"player": false, "hero": true}], true)

func resolve_focus(target: Dictionary) -> Control:
	var ally := bool(target.get("player", true))
	var side: Dictionary = battle.player if ally else battle.opponent
	if target.has("unit_id"):
		for i in range(side.field.size()):
			if int(side.field[i].get("battle_unit_id", -1)) == int(target.unit_id):
				return battle._card_action_field_slot(ally, i)
	if target.has("slot"):
		return battle._card_action_field_slot(ally, int(target.slot))
	return battle._hero_target_for_player(ally)

func scroll_for_rect(rect: Rect2) -> int:
	return session.scroll_for_rect(rect)

func focus_targets(targets: Array, immediate: bool = false) -> void:
	await session.focus(targets, immediate)
