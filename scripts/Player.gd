extends Node2D

const SpriteSheetAnimatorUtil = preload("res://scripts/SpriteSheetAnimator.gd")
const ZoneUtilsUtil = preload("res://scripts/ZoneUtils.gd")

signal shot_fired(start_position: Vector2, end_position: Vector2)
signal weapon_charge_spent(weapon: StringName, amount: int, remaining: int, capacity: int)

const ORIENTATION_BACK_LEFT := 0
const ORIENTATION_BACK_RIGHT := 1
const ORIENTATION_FRONT_RIGHT := 2
const ORIENTATION_FRONT_LEFT := 3

@export var speed: float = 16.0
@export var map_bounds: Rect2 = Rect2(190.0, 305.0, 900.0, 335.0)
@export var map_polygon: PackedVector2Array = PackedVector2Array()
@export var stop_distance: float = 8.0
@export var pistol_range: float = 900.0
@export var shotgun_range: float = 650.0
@export var machinegun_range: float = 1100.0
@export var pistol_fire_interval: float = 0.28
@export var shotgun_fire_interval: float = 1.12
@export var machinegun_fire_interval: float = 0.24
@export var pistol_damage: int = 1
@export var shotgun_damage: int = 2
@export var machinegun_damage: int = 1
@export var shotgun_shot_cost: int = 0
@export var machinegun_shot_cost: int = 0
@export var shotgun_spread_radius: float = 72.0
@export var shotgun_targets_per_shot: int = 2
@export var machinegun_targets_per_shot: int = 3
@export var ray_scene: PackedScene
@export var boundary_retreat_distance: float = 58.0
@export var boundary_probe_distance: float = 1800.0
@export var boundary_probe_step: float = 34.0

@export_group("Sprite sheet animation")
@export var walk_down_texture: Texture2D = preload("res://assets/sprites/brother-walking-front-right.png")
@export var walk_up_texture: Texture2D = preload("res://assets/sprites/brother-walking-back-left.png")
@export var idle_down_texture: Texture2D = preload("res://assets/sprites/brother-idle-front-right.png")
@export var idle_up_texture: Texture2D = preload("res://assets/sprites/brother-idle-back-left.png")
@export var pistol_shoot_texture: Texture2D = preload("res://assets/sprites/brother-shooting-pistol-front-right.png")
@export var shotgun_shoot_texture: Texture2D = preload("res://assets/sprites/brother-shooting-shotgun-front-right.png")
@export var machinegun_shoot_texture: Texture2D = preload("res://assets/sprites/brother-shooting-machinegun-front-right.png")
@export_file("*.json") var walk_down_json: String = "res://assets/sprites/brother-walking-front-right.json"
@export_file("*.json") var walk_up_json: String = "res://assets/sprites/brother-walking-back-left.json"
@export_file("*.json") var idle_down_json: String = "res://assets/sprites/brother-idle-front-right.json"
@export_file("*.json") var idle_up_json: String = "res://assets/sprites/brother-idle-back-left.json"
@export_file("*.json") var pistol_shoot_json: String = "res://assets/sprites/brother-shooting-pistol-front-right.json"
@export_file("*.json") var shotgun_shoot_json: String = "res://assets/sprites/brother-shooting-shotgun-front-right.json"
@export_file("*.json") var machinegun_shoot_json: String = "res://assets/sprites/brother-shooting-machinegun-front-right.json"
@export var down_frame_size: Vector2i = Vector2i(310, 636)
@export var up_frame_size: Vector2i = Vector2i(250, 640)
@export var idle_down_frame_size: Vector2i = Vector2i(200, 546)
@export var idle_up_frame_size: Vector2i = Vector2i(192, 536)
@export var pistol_shoot_frame_size: Vector2i = Vector2i(612, 550)
@export var shotgun_shoot_frame_size: Vector2i = Vector2i(640, 484)
@export var machinegun_shoot_frame_size: Vector2i = Vector2i(640, 536)
@export var sheet_columns: int = 6
@export var frame_count: int = 36
@export var walk_sprite_scale: float = 0.16
@export var idle_down_sprite_scale: float = 0.186
@export var idle_up_sprite_scale: float = 0.191
@export var pistol_shoot_sprite_scale: float = 0.185
@export var shotgun_shoot_sprite_scale: float = 0.21
@export var machinegun_shoot_sprite_scale: float = 0.19
@export var orientation_change_distance: float = 12.0
@export var turn_drift_speed_multiplier: float = 0.22
@export var animation_transition_duration: float = 0.2
@export var walking_animation_speed: float = 1.22
@export var idle_animation_speed: float = 0.52
@export var shooting_animation_speed: float = 3.2
@export var min_idle_time: float = 3.2
@export var max_idle_time: float = 6.0
@export var shooting_fire_start_ratio: float = 0.34
@export var shooting_fire_end_ratio: float = 0.68
@export var pistol_fire_start_frame: int = 23
@export var pistol_fire_end_frame: int = 30
@export var pistol_max_fire_loop_repeats: int = 1
@export var shotgun_max_fire_loop_repeats: int = 1
@export var machinegun_max_fire_loop_repeats: int = 3
@export var right_shoot_visual_rotation_degrees: float = 0.0
@export var left_shoot_visual_rotation_degrees: float = 0.0
@export var muzzle_right_offset: Vector2 = Vector2(44.0, -62.0)
@export var muzzle_left_offset: Vector2 = Vector2(-44.0, -62.0)
@export var muzzle_curve_distance: float = 42.0
@export var muzzle_flash_duration: float = 0.045
@export var shot_light_duration: float = 0.09
@export var shot_light_color: Color = Color(1.32, 1.16, 0.62, 1.0)
@export var down_faces_right: bool = true
@export var up_faces_right: bool = false

