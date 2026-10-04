extends Control
const ButtonMetrics = preload("res://src/ui/styles/button_metrics.gd")
const SharedStyles = preload("res://src/ui/styles/ui_styles.gd")
const Tokens = preload("res://src/ui/styles/ui_tokens.gd")
## Shared landscape board presentation. Input policy and combat remain in BattleScreen.
var battle
var session
var card_dialog: Control
var confirm_button: Button
var detail_slot := -1
var confirm_in_progress := false
var unit_width := 80.0
var hand_size := Vector2(80, 112)
var hero_width: float = 80.0
var rail_width: float = 120.0
var compact_board: bool = true
var field_height := 72.0
var cancel_button: Button
var hero_bars: Array[ProgressBar] = []
var enemy_hero_hint: Label
var phase_badge: Label
var center_guidance: Label
var intent_detail: Label
var hud_hp_label: Label
var hud_gold_label: Label
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
	compact_board = battle._is_landscape_phone()
	hero_width = 80.0 if compact_board else 112.0
	rail_width = 120.0 if compact_board else 168.0
	unit_width = minf(104 if compact_board else 136, floorf((viewport.x - rail_width - 36 - hero_width - 32) / 5.0))
	hand_size = Vector2(82, 110) if compact_board else Vector2(116, 160)
	field_height = maxf(60, floorf((viewport.y - 228) / 2.0)) if compact_board else clampf(floorf((viewport.y - hand_size.y - 220) / 2.0), 128, 172)
	old_root.hide()
	action_panel.hide()
	battle.main.mobile_bottom_inset = 0
	battle.main._apply_root_layout()
	var background := ColorRect.new()
	background.color = Color(Tokens.SURFACE, 0.4)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 4)
	margin.add_child(page)
	var header_panel := PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", surface_style(Tokens.ACCENT_GOLD))
	page.add_child(header_panel)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 36
	header.add_theme_constant_override("separation", 8)
	header_panel.add_child(header)
	var title := label("전투 · " + String(battle.opponent.name), 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(title)
	phase_badge = label("", 14)
	phase_badge.custom_minimum_size.x = 64
	phase_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(phase_badge)
	battle.reference_mana_label = label("", 18)
	battle.reference_mana_label.clip_text = true
	var run_hud := HBoxContainer.new()
	run_hud.name = "RunHud"
	run_hud.add_theme_constant_override("separation", 4)
	run_hud.size_flags_horizontal = Control.SIZE_SHRINK_END
	if not compact_board:
		hud_hp_label = hud_chip("HP %d/%d" % [int(battle.player.get("health", 0)), int(battle.player.get("max_health", 0))], Tokens.ACCENT_DANGER)
		hud_gold_label = hud_chip("골드 %d" % int(battle.main.current_run.get("gold", 0)), Tokens.ACCENT_GOLD)
		run_hud.add_child(hud_hp_label)
		run_hud.add_child(hud_gold_label)
	header.add_child(run_hud)
	battle.detail_toggle_button.reparent(header)
	battle.detail_toggle_button.visible = battle._uses_tutorial_guidance()
	ButtonMetrics.apply(battle.detail_toggle_button, "compact", 60)
	SharedStyles.apply_role_button(battle.detail_toggle_button, "secondary", Tokens.BORDER, Color.TRANSPARENT, 14)
	header.add_child(action("메뉴", func():
		cancel_focus()
		battle.main._show_main_menu(), "compact"))
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
	board_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	board_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_scroll.add_theme_stylebox_override("panel", surface_style(Tokens.BORDER))
	board.add_child(board_scroll)
	lanes = VBoxContainer.new()
	lanes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lanes.custom_minimum_size.x = maxf(0.0, viewport.x - rail_width - 24.0)
	lanes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lanes.alignment = BoxContainer.ALIGNMENT_CENTER
	lanes.add_theme_constant_override("separation", 4)
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
	var selection_row := HBoxContainer.new()
	selection_row.name = "BattleSelectionSummary"
	selection_row.custom_minimum_size.y = 44
	board.add_child(selection_row)
	center_guidance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_row.add_child(center_guidance)
	intent_detail = label("", 16)
	intent_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle.deck_list_label.get_parent().add_child(intent_detail)
	battle.hand_scroll.reparent(board)
	battle.hand_scroll.set_meta("cancel_tap_on_motion", true)
	battle.hand_scroll.add_theme_stylebox_override("panel", surface_style(Tokens.ACCENT_GOLD))
	battle.hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	battle.hand_scroll.custom_minimum_size = Vector2(0, hand_size.y + 6)
	battle.hand_scroll.size_flags_vertical = Control.SIZE_SHRINK_END
	var rail_panel := PanelContainer.new()
	rail_panel.name = "BattleActionPanel"
	rail_panel.custom_minimum_size.x = rail_width
	rail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail_panel.add_theme_stylebox_override("panel", surface_style(Tokens.ACCENT_GOLD))
	body.add_child(rail_panel)
	var rail := VBoxContainer.new()
	rail.name = "BattleActionRail"
	rail.custom_minimum_size.x = rail_width - 16
	rail.add_theme_constant_override("separation", 6)
	rail_panel.add_child(rail)
	var rail_space := Control.new()
	rail_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail.add_child(rail_space)
	battle.reference_mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rail.add_child(battle.reference_mana_label)
	battle.recommended_action_button.reparent(header)
	ButtonMetrics.apply(battle.recommended_action_button, "compact", 90)
	battle.recommended_action_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	for button in [battle.race_power_button, battle.end_turn_button]:
		button.reparent(rail)
		ButtonMetrics.apply(button, "action", rail_width)
	var sort_hand_button := action("손패 정리", Callable(battle, "_sort_hand_cards"), "compact")
	sort_hand_button.name = "SortHandButton"
	sort_hand_button.tooltip_text = "같은 카드를 묶고 비용순으로 손패를 정렬합니다."
	rail.add_child(sort_hand_button)
	cancel_button = action("선택 취소", func():
		battle._cancel_ally_selection()
		battle.selected_attacker = -1
		battle._refresh_ui()
		battle._store_battle_snapshot(), "compact")
	selection_row.add_child(cancel_button)
	cancel_button.custom_minimum_size.x = 120

func surface_style(accent: Color) -> StyleBox:
	return SharedStyles.make_textured_panel_style(Tokens.SURFACE_RAISED, accent, 0, accent == Tokens.ACCENT_GOLD)

func label(value: String, font_size: int = 16) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", Tokens.TEXT_PRIMARY)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func hud_chip(value: String, accent: Color) -> Label:
	var chip := label(value, 12)
	chip.custom_minimum_size = Vector2(72, 28)
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_theme_color_override("font_color", Tokens.TEXT_PRIMARY)
	chip.add_theme_color_override("font_outline_color", Color(Tokens.SURFACE, 0.9))
	chip.add_theme_constant_override("outline_size", 3)
	return chip

func action(value: String, callback: Callable, kind: String = "action") -> Button:
	var button := Button.new()
	button.text = value
	ButtonMetrics.apply(button, kind, 88 if kind == "compact" else 120)
	button.pressed.connect(callback)
	SharedStyles.apply_role_button(button, "secondary", Tokens.BORDER, Color.TRANSPARENT, 14 if kind == "compact" else 16)
	return button

func lane(parent: Control, cards: HBoxContainer, enemy: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.custom_minimum_size.y = field_height
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var hero := Button.new()
	hero.custom_minimum_size = Vector2(hero_width, field_height)
	hero.add_theme_stylebox_override("normal", SharedStyles.make_textured_panel_style(Tokens.SURFACE_RAISED, Tokens.BORDER, 1, false))
	hero.add_theme_stylebox_override("hover", SharedStyles.make_textured_panel_style(Tokens.SURFACE_RAISED, Tokens.ACCENT_GOLD, 2, false))
	hero.add_theme_stylebox_override("pressed", SharedStyles.make_textured_panel_style(Tokens.SURFACE_RAISED, Tokens.ACCENT_GOLD, 2, false))
	hero.clip_text = true
	hero.add_theme_font_size_override("font_size", 16)
	row.add_child(hero)
	hero.clip_contents = true
	var portrait: TextureRect = battle._make_battle_hero_art(int(battle.main.current_run.get("active_enemy", {}).get("art", 0)), Vector2.ZERO, enemy)
	var portrait_size := minf(hero_width, field_height) - 10.0
	portrait.set_anchors_preset(Control.PRESET_CENTER)
	portrait.offset_left = -portrait_size * 0.5
	portrait.offset_top = -portrait_size * 0.5
	portrait.offset_right = portrait_size * 0.5
	portrait.offset_bottom = portrait_size * 0.5
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait_material := ShaderMaterial.new()
	portrait_material.shader = load("res://assets/ui/shaders/circle_portrait.gdshader")
	portrait.material = portrait_material
	hero.add_child(portrait)
	var portrait_ring := Panel.new()
	portrait_ring.name = "HeroPortraitRing"
	portrait_ring.set_anchors_preset(Control.PRESET_CENTER)
	portrait_ring.offset_left = -portrait_size * 0.5
	portrait_ring.offset_top = -portrait_size * 0.5
	portrait_ring.offset_right = portrait_size * 0.5
	portrait_ring.offset_bottom = portrait_size * 0.5
	portrait_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color.TRANSPARENT
	ring_style.border_color = Tokens.ACCENT_GOLD if not enemy else Tokens.ACCENT_DANGER
	ring_style.set_border_width_all(3)
	ring_style.set_corner_radius_all(999)
	portrait_ring.add_theme_stylebox_override("panel", ring_style)
	hero.add_child(portrait_ring)
	var title := label("적 영웅" if enemy else "내 영웅", 14)
	title.name = "HeroTitle"
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 4
	title.offset_right = -4
	title.offset_top = 5
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_constant_override("outline_size", 6)
	hero.add_child(title)
	if enemy:
		enemy_hero_hint = title
	var bar := ProgressBar.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -6
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(bar)
	hero_bars.append(bar)
	var hp := label("", 20)
	hp.name = "HeroHealth"
	hp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hp.offset_bottom = -7
	hp.add_theme_color_override("font_outline_color", Color.BLACK)
	hp.add_theme_color_override("font_color", Color.WHITE)
	hp.add_theme_constant_override("outline_size", 5)
	hero.add_child(hp)
	if enemy:
		battle.opponent_hero_target = hero
		battle.hero_attack_button = hero
		battle.opponent_hero_target_hp_label = hp
		battle.enemy_hero_hp_label = hp
		battle.opponent_info = hp
		hero.pressed.connect(func(): battle._attack_opponent_hero())
		outline(hero, Color(1.0, 0.35, 0.3), 1, 3, "TargetBorder")
	else:
		battle.player_hero_target = hero
		battle.player_hero_target_hp_label = hp
		battle.player_hero_hp_label = hp
		battle.player_info = hp
	cards.reparent(row)
	cards.custom_minimum_size = Vector2(0, field_height)
	cards.add_theme_constant_override("separation", 4)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.alignment = BoxContainer.ALIGNMENT_CENTER

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
	text.add_theme_color_override("font_color", Color.WHITE)
	text.add_theme_constant_override("line_spacing", 0)
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
	return tile(unit, status, unit_width, accent, field_height, true)

func tile(card: Dictionary, bottom: String, width: float, accent: Color, height: float = 72, field: bool = false) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(width, height)
	button.size = button.custom_minimum_size
	button.clip_contents = true
	button.add_theme_stylebox_override("normal", battle.BATTLE_STYLES.make_card_frame(accent, 2))
	if card.is_empty():
		button.add_theme_stylebox_override("disabled", SharedStyles.make_style_box(Tokens.SURFACE_RAISED, Tokens.BORDER, 1, 4))
		return button
	var kind := card_kind(card)
	button.set_meta("card_kind", kind)
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, battle.main.ui.make_race_card_style(card, Color.TRANSPARENT, 3, 2, 0.12 if state == "hover" else 0.0))
	var race_band: Color = battle.main.ui.make_race_band_style(card).bg_color
	var art: TextureRect = battle.main._make_card_art_rect(card, Vector2.ZERO)
	art.name = "Illustration"
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 7
	art.offset_right = -7
	art.offset_top = 6
	art.offset_bottom = -6
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if field:
		art.texture = portrait_texture(card, Vector2(width - 6, height - 24))
		art.anchor_bottom = 0
		art.offset_bottom = height - 24
	button.add_child(art)
	var name_label := stamp(button, "CardName", String(card.get("name", "")), Vector2(7, height - 43), Vector2(width - 14, 20), race_band, 12 if compact_board else 14)
	if field:
		if compact_board:
			name_label.hide()
			button.get_node("CardNameBand").hide()
		else:
			name_label.position.y = height - 80
			button.get_node("CardNameBand").position.y = height - 80
			name_label.add_theme_font_size_override("font_size", 14)
	if card.has("attack"):
		stamp(button, "Attack", str(int(card.attack)), Vector2(3, height - 24), Vector2(26, 22), Color(0.48, 0.12, 0.09))
		stamp(button, "Health", str(int(card.get("health", 0))), Vector2(width - 29, height - 24), Vector2(26, 22), Color(0.08, 0.25, 0.48))
	if not bottom.is_empty():
		stamp(button, "Status", bottom, Vector2(3, 3), Vector2(width - 6, 19), Color(Tokens.SURFACE, 0.9), 12)
	var type_border := Panel.new()
	type_border.name = "TypeBorder"
	type_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	type_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var type_style: StyleBoxFlat = battle.main.ui.make_race_card_style(card, Color.TRANSPARENT, 3, 2)
	type_style.draw_center = false
	type_border.add_theme_stylebox_override("panel", type_style)
	button.add_child(type_border)
	battle.main.ui.decorate_card_frame(button, card)
	var icon := TextureRect.new()
	icon.name = "TypeIcon"
	icon.texture = load("res://assets/ui/fantasy/type_%s.svg" % kind)
	icon.position = Vector2(width - 24, 4)
	icon.size = Vector2(19, 19)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	if field: icon.hide()
	var emblem: TextureRect = battle.main.ui.make_race_emblem(card, 20)
	emblem.position = Vector2((width - 20) * 0.5, 25 if field else 28)
	button.add_child(emblem)
	button.tooltip_text = {"unit":"유닛", "damage":"피해·저주 주문", "support":"회복·지원 주문", "equipment":"장비"}[kind]
	return button

func field_slot(side: Dictionary, index: int, ally: bool) -> Control:
	if index >= side.field.size():
		var empty := field_card({}, "", Color(0.2, 0.27, 0.33))
		if not ally and not compact_board:
			battle._configure_enemy_field_attack(empty)
			for state: String in ["normal", "hover", "pressed"]:
				empty.add_theme_stylebox_override(state, SharedStyles.make_style_box(Tokens.SURFACE_RAISED, Tokens.ACCENT_GOLD if state != "normal" else Tokens.BORDER, 1, 4))
			return empty
		empty.disabled = true
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return empty
	var unit: Dictionary = side.field[index]
	var ready: bool = not battle._is_player_input_locked() and (bool(unit.get("can_attack", false)) or not battle.pending_action.is_empty()) if ally else not battle._is_player_input_locked() and battle.selected_attacker >= 0
	var accent := Color(0.3, 0.38, 0.48)
	if ready:
		accent = Color(0.3, 1.0, 0.65) if ally else Color(1.0, 0.35, 0.3)
	if ally and battle.selected_attacker == index:
		accent = Color(1.0, 0.8, 0.25)
	var status: String = ("대상 선택" if not battle.pending_action.is_empty() else battle._unit_attack_status(unit, index).label) if ally else ("선봉" if unit.get("is_vanguard", false) else "")
	var prediction: Dictionary = {}
	if not ally and ready:
		var attacker: Dictionary = battle._selected_player_attacker()
		prediction = battle._predict_unit_attack(attacker, unit, battle.player, battle.opponent)
	var button := field_card(unit, status, accent)
	if ally and battle.selected_attacker == index:
		outline(button, Color(1.0, 0.8, 0.25), 4, 2, "SelectionBorder")
	elif ready:
		outline(button, Color(0.3, 1.0, 0.65) if ally else Color(1.0, 0.35, 0.3), 4, 1, "TargetBorder")
	elif ally:
		button.get_node("Illustration").modulate = Color(0.65, 0.65, 0.65)
	if not prediction.is_empty():
		button.set_meta("attack_prediction", prediction)
		for node_name in ["Attack", "AttackBand", "Health", "HealthBand"]:
			var node := button.get_node_or_null(node_name)
			if node != null: node.hide()
		stamp(button, "CombatPrediction", "적 %d→%d\n내 %d→%d" % [int(unit.health), int(prediction.defender_health), int(battle._selected_player_attacker().get("health", 0)), int(prediction.attacker_health)], Vector2(2, field_height - 56), Vector2(unit_width - 4, 54), Tokens.SURFACE, 14 if compact_board else 16)
		if prediction.defender_health <= 0:
			button.get_node("CardName").size.x = unit_width - 38
			stamp(button, "Lethal", "처치", Vector2(2, 2), Vector2(32, 18), Color(0.45, 0.08, 0.05), 12)
		button.tooltip_text = battle._unit_attack_preview_text(unit, prediction) + " (후속 사망·장비 효과 별도)"
		if int(prediction.attacker_health) <= 0:
			button.tooltip_text += " · 내 유닛 사망"
	button.pressed.connect(func():
		if button.get_meta("hold_consumed", false) or battle._is_player_input_locked(): return
		if ally: battle._on_player_unit_pressed(index)
		else: battle._on_opponent_unit_pressed(index)
	)
	_bind_hold(button, func(): show_unit(unit, ally))
	return button

func _bind_hold(button: Button, inspect: Callable) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 0.4
	button.add_child(timer)
	battle.main.touch_scroll_router.swipe_started.connect(timer.stop)
	timer.timeout.connect(func():
		button.set_meta("hold_consumed", true)
		inspect.call()
	)
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				button.set_meta("hold_consumed", false)
				button.set_meta("hold_origin", event.position)
				timer.start()
			else: timer.stop()
		elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if event.position.distance_to(button.get_meta("hold_origin", event.position)) >= battle.main.touch_scroll_router.SWIPE_THRESHOLD:
				timer.stop()
				button.set_meta("hold_consumed", true)
	)

