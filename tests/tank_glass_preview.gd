extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(640,640)
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g
 g.get_node("UI").hide()
 g._add_soda_flavor_tank(g.world,"cola",Vector3.ZERO)
 g._set_soda_tank_visual_level("cola",.45)
 var studio:=WorldEnvironment.new();studio.environment=Environment.new();studio.environment.background_mode=Environment.BG_COLOR;studio.environment.background_color=Color("654C35");studio.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;studio.environment.ambient_light_color=Color.WHITE;studio.environment.ambient_light_energy=.7;g.world.add_child(studio)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-30,0);g.world.add_child(light)
 g.camera.position=Vector3(.35,.16,.8);g.camera.look_at(Vector3.ZERO)
 for i in 12:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/customer_polish_qa/tank_clear_center.png")
 assert(g.world.get_node("Tank_cola/Glass").material_override is ShaderMaterial)
 print("TANK_GLASS_OK")
 quit()
