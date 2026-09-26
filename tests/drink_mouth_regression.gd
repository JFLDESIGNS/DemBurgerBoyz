extends SceneTree
class DrinkGame extends Node:
 const CUP_SHELL_H := .189
 var game_audio = null
 var updates := 0
 var arrivals := 0
 func _set_melting_cup_liquid_level(_food, _level, _flavor):updates+=1
 func _customer_burger_arrived(_customer):arrivals+=1
class Eater extends Node3D:
 func side_food_mouth_global():return Vector3(1,1.6,0)
 func side_food_grip_global():return Vector3(1,1.2,.2)
func _initialize():call_deferred("run")
func run():
 var game=DrinkGame.new();root.add_child(game)
 var eater=Eater.new();root.add_child(eater)
 var food=Node3D.new();root.add_child(food);food.scale=Vector3.ONE*1.1
 var anim=load("res://scripts/side_food_serve.gd").new();root.add_child(anim);anim.set_process(false)
 var completed=[0]
 anim.setup(game,eater,food,"drink",func():completed[0]+=1)
 eater.set_meta("meal_stepping_aside",true)
 for i in 160:anim._process(.016)
 assert(anim.started)
 anim.elapsed=.45+.52;anim._process(0)
 var rim=food.global_position+food.global_basis*Vector3(0,game.CUP_SHELL_H,0)
 assert(rim.distance_to(eater.side_food_mouth_global())<.001)
 assert(is_equal_approx(food.scale.x,1.54))
 while not anim.finished:anim._process(.016)
 assert(completed[0]==1);assert(game.updates<=4);assert(eater.get_meta("side_food_pending")==0)
 print("DRINK_MOUTH_REGRESSION_OK liquid mesh updates=",game.updates)
 quit()
