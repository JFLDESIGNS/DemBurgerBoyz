extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/kitchen_network_fixture.gd"));root.add_child(g)
 g.grill_root=Node3D.new();g.add_child(g.grill_root)
 for flavor in ["ketchup","mustard"]:
  var item=g._new_condiment_spline_batch(flavor,.008)
  item.spline_segments=PackedVector3Array([Vector3(-.5,0,0),Vector3(.5,0,0)])
  g._rebuild_condiment_spline_batch(item)
  for pass_index in 3:
   g._scrape_local_sauce(Vector3(0,0,2),Vector2.RIGHT,.08)
   assert(g._scrape_local_sauce(Vector3.ZERO,Vector2.RIGHT,.08))
  assert(g.soda_slicks.size()==1 and not g.soda_slicks[0].smeared,"Three passes clear the touched sauce")
  assert(g.soda_slicks[0].spline_segments.size()==4,"Untouched sauce on both sides remains")
  for repeat in 30:assert(not g._scrape_local_sauce(Vector3.ZERO,Vector2.RIGHT,.08),"Boundary must not manufacture new micro-smears")
  g.soda_slicks[0].mesh.queue_free();g.soda_slicks.clear()
 print("SAUCE_CLEANUP_BOTH_FLAVORS_OK")
 quit()
