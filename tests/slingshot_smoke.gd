extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var g=load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/slingshot_fixture.gd")); root.add_child(g); current_scene=g
	g.playing=true
	var sling=g._ensure_ingredient_slingshot()
	var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=Vector2(350,350)
	assert(not sling.handle_input(press),"Tap remains available to normal ingredient controls")
	var motion=InputEventMouseMotion.new();motion.position=Vector2(325,400)
	assert(sling.handle_input(motion) and sling.pulling)
	var aim:Vector2=sling.aim_point(press.position,motion.position,720)
	assert(aim.x>press.position.x and aim.y<press.position.y,"Pull down-left launches up-right")
	var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.position=motion.position
	assert(sling.handle_input(release) and not sling.pulling and g.spent==1)
	sling.handle_input(press);motion.position=Vector2(350,290)
	assert(not sling.handle_input(motion) and not sling.pulling,"Upward direct dragging stays available")
	sling.handle_input(press);motion.position=Vector2(350,410);sling.handle_input(motion)
	var esc=InputEventKey.new();esc.pressed=true;esc.keycode=KEY_ESCAPE
	assert(sling.handle_input(esc) and not sling.pulling and g.spent==1,"Cancel never spends stock")
	var audio=load("res://scripts/game_audio.gd").new()
	assert(audio._make_slingshot_sound(true).data.size()>0)
	assert(audio._make_slingshot_sound(false).data.size()>0)
	audio.free()
	# Aim directly at a visible customer, then deliberately miss far to the side.
	var customer=Node3D.new();g.world.add_child(customer);customer.position=Vector3(0,0,1.4);g.customers=[customer]
	var head:Vector3=g._customer_head_world(customer)
	var target:Vector2=g.camera.unproject_position(head)
	sling.launch("tomato",Vector2(350,400),target)
	await create_timer(.65).timeout
	assert(g.hits==1,"Projectile reaches the aimed customer")
	sling.launch("tomato",Vector2(350,400),target+Vector2(1000,0))
	await create_timer(.65).timeout
	assert(g.hits==1,"Misses do not auto-aim onto the customer")
	print("SLINGSHOT_OK: reverse aim, one stock, cancel, direct-drag path, sounds, hit and miss")
	g.queue_free(); await process_frame; quit()
