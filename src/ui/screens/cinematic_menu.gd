extends RefCounted
const Tokens = preload("res://src/ui/styles/ui_tokens.gd")
const Layout = preload("res://src/ui/screens/screen_layout.gd")
var main: Node

func _init(value: Node) -> void:
	main = value

func build(body: VBoxContainer) -> void:
	var viewport: Vector2 = main._layout_viewport_size()
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	body.add_child(header)
	var title: Label = main.ui.make_label("Card Draft", 24, Tokens.TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var currency: Label = Layout.label(main, "영혼석 %s" % main._format_large_number(int(main.player_profile.get("soul_stones", 0))))
	currency.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.add_child(currency)
	for entry in [["도감", "_show_compendium"], ["성장", "_show_meta_upgrade"], ["설정", "_show_settings"]]:
		var button: Button = main.ui.make_dock_action_button(entry[0], "", Tokens.ACCENT_TEAL, false, 72)
		button.custom_minimum_size = Vector2(72, 44)
		button.size_flags_horizontal = Control.SIZE_FILL
		button.pressed.connect(Callable(main, entry[1]))
		header.add_child(button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	# Fit the hero within the visible scroll region above the shared action dock.
	# Header labels use their actual minimum height rather than a viewport guess.
	var dock: Dictionary = Layout.dock(main, body)
	row.custom_minimum_size.y = maxf(150, viewport.y - main.mobile_bottom_inset - 16.0 - header.get_combined_minimum_size().y - body.get_theme_constant("separation") * 2.0 - 4.0)
	body.add_child(row)
	var hero := TextureRect.new()
	hero.texture = load("res://assets/backgrounds/king_commander_v1.png")
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.custom_minimum_size = Vector2(0, 150)
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hero)
	var info := VBoxContainer.new()
	info.custom_minimum_size.x = minf(330, viewport.x * 0.42)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 12)
	row.add_child(info)
	var heading: Label = main.ui.make_label("새로운 원정" if main.current_run.is_empty() else "Act %d · %s" % [main.current_run.get("act", 1), main._current_race_meta().get("name", "")], 24, Tokens.TEXT_PRIMARY)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(heading)
	info.add_child(Layout.label(main, main._main_menu_next_action_text()))
	if not main.current_run.is_empty():
		info.add_child(Layout.label(main, "HP %d/%d · 골드 %d · 덱 %d장" % [main.current_run.hp, main.current_run.max_hp, main.current_run.gold, main.current_run.deck_ids.size()]))
	info.add_child(Layout.label(main, "최근 원정 %d회" % main._recent_runs().size(), true))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(spacer)
	var actions: HBoxContainer = dock.actions
	var start: Button = main.ui.make_dock_action_button("새 런 시작", "", Tokens.ACCENT_GOLD, main.current_run.is_empty(), 140)
	start.size_flags_horizontal = Control.SIZE_SHRINK_END
	start.pressed.connect(Callable(main, "_start_new_run"))
	actions.add_child(start)
	if not main.current_run.is_empty():
		var resume: Button = main.ui.make_dock_action_button("이어하기", "", Tokens.ACCENT_GOLD, true, 140)
		resume.size_flags_horizontal = Control.SIZE_SHRINK_END
		resume.pressed.connect(Callable(main, "_continue_run"))
		actions.add_child(resume)
