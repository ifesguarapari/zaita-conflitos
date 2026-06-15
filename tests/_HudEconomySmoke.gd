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
	if not is_equal_approx(enemy.pistol_idle_wait_seconds, 1.0) or not is_equal_approx(enemy.machinegun_idle_wait_seconds, 2.0):
		_fail("Enemy idle wait should be one second for pistol enemies and two seconds for machinegun enemies.")
		return
	if enemy.speed > 42.0 or enemy.start_run_distance > 46.0 or enemy.run_distance_after_shots > 38.0:
		_fail("Enemy running should be slower and cover fewer pixels per burst.")
		return
	if enemy.running_animation_speed < 1.0 or not is_equal_approx(enemy.shooting_animation_duration, 1.0):
		_fail("Enemy running animation should be readable, and shooting animation should last one second.")
		return
	if enemy.sprite_scale < 0.19 or enemy.pistol_shooting_sprite_scale < 0.19 or enemy.machinegun_shooting_sprite_scale < 0.185:
		_fail("Enemy scale should stay close to the brother size across movement and shooting.")
		return
	if absf(enemy.pistol_muzzle_right_offset.x) < 40.0 or absf(enemy.machinegun_muzzle_right_offset.x) < 40.0:
		_fail("Enemy muzzle should be pushed forward to the weapon barrel.")
		return
	if not FileAccess.file_exists(enemy.idle_json) or enemy.idle_texture == null:
		_fail("Enemy should have an idle animation asset configured.")
		return
	var idle_import_text := FileAccess.get_file_as_string("res://assets/sprites/enemy-idle-back-right.png.import")
	if not idle_import_text.contains("mipmaps/generate=true"):
		_fail("Enemy idle sprite should import with mipmaps enabled.")
		return
	if enemy.shots_before_zaita_hit != 5:
		_fail("Enemies should be able to threaten the sisters after a balanced number of shots.")
		return
	enemy.free()

	if main_scene._current_spawn_count() != 1 or not is_equal_approx(main_scene._current_spawn_interval(), 5.0):
		_fail("Enemy spawning should start with one enemy every five seconds.")
		return
	main_scene.spawn_wave_index = main_scene.first_spawn_stage_waves
	if main_scene._current_spawn_count() != 2 or not is_equal_approx(main_scene._current_spawn_interval(), 4.0):
		_fail("Enemy spawning should progress to two enemies every four seconds.")
		return
	main_scene.spawn_wave_index = main_scene.first_spawn_stage_waves + main_scene.second_spawn_stage_waves
	if main_scene._current_spawn_count() != 3 or not is_equal_approx(main_scene._current_spawn_interval(), 3.0):
		_fail("Enemy spawning should progress to three enemies every three seconds.")
		return
	main_scene.spawn_wave_index = main_scene.first_spawn_stage_waves + main_scene.second_spawn_stage_waves + main_scene.third_spawn_stage_waves
	if main_scene._current_spawn_count() != 4 or not is_equal_approx(main_scene._current_spawn_interval(), 2.2):
		_fail("Enemy spawning should progress to four enemies every 2.2 seconds.")
		return
	main_scene.spawn_wave_index = 0

	var animated_enemy = main_scene.enemy_scene.instantiate()
	main_scene.actors.add_child(animated_enemy)
	animated_enemy.configure(main_scene.enemy_spawn_left_zone, main_scene.enemy_red_polygon, 0, false)
	animated_enemy.set_active(true)
	if not animated_enemy.animation_frames.has(&"idle"):
		_fail("Enemy idle animation should be loaded for the waiting state.")
		return
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
	var red_fired_result := {"target": null}
	animated_enemy.fired.connect(func(
		_start_position: Vector2,
		_end_position: Vector2,
		target: Node2D,
		_damage: int,
		_control_position: Vector2,
		_width: float,
		_start_ratio: float
	) -> void:
		red_fired_result["target"] = target
	)
	animated_enemy.total_shots = animated_enemy.shots_before_zaita_hit - 1
	animated_enemy._register_shot()
	if red_fired_result["target"] != main_scene.zaita:
		_fail("Red-zone enemies should target Zaita after the fifth shot.")
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
	var fired_result := {"args": [], "count": 0}
	mirrored_enemy.fired.connect(func(
		start_position: Vector2,
		end_position: Vector2,
		target: Node2D,
		damage: int,
		control_position: Vector2,
		width: float,
		start_ratio: float
	) -> void:
		fired_result["args"] = [start_position, end_position, target, damage, control_position, width, start_ratio]
		fired_result["count"] = int(fired_result["count"]) + 1
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
	if float(fired_args[6]) < 0.72:
		_fail("Enemy projectile should show only the final impact segment.")
		return
	var impact_ray = main_scene.ray_scene.instantiate()
	main_scene.effects.add_child(impact_ray)
	impact_ray.setup(
		fired_args[0] as Vector2,
		fired_args[1] as Vector2,
		Color(1.0, 0.82, 0.08, 1.0),
		float(fired_args[5]),
		fired_args[4] as Vector2,
		float(fired_args[6])
	)
	await process_frame
	if not impact_ray.impact_flash_enabled:
		_fail("Enemy final-segment projectile should enable the impact flash.")
		return
	if impact_ray.active_trail_length <= impact_ray.trail_length or impact_ray.active_scale >= 0.78:
		_fail("Enemy final-segment projectile should be longer and thinner.")
		return
	impact_ray.queue_free()
	fired_result["args"] = []
	fired_result["count"] = 0
	mirrored_enemy.total_shots = mirrored_enemy.shots_before_zaita_hit - 1
	mirrored_enemy._begin_shooting()
	for _frame in range(42):
		mirrored_enemy._process_shooting(0.01)
	if not (fired_result["args"] as Array).is_empty():
		_fail("Enemy shots should wait for the animation fire frame instead of using an independent timer.")
		return
	for _frame in range(30):
		mirrored_enemy._process_shooting(0.01)
		if not (fired_result["args"] as Array).is_empty():
			break
	if (fired_result["args"] as Array).is_empty():
		_fail("Enemy shots should fire when the shooting animation reaches the configured middle frame.")
		return
	if mirrored_enemy.last_fired_frame_index != mirrored_enemy._shooting_fire_frame():
		_fail("Enemy projectile should be emitted exactly on the configured shooting frame.")
		return
	if (fired_result["args"] as Array)[2] != main_scene.naita:
		_fail("Blue-zone enemies should target Naita after the fifth shot.")
		return
	for _frame in range(60):
		mirrored_enemy._process_shooting(0.01)
	if mirrored_enemy.current_state != &"idle" or mirrored_enemy.current_animation != &"idle":
		_fail("Enemy should switch to idle while waiting between shots.")
		return
	fired_result["args"] = []
	var first_shot_count := int(fired_result["count"])
	for _frame in range(150):
		mirrored_enemy._process_shooting(0.01)
	if int(fired_result["count"]) != first_shot_count:
		_fail("Machinegun enemy should wait in idle before the next shooting animation fires.")
		return
	for _frame in range(100):
		mirrored_enemy._process_shooting(0.01)
		if int(fired_result["count"]) > first_shot_count:
			break
	if int(fired_result["count"]) <= first_shot_count:
		_fail("Machinegun enemy should fire again after the shorter idle wait.")
		return
	mirrored_enemy.queue_free()
	await process_frame

	if main_scene.player.shotgun_shot_cost != 0 or main_scene.player.machinegun_shot_cost != 0:
		_fail("Shots should not cost skulls after weapons are purchased.")
		return
	main_scene.player.set_weapon_charges(
		{&"shotgun": 99, &"machinegun": 99},
		{&"shotgun": main_scene.shotgun_charge_capacity, &"machinegun": main_scene.machinegun_charge_capacity}
	)
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
	main_scene.player.weapon_charges[&"shotgun"] = 99
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
	main_scene.player.weapon_charges[&"machinegun"] = 99
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
	if main_scene.black_skulls != 0 or main_scene.current_weapon != &"shotgun" or main_scene.weapon_charges[&"shotgun"] != main_scene.shotgun_charge_capacity:
		_fail("Shotgun purchase should cost 10 skulls, fill the shot bar, and select shotgun.")
		return
	if not main_scene.hud.weapon_charge_bar.visible:
		_fail("Shotgun selection should show the remaining-shot bar.")
		return
	var full_shotgun_width: float = main_scene.hud.weapon_charge_fill.size.x
	main_scene._on_player_weapon_charge_spent(&"shotgun", 1, main_scene.shotgun_charge_capacity - 1, main_scene.shotgun_charge_capacity)
	if main_scene.black_skulls != 0 or main_scene.weapon_charges[&"shotgun"] != main_scene.shotgun_charge_capacity - 1:
		_fail("Shotgun shots should consume the shot bar without spending skulls.")
		return
	if main_scene.hud.weapon_charge_fill.size.x >= full_shotgun_width:
		_fail("Shotgun shot bar should shrink after a shot.")
		return
	main_scene._on_player_weapon_charge_spent(&"shotgun", 1, 0, main_scene.shotgun_charge_capacity)
	if main_scene.current_weapon != &"pistol" or main_scene.unlocked_weapons[&"shotgun"] or main_scene.hud.weapon_charge_bar.visible:
		_fail("Shotgun should return to a purchasable disabled state when shots run out.")
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
	if main_scene.black_skulls != 0 or main_scene.current_weapon != &"machinegun" or main_scene.weapon_charges[&"machinegun"] != main_scene.machinegun_charge_capacity:
		_fail("Machinegun purchase should cost 30 skulls, fill the shot bar, and select machinegun.")
		return
	if not main_scene.hud.weapon_charge_bar.visible:
		_fail("Machinegun selection should show the remaining-shot bar.")
		return
	main_scene._on_player_weapon_charge_spent(&"machinegun", 1, 0, main_scene.machinegun_charge_capacity)
	if main_scene.current_weapon != &"pistol" or main_scene.unlocked_weapons[&"machinegun"] or main_scene.hud.weapon_charge_bar.visible:
		_fail("Machinegun should return to a purchasable disabled state when shots run out.")
		return

	var shotgun_enemy_a = main_scene.enemy_scene.instantiate()
	var shotgun_enemy_b = main_scene.enemy_scene.instantiate()
	var shotgun_enemy_other_side = main_scene.enemy_scene.instantiate()
	main_scene.actors.add_child(shotgun_enemy_a)
	main_scene.actors.add_child(shotgun_enemy_b)
	main_scene.actors.add_child(shotgun_enemy_other_side)
	shotgun_enemy_a.configure(main_scene.enemy_spawn_left_zone, main_scene.enemy_red_polygon, 0, false)
	shotgun_enemy_b.configure(main_scene.enemy_spawn_left_zone, main_scene.enemy_red_polygon, 0, false)
	shotgun_enemy_other_side.configure(main_scene.enemy_spawn_right_zone, main_scene.enemy_blue_polygon, 1, true)
	var red_center := ZoneUtilsUtil.centroid(main_scene.enemy_red_polygon)
	shotgun_enemy_a.global_position = red_center
	shotgun_enemy_b.global_position = red_center + Vector2(42.0, 12.0)
	shotgun_enemy_other_side.global_position = ZoneUtilsUtil.centroid(main_scene.enemy_blue_polygon)
	main_scene.current_weapon = &"shotgun"
	main_scene.unlocked_weapons[&"shotgun"] = true
	main_scene.weapon_charges[&"shotgun"] = 4
	main_scene.player.current_weapon = &"shotgun"
	main_scene.player.unlocked_weapons = main_scene.unlocked_weapons.duplicate()
	main_scene.player.set_weapon_charges(main_scene.weapon_charges, main_scene._weapon_charge_capacities())
	main_scene.player.current_target = shotgun_enemy_a
	main_scene.player.fire_cooldown = 0.0
	main_scene.player._fire_at_target()
	if main_scene.weapon_charges[&"shotgun"] != 2:
		_fail("Shotgun should spend two charges when it hits two enemies in the same perimeter.")
		return
	if shotgun_enemy_other_side.get("alive") == false:
		_fail("Shotgun should not hit enemies from the opposite perimeter.")
		return
	shotgun_enemy_a.queue_free()
	shotgun_enemy_b.queue_free()
	shotgun_enemy_other_side.queue_free()
	await process_frame

	var machinegun_enemy_a = main_scene.enemy_scene.instantiate()
	var machinegun_enemy_b = main_scene.enemy_scene.instantiate()
	var machinegun_enemy_c = main_scene.enemy_scene.instantiate()
	var machinegun_enemy_d = main_scene.enemy_scene.instantiate()
	main_scene.actors.add_child(machinegun_enemy_a)
	main_scene.actors.add_child(machinegun_enemy_b)
	main_scene.actors.add_child(machinegun_enemy_c)
	main_scene.actors.add_child(machinegun_enemy_d)
	for extra_enemy in [machinegun_enemy_a, machinegun_enemy_b, machinegun_enemy_c, machinegun_enemy_d]:
		extra_enemy.configure(main_scene.enemy_spawn_left_zone, main_scene.enemy_red_polygon, 0, false)
	machinegun_enemy_a.global_position = red_center
	machinegun_enemy_b.global_position = red_center + Vector2(34.0, 8.0)
	machinegun_enemy_c.global_position = red_center + Vector2(68.0, 16.0)
	machinegun_enemy_d.global_position = red_center + Vector2(102.0, 24.0)
	main_scene.current_weapon = &"machinegun"
	main_scene.unlocked_weapons[&"machinegun"] = true
	main_scene.weapon_charges[&"machinegun"] = 5
	main_scene.player.current_weapon = &"machinegun"
	main_scene.player.unlocked_weapons = main_scene.unlocked_weapons.duplicate()
	main_scene.player.set_weapon_charges(main_scene.weapon_charges, main_scene._weapon_charge_capacities())
	main_scene.player.current_target = machinegun_enemy_a
	main_scene.player.fire_cooldown = 0.0
	main_scene.player._fire_at_target()
	if main_scene.weapon_charges[&"machinegun"] != 2:
		_fail("Machinegun should spend three charges when it hits three enemies in the same perimeter.")
		return
	if machinegun_enemy_d.get("alive") == false:
		_fail("Machinegun should hit no more than three enemies per shot.")
		return
	machinegun_enemy_a.queue_free()
	machinegun_enemy_b.queue_free()
	machinegun_enemy_c.queue_free()
	machinegun_enemy_d.queue_free()
	await process_frame

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
