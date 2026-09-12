extends SceneTree


func _initialize() -> void:
	print("SkeletonIK3D exists=", ClassDB.class_exists("SkeletonIK3D"))
	if ClassDB.class_exists("SkeletonIK3D"):
		var ik = ClassDB.instantiate("SkeletonIK3D")
		for property in ik.get_property_list():
			if str(property.name) in ["root_bone", "tip_bone", "target", "target_node", "override_tip_basis", "use_magnet", "magnet", "interpolation", "max_iterations", "min_distance"]:
				print("PROP ", property.name, " type=", property.type)
		for method in ik.get_method_list():
			if str(method.name) in ["start", "stop", "is_running"]:
				print("METHOD ", method.name)
	quit()
