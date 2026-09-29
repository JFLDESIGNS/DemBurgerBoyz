extends Node
## Render the original static procedural material only when its settings change.
var view: SubViewport
static func attach(surface: MeshInstance3D, source: ShaderMaterial) -> void:
	var cache=load("res://scripts/cached_grill_surface.gd").new()
	surface.add_child(cache)
	cache.setup(surface,source)
static func invalidate(source: ShaderMaterial) -> void:
	if source.has_meta("surface_cache"):
		var cache=source.get_meta("surface_cache").get_ref()
		if is_instance_valid(cache): cache.view.render_target_update_mode=SubViewport.UPDATE_ONCE
func setup(surface: MeshInstance3D, source: ShaderMaterial) -> void:
	view=SubViewport.new()
	view.size=Vector2i(512,512)
	view.transparent_bg=true;view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(view)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.0
	camera.position=Vector3(0,0,2);camera.current=true;view.add_child(camera)
	var quad:=MeshInstance3D.new()
	var mesh:=QuadMesh.new();mesh.size=Vector2(2,2)
	quad.mesh=mesh;quad.material_override=source
	quad.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.add_child(quad)
	var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/cached_grill_surface.gdshader")
	material.render_priority=source.render_priority
	material.set_shader_parameter("baked_surface",view.get_texture())
	surface.material_override=material
	source.set_meta("surface_cache",weakref(self))
