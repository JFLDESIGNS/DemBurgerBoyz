extends SceneTree
func _initialize(): call_deferred("run")
func run():
	create_timer(30).timeout.connect(func(): quit(1))
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var stage:=Node3D.new();root.add_child(stage)
	var camera:=Camera3D.new();stage.add_child(camera)
	camera.position=Vector3(0,0,2)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.4;camera.current=true
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.5,.45,.3)
	stage.add_child(env)
	var surfaces: Array[MeshInstance3D]=[]
	for i in 2:
		var surface:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(1,1)
		surface.mesh=quad;surface.position.x=(i-.5)*1.1;stage.add_child(surface)
		var mat:=ShaderMaterial.new();mat.shader=load("res://shaders/grill_seasoning.gdshader" if i==0 else "res://shaders/grill_vignette.gdshader")
		surface.material_override=mat;surfaces.append(surface)
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	print("STATIC_GRILL_BEFORE_GPU_MS=",await gpu_sample())
	var reference:=root.get_texture().get_image()
	reference.save_png("res://build/grill_cache_before.png")
	for surface in surfaces: preload("res://scripts/cached_grill_surface.gd").attach(surface,surface.material_override)
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	print("STATIC_GRILL_CACHED_GPU_MS=",await gpu_sample())
	var cached:=root.get_texture().get_image()
	cached.save_png("res://build/grill_cache_after.png")
	reference.resize(256,144);cached.resize(256,144)
	var error:=0.0
	for y in 144:
		for x in 256:
			var a:=reference.get_pixel(x,y);var b:=cached.get_pixel(x,y)
			error+=(absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3.0
	error/=256*144
	print("CACHED_GRILL_MEAN_COLOR_ERROR=",error)
	assert(error<.015,"Cached appearance must preserve static grill shading")
	print("CACHED_GRILL_RENDER_OK");quit()

func gpu_sample() -> float:
	var total:=0.0
	for i in 30:
		await process_frame
		total+=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
	return total/30.0
