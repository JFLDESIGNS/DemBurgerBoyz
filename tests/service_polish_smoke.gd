extends SceneTree
func _initialize(): call_deferred("run")
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/delivery_network_fixture.gd"))
 root.add_child(game);current_scene=game
 game.playing=true
 game.grill_root=Node3D.new();game.world.add_child(game.grill_root)
 game._record_order_history(20,5,4,null)
 assert(game.order_history.size()==1 and game.order_history[0].profit==21.0)
 game.mp_order_history([],0)
 assert(game.order_history.size()==1,"Stale history cannot overwrite current orders")
 var before:int=game.chef_points
 game.perfect_serves=5
 game._check_perfect_rewards();game._check_perfect_rewards()
 assert(game.chef_points==before+50,"Milestone awards exactly once")
 var p:Vector3=Vector3(game.GRILL_CENTER_X,game.GRILL_SURFACE_Y,game.GRILL_SURFACE_Z)
 game._spawn_condiment_spline_segment_local(p-Vector3(.12,0,0),p+Vector3(.12,0,0),.015,"ketchup")
 var initial:int=game.soda_slicks.size()
 for pass_id in 3:
  game._scrape_slick_array(game.soda_slicks,p,Vector2(.04,0),.04,.2,"soda")
  if pass_id<2:
   assert(game.soda_slicks.size()==initial)
   assert(game.soda_slicks[-1].smeared)
   assert(game.condiment_smear_items.is_empty(),"No unrelated splat debris")
  game._scrape_slick_array(game.soda_slicks,p+Vector3(2,0,0),Vector2(.04,0),.04,.2,"soda")
 assert(game.soda_slicks.size()==initial-1,"Three separate passes clear sauce")
 var a:=Node3D.new();var b:=Node3D.new();root.add_child(a);root.add_child(b)
 a.position=Vector3(-1.1,0,0);b.position=Vector3.ZERO
 var min_gap:=100.0
 for i in 240:
  var previous:=a.position
  var desired:=Vector3(a.position.x+.025,0,0)
  a.position=preload("res://scripts/crowd_spacing.gd").steer(a,previous,desired,[a,b],.016)
  min_gap=minf(min_gap,Vector2(a.position.x,a.position.z).length())
 assert(a.position.x>1.0 and min_gap>.60,"Walk around blocker without passing through")
 a.remove_meta("crowd_home_z")
 a.position=Vector3(-1.2,0,0);b.position=Vector3(1.2,0,0)
 min_gap=100.0
 for i in 240:
  var pa:=a.position;var pb:=b.position
  a.position=preload("res://scripts/crowd_spacing.gd").steer(a,pa,Vector3(pa.x+.025,0,0),[a,b],.016)
  b.position=preload("res://scripts/crowd_spacing.gd").steer(b,pb,Vector3(pb.x-.025,0,0),[a,b],.016)
  min_gap=minf(min_gap,Vector2(a.position.x-b.position.x,a.position.z-b.position.z).length())
 assert(a.position.x>1.0 and b.position.x< -1.0 and min_gap>.60,"Opposing walkers pass without intersection")
 a.queue_free();b.queue_free();game.queue_free()
 for i in 5:await process_frame
 print("SERVICE_POLISH_OK")
 quit()
