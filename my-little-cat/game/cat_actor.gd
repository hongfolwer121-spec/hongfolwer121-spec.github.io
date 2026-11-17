class_name CatActor
extends Node3D
## On-screen cat: placeholder body + personality-driven behavior + readable body-language signals.
## The primitive body is temporary; the purchased rigged cat replaces _build_body() later,
## while the behavior/signal logic stays.

signal tapped(cat_id: String)
signal habit_shown(cat_id: String, habit: String)
signal behavior_seen(behavior_id: String)
signal calmed_down(cat_id: String)   # annoyed state ended without being touched

const BOWL_POS := Vector3(0.75, 0, 0.3)
const WINDOW_POS := Vector3(-2.3, 0, -0.6)
const FRONT_POS := Vector3(0.35, 0, 1.55)   # close to the camera: "comes to you"
const BOUNDS_MIN := Vector3(-2.4, 0, -2.4)
const BOUNDS_MAX := Vector3(2.4, 0, 1.7)
const PET_WINDOW_MS := 20000
const CUSHION_POS := Vector3(-1.25, 0, 0.55)
const SCRATCHER_POS := Vector3(-1.9, 0, -2.2)
const TOWER_POS := Vector3(1.45, 0, -2.2)
const TOWER_TOP := 1.1
const BOX_POSITIONS := [Vector3(1.45, 0, 0.9), Vector3(-0.7, 0, -1.9)]

var data: CatData
var household: Household
var rng := RandomNumberGenerator.new()

var state := "idle"
var target := Vector3.ZERO
var speed := 0.6
var state_left := 2.0          # seconds until the next decision
var annoyed_left := 0.0
var touched_while_annoyed := false
var blink_left := 0.0
var pet_times: Array = []
var selected := false

var body: Node3D
var head: Node3D
var tail: Node3D
var ears: Array[Node3D] = []
var eyes: Array[MeshInstance3D] = []
var badge: Label3D
var ring: MeshInstance3D


func setup(cat: CatData, house: Household) -> void:
	data = cat
	household = house
	rng.seed = hash(cat.id)
	_build_body()
	position = Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 0.8))


# ---------- public signals for UI ----------

func is_annoyed() -> bool:
	return annoyed_left > 0.0


func is_sleeping() -> bool:
	return state == "sleep"


func is_blinking() -> bool:
	return blink_left > 0.0


func signal_text() -> String:
	if is_annoyed():
		return "꼬리를 세차게 흔들고 귀를 젖혔어요. 지금은 혼자 있고 싶대요"
	if is_blinking():
		return "당신을 보며 천천히 눈을 깜빡여요. 눈인사로 답해 줄까요?"
	if is_sleeping():
		return "곤히 자고 있어요. 깨우지 말아 주세요"
	match data.need():
		"hungry":
			return "밥그릇 앞에서 기다리고 있어요"
		"bored":
			return "심심해 보여요. 같이 놀아 줄까요?"
	match state:
		"jealous":
			return "다른 고양이만 예뻐해서 질투가 났어요"
		"approach":
			return "당신에게 다가왔어요"
		"box":
			return "택배 상자 안에 쏙 들어가 있어요"
		"scratch":
			return "스크래처에 발톱을 갈고 있어요"
		"perch":
			return "캣타워 꼭대기에서 방을 내려다보고 있어요"
	return "편하게 쉬고 있어요"


func set_selected(v: bool) -> void:
	selected = v
	ring.visible = v


# ---------- reactions to player actions ----------

func on_pet() -> void:
	if is_annoyed():
		touched_while_annoyed = true
		annoyed_left = maxf(annoyed_left, 4.0)  # touching an annoyed cat makes it last longer
		return
	if is_sleeping():
		_set_state("idle", 2.0)
		return
	var now := Time.get_ticks_msec()
	pet_times.append(now)
	pet_times = pet_times.filter(func(t): return now - t < PET_WINDOW_MS)
	if pet_times.size() > int(data.param("pet_tolerance")):
		_become_annoyed()
	else:
		_emit_behavior("purr_pet")


func on_feed() -> void:
	_go(BOWL_POS + Vector3(-0.3, 0, 0), "eat", 4.0)


func on_play() -> void:
	_set_state("play", 3.0)


func on_blink_answered() -> void:
	blink_left = 0.0
	_emit_behavior("slow_blink")


func go_jealous(toward: Vector3) -> void:
	if is_sleeping() or is_annoyed():
		return
	_go(toward + Vector3(0.35, 0, 0.25), "jealous", 5.0)
	if "jealous" in data.habits:
		habit_shown.emit(data.id, "jealous")


# ---------- behavior ----------

func _set_state(s: String, duration: float) -> void:
	state = s
	state_left = duration


func _go(pos: Vector3, then_state: String, then_duration: float) -> void:
	target = pos.clamp(BOUNDS_MIN, BOUNDS_MAX)
	state = "walk"
	set_meta("then", [then_state, then_duration])


func _become_annoyed() -> void:
	annoyed_left = 6.0
	touched_while_annoyed = false
	pet_times.clear()
	_emit_behavior("tail_lash")


