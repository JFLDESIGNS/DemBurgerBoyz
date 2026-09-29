extends SceneTree
var p
func bench(label: String, fn: Callable, count: int = 200):
	var times: Array[int] = []
	for i in count:
		var start := Time.get_ticks_usec()
		fn.call(i)
		times.append(Time.get_ticks_usec() - start)
	times.sort()
	print(label, " us p50=", times[count/2], " p95=", times[int(count*.95)], " max=", times[-1])
func _initialize(): call_deferred("run")
func run():
	p = load("res://scripts/patty.gd").new()
	root.add_child(p)
	p.set_process(false)
	p.flipped_once = true
	p.first_side_time = 15
	bench("cook_texture_changed", func(i): p.cook_time=5+i*.02; p._update_cook_gradient())
	bench("cook_texture_unchanged", func(_i): p._update_cook_gradient())
	bench("refresh_all_visuals_changed", func(i): p.cook_time=5+i*.02; p.refresh_cook_visuals())
	bench("snapshot_apply_changed", func(i): p.apply_mp_state(5+i*.02,true,15,0,true,1,0,false,0,0,false,0,0,0,0))
	p.cook_time=20
	var start := Time.get_ticks_usec()
	p._ensure_flip_smoke()
	print("first_smoke_create_us=",Time.get_ticks_usec()-start)
	bench("smoke_recreate_cached", func(_i): p._clear_flip_smoke(); p._ensure_flip_smoke(), 30)
	bench("smoke_steady_update", func(_i): p._update_flip_smoke(.016))
	await process_frame
	var nodes := [p]
	var meshes := 0
	var particles := 0
	var vertices := 0
	while not nodes.is_empty():
		var n = nodes.pop_back()
		nodes.append_array(n.get_children())
		if n is GPUParticles3D: particles += 1
		if n is MeshInstance3D and n.mesh != null:
			meshes += 1
			vertices += n.mesh.get_faces().size()
	print("patty_nodes=",p.get_child_count()," recursive_mesh_nodes=",meshes," triangle_vertices=",vertices," particle_systems=",particles)
	print("AUDIT_CPU_ONLY_COMPLETE")
	quit()