@onready var sprites_root: Node2D = $Sprites
@onready var down_sprite: Sprite2D = $Sprites/DownSprite
@onready var up_sprite: Sprite2D = $Sprites/UpSprite
@onready var shoot_sprite: Sprite2D = $Sprites/ShootSprite
@onready var muzzle_point: Marker2D = $MuzzlePoint
@onready var muzzle_flash: Polygon2D = $MuzzleFlash

var current_weapon: StringName = &"pistol"
var unlocked_weapons := {
	&"pistol": true,
	&"shotgun": false,
	&"machinegun": false
}
var weapon_charges := {
	&"shotgun": 0,
	&"machinegun": 0
}
var weapon_charge_capacities := {
	&"shotgun": 10,
	&"machinegun": 30
}
var active: bool = false
var target_position: Vector2
var current_target: Node2D
var fire_cooldown: float = 0.0
var frame_time: float = 0.0
var frame_index: int = 0
var current_animation: StringName = &"down"
var animation_frames: Dictionary = {}
var animation_textures: Dictionary = {}
var animation_speeds: Dictionary = {}
var transition_tween: Tween
var effects_root: Node
var try_spend_skulls: Callable
var is_shooting: bool = false
var shooting_phase: StringName = &"none"
var has_fired_in_fire_cycle: bool = false
var fire_loop_repeats: int = 0
var pending_manual_shot: bool = false
var manual_aim_position: Vector2
var auto_walk_after_shot: bool = false
var retreating_from_boundary: bool = false
var last_shot_direction: Vector2 = Vector2(-1.0, 0.5).normalized()
var visual_shot_direction: Vector2 = Vector2.RIGHT
var is_facing_left_for_shot: bool = false
var visual_orientation: int = ORIENTATION_FRONT_LEFT
var target_orientation: int = ORIENTATION_FRONT_LEFT
var orientation_change_walked_distance: float = 0.0
var idle_time_left: float = 0.0
var muzzle_flash_tween: Tween
var shot_light_tween: Tween


func _ready() -> void:
	add_to_group("player")
	target_position = global_position
	_configure_sprite_filtering()
	_prepare_animations()
	_apply_idle_orientation(ORIENTATION_FRONT_LEFT, true)
	idle_time_left = randf_range(min_idle_time, max_idle_time)


func _process(delta: float) -> void:
	if not active:
		return

	fire_cooldown = max(0.0, fire_cooldown - delta)
	_update_target()

	if _is_shooting_animation(current_animation):
		_animate(delta)
		return

	if pending_manual_shot and _can_begin_shot_animation():
		_enter_shooting()
		_animate(delta)
		return

	if idle_time_left > 0.0 and current_target == null:
		idle_time_left -= delta
		_animate(delta)
		if idle_time_left <= 0.0:
			_finish_idle()
		return

	if _has_target_in_range() and _can_begin_shot_animation():
		_enter_shooting()
		_animate(delta)
		return

	_move(delta)
	_animate(delta)

	if _has_target_in_range() and _can_begin_shot_animation():
		_enter_shooting()


func set_active(value: bool) -> void:
	active = value


func set_effects_root(node: Node) -> void:
	effects_root = node


func set_spend_callback(callback: Callable) -> void:
	try_spend_skulls = callback


func set_weapon_charges(new_charges: Dictionary, new_capacities: Dictionary) -> void:
	weapon_charges = new_charges.duplicate()
	weapon_charge_capacities = new_capacities.duplicate()


func reset(initial_position: Vector2, new_zone: Rect2, new_polygon: PackedVector2Array = PackedVector2Array()) -> void:
	global_position = initial_position
	target_position = initial_position
	map_bounds = new_zone
	map_polygon = new_polygon
	current_target = null
	current_weapon = &"pistol"
	unlocked_weapons = {
		&"pistol": true,
		&"shotgun": false,
		&"machinegun": false
	}
	weapon_charges = {
		&"shotgun": 0,
		&"machinegun": 0
	}
	fire_cooldown = 0.0
	frame_time = 0.0
	frame_index = 0
	current_animation = &"down"
	active = false
	visible = true
	modulate = Color.WHITE
	sprites_root.modulate = Color.WHITE
	muzzle_flash.visible = false
	muzzle_flash.rotation_degrees = 0.0
	if muzzle_flash_tween != null:
		muzzle_flash_tween.kill()
	if shot_light_tween != null:
		shot_light_tween.kill()
	is_shooting = false
	shooting_phase = &"none"
	has_fired_in_fire_cycle = false
	fire_loop_repeats = 0
	pending_manual_shot = false
	auto_walk_after_shot = false
	retreating_from_boundary = false
	idle_time_left = randf_range(min_idle_time, max_idle_time)
	last_shot_direction = Vector2(-1.0, 0.5).normalized()
	visual_orientation = ORIENTATION_FRONT_LEFT
	target_orientation = ORIENTATION_FRONT_LEFT
	orientation_change_walked_distance = 0.0
	down_sprite.modulate.a = 1.0
	up_sprite.modulate.a = 0.0
	shoot_sprite.modulate.a = 0.0
	shoot_sprite.rotation_degrees = 0.0
	_apply_idle_orientation(visual_orientation, true)
	_set_current_frame()


