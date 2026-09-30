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
	var game=load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/grill_dance_fixture.gd"));root.add_child(game);game.playing=true;game.customers=[guest]
	for i in 2:
		game._register_grill_dance_tap(Vector3.ONE,0.0)
		assert(life.dance_left==0.0,"First two taps must not start dancing")
		assert(guest._anim_player.current_animation=="burger/Phone_One_Hand")
	game._register_grill_dance_tap(Vector3.ONE,0.0)
	assert(guest._anim_player.current_animation=="kenney_hiphop/HipHop","Third tap must start a full-body dance")
	for i in 120:
		guest._wait_motion_time=11.2
		guest._play_wait_stance()
		assert(guest._anim_player.current_animation=="kenney_hiphop/HipHop","Wait/phone scheduler cannot replace the hip-hop dance")
	life.dance_left=0
	guest._play_wait_stance()
	assert(guest._anim_player.current_animation.begins_with("burger/Phone_") or guest._anim_player.current_animation=="burger/Check_Watch","Normal idle scheduling must resume")
	life._last_grill_dance_tap_ms=Time.get_ticks_msec()-1600
	game._register_grill_dance_tap(Vector3.ONE,0.0)
	assert(life.dance_left==0.0 and life._grill_dance_taps==1,"Quiet pause must reset the tap count")
	for i in 3: game._register_grill_dance_tap(Vector3(-1,1,1),0.0)
	assert(life.dance_left==0.0 and life._grill_dance_taps==1,"HOLD taps must not count toward the piano dance")
	for i in 2: game._register_grill_dance_tap(Vector3.ONE,0.0)
	assert(life.dance_left>0.0,"A fresh three-tap sequence must restart dancing")
	life.dance_left=0
	life._grill_dance_tap_times.clear(); life._last_grill_dance_tap_ms = -10000
	assert(not life.register_grill_dance_tap(1000))
	assert(not life.register_grill_dance_tap(2000))
	assert(not life.register_grill_dance_tap(3000), "Three taps spread over two seconds cannot trigger a dance")
	assert(life.register_grill_dance_tap(3400), "A rolling window accepts three taps in 1.4 seconds")
	assert(not life.register_grill_dance_tap(5000), "A fresh burst must restart after a pause")
	guest.is_leaving=true;life.start_grill_dance();assert(life.dance_left==0,"Leaving must retain priority")
	print("GRILL_DANCE_PRIORITY_OK")
	game.queue_free();guest.queue_free();await process_frame;quit()
