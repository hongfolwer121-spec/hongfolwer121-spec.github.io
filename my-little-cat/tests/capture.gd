extends SceneTree
## Saves screenshots of the room and each phone app (needs a display, e.g. xvfb-run).
## godot --path . --rendering-driver opengl3 --script res://tests/capture.gd -- <out_dir>

func _shot(dir: String, name: String) -> void:
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "user://shots"
	if FileAccess.file_exists(Household.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Household.SAVE_PATH))
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _shot(dir, "01_room")
	main._open_phone()
	await _shot(dir, "02_phone_home")
	main.phone._open_app("adopt")
	await _shot(dir, "03_adopt")
	main.phone._adopt(main.household.adoption_candidates(main.now())[0])
	main._on_pet()
	main._on_feed()
	main.phone._open_app("notes")
	await _shot(dir, "04_notes")
	main.phone._open_app("dex")
	await _shot(dir, "05_dex")
	main.phone._open_app("help")
	main.phone.screen.get_child(2).get_child(0).get_child(0).emit_signal("pressed")
	await _shot(dir, "06_help")
	main.phone.close()
	await _shot(dir, "07_room_two_cats")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Household.SAVE_PATH))
	quit()
