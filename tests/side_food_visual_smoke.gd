extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(45).timeout.connect(func():push_error("Visual serve test timeout");quit(1))
 root.size=Vector2i(960,720)
 var game=load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/main_ticket_harness.gd"))
 root.add_child(game);current_scene=game
 for node in game.get_node("UI/Root").get_children():
  if node is CanvasItem:node.hide()
 game.camera.position=Vector3(1.3,1.9,-3.1)
 game.camera.look_at(Vector3(0,.95,0))
 game.camera.current=true
 var env=WorldEnvironment.new();env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color("263341")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color.WHITE
 env.environment.ambient_light_energy=.7
 game.add_child(env)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-30,0);game.add_child(light)
 var customer=preload("res://scripts/customer.gd").new()
 customer.setup(["bun_bottom","patty","bun_top"],Color.WHITE,45.,0,0,0,-1,{"format_version":8,"name":"Serve Test","body_type":"kenney_chunky_toon","skin_color":"cf895fff","top_style":2},true)
 game.add_child(customer)
 customer.set_process(false);customer.is_waiting=true
 customer.position=Vector3.ZERO;customer.rotation_degrees.y=180
 for kind in ["fries","drink","icecream"]:
  var done=[false]
  game._start_side_food_3d(customer,kind,Vector3(.4,1,-.7),func():done[0]=true)
  await create_timer(.95).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/light_balance_release/serve_3d_"+kind+".png")
  while not done[0]:await process_frame
  assert(customer.get_meta("side_food_pending")==0)
 print("REAL_CUSTOMER_3D_FOOD_OK")
 quit()
