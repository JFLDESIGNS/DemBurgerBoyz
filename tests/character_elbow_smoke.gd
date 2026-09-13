extends SceneTree
const Motion = preload("res://scripts/burger_animation_library.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var model := (load("res://assets/characters/Model/characterMedium.fbx") as PackedScene).instantiate()
	root.add_child(model)
	var skeleton := model.find_child("Skeleton3D",true,false) as Skeleton3D
	var player := AnimationPlayer.new()
	model.add_child(player)
	Motion.attach(player,model)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var bad: Array[String] = []
	var tested := 0
	for clip in Motion.NAMES:
		player.play("burger/"+clip)
		var length := Motion.LIBRARY.get_animation(clip).length
		for f in range(int(round(length*30))+1):
			player.seek(minf(f/30.0,length),true)
			skeleton.force_update_all_bone_transforms()
			var center := skeleton.get_bone_global_pose(skeleton.find_bone("UpperChest")).origin.x
			for side in ["Left","Right"]:
				var sign_x := 1.0 if side == "Left" else -1.0
				var shoulder := skeleton.get_bone_global_pose(skeleton.find_bone(side+"Arm")).origin.x
				var elbow := skeleton.get_bone_global_pose(skeleton.find_bone(side+"ForeArm")).origin.x
				var ratio := (elbow-center)*sign_x/maxf(0.0001,(shoulder-center)*sign_x)
				if ratio < 0.60: bad.append("%s frame %d %s elbow folds into torso: %.3f" % [clip,f,side,ratio])
			tested += 1
	model.free()
	if bad.is_empty(): print("ELBOW_RUNTIME_OK ",tested," frames across 27 clips")
	else:
		for message in bad.slice(0,10): push_error(message)
	quit(0 if bad.is_empty() else 1)
