extends Node2D

const SpriteSheetAnimatorUtil = preload("res://scripts/SpriteSheetAnimator.gd")

signal expired(turret: Node2D)

@export var attack_range: float = 340.0
@export var shoot_interval: float = 0.125
@export var damage_per_shot: int = 1
@export var cost_per_shot: int = 0
@export var duration_seconds: float = 5.0
@export var ammo_limit: int = 40
@export var block_radius: float = 34.0
@export var ray_scene: PackedScene
@export var prop_sprite_scale: float = 0.14
@export var muzzle_right_offset: Vector2 = Vector2(34.0, -52.0)
@export var muzzle_left_offset: Vector2 = Vector2(-34.0, -52.0)
@export var muzzle_curve_distance: float = 46.0
@export var muzzle_flash_duration: float = 0.04
@export_group("Shooting animation")
@export var shooting_texture: Texture2D = preload("res://assets/props/rotarygun-shooting.png")
@export_file("*.json") var shooting_json: String = "res://assets/props/rotarygun-shooting.json"
@export var shooting_frame_size: Vector2i = Vector2i(640, 606)

@onready var sprite: Sprite2D = $Sprite
@onready var muzzle_flash: Polygon2D = $MuzzleFlash

var active: bool = false
var time_left: float = 5.0
var shots_left: int = 40
var fire_cooldown: float = 0.0
var effects_root: Node
var try_spend_skulls: Callable
var shooting_frames: Dictionary = {}
var facing_sign: float = 1.0
var frame_time: float = 0.0
var frame_index: int = 0
var muzzle_flash_tween: Tween


func _ready() -> void:
	add_to_group("turrets")
	add_to_group("protectors")
	z_index = 30
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	shooting_frames = SpriteSheetAnimatorUtil.load_sheet(shooting_json, shooting_frame_size, 5, 25)
	reset()


func _process(delta: float) -> void:
	if not active:
		return

	time_left -= delta
	fire_cooldown = max(0.0, fire_cooldown - delta)
	_advance_shooting_animation(delta)

	if time_left <= 0.0 or shots_left <= 0:
		_expire()
		return

	var target := _find_enemy()
	if target == null:
		return

	if fire_cooldown <= 0.0 and _spend_skulls():
		fire_cooldown = shoot_interval
		shots_left -= 1
		_spawn_ray(_muzzle_position(), target.global_position, _muzzle_control_point(target.global_position))
		_play_muzzle_flash(target.global_position)
		target.take_damage(damage_per_shot)


func configure(effects_node: Node, spend_callback: Callable) -> void:
	effects_root = effects_node
	try_spend_skulls = spend_callback
	active = true
	time_left = duration_seconds
	shots_left = ammo_limit
	fire_cooldown = 0.0
	frame_time = 0.0
	frame_index = 0
	modulate = Color.WHITE
	visible = true
	scale = Vector2.ONE
	_set_current_frame()


func reset() -> void:
	active = false
	time_left = duration_seconds
	shots_left = ammo_limit
	fire_cooldown = 0.0
	frame_time = 0.0
	frame_index = 0
	visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE
	_set_current_frame()


func set_facing_right(faces_right: bool) -> void:
	facing_sign = 1.0 if faces_right else -1.0
	if sprite != null:
		sprite.scale.x = absf(sprite.scale.x) * facing_sign


func _find_enemy() -> Node2D:
	var best: Node2D
	var best_distance := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.alive:
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= attack_range and distance < best_distance:
			best = enemy
			best_distance = distance
	return best


func _spend_skulls() -> bool:
	if cost_per_shot <= 0:
		return true
	if try_spend_skulls.is_valid():
		return try_spend_skulls.call(cost_per_shot)
	return false


func _spawn_ray(start_position: Vector2, end_position: Vector2, control_position: Vector2) -> void:
	if ray_scene == null:
		return
	var parent := effects_root if effects_root != null else get_parent()
	var ray := ray_scene.instantiate()
	parent.add_child(ray)
	ray.setup(start_position, end_position, Color(1.0, 0.86, 0.12, 1.0), 2.2, control_position, 0.04)


func _muzzle_position() -> Vector2:
	var muzzle_offset := muzzle_right_offset if facing_sign > 0.0 else muzzle_left_offset
	return global_position + muzzle_offset


func _muzzle_control_point(aim_position: Vector2) -> Vector2:
	var start_position := _muzzle_position()
	var weapon_direction := Vector2(facing_sign, -0.1).normalized()
	var target_direction := (aim_position - start_position).normalized()
	if target_direction.length() <= 0.01:
		target_direction = weapon_direction
	var masked_direction := (weapon_direction * 0.62 + target_direction * 0.38).normalized()
	return start_position + masked_direction * muzzle_curve_distance


func _play_muzzle_flash(aim_position: Vector2) -> void:
	var muzzle_offset := muzzle_right_offset if facing_sign > 0.0 else muzzle_left_offset
	var direction := aim_position - _muzzle_position()
	if direction.length() <= 0.01:
		direction = Vector2(facing_sign, -0.1)

	muzzle_flash.position = muzzle_offset
	muzzle_flash.rotation = direction.angle()
	muzzle_flash.visible = true
	muzzle_flash.modulate = Color(1.0, 0.82, 0.18, 0.92)
	muzzle_flash.scale = Vector2.ONE

	if muzzle_flash_tween != null:
		muzzle_flash_tween.kill()
	muzzle_flash_tween = create_tween()
	muzzle_flash_tween.set_parallel(true)
	muzzle_flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, muzzle_flash_duration)
	muzzle_flash_tween.tween_property(muzzle_flash, "scale", Vector2.ONE * 1.45, muzzle_flash_duration)
	muzzle_flash_tween.chain().tween_callback(func() -> void:
		muzzle_flash.visible = false
		muzzle_flash.scale = Vector2.ONE
	)


func _expire() -> void:
	active = false
	expired.emit(self)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.45)
	tween.tween_property(self, "scale", Vector2.ONE * 0.78, 0.45)
	tween.chain().tween_callback(queue_free)


func _advance_shooting_animation(delta: float) -> void:
	var rects: Array = shooting_frames.get("rects", [])
	var durations: Array = shooting_frames.get("durations", [])
	if rects.is_empty():
		return

	frame_time += delta
	var duration: float = float(durations[frame_index % durations.size()])
	if frame_time < duration:
		return

	frame_time = 0.0
	frame_index = (frame_index + 1) % rects.size()
	_set_current_frame()


func _set_current_frame() -> void:
	var rects: Array = shooting_frames.get("rects", [])
	if sprite == null or rects.is_empty():
		return

	sprite.texture = shooting_texture
	sprite.region_enabled = true
	var rect: Rect2 = rects[frame_index % rects.size()]
	sprite.region_rect = rect
	sprite.offset = Vector2(0.0, -rect.size.y * 0.5)
	sprite.scale = Vector2(prop_sprite_scale * facing_sign, prop_sprite_scale)
