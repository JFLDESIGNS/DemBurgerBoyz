extends SceneTree
func _initialize(): call_deferred("run")
func run():
	create_timer(90).timeout.connect(func(): quit(1))
	var g=load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/patty_pool_fixture.gd"));root.add_child(g);current_scene=g
	g.playing=true;g.grill_on=false
	g.grill_root=Node3D.new();g.world.add_child(g.grill_root)
	g._ensure_oil_effect_pool()
	var pool=g._oil_effect_pool
	assert(pool.emitters.size()==16 and pool.marks.size()==568)
	var bounds: Rect2=g._grill_place_bounds()
	for cycle in 5:
		for i in 700:
			g._spawn_oil_slick_local(Vector3(lerpf(bounds.position.x,bounds.end.x,float(i%20)/20),g.GRILL_SURFACE_Y,lerpf(bounds.position.y,bounds.end.y,float(i%17)/17)))
		assert(g.oil_slicks.size()==560)
		assert(pool.marks.size()==8)
		for item in g.oil_slicks: item.age=item.life*.5
		g._update_oil_slicks(0)
		assert(pool.emitters.size()==16)
		for item in g.oil_slicks:
			assert(item.smoke==null and item.mesh.visible)
		g._clear_oil_slicks()
		assert(pool.marks.size()==568)
		for fx in pool.emitters: assert(not fx.emitting)
		await process_frame
	var p=load("res://scripts/patty.gd").new();g.patties_root.add_child(p);p.set_process(false)
	var smoke=p._flip_smoke;var cheese=p._cheese_root
	assert(is_instance_valid(smoke) and is_instance_valid(cheese))
	for i in 100:
		p.reset_for_grill_spawn(0,1,Vector3.ZERO,0,true,false)
		assert(p._flip_smoke==smoke and not smoke.visible)
		assert(p._cheese_root==cheese and not cheese.visible)
		p.add_cheese();p.cheese_melt=1;p._update_cheese_visual()
		assert(cheese.visible)
		p.remove_cheese();assert(not cheese.visible)
		p.apply_mp_state(18,true,15,0,true,1,0,false,0,.5,false,0,0,0,0)
		assert(p.cook_time==18 and p.flipped_once and p._cook_visual_dirty)
		p.mp_puppet=true
		p._process(.09)
		assert(p._mat.get_shader_parameter("cook_time")==18)
		assert(p._flip_smoke==smoke)
	p.apply_mp_state(26,true,15,0,false,0,0,false,0,.5,true,0,0,0,0)
	p._process(.09)
	assert(p._mat.get_shader_parameter("cook_time")==26,"Held guest patties must consume visual snapshots too")
	g._build_burner_flames()
	assert(g.burner_flame_tris.size()==1 and g.burner_flame_tris[0] is MultiMeshInstance3D)
	assert(g.burner_flame_tris[0].multimesh.instance_count==70)
	g._set_burner_flames_visible(true)
	g._update_burner_flames(.016)
	var fryer:=Node3D.new();g.world.add_child(fryer)
	g._build_fryer_tub(fryer,0,0,StandardMaterial3D.new(),StandardMaterial3D.new())
	assert(g.fryer_oil_bubbles.size()==1 and g.fryer_oil_bubbles[0].multimesh.instance_count==9)
	g._apply_fryer_visual_colors()
	preload("res://scripts/build_patty_heat.gd").prewarm(g)
	var rows:=Control.new();g.get_node("UI/Root").add_child(rows)
	var overlays: Array=[]
	for i in 3:
		var row:=Control.new();rows.add_child(row)
		var overlay=preload("res://scripts/build_patty_heat.gd").new()
		row.add_child(overlay);overlay.setup(g,p);overlay.size=Vector2(180,180)
		overlays.append(overlay)
	for i in 3: await process_frame
	assert(is_instance_valid(overlays[0].view))
	assert(overlays[0].view.size==Vector2i(256,256))
	assert(overlays[1].view==null and overlays[2].view==null)
	var first_view=overlays[0].view
	overlays[0].get_parent().queue_free()
	for i in 3: await process_frame
	assert(overlays[1].view==first_view,"The next patty reuses the stack vapor viewport")
	g._whole_burger_drag={"test":true}
	await process_frame
	assert(overlays[1].modulate.a==0 and first_view.render_target_update_mode==SubViewport.UPDATE_DISABLED)
	g._whole_burger_drag.clear()
	for i in 15: await process_frame
	print("COOKING_EFFECTS_3500_OIL_MARKS_100_RECYCLES_OK")
	quit()
