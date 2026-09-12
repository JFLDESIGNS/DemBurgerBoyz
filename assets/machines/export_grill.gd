extends SceneTree
## Writes the in-game flat-top grill, stain overlays, and splash lip to res://assets/machines/.

const OUT_DIR := "res://assets/machines"
const STAIN_PNG := "res://assets/machines/grill_stain_layer.png"
const VIGNETTE_PNG := "res://assets/machines/grill_vignette.png"
const STEEL_PNG := "res://assets/machines/grill_stainless_steel.png"
const SPLASH_PNG := "res://assets/machines/grill_splash_lip.png"
const GRILL_GLB := "res://assets/machines/grill.glb"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(256, 256))
	var dir := DirAccess.open("res://")
	if dir != null:
		dir.make_dir_recursive("assets/machines")
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("Could not load scenes/main.tscn")
		quit(1)
		return
	var game := packed.instantiate()
	root.add_child(game)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(256, 256))
	await process_frame
	await RenderingServer.frame_post_draw
	var surface := game.get("grill_surface_area") as Node3D
	if surface == null or not is_instance_valid(surface):
		push_error("Grill surface is missing")
		quit(1)
		return
	var season_mat := game.get("grill_season_mat") as ShaderMaterial
	var vig_mat := game.get("grill_vig_mat") as ShaderMaterial
	var stain_tex := await _bake_shader_png(season_mat, Vector2i(2048, 1088), STAIN_PNG)
	var vig_tex := await _bake_shader_png(vig_mat, Vector2i(2048, 1088), VIGNETTE_PNG)
	_save_loaded_png("res://assets/grill/stainless_steel.png", STEEL_PNG)
	_save_loaded_png("res://assets/grill/stainless_steel.png", SPLASH_PNG)
	var export_root := _assemble_grill(surface, game.get("grill_standoff_root") as Node3D)
	_apply_baked_overlay(export_root, "GrillSeasoning", stain_tex)
	_apply_baked_overlay(export_root, "GrillVignette", vig_tex)
	_strip_non_visual(export_root)
	if not _write_glb(export_root, GRILL_GLB):
		export_root.queue_free()
		quit(1)
		return
	export_root.queue_free()
	game.queue_free()
	print("GRILL_EXPORT_OK")
	quit(0)


func _assemble_grill(surface: Node3D, standoffs: Node3D) -> Node3D:
	var clone := surface.duplicate() as Node3D
	clone.name = "Grill"
	root.add_child(clone)
	if standoffs != null and is_instance_valid(standoffs):
		var legs := standoffs.duplicate() as Node3D
		clone.add_child(legs)
		legs.global_transform = standoffs.global_transform
	clone.position = Vector3.ZERO
	clone.rotation = Vector3.ZERO
	clone.scale = Vector3.ONE
	clone.visible = true
	return clone


func _apply_baked_overlay(root_node: Node, mesh_name: String, tex: Texture2D) -> void:
	if tex == null:
		return
	var found := root_node.find_child(mesh_name, true, false) as MeshInstance3D
	if found == null:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex
	mat.albedo_color = Color.WHITE
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	found.material_override = mat


func _bake_shader_png(src: ShaderMaterial, size: Vector2i, path: String) -> Texture2D:
	if src == null or src.shader == null:
		push_warning("No shader to bake for %s" % path)
		return null
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.world_3d = World3D.new()
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.0
	cam.near = 0.05
	cam.far = 8.0
	cam.position = Vector3(0.0, 0.0, 1.0)
	cam.current = true
	vp.add_child(cam)
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	var aspect := float(size.x) / float(maxi(size.y, 1))
	quad.size = Vector2(aspect, 1.0)
	mi.mesh = quad
	mi.material_override = src.duplicate()
	vp.add_child(mi)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null:
		push_warning("Bake produced no image for %s" % path)
		return null
	if img.is_compressed():
		img.decompress()
	img.save_png(path)
	print("Wrote ", path)
	return ImageTexture.create_from_image(img)


func _save_loaded_png(from_res: String, to_res: String) -> void:
	if not ResourceLoader.exists(from_res):
		push_warning("Missing %s" % from_res)
		return
	var tex := load(from_res) as Texture2D
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		push_warning("Could not read pixels from %s" % from_res)
		return
	if img.is_compressed():
		img.decompress()
	img.save_png(to_res)
	print("Wrote ", to_res)


func _write_glb(node: Node3D, path: String) -> bool:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_scene(node, state) != OK:
		push_error("GLTF append failed for %s" % path)
		return false
	if doc.write_to_filesystem(state, path) != OK:
		push_error("GLTF write failed for %s" % path)
		return false
	print("Wrote ", path)
	return true


func _strip_non_visual(node: Node) -> void:
	for child in node.get_children():
		var drop := _should_drop(child)
		if drop:
			node.remove_child(child)
			child.free()
			continue
		_strip_non_visual(child)


func _should_drop(child: Node) -> bool:
	var n := str(child.name)
	if n == "HeatWarp" or n.begins_with("HeatGlow") or n.contains("Glow") or n.contains("Light"):
		return true
	if child is MeshInstance3D:
		return (child as MeshInstance3D).mesh == null
	if child is ImporterMeshInstance3D:
		return false
	if child is Node3D and not (
		child is Area3D
		or child is CollisionObject3D
		or child is CollisionShape3D
		or child is Label3D
		or child is GPUParticles3D
		or child is CPUParticles3D
		or child is Marker3D
		or child is Light3D
		or child is AudioStreamPlayer3D
		or child is Sprite3D
	):
		return false
	return true
