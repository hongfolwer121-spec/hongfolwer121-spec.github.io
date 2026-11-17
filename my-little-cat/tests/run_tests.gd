extends SceneTree
## Headless logic tests: godot --headless --path . --script res://tests/run_tests.gd

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)


func _init() -> void:
	var t0 := 1_800_000_000

	print("decay")
	var c := CatData.new()
	c.last_update = t0
	c.hunger = 80.0
	c.advance(t0 + 3600 * 4)
	check(is_equal_approx(c.hunger, 30.0), "hunger drops 12.5/h")
	c.advance(t0 + 3600 * 100)
	check(c.hunger == CatData.FLOOR, "hunger never below floor")
	var before := c.hunger
	c.advance(t0)
	check(c.hunger == before, "clock moving backwards is ignored")

	print("adoption")
	var h := Household.new()
	var a := h.adopt("나비", "cheese", ["affectionate"], ["jealous", "window_spot"], t0)
	var b := h.adopt("까망", "black", ["aloof"], ["loner", "curious"], t0)
	h.adopt("구름", "gray", ["sleepy"], ["night_zoomies", "curious"], t0)
	check(h.cats.size() == 3, "three cats adopted")
	check(h.adopt("넷째", "cream", ["playful"], [], t0) == null, "fourth cat rejected (max 3)")

	print("intimacy and signals")
	var gained := h.pet(a, t0 + 10, false, false)
	check(gained > 0.0, "petting a calm cat raises intimacy")
	var lost := h.pet(b, t0 + 20, true, false)
	check(lost < 0.0, "petting an annoyed cat lowers intimacy")
	var total := 0.0
	for i in 50:
		total += h.play(a, t0 + 100 + i)
	check(total <= Household.DAILY_INTIMACY_CAP + 0.001, "daily intimacy cap holds (%.1f)" % total)
	var next_day := h.play(a, t0 + 86400 + 100)
	check(next_day > 0.0, "cap resets the next day")
	check("first_pet" in a.firsts, "first pet recorded")

	print("jealousy")
	h.note_attention(b)
	h.note_attention(b)
	h.note_attention(b)
	var j := h.jealous_cats()
	check(j.size() == 1 and j[0] == a, "jealous cat reacts when another cat gets repeated attention")

	print("discovery")
	check(h.discover_habit(a, "window_spot", t0), "habit discovered once")
	check(not h.discover_habit(a, "window_spot", t0), "habit not discovered twice")
	check(not h.discover_habit(a, "night_zoomies", t0), "cannot discover a habit the cat lacks")
	check(h.record_behavior("slow_blink") and not h.record_behavior("slow_blink"), "behavior dex records once")

	print("save/load")
	var path := "user://test_household.json"
	h.save(path)
	var h2 := Household.load_from(path)
	check(h2.cats.size() == 3, "cats survive save/load")
	check(h2.cats[0].cat_name == "나비" and is_equal_approx(h2.cats[0].intimacy, a.intimacy), "cat fields survive")
	check(h2.diary.size() == h.diary.size(), "diary survives")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	print("random profile")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var p := Household.random_profile(rng)
	check(p["personalities"].size() >= 1 and p["habits"].size() >= 2, "random profile is complete")

	print("economy")
	var e := Household.new()
	var cat := e.adopt("나비", "cheese", ["affectionate"], [], t0)
	check(e.claim_attendance(t0) == Household.ATTENDANCE_COINS and e.claim_attendance(t0 + 60) == 0, "attendance once per day")
	var start_food := int(e.inventory["dry_food"])
	e.feed(cat, t0 + 10)
	check(int(e.inventory["dry_food"]) == start_food - 1, "feeding uses one serving")
	e.inventory["dry_food"] = 0
	check(e.feed(cat, t0 + 20) == 0.0 and e.best_food() == "", "no food: feeding does nothing")
	e.coins = 1000
	var coins_before := e.coins
	check(e.order("cat_tower", t0) == "", "order furniture")
	check(e.coins == coins_before - 400, "price paid")
	check(e.order("cat_tower", t0) != "", "cannot order the same furniture twice")
	e.coins = 0
	check(e.order("dry_food", t0) == "코인이 부족해요", "not enough coins")
	check(e.receive_deliveries(t0 + 60).is_empty(), "not delivered early")
	var got := e.receive_deliveries(t0 + 3600)
	check(got == ["cat_tower"] and "cat_tower" in e.owned and e.boxes == 1, "furniture delivered with a box")
	var farmed := 0
	for i in 100:
		farmed += e.earn_care_coins(5, t0 + 86400 * 2 + i)  # a fresh day
	check(farmed == Household.DAILY_CARE_COIN_CAP, "care coins capped per day")
	var path2 := "user://test_economy.json"
	e.save(path2)
	var e2 := Household.load_from(path2)
	check(e2.coins == e.coins and e2.owned == e.owned and e2.boxes == 1, "economy survives save/load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path2))

	print("\n%s (%d failures)" % ["PASS" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)
