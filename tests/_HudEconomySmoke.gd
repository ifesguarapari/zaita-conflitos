extends SceneTree

const ZoneUtilsUtil = preload("res://scripts/ZoneUtils.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)

	var main_scene := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame

	main_scene.start_popup.hide_popup()
	main_scene.game_over_popup.hide_popup()
	main_scene.start_game()
	main_scene.spawn_timer.stop()
	if main_scene.items.z_index <= main_scene.actors.z_index:
		_fail("Installed props should render above the brother and the sisters.")
		return

	var enemy = main_scene.enemy_scene.instantiate()
	if not enemy.can_shoot:
		_fail("Enemy shooting should be active.")
		return
	if enemy.pistol_health != 1 or enemy.pistol_damage != 1 or enemy.pistol_reward != 2:
		_fail("Red pistol enemies should die with one shot, damage shields by one, and reward two skulls.")
		return
	if enemy.machinegun_health != 2 or enemy.machinegun_damage != 2 or enemy.machinegun_reward != 3:
		_fail("Blue machinegun enemies should die with two shots, damage shields by two, and reward three skulls.")
		return
	if not is_equal_approx(enemy.pistol_shots_per_second, 1.0 / 3.0) or not is_equal_approx(enemy.machinegun_shots_per_second, 1.0 / 5.0):
		_fail("Enemy shots should be paced at one pistol shot every three seconds and one machinegun shot every five seconds.")
		return
	if enemy.speed > 42.0 or enemy.start_run_distance > 46.0 or enemy.run_distance_after_shots > 38.0:
		_fail("Enemy running should be slower and cover fewer pixels per burst.")
		return
	if enemy.shots_before_zaita_hit != 42:
		_fail("Enemies should be able to threaten the sisters after a balanced number of shots.")
		return
	enemy.free()

	if main_scene._current_spawn_count() != 1 or not is_equal_approx(main_scene._current_spawn_interval(), 7.0):
		_fail("Enemy spawning should start with one enemy every seven seconds.")
		return
	main_scene.spawn_wave_index = main_scene.first_spawn_stage_waves
	if main_scene._current_spawn_count() != 2 or not is_equal_approx(main_scene._current_spawn_interval(), 6.0):
		_fail("Enemy spawning should progress to two enemies every six seconds.")
		return
	main_scene.spawn_wave_index = main_scene.first_spawn_stage_waves + main_scene.second_spawn_stage_waves
	if main_scene._current_spawn_count() != 3 or not is_equal_approx(main_scene._current_spawn_interval(), 5.0):
		_fail("Enemy spawning should progress to three enemies every five seconds.")
		return
	main_scene.spawn_wave_index = 0

	var animated_enemy = main_scene.enemy_scene.instantiate()
	main_scene.actors.add_child(animated_enemy)
	animated_enemy.configure(main_scene.enemy_spawn_left_zone, main_scene.enemy_red_polygon, 0, false)
	animated_enemy.set_active(true)
	animated_enemy.global_position = ZoneUtilsUtil.centroid(main_scene.enemy_red_polygon)
	var red_run_start: Vector2 = animated_enemy.global_position
	animated_enemy._begin_run(animated_enemy.start_run_distance)
	var red_run_delta: Vector2 = animated_enemy.target_position - red_run_start
	if red_run_delta.dot(animated_enemy._forward_direction()) <= 0.0 or red_run_delta.length() > animated_enemy.start_run_distance + 0.1:
		_fail("Red enemies should run forward in short, heavy bursts.")
		return
	animated_enemy._enter_starting()
	if animated_enemy.get_node_or_null("HealthBar") != null:
		_fail("Enemy should not have a health bar.")
		return
	if animated_enemy.current_state != &"starting":
		_fail("Enemy should spawn in the starting animation state.")
		return
	for _frame in range(40):
		animated_enemy._process(0.1)
	if animated_enemy.current_state != &"running" and animated_enemy.current_state != &"shooting":
		_fail("Enemy should run forward after the starting animation.")
		return
	animated_enemy.take_damage(1)
	if animated_enemy.current_state != &"dying":
		_fail("Enemy should enter the dying animation when defeated.")
		return
	animated_enemy.queue_free()
	await process_frame

	var mirrored_enemy = main_scene.enemy_scene.instantiate()
	main_scene.actors.add_child(mirrored_enemy)
	mirrored_enemy.configure(main_scene.enemy_spawn_right_zone, main_scene.enemy_blue_polygon, 1, true)
	mirrored_enemy.set_aim_area(main_scene.children_walk_zone, main_scene.safe_zone_polygon)
	if not mirrored_enemy.is_mirrored or not mirrored_enemy.body_sprite.flip_h:
		_fail("Blue/right-side enemies should be mirrored to face left.")
		return
	mirrored_enemy.global_position = ZoneUtilsUtil.centroid(main_scene.enemy_blue_polygon)
	var blue_run_start: Vector2 = mirrored_enemy.global_position
	mirrored_enemy._begin_run(mirrored_enemy.start_run_distance)
	var blue_run_delta: Vector2 = mirrored_enemy.target_position - blue_run_start
	if blue_run_delta.dot(mirrored_enemy._forward_direction()) <= 0.0 or blue_run_delta.length() > mirrored_enemy.start_run_distance + 0.1:
		_fail("Blue enemies should run forward in short, mirrored bursts.")
		return
	mirrored_enemy._enter_starting()
	var first_spawn_position: Vector2 = mirrored_enemy.global_position
	var has_varied_spawn := false
	var farthest_spawn_distance := 0.0
	for _attempt in range(8):
		mirrored_enemy.configure(main_scene.enemy_spawn_right_zone, main_scene.enemy_blue_polygon, 1, true)
		if not Geometry2D.is_point_in_polygon(mirrored_enemy.global_position, main_scene.enemy_blue_polygon):
			_fail("Enemy spawn position should stay inside the blue polygon.")
			return
		farthest_spawn_distance = maxf(farthest_spawn_distance, mirrored_enemy.global_position.distance_to(first_spawn_position))
		if mirrored_enemy.global_position.distance_to(first_spawn_position) > 1.0:
			has_varied_spawn = true
	if not has_varied_spawn:
		_fail("Enemy spawn position should vary inside the perimeter.")
		return
	if farthest_spawn_distance < 80.0:
		_fail("Enemy spawn position should vary across distant points inside the perimeter.")
		return
	var random_aim: Vector2 = mirrored_enemy._random_aim_position()
	if not Geometry2D.is_point_in_polygon(random_aim, main_scene.safe_zone_polygon):
		_fail("Enemy aim points should be random positions inside the green polygon.")
		return
	var fired_result := {"args": []}
	mirrored_enemy.fired.connect(func(
		start_position: Vector2,
		end_position: Vector2,
		target: Node2D,
		damage: int,
		control_position: Vector2,
		width: float
	) -> void:
		fired_result["args"] = [start_position, end_position, target, damage, control_position, width]
	)
	mirrored_enemy._fire_at_position(random_aim, null)
	var fired_args: Array = fired_result["args"]
	if fired_args.is_empty():
		_fail("Enemy should emit projectile data when firing.")
		return
	if (fired_args[0] as Vector2).distance_to(mirrored_enemy.global_position) <= 8.0:
		_fail("Enemy shots should start from a muzzle point instead of the body center.")
		return
	if fired_args[4] == Vector2.INF or float(fired_args[5]) <= 0.0:
		_fail("Enemy shots should carry a control point and ray width.")
		return
	fired_result["args"] = []
	mirrored_enemy._begin_shooting()
	for _frame in range(220):
		mirrored_enemy._process_shooting(0.01)
	if not (fired_result["args"] as Array).is_empty():
		_fail("Enemy shots should wait for the animation fire frame instead of using an independent timer.")
		return
	for _frame in range(90):
		mirrored_enemy._process_shooting(0.01)
		if not (fired_result["args"] as Array).is_empty():
			break
	if (fired_result["args"] as Array).is_empty():
		_fail("Enemy shots should fire when the shooting animation reaches the configured middle frame.")
		return
	if mirrored_enemy.last_fired_frame_index != mirrored_enemy._shooting_fire_frame():
		_fail("Enemy projectile should be emitted exactly on the configured shooting frame.")
		return
	mirrored_enemy.queue_free()
	await process_frame

	if main_scene.player.shotgun_shot_cost != 0 or main_scene.player.machinegun_shot_cost != 0:
		_fail("Shots should not cost skulls after weapons are purchased.")
		return
	main_scene.player.current_weapon = &"shotgun"
	main_scene.player.unlocked_weapons[&"shotgun"] = true
	main_scene.player.fire_cooldown = 0.8
	main_scene.player.shoot_at_position(main_scene.player.global_position + Vector2(240.0, 60.0))
	if main_scene.player._is_shooting_animation(main_scene.player.current_animation):
		_fail("Shotgun animation should wait instead of sticking in fire frames while cooldown is high.")
		return
	for _frame in range(6):
		main_scene.player._process(0.05)
	if main_scene.player._is_shooting_animation(main_scene.player.current_animation):
		_fail("Shotgun animation should not start too early during cooldown.")
		return
	main_scene.player.fire_cooldown = 0.0
	main_scene.player._process(0.02)
	if not main_scene.player._is_shooting_animation(main_scene.player.current_animation):
		_fail("Shotgun animation should begin once cooldown is ready.")
		return
	for _frame in range(60):
		main_scene.player._process(0.03)
	if main_scene.player._is_shooting_animation(main_scene.player.current_animation) and main_scene.player.shooting_phase == &"fire":
		_fail("Shotgun animation should not remain stuck in the middle fire loop.")
		return
	main_scene.player.current_weapon = &"shotgun"
	main_scene.player.unlocked_weapons[&"shotgun"] = true
	main_scene.player.fire_cooldown = 0.0
	for click_index in range(10):
		main_scene.player.shoot_at_position(main_scene.player.global_position + Vector2(220.0, 48.0 + float(click_index)))
		main_scene.player._process(0.04)
	for _frame in range(90):
		main_scene.player._process(0.03)
	if main_scene.player._is_shooting_animation(main_scene.player.current_animation) and main_scene.player.shooting_phase == &"fire":
		_fail("Shotgun animation should recover from repeated manual shots.")
		return
	main_scene.player.current_weapon = &"machinegun"
	main_scene.player.unlocked_weapons[&"machinegun"] = true
	main_scene.player.fire_cooldown = 0.0
	for click_index in range(18):
		main_scene.player.shoot_at_position(main_scene.player.global_position + Vector2(260.0, 70.0 + float(click_index)))
		main_scene.player._process(0.025)
	for _frame in range(90):
		main_scene.player._process(0.025)
	if main_scene.player._is_shooting_animation(main_scene.player.current_animation) and main_scene.player.shooting_phase == &"fire":
		_fail("Machinegun animation should recover from repeated manual shots.")
		return
	main_scene.player.current_weapon = &"pistol"
	main_scene.player._face_shoot_direction(Vector2.RIGHT)
	if not is_equal_approx(main_scene.player.shoot_sprite.rotation_degrees, 0.0):
		_fail("Right-facing shooting animation should keep its original angle.")
		return
	main_scene.player._face_shoot_direction(Vector2.LEFT)
	if not is_equal_approx(main_scene.player.shoot_sprite.rotation_degrees, 0.0):
		_fail("Left-facing shooting animation should keep its original angle.")
		return

	main_scene._on_enemy_defeated(2)
	if main_scene.black_skulls != 2:
		_fail("Enemy reward did not add two skulls.")
		return
	main_scene._on_player_shot_fired(main_scene.player.global_position, main_scene.player.global_position + Vector2(160.0, 40.0))
	if main_scene.shot_camera_time_left <= 0.0 or main_scene.shot_camera_shake_time_left <= 0.0:
		_fail("Brother shots should trigger camera zoom and shake feedback.")
		return

	main_scene.black_skulls = 10
	main_scene._update_hud()
	main_scene._on_weapon_requested(&"shotgun")
	if main_scene.black_skulls != 0 or main_scene.current_weapon != &"shotgun":
		_fail("Shotgun purchase should cost 10 skulls and select shotgun.")
		return

	main_scene.black_skulls = 29
	main_scene._update_hud()
	main_scene._on_weapon_requested(&"machinegun")
	if main_scene.current_weapon == &"machinegun" or main_scene.black_skulls != 29:
		_fail("Machinegun should stay disabled below 30 skulls.")
		return

	main_scene.black_skulls = 30
	main_scene._update_hud()
	main_scene._on_weapon_requested(&"machinegun")
	if main_scene.black_skulls != 0 or main_scene.current_weapon != &"machinegun":
		_fail("Machinegun purchase should cost 30 skulls and select machinegun.")
		return

	main_scene.black_skulls = 20
	main_scene._update_hud()
	main_scene._on_item_requested(&"shield")
	main_scene._try_place_item(_polygon_center(main_scene.item_place_polygon))
	await process_frame
	var shields := get_nodes_in_group("shields")
	if shields.is_empty() or main_scene.black_skulls != 0:
		_fail("Shield should install on the normal item zone and cost 20 skulls.")
		return

	var shield = shields.back()
	if shield.get_node_or_null("HealthBar") != null:
		_fail("Installed shield should not show a score or health bar.")
		return
	if not shield.is_in_group("protectors"):
		_fail("Installed shield should block shots as a protector.")
		return
	shield.take_damage(19)
	if not shield.active:
		_fail("Shield should survive before receiving 20 total damage.")
		return
	shield.take_damage(1)
	if shield.active:
		_fail("Shield should explode after 20 total damage.")
		return

	main_scene.black_skulls = 40
	main_scene._update_hud()
	main_scene._on_item_requested(&"turret")
	main_scene._try_place_item(_polygon_center(main_scene.item_mirrored_polygon))
	await process_frame
	var turrets := get_nodes_in_group("turrets")
	if turrets.is_empty() or main_scene.black_skulls != 0:
		_fail("Rotary gun should install on the mirrored item zone and cost 40 skulls.")
		return

	var turret = turrets.back()
	if turret.get_node_or_null("TimeBar") != null:
		_fail("Installed rotary gun should not show a score or timer bar.")
		return
	if turret.get_node_or_null("MuzzleFlash") == null:
		_fail("Installed rotary gun should have a muzzle flash for its shots.")
		return
	if not turret.is_in_group("protectors"):
		_fail("Installed rotary gun should block shots as a protector.")
		return
	if turret.ammo_limit != 40 or not is_equal_approx(turret.duration_seconds, 5.0) or turret.cost_per_shot != 0:
		_fail("Rotary gun should fire 40 shots in 5 seconds without per-shot skull cost.")
		return
	if turret.facing_sign != -1.0:
		_fail("Rotary gun should be mirrored inside the pink item zone.")
		return

	main_scene.queue_free()
	await process_frame
	print("ZAITA_CONFLITOS_HUD_ECONOMY_SMOKE_OK")
	quit()


func _polygon_center(polygon: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	for point in polygon:
		center += point
	center /= float(polygon.size())
	return center


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
