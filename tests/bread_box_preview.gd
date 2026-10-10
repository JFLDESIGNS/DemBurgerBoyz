extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/grubbah_fixture.gd"));root.add_child(g);current_scene=g
	root.size=Vector2i(1000,800)
	g._build_bun_inventory_piles(g.world)
	g.supply_stock.bun_bottom=100;g.supply_stock.bun_top=100;g._refresh_bun_inventory_piles()
	var box=g.bun_pile_root.get_node("BreadBox")
	assert(is_instance_valid(box.door),"Door hinge must survive GLB export")
	assert(box.model.has_node("InteriorBunLight") and box.model.has_node("SpinningBunSign"))
	g.playing=true
	var spin_before:float=box.bun_sign.rotation.y
	box._process(.1)
	assert(box.bun_sign.rotation.y>spin_before,"Roof bun sign spins during gameplay")
	box.set_process(false)
	box.set_open(true,.5);assert(box.open_amount==1 and is_equal_approx(box.door.rotation.x,-PI*.5))
	assert(box.door.position.z < box.door_closed_position.z and box.door.position.y > box.door_closed_position.y)
	box.set_open(false,.5);assert(box.open_amount==0 and is_zero_approx(box.door.rotation.x))
	assert(box.door.position.is_equal_approx(box.door_closed_position))
	var at:Vector3=g.bun_pile_root.global_position+Vector3(0,.27,0)
	g.camera.look_at_from_position(at+Vector3(-.22,.22,-1.7),at)
	var light=DirectionalLight3D.new();g.world.add_child(light);light.rotation_degrees=Vector3(-35,-35,0);light.light_energy=1.5
	var env=WorldEnvironment.new();g.world.add_child(env);env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("3C4247")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65
	g.get_node("UI").hide()
	await create_timer(.5).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/customer_polish_qa/bread_box_closed.png")
	box.set_open(true,.5)
	await create_timer(.2).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/customer_polish_qa/bread_box_open.png")
	print("BREAD_BOX_OK: clickable inventory, glass, hinge open/close")
	quit()
