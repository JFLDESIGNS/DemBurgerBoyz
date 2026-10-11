extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var g=load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/main_ticket_harness.gd"))
	root.add_child(g);current_scene=g
	var a=g._create_drink_cup_node()
	var b=g._create_drink_cup_node()
	g.add_child(a);g.add_child(b)
	assert(a.get_node("LiquidPivot/SurfacePivot/FizzFoam").material_override.albedo_texture == b.get_node("LiquidPivot/SurfacePivot/FizzFoam").material_override.albedo_texture)
	var la=a.get_node("LiquidPivot/Liquid").material_override
	var lb=b.get_node("LiquidPivot/Liquid").material_override
	assert(la != lb and la.shader == lb.shader, "Share shader compilation, keep each drink's color independent")
	assert(a.get_node("OverflowShell").material_override.shader == b.get_node("OverflowShell").material_override.shader)
	la.set_shader_parameter("pour_blend", .75)
	assert(not is_equal_approx(float(lb.get_shader_parameter("pour_blend")), .75))
	var floor_a=a.get_node("Floor").material_override
	var floor_b=b.get_node("Floor").material_override
	var handoff=g._side_depth_material(floor_a)
	assert(handoff==g._side_depth_material(floor_b), "Identical handoff depth variants are reused")
	assert(floor_a.no_depth_test and not handoff.no_depth_test, "Preparing a handoff must not mutate the original cup")
	floor_b.albedo_color=Color.RED
	assert(handoff!=g._side_depth_material(floor_b), "Different colors must not share a cached material")
	print("CUP_CACHE_OK")
	g.queue_free();await process_frame;quit()
