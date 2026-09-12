extends SceneTree


func _initialize() -> void:
	call_deferred("_inspect")


func _inspect() -> void:
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	var character := scene.get_node("World/Character") as ModularCharacterBase
	await process_frame
	var skeleton := character.get_active_skeleton()
	for bone_name in ["Hips", "Spine", "Chest", "Head", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]:
		var index := skeleton.find_bone(bone_name)
		if index < 0:
			print("MISSING ", bone_name)
			continue
		var rest := skeleton.get_bone_global_rest(index)
		var parent := skeleton.get_bone_parent(index)
		print(bone_name, " idx=", index, " parent=", skeleton.get_bone_name(parent) if parent >= 0 else "none", " origin=", rest.origin, " axes X=", rest.basis.x, " Y=", rest.basis.y, " Z=", rest.basis.z)
	quit()