func _emit_behavior(id: String) -> void:
	behavior_seen.emit(id)


func _is_night() -> bool:
	var hour := int(Time.get_time_dict_from_system()["hour"])
	return hour >= 22 or hour < 5


func _decide() -> void:
	var need := data.need()
	if need == "hungry":
		_go(BOWL_POS + Vector3(-0.3, 0, 0.05), "wait_food", 8.0)
		return
	var roll := rng.randf()
	var sleep_bias := data.param("sleep_bias") + (0.25 if _is_night() else 0.0)
	if rng.randf() < data.param("annoy_chance"):
		_become_annoyed()
		_set_state("idle", 3.0)
		return
	if "night_zoomies" in data.habits and _is_night() and roll < 0.25:
		_go(Vector3(-2.0 if position.x > 0 else 2.0, 0, rng.randf_range(-2.0, 1.0)), "idle", 1.0)
		speed = 2.2
		habit_shown.emit(data.id, "night_zoomies")
		_emit_behavior("zoomies")
		return
	var owned: Array = household.owned if household else []
	var boxes: int = household.boxes if household else 0
	if boxes > 0 and rng.randf() < (0.35 if "curious" in data.habits else 0.15):
		_go(BOX_POSITIONS[rng.randi() % boxes], "box", rng.randf_range(8.0, 14.0))
		if "curious" in data.habits:
			habit_shown.emit(data.id, "curious")
		return
	if roll < sleep_bias * 0.5:
		if "cushion" in owned:
			_go(CUSHION_POS + Vector3(rng.randf_range(-0.15, 0.15), 0, 0), "sleep", rng.randf_range(15.0, 30.0))
		else:
			_set_state("sleep", rng.randf_range(15.0, 30.0))
		_emit_behavior("sleep")
		return
	if "scratcher" in owned and rng.randf() < 0.15:
		_go(SCRATCHER_POS + Vector3(0.35, 0, 0.35), "scratch", 4.0)
		return
	if "cat_tower" in owned and rng.randf() < 0.15:
		_go(TOWER_POS + Vector3(0, 0, 0.45), "perch", rng.randf_range(10.0, 16.0))
		return
	var approach := data.param("approach") * (0.4 + data.intimacy / 100.0)
	if rng.randf() < approach:
		_go(FRONT_POS + Vector3(rng.randf_range(-0.4, 0.4), 0, 0), "approach", 8.0)
		return
	if "window_spot" in data.habits and rng.randf() < 0.35:
		_go(WINDOW_POS + Vector3(0, 0, rng.randf_range(-0.3, 0.3)), "sit_window", 10.0)
		return
	if "loner" in data.habits and rng.randf() < 0.3:
		_go(Vector3(2.1, 0, -2.1), "idle", 8.0)
		habit_shown.emit(data.id, "loner")
		return
	if rng.randf() < 0.25:
		_set_state("groom", 4.0)
		_emit_behavior("groom")
		return
	_go(Vector3(rng.randf_range(-2.0, 2.0), 0, rng.randf_range(-2.0, 1.2)), "idle", rng.randf_range(3.0, 6.0))


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0

	if annoyed_left > 0.0:
		annoyed_left -= delta
		if annoyed_left <= 0.0 and not touched_while_annoyed:
			calmed_down.emit(data.id)
	if blink_left > 0.0:
		blink_left -= delta

	match state:
		"walk":
			var to := target - position
			to.y = 0
			if to.length() < 0.05:
				speed = 0.6
				var then: Array = get_meta("then", ["idle", 3.0])
				_set_state(then[0], then[1])
				if then[0] == "sit_window":
					habit_shown.emit(data.id, "window_spot")
				elif then[0] == "box":
					_emit_behavior("box_sit")
				elif then[0] == "scratch":
					_emit_behavior("scratch")
				elif then[0] == "perch":
					_emit_behavior("tower_perch")
				if then[0] == "eat" and "groom_after_meal" in data.habits:
					set_meta("groom_next", true)
			else:
				position += to.normalized() * minf(speed * delta, to.length())
				rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), delta * 6.0)
		_:
			state_left -= delta
			if state == "approach" and blink_left <= 0.0 and data.intimacy >= 20.0 and rng.randf() < delta * 0.15:
				blink_left = 4.0
			if state_left <= 0.0:
				if state == "eat" and get_meta("groom_next", false):
					set_meta("groom_next", false)
					_set_state("groom", 4.0)
					habit_shown.emit(data.id, "groom_after_meal")
					_emit_behavior("groom")
				else:
					_set_state("idle", 0.0)
					_decide()

	_animate(t, delta)


