extends Node2D
class_name Enemy

const SpriteSheetAnimatorUtil = preload("res://scripts/SpriteSheetAnimator.gd")
const ZoneUtilsUtil = preload("res://scripts/ZoneUtils.gd")

signal defeated(reward: int)
signal fired(start_position: Vector2, end_position: Vector2, target: Node2D, damage: int, control_position: Vector2, width: float)

enum WeaponType { PISTOL, MACHINEGUN }

@export var weapon_type: WeaponType = WeaponType.PISTOL
@export var walk_zone: Rect2 = Rect2(120.0, 470.0, 1040.0, 185.0)
@export var walk_polygon: PackedVector2Array = PackedVector2Array()
@export var speed: float = 42.0
@export var start_run_distance: float = 46.0
@export var run_distance_after_shots: float = 38.0
@export var shots_before_run: int = 100
@export var shots_before_zaita_hit: int = 42
@export var max_shots_per_second: float = 1.0
@export var pistol_health: int = 1
@export var machinegun_health: int = 2
@export var pistol_reward: int = 2
@export var machinegun_reward: int = 3
@export var pistol_damage: int = 1
@export var machinegun_damage: int = 2
@export var can_shoot: bool = true
@export var pistol_shots_per_second: float = 1.0 / 3.0
@export var machinegun_shots_per_second: float = 1.0 / 5.0
@export var pistol_fire_frame: int = 18
@export var machinegun_fire_frame: int = 18
@export var running_animation_speed: float = 0.66
@export var min_shooting_animation_speed: float = 0.35
@export var max_shooting_animation_speed: float = 1.15
@export_group("Sprite sheet animation")
@export var starting_texture: Texture2D = preload("res://assets/sprites/enemy-starting-back-right.png")
@export var running_texture: Texture2D = preload("res://assets/sprites/enemy-running-back-right.png")
@export var pistol_shooting_texture: Texture2D = preload("res://assets/sprites/enemy-shooting-pistol-back-right.png")
@export var machinegun_shooting_texture: Texture2D = preload("res://assets/sprites/enemy-shooting-machinegun-back-right.png")
@export var dying_texture: Texture2D = preload("res://assets/sprites/enemy-dying-back-right.png")
@export_file("*.json") var starting_json: String = "res://assets/sprites/enemy-starting-back-right.json"
@export_file("*.json") var running_json: String = "res://assets/sprites/enemy-running-back-right.json"
@export_file("*.json") var pistol_shooting_json: String = "res://assets/sprites/enemy-shooting-pistol-back-right.json"
@export_file("*.json") var machinegun_shooting_json: String = "res://assets/sprites/enemy-shooting-machinegun-back-right.json"
@export_file("*.json") var dying_json: String = "res://assets/sprites/enemy-dying-back-right.json"
@export var starting_frame_size: Vector2i = Vector2i(600, 640)
@export var running_frame_size: Vector2i = Vector2i(286, 578)
@export var pistol_shooting_frame_size: Vector2i = Vector2i(640, 534)
@export var machinegun_shooting_frame_size: Vector2i = Vector2i(640, 586)
@export var dying_frame_size: Vector2i = Vector2i(458, 586)
@export var sheet_columns: int = 6
@export var frame_count: int = 36
@export var sprite_scale: float = 0.178
@export var starting_sprite_scale: float = 0.205
@export var pistol_shooting_sprite_scale: float = 0.181
@export var machinegun_shooting_sprite_scale: float = 0.173
@export var dying_sprite_scale: float = 0.178
@export_group("Shot effects")
@export var muzzle_right_offset: Vector2 = Vector2(34.0, -58.0)
@export var muzzle_left_offset: Vector2 = Vector2(-34.0, -58.0)
@export var muzzle_curve_distance: float = 54.0
@export var muzzle_flash_duration: float = 0.045
@export var pistol_ray_width: float = 2.0
@export var machinegun_ray_width: float = 1.55

