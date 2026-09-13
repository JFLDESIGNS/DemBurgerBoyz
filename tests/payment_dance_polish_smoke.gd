extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(65).timeout.connect(func():quit(1))
	var stage:=Node3D.new();root.add_child(stage);current_scene=stage
	var game=load("res://scenes/main.tscn").instantiate();game.set_script(load(get_script().resource_path.get_base_dir().path_join("interaction_delivery_fixture.gd")));stage.add_child(game);game.get_node("UI").hide()
	var mat:StandardMaterial3D=game._cached_sale_bill_material()
	assert(mat.albedo_color.is_equal_approx(Color(.8,.8,.8,1)) and mat.shading_mode==BaseMaterial3D.SHADING_MODE_PER_PIXEL)
	assert(mat!=game._cached_tip_bill_material(false),"Sale shading must not alter tip-jar bills")
	var customer=load("res://scripts/customer.gd").new()
	var order:Array[String]=["bun_bottom","patty","bun_top"]
	customer.setup(order,Color.WHITE,45,0,0,0,-1,{},true)
	stage.add_child(customer);customer.position=Vector3.ZERO;customer.rotation=Vector3.ZERO;customer.is_waiting=true;customer.set_process(false)
	var life=customer.get_node("CustomerLife");life.set_process(false);life.start_grill_dance()
	var player:AnimationPlayer=customer._anim_player
	var chosen:=String(player.current_animation)
	assert(chosen in ["kenney_hiphop/HipHop","kenney_wave_hiphop/Dance","kenney_gangnam/Dance"],"Real customer must use an upright dance")
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skeleton=customer.find_child("Skeleton3D",true,false) as Skeleton3D
	var arm:=skeleton.find_bone("LeftArm");assert(arm>=0)
	player.advance(.35);var first:=skeleton.get_bone_pose_rotation(arm)
	player.advance(.65);var second:=skeleton.get_bone_pose_rotation(arm)
	assert(first.angle_to(second)>.08,"Dance must visibly animate the arms")
	for i in 30:customer._play_wait_stance();player.advance(.01)
	assert(player.current_animation==chosen,"Idle refresh must not interrupt dancing")
	var bill=game._make_tip_bill_mesh(false,2.04,0);bill.material_override=mat;stage.add_child(bill);bill.position=Vector3(1.05,1.2,0);bill.rotation_degrees=Vector3(20,0,-20);bill.scale=Vector3.ONE*1.8
	var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(0.25,1.2,3.6);camera.look_at(Vector3(.25,.8,0));camera.current=true
	var light:=DirectionalLight3D.new();stage.add_child(light);light.rotation_degrees=Vector3(-38,-32,0);light.light_energy=1.2
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("4e6275");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.5;stage.add_child(env)
	if DisplayServer.get_name()!="headless":
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://output/payment_dance_polish.png"))
	print("PAYMENT_DANCE_POLISH_OK")
	stage.queue_free();await process_frame;quit()