func set_target_position(new_target_position: Vector2) -> void:
	current_target = null
	is_shooting = false
	shooting_phase = &"none"
	pending_manual_shot = false
	auto_walk_after_shot = false
	retreating_from_boundary = false
	idle_time_left = 0.0
	target_position = _clamp_to_map(new_target_position)


func set_target(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return

	current_target = enemy
	pending_manual_shot = false
	auto_walk_after_shot = false
	retreating_from_boundary = false
	idle_time_left = 0.0
	target_position = _clamp_to_map(enemy.global_position)
	var shot_direction := enemy.global_position - global_position
	if shot_direction.length() > 0.01:
		last_shot_direction = shot_direction.normalized()
		_face_shoot_direction(last_shot_direction)
	if active and _has_target_in_range() and _can_begin_shot_animation():
		_enter_shooting()


func shoot_at_position(aim_position: Vector2) -> void:
	current_target = null
	pending_manual_shot = true
	manual_aim_position = aim_position
	auto_walk_after_shot = true
	retreating_from_boundary = false
	idle_time_left = 0.0
	var direction := aim_position - global_position
	if direction.length() > 0.01:
		last_shot_direction = direction.normalized()
		_face_shoot_direction(last_shot_direction)
	target_position = _edge_target(last_shot_direction)
	if _is_shooting_animation(current_animation) and shooting_phase == &"fire" and fire_cooldown <= 0.0:
		has_fired_in_fire_cycle = false
	if active and _can_begin_shot_animation():
		_enter_shooting()


func select_weapon(weapon_name: StringName) -> void:
	if weapon_name == &"pistol" or (unlocked_weapons.get(weapon_name, false) and _weapon_charge_remaining(weapon_name) > 0):
		current_weapon = weapon_name
		if is_shooting:
			_enter_shooting(true)


func unlock_weapon(weapon_name: StringName) -> void:
	unlocked_weapons[weapon_name] = true
	select_weapon(weapon_name)


func _update_target() -> void:
	if current_target == null:
		return
	if not is_instance_valid(current_target) or not current_target.is_in_group("enemies"):
		_clear_target_after_shot()
		return
	if current_target.get("alive") == false:
		_clear_target_after_shot()


func _move(delta: float) -> void:
	var movement_target := target_position
	if current_target != null and is_instance_valid(current_target):
		var target_distance := global_position.distance_to(current_target.global_position)
		if target_distance > _current_range() * 0.88:
			movement_target = _clamp_to_map(current_target.global_position)
		else:
			movement_target = global_position

	var previous_position := global_position
	var desired_movement := movement_target - global_position
	var is_turning := false
	if desired_movement.length() > 0.1:
		is_turning = _turn_toward_direction(desired_movement, delta)

	if is_turning:
		global_position = _clamp_to_map(global_position + _orientation_direction(visual_orientation) * speed * turn_drift_speed_multiplier * delta)
		return

	global_position = global_position.move_toward(movement_target, speed * delta)
	var movement := global_position - previous_position

	if movement.length() > 0.1:
		_update_visual_direction(movement, delta)
		_apply_walk_orientation(visual_orientation)

	if global_position.distance_to(movement_target) <= stop_distance and current_target == null:
		_handle_arrival()


func _handle_arrival() -> void:
	_begin_idle()


func _begin_idle() -> void:
	idle_time_left = randf_range(min_idle_time, max_idle_time)
	target_position = global_position
	visual_orientation = ORIENTATION_FRONT_LEFT
	target_orientation = ORIENTATION_FRONT_LEFT
	orientation_change_walked_distance = 0.0
	_apply_idle_orientation(visual_orientation)


func _finish_idle() -> void:
	if current_target != null and is_instance_valid(current_target):
		return
	_choose_next_target_after_idle()


func _choose_next_target_after_idle() -> void:
	if retreating_from_boundary:
		retreating_from_boundary = false
		last_shot_direction = _random_isometric_direction()
		target_position = _edge_target(last_shot_direction)
		return

	if auto_walk_after_shot:
		retreating_from_boundary = true
		target_position = _clamp_to_map(global_position - last_shot_direction * boundary_retreat_distance)
		if target_position.distance_to(global_position) <= stop_distance:
			retreating_from_boundary = false
			last_shot_direction = _random_isometric_direction()
			target_position = _edge_target(last_shot_direction)
		return

	last_shot_direction = _random_isometric_direction()
	auto_walk_after_shot = true
	target_position = _edge_target(last_shot_direction)


func _try_fire_from_animation() -> void:
	if has_fired_in_fire_cycle or fire_cooldown > 0.0:
		return

	if current_target != null and is_instance_valid(current_target) and current_target.get("alive") != false:
		if global_position.distance_to(current_target.global_position) <= _current_range():
			_fire_at_target()
			return

	if pending_manual_shot:
		_fire_at_position(manual_aim_position)


func _fire_at_target() -> void:
	if current_target == null or not is_instance_valid(current_target):
		return
	var shot_weapon := current_weapon
	if not _has_weapon_charge(shot_weapon):
		_clear_target_after_shot()
		return
	var hit_targets := _targets_for_weapon_shot(current_target, shot_weapon)
	if hit_targets.is_empty():
		_clear_target_after_shot()
		return

	fire_cooldown = _current_fire_interval()
	has_fired_in_fire_cycle = true
	var impact_position: Vector2 = (hit_targets[0] as Node2D).global_position
	var direction := impact_position - global_position
	if direction.length() > 0.01:
		last_shot_direction = direction.normalized()
		_face_shoot_direction(last_shot_direction)

	var muzzle_position := _muzzle_world_position()
	for target in hit_targets:
		if not is_instance_valid(target):
			continue
		var target_position := target.global_position
		_spawn_ray(muzzle_position, target_position, Color(1.0, 0.86, 0.12, 1.0), _current_ray_width(), _muzzle_control_point(target_position))
		shot_fired.emit(muzzle_position, target_position)
		target.take_damage(_damage_for_weapon(shot_weapon))

	_play_muzzle_flash()
	if current_target == null or not is_instance_valid(current_target) or current_target.get("alive") == false:
		_clear_target_after_shot()
	_consume_weapon_charge(shot_weapon, hit_targets.size())


func _fire_at_position(aim_position: Vector2) -> void:
	var shot_weapon := current_weapon
	if not _has_weapon_charge(shot_weapon):
		pending_manual_shot = false
		return

	fire_cooldown = _current_fire_interval()
	has_fired_in_fire_cycle = true
	pending_manual_shot = false
	var direction := aim_position - global_position
	if direction.length() > 0.01:
		last_shot_direction = direction.normalized()
		_face_shoot_direction(last_shot_direction)
	var muzzle_position := _muzzle_world_position()
	var hit_targets := _targets_for_manual_shot(aim_position, shot_weapon)
	if hit_targets.is_empty():
		_spawn_ray(muzzle_position, aim_position, Color(1.0, 0.86, 0.12, 1.0), _current_ray_width(), _muzzle_control_point(aim_position))
		shot_fired.emit(muzzle_position, aim_position)
	else:
		for target in hit_targets:
			if not is_instance_valid(target):
				continue
			var target_position := target.global_position
			_spawn_ray(muzzle_position, target_position, Color(1.0, 0.86, 0.12, 1.0), _current_ray_width(), _muzzle_control_point(target_position))
			shot_fired.emit(muzzle_position, target_position)
			target.take_damage(_damage_for_weapon(shot_weapon))
	_play_muzzle_flash()
	_consume_weapon_charge(shot_weapon, hit_targets.size())


func _targets_for_weapon_shot(primary_target: Node2D, weapon: StringName) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	if not _is_valid_enemy(primary_target):
		return targets

	var target_limit := _target_limit_for_weapon(weapon)
	if target_limit <= 0:
		return targets

	targets.append(primary_target)
	if target_limit <= 1:
		return targets

	var primary_perimeter := _enemy_perimeter_key(primary_target)
	var candidates: Array[Node2D] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == primary_target or not _is_valid_enemy(enemy):
			continue
		if _enemy_perimeter_key(enemy) != primary_perimeter:
			continue
		if global_position.distance_to(enemy.global_position) > _range_for_weapon(weapon):
			continue
		candidates.append(enemy)

	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(primary_target.global_position) < b.global_position.distance_squared_to(primary_target.global_position)
	)
	for candidate in candidates:
		if targets.size() >= target_limit:
			break
		targets.append(candidate)
	return targets


