extends Control
class_name BattleFxLayer

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 70
	rng.randomize()

func play_attack(attacker: Control, defender: Control, damage: int, counter: bool = false) -> void:
	if defender == null or not is_instance_valid(defender):
		return
	var strong := damage >= 4
	var color := Color(1.0, 0.68, 0.22, 1.0) if counter else Color(1.0, 0.25, 0.16, 1.0)
	var center := _control_center(defender)
	var source := _control_center(attacker) if attacker != null and is_instance_valid(attacker) else center
	_spawn_screen_flash(color, 0.18 if strong else 0.09, 0.24 if strong else 0.16)
	_spawn_travel_streak(source, center, color, strong)
	_spawn_impact_core(center, color, strong)
	_spawn_ring(center, color, 48.0 if strong else 34.0, 0.36 if strong else 0.28)
	_spawn_radial_burst(center, color, 18 if strong else 11, strong)
	_spawn_sparks(center, color, 16 if strong else 8, 0.48 if strong else 0.34)
	if strong:
		_spawn_frame_pulse(color, 0.38)

func play_victory(accent: Color, grand: bool = true, anchor: Control = null) -> void:
	var viewport := _viewport_size()
	var center := _control_center(anchor) if anchor != null and is_instance_valid(anchor) else Vector2(viewport.x * 0.5, viewport.y * 0.46)
	var gold := Color(1.0, 0.82, 0.28, 1.0)
	_spawn_screen_flash(Color(1.0, 0.94, 0.72, 1.0), 0.34 if grand else 0.18, 0.72)
	_spawn_frame_pulse(accent.lerp(gold, 0.48), 1.05)
	if grand:
		_spawn_ring(center, gold, 112.0, 0.92)
		_spawn_ring(center, accent.lightened(0.28), 68.0, 0.68)
		_spawn_victory_rays(center, gold, 34)
		_spawn_sparks(center, gold, 44, 1.15)
		_spawn_sparks(center, accent.lightened(0.34), 24, 0.95)
	else:
		_spawn_ring(center, gold, 58.0, 0.7)
		_spawn_radial_burst(center, gold, 12, false)
		_spawn_sparks(center, gold, 18, 0.82)
		_spawn_sparks(center, accent.lightened(0.34), 8, 0.72)

func _viewport_size() -> Vector2:
	if size.x > 1.0 and size.y > 1.0:
		return size
	return get_viewport_rect().size

func _control_center(control: Control) -> Vector2:
	var canvas_center := control.get_global_transform_with_canvas() * (control.size * 0.5)
	return get_global_transform_with_canvas().affine_inverse() * canvas_center

