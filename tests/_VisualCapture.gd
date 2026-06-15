extends SceneTree

const OUTPUT_PATH := "/tmp/zaita-conflitos-visual.png"
const OUTPUT_PATH_LATER := "/tmp/zaita-conflitos-visual-later.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)

	var main_scene := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame

	main_scene.debug_mode = false
	main_scene.start_popup.hide_popup()
	main_scene.game_over_popup.hide_popup()
	main_scene.start_game()
	main_scene.spawn_timer.stop()

	for _index in range(20):
		await process_frame

	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	assert(error == OK)

	for _index in range(90):
		await process_frame

	var later_image := root.get_viewport().get_texture().get_image()
	error = later_image.save_png(OUTPUT_PATH_LATER)
	assert(error == OK)
	print("ZAITA_CONFLITOS_VISUAL_CAPTURE_OK %s %s" % [OUTPUT_PATH, OUTPUT_PATH_LATER])
	quit()
