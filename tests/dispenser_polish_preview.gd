extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(800,900)
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g
 g.get_node("UI").hide()
 var station=Node3D.new();g.world.add_child(station);g.soda_root=station
 var model=g._instantiate_kitchen_machine(g.REFINED_SODA_PATH);model.name="FountainModel";station.add_child(model)
 g._setup_refined_soda_controls(model)
 var plates=model.find_children("*satin splash liner*","MeshInstance3D",true,false)
 assert(plates.size()==1 and plates[0].get_node("BackplateToonShine").material_override is ShaderMaterial)
 g._build_soda_cup_rack(station)
 g._rebuild_soda_fill_ghosts();g._update_fill_seat_ghosts()
 for ghost in g._ghost_fill_cups.values():assert(not ghost.visible)
 assert(not g.soda_cup_rack_outline.visible)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("344D4A");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;g.world.add_child(env)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-25,0);g.world.add_child(light)
 g.camera.position=Vector3(-.9,.95,-2.0);g.camera.look_at(Vector3(0,.65,0))
 for i in 12:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/customer_polish_qa/dispenser_polish.png")
 print("DISPENSER_POLISH_OK: backplate shine, visible cup stack, no cup outlines")
 quit()