func render_hand() -> void:
	for i in range(battle.player.hand.size()):
		var card: Dictionary = battle.player.hand[i]
		var cost: int = battle.main.relic_service.modify_card_cost(battle.main.current_run, battle.battle_state, card, "player")
		var playable: bool = not battle._is_player_input_locked() and battle._can_play_card(battle.player, card, "player")
		var button := tile(card, "", hand_size.x, Color(0.25, 0.7, 0.6) if playable else Color(0.3, 0.36, 0.42), hand_size.y)
		stamp(button, "Cost", str(cost), Vector2(3, 3), Vector2(26, 26), Color(0.06, 0.26, 0.55), 18)
		if int(card.get("_hand_slot", i)) == battle.selected_hand_slot:
			outline(button, Color(1.0, 0.8, 0.25), 4, 2, "SelectionBorder")
		if playable:
			stamp(button, "Playable", "◆", Vector2(hand_size.x - 20, 27), Vector2(16, 16), Tokens.SURFACE, 12)
		button.set_meta("hand_slot", int(card.get("_hand_slot", i)))
		if not playable: button.get_node("Illustration").modulate = Color(0.42, 0.42, 0.42)
		button.pressed.connect(func():
			if button.get_meta("hold_consumed", false): return
			battle._on_hand_card_pressed(i)
		)
		if battle._uses_touch_hand_selection():
			_bind_hold(button, func(): show_card(i))
		else:
			button.gui_input.connect(Callable(battle, "_on_hand_card_gui_input").bind(i))
			button.tooltip_text = battle._compact_card_hover_text(card, cost, playable)
			button.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
					show_card(i)
					button.accept_event()
			)
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
	if battle != null: battle.call_deferred("_check_no_actions_loss")

