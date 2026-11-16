class_name CatState
extends RefCounted
## Cat needs, computed lazily from timestamps so they stay correct while the app is closed.

const SAVE_PATH := "user://cat_save.json"
const HUNGER_PER_HOUR := 12.5   # full -> empty in 8 hours
const HAPPY_PER_HOUR := 8.0     # full -> empty in ~12 hours
const FLOOR := 5.0              # neglect never goes below this (no death, no running away)
const LOW := 30.0

var cat_name := "나비"
var hunger := 80.0      # 100 = full, 0 = starving
var happiness := 80.0   # 100 = very happy
var last_update := 0    # unix seconds


func advance(now: int) -> void:
	if last_update == 0:
		last_update = now
		return
	if now <= last_update:
		return  # clock moved backwards: ignore instead of rewarding or punishing
	var hours := float(now - last_update) / 3600.0
	hunger = maxf(FLOOR, hunger - HUNGER_PER_HOUR * hours)
	happiness = maxf(FLOOR, happiness - HAPPY_PER_HOUR * hours)
	last_update = now


func feed(now: int) -> void:
	advance(now)
	hunger = minf(100.0, hunger + 40.0)


func play(now: int) -> void:
	advance(now)
	happiness = minf(100.0, happiness + 30.0)
	hunger = maxf(FLOOR, hunger - 3.0)


## Highest-priority need first: hungry > bored > content.
func mood() -> String:
	if hunger < LOW:
		return "hungry"
	if happiness < LOW:
		return "bored"
	return "content"


func to_dict() -> Dictionary:
	return {"name": cat_name, "hunger": hunger, "happiness": happiness, "last_update": last_update}


func from_dict(d: Dictionary) -> void:
	cat_name = str(d.get("name", cat_name))
	hunger = float(d.get("hunger", hunger))
	happiness = float(d.get("happiness", happiness))
	last_update = int(d.get("last_update", last_update))


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))


func load_or_init(now: int) -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			from_dict(parsed)
	advance(now)
