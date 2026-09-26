extends SceneTree
class TestPatty extends Area3D:
 var is_held := false
 var slot_index := 0
 var net_id := -1
 var _rest_x := 0.0
 var _rest_z := 0.0
 var base_y := 1.155
 var heat_mul := 1.0
 func _play_done_jump(_height: float):pass
func _initialize():call_deferred("run")
func run():
 create_timer(40).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/burger_pick_fixture.gd"));root.add_child(g)
 g._setup_stations_data();g._build_station_ui();g.playing=true;g.start_overlay.hide()
 g.stations[0].items.assign(["bun_bottom","patty","bun_top"])
 g._refresh_station(0)
 await process_frame;await process_frame
 var crown=g._find_station_top_bun_row(0);var float_y=crown.position.y
 g._begin_whole_burger_drag(0)
 assert(g.stations[0].carried_closed)
 assert(crown.position.y>float_y+20)
 var move=InputEventMouseMotion.new();move.position=Vector2(40,0);move.relative=Vector2(40,0)
 assert(g._handle_whole_burger_drag(move))
 var swayed=false
 for layer in g._whole_burger_drag.layers:
  if layer.row.position.distance_to(layer.home)>1:swayed=true
  assert(layer.row.get_theme_stylebox("panel") is StyleBoxEmpty)
 assert(swayed)
 g._finish_whole_burger_drag();await create_timer(.6).timeout
 assert(not g.stations[0].carried_closed)
 var found=false
 var tr=crown.get_node("LayerTexture")
 for f in [.4,.5,.6,.7]:
  var point=tr.get_global_transform_with_canvas()*(tr.size*Vector2(.5,f))
  if g._build_layer_at_screen(point)==crown:
   g._update_build_layer_hover(point)
   assert(crown.get_theme_stylebox("panel") is StyleBoxFlat)
   assert(g.stations[0].layer_hint.text.contains("Right-click to remove"))
   assert(not g._try_bun_pile_click(point));assert(g._try_build_burger_click(point));found=true;break
 assert(found);assert(g.served==1)
 var p=TestPatty.new();var neighbor=TestPatty.new();g.add_child(p);g.add_child(neighbor)
 g.grill.resize(g.GRILL_SLOTS);g.slot_positions.resize(g.GRILL_SLOTS)
 p.slot_index=0;neighbor.slot_index=1;g.grill[0]=p;g.grill[1]=neighbor
 p.position=Vector3(-.3,g.GRILL_SURFACE_Y,0);neighbor.position=Vector3(0,g.GRILL_SURFACE_Y,0)
 var moved=g._move_grill_patty_slide(p,Vector2.ZERO,Vector2(-.3,0),true,1)
 assert(not g._patty_blocked_at(moved.target,0))
 assert(neighbor.position.x>.19)
 print("BURGER_PICK_REGRESSION_OK");quit()