func _spawn_screen_flash(color: Color, alpha: float, duration: float) -> void:
	var flash := ColorRect.new()
	flash.color = Color(color.r, color.g, color.b, alpha)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.modulate.a = 0.0
	add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 1.0, 0.025)
	tween.tween_property(flash, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_callback(Callable(self, "_free_if_valid").bind(flash))

func _spawn_travel_streak(source: Vector2, target: Vector2, color: Color, strong: bool) -> void:
	var delta := target - source
	if delta.length() < 8.0:
		return
	var normal := Vector2(-delta.y, delta.x).normalized()
	var streak_count := 5 if strong else 3
	for index in range(streak_count):
		var offset := (float(index) - float(streak_count - 1) * 0.5) * (9.0 if strong else 7.0)
		var streak := Line2D.new()
		streak.width = (8.0 if strong else 5.0) - float(index % 2) * 2.0
		streak.default_color = color.lightened(0.36 if index % 2 == 0 else 0.08)
		streak.begin_cap_mode = Line2D.LINE_CAP_ROUND
		streak.end_cap_mode = Line2D.LINE_CAP_ROUND
		streak.add_point(source + normal * offset)
		streak.add_point(target + normal * offset)
		streak.modulate.a = 0.88
		add_child(streak)
		var tween := streak.create_tween()
		tween.tween_property(streak, "width", 0.0, 0.2 if strong else 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(streak, "modulate:a", 0.0, 0.18)
		tween.tween_callback(Callable(self, "_free_if_valid").bind(streak))

func _spawn_impact_core(center: Vector2, color: Color, strong: bool) -> void:
	var core := ColorRect.new()
	var core_size := 28.0 if strong else 18.0
	core.color = color.lightened(0.62)
	core.size = Vector2(core_size, core_size)
	core.position = center - core.size * 0.5
	core.pivot_offset = core.size * 0.5
	core.rotation = PI * 0.25
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	core.scale = Vector2(0.2, 0.2)
	add_child(core)
	var tween := core.create_tween()
	tween.tween_property(core, "scale", Vector2(3.8, 3.8) if strong else Vector2(2.8, 2.8), 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(core, "modulate:a", 0.0, 0.18)
	tween.tween_callback(Callable(self, "_free_if_valid").bind(core))

func _spawn_ring(center: Vector2, color: Color, radius: float, duration: float) -> void:
	var ring := Line2D.new()
	ring.width = 8.0
	ring.default_color = color
	ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ring.end_cap_mode = Line2D.LINE_CAP_ROUND
	for point_index in range(33):
		var angle := TAU * float(point_index) / 32.0
		ring.add_point(Vector2(cos(angle), sin(angle)) * radius)
	ring.position = center
	ring.scale = Vector2(0.28, 0.28)
	add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(1.55, 1.55), duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "width", 0.0, duration)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, duration)
	tween.tween_callback(Callable(self, "_free_if_valid").bind(ring))

func _spawn_radial_burst(center: Vector2, color: Color, count: int, strong: bool) -> void:
	for index in range(count):
		var ray := Line2D.new()
		var inner := rng.randf_range(8.0, 22.0)
		var outer := rng.randf_range(64.0, 126.0 if strong else 88.0)
		ray.width = rng.randf_range(2.0, 6.0 if strong else 4.0)
		ray.default_color = color.lightened(rng.randf_range(0.05, 0.55))
		ray.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ray.end_cap_mode = Line2D.LINE_CAP_ROUND
		ray.add_point(Vector2(inner, 0))
		ray.add_point(Vector2(outer, 0))
		ray.position = center
		ray.rotation = TAU * float(index) / float(count) + rng.randf_range(-0.11, 0.11)
		ray.scale = Vector2(0.35, 1.0)
		add_child(ray)
		var tween := ray.create_tween()
		tween.tween_property(ray, "scale:x", 1.25, 0.24 if strong else 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(ray, "modulate:a", 0.0, 0.28 if strong else 0.21)
		tween.tween_callback(Callable(self, "_free_if_valid").bind(ray))

func _spawn_victory_rays(center: Vector2, color: Color, count: int) -> void:
	for index in range(count):
		var ray := Line2D.new()
		var inner := rng.randf_range(42.0, 88.0)
		var outer := rng.randf_range(180.0, 420.0)
		ray.width = rng.randf_range(2.0, 7.0)
		ray.default_color = color.lightened(rng.randf_range(0.0, 0.48))
		ray.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ray.end_cap_mode = Line2D.LINE_CAP_ROUND
		ray.add_point(Vector2(inner, 0))
		ray.add_point(Vector2(outer, 0))
		ray.position = center
		ray.rotation = TAU * float(index) / float(count) + rng.randf_range(-0.08, 0.08)
		ray.scale = Vector2(0.12, 1.0)
		ray.modulate.a = 0.84
		add_child(ray)
		var tween := ray.create_tween()
		tween.tween_property(ray, "scale:x", 1.0, 0.24).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_interval(rng.randf_range(0.18, 0.42))
		tween.tween_property(ray, "modulate:a", 0.0, rng.randf_range(0.38, 0.72))
		tween.tween_callback(Callable(self, "_free_if_valid").bind(ray))

func _spawn_sparks(center: Vector2, color: Color, count: int, duration: float) -> void:
	for index in range(count):
		var spark := ColorRect.new()
		var spark_size := Vector2(rng.randf_range(3.0, 7.0), rng.randf_range(9.0, 22.0))
		spark.color = color.lightened(rng.randf_range(0.0, 0.42))
		spark.size = spark_size
		spark.position = center - spark_size * 0.5
		spark.pivot_offset = spark_size * 0.5
		spark.rotation = rng.randf_range(-PI, PI)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(spark)
		var angle := TAU * float(index) / float(maxi(1, count)) + rng.randf_range(-0.3, 0.3)
		var distance := rng.randf_range(70.0, 260.0)
		var destination := center + Vector2(cos(angle), sin(angle)) * distance + Vector2(0, rng.randf_range(18.0, 86.0))
		var tween := spark.create_tween()
		tween.tween_property(spark, "position", destination - spark_size * 0.5, duration * rng.randf_range(0.72, 1.12)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(spark, "rotation", spark.rotation + rng.randf_range(-4.0, 4.0), duration)
		tween.parallel().tween_property(spark, "modulate:a", 0.0, duration).set_delay(duration * 0.42)
		tween.tween_callback(Callable(self, "_free_if_valid").bind(spark))

func _spawn_frame_pulse(color: Color, duration: float) -> void:
	var viewport := _viewport_size()
	var thickness := 10.0
	var edge_specs := [
		[Vector2.ZERO, Vector2(viewport.x, thickness)],
		[Vector2(0, viewport.y - thickness), Vector2(viewport.x, thickness)],
		[Vector2.ZERO, Vector2(thickness, viewport.y)],
		[Vector2(viewport.x - thickness, 0), Vector2(thickness, viewport.y)],
	]
	for spec in edge_specs:
		var edge := ColorRect.new()
		edge.color = Color(color.r, color.g, color.b, 0.68)
		edge.position = spec[0]
		edge.size = spec[1]
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(edge)
		var tween := edge.create_tween()
		tween.tween_property(edge, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_callback(Callable(self, "_free_if_valid").bind(edge))

func _free_if_valid(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
