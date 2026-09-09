extends SceneTree


func _initialize() -> void:
	call_deferred("_run_probe")


func _bounds(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null:
			continue
		var world_box := mesh.global_transform * mesh.get_aabb()
		if first:
			result = world_box
			first = false
		else:
			result = result.merge(world_box)
	return result


func _run_probe() -> void:
	var idle := (load("res://assets/characters/Animations/idle.fbx") as PackedScene).instantiate()
	var player := idle.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		for animation_name in player.get_animation_list():
			var animation := player.get_animation(animation_name)
			for track_index in animation.get_track_count():
				var path_string := str(animation.track_get_path(track_index))
				if path_string.contains("scale") or path_string.begins_with("."):
					print("IDLE_TRACK=", path_string)
	var normal := (load("res://assets/characters/Model/characterMedium.fbx") as PackedScene).instantiate()
	var modular := (load("res://scenes/character_creator/modular_character_base.tscn") as PackedScene).instantiate()
	modular.apply_saved_preset({"hair_style": 4, "top_style": 1, "bottom_style": 2, "shoe_style": 1})
	root.add_child(normal)
	root.add_child(modular)
	await process_frame
	print("NORMAL_BOUNDS=", _bounds(normal))
	print("MODULAR_BOUNDS=", _bounds(modular))
	print("BODY_SCALE=", modular.get_node("Body").scale)
	quit(0)
