extends SceneTree
func _initialize():call_deferred("run")
func run():
	var preset={"format_version":8,"name":"Material cache test","body_type":"kenney_chunky_toon","top_catalog_version":1,"top_style":1,"top_color":"7259d9ff","bottom_catalog_version":1,"bottom_style":2}
	var order:Array[String]=["bun_bottom","patty","bun_top"]
	var people=[]
	for i in 3:
		var c=load("res://scripts/customer.gd").new()
		var appearance=preset.duplicate(true)
		if i==2:appearance.top_color="ff3333ff"
		c.setup(order,Color.WHITE,45,0,-1,0,-1,appearance,true)
		root.add_child(c);c.set_process(false);people.append(c)
	var a=people[0].find_child("FittedTop",true,false)
	var b=people[1].find_child("FittedTop",true,false)
	var other=people[2].find_child("FittedTop",true,false)
	var shared=a.get_surface_override_material(0)
	assert(shared==b.get_surface_override_material(0),"Identical gameplay outfits reuse prepared materials")
	assert(shared!=other.get_surface_override_material(0),"Different saved palettes remain independent")
	var before_shader=shared.shader
	people[0]._apply_leave_fade_alpha(.4)
	assert(a.get_surface_override_material(0)!=shared,"Departing customer takes a private fade material")
	assert(b.get_surface_override_material(0)==shared and shared.shader==before_shader,"Fading one customer cannot fade the other")
	assert(is_equal_approx(float(a.get_surface_override_material(0).get_shader_parameter("fade_alpha")),.4))
	for c in people:c.queue_free()
	await process_frame
	print("CHARACTER_MATERIAL_CACHE_OK");quit()