@onready var body_sprite: Sprite2D = $Sprites/BodySprite
@onready var muzzle_flash: Polygon2D = $MuzzleFlash

var active: bool = false
var alive: bool = true
var is_mirrored: bool = false
var aim_zone: Rect2 = Rect2(956.0, 171.0, 372.0, 120.0)
var aim_polygon: PackedVector2Array = PackedVector2Array()
var health: int = 1
var reward: int = 2
var shot_damage: int = 1
var base_shots_per_second: float = 2.0
var current_shots_per_second: float = 2.0
var shots_since_run: int = 0
var total_shots: int = 0
var target_position: Vector2
var path_points: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var frame_time: float = 0.0
var frame_index: int = 0
var current_animation: StringName = &"starting"
var current_state: StringName = &"starting"
var animation_frames: Dictionary = {}
var animation_textures: Dictionary = {}
var fade_tween: Tween
var muzzle_flash_tween: Tween
var has_finished_dying: bool = false
var has_fired_this_animation_loop: bool = false
var last_fired_frame_index: int = -1


func _ready() -> void:
	add_to_group("enemies")
	body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_prepare_animations()
	configure_type(weapon_type)
	_build_path()
	_place_at_random_start()
	_enter_starting()


func _process(delta: float) -> void:
	if not active:
		return
	if not alive and current_state != &"dying":
		return

	match current_state:
		&"starting":
			if _animate_once(delta):
				_begin_run(start_run_distance)
		&"running":
			_process_running(delta)
		&"shooting":
			_process_shooting(delta)
		&"dying":
			if _animate_once(delta) and not has_finished_dying:
				_finish_dying()


func set_active(value: bool) -> void:
	active = value


func set_aim_area(zone: Rect2, polygon: PackedVector2Array) -> void:
	aim_zone = zone
	aim_polygon = polygon


func configure(zone: Rect2, polygon: PackedVector2Array, new_type_index: int, spawned_in_blue_zone: bool) -> void:
	walk_zone = zone
	walk_polygon = polygon
	is_mirrored = spawned_in_blue_zone
	configure_type(new_type_index)
	_build_path()
	_place_at_random_start()
	shots_since_run = 0
	total_shots = 0
	alive = true
	has_finished_dying = false
	has_fired_this_animation_loop = false
	last_fired_frame_index = -1
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	scale = Vector2.ONE
	_enter_starting()


func configure_type(new_type_index: int) -> void:
	weapon_type = new_type_index as WeaponType
	if weapon_type == WeaponType.PISTOL:
		health = pistol_health
		reward = pistol_reward
		shot_damage = pistol_damage
		base_shots_per_second = pistol_shots_per_second
	else:
		health = machinegun_health
		reward = machinegun_reward
		shot_damage = machinegun_damage
		base_shots_per_second = machinegun_shots_per_second
	current_shots_per_second = base_shots_per_second


func take_damage(amount: int) -> void:
	if not alive or current_state == &"dying":
		return

	health = max(0, health - amount)
	_flash()
	if health <= 0:
		_begin_dying()


func _enter_starting() -> void:
	_switch_animation(&"starting")
	current_state = &"starting"
	modulate.a = 0.0
	if fade_tween != null:
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, 0.45)


func _begin_run(distance: float) -> void:
	var next_position := _advance_forward(distance)
	if next_position.distance_to(global_position) <= 1.0:
		_begin_shooting()
		return

	target_position = next_position
	current_state = &"running"
	_switch_animation(&"running")


func _begin_shooting() -> void:
	current_state = &"shooting"
	has_fired_this_animation_loop = false
	last_fired_frame_index = -1
	_switch_animation(_shooting_animation())


func _begin_dying() -> void:
	alive = false
	current_state = &"dying"
	has_finished_dying = false
	defeated.emit(reward)
	_switch_animation(&"dying")


func _finish_dying() -> void:
	has_finished_dying = true
	active = false
	if fade_tween != null:
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.35)
	fade_tween.tween_property(self, "scale", Vector2.ONE * 0.82, 0.35)
	fade_tween.chain().tween_callback(queue_free)


