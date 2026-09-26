extends RefCounted
## Pure viewport policy shared by menus and battle. Sizes are logical unless named physical.
const PHONE_LOGICAL_WIDTH := 390.0

static func landscape_size(size: Vector2) -> Vector2:
	return Vector2(maxf(size.x, size.y), minf(size.x, size.y))

static func is_mobile_landscape(size: Vector2) -> bool:
	return size.x > size.y and size.y <= 500.0 and size.x <= 1000.0

static func is_compact(size: Vector2, width: float = 860.0, height: float = 0.0) -> bool:
	return size.x < width or (height > 0.0 and size.y < height)

static func native_scale(physical: Vector2, base: Vector2) -> float:
	if physical.x <= 0.0 or physical.y <= 0.0:
		return 1.0
	return minf(physical.x / base.x, physical.y / base.y)

static func render_scale(physical: Vector2, base: Vector2, touch: bool, multiplier: float, maximum: float) -> float:
	if touch:
		return maxf(1.0, minf(physical.x, physical.y) / PHONE_LOGICAL_WIDTH) * multiplier
	var native := native_scale(physical, base)
	if native < 1.0:
		return 1.0
	return clampf(clampf(native, 1.0, maximum) * multiplier, 0.95, maximum * 1.08)
