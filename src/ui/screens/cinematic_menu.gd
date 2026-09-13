extends RefCounted
const Fantasy = preload("res://src/ui/fantasy_components.gd")
var main: Node
func _init(value: Node) -> void:
	main = value
func build(body: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	body.add_child(header)
	var title := Fantasy.heading(main, "⚜  Card Draft", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	for entry in [["설정", "_show_settings"]]:
		var tab := Fantasy.action(main, entry[0], Callable(main, entry[1]), false)
		tab.size_flags_horizontal = Control.SIZE_SHRINK_END
		tab.custom_minimum_size.x = 110
		header.add_child(tab)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.custom_minimum_size.y = 440
	body.add_child(row)
	var nav := VBoxContainer.new()
	nav.custom_minimum_size.x = 320
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 12)
	row.add_child(nav)
	if not main.current_run.is_empty():
		nav.add_child(Fantasy.action(main, "⚔  이어하기", Callable(main, "_continue_run")))
	nav.add_child(Fantasy.action(main, "새 런 시작", Callable(main, "_start_new_run"), main.current_run.is_empty()))
	for entry in [["도감", "_show_compendium"], ["성장", "_show_meta_upgrade"]]:
		nav.add_child(Fantasy.action(main, entry[0], Callable(main, entry[1]), false))
	var hero := TextureRect.new()
	var portrait := AtlasTexture.new()
	portrait.atlas = load("res://assets/backgrounds/king_commander_v1.png")
	portrait.region = Rect2(0, 0, 1024, 1000)
	hero.texture = portrait
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.custom_minimum_size = Vector2(300, 440)
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hero)
	var info := Fantasy.panel(main, "♛  현재 런", 300)
	row.add_child(info.get_meta("frame"))
	info.add_child(Fantasy.heading(main, "새로운 원정" if main.current_run.is_empty() else "Act %d · %s" % [main.current_run.get("act", 1), main._current_race_meta().get("name", "")], 22))
	info.add_child(main._make_label(main._main_menu_next_action_text(), 16, Color(0.82, 0.85, 0.88)))
	info.add_child(main._make_label("흩어진 전열을 모아\n당신만의 승리를 만드세요.", 16, Color(0.86, 0.81, 0.69)))
	if not main.current_run.is_empty():
		info.add_child(main._make_label("HP %d / %d\n골드 %d\n덱 %d장" % [main.current_run.hp, main.current_run.max_hp, main.current_run.gold, main.current_run.deck_ids.size()], 19, Color(0.85, 0.92, 1)))

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	body.add_child(footer)
	for entry in [["최근 런 기록", "%d회 원정" % main._recent_runs().size()], ["보유 영혼석", str(main.player_profile.get("soul_stones", 0))], ["세력", "인간 · 엘프 · 언데드"]]:
		var box := Fantasy.panel(main, entry[0])
		var frame: Control = box.get_meta("frame")
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		footer.add_child(frame)
		box.add_child(Fantasy.heading(main, entry[1], 20))
