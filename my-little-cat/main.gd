extends Node3D
## Prototype: 3D room, up to 3 cats with personalities/habits, intimacy built by reading body language.
## Cats are primitive placeholders until the purchased rigged asset is imported.

const DEV_TOOLS := true  # "+1시간" button for testing decay


var household: Household
var time_offset := 0
var actors := {}          # cat_id -> CatActor
var selected_id := ""
var jealous_pending := {}  # cat_id -> true while waiting to be comforted
var rng := RandomNumberGenerator.new()

var title_label: Label
var trait_label: Label
var hunger_bar: ProgressBar
var happy_bar: ProgressBar
var bond_bar: ProgressBar
var signal_label: Label
var toast_label: Label
var toast_left := 0.0
var blink_button: Button
var tabs: HBoxContainer
var phone: PhoneUI
var phone_button: Button
var coin_label: Label
var props: Node3D            # furniture and delivery boxes, rebuilt when they change
var delivery_check := 0.0


func now() -> int:
	return int(Time.get_unix_time_from_system()) + time_offset


func _ready() -> void:
	Engine.max_fps = 30  # keeps heat and battery low; enough for a calm pet scene
	get_viewport().physics_object_picking = true
	rng.randomize()
	household = Household.load_from()
	if household.cats.is_empty():
		household.adopt("나비", "cheese", ["affectionate"], ["jealous", "window_spot"], now())
	household.advance_all(now())
	_build_room()
	_build_ui()
	for c in household.cats:
		_spawn(c)
	_select(household.cats[0].id)
	_check_deliveries()
	_refresh_props()
	_check_attendance()


func _check_attendance() -> void:
	var got := household.claim_attendance(now())
	if got > 0:
		_toast("오늘의 출석 보상: 코인 +%d" % got)
		household.save()


func _check_deliveries() -> void:
	var arrived := household.receive_deliveries(now())
	if arrived.is_empty():
		return
	var names: Array = []
	for id in arrived:
		names.append(Catalog.item(id)["name"])
	_toast("딩동! 택배 도착: %s" % ", ".join(names))
	_refresh_props()
	household.save()


func _notification(what: int) -> void:
	if household == null:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		household.advance_all(now())
		household.save()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		household.advance_all(now())
		_check_deliveries()
		_check_attendance()


func _sel() -> CatData:
	return household.find(selected_id)


func _actor() -> CatActor:
	return actors.get(selected_id)


# ---------- room ----------

