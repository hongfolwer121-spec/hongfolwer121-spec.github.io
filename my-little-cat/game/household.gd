class_name Household
extends RefCounted
## All cats plus shared records (diary, discovered behaviors). Single source of truth for saves.

const SAVE_PATH := "user://household.json"
const SAVE_VERSION := 1
const MAX_CATS := 3
const DAILY_INTIMACY_CAP := 15.0   # positive intimacy per cat per day: steady care beats grinding
const DIARY_LIMIT := 500
const JEALOUSY_STREAK := 3
const START_COINS := 300
const ATTENDANCE_COINS := 50
const DAILY_CARE_COIN_CAP := 150     # coins from care actions per day
const MAX_BOXES := 2

var cats: Array[CatData] = []
var diary: Array = []                 # {t, cat_id, text}
var discovered_behaviors: Array = []  # behavior ids seen at least once (behavior dex)
var daily_gain := {}                  # {"<day>": {"<cat_id>": gained}}
var diary_seen := 0                  # diary entries already viewed in the phone (unread badge)
var adopted_candidates: Array = []   # adoption-center candidate ids already taken
var coins := START_COINS
var inventory := {"dry_food": 10}   # consumable servings
var owned: Array = []               # toys and furniture already delivered
var orders: Array = []              # {id, item, arrives_at}
var boxes := 0                      # empty delivery boxes in the room
var daily_coins := {}               # {"<day>": earned_from_care}
var last_attendance := ""
var attention_cat := ""               # id of the cat that got the latest attention
var attention_streak := 0


# ---------- helpers ----------

static func day_key(now: int) -> String:
	var bias_sec := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return str(int(floor(float(now + bias_sec) / 86400.0)))


func find(id: String) -> CatData:
	for c in cats:
		if c.id == id:
			return c
	return null


func log_event(cat: CatData, text: String, now: int) -> void:
	diary.append({"t": now, "cat_id": cat.id if cat else "", "text": text})
	if diary.size() > DIARY_LIMIT:
		diary_seen = maxi(0, diary_seen - (diary.size() - DIARY_LIMIT))
		diary = diary.slice(diary.size() - DIARY_LIMIT)


func _first(cat: CatData, key: String, text: String, now: int) -> void:
	if key in cat.firsts:
		return
	cat.firsts.append(key)
	log_event(cat, text, now)


func advance_all(now: int) -> void:
	for c in cats:
		c.advance(now)


# ---------- adoption ----------

func adopt(cat_name: String, coat: String, personalities: Array, habits: Array, now: int) -> CatData:
	if cats.size() >= MAX_CATS:
		return null
	var c := CatData.new()
	c.id = "%d-%d" % [now, randi() % 1000000]
	c.cat_name = cat_name
	c.coat = coat
	c.personalities = personalities
	c.habits = habits
	c.adopted_at = now
	c.last_update = now
	c.intimacy = 5.0
	cats.append(c)
	log_event(c, "%s(이)가 우리 집에 왔어요." % cat_name, now)
	return c


static func random_profile(rng: RandomNumberGenerator) -> Dictionary:
	var p_ids := Traits.PERSONALITIES.keys()
	var h_ids := Traits.HABITS.keys()
	var personalities: Array = [p_ids[rng.randi() % p_ids.size()]]
	if rng.randf() < 0.4:
		var second = p_ids[rng.randi() % p_ids.size()]
		if second != personalities[0]:
			personalities.append(second)
	var habits: Array = []
	var habit_count := 2 + (rng.randi() % 2)
	while habits.size() < habit_count:
		var h = h_ids[rng.randi() % h_ids.size()]
		if not h in habits:
			habits.append(h)
	var coats := Traits.COATS.keys()
	return {"coat": coats[rng.randi() % coats.size()], "personalities": personalities, "habits": habits}


## Adoption center: 3 cats per day, identical all day long.
func adoption_candidates(now: int) -> Array:
	var dk := day_key(now)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("adopt-" + dk)
	var used: Array = []   # only among today's candidates, so the list never shifts after an adoption
	var out: Array = []
	for i in 3:
		var p := random_profile(rng)
		var cat_name := ""
		for _try in 20:
			var n: String = Catalog.NAME_POOL[rng.randi() % Catalog.NAME_POOL.size()]
			if not n in used:
				cat_name = n
				break
		used.append(cat_name)
		p["name"] = cat_name
		p["candidate_id"] = "%s-%d" % [dk, i]
		p["taken"] = p["candidate_id"] in adopted_candidates
		out.append(p)
	return out


func adopt_candidate(candidate: Dictionary, now: int) -> CatData:
	if candidate.get("taken", false):
		return null
	var cat_name: String = candidate["name"]
	for other in cats:
		if other.cat_name == cat_name:
			cat_name += " 2세"
	var c := adopt(cat_name, candidate["coat"], candidate["personalities"], candidate["habits"], now)
	if c:
		adopted_candidates.append(candidate["candidate_id"])
	return c


# ---------- intimacy ----------

