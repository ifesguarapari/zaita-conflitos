extends RefCounted
class_name SpriteSheetAnimator


static func load_sheet(json_path: String, default_frame_size: Vector2i, columns: int, frame_count: int) -> Dictionary:
	var rects: Array[Rect2] = []
	var durations: Array[float] = []

	if FileAccess.file_exists(json_path):
		var text: String = FileAccess.get_file_as_string(json_path)
		var data: Variant = JSON.parse_string(text)
		if data is Dictionary:
			var root_data: Dictionary = data
			var frames: Dictionary = root_data.get("frames", {})
			var keys: Array = frames.keys()
			keys.sort()
			for key in keys:
				var entry: Dictionary = frames[key]
				var frame: Dictionary = entry.get("frame", {})
				rects.append(Rect2(
					float(frame.get("x", 0)),
					float(frame.get("y", 0)),
					float(frame.get("w", default_frame_size.x)),
					float(frame.get("h", default_frame_size.y))
				))
				durations.append(float(entry.get("duration", 100)) / 1000.0)

	if rects.is_empty():
		# If the JSON is missing, a simple grid keeps the lesson running.
		var safe_columns: int = maxi(1, columns)
		for index in range(maxi(1, frame_count)):
			var column: int = index % safe_columns
			var row: int = floori(float(index) / float(safe_columns))
			rects.append(Rect2(
				column * default_frame_size.x,
				row * default_frame_size.y,
				default_frame_size.x,
				default_frame_size.y
			))
			durations.append(0.1)

	return {
		"rects": rects,
		"durations": durations
	}


static func make_loop_slice(data: Dictionary, start_index: int, end_index: int) -> Dictionary:
	var rects: Array = data.get("rects", [])
	var durations: Array = data.get("durations", [])
	if rects.is_empty():
		return data

	var safe_start: int = clampi(start_index, 0, rects.size() - 1)
	var safe_end: int = clampi(end_index, safe_start, rects.size() - 1)
	var loop_rects: Array[Rect2] = []
	var loop_durations: Array[float] = []
	for index in range(safe_start, safe_end + 1):
		loop_rects.append(rects[index])
		loop_durations.append(durations[index])

	return {
		"rects": loop_rects,
		"durations": loop_durations
	}
