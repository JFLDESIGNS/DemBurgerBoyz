extends SceneTree
## Focused allocation/CPU measurements, not a multiplayer or GPU benchmark.
func _initialize() -> void:
	call_deferred("run")

func summarize(samples: Array) -> Dictionary:
	samples.sort()
	return {"samples": samples.size(), "p50_ms": samples[int((samples.size()-1)*0.5)], "p95_ms": samples[int((samples.size()-1)*0.95)], "max_ms": samples.back()}

func run() -> void:
	assert(not OS.get_environment("MP_HITCH_AUDIT_OUTPUT").is_empty())
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load("res://tests/multiplayer_hitch_audit_harness.gd"))
	root.add_child(game)
	current_scene = game
	game.set_process_input(false)
	var results := {"engine": Engine.get_version_info(), "renderer": DisplayServer.get_name(), "scope": "Isolated real helper calls; no active multiplayer game loop or GPU timing"}
	var cup: Node3D = game._create_drink_cup_node()
	game.world.add_child(cup)
	game._mp_apply_remote_cup_fill(cup, "cola", 0.9, game.CUP_ICE_FULL, 0.2, false)
	var ice: Node3D = cup.get_node("IceStack")
	var previous_materials: Array = []
	for cube in ice.get_children():
		previous_materials.append(cube.material_override)
	var ice_samples: Array = []
	var replaced := 0
	for iteration in 60:
		var began := Time.get_ticks_usec()
		game._mp_apply_remote_cup_fill(cup, "cola", 0.9, game.CUP_ICE_FULL, 0.2, false)
		ice_samples.append((Time.get_ticks_usec()-began)/1000.0)
		if iteration == 0:
			for i in ice.get_child_count():
				if ice.get_child(i).material_override != previous_materials[i]:
					replaced += 1
		await process_frame
	results["identical_remote_cup_updates"] = summarize(ice_samples)
	results["ice_cube_count"] = ice.get_child_count()
	results["ice_materials_replaced_on_identical_update"] = replaced
	previous_materials.clear()
	game.fryer_ready_root = Node3D.new()
	game.world.add_child(game.fryer_ready_root)
	game.fryer_ready_servings = 4
	game._refresh_ready_fries_visuals()
	for i in 3: await process_frame
	var old_pack_ids: Array = []
	for pack in game.fryer_ready_root.get_children(): old_pack_ids.append(pack.get_instance_id())
	var fries_samples: Array = []
	var same_frame_children := 0
	for iteration in 20:
		var began := Time.get_ticks_usec()
		game._refresh_ready_fries_visuals()
		fries_samples.append((Time.get_ticks_usec()-began)/1000.0)
		if iteration == 0: same_frame_children = game.fryer_ready_root.get_child_count()
		for i in 2: await process_frame
	var retained := 0
	for pack in game.fryer_ready_root.get_children():
		if old_pack_ids.has(pack.get_instance_id()): retained += 1
	results["identical_ready_fries_refresh"] = summarize(fries_samples)
	results["ready_fries_old_packs_retained"] = retained
	results["ready_fries_same_frame_child_count"] = same_frame_children
	results["ready_fries_settled_child_count"] = game.fryer_ready_root.get_child_count()
	var cone := Node3D.new()
	game.world.add_child(cone)
	var swirl := Node3D.new()
	swirl.name = "SoftServeSwirl"
	cone.add_child(swirl)
	var corkscrew := MeshInstance3D.new()
	corkscrew.name = "CorkscrewSplineServe"
	swirl.add_child(corkscrew)
	game._mp_apply_remote_icecream_fill(cone, 1.0, false)
	var old_mesh: Mesh = corkscrew.mesh
	var cone_samples: Array = []
	for iteration in 30:
		var began := Time.get_ticks_usec()
		game._mp_apply_remote_icecream_fill(cone, 1.0, false)
		cone_samples.append((Time.get_ticks_usec()-began)/1000.0)
		await process_frame
	results["identical_full_cone_updates"] = summarize(cone_samples)
	results["cone_mesh_replaced"] = corkscrew.mesh != old_mesh
	old_mesh = null
	var output := FileAccess.open(OS.get_environment("MP_HITCH_AUDIT_OUTPUT"), FileAccess.WRITE)
	output.store_string(JSON.stringify(results, "\t"))
	output.close()
	print("MULTIPLAYER_HITCH_AUDIT_RESULT ", JSON.stringify(results))
	print("MULTIPLAYER_HITCH_AUDIT_OK")
	quit()
