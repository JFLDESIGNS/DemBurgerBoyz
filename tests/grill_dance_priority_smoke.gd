extends SceneTree
class Guest extends "res://scripts/customer.gd":
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
class Life extends "res://scripts/customer_life.gd":
	func _ready() -> void: pass
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(20).timeout.connect(func():quit(1))
	var guest:=Guest.new();root.add_child(guest);guest.is_waiting=true
	guest._burger_props=Node3D.new();guest.add_child(guest._burger_props)
	guest._anim_player=AnimationPlayer.new();guest.add_child(guest._anim_player)
	var library:=AnimationLibrary.new()
	for name in ["Idle_Forward","Phone_One_Hand","Phone_Two_Hands","Check_Watch","Impatient_Foot_Tap"]:
		var animation:=Animation.new();animation.length=4;animation.loop_mode=Animation.LOOP_LINEAR;library.add_animation(name,animation)
	guest._anim_player.add_animation_library("burger",library)
	var hiphop:=AnimationLibrary.new();var dance:=Animation.new();dance.length=5;hiphop.add_animation("HipHop",dance)
	guest._anim_player.add_animation_library("kenney_hiphop",hiphop)
	var life:=Life.new();life.name="CustomerLife";life.customer=guest;guest.add_child(life);life.set_process(false)
	guest._play_anim("burger:Phone_One_Hand")
	assert(guest._anim_player.current_animation=="burger/Phone_One_Hand")
	life.start_grill_dance()
	assert(guest._anim_player.current_animation=="kenney_hiphop/HipHop","Tap must start a full-body hip-hop dance immediately")
	for i in 120:
		guest._wait_motion_time=11.2
		guest._play_wait_stance()
		assert(guest._anim_player.current_animation=="kenney_hiphop/HipHop","Wait/phone scheduler cannot replace the hip-hop dance")
	life.dance_left=0
	guest._play_wait_stance()
	assert(guest._anim_player.current_animation.begins_with("burger/Phone_") or guest._anim_player.current_animation=="burger/Check_Watch","Normal idle scheduling must resume")
	guest.is_leaving=true;life.start_grill_dance();assert(life.dance_left==0,"Leaving must retain priority")
	print("GRILL_DANCE_PRIORITY_OK")
	guest.queue_free();await process_frame;quit()
