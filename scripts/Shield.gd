extends Node2D

const SpriteSheetAnimatorUtil = preload("res://scripts/SpriteSheetAnimator.gd")

signal destroyed(shield: Node2D)

@export var max_health: int = 20
@export var block_radius: float = 38.0
@export var prop_sprite_scale: float = 0.14
@export var explosion_scale: float = 1.12
@export var explosion_duration: float = 0.42
@export var explosion_recoil: Vector2 = Vector2(22.0, 12.0)
@export_group("Animacoes do shield")
@export var idle_texture: Texture2D = preload("res://assets/props/shield.png")
@export var impact_texture: Texture2D = preload("res://assets/props/shield-getting-shot.png")
@export var explosion_texture: Texture2D = preload("res://assets/props/shield-exploding.png")
@export_file("*.json") var impact_json: String = "res://assets/props/shield-getting-shot.json"
@export_file("*.json") var explosion_json: String = "res://assets/props/shield-exploding.json"
@export var impact_frame_size: Vector2i = Vector2i(302, 522)
@export var explosion_frame_size: Vector2i = Vector2i(640, 640)

@onready var sprite: Sprite2D = $Sprite

var health: int = max_health
var active: bool = true
var impact_frames: Dictionary = {}
var explosion_frames: Dictionary = {}
var animation_sequence: int = 0
var facing_sign: float = 1.0


func _ready() -> void:
	add_to_group("shields")
	add_to_group("protectors")
	z_index = 30
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	impact_frames = SpriteSheetAnimatorUtil.load_sheet(impact_json, impact_frame_size, 4, 28)
	explosion_frames = SpriteSheetAnimatorUtil.load_sheet(explosion_json, explosion_frame_size, 5, 25)
	reset()


func reset() -> void:
	health = max_health
	active = true
	visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE
	sprite.texture = idle_texture
	sprite.region_enabled = false
	sprite.offset = Vector2(0, -356)
	sprite.scale = Vector2(prop_sprite_scale * facing_sign, prop_sprite_scale)


func set_facing_right(faces_right: bool) -> void:
	facing_sign = 1.0 if faces_right else -1.0
	if sprite != null:
		sprite.scale.x = absf(sprite.scale.x) * facing_sign


func take_damage(amount: int) -> void:
	if not active:
		return

	health = max(0, health - amount)

	if health <= 0:
		_destroy_safely()
	else:
		_play_impact_animation()


func _flash_impact() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.92, 0.35, 1.0), 0.06)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)


func _destroy_safely() -> void:
	active = false
	destroyed.emit(self)
	animation_sequence += 1
	_play_sheet_animation(explosion_texture, explosion_frames, animation_sequence, true)

	var recoil := Vector2(-explosion_recoil.x * facing_sign, explosion_recoil.y)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + recoil, explosion_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * explosion_scale, explosion_duration)
	tween.tween_property(self, "modulate:a", 0.0, explosion_duration).set_delay(0.22)


func _play_impact_animation() -> void:
	_flash_impact()
	animation_sequence += 1
	_play_sheet_animation(impact_texture, impact_frames, animation_sequence, false)


func _play_sheet_animation(texture: Texture2D, data: Dictionary, animation_id: int, remove_at_end: bool) -> void:
	if texture == null:
		return

	var rects: Array = data.get("rects", [])
	var durations: Array = data.get("durations", [])
	if rects.is_empty():
		return

	sprite.texture = texture
	sprite.region_enabled = true
	sprite.scale = Vector2(prop_sprite_scale * facing_sign, prop_sprite_scale)
	for index in range(rects.size()):
		if animation_sequence != animation_id:
			return
		var rect: Rect2 = rects[index]
		sprite.region_rect = rect
		sprite.offset = Vector2(0.0, -rect.size.y * 0.5)
		await get_tree().create_timer(float(durations[index]) * 0.65).timeout

	if remove_at_end:
		queue_free()
	elif active and animation_sequence == animation_id:
		sprite.texture = idle_texture
		sprite.region_enabled = false
		sprite.offset = Vector2(0, -356)
		sprite.scale = Vector2(prop_sprite_scale * facing_sign, prop_sprite_scale)
