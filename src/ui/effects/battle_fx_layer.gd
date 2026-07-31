extends Control
class_name BattleFxLayer

const HEAVY_IMPACT_TEXTURE_PATH := "res://assets/fx/impact_heavy_v1.png"

var rng := RandomNumberGenerator.new()
var heavy_impact_texture: Texture2D

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 70
	rng.randomize()
	if ResourceLoader.exists(HEAVY_IMPACT_TEXTURE_PATH):
		heavy_impact_texture = ResourceLoader.load(HEAVY_IMPACT_TEXTURE_PATH, "Texture2D") as Texture2D

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
	_spawn_impact_texture(center, strong, counter)
	_spawn_ring(center, color, 48.0 if strong else 34.0, 0.36 if strong else 0.28)
	_spawn_radial_burst(center, color, 18 if strong else 11, strong)
	_spawn_sparks(center, color, 16 if strong else 8, 0.48 if strong else 0.34)
	if strong:
		_spawn_frame_pulse(color, 0.38)

func _spawn_impact_texture(center: Vector2, strong: bool, counter: bool) -> void:
	if heavy_impact_texture == null:
		return
	var impact := TextureRect.new()
	impact.texture = heavy_impact_texture
	impact.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	impact.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var texture_size := 250.0 if strong else 170.0
	impact.size = Vector2(texture_size, texture_size)
	impact.position = center - impact.size * 0.5
	impact.pivot_offset = impact.size * 0.5
	impact.rotation = deg_to_rad(rng.randf_range(-14.0, 14.0) + (82.0 if counter else 0.0))
	impact.scale = Vector2(0.18, 0.18)
	impact.modulate = Color(1.0, 0.82 if counter else 1.0, 0.64 if counter else 1.0, 0.0)
	impact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	impact.z_index = 260
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	impact.material = additive
	add_child(impact)

	var tween := impact.create_tween()
	tween.tween_property(impact, "modulate:a", 0.96, 0.025)
	tween.parallel().tween_property(impact, "scale", Vector2.ONE, 0.075 if strong else 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.025 if strong else 0.01)
	tween.tween_property(impact, "scale", Vector2(1.34, 1.34), 0.2 if strong else 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(impact, "modulate:a", 0.0, 0.18 if strong else 0.13).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_callback(Callable(self, "_free_if_valid").bind(impact))

func fly_card(
	card_visual: Control,
	source: Control,
	target: Control,
	action_kind: String,
	accent: Color,
	quick: bool = false
):
	if card_visual == null or source == null or target == null:
		_free_if_valid(card_visual)
		return null
	if not is_instance_valid(source) or not is_instance_valid(target):
		_free_if_valid(card_visual)
		return null

	add_child(card_visual)
	card_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_visual.z_index = 240
	var source_center := _control_center(source)
	var target_center := _control_center(target)
	var lift_center := source_center + Vector2(0, -18.0)
	var delta := target_center - lift_center
	var curve_height := maxf(72.0, absf(delta.y) * 0.24)
	var curve_center := (lift_center + target_center) * 0.5 + Vector2(delta.x * 0.08, -curve_height)
	var direction := -1.0 if delta.x < 0.0 else 1.0
	var start_scale := Vector2(0.92, 0.92)
	var end_scale := Vector2(0.72, 0.72)
	var end_rotation := 0.0
	match action_kind:
		"spell":
			end_scale = Vector2(0.82, 0.82)
			end_rotation = -7.0 * direction
		"equipment":
			end_scale = Vector2(0.68, 0.68)
			end_rotation = 9.0 * direction

	card_visual.position = source_center - card_visual.size * 0.5
	card_visual.pivot_offset = card_visual.size * 0.5
	card_visual.scale = start_scale * 0.94
	card_visual.rotation_degrees = -4.0 * direction
	card_visual.modulate.a = 0.92

	var lift_duration := 0.045 if quick else 0.1
	var travel_duration := 0.14 if quick else (0.34 if action_kind == "spell" else 0.29)
	var lift := card_visual.create_tween()
	lift.set_parallel(true)
	lift.tween_property(card_visual, "position", lift_center - card_visual.size * 0.5, lift_duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	lift.tween_property(card_visual, "scale", start_scale * 1.08, lift_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lift.tween_property(card_visual, "modulate:a", 1.0, lift_duration)
	await lift.finished

	_spawn_card_arc_trail(lift_center, curve_center, target_center, accent, travel_duration)
	var travel := card_visual.create_tween()
	travel.set_parallel(true)
	travel.tween_method(
		Callable(self, "_set_card_curve_progress").bind(card_visual, lift_center, curve_center, target_center),
		0.0,
		1.0,
		travel_duration
	).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	travel.tween_property(card_visual, "scale", end_scale, travel_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	travel.tween_property(card_visual, "rotation_degrees", end_rotation, travel_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await travel.finished
	return card_visual

func finish_card(card_visual: Control, action_kind: String, accent: Color, quick: bool = false) -> void:
	if card_visual == null or not is_instance_valid(card_visual):
		return
	var center := card_visual.position + card_visual.size * 0.5
	var impact_color := accent.lightened(0.18)
	_spawn_ring(center, impact_color, 42.0 if action_kind == "unit" else 58.0, 0.24 if quick else 0.34)
	_spawn_sparks(center, impact_color, 7 if quick else (16 if action_kind == "spell" else 11), 0.25 if quick else 0.42)
	if action_kind == "spell":
		_spawn_screen_flash(impact_color, 0.08 if quick else 0.14, 0.16 if quick else 0.24)
		_spawn_radial_burst(center, impact_color, 8 if quick else 14, not quick)

	var finish_duration := 0.07 if quick else 0.14
	var final_scale := card_visual.scale * (Vector2(1.28, 1.28) if action_kind == "spell" else Vector2(0.72, 0.72))
	if action_kind == "equipment":
		final_scale = card_visual.scale * Vector2(0.34, 0.34)
	var finish := card_visual.create_tween()
	finish.set_parallel(true)
	finish.tween_property(card_visual, "scale", final_scale, finish_duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	finish.tween_property(card_visual, "modulate:a", 0.0, finish_duration)
	if action_kind == "spell":
		finish.tween_property(card_visual, "rotation_degrees", card_visual.rotation_degrees + 12.0, finish_duration)
	await finish.finished
	_free_if_valid(card_visual)

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

func _set_card_curve_progress(
	progress: float,
	card_visual: Control,
	start: Vector2,
	curve: Vector2,
	finish: Vector2
) -> void:
	if card_visual == null or not is_instance_valid(card_visual):
		return
	var center := _quadratic_point(start, curve, finish, progress)
	card_visual.position = center - card_visual.size * 0.5

func _quadratic_point(start: Vector2, curve: Vector2, finish: Vector2, progress: float) -> Vector2:
	var inverse := 1.0 - progress
	return start * inverse * inverse + curve * 2.0 * inverse * progress + finish * progress * progress

func _spawn_card_arc_trail(start: Vector2, curve: Vector2, finish: Vector2, color: Color, duration: float) -> void:
	var trail := Line2D.new()
	trail.width = 7.0
	trail.default_color = Color(color.r, color.g, color.b, 0.58)
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail.z_index = 230
	for point_index in range(13):
		var progress := float(point_index) / 12.0
		trail.add_point(_quadratic_point(start, curve, finish, progress))
	add_child(trail)
	var tween := trail.create_tween()
	tween.tween_property(trail, "width", 1.0, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(trail, "modulate:a", 0.0, duration).set_delay(duration * 0.32)
	tween.tween_callback(Callable(self, "_free_if_valid").bind(trail))

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
