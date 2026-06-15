extends Node2D

const ZoneUtilsUtil = preload("res://scripts/ZoneUtils.gd")

@export var enemy_scene: PackedScene
@export var shield_scene: PackedScene
@export var turret_scene: PackedScene
@export var ray_scene: PackedScene

@export_group("Editable zones")
@export var children_walk_zone: Rect2 = Rect2(958.0, 176.0, 375.0, 103.0)
@export var enemy_spawn_left_zone: Rect2 = Rect2(252.0, 323.0, 592.0, 264.0)
@export var enemy_spawn_right_zone: Rect2 = Rect2(1077.0, 375.0, 609.0, 505.0)
@export var enemy_walk_zone: Rect2 = Rect2(252.0, 323.0, 1434.0, 557.0)
@export var player_walk_zone: Rect2 = Rect2(958.0, 176.0, 375.0, 103.0)
@export var item_place_zone: Rect2 = Rect2(570.0, 330.0, 1100.0, 270.0)
@export var safe_boundary_place_tolerance: float = 58.0
@export var safe_zone_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(958.0, 200.0),
	Vector2(1043.0, 176.0),
	Vector2(1333.0, 247.0),
	Vector2(1220.0, 279.0)
])
@export var item_place_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(856.0, 219.0),
	Vector2(925.0, 201.0),
	Vector2(1272.0, 305.0),
	Vector2(1191.0, 348.0)
])
@export var item_mirrored_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(1218.0, 318.0),
	Vector2(1387.0, 277.0),
	Vector2(1454.0, 309.0),
	Vector2(1275.0, 366.0)
])
@export var enemy_red_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(252.0, 418.0),
	Vector2(475.0, 323.0),
	Vector2(768.0, 365.0),
	Vector2(844.0, 454.0),
	Vector2(556.0, 587.0)
])
@export var enemy_blue_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(1077.0, 610.0),
	Vector2(1561.0, 375.0),
	Vector2(1686.0, 513.0),
	Vector2(1625.0, 880.0),
	Vector2(1222.0, 686.0)
])
@export var sewer_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(100.0, 552.0),
	Vector2(148.0, 554.0),
	Vector2(182.0, 600.0),
	Vector2(215.0, 642.0),
	Vector2(250.0, 674.0),
	Vector2(276.0, 718.0),
	Vector2(305.0, 760.0),
	Vector2(330.0, 806.0),
	Vector2(355.0, 858.0),
	Vector2(374.0, 910.0),
	Vector2(380.0, 930.0),
	Vector2(200.0, 930.0),
	Vector2(170.0, 858.0),
	Vector2(136.0, 780.0),
	Vector2(100.0, 710.0)
])

@export_group("Economy")
@export var initial_skulls: int = 0
@export var shotgun_unlock_cost: int = 10
@export var machinegun_unlock_cost: int = 30
@export var shield_cost: int = 20
@export var turret_cost: int = 40

@export_group("Flow")
@export var debug_mode: bool = false
@export var initial_spawn_interval: float = 7.0
@export var second_spawn_interval: float = 6.0
@export var final_spawn_interval: float = 5.0
@export var first_spawn_stage_waves: int = 8
@export var second_spawn_stage_waves: int = 10
@export var parallax_strength: float = 0.045
@export var background_2_parallax_margin: float = 1.08
@export var enemy_click_radius: float = 104.0

@export_group("Camera")
@export var camera_fit_margin: float = 1.0
@export var camera_smoothing: float = 5.5
@export var death_camera_zoom_multiplier: float = 1.85
@export var death_camera_vertical_offset: float = -52.0
@export var death_camera_smoothing: float = 2.4
@export var shot_camera_zoom_multiplier: float = 1.13
@export var shot_camera_focus_blend: float = 0.42
@export var shot_camera_duration: float = 0.2
@export var shot_camera_smoothing: float = 13.0
@export var shot_camera_shake_duration: float = 0.16
@export var shot_camera_shake_strength: float = 5.5

