extends Control
class_name ArcaneButtonOrnament

var accent_color := Color(0.32, 0.68, 0.72, 1.0)
var active := false
var hovered := false
var pressed := false

func configure(color: Color, is_active: bool) -> void:
	accent_color = color
	active = is_active
	queue_redraw()

func set_hovered(value: bool) -> void:
	hovered = value
	queue_redraw()

func set_pressed(value: bool) -> void:
	pressed = value
	queue_redraw()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x < 52.0 or size.y < 24.0:
		return
	var glow: Color = accent_color.lightened(0.18 if hovered else 0.04)
	var alpha: float = 0.9 if active else (0.72 if hovered else 0.48)
	if pressed:
		alpha *= 0.72
	glow.a = alpha
	var edge := Color(glow.r, glow.g, glow.b, alpha * 0.54)
	var mid_y: float = size.y * 0.5
	var inset := 7.0
	var cut: float = minf(13.0, size.y * 0.24)

	draw_line(Vector2(cut + 8.0, inset), Vector2(size.x - cut - 8.0, inset), edge, 1.0, true)
	draw_line(Vector2(cut + 8.0, size.y - inset), Vector2(size.x - cut - 8.0, size.y - inset), Color(edge.r, edge.g, edge.b, edge.a * 0.52), 1.0, true)
	draw_line(Vector2(inset, cut + 3.0), Vector2(inset, size.y - cut - 3.0), edge, 1.0, true)
	draw_line(Vector2(size.x - inset, cut + 3.0), Vector2(size.x - inset, size.y - cut - 3.0), edge, 1.0, true)

	var diamond_size: float = 3.5 if active else 2.5
	for x_value in [inset, size.x - inset]:
		var x := float(x_value)
		var diamond := PackedVector2Array([
			Vector2(x, mid_y - diamond_size),
			Vector2(x + diamond_size, mid_y),
			Vector2(x, mid_y + diamond_size),
			Vector2(x - diamond_size, mid_y),
		])
		draw_colored_polygon(diamond, glow)

	if active and size.x >= 120.0:
		var center_x := size.x * 0.5
		draw_line(Vector2(center_x - 13.0, inset), Vector2(center_x - 4.0, inset), glow, 1.5, true)
		draw_line(Vector2(center_x + 4.0, inset), Vector2(center_x + 13.0, inset), glow, 1.5, true)
		var center_mark := PackedVector2Array([
			Vector2(center_x, inset - 2.5),
			Vector2(center_x + 3.0, inset),
			Vector2(center_x, inset + 2.5),
			Vector2(center_x - 3.0, inset),
		])
		draw_colored_polygon(center_mark, glow)

static func attach_to(button: Button, color: Color, is_active: bool) -> void:
	var ornament := button.get_node_or_null("ArcaneButtonOrnament") as ArcaneButtonOrnament
	if ornament == null:
		ornament = ArcaneButtonOrnament.new()
		ornament.name = "ArcaneButtonOrnament"
		ornament.z_index = 20
		button.add_child(ornament)
		button.mouse_entered.connect(ornament.set_hovered.bind(true))
		button.mouse_exited.connect(ornament.set_hovered.bind(false))
		button.button_down.connect(ornament.set_pressed.bind(true))
		button.button_up.connect(ornament.set_pressed.bind(false))
	ornament.configure(color, is_active)