func _targets_for_manual_shot(aim_position: Vector2, weapon: StringName) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	if weapon == &"pistol":
		return targets

	var target_limit := _target_limit_for_weapon(weapon)
	if target_limit <= 0:
		return targets

	var aim_radius := _manual_aim_radius_for_weapon(weapon)
	var candidates: Array[Node2D] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not _is_valid_enemy(enemy):
			continue
		if global_position.distance_to(enemy.global_position) > _range_for_weapon(weapon):
			continue
		if enemy.global_position.distance_to(aim_position) > aim_radius:
			continue
		candidates.append(enemy)

	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(aim_position) < b.global_position.distance_squared_to(aim_position)
	)
	for candidate in candidates:
		if targets.size() >= target_limit:
			break
		targets.append(candidate)
	return targets


func _target_limit_for_weapon(weapon: StringName) -> int:
	var target_limit := 1
	match weapon:
		&"shotgun":
			target_limit = shotgun_targets_per_shot
		&"machinegun":
			target_limit = machinegun_targets_per_shot
		_:
			target_limit = 1
	if weapon != &"pistol":
		target_limit = mini(target_limit, _weapon_charge_remaining(weapon))
	return maxi(0, target_limit)


func _manual_aim_radius_for_weapon(weapon: StringName) -> float:
	if weapon == &"machinegun":
		return shotgun_spread_radius * 1.65
	return shotgun_spread_radius * 1.25


func _is_valid_enemy(enemy: Node2D) -> bool:
	return is_instance_valid(enemy) and enemy.is_in_group("enemies") and enemy.get("alive") != false


func _enemy_perimeter_key(enemy: Node2D) -> bool:
	return bool(enemy.get("is_mirrored"))