func dialog(title: String, text: String, card: Dictionary = {}, custom_content: Control = null) -> HBoxContainer:
	cancel_focus()
	close_detail()
	card_dialog = Control.new()
	card_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_dialog.z_index = 350
	battle.main.modal_layer.add_child(card_dialog)
	var shade := ColorRect.new()
	shade.color = Tokens.SURFACE
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
	var heading_row := HBoxContainer.new()
	panel.add_child(heading_row)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(heading)
	var close := action("닫기", close_detail)
	heading_row.add_child(close)
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
	if custom_content != null:
		scroll.add_child(custom_content)
	else:
		var description := label(text, 18)
		description.add_theme_constant_override("line_spacing", 5)
		description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(description)
	var buttons := HBoxContainer.new()
	right.add_child(buttons)
	buttons.alignment = BoxContainer.ALIGNMENT_END
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
	SharedStyles.apply_role_button(confirm_button, "primary", Tokens.ACCENT_GOLD, Color.TRANSPARENT, 16)
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
	var text: String = battle._compact_unit_hover_text(unit, definition, ally)
	var attacker: Dictionary = battle._selected_player_attacker()
	if not ally and not attacker.is_empty() and bool(attacker.get("can_attack", false)):
		text += "\n\n현재 전장 기준\n" + battle._unit_attack_preview_text(unit, battle._predict_unit_attack(attacker, unit, battle.player, battle.opponent))
		text += "\n사망 효과·장비 등 후속 부가효과는 미확정"
	dialog(String(unit.get("name", "유닛")), text, unit)

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
		battle._store_battle_snapshot()
		return true
	if battle.battle_detail_visible:
		battle._toggle_battle_details()
		return true
	return false

