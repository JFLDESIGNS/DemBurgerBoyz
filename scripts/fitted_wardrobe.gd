extends RefCounted
## Converts authored garments into the customer's existing mesh/bind space.
## No additional Skeleton3D is retained on the character.

const CATALOG_VERSION := 1
const LABELS := ["None", "Midnight pink lapel", "Sunshine bowling shirt", "Lagoon contrast collar", "Club varsity", "Seafoam ringer T-shirt", "Ochre striped shirt", "Emerald gold cardigan", "Terracotta polo", "Ivory oxford", "Merlot henley", "Athletic tank top", "Orchid cropped halter"]
const SCENES: Array[PackedScene] = [
	null,
	preload("res://assets/shirts/glb/01_Midnight_Lapel.glb"),
	preload("res://assets/shirts/glb/02_Sunshine_Bowling.glb"),
	preload("res://assets/shirts/glb/03_Lagoon_Collar.glb"),
	preload("res://assets/shirts/glb/04_Club_Varsity.glb"),
	preload("res://assets/shirts/glb/05_Seafoam_Ringer.glb"),
	preload("res://assets/shirts/glb/06_Ochre_Stripe.glb"),
	preload("res://assets/shirts/glb/07_Emerald_Cardigan.glb"),
	preload("res://assets/shirts/glb/08_Terracotta_Polo.glb"),
	preload("res://assets/shirts/glb/09_Ivory_Oxford.glb"),
	preload("res://assets/shirts/glb/10_Merlot_Henley.glb"),
	preload("res://assets/shirts/glb/11_Athletic_Tank.glb"),
	preload("res://assets/shirts/glb/12_Orchid_Halter.glb"),
]
const BOTTOM_CATALOG_VERSION := 1
const BOTTOM_LABELS := ["None", "Timber cargo trousers", "Emerald belted chinos", "Slate utility trousers", "Azure cuffed joggers", "Coast pocket jeans", "Plum ankle leggings", "Midnight stripe track pants", "Sand cargo shorts", "Lagoon belted bermudas", "Coral running shorts", "Emerald shorts over leggings", "Olive cuffed capris", "Indigo button A-line skirt", "Orchid pleated skirt", "Saffron pocket midi skirt"]
const BOTTOM_SCENES: Array[PackedScene] = [
	null,
	preload("res://assets/bottoms/glb/01_Timber_Cargo.glb"),
	preload("res://assets/bottoms/glb/02_Emerald_Chinos.glb"),
	preload("res://assets/bottoms/glb/03_Slate_Utility.glb"),
	preload("res://assets/bottoms/glb/04_Azure_Joggers.glb"),
	preload("res://assets/bottoms/glb/05_Coast_Jeans.glb"),
	preload("res://assets/bottoms/glb/06_Plum_Leggings.glb"),
	preload("res://assets/bottoms/glb/07_Midnight_Track.glb"),
	preload("res://assets/bottoms/glb/08_Sand_Cargo_Shorts.glb"),
	preload("res://assets/bottoms/glb/09_Lagoon_Bermudas.glb"),
	preload("res://assets/bottoms/glb/10_Coral_Running.glb"),
	preload("res://assets/bottoms/glb/11_Sport_Layers.glb"),
	preload("res://assets/bottoms/glb/12_Olive_Capris.glb"),
	preload("res://assets/bottoms/glb/13_Indigo_A_Line.glb"),
	preload("res://assets/bottoms/glb/14_Orchid_Pleats.glb"),
	preload("res://assets/bottoms/glb/15_Saffron_Midi.glb"),
]
const PRINT_SHADER := preload("res://shaders/fitted_shirt.gdshader")
static var _mesh_cache: Dictionary = {}

