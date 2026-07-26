## Colored freeform plane drawn with the lasso tool.
extends Node3D

enum MaterialKind {
	FLAT,
	GLOSSY,
	MATTE,
	NEON,
	GLASS,
}

const MATERIAL_LABELS: PackedStringArray = [
	"Flat", "Glossy", "Matte", "Neon", "Glass",
]

signal changed

var shape_name: String = "Shape"
var local_points: PackedVector2Array = PackedVector2Array() ## XZ in local space around centroid
var fill_color: Color = Color(0.95, 0.35, 0.2, 0.85)
var opacity: float = 0.85:
	set(v):
		opacity = clampf(v, 0.0, 1.0)
		_apply_material()
		changed.emit()
var material_kind: int = MaterialKind.FLAT:
	set(v):
		material_kind = clampi(v, 0, MATERIAL_LABELS.size() - 1)
		_apply_material()
		changed.emit()
var z_order: int = 0:
	set(v):
		z_order = v
		_apply_z_order()
		changed.emit()
var selected: bool = false:
	set(v):
		selected = v
		_refresh_outline()

var _mesh_inst: MeshInstance3D
var _outline: MeshInstance3D
var _mat: StandardMaterial3D
var _outline_mat: StandardMaterial3D
var _base_y: float = 0.0


func setup(world_points: PackedVector3Array, y: float, color: Color) -> void:
	_base_y = y
	position = Vector3.ZERO
	fill_color = color
	opacity = color.a
	_compute_local_from_world(world_points)
	_ensure_nodes()
	_rebuild_mesh()
	_apply_material()
	_apply_z_order()
	_refresh_outline()


func set_fill_color(c: Color) -> void:
	fill_color = Color(c.r, c.g, c.b, opacity)
	_apply_material()
	changed.emit()


func get_display_color() -> Color:
	return Color(fill_color.r, fill_color.g, fill_color.b, opacity)


func set_uniform_scale(s: float) -> void:
	s = clampf(s, 0.05, 12.0)
	scale = Vector3(s, 1.0, s)
	changed.emit()


func get_uniform_scale() -> float:
	return scale.x


func set_yaw_degrees(deg: float) -> void:
	rotation_degrees.y = deg
	changed.emit()


func get_yaw_degrees() -> float:
	return rotation_degrees.y


func contains_world_xz(world: Vector3) -> bool:
	if local_points.size() < 3:
		return false
	var local := to_local(world)
	return Geometry2D.is_point_in_polygon(Vector2(local.x, local.z), local_points)


func _compute_local_from_world(world_points: PackedVector3Array) -> void:
	var cx := 0.0
	var cz := 0.0
	for p in world_points:
		cx += p.x
		cz += p.z
	var n := float(world_points.size())
	cx /= n
	cz /= n
	position = Vector3(cx, _base_y, cz)
	local_points = PackedVector2Array()
	for p in world_points:
		local_points.append(Vector2(p.x - cx, p.z - cz))


func _ensure_nodes() -> void:
	if _mesh_inst == null:
		_mesh_inst = MeshInstance3D.new()
		_mesh_inst.name = "Fill"
		_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_mesh_inst)
	if _outline == null:
		_outline = MeshInstance3D.new()
		_outline.name = "Outline"
		_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_outline)
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		_mesh_inst.material_override = _mat
	if _outline_mat == null:
		_outline_mat = StandardMaterial3D.new()
		_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_outline_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_outline_mat.albedo_color = Color(1.0, 0.95, 0.35, 0.95)
		_outline.material_override = _outline_mat


func _rebuild_mesh() -> void:
	_ensure_nodes()
	if local_points.size() < 3:
		_mesh_inst.mesh = null
		_outline.mesh = null
		return
	var tris := Geometry2D.triangulate_polygon(local_points)
	if tris.is_empty():
		## Self-intersecting / bad winding — try convex hull.
		var hull := Geometry2D.convex_hull(local_points)
		if hull.size() < 3:
			_mesh_inst.mesh = null
			_outline.mesh = null
			return
		local_points = hull
		tris = Geometry2D.triangulate_polygon(local_points)
	if tris.is_empty():
		_mesh_inst.mesh = null
		_outline.mesh = null
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := Vector3.UP
	for i in range(0, tris.size(), 3):
		var a: Vector2 = local_points[tris[i]]
		var b: Vector2 = local_points[tris[i + 1]]
		var c: Vector2 = local_points[tris[i + 2]]
		st.set_normal(n)
		st.add_vertex(Vector3(a.x, 0.0, a.y))
		st.set_normal(n)
		st.add_vertex(Vector3(b.x, 0.0, b.y))
		st.set_normal(n)
		st.add_vertex(Vector3(c.x, 0.0, c.y))
	_mesh_inst.mesh = st.commit()
	_rebuild_outline()


func _rebuild_outline() -> void:
	if local_points.size() < 2:
		_outline.mesh = null
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in local_points:
		st.add_vertex(Vector3(p.x, 0.0015, p.y))
	## Close loop.
	var first: Vector2 = local_points[0]
	st.add_vertex(Vector3(first.x, 0.0015, first.y))
	_outline.mesh = st.commit()


func _apply_material() -> void:
	_ensure_nodes()
	var c := Color(fill_color.r, fill_color.g, fill_color.b, opacity)
	_mat.albedo_color = c
	_mat.emission_enabled = false
	_mat.metallic = 0.0
	_mat.roughness = 0.85
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	match material_kind:
		MaterialKind.FLAT:
			_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_mat.roughness = 1.0
		MaterialKind.GLOSSY:
			_mat.metallic = 0.35
			_mat.roughness = 0.12
			_mat.clearcoat_enabled = true
			_mat.clearcoat = 0.7
			_mat.clearcoat_roughness = 0.08
		MaterialKind.MATTE:
			_mat.metallic = 0.0
			_mat.roughness = 0.95
			_mat.clearcoat_enabled = false
		MaterialKind.NEON:
			_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_mat.emission_enabled = true
			_mat.emission = Color(c.r, c.g, c.b) * 1.4
			_mat.emission_energy_multiplier = 2.2
		MaterialKind.GLASS:
			_mat.metallic = 0.05
			_mat.roughness = 0.05
			_mat.clearcoat_enabled = true
			_mat.clearcoat = 1.0
			_mat.clearcoat_roughness = 0.02
			_mat.albedo_color = Color(c.r, c.g, c.b, opacity * 0.55)


func _apply_z_order() -> void:
	_ensure_nodes()
	## Slight Y lift + sorting so layering is visible on the grill plane.
	position.y = _base_y + float(z_order) * 0.0012
	_mesh_inst.sorting_offset = float(z_order) * 0.1
	_mesh_inst.material_override = _mat
	if _mat:
		_mat.render_priority = clampi(z_order, -64, 64)


func _refresh_outline() -> void:
	_ensure_nodes()
	_outline.visible = selected
	if selected:
		_outline_mat.albedo_color = Color(1.0, 0.92, 0.25, 0.98)
	_rebuild_outline()