func _has_weapon_charge(weapon: StringName) -> bool:
	if weapon == &"pistol":
		return true
	return _weapon_charge_remaining(weapon) > 0


func _consume_weapon_charge(weapon: StringName, amount: int = 1) -> void:
	if weapon == &"pistol":
		return
	if amount <= 0:
		return
	var remaining: int = max(0, _weapon_charge_remaining(weapon) - amount)
	weapon_charges[weapon] = remaining
	if remaining <= 0:
		unlocked_weapons[weapon] = false
	weapon_charge_spent.emit(weapon, amount, remaining, _weapon_charge_capacity(weapon))


func _weapon_charge_remaining(weapon: StringName) -> int:
	return int(weapon_charges.get(weapon, 0))


func _weapon_charge_capacity(weapon: StringName) -> int:
	return int(weapon_charge_capacities.get(weapon, 1))


func _range_for_weapon(weapon: StringName) -> float:
	match weapon:
		&"shotgun":
			return shotgun_range
		&"machinegun":
			return machinegun_range
		_:
			return pistol_range


func _damage_for_weapon(weapon: StringName) -> int:
	match weapon:
		&"shotgun":
			return shotgun_damage
		&"machinegun":
			return machinegun_damage
		_:
			return pistol_damage


func _current_range() -> float:
	return _range_for_weapon(current_weapon)


func _current_fire_interval() -> float:
	match current_weapon:
		&"shotgun":
			return shotgun_fire_interval
		&"machinegun":
			return machinegun_fire_interval
		_:
			return pistol_fire_interval


func _current_damage() -> int:
	return _damage_for_weapon(current_weapon)


func _current_ray_width() -> float:
	if current_weapon == &"shotgun":
		return 2.4
	if current_weapon == &"machinegun":
		return 1.45
	return 1.75


func _clamp_to_map(point: Vector2) -> Vector2:
	return ZoneUtilsUtil.clamp_point(point, map_polygon, map_bounds)


func _is_inside_map(point: Vector2) -> bool:
	if map_polygon.size() >= 3:
		return ZoneUtilsUtil.contains_point(map_polygon, point)
	return map_bounds.has_point(point)


func _edge_target(direction: Vector2) -> Vector2:
	var safe_direction := direction.normalized()
	if safe_direction.length() <= 0.01:
		safe_direction = _random_isometric_direction()

	var last_valid := global_position
	var step_count := maxi(1, ceili(boundary_probe_distance / boundary_probe_step))
	for step_index in range(1, step_count + 1):
		var candidate := global_position + safe_direction * boundary_probe_step * float(step_index)
		if not _is_inside_map(candidate):
			break
		last_valid = candidate

	if last_valid.distance_to(global_position) <= stop_distance:
		last_valid = _clamp_to_map(global_position + safe_direction * boundary_retreat_distance * 2.0)
	return last_valid


func _random_isometric_direction() -> Vector2:
	var directions := [
		Vector2(1.0, 0.5).normalized(),
		Vector2(-1.0, 0.5).normalized(),
		Vector2(1.0, -0.5).normalized(),
		Vector2(-1.0, -0.5).normalized()
	]
	return directions.pick_random()


func _spawn_ray(start_position: Vector2, end_position: Vector2, color: Color, width: float, control_position: Vector2 = Vector2.INF) -> void:
	if ray_scene == null:
		return
	var parent := effects_root if effects_root != null else get_parent()
	var ray := ray_scene.instantiate()
	parent.add_child(ray)
	ray.setup(start_position, end_position, color, width, control_position)


func _animate(delta: float) -> void:
	var data: Dictionary = animation_frames.get(current_animation, {})
	var rects: Array = data.get("rects", [])
	var durations: Array = data.get("durations", [])
	if rects.is_empty():
		return

	if shooting_phase == &"fire":
		_try_fire_from_animation()

	var speed_multiplier: float = float(animation_speeds.get(current_animation, 1.0))
	frame_time += delta * speed_multiplier
	var duration: float = float(durations[frame_index % durations.size()])
	if frame_time < duration:
		return

	frame_time = 0.0
	if _is_shooting_animation(current_animation):
		_advance_shooting_frame(rects.size())
	else:
		frame_index = (frame_index + 1) % rects.size()
	_set_current_frame()


func _advance_shooting_frame(frame_total: int) -> void:
	var fire_start := _shoot_fire_start(current_animation)
	var fire_end := _shoot_fire_end(current_animation)

	if shooting_phase == &"intro":
		frame_index += 1
		if frame_index >= fire_start:
			frame_index = fire_start
			shooting_phase = &"fire"
			has_fired_in_fire_cycle = false
			fire_loop_repeats = 0
			_try_fire_from_animation()
		return

	if shooting_phase == &"fire":
		frame_index += 1
		if frame_index >= fire_end:
			if _should_hold_fire_loop() and fire_loop_repeats < _max_fire_loop_repeats():
				fire_loop_repeats += 1
				frame_index = fire_start
				has_fired_in_fire_cycle = false
			else:
				frame_index = fire_end
				shooting_phase = &"outro"
		return

	if shooting_phase == &"outro":
		frame_index += 1
		if frame_index >= frame_total:
			_finish_shooting()


