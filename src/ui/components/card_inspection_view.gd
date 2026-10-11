extends Control
## A single cached card face; only its projection is animated, never game state.
const EFFECT = preload("res://src/ui/shaders/card_inspection.gdshader")
var target_tilt := Vector2.ZERO
var tilt := Vector2.ZERO
var pointer := -1
var effect: ShaderMaterial
var capture: SubViewport

func setup(face: Control, display_size := Vector2(300, 470), face_size := Vector2(284, 396)) -> void:
	name = "CardInspectionView"
	custom_minimum_size = display_size
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "좌우로 기울이기 · 위아래로 스크롤"
	capture = SubViewport.new()
	# One cached face at 2x resolution keeps text clear on high-density phones.
	capture.size = Vector2i(face_size * 2.0)
	capture.transparent_bg = true
	capture.disable_3d = true
	capture.gui_disable_input = true
	capture.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(capture)
	face.custom_minimum_size = face_size
	face.size = face_size
	face.scale = Vector2(capture.size) / face_size
	capture.add_child(face)
	var surface := TextureRect.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	surface.texture = capture.get_texture()
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect = ShaderMaterial.new()
	effect.shader = EFFECT
	effect.set_shader_parameter("edge_color", face.get_meta("type_edge_color", Color.WHITE))
	surface.material = effect
	add_child(surface)
	mouse_exited.connect(_release)
	set_process(false)
	call_deferred("_refresh_face")

func _refresh_face() -> void:
	await get_tree().process_frame
	if is_instance_valid(capture): capture.render_target_update_mode = SubViewport.UPDATE_ONCE

func _aim(point: Vector2) -> void:
	target_tilt = ((point / size - Vector2(0.5, 0.5)) * 0.65).clamp(Vector2(-0.3, -0.3), Vector2(0.3, 0.3))
	set_process(true)

func _release() -> void:
	pointer = -1
	target_tilt = Vector2.ZERO
	set_process(true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and pointer == -1:
			pointer = event.index
			_aim(event.position)
		elif event.index == pointer: _release()
		accept_event()
	elif event is InputEventScreenDrag and event.index == pointer:
		_aim(event.position)
		accept_event()
	elif event is InputEventMouseMotion and pointer == -1:
		_aim(event.position)
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			return
		if not event.pressed: _release()
		accept_event()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_SCROLL_BEGIN]: _release()

func _process(delta: float) -> void:
	tilt = tilt.lerp(target_tilt, 1.0 - exp(-14.0 * delta))
	if tilt.distance_to(target_tilt) < 0.001:
		tilt = target_tilt
		set_process(false)
	if effect != null: effect.set_shader_parameter("tilt", tilt)

static func make_face(main: Node, card: Dictionary) -> Control:
	return preload("res://src/ui/components/card_view.gd").make_inspection_face(main, card)
