extends Node2D

var race := "중립"
var card_type := "unit"
var accent := Color.WHITE
var size: Vector2:
	get: return (get_parent() as Control).size

func _ready() -> void:
	(get_parent() as Control).resized.connect(queue_redraw)

func uses_simple_ornaments() -> bool:
	return size.x < 180.0

func _draw() -> void:
	if size.x < 20 or size.y < 20: return
	var ink := accent.darkened(0.65)
	var shine := accent.lightened(0.55)
	var type_accent: Color = Color("c5cfda")
	match card_type:
		"spell": type_accent = Color("8fdcff")
		"equipment": type_accent = Color("efbd68")
		_: type_accent = Color("d7e3ee")
	# The outer rule makes the card type visible at a glance; race ornaments stay in the corners.
	draw_line(Vector2(8, 4), Vector2(size.x - 8, 4), type_accent, 2.0, true)
	draw_line(Vector2(8, size.y - 4), Vector2(size.x - 8, size.y - 4), type_accent.darkened(0.25), 2.0, true)
	if card_type == "spell":
		var spell_mark := PackedVector2Array([Vector2(size.x * 0.5, 2), Vector2(size.x * 0.5 + 4, 7), Vector2(size.x * 0.5, 12), Vector2(size.x * 0.5 - 4, 7)])
		draw_colored_polygon(spell_mark, type_accent)
	elif card_type == "equipment":
		draw_line(Vector2(size.x * 0.5 - 8, 7), Vector2(size.x * 0.5 + 8, 7), type_accent, 2.0, true)
		draw_line(Vector2(size.x * 0.5 - 5, size.y - 7), Vector2(size.x * 0.5 + 5, size.y - 7), type_accent, 2.0, true)
	else:
		draw_circle(Vector2(size.x * 0.5, 7), 3.0, type_accent)
		draw_circle(Vector2(size.x * 0.5, size.y - 7), 3.0, type_accent.darkened(0.25))
	# Keep ornamentation inside the frame so card text and input stay unobstructed.
	for x in [3.0, size.x - 3.0]:
		if uses_simple_ornaments(): continue
		draw_line(Vector2(x, 12), Vector2(x, size.y - 12), ink, 1.0, true)
		for fraction in [0.22, 0.5, 0.78]:
			var p := Vector2(x, size.y * fraction)
			match race:
				"엘프":
					for shift in [-5.0, 4.0]:
						var leaf := PackedVector2Array([p + Vector2(-2, shift + 3), p + Vector2(-2, shift - 2), p + Vector2(2, shift - 5), p + Vector2(2, shift)])
						draw_colored_polygon(leaf, ink)
						draw_line(p + Vector2(-1, shift + 1), p + Vector2(1, shift - 3), shine, 1, true)
				"언데드":
					draw_line(p - Vector2(0, 6), p + Vector2(0, 6), ink, 3, true)
					for y in [-6.0, 6.0]:
						draw_circle(p + Vector2(-1, y), 1.5, shine)
						draw_circle(p + Vector2(1, y), 1.5, shine)
				"정령":
					var gem := PackedVector2Array([p + Vector2(0, -7), p + Vector2(2.5, 0), p + Vector2(0, 7), p + Vector2(-2.5, 0)])
					draw_colored_polygon(gem, ink)
					draw_line(p - Vector2(0, 5), p + Vector2(0, 5), shine, 1, true)
				"인간":
					draw_line(p - Vector2(0, 5), p + Vector2(0, 5), ink, 2, true)
					draw_line(p - Vector2(2, 2), p + Vector2(2, -2), ink, 2, true)
					draw_circle(p + Vector2(0, 5), 1.5, shine)
				_:
					draw_circle(p, 2.5, ink)
					draw_circle(p - Vector2(0.5, 0.5), 1.2, shine)
	for y in [3.0, size.y - 3.0]:
		if uses_simple_ornaments(): continue
		var center := Vector2(size.x * 0.5, y)
		if race == "인간":
			var crown := PackedVector2Array([center + Vector2(-8, -2), center + Vector2(-4, 0), center + Vector2(0, -3), center + Vector2(4, 0), center + Vector2(8, -2), center + Vector2(6, 3), center + Vector2(-6, 3)])
			draw_colored_polygon(crown, ink)
		else:
			draw_line(center - Vector2(10, 0), center + Vector2(10, 0), ink, 1, true)
			var crest := PackedVector2Array([center + Vector2(-5, 0), center + Vector2(0, -2.5), center + Vector2(5, 0), center + Vector2(0, 2.5)])
			draw_colored_polygon(crest, ink)
			draw_circle(center, 1, shine)
	for corner in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		var direction := Vector2(-1 if corner.x > 0 else 1, -1 if corner.y > 0 else 1)
		draw_set_transform(corner + direction, 0, direction)
		_draw_corner(ink, shine)
	draw_set_transform(Vector2.ZERO)

func _draw_corner(ink: Color, shine: Color) -> void:
	var length := minf(27, size.x * 0.28)
	var plate := PackedVector2Array([Vector2.ZERO, Vector2(length, 0), Vector2(length - 4, 5), Vector2(5, 5), Vector2(5, length - 4), Vector2(0, length)])
	draw_colored_polygon(plate, ink)
	draw_polyline(PackedVector2Array([Vector2(1, length - 2), Vector2(1, 1), Vector2(length - 2, 1)]), shine, 1, true)
	match race:
		"엘프":
			for vertical in [false, true]:
				var leaf := PackedVector2Array([Vector2(4, 3), Vector2(9, 1), Vector2(length - 2, 2), Vector2(11, 5)])
				if vertical:
					for i in range(leaf.size()): leaf[i] = Vector2(leaf[i].y, leaf[i].x)
				draw_colored_polygon(leaf, accent)
				draw_line(leaf[0], leaf[2], shine, 1, true)
		"언데드":
			draw_circle(Vector2(3, 3), 2.7, shine)
			draw_circle(Vector2(2, 2.5), 0.8, ink)
			draw_circle(Vector2(4, 2.5), 0.8, ink)
			for offset in [8.0, 12.0, 16.0]:
				if offset >= length - 1: continue
				draw_line(Vector2(offset - 2, 1), Vector2(offset, 4), accent, 1.5, true)
				draw_line(Vector2(1, offset - 2), Vector2(4, offset), accent, 1.5, true)
		"정령":
			for p in [Vector2(3, 3), Vector2(length - 6, 2.5), Vector2(2.5, length - 6)]:
				var crystal := PackedVector2Array([p + Vector2(0, -2), p + Vector2(2, 0), p + Vector2(0, 2), p + Vector2(-2, 0)])
				draw_colored_polygon(crystal, accent)
				draw_line(p - Vector2(0, 2), p + Vector2(0, 2), shine, 1, true)
		"인간":
			var shield := PackedVector2Array([Vector2(1, 1), Vector2(5, 1), Vector2(5, 4), Vector2(3, 6), Vector2(1, 4)])
			draw_colored_polygon(shield, accent)
			draw_line(Vector2(3, 1), Vector2(3, 4), shine, 1, true)
			draw_line(Vector2(7, 3), Vector2(length - 4, 3), accent, 2, true)
			draw_line(Vector2(3, 7), Vector2(3, length - 4), accent, 2, true)
		_:
			for p in [Vector2(3, 3), Vector2(length - 5, 2.5), Vector2(2.5, length - 5)]:
				draw_circle(p, 1.7, shine)
				draw_line(p - Vector2(1, 0), p + Vector2(1, 0), ink, 1, true)
