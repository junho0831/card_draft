extends Node2D

const Tokens = preload("res://src/ui/styles/ui_tokens.gd")
var race := "중립"
var card_type := "unit"
var accent := Color.WHITE
var frame: Texture2D
var corner: Texture2D
var size: Vector2:
	get: return (get_parent() as Control).size

func _ready() -> void:
	var type := card_type if card_type in ["spell", "equipment"] else "unit"
	frame = load(Tokens.MATERIAL_PATH + "frame_%s.png" % type)
	var key: String = {"인간": "human", "엘프": "elf", "언데드": "undead", "정령": "spirit"}.get(race, "neutral")
	corner = load(Tokens.MATERIAL_PATH + "corner_%s.png" % key)
	(get_parent() as Control).resized.connect(queue_redraw)

func uses_simple_ornaments() -> bool:
	return size.x < 180.0

func _draw() -> void:
	if frame == null or size.x < 20 or size.y < 20: return
	# Separate source and display margins keep engraved corners unstretched.
	var source := frame.get_size()
	var source_patch := Vector2(source.x * 0.14, source.y * 0.09)
	var patch := Vector2.ONE * minf(18, minf(size.x, size.y) * 0.18)
	var sx := [0.0, source_patch.x, source.x - source_patch.x, source.x]
	var sy := [0.0, source_patch.y, source.y - source_patch.y, source.y]
	var dx := [0.0, patch.x, size.x - patch.x, size.x]
	var dy := [0.0, patch.y, size.y - patch.y, size.y]
	for x in range(3):
		for y in range(3):
			if x == 1 and y == 1: continue
			draw_texture_rect_region(frame, Rect2(dx[x], dy[y], dx[x + 1] - dx[x], dy[y + 1] - dy[y]), Rect2(sx[x], sy[y], sx[x + 1] - sx[x], sy[y + 1] - sy[y]))
	var edge := minf(38, minf(size.x, size.y) * 0.32)
	for point in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		var direction := Vector2(-1 if point.x > 0 else 1, -1 if point.y > 0 else 1)
		draw_set_transform(point, 0, direction)
		draw_texture_rect(corner, Rect2(Vector2.ZERO, Vector2(edge, edge)), false)
	draw_set_transform(Vector2.ZERO)
