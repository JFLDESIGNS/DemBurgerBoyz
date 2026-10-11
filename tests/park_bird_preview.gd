extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1000,850)
 var scene=Node3D.new();root.add_child(scene);current_scene=scene
 var bird=load("res://scripts/park_bird.gd").new();scene.add_child(bird);bird.set_process(false);bird._enter(&"Idle")
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("B5D5DC");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.6;scene.add_child(env)
 var light=DirectionalLight3D.new();scene.add_child(light);light.rotation_degrees=Vector3(-40,-25,0)
 var camera=Camera3D.new();scene.add_child(camera);camera.position=Vector3(1.0,.8,1.6);camera.look_at(Vector3(0,.43,.05));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.3;camera.make_current()
 for n in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://output/bird_2k_preview.png")
 print("BIRD_PREVIEW_OK");quit()
