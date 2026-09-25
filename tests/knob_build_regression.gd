extends SceneTree
func _initialize(): call_deferred("run")
func run():
 create_timer(90).timeout.connect(func(): push_error("KNOB_BUILD_TIMEOUT"); quit(1))
 var grill = load("res://assets/machines/stylized_grill.glb").instantiate()
 grill.set_script(load("res://scripts/stylized_grill.gd"))
 root.add_child(grill)
 grill.configure()
 var mesh: MeshInstance3D = grill.knob.find_child("Rotary_Vermilion",true,false)
 var local_center = mesh.mesh.get_aabb().get_center()
 var start: Vector3 = mesh.to_global(local_center)
 for i in 8:
  grill.set_power(i % 2 == 0,true)
  assert(mesh.to_global(local_center).distance_to(start) < 0.00001,"Knob rotates off-center")
 grill.set_power(true)
 for i in 20:
  await process_frame
  assert(mesh.to_global(local_center).distance_to(start) < 0.00001,"Animated knob drifts")
 var game = load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/main_ticket_harness.gd"))
 root.add_child(game)
 game._style_static_labels()
 game._setup_stations_data()
 game._build_station_ui()
 game.playing = true
 game._serve_fly_busy = true
 var st: Dictionary = game.stations[game.STATION_CRAFT]
 var preview: Control = st.preview
 preview.modulate.a = 0.0
 st.items = ["bun_bottom","patty","bun_top"] as Array[String]
 game._refresh_station(game.STATION_CRAFT)
 assert(preview.modulate.a == 1.0,"Next burger hidden behind ongoing serving animation")
 var visible_layers := 0
 for row in st.layer_pool:
  if row.visible: visible_layers += 1
 assert(visible_layers >= 3,"Next burger layers were not drawn")
 assert(game._serve_fly_busy,"Redrawing build should not cancel serving")
 preview.modulate.a = 0.0
 game._clear_station(game.STATION_CRAFT)
 assert(preview.modulate.a == 1.0,"Clearing challenge station left preview transparent")
 print("KNOB_BUILD_OK stationary rotation, new burger visible during serving, clear resets alpha")
 quit()