@onready var distant_background: Sprite2D = $Backgrounds/BackgroundDistant
@onready var map_background: Sprite2D = $Backgrounds/BackgroundMap
@onready var camera: Camera2D = $Camera2D
@onready var player: Node2D = $Actors/Brother
@onready var zaita: Node2D = $Actors/Zaita
@onready var naita: Node2D = $Actors/Naita
@onready var actors: Node2D = $Actors
@onready var items: Node2D = $Items
@onready var effects: Node2D = $Effects
@onready var spawn_timer: Timer = $SpawnTimer
@onready var hud: CanvasLayer = $HUD
@onready var start_popup: CanvasLayer = $StartPopup
@onready var game_over_popup: CanvasLayer = $GameOverPopup

var is_game_active: bool = false
var black_skulls: int = 0
var current_weapon: StringName = &"pistol"
var unlocked_weapons := {
	&"pistol": true,
	&"shotgun": false,
	&"machinegun": false
}
var placement_mode: StringName = &""
var initial_player_position: Vector2
var initial_zaita_position: Vector2
var initial_naita_position: Vector2
var initial_parallax_position: Vector2
var parallax_reference_position: Vector2
var is_game_over_sequence: bool = false
var base_camera_zoom: Vector2 = Vector2.ONE
var death_camera_focus_active: bool = false
var death_camera_focus_position: Vector2 = Vector2.ZERO
var shot_camera_time_left: float = 0.0
var shot_camera_shake_time_left: float = 0.0
var shot_camera_focus_position: Vector2 = Vector2.ZERO
var spawn_wave_index: int = 0


func _ready() -> void:
	randomize()
	_fit_backgrounds()
	get_viewport().size_changed.connect(_on_viewport_resized)
	initial_player_position = player.global_position
	initial_zaita_position = zaita.global_position
	initial_naita_position = naita.global_position
	initial_parallax_position = distant_background.position
	parallax_reference_position = initial_player_position

	spawn_timer.timeout.connect(_spawn_enemy)
	start_popup.play_requested.connect(start_game)
	game_over_popup.play_again_requested.connect(reset_to_start)
	hud.weapon_requested.connect(_on_weapon_requested)
	hud.item_requested.connect(_on_item_requested)
	hud.shotgun_unlock_cost = shotgun_unlock_cost
	hud.machinegun_unlock_cost = machinegun_unlock_cost
	hud.shield_cost = shield_cost
	hud.turret_cost = turret_cost

	player.set_effects_root(effects)
	player.set_spend_callback(Callable(self, "_try_spend_skulls"))
	player.connect("shot_fired", Callable(self, "_on_player_shot_fired"))
	zaita.hit.connect(_on_child_hit)
	naita.hit.connect(_on_child_hit)
	zaita.death_sequence_finished.connect(_on_child_death_sequence_finished)
	naita.death_sequence_finished.connect(_on_child_death_sequence_finished)

	reset_state()
	show_start()


func _process(delta: float) -> void:
	_update_parallax()
	_update_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not is_game_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_click(get_global_mouse_position())
	elif event is InputEventScreenTouch and event.pressed:
		var world_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
		_handle_click(world_position)


func start_game() -> void:
	is_game_active = true
	placement_mode = &""
	hud.visible = true
	hud.show_placement_mode(placement_mode)
	player.set_active(true)
	zaita.set_active(true)
	naita.set_active(true)
	spawn_timer.wait_time = initial_spawn_interval
	spawn_timer.start()
	_update_hud()


func reset_to_start() -> void:
	reset_state()
	start_popup.hide_popup()
	game_over_popup.hide_popup()
	start_game()


