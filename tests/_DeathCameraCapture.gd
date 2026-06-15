extends SceneTree

const OUTPUT_PATH := "/tmp/zaita-conflitos-death-camera.png"


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

	for _index in range(150):
		await process_frame

	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	assert(error == OK)
	print("ZAITA_CONFLITOS_DEATH_CAMERA_CAPTURE_OK %s" % OUTPUT_PATH)
	quit()