func _animate(t: float, delta: float) -> void:
	var sleeping := is_sleeping()
	var lie := 1.0 if sleeping else 0.0
	body.position.y = lerpf(body.position.y, -0.1 * lie, delta * 3.0)
	body.scale = Vector3(1.0 + 0.1 * lie, 1.0 - 0.25 * lie, 1.0) * (1.0 + 0.015 * sin(t * (1.2 if sleeping else 2.2)))

	var tail_speed := 9.0 if is_annoyed() else (0.8 if sleeping else 2.5)
	var tail_amp := 35.0 if is_annoyed() else 15.0
	tail.rotation_degrees.z = sin(t * tail_speed) * tail_amp
	tail.rotation_degrees.x = -10.0 if state == "approach" or state == "jealous" else 25.0  # tail up when greeting

	for e in ears:
		e.rotation_degrees.z = lerpf(e.rotation_degrees.z, (35.0 if is_annoyed() else 0.0) * signf(e.position.x), delta * 8.0)

	var eye_open := 1.0
	if sleeping:
		eye_open = 0.1
	elif is_blinking():
		eye_open = 0.15 + 0.85 * absf(sin(t * 0.9))  # slow blink
	for eye in eyes:
		eye.scale.y = lerpf(eye.scale.y, eye_open, delta * 8.0)

	var pitch := 0.0
	match state:
		"eat":
			pitch = 30.0 + sin(t * 10.0) * 6.0
		"groom":
			pitch = 20.0 + sin(t * 6.0) * 15.0
		"wait_food":
			pitch = 15.0
		"scratch":
			pitch = -25.0 + sin(t * 14.0) * 8.0
		"perch":
			pitch = 20.0
		"approach", "jealous":
			pitch = -15.0
		"play":
			position.y = absf(sin(t * 6.0)) * 0.25
	if state != "play":
		var ground := TOWER_TOP if state == "perch" else (0.04 if state == "box" else 0.0)
		position.y = lerpf(position.y, ground, delta * 6.0)
	head.rotation_degrees.x = lerpf(head.rotation_degrees.x, pitch, delta * 4.0)

	if is_annoyed():
		badge.text = "!!"
	elif is_blinking():
		badge.text = "♥"
	elif sleeping:
		badge.text = "Zz"
	elif data.need() == "hungry":
		badge.text = "밥?"
	else:
		badge.text = ""


# ---------- placeholder body ----------

func _mat(c: Color, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _part(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_body() -> void:
	var coat: Dictionary = Traits.COATS.get(data.coat, Traits.COATS["cheese"])
	var fur := _mat(coat["fur"])
	var cream := _mat(coat["cream"])
	var eye_mat := _mat(Color("f2d36b") if data.coat in ["black", "tuxedo"] else Color("2b2320"), 0.2)

	body = Node3D.new()
	add_child(body)
	var torso := SphereMesh.new()
	torso.radius = 0.2
	torso.height = 0.36
	_part(torso, fur, Vector3(0, 0.2, 0), body).scale = Vector3(0.9, 1.0, 1.2)
	for side in [-1, 1]:
		var leg := CapsuleMesh.new()
		leg.radius = 0.04
		leg.height = 0.18
		_part(leg, cream, Vector3(0.07 * side, 0.08, 0.13), body)

	head = Node3D.new()
	head.position = Vector3(0, 0.45, 0.12)
	body.add_child(head)
	var skull := SphereMesh.new()
	skull.radius = 0.15
	skull.height = 0.27
	_part(skull, fur, Vector3.ZERO, head)
	var muzzle := SphereMesh.new()
	muzzle.radius = 0.07
	muzzle.height = 0.1
	_part(muzzle, cream, Vector3(0, -0.05, 0.11), head)
	for side in [-1, 1]:
		var ear := Node3D.new()
		ear.position = Vector3(0.08 * side, 0.13, 0)
		head.add_child(ear)
		var ear_mesh := PrismMesh.new()
		ear_mesh.size = Vector3(0.1, 0.11, 0.04)
		_part(ear_mesh, fur, Vector3(0, 0.03, 0), ear)
		ears.append(ear)
		var eye := SphereMesh.new()
		eye.radius = 0.025
		eye.height = 0.05
		eyes.append(_part(eye, eye_mat, Vector3(0.055 * side, 0.02, 0.125), head))

	tail = Node3D.new()
	tail.position = Vector3(0, 0.12, -0.2)
	body.add_child(tail)
	var tail_mesh := CapsuleMesh.new()
	tail_mesh.radius = 0.035
	tail_mesh.height = 0.4
	_part(tail_mesh, fur, Vector3(0, 0.18, -0.05), tail).rotation_degrees = Vector3(-25, 0, 0)

	badge = Label3D.new()
	badge.font = load("res://fonts/NanumGothicBold.ttf")
	badge.font_size = 64
	badge.outline_size = 12
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.position = Vector3(0, 0.85, 0)
	badge.pixel_size = 0.004
	add_child(badge)

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.3
	ring_mesh.outer_radius = 0.34
	ring = _part(ring_mesh, _mat(Color("ffd36b"), 0.4), Vector3(0, 0.01, 0), self)
	ring.scale = Vector3(1, 0.1, 1)
	ring.visible = false

	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	shape.shape = sphere
	shape.position = Vector3(0, 0.3, 0)
	area.add_child(shape)
	area.input_event.connect(_on_input_event)
	add_child(area)


func _on_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		tapped.emit(data.id)