func refresh_labels() -> void:
	battle.recommended_action_button.text = battle._recommended_action_text()
	phase_badge.text = battle._battle_phase_state().badge
	phase_badge.add_theme_color_override("font_color", Tokens.TEXT_SECONDARY if battle.current_player != "player" else Tokens.ACCENT_GOLD)
	if is_instance_valid(enemy_hero_hint):
		enemy_hero_hint.text = "선봉 보호" if battle._enemy_vanguard_blocks_hero() else "적 영웅"
		battle.opponent_hero_target.get_node("TargetBorder").visible = battle.selected_attacker >= 0 and not battle._is_player_input_locked() and battle.pending_action.is_empty() and not battle._enemy_vanguard_blocks_hero()
		battle.opponent_hero_target.tooltip_text = "%s · %d/%d\n%s" % [battle.opponent.name, battle.opponent.health, battle.opponent.max_health, battle._hero_attack_target_badge_text() if battle.selected_attacker >= 0 else "아군을 선택한 뒤 이 영웅을 누르면 공격합니다."]
	battle.opponent_info.text = str(battle.opponent.health)
	battle.player_info.text = str(battle.player.health)
	for i in range(hero_bars.size()):
		var side: Dictionary = battle.opponent if i == 0 else battle.player
		hero_bars[i].max_value = side.max_health
		hero_bars[i].value = side.health
	battle.reference_mana_label.add_theme_color_override("font_color", Tokens.ACCENT_TEAL)
	battle.reference_mana_label.text = "◆ %d/%d" % [battle.player.mana, battle.player.max_mana]
	if is_instance_valid(hud_hp_label):
		hud_hp_label.text = "HP %d/%d" % [battle.player.health, battle.player.max_health]
	if is_instance_valid(hud_gold_label):
		hud_gold_label.text = "골드 %d" % int(battle.main.current_run.get("gold", 0))
	cancel_button.disabled = battle.pending_action.is_empty() and battle.selected_attacker < 0
	if not cancel_button.disabled:
		battle.end_turn_button.text = "턴 종료"
		battle.end_turn_button.disabled = true
	center_guidance.text = battle._next_enemy_action_text(true)
	if not battle.pending_action.is_empty() or Time.get_ticks_msec() < battle.interaction_hint_until or battle.main.Onboarding.first_battle(battle.main.current_run):
		center_guidance.text = battle._current_battle_guidance_text()
	elif battle.current_player == "player" and not battle._is_player_input_locked() and battle._ready_player_attacker_indexes().is_empty():
		center_guidance.text = "할 수 있는 행동이 없습니다 · 턴 종료" if battle._turn_action_state().exhausted else "카드·필살기 사용 또는 턴 종료"
	if battle.selected_attacker >= 0 and battle.pending_action.is_empty() and Time.get_ticks_msec() >= battle.interaction_hint_until:
		center_guidance.text = String(battle._selected_player_attacker().get("name", "아군")) + " 선택 · 공격 후 체력 미리보기"
	center_guidance.text = center_guidance.text.replace("손패 카드를 눌러 확인한 뒤 다시 눌러 소환하세요.", "손패 카드를 누르면 바로 소환합니다.")
	center_guidance.tooltip_text = center_guidance.text
	intent_detail.text = battle._battle_choice_detail_text()
	SharedStyles.apply_role_button(battle.recommended_action_button, "secondary", Tokens.BORDER, Color.TRANSPARENT, 14)
	SharedStyles.apply_role_button(battle.race_power_button, "power", Tokens.ACCENT_TEAL, Color.TRANSPARENT, 16)
	SharedStyles.apply_role_button(battle.end_turn_button, "primary", Tokens.ACCENT_GOLD, Color.TRANSPARENT, 16)

