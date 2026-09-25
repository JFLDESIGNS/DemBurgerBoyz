extends Node3D
## Owns presentation only; inventory and payout stay in the game's serve callbacks.
var game: Node
var customer: Node3D
var food: Node3D
var kind: String
var completed: Callable
var elapsed := 0.0
var started := false
var finished := false
var start_position := Vector3.ZERO
var source_scale := Vector3.ONE
var fries: Node3D
var fries_scale := Vector3.ONE
var flavor := "cola"
var delay := 0.0
var gulp_count := 0
var bites := 0
var bite_materials: Array[ShaderMaterial] = []
var cone_bounds := AABB()
var hand_size := 1.0
var fries_position := Vector3.ZERO

func setup(owner_game: Node, eater: Node3D, model: Node3D, food_kind: String, callback: Callable, wait: float = 0.0) -> void:
 game=owner_game;customer=eater;food=model;kind=food_kind;completed=callback;delay=wait
 start_position=food.global_position
 source_scale=food.scale
 hand_size=2.0 if kind=="fries" else 1.4
 if kind=="fries":
  fries=food.find_child("FriesShakeRoot",true,false)
  if is_instance_valid(fries):
   fries_scale=fries.scale
   fries_position=fries.position
   var bounds:AABB=game._mesh_aabb_local(food)
   for mesh in fries.find_children("*","MeshInstance3D",true,false):
    if mesh.mesh==null:continue
    var ink:=ShaderMaterial.new()
    ink.shader=preload("res://shaders/icecream_bites.gdshader")
    var old:Material=mesh.get_active_material(0)
    var tint:=Color(1,.75,.13)
    if old is StandardMaterial3D:
     tint=old.albedo_color
     if old.albedo_texture:ink.set_shader_parameter("albedo_tex",old.albedo_texture)
    ink.set_shader_parameter("tint",tint)
    ink.set_shader_parameter("bounds_min",bounds.position)
    ink.set_shader_parameter("bounds_size",bounds.size)
    mesh.material_override=ink
    bite_materials.append(ink)

 elif kind=="icecream":
  cone_bounds=game._mesh_aabb_local(food)
  for mesh in food.find_children("*","MeshInstance3D",true,false):
   if mesh.mesh==null:continue
   var ink:=ShaderMaterial.new()
   ink.shader=preload("res://shaders/icecream_bites.gdshader")
   var old:Material=mesh.material_override
   var tint:=Color(1,.95,.84)
   if old is StandardMaterial3D:
    tint=old.albedo_color
    if old.albedo_texture:ink.set_shader_parameter("albedo_tex",old.albedo_texture)
   ink.set_shader_parameter("tint",tint)
   ink.set_shader_parameter("bounds_min",cone_bounds.position)
   ink.set_shader_parameter("bounds_size",cone_bounds.size)
   mesh.material_override=ink
   bite_materials.append(ink)
 else:
  flavor=str(food.get_meta("flavor","cola"))
 customer.set_meta("side_food_pending",int(customer.get_meta("side_food_pending",0))+1)

func mouth() -> Vector3:
 if customer.has_method("side_food_mouth_global"): return customer.side_food_mouth_global()
 return customer.mouth_global() if customer.has_method("mouth_global") else customer.global_position+Vector3(0,1.4,0)

func hand() -> Vector3:
 if customer.has_method("side_food_grip_global"): return customer.side_food_grip_global()
 if customer.has_method("burger_grip_global"): return customer.burger_grip_global()
 return mouth()+customer.global_basis*Vector3(0,-.27,.19)

func _process(delta: float) -> void:
 if finished: return
 if not is_instance_valid(customer) or not is_instance_valid(food):
  finish();return
 if not started:
  delay-=delta
  if delay>0 or bool(customer.get_meta("meal_stepping_aside",false)) or bool(customer.get_meta("burger_in_flight",false)) or bool(customer.get_meta("side_food_active",false)): return
  started=true
  customer.set_meta("side_food_active",true)
  if customer.has_method("begin_side_food"): customer.begin_side_food()
  if game.game_audio and game.game_audio.has_method("play_serve_whoosh"): game.game_audio.play_serve_whoosh()
 elapsed+=delta
 var catch_t:=clampf(elapsed/.45,0,1)
 # Three complete lift/lower cycles, driven by the same hand animation as burgers.
 var cycle_time:=1.0
 var eating_time:=maxf(0,elapsed-.45)
 var cycle:=mini(2,int(eating_time/cycle_time))
 var phase:=clampf((eating_time-float(cycle)*cycle_time)/cycle_time,0,1)
 var lift:=smoothstep(0,.42,phase)*(1-smoothstep(.62,1,phase))
 if elapsed<.45:lift=0
 if customer.has_method("pose_side_food"):customer.pose_side_food(lift,kind=="drink")
 var grip:=hand()
 var hold_height:=.055 if kind=="fries" else (.13 if kind=="icecream" else .095)
 var tilt:=lift*(.4 if kind=="drink" else (.62 if kind=="fries" else .72))
 var held_basis:Basis=customer.global_basis*Basis(Vector3.RIGHT,-tilt)
 var size_now:=source_scale.lerp(Vector3.ONE*hand_size,catch_t)
 food.global_basis=held_basis.scaled(size_now)
 var held_position:=grip-food.global_basis*Vector3(0,hold_height,0)
 # Four inches higher throughout each lift, independent of item scale and tilt.
 if kind in ["fries","icecream"]:held_position += Vector3.UP*.1016
 food.global_position=start_position.lerp(held_position,catch_t)+Vector3(0,sin(catch_t*PI)*.16,0)
 var next_bite:=mini(3,cycle+(1 if phase>=.52 else 0)) if elapsed>=.45 else 0
 if next_bite>bites:
  bites=next_bite
  if kind=="drink":
   if game.game_audio and game.game_audio.has_method("play_drink_gulp"):game.game_audio.play_drink_gulp()
  else:
   if customer.has_method("chomp_burger"):customer.chomp_burger()
   if game.game_audio and game.game_audio.has_method("play_burger_chomp"):game.game_audio.play_burger_chomp()
 if kind=="fries":
  if is_instance_valid(fries):
   # Clip eaten portions in place; never push geometry through the carton.
   for ink in bite_materials:
    ink.set_shader_parameter("food_inverse",food.global_transform.affine_inverse())
    ink.set_shader_parameter("consumed",float(bites)/3.0)
   if bites>=3:fries.hide()
 elif kind=="icecream":
  for ink in bite_materials:
   ink.set_shader_parameter("food_inverse",food.global_transform.affine_inverse())
   ink.set_shader_parameter("consumed",float(bites)/3.0)
 else:
  game._set_melting_cup_liquid_level(food,1-float(bites)/3.0,flavor)
 # Let the last lowering motion finish before releasing the customer.
 if elapsed>=3.45:finish()

func finish() -> void:
 if finished:return
 finished=true
 if is_instance_valid(customer):
  customer.set_meta("side_food_pending",maxi(0,int(customer.get_meta("side_food_pending",1))-1))
  if started:
   customer.set_meta("side_food_active",false)
   if customer.has_method("finish_catch_burger"): customer.finish_catch_burger()
 if is_instance_valid(food):food.queue_free()
 if completed.is_valid():completed.call()
 if is_instance_valid(customer) and not bool(customer.get_meta("burger_in_flight",false)) and int(customer.get_meta("side_food_pending",0))==0:
  game._customer_burger_arrived(customer)
 queue_free()
