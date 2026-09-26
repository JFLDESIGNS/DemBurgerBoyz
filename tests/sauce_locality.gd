extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var game=load("res://scripts/game.gd").new()
 var grill=Node3D.new();root.add_child(grill);game.grill_root=grill
 var item=game._new_condiment_spline_batch("ketchup",.008)
 item.spline_segments=PackedVector3Array([Vector3(-.5,0,0),Vector3(.5,0,0)])
 game._rebuild_condiment_spline_batch(item)
 assert(game._scrape_local_sauce(Vector3.ZERO,Vector2.RIGHT,.08))
 assert(not item.smeared)
 assert(item.spline_segments[0].x == -.5)
 assert(item.spline_segments[-1].x == .5)
 var count=0
 for slick in game.soda_slicks:
  if slick.smeared:
   count+=1
   for pt in slick.spline_segments: assert(absf(pt.x)<.10)
 assert(count==1)
 for pass_index in 2:
  game._scrape_local_sauce(Vector3(0,0,2),Vector2.RIGHT,.08)
  game._scrape_local_sauce(Vector3.ZERO,Vector2.RIGHT,.08)
 for slick in game.soda_slicks: assert(not slick.smeared)
 game._challenge_bonus_tip=50;game._challenge_cook_count=10
 game._challenge_cook_total=2.0
 var low=game._challenge_quality_bonus()
 game._challenge_cook_total=11.0
 assert(game._challenge_quality_bonus()>low*10)
 game.free();grill.queue_free()
 print("SAUCE_LOCALITY_AND_BONUS_OK")
 quit()
