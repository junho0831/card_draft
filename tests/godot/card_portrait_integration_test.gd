extends SceneTree

const Storage = preload("res://src/services/game_storage.gd")
const IDS = ["militia", "forest_archer", "bone_soldier", "stone_golem", "mercenary"]
var failures: Array[String] = []

func _init() -> void:
	if not Storage.prepare_test_directory():
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func labels(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is Label: result.append(node.text)
	for child in node.get_children(): result.append_array(labels(child))
	return result

func run() -> void:
	root.size = Vector2i(1280, 720)
	var main = preload("res://src/core/Main.tscn").instantiate()
	main.set_meta("disable_window_mode_changes", true)
	root.add_child(main)
	for i in range(10): await process_frame
	main._clear_screen()
	var row := HBoxContainer.new()
	row.theme = main.theme
	row.position = Vector2(20, 28)
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	for id in IDS:
		var card: Dictionary = main.card_db.get_card(id)
		var before := card.duplicate(true)
		var texture: Texture2D = main.ui.card_art_texture(card)
		check(texture != null and texture.resource_path == "res://assets/card_art/portraits_v2/%s.png" % id, "new portrait selected: " + id)
		check(main.ui.card_art_texture(card) == texture, "cached portrait reused: " + id)
		var upgraded: Dictionary = main.card_db.get_card(id + "_plus")
		check(main.ui.card_art_texture(upgraded) == texture, "upgrade preserves portrait: " + id)
		check(card == before, "art loading leaves card data unchanged: " + id)
		var panel: PanelContainer = main.ui.make_race_card_panel(card, 8)
		panel.custom_minimum_size = Vector2(238, 640)
		check(panel.get_node("RaceOrnaments").z_index == 0, "ornaments cannot float above a modal: " + id)
		row.add_child(panel)
		var face: Control = main.ui.make_card_face(main, card, "collection", {
			"tight": true, "art_size": Vector2(218, 360), "include_stats": true,
			"show_detail": false, "summary_text": card.get("text", "")
		})
		panel.add_child(face)
		var text := labels(face)
		check(text.has(String(card.name)), "name is a live label: " + id)
		check(text.has(str(int(card.cost))), "cost is a live label: " + id)
		check(" ".join(text).contains("%d/%d" % [card.attack, card.health]), "stats are live labels: " + id)
		var upgrade_face: Control = main.ui.make_card_face(main, upgraded, "collection")
		check(" ".join(labels(upgrade_face)).contains("%d/%d" % [upgraded.attack, upgraded.health]), "upgraded stats stay dynamic: " + id)
		upgrade_face.free()
		var thumbnail: TextureRect = main.ui.make_card_art_rect(card, Vector2(218, 108))
		check(thumbnail.texture is AtlasTexture, "focal crop exists before a resize event: " + id)
		root.add_child(thumbnail)
		thumbnail.size = Vector2(218, 108)
		await process_frame
		check(thumbnail.texture is AtlasTexture, "landscape thumbnail uses focal crop: " + id)
		if thumbnail.texture is AtlasTexture:
			var region: Rect2 = thumbnail.texture.region
			check(is_equal_approx(region.size.x / region.size.y, 218.0 / 108.0), "crop matches thumbnail aspect without distortion: " + id)
			check(region.has_point(texture.get_size() * Vector2(0.5, 0.25)), "thumbnail keeps face visible: " + id)
		thumbnail.queue_free()
	check(main.ui.card_art_texture(main.card_db.get_card("small_flame")) is AtlasTexture, "unmodified card retains atlas fallback")
	await create_timer(0.6).timeout
	for child in row.get_children():
		check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(child.get_global_rect()), "portrait panel fits viewport")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Storage.path_for("card_portraits.png"))
	row.queue_free()
	main.queue_free()
	await process_frame
	print("PASS card portrait integration" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
