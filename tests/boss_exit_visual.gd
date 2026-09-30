extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(100).timeout.connect(func():quit(1))
 root.size=Vector2i(1100,700)
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load(get_script().resource_path.get_base_dir().path_join("hotdog_challenge_fixture.gd")))
 root.add_child(g);current_scene=g;g.playing=true;g.stations=[{"items":[],"patties":[]}];g.get_node("UI").hide()
 var light=DirectionalLight3D.new();g.add_child(light);light.rotation_degrees=Vector3(-35,-30,0);light.light_energy=1.2
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("64757b");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;g.add_child(env)
 var pavement=MeshInstance3D.new();pavement.mesh=PlaneMesh.new();pavement.mesh.size=Vector2(40,40);pavement.position.y=-.04;g.add_child(pavement)
 var boss=g._ensure_hotdog_challenge();boss.set_process(false);assert(boss.start());boss.advance_phase();boss.advance_phase()
 g.camera.look_at_from_position(Vector3(3,3.8,-1),Vector3(0,1.5,6.3))
 boss.play("hammer_double");boss.customer.player.seek(boss.customer.player.get_animation("hammer_double").length,true)
 await process_frame
 boss.phase="defeat_sinking";boss.timer=boss.play("ground_exit")
 var heights=[]
 for t in [0.0,.4,.75,1.0]:
  boss.timer=boss.SINK_SECONDS*(1-t);boss.apply_placement()
  await process_frame;await process_frame
  heights.append(boss.customer.mouth_global().y)
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://output/boss_exit_%d.png"%int(t*100))
 assert(heights[3]<heights[0]-1.5,"Authored skeleton must actually travel underground")
 assert(boss.customer.position==boss.boss_position,"Pavement root must stay planted")
 print("BOSS_EXIT_VISUAL_OK ",heights)
 boss.cancel();g.queue_free();await process_frame;quit()
