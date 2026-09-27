extends SceneTree
class Puppet extends "res://scripts/window_cat.gd":
 func _ready():
  _visual=Node3D.new();add_child(_visual);enabled=true;mp_puppet=true;set_process(false)
 func _update_character(_delta:float)->void:pass
 func _update_begging_meows(_delta:float)->void:pass
 func _apply_visual_scale()->void:pass
func _initialize():call_deferred("run")
func run():
 var cat=Puppet.new();root.add_child(cat)
 cat.apply_mp_sync({"x":0.0,"y":0.0,"z":0.0,"yaw":0.0,"vis":true})
 cat.apply_mp_sync({"x":1.0,"y":0.0,"z":0.0,"yaw":90.0,"vis":true})
 assert(is_zero_approx(cat.position.x),"Packet does not snap the cat")
 cat._process(.05)
 assert(is_equal_approx(cat.position.x,.5))
 assert(is_equal_approx(cat.rotation_degrees.y,45.0))
 cat._process(.05)
 assert(is_equal_approx(cat.position.x,1.0))
 print("CAT_PUPPET_INTERPOLATION_OK");quit()
