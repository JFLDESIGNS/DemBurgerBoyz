extends SceneTree
class PoseCustomer extends "res://scripts/customer.gd":
 var poses:=0
 var walks:=0
 func _ready():pass
 func _update_eat_pose():poses+=1
 func _play_anim(state:String):
  if state=="walk":walks+=1
 func _animate_expression(_delta:float):pass
 func _apply_bobble(_walking:bool):pass
func _initialize():call_deferred("run")
func run():
 var c=PoseCustomer.new();root.add_child(c);c.set_process(false);c.mp_host_driven=true;c.is_waiting=false;c._eating=true;c._burger_eat_phase="eat"
 c.apply_host_snapshot(Vector3(1,0,2),0)
 for i in 60:c._update_host_driven_pose(.016)
 assert(c.poses==60 and c.walks==0,"Removed ticket must not overwrite eating with walk")
 var cat=load("res://assets/cat/shipping_cat.glb").instantiate();root.add_child(cat)
 load("res://scripts/cat_appearance.gd").apply_eyes(cat)
 for name in ["Cat_Eye_L","Cat_Eye_R"]:
  var eye=cat.find_child(name,true,false)
  assert(eye!=null and eye.material_override is ShaderMaterial)
  assert(eye.material_override.shader.resource_path=="res://shaders/cat_eyes.gdshader")
 print("CAT_PUPILS_GUEST_EAT_OK");quit()