func _process_running(delta: float) -> void:
	global_position = global_position.move_toward(target_position, speed * delta)
	_animate_loop(delta, running_animation_speed)
	if global_position.distance_to(target_position) <= 2.0:
		_begin_shooting()


func _process_shooting(delta: float) -> void:
	_animate_shooting(delta)


func _register_shot() -> void:
	shots_since_run += 1
	total_shots += 1

	if can_shoot:
		_emit_enemy_shot(total_shots >= shots_before_zaita_hit)

	if shots_since_run >= shots_before_run:
		shots_since_run = 0
		current_shots_per_second = minf(current_shots_per_second * 2.0, max_shots_per_second)
		_begin_run(run_distance_after_shots)


func _emit_enemy_shot(can_hit_child: bool) -> void:
	if can_hit_child:
		var target := _find_child_target()
		if target == null:
			return
		total_shots = 0
		_fire_at_position(target.global_position, target)
	else:
		_fire_at_position(_random_aim_position(), null)


func _fire_at_position(aim_position: Vector2, target: Node2D) -> void:
	var start_position := _muzzle_world_position()
	var control_position := _muzzle_control_point(aim_position)
	_play_muzzle_flash(aim_position)
	fired.emit(start_position, aim_position, target, shot_damage, control_position, _current_ray_width())


func _find_child_target() -> Node2D:
	var candidates: Array[Node2D] = []
	for child in get_tree().get_nodes_in_group("children"):
		if child is Node2D and child.get("alive") == true:
			candidates.append(child)
	if candidates.is_empty():
		return null
	return candidates.pick_random()


func _random_aim_position() -> Vector2:
	return ZoneUtilsUtil.random_point(aim_polygon, aim_zone)


func _current_ray_width() -> float:
	if weapon_type == WeaponType.MACHINEGUN:
		return machinegun_ray_width
	return pistol_ray_width


func _muzzle_world_position() -> Vector2:
	var muzzle_offset := muzzle_left_offset if is_mirrored else muzzle_right_offset
	return global_position + muzzle_offset


func _muzzle_control_point(aim_position: Vector2) -> Vector2:
	var start_position := _muzzle_world_position()
	var weapon_direction := Vector2(-1.0 if is_mirrored else 1.0, -0.12).normalized()
	var target_direction := (aim_position - start_position).normalized()
	if target_direction.length() <= 0.01:
		target_direction = weapon_direction
	var masked_direction := (weapon_direction * 0.68 + target_direction * 0.32).normalized()
	return start_position + masked_direction * muzzle_curve_distance


func _play_muzzle_flash(aim_position: Vector2) -> void:
	var muzzle_offset := muzzle_left_offset if is_mirrored else muzzle_right_offset
	var direction := aim_position - _muzzle_world_position()
	if direction.length() <= 0.01:
		direction = Vector2(-1.0 if is_mirrored else 1.0, -0.12)

	muzzle_flash.position = muzzle_offset
	muzzle_flash.rotation = direction.angle()
	muzzle_flash.visible = true
	muzzle_flash.modulate = Color(1.0, 0.75, 0.18, 0.9)
	muzzle_flash.scale = Vector2.ONE

	if muzzle_flash_tween != null:
		muzzle_flash_tween.kill()
	muzzle_flash_tween = create_tween()
	muzzle_flash_tween.set_parallel(true)
	muzzle_flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, muzzle_flash_duration)
	muzzle_flash_tween.tween_property(muzzle_flash, "scale", Vector2.ONE * 1.55, muzzle_flash_duration)
	muzzle_flash_tween.chain().tween_callback(func() -> void:
		muzzle_flash.visible = false
		muzzle_flash.scale = Vector2.ONE
	)


