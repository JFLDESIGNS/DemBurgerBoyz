extends Node3D

var game: Node
var door: Node3D
var open_amount := 0.0
var linger := 0.0
var model: Node3D

func setup(owner_game: Node, bun_scale: float) -> void:
	game=owner_game
	var gltf:=GLTFDocument.new();var state:=GLTFState.new()
	if gltf.append_from_file("res://models/bread_box/bread_box.glb",state)!=OK: return
	model=gltf.generate_scene(state)
	add_child(model)
	model.scale=Vector3.ONE*1.3*bun_scale
	model.rotation.y=PI
	door=model.find_child("BreadDoorPivot",true,false) as Node3D
	# A lightly tinted pane stays readable without hiding the inventory behind it.
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var original=mesh.get_active_material(i)
			if original is StandardMaterial3D and "glass" in original.resource_name.to_lower():
				var mat:StandardMaterial3D=original.duplicate()
				mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color=Color(.78,.91,.96,.10)
				mat.cull_mode=BaseMaterial3D.CULL_DISABLED
				mat.roughness=.12
				mesh.set_surface_override_material(i,mat)
				mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func overlaps_door(pointer:Vector2) -> bool:
	if not is_instance_valid(model) or not is_instance_valid(game.camera):return false
	# Exact closed-door face, including glass; no sign, roof, sides or hover padding.
	# Keep this footprint stable as the door swings so buns remain accessible.
	var polygon:=PackedVector2Array()
	for corner in [Vector3(-.262,.0745,.216),Vector3(.262,.0745,.216),Vector3(.262,.3315,.216),Vector3(-.262,.3315,.216)]:
		var world_point:Vector3=model.to_global(corner)
		if game.camera.is_position_behind(world_point):return false
		polygon.append(game.camera.unproject_position(world_point))
	return Geometry2D.is_point_in_polygon(pointer,polygon)

func _process(delta:float) -> void:
	if not is_instance_valid(door) or not is_instance_valid(game):return
	var active:bool=game.playing and not game.options_menu_open and not game.shift_paused and is_visible_in_tree()
	var pointer:Vector2=game._gui_to_camera_screen(get_viewport().get_mouse_position())
	if active and overlaps_door(pointer):linger=.65
	else:linger=maxf(0,linger-delta)
	set_open(linger>0,delta)

func set_open(wanted:bool,delta:float) -> void:
	open_amount=move_toward(open_amount,1.0 if wanted else 0.0,delta*3.4)
	if is_instance_valid(door):door.rotation.y=-deg_to_rad(105)*smoothstep(0,1,open_amount)
