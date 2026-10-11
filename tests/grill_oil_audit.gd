extends SceneTree
var g
func _initialize(): call_deferred("run")
func run():
 g=load("res://scenes/main.tscn").instantiate()
 g.set_script(load("res://tests/patty_pool_fixture.gd"));root.add_child(g);current_scene=g
 g.grill_root=Node3D.new();g.world.add_child(g.grill_root)
 g.grill.resize(g.GRILL_SLOTS)
 var at:Vector3=Vector3(g.GRILL_CENTER_X,g.GRILL_SURFACE_Y,g.GRILL_SURFACE_Z)
 g._spawn_oil_slick_local(at,.02)
 g._spawn_oil_slick_local(at+Vector3(.12,0,0),.02)
 # Guest predicts a removal, then receives the host's authoritative acknowledgement.
 assert(g._scrape_slick_array(g.oil_slicks,at,Vector2.RIGHT,.3,.01,"oil"))
 assert(g.oil_slicks.size()==1)
 g._mp_apply_oil_slick_scrape(at.x,at.z,.08,true)
 print("OIL_ACK_REMAINING ",g.oil_slicks.size())
 assert(g.oil_slicks.size()==1,"A repeated removal acknowledgement must not erase the neighboring puddle")
 print("GRILL_OIL_AUDIT_OK")
 quit()
