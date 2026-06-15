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
var active_scale: float = 1.0
var elapsed: float = 0.0
var is_fading: bool = false


func _ready() -> void:
	global_position = Vector2.ZERO
	set_process(false)


func setup(start_position: Vector2, end_position: Vector2, new_color: Color = ray_color, new_width: float = -1.0, new_control_point: Vector2 = Vector2.INF) -> void:
	global_position = Vector2.ZERO
	original_start_point = start_position
	end_point = end_position
	control_point = new_control_point if new_control_point != Vector2.INF else start_position.lerp(end_position, 0.18)
	start_point = _quadratic_bezier(original_start_point, control_point, end_point, path_start_ratio)
	current_point = start_point
	previous_point = start_point
	active_color = new_color
	active_scale = clampf(new_width / 2.2, 0.78, 1.24) if new_width > 0.0 else 0.9
	elapsed = 0.0
	is_fading = false
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if not is_fading:
		var progress := clampf(elapsed / maxf(travel_duration, 0.001), 0.0, 1.0)
		var eased_progress := 1.0 - pow(1.0 - progress, 4.0)
		var curve_progress := lerpf(path_start_ratio, 1.0, eased_progress)
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

	var trail_end := current_point - direction * trail_length * active_scale
	var outer_trail_color := active_color
	outer_trail_color.a = 0.16 * alpha
	draw_line(trail_end, current_point, outer_trail_color, trail_width * 2.4 * active_scale, true)

	var trail_color := Color(1.0, 0.55, 0.12, 0.62 * alpha)
	draw_line(trail_end.lerp(current_point, 0.22), current_point, trail_color, trail_width * active_scale, true)

	var core_trail_color := Color(1.0, 0.94, 0.58, 0.92 * alpha)
	draw_line(trail_end.lerp(current_point, 0.52), current_point, core_trail_color, trail_width * 0.46 * active_scale, true)

	var glow_color := active_color
	glow_color.a = 0.38 * alpha
	draw_circle(current_point, glow_radius * active_scale, glow_color)

	var core_color := Color(1.0, 0.96, 0.62, alpha)
	draw_circle(current_point, bullet_radius * active_scale, core_color)


func _quadratic_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var first := a.lerp(b, t)
	var second := b.lerp(c, t)
	return first.lerp(second, t)
