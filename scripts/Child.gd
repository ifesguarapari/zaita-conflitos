extends Node2D

const SpriteSheetAnimatorUtil = preload("res://scripts/SpriteSheetAnimator.gd")
const ZoneUtilsUtil = preload("res://scripts/ZoneUtils.gd")

signal hit(child: Node2D)
signal death_sequence_finished(child: Node2D)

const ORIENTATION_BACK_LEFT := 0
const ORIENTATION_BACK_RIGHT := 1
const ORIENTATION_FRONT_RIGHT := 2
const ORIENTATION_FRONT_LEFT := 3

@export var child_name: String = "Zaíta"
@export var walk_zone: Rect2 = Rect2(430.0, 155.0, 420.0, 180.0)
@export var walk_polygon: PackedVector2Array = PackedVector2Array()
@export var speed: float = 18.0
@export var min_step_distance: float = 32.0
@export var max_step_distance: float = 86.0
@export var min_pause: float = 2.4
@export var max_pause: float = 4.8
@export_group("Sprite sheet animation")
@export_file("*.json") var walk_down_json: String = "res://assets/sprites/zaita-walking-front-left.json"
@export_file("*.json") var walk_up_json: String = "res://assets/sprites/zaita-walking-back-right.json"
@export var idle_down_texture: Texture2D = preload("res://assets/sprites/zaita-idle-front-left.png")
@export var idle_up_texture: Texture2D = preload("res://assets/sprites/zaita-idle-back-right.png")
@export var getting_shot_texture: Texture2D = preload("res://assets/sprites/zaita-getting-shot-front-left.png")
@export var dying_texture: Texture2D = preload("res://assets/sprites/zaita-dying-front-left.png")
@export var lowering_texture: Texture2D = preload("res://assets/sprites/zaita-lowering-front-left.png")
@export_file("*.json") var idle_down_json: String = "res://assets/sprites/zaita-idle-front-left.json"
@export_file("*.json") var idle_up_json: String = "res://assets/sprites/zaita-idle-back-right.json"
@export_file("*.json") var getting_shot_json: String = "res://assets/sprites/zaita-getting-shot-front-left.json"
@export_file("*.json") var dying_json: String = "res://assets/sprites/zaita-dying-front-left.json"
@export_file("*.json") var lowering_json: String = "res://assets/sprites/zaita-lowering-front-left.json"
@export var down_frame_size: Vector2i = Vector2i(312, 596)
@export var up_frame_size: Vector2i = Vector2i(230, 640)
@export var idle_down_frame_size: Vector2i = Vector2i(188, 552)
@export var idle_up_frame_size: Vector2i = Vector2i(234, 540)
@export var getting_shot_frame_size: Vector2i = Vector2i(306, 524)
@export var dying_frame_size: Vector2i = Vector2i(552, 612)
@export var lowering_frame_size: Vector2i = Vector2i(232, 488)
@export var sheet_columns: int = 6
@export var frame_count: int = 36
@export var orientation_change_distance: float = 9.0
@export var turn_drift_speed_multiplier: float = 0.24
@export var animation_transition_duration: float = 0.2
@export var walking_animation_speed: float = 1.12
@export var idle_animation_speed: float = 0.58
@export var getting_shot_animation_speed: float = 1.0
@export var dying_animation_speed: float = 1.0
@export var lowering_animation_speed: float = 1.16
@export var lowering_hold_frame: int = 17
@export var down_sprite_scale: float = 0.137
@export var up_sprite_scale: float = 0.127
@export var idle_down_sprite_scale: float = 0.148
@export var idle_up_sprite_scale: float = 0.151
@export var getting_shot_sprite_scale: float = 0.156
@export var dying_sprite_scale: float = 0.158
@export var lowering_sprite_scale: float = 0.168
@export var lowering_chance_after_idle: float = 0.38
@export var min_lowering_duration: float = 1.35
@export var max_lowering_duration: float = 2.35
@export var down_faces_right: bool = false
@export var up_faces_right: bool = true
@export var character_tint: Color = Color.WHITE

