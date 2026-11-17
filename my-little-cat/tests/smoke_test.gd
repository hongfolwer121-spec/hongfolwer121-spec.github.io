extends SceneTree
## Runs the real main scene headlessly and presses every button path.
## godot --headless --path . --script res://tests/smoke_test.gd

func _initialize() -> void:
	if FileAccess.file_exists(Household.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Household.SAVE_PATH))
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._open_phone()
	var cands: Array = main.household.adoption_candidates(main.now())
	main.phone._adopt(cands[0])
	main.phone._adopt(cands[0])  # same candidate twice: must be refused
	main.phone._adopt(main.household.adoption_candidates(main.now())[1])
	main.phone._adopt(main.household.adoption_candidates(main.now())[2])  # 4th cat: must be refused
	for app in ["market", "adopt", "camera", "notes", "dex", "help"]:
		main.phone._open_app(app)
		await process_frame
	main.household.coins = 2000
	for item in ["cat_tower", "cushion", "scratcher", "treat", "wet_food"]:
		main.phone._buy(item)
	for tab in ["orders", "storage", "shop"]:
		main.phone._set_market_tab(tab)
	main.time_offset += 7200
	main._check_deliveries()
	main._on_treat()
	main.phone._set_dex_tab("habit")
	main.phone._set_dex_tab("title")
	main.phone._set_notes_filter(main.household.cats[0].id)
	main.phone.close()
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
	var ok: bool = main.household.cats.size() == 3 and main.actors.size() == 3 and not main.household.diary.is_empty() and main.household.owned.size() == 3 and main.household.boxes == 2
	print("cats=%d actors=%d diary=%d behaviors=%s" % [main.household.cats.size(), main.actors.size(), main.household.diary.size(), main.household.discovered_behaviors])
	print("SMOKE ", "PASS" if ok else "FAIL")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Household.SAVE_PATH))
	quit(0 if ok else 1)