func _exit_tree() -> void:
	session.dispose()
	get_tree().quit_on_go_back = previous_back_quit

func show_help() -> void:
	if not battle._uses_tutorial_guidance():
		battle._show_battle_choice_details()
		return
	dialog("전투 도움", center_guidance.text + "\n\n" + battle._next_enemy_action_text() + "\n\n카드를 누르면 바로 사용합니다. 길게 누르면 효과와 비용을 확인합니다.\n아군을 누른 뒤 강조된 적을 누르면 공격합니다. 선봉을 처치하면 적 영웅을 공격할 수 있습니다.\n카드 숫자는 공격 / 체력입니다. 유닛을 길게 누르면 효과를 확인합니다.\n대상을 고르는 중에는 선택 취소로 돌아갈 수 있습니다.")

# Camera movement is presentation only; cancelling it never cancels combat.
func cancel_focus() -> void:
	session.cancel_focus()

func _gesture_started(point: Vector2) -> void:
	session.gesture_started(point)

func _gesture_ended() -> void:
	session.gesture_ended()

func _initial_focus() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	await get_tree().process_frame
	if is_inside_tree() and not is_queued_for_deletion():
		await focus_targets([{"player": battle.current_player == "player", "hero": true}], true)

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

func focus_targets(targets: Array, immediate: bool = false, manual: bool = false) -> void:
	pass
