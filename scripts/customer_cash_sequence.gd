extends RefCounted

static func play(game: Node, customer: Node3D, special: bool) -> void:
	if not is_instance_valid(customer) or bool(customer.get_meta("cash_sequence_playing",false)):return
	customer.set_meta("cash_sequence_playing",true)
	var processing := customer.is_processing()
	customer.set_process(false)
	customer._anim_player.stop()
	customer._play_burger_clip("Grisaldi_Spin_Throw" if special else "Give_Money")
	await game.get_tree().create_timer(1.95 if special else .85).timeout
	if not is_instance_valid(customer):return
	if is_instance_valid(customer._burger_props):customer._burger_props.hide()
	# Visible notes leave the customer's hand and land toward the serving counter.
	for i in (9 if special else 1):
		var note := MeshInstance3D.new()
		var mesh := BoxMesh.new();mesh.size=Vector3(.16,.006,.075);note.mesh=mesh
		var mat := StandardMaterial3D.new();mat.albedo_color=Color("91b984");note.material_override=mat
		game.add_child(note);note.global_position=customer.global_position+Vector3(.2,1.5,.0)
		var start := note.global_position
		var end := start+Vector3((i-4)*.12 if special else 0.0,-.35,-1.0)
		var tween := note.create_tween()
		tween.tween_method(func(t: float):
			if is_instance_valid(note):
				note.global_position=start.lerp(end,t)+Vector3.UP*sin(t*PI)*(.65 if special else .15)
				note.rotation=Vector3(t*PI*2,t*i*.4,t*.7)
		,0.0,1.0,.8)
		tween.tween_interval(.3);tween.tween_callback(note.queue_free)
	await game.get_tree().create_timer(.65 if special else .75).timeout
	if not is_instance_valid(customer):return
	customer._anim_player.stop();customer._reset_skeleton_pose()
	customer._anim_state="";customer._play_anim("idle");customer.set_process(processing)
	customer.set_meta("cash_sequence_playing",false)

static func story(game: Node, customer: Node3D) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	if not is_instance_valid(customer):return
	var viewport := game.get_viewport()
	var camera := viewport.get_camera_3d()
	if camera==null:return
	var photo := viewport.get_texture().get_image()
	var center := camera.unproject_position(customer.global_position+Vector3.UP*1.35)
	var top := camera.unproject_position(customer.global_position+Vector3.UP*2.25)
	var ratio := Vector2(photo.get_size()) / viewport.get_visible_rect().size
	center *= ratio;top *= ratio
	var height := maxf(160,absf(center.y-top.y)*2.7)
	var rect := Rect2i(center-Vector2(height*.4,height*.5),Vector2(height*.8,height)).intersection(Rect2i(Vector2i.ZERO,photo.get_size()))
	if rect.size.x<1 or rect.size.y<1:return
	var layer := CanvasLayer.new();layer.layer=35;game.add_child(layer)
	var panel := PanelContainer.new();layer.add_child(panel)
	panel.position=Vector2(24,90);panel.size=Vector2(260,350);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new();style.bg_color=Color("241b32");style.border_color=Color("f4a84e");style.set_border_width_all(3);style.set_corner_radius_all(16);style.content_margin_left=14;style.content_margin_right=14;style.content_margin_top=12;style.content_margin_bottom=12;panel.add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new();panel.add_child(column)
	var title := Label.new();title.text="GRISALDI  •  JUST POSTED";title.add_theme_color_override("font_color",Color("ffca55"));column.add_child(title)
	var image := TextureRect.new();image.texture=ImageTexture.create_from_image(photo.get_region(rect));image.custom_minimum_size=Vector2(260,250);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;column.add_child(image)
	var caption := Label.new();caption.text="Found my next burger spot!\nCamera eats first.  #BurgerPals\n♥  5 friends are on their way";column.add_child(caption)
	var tween := panel.create_tween();panel.modulate.a=0;tween.tween_property(panel,"modulate:a",1.0,.2);tween.tween_interval(4.5);tween.tween_property(panel,"modulate:a",0.0,.3);tween.tween_callback(layer.queue_free)
