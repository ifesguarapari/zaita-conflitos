extends Node2D

@export var travel_duration: float = 0.042
@export var fade_duration: float = 0.052
@export var path_start_ratio: float = 0.45
@export var bullet_radius: float = 2.4
@export var glow_radius: float = 9.0
@export var trail_length: float = 44.0
@export var trail_width: float = 4.2
@export var ray_color: Color = Color(1.0, 0.86, 0.12, 1.0)

var original_start_point: Vector2
var start_point: Vector2
var end_point: Vector2
var current_point: Vector2
var previous_point: Vector2
var control_point: Vector2
var active_color: Color
var active_path_start_ratio: float = 0.45
var active_scale: float = 1.0
var active_trail_length: float = 44.0
var active_trail_width: float = 4.2
var impact_flash_enabled: bool = false
var elapsed: float = 0.0
var is_fading: bool = false


func _ready() -> void:
	global_position = Vector2.ZERO
	set_process(false)


func setup(start_position: Vector2, end_position: Vector2, new_color: Color = ray_color, new_width: float = -1.0, new_control_point: Vector2 = Vector2.INF, new_start_ratio: float = -1.0) -> void:
	global_position = Vector2.ZERO
	original_start_point = start_position
	end_point = end_position
	control_point = new_control_point if new_control_point != Vector2.INF else start_position.lerp(end_position, 0.18)
	active_path_start_ratio = clampf(new_start_ratio, 0.0, 0.92) if new_start_ratio >= 0.0 else path_start_ratio
	start_point = _quadratic_bezier(original_start_point, control_point, end_point, active_path_start_ratio)
	current_point = start_point
	previous_point = start_point
	active_color = new_color
	active_scale = clampf(new_width / 2.2, 0.78, 1.24) if new_width > 0.0 else 0.9
	impact_flash_enabled = active_path_start_ratio >= 0.65
	active_trail_length = trail_length
	active_trail_width = trail_width
	if impact_flash_enabled:
		active_scale = clampf(active_scale * 0.62, 0.42, 0.76)
		active_trail_length = trail_length * 2.35
		active_trail_width = trail_width * 0.68
	elapsed = 0.0
	is_fading = false
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if not is_fading:
		var progress := clampf(elapsed / maxf(travel_duration, 0.001), 0.0, 1.0)
		var eased_progress := 1.0 - pow(1.0 - progress, 4.0)
		var curve_progress := lerpf(active_path_start_ratio, 1.0, eased_progress)
		previous_point = current_point
		current_point = _quadratic_bezier(original_start_point, control_point, end_point, curve_progress)
		if progress >= 1.0:
			is_fading = true
			elapsed = 0.0
			current_point = end_point
		queue_redraw()
		return

	var fade_progress := clampf(elapsed / maxf(fade_duration, 0.001), 0.0, 1.0)
	if fade_progress >= 1.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var alpha := 1.0
	if is_fading:
		alpha = 1.0 - clampf(elapsed / maxf(fade_duration, 0.001), 0.0, 1.0)

	var direction := current_point - previous_point
	if direction.length() <= 0.01:
		direction = end_point - start_point
	if direction.length() <= 0.01:
		direction = Vector2.RIGHT
	direction = direction.normalized()

	var fade_progress := clampf(elapsed / maxf(fade_duration, 0.001), 0.0, 1.0) if is_fading else 0.0
	var visible_trail_length := active_trail_length * active_scale
	if impact_flash_enabled and is_fading:
		visible_trail_length = lerpf(visible_trail_length, visible_trail_length * 0.12, fade_progress)

	var trail_end := current_point - direction * visible_trail_length
	var outer_trail_color := active_color
	outer_trail_color.a = 0.16 * alpha
	draw_line(trail_end, current_point, outer_trail_color, active_trail_width * 2.4 * active_scale, true)

	var trail_color := Color(1.0, 0.55, 0.12, 0.62 * alpha)
	draw_line(trail_end.lerp(current_point, 0.22), current_point, trail_color, active_trail_width * active_scale, true)

	var core_trail_color := Color(1.0, 0.94, 0.58, 0.92 * alpha)
	draw_line(trail_end.lerp(current_point, 0.52), current_point, core_trail_color, active_trail_width * 0.46 * active_scale, true)

	var glow_color := active_color
	glow_color.a = 0.38 * alpha
	draw_circle(current_point, glow_radius * active_scale, glow_color)

	var core_color := Color(1.0, 0.96, 0.62, alpha)
	draw_circle(current_point, bullet_radius * active_scale, core_color)

	if impact_flash_enabled and is_fading:
		_draw_impact_flash(fade_progress)


func _draw_impact_flash(fade_progress: float) -> void:
	var flash_alpha := 1.0 - fade_progress
	var radius := lerpf(7.0, 28.0, fade_progress)
	var outer_color := Color(1.0, 0.78, 0.18, 0.28 * flash_alpha)
	var core_color := Color(1.0, 0.95, 0.62, 0.56 * flash_alpha)

	draw_set_transform(end_point, 0.0, Vector2(1.85, 0.42))
	draw_circle(Vector2.ZERO, radius, outer_color)
	draw_circle(Vector2.ZERO, radius * 0.42, core_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _quadratic_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var first := a.lerp(b, t)
	var second := b.lerp(c, t)
	return first.lerp(second, t)