@onready var down_sprite: Sprite2D = $Sprites/DownSprite
@onready var up_sprite: Sprite2D = $Sprites/UpSprite

var active: bool = false
var alive: bool = true
var is_lowering: bool = false
var is_dying: bool = false
var target_position: Vector2
var pause_time: float = 0.0
var lowering_time_left: float = 0.0
var lowering_phase: StringName = &"none"
var frame_time: float = 0.0
var frame_index: int = 0
var current_animation: StringName = &"down"
var animation_frames: Dictionary = {}
var animation_textures: Dictionary = {}
var animation_speeds: Dictionary = {}
var visual_orientation: int = ORIENTATION_FRONT_LEFT
var target_orientation: int = ORIENTATION_FRONT_LEFT
var orientation_change_walked_distance: float = 0.0
var transition_tween: Tween


func _ready() -> void:
	add_to_group("children")
	_configure_sprite_filtering()
	down_sprite.modulate = character_tint
	up_sprite.modulate = Color(character_tint.r, character_tint.g, character_tint.b, 0.0)
	target_position = global_position
	_prepare_animations()
	_apply_idle_orientation(visual_orientation)
	pause_time = randf_range(min_pause, max_pause)


func _process(delta: float) -> void:
	if not active or not alive:
		return

	if is_lowering:
		_process_lowering(delta)
		return

	if pause_time > 0.0:
		pause_time -= delta
		_animate(delta)
		if pause_time <= 0.0:
			if randf() < lowering_chance_after_idle:
				_begin_lowering()
			else:
				_choose_new_target()
		return

	var previous_position := global_position
	var desired_movement := target_position - global_position
	var is_turning := false
	if desired_movement.length() > 0.1:
		is_turning = _turn_toward_direction(desired_movement, delta)

	if is_turning:
		global_position = _clamp_to_zone(global_position + _orientation_direction(visual_orientation) * speed * turn_drift_speed_multiplier * delta)
	else:
		global_position = global_position.move_toward(target_position, speed * delta)

	var movement := global_position - previous_position

	if is_turning:
		_animate(delta)
	elif movement.length() > 0.1:
		_update_visual_direction(movement, delta)
		_apply_walk_orientation(visual_orientation)
		_animate(delta)

	if not is_turning and global_position.distance_to(target_position) <= 2.0:
		_begin_idle_pause()


func set_active(value: bool) -> void:
	active = value


func reset(initial_position: Vector2, new_zone: Rect2, new_polygon: PackedVector2Array = PackedVector2Array()) -> void:
	walk_zone = new_zone
	walk_polygon = new_polygon
	global_position = initial_position
	target_position = initial_position
	pause_time = 0.0
	frame_time = 0.0
	frame_index = 0
	current_animation = &"down"
	alive = true
	is_lowering = false
	lowering_phase = &"none"
	is_dying = false
	active = false
	visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE
	down_sprite.modulate = character_tint
	up_sprite.modulate = Color(character_tint.r, character_tint.g, character_tint.b, 0.0)
	visual_orientation = ORIENTATION_FRONT_LEFT
	target_orientation = ORIENTATION_FRONT_LEFT
	orientation_change_walked_distance = 0.0
	lowering_time_left = 0.0
	lowering_phase = &"none"
	_apply_idle_orientation(visual_orientation, true)
	_set_current_frame()
	pause_time = randf_range(min_pause, max_pause)


func take_shot() -> void:
	if not alive or is_dying:
		return
	if is_lowering:
		return

	is_dying = true
	alive = false
	active = false
	pause_time = 0.0
	lowering_time_left = 0.0
	lowering_phase = &"none"
	hit.emit(self)
	await _play_death_sequence()
	death_sequence_finished.emit(self)