func _mat(c: Color, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _mesh(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _build_room() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("2a2420")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("f3dcc4")
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe2b8")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -35, 0)
	add_child(sun)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(6, 6)
	_mesh(floor_mesh, _mat(Color("8c705e")), Vector3.ZERO)
	var back := BoxMesh.new()
	back.size = Vector3(6, 3, 0.1)
	_mesh(back, _mat(Color("d8cfc4")), Vector3(0, 1.5, -3))
	var left := BoxMesh.new()
	left.size = Vector3(0.1, 3, 6)
	_mesh(left, _mat(Color("cfc4b6")), Vector3(-3, 1.5, 0))
	var window := BoxMesh.new()
	window.size = Vector3(0.05, 0.9, 1.2)
	var win_mat := _mat(Color("cfe8f5"), 0.1)
	win_mat.emission_enabled = true
	win_mat.emission = Color("fff1d6")
	win_mat.emission_energy_multiplier = 0.3
	_mesh(window, win_mat, Vector3(-2.94, 1.4, -0.6))

	var rug := CylinderMesh.new()
	rug.top_radius = 1.2
	rug.bottom_radius = 1.2
	rug.height = 0.02
	_mesh(rug, _mat(Color("d9a89c"), 1.0), Vector3(0, 0.01, 0)).scale = Vector3(1, 1, 0.7)
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.16
	bowl.bottom_radius = 0.12
	bowl.height = 0.08
	_mesh(bowl, _mat(Color("7fb0d9"), 0.3), CatActor.BOWL_POS + Vector3(0, 0.04, 0))

	var cam := Camera3D.new()
	cam.fov = 60
	cam.position = Vector3(0.0, 3.4, 4.6)
	add_child(cam)
	cam.look_at(Vector3(-0.2, 0.0, -0.4))


func _refresh_props() -> void:
	if props:
		props.queue_free()
	props = Node3D.new()
	add_child(props)
	var wood := _mat(Color("a9825f"))
	var fabric := _mat(Color("c7a4c9"), 1.0)
	var rope := _mat(Color("d6c19a"), 1.0)
	if "cushion" in household.owned:
		var c := CylinderMesh.new()
		c.top_radius = 0.42
		c.bottom_radius = 0.45
		c.height = 0.08
		_prop(c, fabric, CatActor.CUSHION_POS + Vector3(0, 0.04, 0))
	if "scratcher" in household.owned:
		var base := BoxMesh.new()
		base.size = Vector3(0.4, 0.05, 0.4)
		_prop(base, wood, CatActor.SCRATCHER_POS + Vector3(0, 0.025, 0))
		var post := CylinderMesh.new()
		post.top_radius = 0.07
		post.bottom_radius = 0.07
		post.height = 0.7
		_prop(post, rope, CatActor.SCRATCHER_POS + Vector3(0, 0.4, 0))
	if "cat_tower" in household.owned:
		var pole := CylinderMesh.new()
		pole.top_radius = 0.09
		pole.bottom_radius = 0.09
		pole.height = CatActor.TOWER_TOP
		_prop(pole, rope, CatActor.TOWER_POS + Vector3(0, CatActor.TOWER_TOP / 2.0, 0))
		for h in [0.05, 0.6, CatActor.TOWER_TOP]:
			var shelf := BoxMesh.new()
			shelf.size = Vector3(0.7, 0.06, 0.7)
			_prop(shelf, fabric, CatActor.TOWER_POS + Vector3(0, h, 0))
	var box_mat := _mat(Color("c9a173"), 1.0)
	for i in household.boxes:
		var p: Vector3 = CatActor.BOX_POSITIONS[i]
		var bottom := BoxMesh.new()
		bottom.size = Vector3(0.6, 0.04, 0.45)
		_prop(bottom, box_mat, p + Vector3(0, 0.02, 0))
		for side in [-1, 1]:
			var wall_x := BoxMesh.new()
			wall_x.size = Vector3(0.04, 0.3, 0.45)
			_prop(wall_x, box_mat, p + Vector3(0.3 * side, 0.15, 0))
			var wall_z := BoxMesh.new()
			wall_z.size = Vector3(0.6, 0.3, 0.04)
			_prop(wall_z, box_mat, p + Vector3(0, 0.15, 0.225 * side))


func _prop(mesh: Mesh, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	props.add_child(mi)


func _spawn(c: CatData) -> void:
	var a := CatActor.new()
	add_child(a)
	a.setup(c, household)
	a.tapped.connect(_select)
	a.habit_shown.connect(_on_habit_shown)
	a.behavior_seen.connect(_on_behavior_seen)
	a.calmed_down.connect(_on_calmed_down)
	actors[c.id] = a
	_rebuild_tabs()


# ---------- UI ----------

const INK := Color("3a2f28")
const SUB := Color("6e5f55")


func _box(color: Color, radius := 18, pad := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6
	return sb


func _label(text: String, size: int, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _bar(label_text: String, parent: Control, color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := _label(label_text, 22)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2(96, 0)
	row.add_child(l)
	var b := ProgressBar.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(0, 22)
	b.show_percentage = false
	b.add_theme_stylebox_override("fill", _box(color, 11, 0))
	b.add_theme_stylebox_override("background", _box(Color("e8ddd2"), 11, 0))
	row.add_child(b)
	return b


func _button(text: String, parent: Control, cb: Callable, height := 88, color := Color("f2a65a")) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 26)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, Color.WHITE)
	b.add_theme_stylebox_override("normal", _box(color))
	b.add_theme_stylebox_override("hover", _box(color.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", _box(color.darkened(0.15)))
	b.add_theme_stylebox_override("hover_pressed", _box(color.darkened(0.15)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 20)
	root.add_theme_constant_override("margin_right", 20)
	root.add_theme_constant_override("margin_top", 40)
	root.add_theme_constant_override("margin_bottom", 32)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)

	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	col.add_child(tabs)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color(1.0, 0.98, 0.95, 0.93), 22, 20))
	col.add_child(card)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	card.add_child(info)
	var title_row := HBoxContainer.new()
	info.add_child(title_row)
	title_label = _label("", 34)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)
	coin_label = _label("", 22, Color("8a6a2a"))
	coin_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	coin_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(coin_label)
	trait_label = _label("", 20, SUB)
	info.add_child(trait_label)
	hunger_bar = _bar("배부름", info, Color("f2a65a"))
	happy_bar = _bar("행복", info, Color("6cbf98"))
	bond_bar = _bar("친밀도", info, Color("f08ca0"))
	signal_label = _label("", 22, Color("8a4b3a"))
	info.add_child(signal_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)

	toast_label = _label("", 22, Color.WHITE)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_stylebox_override("normal", _box(Color(0.16, 0.12, 0.1, 0.82), 16, 16))
	toast_label.visible = false
	col.add_child(toast_label)

	blink_button = _button("눈인사로 답하기 ♥", col, _on_blink, 76, Color("f08ca0"))
	blink_button.visible = false

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	col.add_child(row1)
	_button("쓰다듬기", row1, _on_pet, 88, Color("e8946a"))
	_button("밥 주기", row1, _on_feed, 88, Color("f2a65a"))
	_button("간식", row1, _on_treat, 88, Color("d98aa8"))
	_button("놀아주기", row1, _on_play, 88, Color("6cbf98"))

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	col.add_child(row2)
	phone_button = _button("스마트폰 열기", row2, _open_phone, 72, Color("4a3f38"))
	if DEV_TOOLS:
		_button("+1시간 (테스트)", row2, _on_skip_hour, 72, Color("9a8f86"))

	phone = PhoneUI.new()
	layer.add_child(phone)
	phone.setup(household, now)
	phone.adopted.connect(_on_adopted)
	phone.props_changed.connect(_refresh_props)


func _rebuild_tabs() -> void:
	for ch in tabs.get_children():
		ch.queue_free()
	for c in household.cats:
		var id: String = c.id
		var color := Color("f08ca0") if id == selected_id else Color("b8a89c")
		_button(c.cat_name, tabs, func(): _select(id), 60, color)


func _select(id: String) -> void:
	selected_id = id
	for k in actors:
		actors[k].set_selected(k == id)
	_rebuild_tabs()


func _toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_left = 3.5


func _process(delta: float) -> void:
	var c := _sel()
	var a := _actor()
	if c == null or a == null:
		return
	title_label.text = c.cat_name
	var habits_text := "습관: 아직 발견 못 함"
	if not c.discovered_habits.is_empty():
		var names: Array = []
		for h in c.discovered_habits:
			names.append(Traits.HABITS[h]["label"])
		habits_text = "습관: " + ", ".join(names)
	trait_label.text = "%s  |  %s  (%d/%d 발견)" % [c.personality_labels(), habits_text, c.discovered_habits.size(), c.habits.size()]
	hunger_bar.value = c.hunger
	happy_bar.value = c.happiness
	bond_bar.value = c.intimacy
	signal_label.text = a.signal_text()
	blink_button.visible = a.is_blinking()
	coin_label.text = "코인 %d · 사료 %d · 간식 %d" % [household.coins, int(household.inventory.get("dry_food", 0)) + int(household.inventory.get("wet_food", 0)), int(household.inventory.get("treat", 0))]
	delivery_check -= delta
	if delivery_check <= 0.0:
		delivery_check = 5.0
		_check_deliveries()
	var unread := phone.unread_count()
	phone_button.text = "스마트폰 (새 기록 %d)" % unread if unread > 0 else "스마트폰 열기"
	if toast_left > 0.0:
		toast_left -= delta
		if toast_left <= 0.0:
			toast_label.visible = false


# ---------- actions ----------

func _after_action(c: CatData, delta_bond: float, msg: String) -> void:
	if jealous_pending.has(c.id):
		jealous_pending.erase(c.id)
		household.comfort_jealous(c, now())
		msg = "%s의 질투가 풀렸어요" % c.cat_name
	for j in household.jealous_cats():
		if not jealous_pending.has(j.id):
			jealous_pending[j.id] = true
			actors[j.id].go_jealous(actors[c.id].position)
	if household.attention_streak >= Household.JEALOUSY_STREAK:
		household.attention_streak = 0
	if msg != "":
		_toast(msg)
	elif delta_bond < 0.0:
		_toast("%s(이)가 싫어했어요 (친밀도 %.0f)" % [c.cat_name, delta_bond])
	household.save()


func _on_pet() -> void:
	var c := _sel()
	var a := _actor()
	var d := household.pet(c, now(), a.is_annoyed(), a.is_sleeping())
	var msg := ""
	if a.is_sleeping():
		msg = "자는 %s를 깨웠어요" % c.cat_name
	a.on_pet()
	_after_action(c, d, msg)


func _on_feed() -> void:
	var c := _sel()
	if household.best_food() == "":
		_toast("사료가 다 떨어졌어요. 스마트폰의 냥마켓에서 주문해 주세요")
		return
	var d := household.feed(c, now())
	_actor().on_feed()
	_after_action(c, d, "")


func _on_treat() -> void:
	var c := _sel()
	if int(household.inventory.get("treat", 0)) <= 0:
		_toast("간식이 없어요. 냥마켓에서 츄르를 주문해 보세요")
		return
	var d := household.give_treat(c, now())
	_actor().on_feed()
	_after_action(c, d, "%s(이)가 간식을 맛있게 먹었어요" % c.cat_name)


func _on_play() -> void:
	var c := _sel()
	var d := household.play(c, now())
	_actor().on_play()
	_after_action(c, d, "")


func _on_blink() -> void:
	var c := _sel()
	var d := household.answer_blink(c, now())
	_actor().on_blink_answered()
	_after_action(c, d, "%s와 눈인사를 나눴어요 ♥" % c.cat_name)


func _on_calmed_down(cat_id: String) -> void:
	var c := household.find(cat_id)
	if c:
		household.respected_space(c, now())
		if cat_id == selected_id:
			_toast("기다려 줘서 고마워요. %s의 기분이 풀렸어요" % c.cat_name)
		household.save()


func _on_habit_shown(cat_id: String, habit: String) -> void:
	var c := household.find(cat_id)
	if c and household.discover_habit(c, habit, now()):
		_toast("%s의 새로운 습관 발견: %s" % [c.cat_name, Traits.HABITS[habit]["label"]])
		household.save()


func _on_behavior_seen(behavior_id: String) -> void:
	if household.record_behavior(behavior_id):
		_toast("행동 도감에 추가: %s" % Catalog.behavior_name(behavior_id))
		household.save()


func _on_skip_hour() -> void:
	time_offset += 3600
	household.advance_all(now())
	_check_deliveries()
	household.save()


func _open_phone() -> void:
	household.advance_all(now())
	phone.open()


func _on_adopted(c: CatData) -> void:
	_spawn(c)
	_select(c.id)
	_toast("%s(이)가 우리 집에 왔어요! 성격: %s" % [c.cat_name, c.personality_labels()])
