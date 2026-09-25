extends SceneTree
class Eater extends Node3D:
 var is_challenge_guest:=false
 var starts:=0
 var finishes:=0
 var poses:=0
 var lifts:=0
 var was_lifted:=false
 var chomps:=0
 func mouth_global()->Vector3:return global_position+Vector3(0,1.5,0)
 func begin_side_food():starts+=1
 func pose_side_food(amount:float,_drink:bool):
  poses+=1
  if amount>.95 and not was_lifted:lifts+=1
  was_lifted=amount>.95
 func finish_catch_burger():finishes+=1
 func chomp_burger():chomps+=1
func _initialize():call_deferred("run")
func run():
 create_timer(20).timeout.connect(func():push_error("Side food test timeout");quit(1))
 var game=load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/main_ticket_harness.gd"))
 root.add_child(game);current_scene=game
 var eater=Eater.new();game.add_child(eater)
 eater.set_meta("burger_in_flight",true)
 var callbacks=[0]
 game._start_side_food_3d(eater,"fries",Vector3(1,1,1),func():callbacks[0]+=1)
 game._start_side_food_3d(eater,"drink",Vector3(-1,1,1),func():callbacks[0]+=1,"cola")
 await create_timer(.15).timeout
 assert(eater.starts==0 and eater.get_meta("side_food_pending")==2)
 var fries=game.get_node("ServedFries3D")
 var cup=game.get_node("ServedDrink3D")
 assert(fries.find_child("FriesShakeRoot",true,false)!=null)
 assert(cup.find_child("Liquid",true,false)!=null)
 eater.set_meta("burger_in_flight",false)
 await create_timer(1.35).timeout
 assert(eater.starts==1 and callbacks[0]==0)
 var pile=fries.find_child("FriesShakeRoot",true,false)
 var pile_position=pile.position
 var pile_scale=pile.scale
 await create_timer(1.1).timeout
 assert(pile.position.is_equal_approx(pile_position) and pile.scale.is_equal_approx(pile_scale),"Eating fries must not sink through the carton")
 await create_timer(5.0).timeout
 assert(callbacks[0]==2 and eater.starts==2 and eater.finishes==2)
 assert(eater.get_meta("side_food_pending")==0)
 assert(not is_instance_valid(cup) and not is_instance_valid(fries))
 game._start_side_food_3d(eater,"icecream",Vector3(0,1,1),func():callbacks[0]+=1)
 var cone=game.get_node("ServedCone3D")
 await create_timer(1.8).timeout
 var cream=cone.find_child("CorkscrewSplineServe",true,false)
 assert(is_equal_approx(cone.scale.x,1.4))
 assert(cream.material_override.get_shader_parameter("consumed")>0)
 var waffle=cone.find_child("WaffleCone",true,false)
 assert(waffle.material_override.get_shader_parameter("consumed")>0)
 await create_timer(1.9).timeout
 assert(callbacks[0]==3 and not is_instance_valid(cone))
 assert(eater.get_meta("side_food_pending")==0)
 assert(eater.poses>0)
 assert(eater.lifts==9,"Each food must make three hand-to-mouth motions")
 assert(eater.chomps==6,"Fries and cone must each take three bites")
 print("SIDE_FOOD_3D_QUEUE_CLEANUP_OK")
 quit()
