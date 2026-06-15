extends SceneTree


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

	main_scene.zaita.take_shot()

	var timeout_frames := 420
	while timeout_frames > 0 and not main_scene.game_over_popup.visible:
		timeout_frames -= 1
		await process_frame

	assert(main_scene.game_over_popup.visible)
	assert(not main_scene.is_game_active)
	print("ZAITA_CONFLITOS_DEATH_SEQUENCE_OK")
	quit()