func _choose_new_target() -> void:
	is_lowering = false
	var directions := [
		Vector2(1.0, 0.5).normalized(),
		Vector2(-1.0, -0.5).normalized(),
		Vector2(1.0, -0.5).normalized(),
		Vector2(-1.0, 0.5).normalized()
	]
	var candidates: Array[Vector2] = []
	for direction: Vector2 in directions:
		for _attempt in range(3):
			var distance := randf_range(min_step_distance, max_step_distance)
			var candidate := _clamp_to_zone(global_position + direction * distance)
			if global_position.distance_to(candidate) >= min_step_distance * 0.55:
				candidates.append(candidate)

	if not candidates.is_empty():
		target_position = candidates.pick_random()
		return

	for _attempt in range(6):
		var fallback := ZoneUtilsUtil.random_point(walk_polygon, walk_zone)
		if global_position.distance_to(fallback) >= min_step_distance * 0.55:
			target_position = fallback
			return

	target_position = global_position


func _begin_idle_pause() -> void:
	is_lowering = false
	lowering_phase = &"none"
	target_position = global_position
	pause_time = randf_range(min_pause, max_pause)
	_apply_idle_orientation(visual_orientation)


func _begin_lowering() -> void:
	if not _is_idle_animation(current_animation):
		_begin_idle_pause()
		return

	is_lowering = true
	lowering_phase = &"enter"
	lowering_time_left = randf_range(min_lowering_duration, max_lowering_duration)
	pause_time = 0.0
	target_position = global_position
	_apply_lowering_orientation(visual_orientation)
	frame_index = 0
	frame_time = 0.0
	_set_current_frame()


func _process_lowering(delta: float) -> void:
	if lowering_phase == &"enter":
		if _advance_lowering_frame(delta, 1, _lowering_hold_frame()):
			lowering_phase = &"hold"
			frame_index = _lowering_hold_frame()
			frame_time = 0.0
			_set_current_frame()
		return

	if lowering_phase == &"hold":
		lowering_time_left -= delta
		if lowering_time_left <= 0.0:
			lowering_phase = &"exit"
			frame_index = _lowering_hold_frame()
			frame_time = 0.0
			_set_current_frame()
		return

	if lowering_phase == &"exit":
		if _advance_lowering_frame(delta, -1, 0):
			_begin_idle_pause()


func _advance_lowering_frame(delta: float, direction: int, target_frame: int) -> bool:
	var data: Dictionary = animation_frames.get(&"lowering", {})
	var rects: Array = data.get("rects", [])
	var durations: Array = data.get("durations", [])
	if rects.is_empty():
		return true

	var current_frame := clampi(frame_index, 0, rects.size() - 1)
	frame_time += delta * lowering_animation_speed
	var duration: float = float(durations[current_frame % durations.size()])
	if frame_time < duration:
		return false

	frame_time = 0.0
	frame_index = clampi(frame_index + direction, 0, rects.size() - 1)
	_set_current_frame()
	return frame_index == target_frame


func _lowering_hold_frame() -> int:
	var data: Dictionary = animation_frames.get(&"lowering", {})
	var rects: Array = data.get("rects", [])
	if rects.is_empty():
		return 0
	return clampi(lowering_hold_frame, 0, rects.size() - 1)


func _clamp_to_zone(point: Vector2) -> Vector2:
	return ZoneUtilsUtil.clamp_point(point, walk_polygon, walk_zone)


func _animate(delta: float) -> void:
	var data: Dictionary = animation_frames.get(current_animation, {})
	var rects: Array = data.get("rects", [])
	var durations: Array = data.get("durations", [])
	if rects.is_empty():
		return

	var speed_multiplier: float = float(animation_speeds.get(current_animation, walking_animation_speed))
	frame_time += delta * speed_multiplier
	var duration: float = float(durations[frame_index % durations.size()])
	if frame_time >= duration:
		frame_time = 0.0
		frame_index = (frame_index + 1) % rects.size()
		_set_current_frame()


