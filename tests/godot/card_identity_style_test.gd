extends SceneTree

const Styles = preload("res://src/ui/styles/card_race_styles.gd")
const Storage = preload("res://src/services/game_storage.gd")
var failures: Array[String] = []

func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func run() -> void:
	var races := ["인간", "엘프", "언데드", "정령", "중립"]
	var types := ["unit", "spell", "equipment"]
	for race in races:
		var base := Styles.make_frame_style(race)
		for type in types:
			var style := Styles.make_frame_style(race, Color.TRANSPARENT, 2, 7, 0, Color.TRANSPARENT, type)
			check(style.bg_color == base.bg_color, "type preserves race surface")
			check(style.border_color == Styles.make_frame_style("중립", Color.TRANSPARENT, 2, 7, 0, Color.TRANSPARENT, type).border_color, "race preserves type border")
			check(style.border_width_left >= 6, "type border remains visible")
			var selected := Styles.make_frame_style(race, Color.RED, 2, 7, 0, Color.YELLOW, type)
			check(selected.border_color == style.border_color and selected.bg_color == style.bg_color, "selection does not replace identity")
		for other in races:
			if other != race:
				check(base.bg_color != Styles.make_frame_style(other).bg_color, "race surfaces differ")
	var unit := Styles.type_meta("unit")
	var spell := Styles.type_meta("spell")
	var gear := Styles.type_meta("equipment")
	check(unit.radius != spell.radius and spell.radius != gear.radius and unit.radius != gear.radius, "type shapes differ")
	check(unit.accent != spell.accent and spell.accent != gear.accent and unit.accent != gear.accent, "type colors differ")
	var main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	root.size = Vector2i(1100, 850)
	root.add_child(main)
	for i in range(5): await process_frame
	main._clear_screen()
	var emblem_paths: Array[String] = []
	for race in races:
		var emblem: TextureRect = main.ui.make_race_emblem({"race": race})
		check(emblem.texture != null, "race emblem texture loads")
		if emblem.texture != null:
			check(not emblem_paths.has(emblem.texture.resource_path), "each race has a distinct emblem")
			emblem_paths.append(emblem.texture.resource_path)
		check(emblem.mouse_filter == Control.MOUSE_FILTER_IGNORE, "race emblem does not intercept input")
		check(emblem.size == Vector2(24, 24), "emblem uses requested size instead of source texture dimensions")
		emblem.free()
	var grid := GridContainer.new()
	grid.theme = main.theme
	grid.columns = 5
	grid.position = Vector2(12, 12)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	root.add_child(grid)
	for type in types:
		for race in races:
			var card := {}
			for candidate in main.card_db.card_defs:
				if candidate.get("race") == race and candidate.get("type") == type:
					card = candidate
					break
			if card.is_empty():
				for candidate in main.card_db.card_defs:
					if candidate.get("type") == type:
						card = candidate.duplicate(true)
						card["race"] = race
						card["name"] = "스타일 견본"
						break
			var panel: PanelContainer = main.ui.make_race_card_panel(card, 7)
			check(panel.get_node("RaceOrnaments").race == race, "frame has matching race ornament")
			check(panel.get_node("RaceOrnaments") is Node2D, "ornament stays outside control layout and input")
			panel.custom_minimum_size = Vector2(205, 260)
			grid.add_child(panel)
			var box := VBoxContainer.new()
			panel.add_child(box)
			box.add_child(main.ui.make_card_name_band(main, card, "hand", true, true))
			box.add_child(main.ui.make_card_identity_label(main, card, "hand", true, true))
			box.add_child(main.ui.make_card_art(main, card, Vector2(185, 120)))
			box.add_child(main.ui.make_card_rules_block(main, card, String(card.get("text", "")), "", "hand", true, true))
	for i in range(10): await process_frame
	await create_timer(0.5).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Storage.path_for("card_identity_matrix.png"))
	grid.queue_free()
	main.queue_free()
	await process_frame
	print("PASS card identity styles" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