func reset_state() -> void:
	is_game_active = false
	is_game_over_sequence = false
	death_camera_focus_active = false
	shot_camera_time_left = 0.0
	shot_camera_shake_time_left = 0.0
	black_skulls = initial_skulls
	current_weapon = &"pistol"
	unlocked_weapons = {
		&"pistol": true,
		&"shotgun": false,
		&"machinegun": false
	}
	placement_mode = &""
	spawn_wave_index = 0

	spawn_timer.stop()
	_clear_group("enemies")
	_clear_group("shields")
	_clear_group("turrets")
	_clear_children(effects)

	player.reset(initial_player_position, player_walk_zone, safe_zone_polygon)
	zaita.reset(initial_zaita_position, children_walk_zone, safe_zone_polygon)
	naita.reset(initial_naita_position, children_walk_zone, safe_zone_polygon)
	player.current_weapon = current_weapon
	player.unlocked_weapons = unlocked_weapons.duplicate()

	distant_background.position = initial_parallax_position
	hud.visible = false
	hud.show_placement_mode(placement_mode)
	hud.update_child_status("Zaíta", true)
	hud.update_child_status("Naíta", true)
	_update_hud()
	queue_redraw()


func show_start() -> void:
	game_over_popup.hide_popup()
	start_popup.show_popup()


func _handle_click(click_position: Vector2) -> void:
	if placement_mode != &"":
		_try_place_item(click_position)
		return

	if _is_enemy_zone_point(click_position):
		var zone_enemy := _enemy_in_clicked_zone(click_position)
		if zone_enemy != null:
			player.set_target(zone_enemy)
		else:
			player.shoot_at_position(click_position)
		return

	var enemy := _enemy_at_point(click_position)
	if enemy != null:
		player.set_target(enemy)
	else:
		player.set_target_position(click_position)


func _try_place_item(item_position: Vector2) -> void:
	if not _is_item_placement_point(item_position):
		hud.show_placement_mode(placement_mode)
		return

	var install_position := item_position
	var faces_right := _item_faces_right(item_position)

	if placement_mode == &"shield":
		if not _try_spend_skulls(shield_cost):
			return
		var shield := shield_scene.instantiate()
		items.add_child(shield)
		shield.global_position = install_position
		if shield.has_method("set_facing_right"):
			shield.set_facing_right(faces_right)
	elif placement_mode == &"turret":
		if not _try_spend_skulls(turret_cost):
			return
		var turret := turret_scene.instantiate()
		items.add_child(turret)
		turret.global_position = install_position
		if turret.has_method("set_facing_right"):
			turret.set_facing_right(faces_right)
		turret.configure(effects, Callable(self, "_try_spend_skulls"))

	placement_mode = &""
	hud.show_placement_mode(placement_mode)
	_update_hud()


func _spawn_enemy() -> void:
	if not is_game_active or enemy_scene == null:
		return

	var spawn_count := _current_spawn_count()
	for spawn_index in range(spawn_count):
		_spawn_one_enemy(spawn_index)

	spawn_wave_index += 1
	spawn_timer.wait_time = _current_spawn_interval()
	spawn_timer.start()


func _spawn_one_enemy(spawn_index: int) -> void:
	var spawned_in_blue_zone: bool = ((spawn_wave_index + spawn_index) % 2) == 1
	var spawn_zone: Rect2 = enemy_spawn_right_zone if spawned_in_blue_zone else enemy_spawn_left_zone
	var spawn_polygon: PackedVector2Array = enemy_blue_polygon if spawned_in_blue_zone else enemy_red_polygon
	var enemy = enemy_scene.instantiate()
	actors.add_child(enemy)
	var type_index: int = 1 if spawned_in_blue_zone else 0
	enemy.configure(spawn_zone, spawn_polygon, type_index, spawned_in_blue_zone)
	if enemy.has_method("set_aim_area"):
		enemy.set_aim_area(children_walk_zone, safe_zone_polygon)
	enemy.set_active(true)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.fired.connect(_on_enemy_fired)


func _current_spawn_count() -> int:
	if spawn_wave_index < first_spawn_stage_waves:
		return 1
	if spawn_wave_index < first_spawn_stage_waves + second_spawn_stage_waves:
		return 2
	return 3


func _current_spawn_interval() -> float:
	if spawn_wave_index < first_spawn_stage_waves:
		return initial_spawn_interval
	if spawn_wave_index < first_spawn_stage_waves + second_spawn_stage_waves:
		return second_spawn_interval
	return final_spawn_interval


func _on_enemy_defeated(reward: int) -> void:
	black_skulls += reward
	_update_hud()
	hud.show_skull_delta(reward)