func _prepare_animations() -> void:
	animation_frames = {
		&"down": SpriteSheetAnimatorUtil.make_loop_slice(SpriteSheetAnimatorUtil.load_sheet(walk_down_json, down_frame_size, sheet_columns, frame_count), 4, 24),
		&"up": SpriteSheetAnimatorUtil.make_loop_slice(SpriteSheetAnimatorUtil.load_sheet(walk_up_json, up_frame_size, sheet_columns, frame_count), 9, 32),
		&"idle_down": SpriteSheetAnimatorUtil.make_loop_slice(SpriteSheetAnimatorUtil.load_sheet(idle_down_json, idle_down_frame_size, sheet_columns, frame_count), 6, 31),
		&"idle_up": SpriteSheetAnimatorUtil.make_loop_slice(SpriteSheetAnimatorUtil.load_sheet(idle_up_json, idle_up_frame_size, sheet_columns, frame_count), 0, 35),
		&"getting_shot": SpriteSheetAnimatorUtil.load_sheet(getting_shot_json, getting_shot_frame_size, sheet_columns, frame_count),
		&"dying": SpriteSheetAnimatorUtil.load_sheet(dying_json, dying_frame_size, sheet_columns, frame_count),
		&"lowering": SpriteSheetAnimatorUtil.load_sheet(lowering_json, lowering_frame_size, sheet_columns, frame_count)
	}
	animation_textures = {
		&"down": down_sprite.texture,
		&"up": up_sprite.texture,
		&"idle_down": idle_down_texture,
		&"idle_up": idle_up_texture,
		&"getting_shot": getting_shot_texture,
		&"dying": dying_texture,
		&"lowering": lowering_texture
	}
	animation_speeds = {
		&"down": walking_animation_speed,
		&"up": walking_animation_speed,
		&"idle_down": idle_animation_speed,
		&"idle_up": idle_animation_speed,
		&"getting_shot": getting_shot_animation_speed,
		&"dying": dying_animation_speed,
		&"lowering": lowering_animation_speed
	}
	_set_frame(down_sprite, &"down", 0)
	_set_frame(up_sprite, &"up", 0)


func _play_death_sequence() -> void:
	var faces_right := _orientation_faces_right(visual_orientation)
	visual_orientation = ORIENTATION_FRONT_RIGHT if faces_right else ORIENTATION_FRONT_LEFT
	target_orientation = visual_orientation
	_apply_front_action_animation(&"getting_shot", faces_right)
	await _play_current_animation_once()
	_apply_front_action_animation(&"dying", faces_right)
	await _play_current_animation_once()


func _play_current_animation_once() -> void:
	var data: Dictionary = animation_frames.get(current_animation, {})
	var rects: Array = data.get("rects", [])
	var durations: Array = data.get("durations", [])
	if rects.is_empty():
		return

	var speed_multiplier: float = float(animation_speeds.get(current_animation, 1.0))
	for index in range(rects.size()):
		frame_index = index
		frame_time = 0.0
		_set_current_frame()
		var duration: float = float(durations[index % durations.size()]) / maxf(0.01, speed_multiplier)
		await get_tree().create_timer(duration).timeout


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
	if current_animation != new_animation:
		_switch_animation(new_animation)
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


func _apply_lowering_orientation(new_orientation: int) -> void:
	var faces_right := _orientation_faces_right(new_orientation)
	_apply_front_action_animation(&"lowering", faces_right)


func _apply_front_action_animation(new_animation: StringName, faces_right: bool) -> void:
	if current_animation != new_animation:
		_switch_animation(new_animation, true)
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


func _is_idle_animation(animation: StringName) -> bool:
	return animation == &"idle_down" or animation == &"idle_up"


func _switch_animation(new_animation: StringName, immediate: bool = false) -> void:
	if current_animation == new_animation and not immediate:
		return

	current_animation = new_animation
	frame_time = 0.0
	frame_index = 0
	_set_current_frame()
	if transition_tween != null:
		transition_tween.kill()

	var active_sprite := _active_sprite()
	var inactive_sprite := up_sprite if active_sprite == down_sprite else down_sprite
	active_sprite.modulate.a = character_tint.a
	inactive_sprite.modulate.a = 0.0


func _configure_sprite_filtering() -> void:
	for sprite in [down_sprite, up_sprite]:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _active_sprite() -> Sprite2D:
	if current_animation == &"up" or current_animation == &"idle_up":
		return up_sprite
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
		&"getting_shot":
			return getting_shot_sprite_scale
		&"dying":
			return dying_sprite_scale
		&"lowering":
			return lowering_sprite_scale
		&"up":
			return up_sprite_scale
		_:
			return down_sprite_scale
