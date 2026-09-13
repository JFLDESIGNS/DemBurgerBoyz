extends SceneTree
const Customer = preload("res://scripts/customer.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for custom in [false,true]:
		var c := Customer.new()
		c.setup(["bun_bottom","patty","bun_top"],Color.WHITE,45,0,0,0,-1,{"format_version":8,"body_type":"kenney_chunky_toon","name":"Probe","hair_style":3,"lash_style":1} if custom else {},true)
		root.add_child(c)
		c.set_process(false)
		var p: AnimationPlayer=c.get("_anim_player")
		var sk := c.find_child("Skeleton3D",true,false) as Skeleton3D
		p.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for lib in p.get_animation_library_list():
			for n in p.get_animation_library(lib).get_animation_list():
				if lib=="burger":continue
				var a:=p.get_animation(String(lib)+"/"+n)
				print("LIB ",custom," ",lib,"/",n," ",a.length," tracks=",a.get_track_count()," first=",a.track_get_path(0))
		for state in ["idle","walk","burger:Phone_One_Hand","idle","button","idle","offensive","walk"]:
			c.call("_play_anim",state);p.advance(.3)
			var a:=sk.get_bone_pose_rotation(sk.find_bone("LeftArm"));var b:=sk.get_bone_rest(sk.find_bone("LeftArm")).basis.get_rotation_quaternion()
			print("STATE ",custom," ",state," -> ",p.current_animation," active=",p.active," arm_angle=",a.angle_to(b))
		c.free()
	quit()
