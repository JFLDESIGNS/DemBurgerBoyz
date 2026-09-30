extends SceneTree

func _matrix(rows: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(rows[0][0],rows[1][0],rows[2][0]),Vector3(rows[0][1],rows[1][1],rows[2][1]),Vector3(rows[0][2],rows[1][2],rows[2][2])),Vector3(rows[0][3],rows[1][3],rows[2][3]))

func _initialize() -> void:
	var motion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/character_animation/courier/grab_motion.json"))
	var model := (load("res://assets/characters/Model/characterMedium.fbx") as PackedScene).instantiate()
	var skeleton := model.find_child("Skeleton3D",true,false) as Skeleton3D
	var unit := skeleton.get_bone_global_rest(skeleton.find_bone("Head")).origin.z / _matrix(motion.rest.Head).origin.z
	var skeleton_path := str(model.get_path_to(skeleton))
	var rest_inv := {}
	for i in skeleton.get_bone_count():
		var bone := skeleton.get_bone_name(i)
		rest_inv[bone] = _matrix(motion.rest[bone]).affine_inverse()
	var library := AnimationLibrary.new()
	for clip in motion.clips:
		var anim := Animation.new()
		anim.resource_name = clip.name
		anim.length = clip.length
		anim.step = 1.0 / motion.fps
		anim.loop_mode = Animation.LOOP_LINEAR if clip.loop else Animation.LOOP_NONE
		var tracks := {}
		var previous := {}
		for i in skeleton.get_bone_count():
			var bone := skeleton.get_bone_name(i)
			var indices: Array[int] = []
			for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:
				var track := anim.add_track(type)
				anim.track_set_path(track,NodePath(skeleton_path+":"+bone))
				indices.append(track)
			tracks[bone] = indices
		var pt: Array[int] = []
		for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D]:
			var track := anim.add_track(type)
			anim.track_set_path(track,NodePath(skeleton_path+"/BurgerMotionProps"))
			pt.append(track)
		for kind in ["burger","phone","hat","watch","card","napkin"]:
			var track := anim.add_track(Animation.TYPE_VALUE)
			anim.track_set_path(track,NodePath(skeleton_path+"/BurgerMotionProps/"+kind+":visible"))
			anim.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
			anim.track_insert_key(track,0.0,clip.prop == kind)
		for frame in clip.frames:
			var poses: Array[Transform3D] = []
			for i in skeleton.get_bone_count():
				var bone := skeleton.get_bone_name(i)
				var deformation: Transform3D = _matrix(frame.bones[bone]) * rest_inv[bone]
				deformation.origin *= unit
				poses.append(deformation * skeleton.get_bone_global_rest(i))
			for i in skeleton.get_bone_count():
				var bone := skeleton.get_bone_name(i)
				var pose := poses[i]
				var parent := skeleton.get_bone_parent(i)
				if parent >= 0:pose = poses[parent].affine_inverse() * pose
				var rot := pose.basis.get_rotation_quaternion().normalized()
				if previous.has(bone) and rot.dot(previous[bone]) < 0:rot = -rot
				previous[bone] = rot
				anim.position_track_insert_key(tracks[bone][0],frame.time,pose.origin)
				anim.rotation_track_insert_key(tracks[bone][1],frame.time,rot)
				anim.scale_track_insert_key(tracks[bone][2],frame.time,pose.basis.get_scale())
			var prop_pose := _matrix(frame.prop) if frame.has("prop") else Transform3D.IDENTITY
			anim.position_track_insert_key(pt[0],frame.time,prop_pose.origin * unit)
			anim.rotation_track_insert_key(pt[1],frame.time,prop_pose.basis.get_rotation_quaternion())
		for track in range(anim.get_track_count()-1,-1,-1):
			if "BurgerMotionProps" in str(anim.track_get_path(track)): anim.remove_track(track)
		library.add_animation(clip.name,anim)
		print("BAKED ",clip.name," ",anim.length)
	assert(ResourceSaver.save(library,"res://assets/characters/Animations/CourierGrab.res",ResourceSaver.FLAG_COMPRESS)==OK)
	model.free()
	print("COURIER_GRAB_LIBRARY_READY")
	quit()
