class_name CatData
extends RefCounted
## One cat's persistent data. Needs are computed lazily from timestamps.
## Intimacy changes go through Household so the daily cap and diary stay consistent.

const HUNGER_PER_HOUR := 12.5   # full -> empty in 8 hours
const HAPPY_PER_HOUR := 8.0
const FLOOR := 5.0              # neglect never goes below this: no death, no running away
const LOW := 30.0

var id := ""
var cat_name := ""
var coat := "cheese"
var personalities: Array = []       # 1-2 ids from Traits.PERSONALITIES (partly shown at adoption)
var habits: Array = []              # 2-3 ids from Traits.HABITS (hidden until discovered)
var discovered_habits: Array = []
var intimacy := 0.0                 # 0..100
var hunger := 80.0                  # 100 = full
var happiness := 80.0
var adopted_at := 0
var last_update := 0
var firsts: Array = []              # one-time events already logged ("first_pet", ...)
var intimacy_milestones: Array = [] # 10, 20, ... already logged


func advance(now: int) -> void:
	if last_update == 0:
		last_update = now
		return
	if now <= last_update:
		return  # clock moved backwards: ignore
	var hours := float(now - last_update) / 3600.0
	hunger = maxf(FLOOR, hunger - HUNGER_PER_HOUR * hours)
	happiness = maxf(FLOOR, happiness - HAPPY_PER_HOUR * hours)
	last_update = now


## Highest-priority need first.
func need() -> String:
	if hunger < LOW:
		return "hungry"
	if happiness < LOW:
		return "bored"
	return "content"


func param(key: String) -> float:
	return Traits.param(personalities, key)


func personality_labels() -> String:
	var names: Array = []
	for p in personalities:
		names.append(Traits.personality(p)["label"])
	return " · ".join(names)


func to_dict() -> Dictionary:
	return {
		"id": id, "name": cat_name, "coat": coat,
		"personalities": personalities, "habits": habits, "discovered_habits": discovered_habits,
		"intimacy": intimacy, "hunger": hunger, "happiness": happiness,
		"adopted_at": adopted_at, "last_update": last_update,
		"firsts": firsts, "intimacy_milestones": intimacy_milestones,
	}


static func from_dict(d: Dictionary) -> CatData:
	var c := CatData.new()
	c.id = str(d.get("id", ""))
	c.cat_name = str(d.get("name", ""))
	c.coat = str(d.get("coat", "cheese"))
	c.personalities = Array(d.get("personalities", []))
	c.habits = Array(d.get("habits", []))
	c.discovered_habits = Array(d.get("discovered_habits", []))
	c.intimacy = float(d.get("intimacy", 0.0))
	c.hunger = float(d.get("hunger", 80.0))
	c.happiness = float(d.get("happiness", 80.0))
	c.adopted_at = int(d.get("adopted_at", 0))
	c.last_update = int(d.get("last_update", 0))
	c.firsts = Array(d.get("firsts", []))
	c.intimacy_milestones = Array(d.get("intimacy_milestones", []))
	return c