func _build_path() -> void:
	path_points = PackedVector2Array()
	if walk_polygon.size() >= 2:
		path_points = PackedVector2Array(walk_polygon)
	else:
		path_points = PackedVector2Array([
			walk_zone.position,
			Vector2(walk_zone.end.x, walk_zone.position.y),
			walk_zone.end,
			Vector2(walk_zone.position.x, walk_zone.end.y)
		])
	path_index = 0


func _path_start() -> Vector2:
	if path_points.is_empty():
		return walk_zone.position
	return path_points[0]


func _place_at_random_start() -> void:
	global_position = ZoneUtilsUtil.random_point(walk_polygon, walk_zone)
	path_index = _nearest_path_index(global_position)
	target_position = global_position


func _nearest_path_index(point: Vector2) -> int:
	if path_points.size() < 2:
		return 0

	var nearest_index := 0
	var nearest_distance := INF
	for index in range(path_points.size() - 1):
		var candidate := ZoneUtilsUtil.closest_point_on_segment(point, path_points[index], path_points[index + 1])
		var distance := point.distance_squared_to(candidate)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	return nearest_index


func _advance_path(distance: float) -> Vector2:
	if path_points.size() < 2:
		return global_position

	var remaining := distance
	var cursor := global_position
	while remaining > 0.0 and path_index < path_points.size() - 1:
		var next_point := path_points[path_index + 1]
		var segment_length := cursor.distance_to(next_point)
		if segment_length <= 0.01:
			path_index += 1
			continue
		if segment_length <= remaining:
			cursor = next_point
			path_index += 1
			remaining -= segment_length
		else:
			cursor = cursor.move_toward(next_point, remaining)
			remaining = 0.0

	return cursor


func _advance_forward(distance: float) -> Vector2:
	var direction := _forward_direction()
	var remaining := distance
	while remaining > 1.0:
		var candidate := global_position + direction * remaining
		if _is_inside_walk_area(candidate):
			return candidate
		remaining -= 4.0
	return global_position


func _forward_direction() -> Vector2:
	return Vector2(-1.0 if is_mirrored else 1.0, -0.42).normalized()


func _is_inside_walk_area(point: Vector2) -> bool:
	if walk_polygon.size() >= 3:
		return ZoneUtilsUtil.contains_point(walk_polygon, point)
	return walk_zone.has_point(point)


func _animate_loop(delta: float, speed_multiplier: float = 1.0) -> void:
	var data: Dictionary = animation_frames.get(current_animation, {})
	var rects: Array = data.get("rects", [])
	var durations: Array = data.get("durations", [])
	if rects.is_empty():
		return

	frame_time += delta * speed_multiplier
	var duration: float = float(durations[frame_index % durations.size()])
	if frame_time >= duration:
		frame_time = 0.0
		frame_index = (frame_index + 1) % rects.size()
		_set_current_frame()


func _animate_shooting(delta: float) -> void:
	var data: Dictionary = animation_frames.get(current_animation, {})
	var rects: Array = data.get("rects", [])
	var durations: Array = data.get("durations", [])
	if rects.is_empty():
		return

	frame_time += delta * _shooting_animation_speed()
	var safety_limit := rects.size() * 3
	var steps := 0
	while steps < safety_limit:
		var duration: float = float(durations[frame_index % durations.size()])
		if frame_time < duration:
			return

		frame_time -= duration
		if frame_index >= rects.size() - 1:
			frame_index = 0
			has_fired_this_animation_loop = false
		else:
			frame_index += 1
		_set_current_frame()
		_try_fire_on_current_shooting_frame()
		if current_state != &"shooting":
			return
		steps += 1


func _try_fire_on_current_shooting_frame() -> void:
	if has_fired_this_animation_loop:
		return
	if frame_index != _shooting_fire_frame():
		return

	has_fired_this_animation_loop = true
	last_fired_frame_index = frame_index
	_register_shot()


