extends SceneTree
const Customer = preload("res://scripts/customer.gd")
const Motion = preload("res://scripts/burger_animation_library.gd")
const Timing = preload("res://scripts/burger_serve_timing.gd")
var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:call_deferred("run")

func run() -> void:
	# Load with autoloads registered; --check-only cannot resolve NetManager.
	var game_script := load("res://scripts/game.gd") as GDScript
	expect(game_script != null and game_script.can_instantiate(),"Gameplay script does not compile")
	expect(Motion.LIBRARY.get_animation_list().size() == 27,"All 27 clips must be available")
	for name in Motion.NAMES:
		var clip := Motion.LIBRARY.get_animation(name)
		expect(clip != null,"Missing " + name)
		if clip == null:continue
		for track in clip.get_track_count():
			if str(clip.track_get_path(track)).ends_with(":HipsCtrl") and clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
				var start: Vector3 = clip.track_get_key_value(track,0)
				for key in clip.track_get_key_count(track):
					var pos: Vector3 = clip.track_get_key_value(track,key)
					expect(Vector2(pos.x-start.x,pos.y-start.y).length()<.00001,"Root drift in " + name)
	for custom in [false,true]:
		var c := Customer.new()
		var preset := {"format_version":8,"name":"Burger Motion Test","body_type":"kenney_chunky_toon","skin_color":"cf895fff","top_style":1} if custom else {}
		c.setup(["bun_bottom","patty","bun_top"],Color.WHITE,45.0,0,0,0,-1,preset,true)
		root.add_child(c)
		c.set_process(false)
		c.is_waiting = true
		c.position = Vector3(c.target_x,Customer.STAND_Y,Customer.WAIT_Z)
		var player: AnimationPlayer = c.get("_anim_player")
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var walk: String = c.get("_walk_anim_path")
		c.call("_play_anim","walk")
		expect(player.current_animation == walk,"Normal walk was replaced")
		c.begin_catch_burger(true)
		player.advance(.85)
		expect(player.current_animation == "burger/Take_Burger_Fast","Grab must use fast authored clip")
		var grip := c.burger_grip_global()
		var skeleton := c.find_child("Skeleton3D",true,false) as Skeleton3D
		var wrist := skeleton.get_bone_pose_rotation(skeleton.find_bone("RightHand"))
		c.call("_update_eat_pose")
		expect(wrist.is_equal_approx(skeleton.get_bone_pose_rotation(skeleton.find_bone("RightHand"))),"Procedural eating pose overrode grab")
		player.advance(.70)
		expect(grip.distance_to(c.burger_grip_global())>.005,"Grip does not follow the moving hands")
		c.start_eating_burger()
		player.advance(.60)
		expect(player.current_animation == "burger/Eat_Burger_Fast","Grab must transition to fast eating")
		var clock := player.current_animation_position
		c.chomp_burger()
		expect(is_equal_approx(clock,player.current_animation_position),"Bite restarted the eat animation")
		expect(not (c.get("_burger_props") as Node3D).visible,"Game must not show a second burger prop")
		c.finish_catch_burger()
		c.leave_mad()
		c.call("_update_sidewalk_leave",3.3)
		c.call("_update_sidewalk_leave",.5)
		c.call("_update_sidewalk_leave",.1)
		expect(player.current_animation == "burger/Walk_Away_Angry","Angry departure must use the new angry walk")
		expect(c.get("_walk_anim_path") == walk,"Angry departure changed normal walk selection")
		c.free()
		await process_frame
	var pedestrian := Customer.new()
	pedestrian.is_street_pedestrian = true
	pedestrian.setup(["bun_bottom","patty","bun_top"],Color.WHITE,45.0,0,0,0,-1,{"format_version":8,"name":"Runner","body_type":"kenney_chunky_toon","skin_color":"cf895fff"},true)
	root.add_child(pedestrian)
	pedestrian.play_street_run()
	var runner: AnimationPlayer = pedestrian.get("_anim_player")
	expect(runner.current_animation == "kenney_running/Run","Existing street run was replaced")
	pedestrian.free()
	var doll := (load("res://scenes/character_creator/modular_character_base.tscn") as PackedScene).instantiate()
	root.add_child(doll)
	doll.set_process(false)
	for i in Motion.NAMES.size():
		doll.start_preview_animation(i+3)
		doll.call("_process",.4)
		var player: AnimationPlayer = doll.get("_native_preview_player")
		expect(player.current_animation == "burger/"+Motion.NAMES[i],"Editor cannot preview " + Motion.NAMES[i])
	doll.stop_preview_animation()
	expect(not doll.is_preview_animation_playing(),"Editor stop failed")
	expect(not (doll.get("_native_preview_props") as Node3D).visible,"Editor props survived stop")
	doll.start_preview_animation(3+Motion.NAMES.find("Phone_One_Hand"))
	doll.set_pose_control("head_yaw",12.0)
	expect(not (doll.get("_native_preview_player") as AnimationPlayer).is_playing(),"Manual editing did not stop native preview")
	doll.free()
	var timing := Timing.plan(1.6,2.2,.85)
	expect(is_equal_approx(timing.catch_hold,.75),"Catch hold does not finish the grab")
	expect(is_equal_approx(timing.lift_to_bite,.594),"Bite is not aligned to the authored lift")
	expect(is_equal_approx(.85+timing.catch_hold+timing.lift_to_bite+timing.bite_to_finish,3.8),"Eating does not complete before release")
	if failures.is_empty():print("BURGER27_INTEGRATION_SMOKE_OK")
	quit(0 if failures.is_empty() else 1)