## Applies an intimacy change. Positive gains respect the per-cat daily cap; losses always apply.
## Returns the change actually applied.
func change_intimacy(cat: CatData, amount: float, now: int) -> float:
	var applied := amount
	if amount > 0.0:
		applied *= cat.param("intimacy_mult")
		var dk := day_key(now)
		var today: Dictionary = daily_gain.get(dk, {})
		var used := float(today.get(cat.id, 0.0))
		applied = clampf(applied, 0.0, maxf(0.0, DAILY_INTIMACY_CAP - used))
		today[cat.id] = used + applied
		daily_gain = {dk: today}  # only today's bucket is needed
	var before := cat.intimacy
	cat.intimacy = clampf(cat.intimacy + applied, 0.0, 100.0)
	for m in range(10, 101, 10):
		if before < m and cat.intimacy >= m and not m in cat.intimacy_milestones:
			cat.intimacy_milestones.append(m)
			log_event(cat, "%s와의 친밀도가 %d에 도달했어요." % [cat.cat_name, m], now)
	return cat.intimacy - before


func note_attention(cat: CatData) -> void:
	if cat.id == attention_cat:
		attention_streak += 1
	else:
		attention_cat = cat.id
		attention_streak = 1


## Cats with the "jealous" habit that should react because another cat got repeated attention.
func jealous_cats() -> Array[CatData]:
	var out: Array[CatData] = []
	if attention_streak < JEALOUSY_STREAK:
		return out
	for c in cats:
		if c.id != attention_cat and "jealous" in c.habits:
			out.append(c)
	return out


# ---------- care actions (return intimacy delta) ----------

## Best food in stock: wet food first, then dry food. "" if none.
func best_food() -> String:
	for id in ["wet_food", "dry_food"]:
		if int(inventory.get(id, 0)) > 0:
			return id
	return ""


func feed(cat: CatData, now: int, food_id := "") -> float:
	if food_id == "":
		food_id = best_food()
	if food_id == "" or int(inventory.get(food_id, 0)) <= 0:
		return 0.0
	var item := Catalog.item(food_id)
	inventory[food_id] = int(inventory[food_id]) - 1
	cat.advance(now)
	cat.hunger = minf(100.0, cat.hunger + float(item["hunger"]))
	cat.happiness = minf(100.0, cat.happiness + float(item["happy"]))
	_first(cat, "first_feed", "%s에게 처음으로 밥을 줬어요." % cat.cat_name, now)
	note_attention(cat)
	earn_care_coins(5, now)
	return change_intimacy(cat, 1.0, now)


func give_treat(cat: CatData, now: int) -> float:
	if int(inventory.get("treat", 0)) <= 0:
		return 0.0
	var item := Catalog.item("treat")
	inventory["treat"] = int(inventory["treat"]) - 1
	cat.advance(now)
	cat.hunger = minf(100.0, cat.hunger + float(item["hunger"]))
	cat.happiness = minf(100.0, cat.happiness + float(item["happy"]))
	_first(cat, "first_treat", "%s에게 처음으로 간식을 줬어요. 눈이 반짝였어요." % cat.cat_name, now)
	note_attention(cat)
	return change_intimacy(cat, 2.0, now)


func play(cat: CatData, now: int) -> float:
	cat.advance(now)
	var toy_mult := 1.3 if "feather" in owned else 1.0
	cat.happiness = minf(100.0, cat.happiness + 30.0 * cat.param("play_mult") * toy_mult)
	earn_care_coins(8, now)
	cat.hunger = maxf(CatData.FLOOR, cat.hunger - 3.0)
	_first(cat, "first_play", "%s와 처음으로 함께 놀았어요." % cat.cat_name, now)
	note_attention(cat)
	return change_intimacy(cat, 3.0 * cat.param("play_mult"), now)


## Petting reads the cat's signals: annoyed or sleeping cats lose intimacy instead of gaining it.
func pet(cat: CatData, now: int, annoyed: bool, sleeping: bool) -> float:
	cat.advance(now)
	note_attention(cat)
	if annoyed:
		return change_intimacy(cat, -3.0, now)
	if sleeping:
		return change_intimacy(cat, -1.0, now)
	cat.happiness = minf(100.0, cat.happiness + 5.0)
	_first(cat, "first_pet", "%s를 처음으로 쓰다듬었어요." % cat.cat_name, now)
	return change_intimacy(cat, 2.0, now)


## Player answered the cat's slow blink ("cat kiss"): the most valuable bond action.
func answer_blink(cat: CatData, now: int) -> float:
	_first(cat, "first_blink", "%s와 처음으로 눈인사를 나눴어요." % cat.cat_name, now)
	note_attention(cat)
	return change_intimacy(cat, 4.0, now)


## Player left an annoyed cat alone until it calmed down.
func respected_space(cat: CatData, now: int) -> float:
	return change_intimacy(cat, 1.0, now)