func _prepare_animations() -> void:
	animation_frames = {
		&"down": SpriteSheetAnimatorUtil.make_loop_slice(SpriteSheetAnimatorUtil.load_sheet(walk_down_json, down_frame_size, sheet_columns, frame_count), 6, 35),
		&"up": SpriteSheetAnimatorUtil.make_loop_slice(SpriteSheetAnimatorUtil.load_sheet(walk_up_json, up_frame_size, sheet_columns, frame_count), 8, 26),
		&"idle_down": SpriteSheetAnimatorUtil.make_loop_slice(SpriteSheetAnimatorUtil.load_sheet(idle_down_json, idle_down_frame_size, sheet_columns, frame_count), 10, 20),
		&"idle_up": SpriteSheetAnimatorUtil.make_loop_slice(SpriteSheetAnimatorUtil.load_sheet(idle_up_json, idle_up_frame_size, sheet_columns, frame_count), 0, 21),
		&"shoot_pistol": SpriteSheetAnimatorUtil.load_sheet(pistol_shoot_json, pistol_shoot_frame_size, sheet_columns, frame_count),
		&"shoot_shotgun": SpriteSheetAnimatorUtil.load_sheet(shotgun_shoot_json, shotgun_shoot_frame_size, sheet_columns, frame_count),
		&"shoot_machinegun": SpriteSheetAnimatorUtil.load_sheet(machinegun_shoot_json, machinegun_shoot_frame_size, sheet_columns, frame_count)
	}
	animation_textures = {
		&"down": walk_down_texture,
		&"up": walk_up_texture,
		&"idle_down": idle_down_texture,
		&"idle_up": idle_up_texture,
		&"shoot_pistol": pistol_shoot_texture,
		&"shoot_shotgun": shotgun_shoot_texture,
		&"shoot_machinegun": machinegun_shoot_texture
	}
	animation_speeds = {
		&"down": walking_animation_speed,
		&"up": walking_animation_speed,
		&"idle_down": idle_animation_speed,
		&"idle_up": idle_animation_speed,
		&"shoot_pistol": shooting_animation_speed,
		&"shoot_shotgun": shooting_animation_speed,
		&"shoot_machinegun": shooting_animation_speed * 1.2
	}
	_set_frame(down_sprite, &"down", 0)
	_set_frame(up_sprite, &"up", 0)
	_set_frame(down_sprite, &"idle_down", 0)
	_set_frame(up_sprite, &"idle_up", 0)
	_set_frame(shoot_sprite, &"shoot_pistol", 0)


func _has_target_in_range() -> bool:
	if current_target == null or not is_instance_valid(current_target):
		return false
	if current_target.get("alive") == false:
		return false
	return global_position.distance_to(current_target.global_position) <= _current_range()


func _enter_shooting(force_restart: bool = false) -> void:
	var new_animation := _shoot_animation()
	if current_target != null and is_instance_valid(current_target):
		var direction := current_target.global_position - global_position
		if direction.length() > 0.01:
			last_shot_direction = direction.normalized()
			_face_shoot_direction(last_shot_direction)

	if current_animation != new_animation or force_restart:
		is_shooting = true
		shooting_phase = &"intro"
		has_fired_in_fire_cycle = false
		fire_loop_repeats = 0
		_switch_animation(new_animation, force_restart)
		return

	is_shooting = true
	if shooting_phase == &"none":
		shooting_phase = &"intro"
		fire_loop_repeats = 0
	elif shooting_phase == &"outro":
		shooting_phase = &"fire"
		frame_index = _shoot_fire_start(current_animation)
		has_fired_in_fire_cycle = false
		fire_loop_repeats = 0


func _finish_shooting() -> void:
	is_shooting = false
	shooting_phase = &"none"
	has_fired_in_fire_cycle = false
	fire_loop_repeats = 0
	_apply_walk_orientation(visual_orientation)


func _clear_target_after_shot() -> void:
	current_target = null
	auto_walk_after_shot = true
	retreating_from_boundary = false
	target_position = _edge_target(last_shot_direction)


func _should_hold_fire_loop() -> bool:
	if fire_cooldown > _shoot_fire_loop_duration(current_animation) * 0.85:
		return false
	if pending_manual_shot:
		return true
	if current_target == null or not is_instance_valid(current_target):
		return false
	if current_target.get("alive") == false:
		return false
	return global_position.distance_to(current_target.global_position) <= _current_range()


func _max_fire_loop_repeats() -> int:
	match current_weapon:
		&"shotgun":
			return shotgun_max_fire_loop_repeats
		&"machinegun":
			return machinegun_max_fire_loop_repeats
		_:
			return pistol_max_fire_loop_repeats


func _can_begin_shot_animation() -> bool:
	var animation := _shoot_animation()
	return fire_cooldown <= _shoot_intro_duration(animation) + 0.035


func _shoot_intro_duration(animation: StringName) -> float:
	var fire_start := _shoot_fire_start(animation)
	return _shoot_duration_between(animation, 0, fire_start)


func _shoot_fire_loop_duration(animation: StringName) -> float:
	var fire_start := _shoot_fire_start(animation)
	var fire_end := _shoot_fire_end(animation)
	return _shoot_duration_between(animation, fire_start, fire_end)


