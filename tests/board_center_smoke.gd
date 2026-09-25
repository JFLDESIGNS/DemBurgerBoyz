extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/main_ticket_harness.gd"))
 root.add_child(game);current_scene=game
 game._setup_stations_data();game._build_station_ui()
 game.playing=true;game.tutorial_mode=true
 var board=Node3D.new();game.add_child(board)
 board.position=Vector3(1.5,1.1,.3)
 board.set_meta("burger_surface_center",Vector3(0,.04,0))
 game.build_cutting_board=board
 var cam=Camera3D.new();game.add_child(cam);game.camera=cam
 cam.position=Vector3(0,3,5);cam.look_at(board.position)
 var st:Dictionary=game.stations[game.STATION_CRAFT]
 st.items=["bun_bottom","bun_top"] as Array[String]
 game._refresh_station(game.STATION_CRAFT)
 await process_frame
 for shift in [Vector3.ZERO,Vector3(.2,0,.1)]:
  cam.position+=shift
  game._center_build_burger_on_board()
  var row:Control=st.layer_pool[0]
  var contact=row.get_global_transform_with_canvas()*Vector2(row.size.x*.5,row.size.y*.84)
  var target=cam.unproject_position(board.to_global(Vector3(0,.04,0)))
  assert(contact.distance_to(target)<.1)
 assert(is_equal_approx(game._bun_pile_world_pos().x,game.FRYER_STATION_POS.x+game.BUN_PILE_FRYER_OFFSET.x+.1016))
 print("BOARD_CENTER_AND_BUN_SHIFT_OK")
 quit()
