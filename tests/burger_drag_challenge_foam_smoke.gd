extends SceneTree
class Eater extends Node3D:
 var lifts:=0
 func start_eating_burger(): lifts+=1
 func burger_animation_duration(eating:bool): return 1.2 if eating else .4
func _initialize(): call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/main_ticket_harness.gd"))
 root.add_child(game);current_scene=game
 game._setup_stations_data();game._build_station_ui()
 game.playing=true
 game.tutorial_mode=true
 var index=game.STATION_CRAFT
 var st:Dictionary=game.stations[index]
 st.items=["bun_bottom","bun_top"] as Array[String]
 game._refresh_station(index)
 var preview:Control=st.preview
 var home=preview.position
 game._begin_whole_burger_drag(index)
 assert(not game._whole_burger_drag.is_empty())
 var move=InputEventMouseMotion.new()
 move.position=game._whole_burger_drag.mouse+Vector2(80,-30)
 move.relative=Vector2(20,0)
 assert(game._handle_whole_burger_drag(move))
 assert(preview.position.distance_to(home)>10)
 assert(abs(preview.rotation)>0)
 var release=InputEventMouseButton.new()
 release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false
 assert(game._handle_whole_burger_drag(release))
 await create_timer(.55).timeout
 assert(preview.position.is_equal_approx(home))
 assert(is_zero_approx(preview.rotation))
 assert(st.items==["bun_bottom","bun_top"])
 assert(is_equal_approx(game._station_item_build_scale("bun_top"),1.05*.87))
 game.cup_soda_fill=1.0;game._cup_pouring=true
 game._update_cup_fizz_life(1.0)
 var foam=game._cup_fizz
 game._cup_pouring=false
 game._update_cup_fizz_life(.1)
 assert(game._cup_fizz>0 and game._cup_fizz<foam)
 assert(game._cup_foam_linger>29)
 var eater=Eater.new();root.add_child(eater)
 var bites=[0];var consumed=[0.0];var finished=[false]
 var tween=create_tween()
 preload("res://scripts/burger_serve_timing.gd").append_handoff(tween,eater,.4,func(value):consumed[0]=value,func():bites[0]+=1,func():finished[0]=true,1)
 await tween.finished
 assert(eater.lifts==1 and bites[0]==2 and finished[0])
 assert(is_equal_approx(consumed[0],1.0))
 print("BURGER_DRAG_CHALLENGE_FOAM_OK")
 quit()
