extends SceneTree
func _initialize(): call_deferred("run")
func run():
	create_timer(100).timeout.connect(func(): push_error("SNACK_INTEGRATION_TIMEOUT"); quit(1))
	var g=load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g
	g.get_node("UI/Root").hide()
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("54545c");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.85;g.world.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-30,-25,0);sun.light_energy=1.2;g.world.add_child(sun)
	var c=load("res://scripts/customer.gd").new()
	var order:Array[String]=["bun_bottom","patty","bun_top"]
	c.setup(order,Color.WHITE,45.0,0,0,0,-1,{"format_version":8,"name":"Snack Preview","body_type":"kenney_chunky_toon","skin_color":"cf895fff","top_style":2,"hair_style":1},true)
	g.world.add_child(c);c.position=Vector3.ZERO;c.rotation=Vector3.ZERO;c.is_waiting=true;c.set_process(false)
	for i in 4:await process_frame
	var mouth_pos:Vector3=c.side_food_mouth_global()
	g.camera.position=mouth_pos+Vector3(0,.08,1.45);g.camera.look_at(mouth_pos);g.camera.current=true
	c.patience = c.patience_max * .5
	var before_patience: float = c.patience
	g._apply_customer_ingredient_hit(c,"bacon",mouth_pos+Vector3(.14,-.12,.07),"face",1)
	assert(is_equal_approx(c.patience, before_patience+c.patience_max*g.BACON_PATIENCE_RESTORE), "Accepted bacon restores customer patience")
	var snack=c.get_node("ThrownFoodSnack");snack.set_process(false);snack.sample(.31)
	assert(c._body.position.y < snack.body_home_y-.05, "Customer body must dip toward low food")
	assert(not snack.temporary_mouth and snack.material!=null,"Real customer must animate its authored mouth")
	assert(float(snack.material.get_shader_parameter("speech_round"))>.7)
	if DisplayServer.get_name()!="headless":
		for i in 4:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/opening_sequence_release/customer_chewing.png")
	snack.finish();snack.queue_free();c.hide()
	preload("res://scripts/love_hearts.gd").burst(c, Vector3(0,2.4,0))
	assert(c.find_children("LoveHeart*", "Sprite3D", false, false).size()==5)
	# End-to-end sling collision with the real cat, including target depth.
	var cat=load("res://scripts/window_cat.gd").new();g.world.add_child(cat);g.window_cat=cat
	cat.special_people_peek(60);cat.set_process(false);cat._happy_anim_left=0;cat._update_character(.01);cat._anim.advance(0)
	for m in cat._visual.find_children("Cat_*","MeshInstance3D",true,false):
		print("CAT_PART ",m.name," center_local=",cat.to_local(m.to_global(m.get_aabb().get_center()))," size=",m.get_aabb().size*m.global_basis.get_scale())
	var head:Vector3=cat.head_global()
	g.camera.position=head+Vector3(0,0,-2.8);g.camera.look_at(head)
	for i in 3:await process_frame
	var screen:Vector2=g._camera_screen_to_gui(g.camera.unproject_position(head)) if g.has_method("_camera_screen_to_gui") else g.camera.unproject_position(head)
	for id in ["cheese","bacon"]:
		g._ensure_ingredient_slingshot().launch(id,screen+Vector2(0,180),screen)
		await create_timer(.55).timeout
		assert(cat._visit_fed,"A flung favorite must feed the cat without petting first")
		var cat_snack=cat.get_node_or_null("ThrownFoodSnack")
		assert(cat_snack!=null,"Real slingshot flight must reach the cat")
		cat_snack.set_process(false);cat_snack.sample(.31)
		assert(cat_snack.temporary_mouth)
		if DisplayServer.get_name()!="headless":
			g.camera.position=head+Vector3(0,-.16,-1.4);g.camera.look_at(head+Vector3(0,-.16,0))
			for i in 4:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/opening_sequence_release/cat_chewing.png")
		cat_snack.finish();cat.remove_child(cat_snack);cat_snack.queue_free()
		g.camera.position=head+Vector3(0,0,-2.8);g.camera.look_at(head)
	print("SNACK_INTEGRATION_OK: authored mouth shader and real cat sling catches")
	g.queue_free();await process_frame;quit()
