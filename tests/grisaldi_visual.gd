extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();game.set_script(load("res://tests/delivery_network_fixture.gd"));root.add_child(game);current_scene=game
 game.get_node("UI").hide()
 var outside=Node3D.new();game.add_child(outside);game.playing=true
 game._build_background_people(outside);game._start_background_person(0)
 var actor=game.bg_people[0];actor.position=Vector3.ZERO;actor.rotation_degrees.y=180;actor.scale=Vector3.ONE
 for i in range(1,game.bg_people.size()):game.bg_people[i].hide()
 var camera=Camera3D.new();game.add_child(camera);camera.position=Vector3(0,1.4,-4);camera.look_at(Vector3(0,1.3,0));camera.current=true
 var light=DirectionalLight3D.new();game.add_child(light);light.rotation_degrees=Vector3(-35,-30,0);light.light_energy=1.5
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.3,.4,.42);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.6;game.add_child(env)
 await process_frame;await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png("res://output/grisaldi_new_look.png")
 actor._burger_props=preload("res://scripts/burger_animation_library.gd").attach(actor._anim_player,actor._anim_player.get_parent())
 assert(actor._anim_player.has_animation("burger/Grisaldi_Cartwheel"))
 actor._anim_player.play("burger/Grisaldi_Cartwheel");actor._anim_player.seek(1.02,true)
 await process_frame;await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png("res://output/grisaldi_cartwheel.png")
 print("GRISALDI_VISUAL_OK");quit()
