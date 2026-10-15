extends Node
var game: Node
var actor: Node3D
var age:=0.0
var home:=Vector3.ZERO
var home_yaw:=0.0
var home_scale:=Vector3.ONE
var home_process:=true
var contact:=Vector3.ZERO
var hit:=false
var phase:="point"
var route: Array[Vector3]=[]
var route_index:=0
func setup(owner_game: Node,person: Node3D,origin: Vector3) -> void:
 game=owner_game;actor=person;home=origin;home_yaw=actor.rotation.y;home_scale=actor.scale
 home_process=actor.is_processing();actor.set_process(false)
 actor.set_meta("truck_smack_busy",true)
 actor._eating=false;actor._burger_eat_phase="";actor._cat_pet_left=0.0
 actor.global_position=home
 # The camera faces +Z: negative X is screen right. Route around the queue.
 contact=Vector3(-1.55,actor.STAND_Y,1.20 + 0.6096) # Two feet farther from the truck.
 route.assign([Vector3(-9.2,home.y,home.z),Vector3(-9.2,actor.STAND_Y,actor.WAIT_Z),Vector3(contact.x,actor.STAND_Y,actor.WAIT_Z),contact])
 if not actor._anim_player.has_animation("burger/Truck_Smack"):
  actor._burger_props=preload("res://scripts/burger_animation_library.gd").attach(actor._anim_player,actor._anim_player.get_parent())
 actor.play_street_rejection(true)
func _process(delta: float) -> void:
 if not is_instance_valid(actor) or not is_instance_valid(game) or not game.playing:
  finish();return
 age+=delta
 if phase=="point":
  if age<.65:return
  phase="approach";actor.play_street_run(1.25)
 if phase=="approach" or phase=="escape":
  if phase=="approach" and route_index>=1: actor.scale=actor.scale.lerp(Vector3.ONE,1.0-exp(-delta*8.0))
  var destination:=route[route_index]
  var before:=actor.global_position
  actor.global_position=before.move_toward(destination,delta*6.8)
  var direction:=destination-before
  if direction.length_squared()>.00001:actor.rotation.y=lerp_angle(actor.rotation.y,atan2(direction.x,direction.z),minf(1,delta*18))
  if actor.global_position.distance_to(destination)<.01:
   route_index+=1
   if route_index>=route.size():
    if phase=="escape":finish();return
    phase="strike";age=0
    actor.scale=Vector3.ONE
    actor.rotation_degrees.y=actor.FACE_TRUCK_YAW
    actor._anim_state="truck_hit"
    actor._anim_player.stop();actor._anim_player.clear_caches()
    actor._anim_player.play("burger/Truck_Smack",0.0);actor._anim_player.speed_scale=1.0
    actor.animate_wawa(1.4)
    if is_instance_valid(game.game_audio):game.game_audio.play_customer_wawa_click(.22,actor.get_customer_voice())
 elif phase=="strike":
  if age>=.58 and not hit:
   hit=true;game._start_slot_camera_shake(.5,.075)
   if is_instance_valid(game.game_audio):game.game_audio.play_truck_knock(1.0)
  if age>=1.4:
   phase="escape";route_index=0
   # Leave along the foreground lane to screen right, never toward storefronts.
   route.assign([Vector3(-10.5,actor.STAND_Y,contact.z)])
   actor._anim_player.stop();actor._anim_player.clear_caches()
   actor.play_street_run(1.3)
func finish() -> void:
 if is_instance_valid(actor):
  actor.set_meta("truck_smack_busy",false);actor.set_meta("food_stop_until",0)
  actor._reset_skeleton_pose();actor.set_process(home_process);actor.scale=home_scale
  if actor.is_street_pedestrian:
   actor.set_meta("building_trip",false)
   actor.remove_meta("mp_walk_target");actor.remove_meta("mp_walk_pose");actor.remove_meta("mp_walk_buffer")
   actor.visible=false
   actor._wawa_click_area.collision_layer=0
   var idx: int=game.bg_people.find(actor)
   if idx>=0:game.bg_people_active[idx]=false;game.bg_people_wait[idx]=8.0
  else:
   if hit:
    actor.hide()
    if not game.mp_enabled or NetManager.is_host():game._on_customer_left(actor,true)
    actor.queue_free()
   else:
    actor.global_position=home;actor.rotation.y=home_yaw
    actor._anim_state="";actor._play_anim("idle")
 queue_free()
