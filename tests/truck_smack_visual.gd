extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/delivery_network_fixture.gd"));root.add_child(g);current_scene=g;g.playing=true;g.get_node("UI").hide()
 var outside=Node3D.new();g.add_child(outside);g._build_background_people(outside);g._start_background_person(0)
 var actor=g.bg_people[0]
 var reaction=load("res://scripts/customer_truck_smack.gd").new();g.add_child(reaction);reaction.setup(g,actor,actor.global_position);reaction.set_process(false)
 for tick in 1000:
  reaction._process(1.0/60)
  if reaction.phase=="strike":break
 assert(actor.scale.is_equal_approx(Vector3.ONE))
 actor.global_position=Vector3(-.65,actor.STAND_Y,0)
 actor._anim_player.seek(.58,true);actor._anim_player.pause()
 var customer=load("res://scripts/customer.gd").new();customer.setup(["bun_bottom","patty","bun_top"] as Array[String],Color.WHITE,90,0,0,0,-1,{},true);g.add_child(customer);customer.set_process(false)
 customer.position=Vector3(.65,customer.STAND_Y,0);customer.rotation_degrees.y=180;customer._play_anim("idle")
 for i in range(1,g.bg_people.size()):g.bg_people[i].hide()
 var cam=Camera3D.new();g.add_child(cam);cam.position=Vector3(0,1.4,-4.1);cam.look_at(Vector3(0,1.15,0));cam.current=true
 var light=DirectionalLight3D.new();g.add_child(light);light.rotation_degrees=Vector3(-35,-30,0);light.light_energy=1.5
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.24,.3,.33);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;g.add_child(env)
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://output/truck_smack_height.png")
 print("TRUCK_SMACK_HEIGHT_VISUAL_OK");quit()