func comfort_jealous(cat: CatData, now: int) -> float:
	_first(cat, "first_jealous", "%s(이)가 질투를 했어요. 달래 주니 금세 기분이 풀렸어요." % cat.cat_name, now)
	note_attention(cat)
	return change_intimacy(cat, 2.0, now)


# ---------- coins, market, delivery ----------

## Coins for care actions, limited per day so tapping cannot farm the shop.
func earn_care_coins(amount: int, now: int) -> int:
	var dk := day_key(now)
	var used := int(daily_coins.get(dk, 0))
	var give := clampi(amount, 0, maxi(0, DAILY_CARE_COIN_CAP - used))
	daily_coins = {dk: used + give}
	coins += give
	return give


## First visit of the day pays attendance coins. Returns coins given (0 if already claimed).
func claim_attendance(now: int) -> int:
	var dk := day_key(now)
	if last_attendance == dk:
		return 0
	last_attendance = dk
	coins += ATTENDANCE_COINS
	return ATTENDANCE_COINS


func is_owned_or_ordered(item_id: String) -> bool:
	if item_id in owned:
		return true
	for o in orders:
		if o["item"] == item_id:
			return true
	return false


## Returns "" on success, otherwise a message explaining why the order failed.
func order(item_id: String, now: int) -> String:
	var item := Catalog.item(item_id)
	if item.is_empty():
		return "없는 상품이에요"
	if item["kind"] in ["toy", "furniture"] and is_owned_or_ordered(item_id):
		return "이미 가지고 있거나 배송 중이에요"
	if coins < int(item["price"]):
		return "코인이 부족해요"
	coins -= int(item["price"])
	orders.append({"id": "%d-%d" % [now, randi() % 100000], "item": item_id, "arrives_at": now + int(item["delivery"]) * 60})
	return ""


## Moves arrived orders into the home. Returns the item ids that just arrived.
func receive_deliveries(now: int) -> Array:
	var arrived: Array = []
	var waiting: Array = []
	for o in orders:
		if int(o["arrives_at"]) <= now:
			arrived.append(o["item"])
		else:
			waiting.append(o)
	orders = waiting
	for item_id in arrived:
		var item := Catalog.item(item_id)
		if item["kind"] in ["food", "treat"]:
			inventory[item_id] = int(inventory.get(item_id, 0)) + int(item["servings"])
		elif not item_id in owned:
			owned.append(item_id)
		boxes = mini(MAX_BOXES, boxes + 1)
		log_event(null, "택배 도착: %s" % item["name"], now)
	return arrived


func clear_boxes() -> void:
	boxes = 0


# ---------- discovery ----------

func discover_habit(cat: CatData, habit: String, now: int) -> bool:
	if not habit in cat.habits or habit in cat.discovered_habits:
		return false
	cat.discovered_habits.append(habit)
	var h: Dictionary = Traits.HABITS[habit]
	log_event(cat, "새로운 습관 발견: %s — %s" % [h["label"], h["hint"]], now)
	coins += 30  # discovery rewards are one-time, so they are not part of the daily cap
	return true


func record_behavior(behavior_id: String) -> bool:
	if behavior_id in discovered_behaviors:
		return false
	discovered_behaviors.append(behavior_id)
	coins += 20
	return true


# ---------- persistence ----------

func to_dict() -> Dictionary:
	var cat_dicts: Array = []
	for c in cats:
		cat_dicts.append(c.to_dict())
	return {
		"version": SAVE_VERSION, "cats": cat_dicts, "diary": diary,
		"discovered_behaviors": discovered_behaviors, "daily_gain": daily_gain,
		"adopted_candidates": adopted_candidates, "diary_seen": diary_seen,
		"coins": coins, "inventory": inventory, "owned": owned, "orders": orders, "boxes": boxes,
		"daily_coins": daily_coins, "last_attendance": last_attendance,
	}


static func from_dict(d: Dictionary) -> Household:
	var h := Household.new()
	for cd in d.get("cats", []):
		if cd is Dictionary:
			h.cats.append(CatData.from_dict(cd))
	h.diary = Array(d.get("diary", []))
	h.discovered_behaviors = Array(d.get("discovered_behaviors", []))
	h.adopted_candidates = Array(d.get("adopted_candidates", []))
	h.diary_seen = int(d.get("diary_seen", 0))
	h.coins = int(d.get("coins", START_COINS))
	var inv = d.get("inventory", {"dry_food": 10})
	h.inventory = inv if inv is Dictionary else {}
	h.owned = Array(d.get("owned", []))
	h.orders = Array(d.get("orders", []))
	h.boxes = int(d.get("boxes", 0))
	var dc = d.get("daily_coins", {})
	h.daily_coins = dc if dc is Dictionary else {}
	h.last_attendance = str(d.get("last_attendance", ""))
	var dg = d.get("daily_gain", {})
	h.daily_gain = dg if dg is Dictionary else {}
	return h


func save(path := SAVE_PATH) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))


static func load_from(path := SAVE_PATH) -> Household:
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			return from_dict(parsed)
	return Household.new()
