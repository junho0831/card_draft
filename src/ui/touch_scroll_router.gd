extends RefCounted
## Own a swipe before child buttons/card handlers can interpret it as a click.
signal gesture_started(point: Vector2)
signal swipe_started
signal gesture_ended
var tap_blocked := false

func block_current_tap() -> void:
	tap_blocked = true
	suppress_mouse = true

const SWIPE_THRESHOLD := 8.0
const COAST_SECONDS := 0.18
var finger := -1
var origin := Vector2.ZERO
var candidates: Array[ScrollContainer] = []
var selected: ScrollContainer
var horizontal := false
var swiping := false
var suppress_mouse := false
var coast: Tween
var velocity := 0.0
var last_motion_msec := 0
var cancel_on_motion := false

func handle(event: InputEvent, surface: Control) -> bool:
	if event.device == -1 and (event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag):
		if event is InputEventMouseButton and event.pressed and finger == -1:
			suppress_mouse = false
		return suppress_mouse
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
		return _scroll_at(event.position, Vector2(0, (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1) * 48 * event.factor), surface)
	if event is InputEventPanGesture:
		return _scroll_at(event.position, event.delta * 16.0, surface)
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
	if is_instance_valid(coast):
		coast.kill()
	velocity = 0.0
	last_motion_msec = Time.get_ticks_msec()
	tap_blocked = false
	suppress_mouse = false
	swiping = false
	selected = null
	origin = point
	candidates.clear()
	cancel_on_motion = false
	var hit := _hit(surface, point)
	while hit != null:
		cancel_on_motion = cancel_on_motion or bool(hit.get_meta("cancel_tap_on_motion", false))
		# Sliders own their drag; the surrounding page must not steal volume input.
		if hit is Slider:
			candidates.clear()
			gesture_started.emit(point)
			return tap_blocked
		if hit is ScrollContainer:
			if not candidates.has(hit): candidates.append(hit)
			var linked: WeakRef = hit.get_meta("vertical_scroll_target") if hit.has_meta("vertical_scroll_target") else null
			if linked != null:
				var target = linked.get_ref()
				if target is ScrollContainer and target.is_visible_in_tree() and not candidates.has(target):
					candidates.append(target)
		hit = hit.get_parent() as Control
	gesture_started.emit(point)
	return tap_blocked

func _end_gesture() -> bool:
	var consumed := swiping or tap_blocked
	if is_instance_valid(selected):
		if swiping and not horizontal and selected.get_meta("kinetic_scroll", false) and Time.get_ticks_msec() - last_motion_msec < 100:
			var bar := selected.get_v_scroll_bar()
			var destination := clampf(selected.scroll_vertical + velocity * COAST_SECONDS * 0.5, 0, maxf(0, bar.max_value - bar.page))
			coast = selected.create_tween()
			coast.tween_property(selected, "scroll_vertical", int(destination), COAST_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		selected.propagate_notification(Control.NOTIFICATION_SCROLL_END)
	finger = -1
	selected = null
	swiping = false
	candidates.clear()
	gesture_ended.emit()
	return consumed

func _scroll_at(point: Vector2, delta: Vector2, surface: Control) -> bool:
	_begin_gesture(point, surface)
	horizontal = absf(delta.x) > absf(delta.y)
	var target := _select_scroll(horizontal)
	if is_instance_valid(target):
		if horizontal: target.scroll_horizontal += int(round(delta.x))
		else: target.scroll_vertical += int(round(delta.y))
	_end_gesture()
	return is_instance_valid(target)

func _select_scroll(on_horizontal_axis: bool) -> ScrollContainer:
	for candidate in candidates:
		if not is_instance_valid(candidate): continue
		var mode: int = candidate.horizontal_scroll_mode if on_horizontal_axis else candidate.vertical_scroll_mode
		var bar: ScrollBar = candidate.get_h_scroll_bar() if on_horizontal_axis else candidate.get_v_scroll_bar()
		if mode != ScrollContainer.SCROLL_MODE_DISABLED and bar.max_value > bar.page:
			return candidate
	return null

func _move_gesture(point: Vector2, relative: Vector2) -> bool:
	if not swiping:
		var distance := point - origin
		if distance.length() < SWIPE_THRESHOLD:
			return not candidates.is_empty()
		horizontal = absf(distance.x) > absf(distance.y)
		selected = _select_scroll(horizontal)
		if selected == null:
			if not cancel_on_motion: return false
		swiping = true
		swipe_started.emit()
		suppress_mouse = true
		if is_instance_valid(selected): selected.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	if is_instance_valid(selected):
		var now := Time.get_ticks_msec()
		var elapsed := maxf(0.016, float(now - last_motion_msec) / 1000.0)
		velocity = clampf(-relative.y / elapsed, -1600.0, 1600.0)
		last_motion_msec = now
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
