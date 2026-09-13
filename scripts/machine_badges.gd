extends RefCounted
## Generated artwork mounted in each model's authored coordinates.

const ART := "res://assets/machine_decals/"


static func decal(parent: Node3D, label: String, file: String, size: Vector2, pos: Vector3, rotation: Vector3 = Vector3.ZERO, tint: Color = Color.WHITE) -> MeshInstance3D:
	var existing := parent.get_node_or_null(NodePath(label)) as MeshInstance3D
	if existing != null:
		return existing
	var texture := load(ART + file) as Texture2D
	if texture == null:
		return null
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var quad := QuadMesh.new()
	quad.size = size
	mesh.mesh = quad
	mesh.position = pos
	mesh.rotation_degrees = rotation
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mat.no_depth_test = false
	mat.albedo_color = tint
	mat.roughness = 0.65
	mat.metallic = 0.08
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh


static func soda(visual: Node3D) -> void:
	for fid in ["cola", "ice"]:
		var pad := visual.find_child("FlavorChip_%s" % fid, true, false) as MeshInstance3D
		if pad == null:
			continue
		var bounds := pad.get_aabb()
		var size := minf(bounds.size.x, bounds.size.y)
		var pos := bounds.get_center()
		pos.z = bounds.position.z - 0.0015
		var file := "ice_chip_v2.png" if fid == "ice" else "soda_chip_v2.png"
		var graphic := decal(pad, "FlavorGraphic_%s" % fid, file, Vector2.ONE * size, pos, Vector3(0, 180, 0))
		if graphic != null:
			for old in visual.find_children("FlavorLettering_%s_*" % fid, "MeshInstance3D", true, false):
				old.set_meta("replaced_by_generated_badge", true)
				old.hide()
	decal(visual, "SodaMakerBadge", "burger_pals_metal_badge.png", Vector2(0.22, 0.073), Vector3(0, 0.54, -0.22), Vector3(0, 180, 0))


static func soft_serve(visual: Node3D) -> void:
	decal(visual, "SoftServeMakerBadge", "burger_pals_metal_badge.png", Vector2(0.125, 0.0417), Vector3(0, 0.302, 0.219))
	decal(visual, "SoftServeSideLeft", "soft_serve_side_v2.png", Vector2(0.18, 0.27), Vector3(-0.111, 0.32, 0.015), Vector3(0, -90, 0))
	# The right cabinet has cooling louvers; the smaller emblem sits above them.
	decal(visual, "SoftServeSideRight", "soft_serve_side_v2.png", Vector2(0.10, 0.15), Vector3(0.111, 0.413, 0.015), Vector3(0, 90, 0))


static func grill(visual: Node3D) -> void:
	# The imported scene wraps an authored root with a 180-degree rotation.
	var authored := visual.find_child("StylizedGrill", true, false) as Node3D
	if authored == null:
		authored = visual
	## Smaller / darker plaques so they sit into the steel instead of reading as stickers.
	var plaque := Color(0.68, 0.68, 0.68)
	decal(authored, "GrillSplashBadge", "grill_badge_v1.png", Vector2(0.205, 0.068), Vector3(0, 0.076, -0.464), Vector3.ZERO, plaque)
	var front := visual.find_child("ControlPanelMount", true, false) as Node3D
	if front != null:
		decal(front, "GrillFrontBadge", "grill_badge_v1.png", Vector2(0.108, 0.036), Vector3(-0.77, 0.011, 0), Vector3(-90, 0, 0), plaque)

