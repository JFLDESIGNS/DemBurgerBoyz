extends Node3D
## Visual-only miniature: no cooking scripts, interaction areas, or shared material edits.
var game: Node
var destination: Node3D
var elapsed := 0.0
var origin := Vector3.ZERO
var launched := false
var visual: Node3D

func setup(owner_game: Node, target: Node3D) -> void:
	game = owner_game
	destination = target
	visual = Node3D.new()
	add_child(visual)
	_copy_visuals(target, visual, true)
	hide()

func _copy_visuals(source: Node, parent: Node3D, is_root: bool = false) -> void:
	if not is_root and source is Node3D and not source.visible: return
	var copy: Node3D
	if source is MeshInstance3D:
		var mesh_copy := MeshInstance3D.new()
		mesh_copy.mesh = source.mesh
		mesh_copy.material_override = source.material_override
		mesh_copy.cast_shadow = source.cast_shadow
		for surface in source.get_surface_override_material_count():
			mesh_copy.set_surface_override_material(surface, source.get_surface_override_material(surface))
		copy = mesh_copy
	else:
		copy = Node3D.new()
	parent.add_child(copy)
	if source is Node3D and not is_root: copy.transform = source.transform
	for child in source.get_children():
		if child is Node3D: _copy_visuals(child, copy)

func advance(delta: float) -> bool:
	elapsed += delta
	if not is_instance_valid(destination): return true
	if elapsed < 2.4: return false
	if not launched:
		launched = true
		origin = game.mail_delivery_truck.delivery_origin_global() if is_instance_valid(game.mail_delivery_truck) else Vector3(1.38, 1.1, 1.76)
		show()
	var u := clampf((elapsed - 2.4) / 1.45, 0.0, 1.0)
	var ease := smoothstep(0.0, 1.0, u)
	global_transform = destination.global_transform
	global_position = origin.lerp(destination.global_position, ease) + Vector3(0, sin(u * PI) * 0.85, 0)
	visual.scale = Vector3.ONE * lerpf(0.12, 1.0, ease)
	visual.rotation = Vector3(sin(u * TAU) * 0.14, (1.0-ease) * PI * 0.45, sin(u * PI) * 0.16)
	if u < 1.0: return false
	var settle := clampf((elapsed - 3.85) / 0.42, 0.0, 1.0)
	global_position.y += sin(settle * PI) * 0.09 * (1.0-settle)
	visual.scale = Vector3(1.0 + sin(settle*TAU)*0.025, 1.0-sin(settle*TAU)*0.045, 1.0+sin(settle*TAU)*0.025)
	return settle >= 1.0
