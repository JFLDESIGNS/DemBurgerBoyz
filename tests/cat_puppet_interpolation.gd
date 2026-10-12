extends SceneTree
func _initialize():call_deferred("run")
func run():
 var cat=load("res://tests/cat_puppet_fixture.gd").new();root.add_child(cat)
 cat.apply_mp_sync({"x":0.0,"y":0.0,"z":0.0,"yaw":0.0,"vis":true})
 cat.apply_mp_sync({"x":1.0,"y":0.0,"z":0.0,"yaw":90.0,"vis":true})
 assert(is_zero_approx(cat.position.x),"Packet does not snap the cat")
 cat._process(.05)
 assert(is_equal_approx(cat.position.x,.5))
 assert(is_equal_approx(cat.rotation_degrees.y,45.0))
 cat._process(.05)
 assert(is_equal_approx(cat.position.x,1.0))
 print("CAT_PUPPET_INTERPOLATION_OK");quit()
