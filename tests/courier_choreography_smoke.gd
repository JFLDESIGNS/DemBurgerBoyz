extends SceneTree
func _initialize(): call_deferred("run")
func run():
 create_timer(100).timeout.connect(func():quit(1))
 root.size=Vector2i(1280,720)
 var game=load("res://scenes/main.tscn").instantiate();game.set_script(load(get_script().resource_path.get_base_dir().path_join("mobile_packing_fixture.gd")))
 root.add_child(game);current_scene=game;game.playing=true
 for i in game.STATION_COUNT:game.stations.append({"items":[],"patties":[]})
 game.get_node("UI").hide()
 var light=DirectionalLight3D.new();game.add_child(light);light.rotation_degrees=Vector3(-40,-30,0);light.light_energy=1.2
 var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("38453f");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.6;game.add_child(environment)
 var phone=VBoxContainer.new();game.get_node("UI/Root").add_child(phone)
 var mobile=load("res://scripts/grubbah.gd").new();game.add_child(mobile);mobile.set_process(false);game._grubbah=mobile;mobile.setup(game,phone)
 mobile.state={"number":2,"items":["bun_bottom","patty","bun_top"],"phase":"pickup","driver_skin":2,"base":20}
 mobile.build_props();mobile.driver_style=2
 mobile.age=mobile.DRIVER_APPROACH+mobile.DRIVER_WALK*.72;mobile.update_visuals(0)
 assert(is_equal_approx(mobile.courier.position.z,3.9))
 mobile.age=mobile.DRIVER_APPROACH+mobile.DRIVER_WALK+.55;mobile.update_visuals(0)
 assert(mobile.courier.position.z<2.5 and mobile.courier._anim_player.current_animation=="courier/Courier_Grab")
 var pos=mobile.courier.position
 game.camera.look_at_from_position(Vector3(2.8,2.2,-.2),Vector3(.4,1.1,2.35))
 await process_frame;mobile.update_visuals(0);await process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://output/courier_grab.png")
 mobile.age=mobile.DRIVER_APPROACH+mobile.DRIVER_WALK+1.0;mobile.update_visuals(0)
 assert(mobile.bag.position.distance_to(mobile.courier_grab_position())<.03,"Bag follows authored hands after grasp")
 mobile.state.phase="collected";mobile.age=0;mobile.update_visuals(0)
 assert(mobile.courier.position.is_equal_approx(pos),"Turn starts without teleporting")
 mobile.age=mobile.DRIVER_TURN+mobile.DRIVER_RETREAT;mobile.update_visuals(0)
 assert(is_equal_approx(mobile.courier.position.z,3.9) and mobile.courier.get_meta("courier_running"))
 mobile.age=mobile.DRIVER_TURN+mobile.DRIVER_RETREAT+mobile.DRIVER_RETURN;mobile.update_visuals(0)
 assert(not mobile.courier.visible)
 # Real leaving customer moves only 28 cm away and keeps that offset for the review.
 var c=load("res://scripts/customer.gd").new();game.customers_root.add_child(c);c.set_process(false)
 c._leave_walk_x=0;c._apply_leave_body(.6,false)
 assert(is_equal_approx(c.global_position.z,c._wait_z()+.28))
 c._apply_leave_body(3,false);assert(is_equal_approx(c._service_backstep,.28))
 print("COURIER_CHOREOGRAPHY_OK")
 game.queue_free();await process_frame;quit()
