extends RefCounted
## Pure viewport policy shared by menus and battle. Sizes are logical unless named physical.
const PHONE_LOGICAL_WIDTH := 390.0
const MOBILE_WIDTH := 600.0
const TOUCH_PORTRAIT_WIDTH := 900.0

static func is_mobile_portrait(size: Vector2) -> bool:
	return size.x <= MOBILE_WIDTH and size.y > size.x

static func is_touch_portrait(size: Vector2) -> bool:
	return size.x <= TOUCH_PORTRAIT_WIDTH and size.y > size.x

static func is_compact(size: Vector2, width: float = 860.0, height: float = 0.0) -> bool:
	return size.x < width or (height > 0.0 and size.y < height)

static func native_scale(physical: Vector2, base: Vector2) -> float:
	if physical.x <= 0.0 or physical.y <= 0.0:
		return 1.0
	return minf(physical.x / base.x, physical.y / base.y)

static func render_scale(physical: Vector2, base: Vector2, touch: bool, multiplier: float, maximum: float) -> float:
	if touch and physical.y > physical.x:
		return maxf(1.0, physical.x / PHONE_LOGICAL_WIDTH) * multiplier
	var native := native_scale(physical, base)
	if native < 1.0:
		return 1.0
	return clampf(clampf(native, 1.0, maximum) * multiplier, 0.95, maximum * 1.08)
