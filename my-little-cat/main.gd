extends Node3D
## Prototype: 3D room + placeholder cat + feed/play loop.
## The placeholder cat (primitive shapes) will be replaced by the purchased rigged cat asset.

const DEV_TOOLS := true  # shows the "+1시간" time-skip button for testing decay

var state := CatState.new()
var time_offset := 0  # dev time skip, seconds

var cat: Node3D
var head: Node3D
var tail: Node3D
var action := "idle"
var action_t := 0.0

var hunger_bar: ProgressBar
var happy_bar: ProgressBar
var status_label: Label


func now() -> int:
	return int(Time.get_unix_time_from_system()) + time_offset


func _ready() -> void:
	Engine.max_fps = 30  # keeps heat and battery low; enough for a calm pet scene
	state.load_or_init(now())
	_build_room()
	_build_cat()
	_build_ui()
	_refresh_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		state.advance(now())
		state.save()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		state.advance(now())
		_refresh_ui()


# ---------- scene ----------

func _mat(c: Color, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _mesh(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_room() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("2a2420")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("f3dcc4")
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe2b8")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -35, 0)
	add_child(sun)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(6, 6)
	_mesh(floor_mesh, _mat(Color("b88a5f")), Vector3.ZERO)

	var back := BoxMesh.new()
	back.size = Vector3(6, 3, 0.1)
	_mesh(back, _mat(Color("ecdcc5")), Vector3(0, 1.5, -3))
	var left := BoxMesh.new()
	left.size = Vector3(0.1, 3, 6)
	_mesh(left, _mat(Color("e4d2b8")), Vector3(-3, 1.5, 0))

	var rug := CylinderMesh.new()
	rug.top_radius = 1.2
	rug.bottom_radius = 1.2
	rug.height = 0.02
	var rug_mi := _mesh(rug, _mat(Color("e9b8aa"), 1.0), Vector3(0, 0.01, 0))
	rug_mi.scale = Vector3(1, 1, 0.7)

	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.16
	bowl.bottom_radius = 0.12
	bowl.height = 0.08
	_mesh(bowl, _mat(Color("7fb0d9"), 0.3), Vector3(0.7, 0.04, 0.3))

	var cam := Camera3D.new()
	cam.fov = 50
	cam.position = Vector3(0.9, 1.6, 2.6)
	add_child(cam)
	cam.look_at(Vector3(0, 0.35, 0))


func _build_cat() -> void:
	var fur := _mat(Color("f2a65a"))
	var cream := _mat(Color("fbe3c4"))
	var dark := _mat(Color("2b2320"), 0.2)
	cat = Node3D.new()
	add_child(cat)

	var body := SphereMesh.new()
	body.radius = 0.2
	body.height = 0.36
	var body_mi := _mesh(body, fur, Vector3(0, 0.2, 0), cat)
	body_mi.scale = Vector3(0.9, 1.0, 1.2)

	for side in [-1, 1]:
		var leg := CapsuleMesh.new()
		leg.radius = 0.04
		leg.height = 0.18
		_mesh(leg, cream, Vector3(0.07 * side, 0.08, 0.13), cat)

	head = Node3D.new()
	head.position = Vector3(0, 0.45, 0.12)
	cat.add_child(head)
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.15
	head_mesh.height = 0.27
	_mesh(head_mesh, fur, Vector3.ZERO, head)
	var muzzle := SphereMesh.new()
	muzzle.radius = 0.07
	muzzle.height = 0.1
	_mesh(muzzle, cream, Vector3(0, -0.05, 0.11), head)
	for side in [-1, 1]:
		var ear := PrismMesh.new()
		ear.size = Vector3(0.1, 0.11, 0.04)
		_mesh(ear, fur, Vector3(0.08 * side, 0.15, 0), head)
		var eye := SphereMesh.new()
		eye.radius = 0.025
		eye.height = 0.05
		_mesh(eye, dark, Vector3(0.055 * side, 0.02, 0.125), head)

	tail = Node3D.new()
	tail.position = Vector3(0, 0.12, -0.2)
	cat.add_child(tail)
	var tail_mesh := CapsuleMesh.new()
	tail_mesh.radius = 0.035
	tail_mesh.height = 0.4
	var tail_mi := _mesh(tail_mesh, fur, Vector3(0, 0.18, -0.05), tail)
	tail_mi.rotation_degrees = Vector3(-25, 0, 0)


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var mood := state.mood()
	# breathing
	cat.scale = Vector3.ONE * (1.0 + 0.015 * sin(t * 2.2))
	tail.rotation_degrees.z = sin(t * (3.5 if mood == "content" else 1.2)) * 20.0

	if action != "idle":
		action_t += delta
		match action:
			"eat":
				cat.position = cat.position.lerp(Vector3(0.45, 0, 0.25), delta * 3.0)
				head.rotation_degrees.x = 30.0 + sin(action_t * 10.0) * 6.0
			"play":
				cat.position.y = absf(sin(action_t * 6.0)) * 0.25
				cat.rotation_degrees.y += delta * 240.0
		if action_t > 2.5:
			action = "idle"
			cat.position = Vector3.ZERO
			cat.rotation_degrees = Vector3.ZERO
	else:
		# hungry/bored cats droop their head; content cats look up at the owner
		var target_pitch := 22.0 if mood != "content" else -8.0
		head.rotation_degrees.x = lerpf(head.rotation_degrees.x, target_pitch, delta * 2.0)


# ---------- UI ----------

func _bar(label_text: String, parent: Control) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(110, 0)
	l.add_theme_font_size_override("font_size", 26)
	row.add_child(l)
	var b := ProgressBar.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 30)
	b.show_percentage = false
	row.add_child(b)
	return b


func _button(text: String, parent: Control, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 96)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 32)
	b.pressed.connect(cb)
	parent.add_child(b)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		root.add_theme_constant_override("margin_" + side, 32)
	root.add_theme_constant_override("margin_top", 72)
	root.add_theme_constant_override("margin_bottom", 56)
	layer.add_child(root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	root.add_child(col)

	var title := Label.new()
	title.text = state.cat_name
	title.add_theme_font_size_override("font_size", 44)
	col.add_child(title)
	hunger_bar = _bar("배부름", col)
	happy_bar = _bar("행복", col)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 28)
	col.add_child(status_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	col.add_child(buttons)
	_button("밥 주기", buttons, _on_feed)
	_button("놀아주기", buttons, _on_play)
	if DEV_TOOLS:
		_button("+1시간", buttons, _on_skip_hour)


func _refresh_ui() -> void:
	hunger_bar.value = state.hunger
	happy_bar.value = state.happiness
	match state.mood():
		"hungry":
			status_label.text = "배가 고파요. 밥그릇을 쳐다보고 있어요"
		"bored":
			status_label.text = "심심해요. 놀아줄까요?"
		_:
			status_label.text = "기분 좋게 쉬고 있어요"


func _on_feed() -> void:
	state.feed(now())
	state.save()
	action = "eat"
	action_t = 0.0
	_refresh_ui()


func _on_play() -> void:
	state.play(now())
	state.save()
	action = "play"
	action_t = 0.0
	_refresh_ui()


func _on_skip_hour() -> void:
	time_offset += 3600
	state.advance(now())
	state.save()
	_refresh_ui()
