extends SceneTree
## Close-up renders of one cat to tune body-language bones (needs a display).

func _shot(dir: String, name: String) -> void:
	for i in 25:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	var m: CatModel = root.find_children("*", "CatModel", true, false)[0] if not root.find_children("*", "CatModel", true, false).is_empty() else null
	if m:
		print(name, " anim=", m.player.current_animation, " t=", snappedf(m.player.current_animation_position, 0.01), " ears=", m.overlay.ears_back)


func _initialize() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("d8cfc4")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("f3dcc4")
	e.ambient_light_energy = 0.5
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	world.add_child(sun)
	var c := CatData.new()
	c.id = "test"
	c.cat_name = "테스트"
	c.coat = "cheese"
	c.personalities = ["affectionate"]
	var a := CatActor.new()
	world.add_child(a)
	a.setup(c, null)
	a.position = Vector3.ZERO
	a.rotation.y = 0.0
	await process_frame
	a.set_process(false)  # must happen after _ready, which re-enables processing
	var cam := Camera3D.new()
	world.add_child(cam)
	await process_frame
	cam.look_at_from_position(Vector3(0.35, 0.65, 0.95), Vector3(0, 0.5, 0.3))
	var o := a.model.overlay
	a.model.play_state("approach", a.rng)
	await _shot(dir, "c1_neutral")
	o.ears_back = 1.0
	o.tail_lash = 1.0
	await _shot(dir, "c2_annoyed")
	o.ears_back = 0.0
	o.tail_lash = 0.0
	o.eyes_closed = 1.0
	await _shot(dir, "c3_eyes_closed")
	o.eyes_closed = 0.0
	o.tail_up = 1.0
	await _shot(dir, "c4_tail_up")
	quit()