func _shoot_duration_between(animation: StringName, start_index: int, end_index: int) -> float:
	var data: Dictionary = animation_frames.get(animation, {})
	var durations: Array = data.get("durations", [])
	if durations.is_empty():
		return 0.0

	var safe_start := clampi(start_index, 0, durations.size())
	var safe_end := clampi(end_index, safe_start, durations.size())
	var duration_sum := 0.0
	for index in range(safe_start, safe_end):
		duration_sum += float(durations[index])

	var speed_multiplier: float = float(animation_speeds.get(animation, 1.0))
	return duration_sum / maxf(speed_multiplier, 0.001)


func _shoot_animation() -> StringName:
	match current_weapon:
		&"shotgun":
			return &"shoot_shotgun"
		&"machinegun":
			return &"shoot_machinegun"
		_:
			return &"shoot_pistol"


func _is_shooting_animation(animation: StringName) -> bool:
	return animation == &"shoot_pistol" or animation == &"shoot_shotgun" or animation == &"shoot_machinegun"


func _is_idle_animation(animation: StringName) -> bool:
	return animation == &"idle_down" or animation == &"idle_up"


func _shoot_fire_start(animation: StringName) -> int:
	if animation == &"shoot_pistol":
		return _clamped_shoot_frame(animation, pistol_fire_start_frame)
	return _shoot_frame_at_ratio(animation, shooting_fire_start_ratio)


func _shoot_fire_end(animation: StringName) -> int:
	if animation == &"shoot_pistol":
		return max(_shoot_fire_start(animation) + 1, _clamped_shoot_frame(animation, pistol_fire_end_frame))
	return max(_shoot_fire_start(animation) + 1, _shoot_frame_at_ratio(animation, shooting_fire_end_ratio))


func _clamped_shoot_frame(animation: StringName, frame: int) -> int:
	var data: Dictionary = animation_frames.get(animation, {})
	var rects: Array = data.get("rects", [])
	var total := maxi(1, rects.size())
	return clampi(frame, 1, total - 1)


func _shoot_frame_at_ratio(animation: StringName, ratio: float) -> int:
	var data: Dictionary = animation_frames.get(animation, {})
	var rects: Array = data.get("rects", [])
	var total := maxi(1, rects.size())
	return clampi(floori(float(total) * ratio), 1, total - 1)


func _face_shoot_direction(direction: Vector2) -> void:
	if absf(direction.x) > 0.01:
		is_facing_left_for_shot = direction.x < 0.0
		shoot_sprite.flip_h = is_facing_left_for_shot
	shoot_sprite.rotation_degrees = left_shoot_visual_rotation_degrees if is_facing_left_for_shot else right_shoot_visual_rotation_degrees
	visual_shot_direction = Vector2(-1.0 if is_facing_left_for_shot else 1.0, 0.08).normalized()
	muzzle_point.position = muzzle_left_offset if is_facing_left_for_shot else muzzle_right_offset


func _muzzle_world_position() -> Vector2:
	muzzle_point.position = muzzle_left_offset if is_facing_left_for_shot else muzzle_right_offset
	return muzzle_point.global_position


func _muzzle_control_point(aim_position: Vector2) -> Vector2:
	var start_position := _muzzle_world_position()
	var weapon_direction := visual_shot_direction
	var target_direction := (aim_position - start_position).normalized()
	if target_direction.length() <= 0.01:
		target_direction = weapon_direction
	var masked_direction := (weapon_direction * 0.72 + target_direction * 0.28).normalized()
	return start_position + masked_direction * muzzle_curve_distance


func _play_muzzle_flash() -> void:
	muzzle_flash.position = muzzle_point.position
	muzzle_flash.scale = Vector2(-1.0, 1.0) if is_facing_left_for_shot else Vector2.ONE
	muzzle_flash.rotation_degrees = left_shoot_visual_rotation_degrees if is_facing_left_for_shot else right_shoot_visual_rotation_degrees
	muzzle_flash.visible = true
	muzzle_flash.modulate = Color(1.0, 0.92, 0.32, 0.92)
	_play_character_shot_light()
	if muzzle_flash_tween != null:
		muzzle_flash_tween.kill()
	muzzle_flash_tween = create_tween()
	muzzle_flash_tween.set_parallel(true)
	muzzle_flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, muzzle_flash_duration)
	muzzle_flash_tween.tween_property(muzzle_flash, "scale", muzzle_flash.scale * 1.45, muzzle_flash_duration)
	muzzle_flash_tween.chain().tween_callback(func() -> void:
		muzzle_flash.visible = false
		muzzle_flash.scale = Vector2(-1.0, 1.0) if is_facing_left_for_shot else Vector2.ONE
		muzzle_flash.rotation_degrees = left_shoot_visual_rotation_degrees if is_facing_left_for_shot else right_shoot_visual_rotation_degrees
	)