func _on_enemy_fired(
	start_position: Vector2,
	end_position: Vector2,
	target: Node2D,
	damage: int,
	control_position: Vector2 = Vector2.INF,
	width: float = 2.2
) -> void:
	if not is_game_active:
		return

	var protector := _protector_on_path(start_position, end_position)
	if protector != null:
		_spawn_ray(start_position, protector.global_position, Color(1.0, 0.82, 0.08, 1.0), width, control_position)
		if protector.has_method("take_damage"):
			protector.take_damage(damage)
		return

	_spawn_ray(start_position, end_position, Color(1.0, 0.82, 0.08, 1.0), width, control_position)
	if target != null and target.is_in_group("children"):
		target.take_shot()
	# The brother can be targeted, but the prototype never applies damage to him.


func _on_player_shot_fired(start_position: Vector2, end_position: Vector2) -> void:
	if not is_game_active or death_camera_focus_active:
		return

	shot_camera_focus_position = start_position.lerp(end_position, shot_camera_focus_blend)
	shot_camera_time_left = shot_camera_duration
	shot_camera_shake_time_left = shot_camera_shake_duration


func _on_child_hit(child: Node2D) -> void:
	if not is_game_active or is_game_over_sequence:
		return

	is_game_active = false
	is_game_over_sequence = true
	_focus_camera_on_child(child)
	spawn_timer.stop()
	player.set_active(false)
	zaita.set_active(false)
	naita.set_active(false)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.set_active(false)
	for turret in get_tree().get_nodes_in_group("turrets"):
		if is_instance_valid(turret):
			turret.active = false

	hud.update_child_status(child.child_name, false)


func _on_child_death_sequence_finished(child: Node2D) -> void:
	if not is_game_over_sequence:
		return

	await _flash_game_over_red()
	game_over_popup.show_popup(child.child_name)


func _flash_game_over_red() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)

	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.95, 0.0, 0.0, 0.0)
	layer.add_child(flash)

	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.48, 0.09)
	tween.tween_property(flash, "color:a", 0.0, 0.12)
	tween.tween_property(flash, "color:a", 0.38, 0.08)
	tween.tween_property(flash, "color:a", 0.0, 0.16)
	await tween.finished
	layer.queue_free()


func _focus_camera_on_child(child: Node2D) -> void:
	death_camera_focus_active = true
	death_camera_focus_position = child.global_position + Vector2(0.0, death_camera_vertical_offset)


func _on_weapon_requested(weapon: StringName) -> void:
	if not is_game_active:
		return

	if weapon == &"pistol":
		current_weapon = weapon
	elif weapon == &"shotgun":
		if not unlocked_weapons[&"shotgun"]:
			if not _try_spend_skulls(shotgun_unlock_cost):
				return
			unlocked_weapons[&"shotgun"] = true
		current_weapon = weapon
	elif weapon == &"machinegun":
		if not unlocked_weapons[&"machinegun"]:
			if not _try_spend_skulls(machinegun_unlock_cost):
				return
			unlocked_weapons[&"machinegun"] = true
		current_weapon = weapon

	player.unlocked_weapons = unlocked_weapons.duplicate()
	player.select_weapon(current_weapon)
	placement_mode = &""
	hud.show_placement_mode(placement_mode)
	_update_hud()


func _on_item_requested(item: StringName) -> void:
	if not is_game_active:
		return

	if item == &"shield" and black_skulls < shield_cost:
		return
	if item == &"turret" and black_skulls < turret_cost:
		return

	placement_mode = item
	hud.show_placement_mode(placement_mode)


func _try_spend_skulls(amount: int) -> bool:
	if amount <= 0:
		return true
	if black_skulls < amount:
		return false
	black_skulls -= amount
	_update_hud()
	hud.show_skull_delta(-amount)
	return true


func _update_hud() -> void:
	if hud == null:
		return
	hud.update_display(black_skulls, current_weapon, unlocked_weapons)
	hud.update_child_status("Zaíta", zaita.alive)
	hud.update_child_status("Naíta", naita.alive)


