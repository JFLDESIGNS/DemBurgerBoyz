extends Node
var game: Node
var actor: Node3D
var age:=0.0
var home:=Vector3.ZERO
var home_yaw:=0.0
var home_process:=true
var lane:=Vector3.ZERO
var contact:=Vector3.ZERO
var hit:=false
var started_walk:=false
var started_return:=false
func setup(owner_game: Node,person: Node3D,origin: Vector3) -> void:
 game=owner_game;actor=person;home=origin;home_yaw=actor.rotation.y
 home_process=actor.is_processing();actor.set_process(false)
 actor.set_meta("truck_smack_busy",true)
 actor._eating=false;actor._burger_eat_phase="";actor._cat_pet_left=0.0
 actor.global_position=home
 lane=Vector3(.42,home.y,3.9);contact=Vector3(.42,home.y,2.45)
 actor.play_street_rejection(true)
func _process(delta: float) -> void:
 if not is_instance_valid(actor) or not is_instance_valid(game) or not game.playing:
  finish();return
 age+=delta
 if age<.85:return
 if age<2.65:
  if not started_walk: actor.play_street_walk(1.35);started_walk=true
  var u:=clampf((age-.85)/1.8,0.0,1.0)
  actor.global_position=home.lerp(lane,minf(u/.7,1.0)) if u<.7 else lane.lerp(contact,(u-.7)/.3)
  actor.rotation.y=atan2(contact.x-actor.global_position.x,contact.z-actor.global_position.z)
 elif age<3.35:
  actor._play_anim("idle")
  if actor._anim_player:actor._anim_player.stop()
  actor._cache_panic_bones()
  var u:=clampf((age-2.65)/.7,0.0,1.0)
  var punch:=sin(u*PI)
  actor._set_panic_bone_rot("RightArm",Vector3(-1.1*punch,0,.9*punch))
  actor._set_panic_bone_rot("RightForeArm",Vector3(-.7*punch,0,0))
  if u>=.52 and not hit:
   hit=true
   game._start_slot_camera_shake(.5,.075)
   if is_instance_valid(game.game_audio):game.game_audio.play_truck_knock(1.0)
 elif age<5.15:
  if not started_return:actor._reset_skeleton_pose();actor.play_street_walk(1.25);started_return=true
  var u:=clampf((age-3.35)/1.8,0.0,1.0)
  actor.global_position=contact.lerp(lane,minf(u/.3,1.0)) if u<.3 else lane.lerp(home,(u-.3)/.7)
  actor.rotation.y=atan2(home.x-actor.global_position.x,home.z-actor.global_position.z)
 else:finish()
func finish() -> void:
 if is_instance_valid(actor):
  actor.global_position=home;actor.rotation.y=home_yaw
  actor.set_meta("truck_smack_busy",false)
  actor.set_meta("food_stop_until",0)
  actor._reset_skeleton_pose()
  actor.set_process(home_process)
  if actor.is_street_pedestrian:actor.play_street_walk()
  else:actor._anim_state="";actor._play_anim("idle")
 queue_free()
