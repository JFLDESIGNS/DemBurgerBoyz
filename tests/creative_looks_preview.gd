extends SceneTree
func _initialize(): call_deferred("run")
func run():
	root.size=Vector2i(1000,350)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var g=load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g;g.get_node("UI").hide()
	var canvas=CanvasLayer.new();root.add_child(canvas)
	var backdrop=TextureRect.new();canvas.add_child(backdrop);backdrop.size=Vector2(1000,350)
	backdrop.texture=ImageTexture.create_from_image(Image.load_from_file("C:/Users/joe/AppData/Local/Temp/codex-clipboard-d59f1311-76d9-49bb-907c-74fa86f6a191.png"))
	backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	var settings=g.GFX_DEFAULTS.duplicate();settings.toon_filter=false;settings.pixel_filter=false
	g._apply_screen_style_filter(settings);assert(not g.screen_style_layer.visible)
	var previews=[]
	for key in ["original"]+g.CREATIVE_LOOKS.keys():
		for other in g.CREATIVE_LOOKS: settings[other]=0.0
		if key!="original":
			settings[key]=50.0;g._apply_screen_style_filter(settings)
			assert(is_equal_approx(g.screen_style_mat.get_shader_parameter(key),.5))
			settings[key]=100.0
		g._apply_screen_style_filter(settings)
		assert(g.screen_style_layer.visible == (key!="original"))
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		previews.append(root.get_texture().get_image())
	var sheet=Image.create(1000,350*previews.size(),false,Image.FORMAT_RGBA8)
	for i in previews.size():
		previews[i].convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(previews[i],Rect2i(0,0,1000,350),Vector2i(0,350*i))
	sheet.save_png("res://build/customer_polish_qa/creative_looks_preview.png")
	for key in g.CREATIVE_LOOKS: settings[key]=0.0
	g._apply_screen_style_filter(settings);assert(not g.screen_style_layer.visible)
	print("CREATIVE_LOOKS_OK: six independent opacity uniforms and visibility")
	quit()