func _enemy_at_point(point: Vector2) -> Node2D:
	var selected: Node2D
	var closest_distance := enemy_click_radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.alive:
			continue
		var distance: float = _enemy_selection_distance(enemy, point)
		if distance <= closest_distance:
			selected = enemy
			closest_distance = distance
	return selected


func _is_enemy_zone_point(point: Vector2) -> bool:
	return (
		ZoneUtilsUtil.contains_point(enemy_red_polygon, point)
		or ZoneUtilsUtil.contains_point(enemy_blue_polygon, point)
	)


func _enemy_in_clicked_zone(point: Vector2) -> Node2D:
	var zone_polygon: PackedVector2Array = enemy_blue_polygon if ZoneUtilsUtil.contains_point(enemy_blue_polygon, point) else enemy_red_polygon
	var selected: Node2D
	var closest_distance := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.alive:
			continue
		if not ZoneUtilsUtil.contains_point(zone_polygon, enemy.global_position):
			continue
		var distance: float = enemy.global_position.distance_to(point)
		if distance < closest_distance:
			selected = enemy
			closest_distance = distance
	return selected


func _enemy_selection_distance(enemy: Node2D, point: Vector2) -> float:
	var body_center := enemy.global_position + Vector2(0.0, -48.0)
	var foot_distance := enemy.global_position.distance_to(point)
	var body_distance := body_center.distance_to(point)
	return minf(foot_distance, body_distance)


func _protector_on_path(start_position: Vector2, end_position: Vector2) -> Node2D:
	var selected: Node2D
	var closest_distance := INF
	for protector in get_tree().get_nodes_in_group("protectors"):
		if not is_instance_valid(protector) or not protector.active:
			continue
		var segment_distance := _distance_point_to_segment(protector.global_position, start_position, end_position)
		if segment_distance <= protector.block_radius:
			var origin_distance := start_position.distance_to(protector.global_position)
			if origin_distance < closest_distance:
				selected = protector
				closest_distance = origin_distance
	return selected


func _is_safe_boundary_placement_point(point: Vector2) -> bool:
	var closest_edge_point := ZoneUtilsUtil.closest_point_on_polygon(point, safe_zone_polygon)
	return point.distance_to(closest_edge_point) <= safe_boundary_place_tolerance


func _safe_boundary_install_position(point: Vector2) -> Vector2:
	var edge_point := ZoneUtilsUtil.closest_point_on_polygon(point, safe_zone_polygon)
	var center := ZoneUtilsUtil.centroid(safe_zone_polygon)
	var inward_direction := center - edge_point
	if inward_direction.length() <= 0.01:
		return point
	return edge_point + inward_direction.normalized() * 24.0


func _is_item_placement_point(point: Vector2) -> bool:
	return (
		ZoneUtilsUtil.contains_point(item_place_polygon, point)
		or ZoneUtilsUtil.contains_point(item_mirrored_polygon, point)
	)


func _item_faces_right(point: Vector2) -> bool:
	if ZoneUtilsUtil.contains_point(item_mirrored_polygon, point):
		return false
	return true


func _distance_point_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_squared_value := ab.length_squared()
	if length_squared_value <= 0.001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_squared_value, 0.0, 1.0)
	var projection := a + ab * t
	return point.distance_to(projection)


func _spawn_ray(start_position: Vector2, end_position: Vector2, color: Color, width: float, control_position: Vector2 = Vector2.INF) -> void:
	if ray_scene == null:
		return
	var ray := ray_scene.instantiate()
	effects.add_child(ray)
	ray.setup(start_position, end_position, color, width, control_position)


func _update_parallax() -> void:
	var offset := player.global_position - parallax_reference_position
	distant_background.position = initial_parallax_position - offset * parallax_strength


func _on_viewport_resized() -> void:
	_fit_backgrounds()
	_configure_camera()
	initial_parallax_position = distant_background.position
	_update_parallax()


