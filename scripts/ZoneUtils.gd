extends RefCounted
class_name ZoneUtils


static func contains_point(polygon: PackedVector2Array, point: Vector2) -> bool:
	if polygon.size() < 3:
		return false
	return Geometry2D.is_point_in_polygon(point, polygon)


static func clamp_point(point: Vector2, polygon: PackedVector2Array, fallback_rect: Rect2) -> Vector2:
	if polygon.size() >= 3:
		if contains_point(polygon, point):
			return point
		return closest_point_on_polygon(point, polygon)

	return Vector2(
		clampf(point.x, fallback_rect.position.x, fallback_rect.end.x),
		clampf(point.y, fallback_rect.position.y, fallback_rect.end.y)
	)


static func random_point(polygon: PackedVector2Array, fallback_rect: Rect2) -> Vector2:
	if polygon.size() < 3:
		return Vector2(
			randf_range(fallback_rect.position.x, fallback_rect.end.x),
			randf_range(fallback_rect.position.y, fallback_rect.end.y)
		)

	var search_area := polygon_rect(polygon)
	for _attempt in range(240):
		var point := Vector2(
			randf_range(search_area.position.x, search_area.end.x),
			randf_range(search_area.position.y, search_area.end.y)
		)
		if contains_point(polygon, point):
			return point

	return centroid(polygon)


static func polygon_rect(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()

	var minimum := polygon[0]
	var maximum := polygon[0]
	for point in polygon:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)

	return Rect2(minimum, maximum - minimum)


static func centroid(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO

	var sum := Vector2.ZERO
	for point in polygon:
		sum += point
	return sum / float(polygon.size())


static func closest_point_on_polygon(point: Vector2, polygon: PackedVector2Array) -> Vector2:
	var best := polygon[0]
	var best_distance := INF
	for index in range(polygon.size()):
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		var candidate := closest_point_on_segment(point, a, b)
		var distance := point.distance_squared_to(candidate)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


static func closest_point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var length_squared_value := ab.length_squared()
	if length_squared_value <= 0.001:
		return a

	var t := clampf((point - a).dot(ab) / length_squared_value, 0.0, 1.0)
	return a + ab * t
