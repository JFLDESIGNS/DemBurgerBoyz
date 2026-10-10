extends SceneTree
func _initialize():call_deferred("run")
func run():
	var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g
	var bottle=Node3D.new();g.world.add_child(bottle)
	load("res://scripts/truck_ceiling_details.gd").taped_label(g,bottle,"Seasoning",.12,Vector3(0,0,.07))
	var label=bottle.get_node("SeasoningTapedLabel/LabelArtwork/BoldLettering")
	assert(label.visible and label.text=="Seasoning")
	assert(label.get_theme_font("font").resource_path.contains("Caveat"))
	g.tip_jar_fill_root=Node3D.new();g.world.add_child(g.tip_jar_fill_root)
	for i in 24:g._add_tip_jar_settled_bill()
	assert(g._tip_jar_bill_count==18 and g.tip_jar_fill_root.get_child_count()==18)
	var positions={}
	for bill in g.tip_jar_fill_root.get_children():positions[bill.position]=true
	assert(positions.size()==18)
	if DisplayServer.get_name()!="headless":
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		bottle.get_node("SeasoningTapedLabel/LabelArtwork").get_texture().get_image().save_png("res://build/customer_polish_qa/handwritten_seasoning.png")
	print("LABEL_TIPS_OK: handwritten tape and 18 unique bill positions");quit()