func _play_character_shot_light() -> void:
	if shot_light_tween != null:
		shot_light_tween.kill()
	sprites_root.modulate = shot_light_color
	shot_light_tween = create_tween()
	shot_light_tween.tween_property(sprites_root, "modulate", Color.WHITE, shot_light_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_visual_direction(movement: Vector2, _delta: float) -> void:
	if not _turn_toward_direction(movement, _delta):
		orientation_change_walked_distance = 0.0


func _turn_toward_direction(direction: Vector2, delta: float) -> bool:
	var desired_orientation := _orientation_for_direction(direction)
	if desired_orientation != target_orientation:
		target_orientation = desired_orientation
		orientation_change_walked_distance = 0.0

	if visual_orientation == target_orientation:
		return false

	orientation_change_walked_distance += speed * delta
	if orientation_change_walked_distance >= orientation_change_distance:
		_step_visual_orientation()
		orientation_change_walked_distance = 0.0
		_apply_walk_orientation(visual_orientation)
	return true


func _orientation_for_direction(direction: Vector2) -> int:
	if direction.y < -0.01:
		return ORIENTATION_BACK_RIGHT if direction.x > 0.01 else ORIENTATION_BACK_LEFT
	return ORIENTATION_FRONT_LEFT if direction.x < -0.01 else ORIENTATION_FRONT_RIGHT


func _step_visual_orientation() -> void:
	var clockwise_steps: int = (target_orientation - visual_orientation + 4) % 4
	var counter_clockwise_steps: int = (visual_orientation - target_orientation + 4) % 4
	if clockwise_steps <= counter_clockwise_steps:
		visual_orientation = (visual_orientation + 1) % 4
	else:
		visual_orientation = (visual_orientation + 3) % 4


func _orientation_direction(orientation: int) -> Vector2:
	match orientation:
		ORIENTATION_BACK_LEFT:
			return Vector2(-1.0, -0.5).normalized()
		ORIENTATION_BACK_RIGHT:
			return Vector2(1.0, -0.5).normalized()
		ORIENTATION_FRONT_LEFT:
			return Vector2(-1.0, 0.5).normalized()
		_:
			return Vector2(1.0, 0.5).normalized()


func _apply_walk_orientation(new_orientation: int) -> void:
	var new_animation := _walk_animation_for_orientation(new_orientation)
	var was_shooting := _is_shooting_animation(current_animation)
	var was_idle := _is_idle_animation(current_animation)
	if current_animation != new_animation or was_shooting or was_idle:
		_switch_animation(new_animation, false, not was_shooting and not was_idle)
	var faces_right := _orientation_faces_right(new_orientation)
	down_sprite.flip_h = faces_right != down_faces_right
	up_sprite.flip_h = faces_right != up_faces_right


func _apply_idle_orientation(new_orientation: int, immediate: bool = false) -> void:
	var new_animation := _idle_animation_for_orientation(new_orientation)
	if current_animation != new_animation or immediate:
		_switch_animation(new_animation, immediate)
	var faces_right := _orientation_faces_right(new_orientation)
	down_sprite.flip_h = faces_right != down_faces_right
	up_sprite.flip_h = faces_right != up_faces_right


func _walk_animation_for_orientation(new_orientation: int) -> StringName:
	if new_orientation == ORIENTATION_BACK_LEFT or new_orientation == ORIENTATION_BACK_RIGHT:
		return &"up"
	return &"down"


func _idle_animation_for_orientation(new_orientation: int) -> StringName:
	if new_orientation == ORIENTATION_BACK_LEFT or new_orientation == ORIENTATION_BACK_RIGHT:
		return &"idle_up"
	return &"idle_down"


func _orientation_faces_right(new_orientation: int) -> bool:
	return new_orientation == ORIENTATION_BACK_RIGHT or new_orientation == ORIENTATION_FRONT_RIGHT


func _switch_animation(new_animation: StringName, immediate: bool = false, preserve_frame: bool = false) -> void:
	var changed := current_animation != new_animation or immediate
	if not changed:
		return

	current_animation = new_animation
	if not preserve_frame:
		frame_time = 0.0
		frame_index = 0
	_set_current_frame()
	if transition_tween != null:
		transition_tween.kill()

	var active_sprite := _active_sprite()
	var sprites := [down_sprite, up_sprite, shoot_sprite]
	for sprite in sprites:
		sprite.modulate.a = 1.0 if sprite == active_sprite else 0.0


func _configure_sprite_filtering() -> void:
	for sprite in [down_sprite, up_sprite, shoot_sprite]:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _active_sprite() -> Sprite2D:
	match current_animation:
		&"up", &"idle_up":
			return up_sprite
		&"shoot_pistol", &"shoot_shotgun", &"shoot_machinegun":
			return shoot_sprite
		_:
			return down_sprite


func _set_current_frame() -> void:
	_set_frame(_active_sprite(), current_animation, frame_index)


func _set_frame(sprite: Sprite2D, animation: StringName, index: int) -> void:
	var data: Dictionary = animation_frames.get(animation, {})
	var rects: Array = data.get("rects", [])
	if rects.is_empty():
		return
	var texture: Texture2D = animation_textures.get(animation, null)
	if texture != null:
		sprite.texture = texture
	sprite.region_enabled = true
	var rect: Rect2 = rects[index % rects.size()]
	sprite.region_rect = rect
	sprite.offset = Vector2(0.0, -rect.size.y * 0.5)
	var sprite_scale := _sprite_scale_for_animation(animation)
	sprite.scale = Vector2(sprite_scale, sprite_scale)


func _sprite_scale_for_animation(animation: StringName) -> float:
	match animation:
		&"idle_down":
			return idle_down_sprite_scale
		&"idle_up":
			return idle_up_sprite_scale
		&"shoot_pistol":
			return pistol_shoot_sprite_scale
		&"shoot_shotgun":
			return shotgun_shoot_sprite_scale
		&"shoot_machinegun":
			return machinegun_shoot_sprite_scale
		_:
			return walk_sprite_scale