func _fit_backgrounds() -> void:
	if map_background.texture == null or distant_background.texture == null:
		return

	map_background.position = Vector2.ZERO
	map_background.scale = Vector2.ONE

	var map_size: Vector2 = map_background.texture.get_size()
	var distant_size: Vector2 = distant_background.texture.get_size()
	var distant_scale: float = maxf(
		map_size.x / distant_size.x,
		map_size.y / distant_size.y
	) * background_2_parallax_margin
	distant_background.scale = Vector2.ONE * distant_scale
	distant_background.position = (map_size - distant_size * distant_scale) * 0.5
	_configure_camera()


func _configure_camera() -> void:
	if camera == null or map_background.texture == null:
		return

	var map_size: Vector2 = map_background.texture.get_size()
	var viewport_size := Vector2(get_viewport_rect().size)
	var fitted_zoom := maxf(viewport_size.x / map_size.x, viewport_size.y / map_size.y) * camera_fit_margin
	base_camera_zoom = Vector2.ONE * fitted_zoom
	camera.zoom = base_camera_zoom
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map_size.x)
	camera.limit_bottom = int(map_size.y)
	camera.global_position = map_size * 0.5
	camera.offset = Vector2.ZERO
	camera.make_current()


func _update_camera(delta: float) -> void:
	if camera == null or map_background.texture == null:
		return
	var target_position := map_background.texture.get_size() * 0.5
	var target_zoom := base_camera_zoom
	var smoothing := camera_smoothing
	if death_camera_focus_active:
		target_position = death_camera_focus_position
		target_zoom = base_camera_zoom * death_camera_zoom_multiplier
		smoothing = death_camera_smoothing
	elif shot_camera_time_left > 0.0:
		shot_camera_time_left = maxf(0.0, shot_camera_time_left - delta)
		target_position = target_position.lerp(shot_camera_focus_position, shot_camera_focus_blend)
		target_zoom = base_camera_zoom * shot_camera_zoom_multiplier
		smoothing = shot_camera_smoothing

	var weight := clampf(delta * smoothing, 0.0, 1.0)
	camera.global_position = camera.global_position.lerp(target_position, weight)
	camera.zoom = camera.zoom.lerp(target_zoom, weight)
	_update_camera_shake(delta)


func _update_camera_shake(delta: float) -> void:
	if camera == null:
		return
	if death_camera_focus_active:
		camera.offset = camera.offset.lerp(Vector2.ZERO, clampf(delta * 18.0, 0.0, 1.0))
		return
	if shot_camera_shake_time_left > 0.0 and shot_camera_shake_duration > 0.0:
		shot_camera_shake_time_left = maxf(0.0, shot_camera_shake_time_left - delta)
		var intensity := shot_camera_shake_time_left / shot_camera_shake_duration
		camera.offset = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * shot_camera_shake_strength * intensity
	else:
		camera.offset = camera.offset.lerp(Vector2.ZERO, clampf(delta * 18.0, 0.0, 1.0))


func _clear_group(group_name: StringName) -> void:
	for node in get_tree().get_nodes_in_group(group_name):
		if is_instance_valid(node):
			node.queue_free()


func _clear_children(parent_node: Node) -> void:
	for child_node in parent_node.get_children():
		child_node.queue_free()


func _draw() -> void:
	if not debug_mode:
		return

	_draw_polygon(safe_zone_polygon, Color(0.25, 1.0, 0.35, 0.8))
	_draw_polygon(item_place_polygon, Color(0.95, 0.65, 1.0, 0.8))
	_draw_polygon(item_mirrored_polygon, Color(1.0, 0.55, 0.86, 0.8))
	_draw_polygon(enemy_red_polygon, Color(1.0, 0.25, 0.2, 0.8))
	_draw_polygon(enemy_blue_polygon, Color(0.25, 0.35, 1.0, 0.8))
	_draw_polygon(sewer_polygon, Color(1.0, 0.9, 0.18, 0.8))


func _draw_zone(zone: Rect2, color: Color) -> void:
	draw_rect(zone, color, false, 2.0)


func _draw_polygon(polygon: PackedVector2Array, color: Color) -> void:
	if polygon.size() < 2:
		return
	var points := PackedVector2Array(polygon)
	points.append(polygon[0])
	draw_polyline(points, color, 3.0)
