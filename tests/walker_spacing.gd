extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var a := Node3D.new()
 var b := Node3D.new()
 root.add_child(a); root.add_child(b)
 a.set_meta("street_spacing",true); b.set_meta("street_spacing",true)
 b.position.x=1.2
 var spacing=load("res://scripts/crowd_spacing.gd")
 var result: Vector3=spacing.steer(a,Vector3.ZERO,Vector3(.2,0,0),[b],.1)
 assert(result.x<=.051,"Follower must preserve headway")
 a.set_meta("street_pair",123);b.set_meta("street_pair",123)
 result=spacing.steer(a,Vector3.ZERO,Vector3(.2,0,0),[b],.1)
 assert(is_equal_approx(result.x,.2),"Couples may stay close")
 a.free();b.free()
 print("WALKER_SPACING_OK")
 quit()
