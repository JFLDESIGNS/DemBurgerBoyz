extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var scene := Node.new(); root.add_child(scene); current_scene = scene
	var ui := CanvasLayer.new(); ui.name = "UI"; scene.add_child(ui)
	var canvas := Control.new(); canvas.name = "Root"; ui.add_child(canvas)
	var bar := HBoxContainer.new(); canvas.add_child(bar); bar.position = Vector2(900,40)
	var hud = load("res://scripts/chef_points_hud.gd").new(); bar.add_child(hud)
	var stale := Label.new(); stale.text="+10 CHEF POINTS"; stale.modulate=Color.ORANGE; canvas.add_child(stale)
	hud.set_total(125,10,"PERFECT FLIP")
	await process_frame; await process_frame
	assert(canvas.get_children().filter(func(n): return n is Label and "CHEF POINTS" in n.text).size()==1)
	for factor in [0.75,1.0,1.5]:
		bar.scale = Vector2.ONE * factor
		for pop_scale in [.85,1.0,1.08]:
			hud.active_pop.scale = Vector2.ONE * pop_scale
			hud._position_reward(hud.active_pop)
			var a: Vector2 = hud.number.get_global_transform_with_canvas() * (hud.number.size*.5)
			var b: Vector2 = hud.active_pop.get_global_transform_with_canvas() * (hud.active_pop.size*.5)
			assert(absf(a.y-b.y)<.1,"Reward must match the rendered chef-point center")
	print("CHEF_POINTS_ALIGNMENT_OK: HUD and popup scales")
	quit()