func _animate_once(delta: float) -> bool:
	var data: Dictionary = animation_frames.get(current_animation, {})
	var rects: Array = data.get("rects", [])
	var durations: Array = data.get("durations", [])
	if rects.is_empty():
		return true

	frame_time += delta
	var duration: float = float(durations[frame_index % durations.size()])
	if frame_time < duration:
		return false

	frame_time = 0.0
	if frame_index >= rects.size() - 1:
		return true
	frame_index += 1
	_set_current_frame()
	return false


func _prepare_animations() -> void:
	animation_frames = {
		&"starting": SpriteSheetAnimatorUtil.load_sheet(starting_json, starting_frame_size, sheet_columns, frame_count),
		&"running": SpriteSheetAnimatorUtil.load_sheet(running_json, running_frame_size, sheet_columns, frame_count),
		&"shooting_pistol": SpriteSheetAnimatorUtil.load_sheet(pistol_shooting_json, pistol_shooting_frame_size, sheet_columns, frame_count),
		&"shooting_machinegun": SpriteSheetAnimatorUtil.load_sheet(machinegun_shooting_json, machinegun_shooting_frame_size, sheet_columns, frame_count),
		&"dying": SpriteSheetAnimatorUtil.load_sheet(dying_json, dying_frame_size, sheet_columns, frame_count)
	}
	animation_textures = {
		&"starting": starting_texture,
		&"running": running_texture,
		&"shooting_pistol": pistol_shooting_texture,
		&"shooting_machinegun": machinegun_shooting_texture,
		&"dying": dying_texture
	}


func _switch_animation(new_animation: StringName) -> void:
	current_animation = new_animation
	frame_time = 0.0
	frame_index = 0
	_set_current_frame()


func _set_current_frame() -> void:
	var data: Dictionary = animation_frames.get(current_animation, {})
	var rects: Array = data.get("rects", [])
	if rects.is_empty():
		return

	var texture: Texture2D = animation_textures.get(current_animation, null)
	if texture != null:
		body_sprite.texture = texture
	body_sprite.region_enabled = true
	var rect: Rect2 = rects[frame_index % rects.size()]
	body_sprite.region_rect = rect
	body_sprite.offset = Vector2(0.0, -rect.size.y * 0.5)
	var scale_value := _sprite_scale_for_animation(current_animation)
	body_sprite.flip_h = is_mirrored
	body_sprite.scale = Vector2(scale_value, scale_value)


func _sprite_scale_for_animation(animation: StringName) -> float:
	match animation:
		&"starting":
			return starting_sprite_scale
		&"shooting_pistol":
			return pistol_shooting_sprite_scale
		&"shooting_machinegun":
			return machinegun_shooting_sprite_scale
		&"dying":
			return dying_sprite_scale
		_:
			return sprite_scale


func _shooting_animation() -> StringName:
	return &"shooting_machinegun" if weapon_type == WeaponType.MACHINEGUN else &"shooting_pistol"


func _shooting_animation_speed() -> float:
	var loop_duration := _animation_duration(current_animation)
	var desired_speed := loop_duration * maxf(0.1, current_shots_per_second)
	return clampf(desired_speed, min_shooting_animation_speed, max_shooting_animation_speed)


func _shooting_fire_frame() -> int:
	var selected_frame := machinegun_fire_frame if weapon_type == WeaponType.MACHINEGUN else pistol_fire_frame
	var data: Dictionary = animation_frames.get(current_animation, {})
	var rects: Array = data.get("rects", [])
	if rects.is_empty():
		return 0
	return clampi(selected_frame, 0, rects.size() - 1)


func _animation_duration(animation: StringName) -> float:
	var data: Dictionary = animation_frames.get(animation, {})
	var durations: Array = data.get("durations", [])
	var total_duration := 0.0
	for duration in durations:
		total_duration += float(duration)
	return maxf(total_duration, 0.01)


func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(body_sprite, "modulate", Color(1.0, 0.08, 0.03, body_sprite.modulate.a), 0.05)
	tween.tween_property(body_sprite, "modulate", Color(1.0, 1.0, 1.0, body_sprite.modulate.a), 0.1)
