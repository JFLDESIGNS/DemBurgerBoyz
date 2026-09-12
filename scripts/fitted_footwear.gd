extends RefCounted
## Authored pairs share the original foot/toe/ankle skin binds.
const CATALOG_VERSION := 1
const LABELS := ["None", "Court classic", "Timber work boots", "Arcade high tops", "Penny loafers", "Trail sandals", "Neon runners", "Sunset skate shoes", "Violet retro trainers", "Midnight Chelsea boots", "Alpine hiking boots", "Kitchen clogs", "Seafoam slides", "Rose Mary Janes", "Orchid ankle boots", "Froggy slippers"]
const CATEGORIES := ["none", "universal", "universal", "universal", "universal", "special", "universal", "universal", "universal", "universal", "universal", "universal", "special", "special", "special", "special"]
const SCENES: Array[PackedScene] = [
	null,
	preload("res://assets/shoes/glb/01_Court_Classic.glb"),
	preload("res://assets/shoes/glb/02_Timber_Boots.glb"),
	preload("res://assets/shoes/glb/03_Arcade_High_Tops.glb"),
	preload("res://assets/shoes/glb/04_Penny_Loafers.glb"),
	preload("res://assets/shoes/glb/05_Trail_Sandals.glb"),
	preload("res://assets/shoes/glb/06_Neon_Runners.glb"),
	preload("res://assets/shoes/glb/07_Sunset_Skate.glb"),
	preload("res://assets/shoes/glb/08_Violet_Retro.glb"),
	preload("res://assets/shoes/glb/09_Chelsea_Boots.glb"),
	preload("res://assets/shoes/glb/10_Alpine_Hikers.glb"),
	preload("res://assets/shoes/glb/11_Kitchen_Clogs.glb"),
	preload("res://assets/shoes/glb/12_Seafoam_Slides.glb"),
	preload("res://assets/shoes/glb/13_Rose_Mary_Janes.glb"),
	preload("res://assets/shoes/glb/14_Orchid_Ankle_Boots.glb"),
	preload("res://assets/shoes/glb/15_Froggy_Slippers.glb"),
]
static var _mesh_cache: Dictionary = {}

static func migrate_preset(data: Dictionary) -> void:
	# IDs 0-5 preserve the retired procedural shoe categories.
	if int(data.get("shoe_catalog_version", 0)) < CATALOG_VERSION:
		data["shoe_color"] = "ffffffff"
		data["shoe_scale"] = 1.0
	data["shoe_style"] = clampi(int(data.get("shoe_style", 0)), 0, SCENES.size() - 1)
	data["shoe_scale"] = clampf(float(data.get("shoe_scale", 1.0)), 0.9, 1.2)
	data["shoe_catalog_version"] = CATALOG_VERSION

static func _relative_transform(node: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent() as Node3D
	while parent != null:
		result = parent.transform * result
		parent = parent.get_parent() as Node3D
	return result

static func fitted_mesh(style: int, body_mesh: MeshInstance3D, body_root: Node3D, fit: float) -> ArrayMesh:
	var catalog := SCENES
	var labels := LABELS
	if style <= 0 or style >= catalog.size():
		return null
	fit = snappedf(clampf(fit, 0.9, 1.2), 0.01)
	var cache_key := "%s|%s|%d|%.2f" % [body_mesh.mesh.get_instance_id(), "shoes", style, fit]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key] as ArrayMesh
	var imported := catalog[style].instantiate()
	var meshes := imported.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() != 1:
		push_error("Expected one authored shoe pair: " + labels[style])
		imported.free()
		return null
	var source := meshes[0] as MeshInstance3D
	var target_binds := {}
	for index in body_mesh.skin.get_bind_count():
		target_binds[String(body_mesh.skin.get_bind_name(index))] = index
	var bind_map := PackedInt32Array()
	for index in source.skin.get_bind_count():
		bind_map.append(int(target_binds.get(String(source.skin.get_bind_name(index)), -1)))
	# The FBX stores Z-up vertices at 1/100 scale; GLB stores meter-sized Y-up
	# vertices. Derive the conversion from the actual scene transforms.
	var conversion := body_mesh.global_transform.affine_inverse() * body_root.global_transform * _relative_transform(source)
	var normal_basis := conversion.basis.inverse().transposed()
	var result := ArrayMesh.new()
	for surface in source.mesh.get_surface_count():
		var arrays := source.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for index in vertices.size():
			normals[index] = (normal_basis * normals[index]).normalized()
			# Adjust clearance locally without moving the shoes away from their joints.
			vertices[index] = conversion * vertices[index] + normals[index] * (fit - 1.0) * 0.001
		for index in bones.size():
			var mapped := bind_map[bones[index]]
			if mapped < 0 and weights[index] > 0.00001:
				push_error("Missing customer bind for " + labels[style])
				imported.free()
				return null
			bones[index] = maxi(mapped, 0)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_TANGENT] = null
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(surface, source.mesh.surface_get_material(surface))
	imported.free()
	_mesh_cache[cache_key] = result
	return result

static func shoe_material(authored: Material, tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	if authored is StandardMaterial3D:
		material = authored.duplicate() as StandardMaterial3D
	var source := material.albedo_color
	var value := source.r*0.2126+source.g*0.7152+source.b*0.0722
	material.albedo_color = Color(value,value,value,source.a)*tint
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_TOON
	material.roughness = 0.8
	return material