static func migrate_preset(data: Dictionary) -> void:
	if int(data.get("top_catalog_version", 0)) < CATALOG_VERSION:
		var replacements := [5, 5, 11, 3, 12, 9, 8, 4, 3, 11, 12, 7]
		data["top_style"] = replacements[clampi(int(data.get("top_style", 1)), 0, 11)]
		data["top_color"] = "ffffffff"
		data["top_scale"] = 1.0
		data["shirt_graphic_depth"] = 0.0
	data["top_style"] = clampi(int(data.get("top_style", 5)), 0, SCENES.size() - 1)
	data["top_catalog_version"] = CATALOG_VERSION
	if int(data.get("bottom_catalog_version", 0)) < BOTTOM_CATALOG_VERSION:
		var old_bottom := clampi(int(data.get("bottom_style", 2)), 0, 7)
		if not data.has("bottom_style") and int(data.get("format_version", 1)) < 3:
			var clothing := int(data.get("clothing_style", 0))
			if int(data.get("format_version", 1)) < 2 and clothing > 0:
				clothing += 3
			old_bottom = 1 if clothing == 2 or clothing == 3 else 2
		var replacements := [8, 2, 8, 12, 6, 13, 15, 14]
		data["bottom_style"] = replacements[old_bottom]
		data["bottom_color"] = "ffffffff"
		data["bottom_scale"] = 1.0
	data["bottom_style"] = clampi(int(data.get("bottom_style", 8)), 0, BOTTOM_SCENES.size() - 1)
	data["bottom_catalog_version"] = BOTTOM_CATALOG_VERSION

static func _relative_transform(node: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent() as Node3D
	while parent != null:
		result = parent.transform * result
		parent = parent.get_parent() as Node3D
	return result

static func fitted_mesh(style: int, body_mesh: MeshInstance3D, body_root: Node3D, fit: float, bottom: bool = false) -> ArrayMesh:
	var catalog := BOTTOM_SCENES if bottom else SCENES
	var labels := BOTTOM_LABELS if bottom else LABELS
	if style <= 0 or style >= catalog.size():
		return null
	fit = snappedf(clampf(fit, 0.9, 1.12), 0.01)
	var cache_key := "%s|%s|%d|%.2f" % [body_mesh.mesh.get_instance_id(), "bottom" if bottom else "top", style, fit]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key] as ArrayMesh
	var imported := catalog[style].instantiate()
	var meshes := imported.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() != 1:
		push_error("Expected one authored garment mesh: " + labels[style])
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
		var print_coordinates := PackedVector2Array()
		var print_mask := PackedColorArray()
		for index in vertices.size():
			normals[index] = (normal_basis * normals[index]).normalized()
			# Fit adjusts fabric clearance rather than scaling sleeves away from
			# their joints or moving the neckline vertically.
			vertices[index] = conversion * vertices[index] + normals[index] * (fit - 1.0) * 0.0015
			print_coordinates.append(Vector2(vertices[index].x, vertices[index].z))
			var front := normals[index].y < -0.25 and vertices[index].y < 0.0
			print_mask.append(Color(1.0, 1.0, 1.0, 1.0 if front else 0.0))
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
		arrays[Mesh.ARRAY_TEX_UV2] = print_coordinates
		arrays[Mesh.ARRAY_COLOR] = print_mask
		arrays[Mesh.ARRAY_TANGENT] = null
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(surface, source.mesh.surface_get_material(surface))
	imported.free()
	_mesh_cache[cache_key] = result
	return result

static func fabric_material(authored: Material, tint: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PRINT_SHADER
	var color := Color.WHITE
	if authored is BaseMaterial3D:
		color = (authored as BaseMaterial3D).albedo_color
	material.set_shader_parameter("fabric_color", color)
	material.set_shader_parameter("fabric_tint", tint)
	return material

static func update_print(garment: MeshInstance3D, texture: Texture2D, color: Color, print_scale: float, horizontal: float, vertical: float, cropped: bool) -> void:
	var center := Vector2(horizontal, (2.235 if cropped else 2.16) + vertical) * 0.01
	var size := (0.20 if cropped else 0.26) * print_scale * 0.01
	for surface in garment.mesh.get_surface_count():
		var material := garment.get_surface_override_material(surface) as ShaderMaterial
		material.set_shader_parameter("graphic_enabled", texture != null)
		material.set_shader_parameter("graphic_texture", texture)
		material.set_shader_parameter("graphic_color", color)
		material.set_shader_parameter("graphic_center", center)
		material.set_shader_parameter("graphic_size", size)
