extends SceneTree
## Runs the real main scene headlessly and presses every button path.
## godot --headless --path . --script res://tests/smoke_test.gd

func _initialize() -> void:
	if FileAccess.file_exists(Household.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Household.SAVE_PATH))
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._on_adopt_test()
	main._on_adopt_test()
	main._on_adopt_test()  # 4th: must be refused
	for i in 3:
		main._select(main.household.cats[0].id)
		main._on_pet()
	main._on_feed()
	main._on_play()
	main._on_skip_hour()
	main._select(main.household.cats[1].id)
	main._on_pet()
	for i in 600:
		await process_frame
	var ok: bool = main.household.cats.size() == 3 and main.actors.size() == 3 and not main.household.diary.is_empty()
	print("cats=%d actors=%d diary=%d behaviors=%s" % [main.household.cats.size(), main.actors.size(), main.household.diary.size(), main.household.discovered_behaviors])
	print("SMOKE ", "PASS" if ok else "FAIL")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Household.SAVE_PATH))
	quit(0 if ok else 1)
