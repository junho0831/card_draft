extends RefCounted
## Own a swipe before child buttons/card handlers can interpret it as a click.
signal gesture_started(point: Vector2)
signal swipe_started
signal gesture_ended
var tap_blocked := false

func block_current_tap() -> void:
	tap_blocked = true
	suppress_mouse = true

const SWIPE_THRESHOLD := 12.0
var finger := -1
var origin := Vector2.ZERO
var candidates: Array[ScrollContainer] = []
var selected: ScrollContainer
var horizontal := false
var swiping := false
var suppress_mouse := false

func handle(event: InputEvent, surface: Control) -> bool:
	if event.device == -1 and (event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag):
		if event is InputEventMouseButton and event.pressed and finger == -1:
			suppress_mouse = false
		return suppress_mouse
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
		gesture_started.emit(event.position)
		gesture_ended.emit()
		return false
	var pressed := false
	var released := false
	var moving := false
	var point := Vector2.ZERO
	var relative := Vector2.ZERO
	if event is InputEventScreenTouch:
		if finger != -1 and event.index != finger:
			return swiping
		pressed = event.pressed
		released = not event.pressed
		point = event.position
		if pressed:
			finger = event.index
	elif event is InputEventScreenDrag:
		if event.index != finger:
			return false
		moving = true
		point = event.position
		relative = event.relative
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not event.pressed
		point = event.position
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		moving = true
		point = event.position
		relative = event.relative
	else:
		return false
	if pressed:
		return _begin_gesture(point, surface)
	if released:
		return _end_gesture()
	if moving:
		return _move_gesture(point, relative)
	return false

func _begin_gesture(point: Vector2, surface: Control) -> bool:
	tap_blocked = false
	suppress_mouse = false
	swiping = false
	selected = null
	origin = point
	candidates.clear()
	var hit := _hit(surface, point)
	while hit != null:
		if hit is ScrollContainer:
			candidates.append(hit)
		hit = hit.get_parent() as Control
	gesture_started.emit(point)
	return tap_blocked

func _end_gesture() -> bool:
	var consumed := swiping or tap_blocked
	if is_instance_valid(selected):
		selected.propagate_notification(Control.NOTIFICATION_SCROLL_END)
	finger = -1
	selected = null
	swiping = false
	candidates.clear()
	gesture_ended.emit()
	return consumed

func _move_gesture(point: Vector2, relative: Vector2) -> bool:
	if not swiping:
		var distance := point - origin
		if distance.length() < SWIPE_THRESHOLD:
			return not candidates.is_empty()
		horizontal = absf(distance.x) > absf(distance.y)
		for candidate in candidates:
			if not is_instance_valid(candidate):
				continue
			var mode: int = candidate.horizontal_scroll_mode if horizontal else candidate.vertical_scroll_mode
			var bar: ScrollBar = candidate.get_h_scroll_bar() if horizontal else candidate.get_v_scroll_bar()
			if mode != ScrollContainer.SCROLL_MODE_DISABLED and bar.max_value > bar.page:
				selected = candidate
				break
		if selected == null:
			return false
		swiping = true
		swipe_started.emit()
		suppress_mouse = true
		selected.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	if is_instance_valid(selected):
		if horizontal:
			selected.scroll_horizontal -= int(round(relative.x))
		else:
			selected.scroll_vertical -= int(round(relative.y))
	return true

func _hit(node: Control, point: Vector2) -> Control:
	if not node.is_visible_in_tree():
		return null
	var inside := node.get_global_rect().has_point(point)
	if node.clip_contents and not inside:
		return null
	var children := node.get_children()
	children.reverse()
	for child in children:
		if child is Control:
			var found := _hit(child, point)
			if found != null:
				return found
	if inside and node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return node
	return null
