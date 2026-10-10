extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(100).timeout.connect(func(): push_error("SOCIAL_TIMEOUT"); quit(1))
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_script(load(get_script().resource_path.get_base_dir().path_join("social_shift_fixture.gd")))
	root.add_child(game); current_scene = game; game.playing = true
	assert(game._shift_length() == 900.0)
	game.day = 2; assert(game._shift_length() == 900.0)
	game.day = 3; assert(game._shift_length() == 900.0)
	assert(not "mail cat" in game.BOSS_FRYER_ADVICE.to_lower())
	var cat = load("res://scripts/window_cat.gd").new()
	var calls = []
	cat.wants_meow.connect(func(pitch): calls.append(pitch))
	cat._state = "peek"; cat.visible = true
	cat._update_begging_meows(11.99); assert(calls.is_empty())
	cat._update_begging_meows(.02); assert(calls.size()==1)
	cat._visit_fed = true; cat._update_begging_meows(20.0); assert(calls.size()==1)
	cat.free()
	var social = load("res://scripts/customer_social.gd").new()
	social.game = game; game.add_child(social); social.set_process(false); game._customer_social = social
	var counts = {"reply":0,"away":0,"love":0,"quiet":0}
	for i in 100: counts[social.outcome((i+.5)/100.0)] += 1
	assert(counts == {"reply":65,"away":20,"love":2,"quiet":13})
	var chat_count := 0
	for i in 100:
		var person := Node.new()
		if social.conversation_roll(person,(i+.5)/100.0): chat_count += 1
		assert(not social.conversation_roll(person,0.0),"A customer does not reroll conversation chance")
		person.free()
	assert(chat_count == 50)
	var customers = []
	for i in 2:
		var c = load("res://scripts/customer.gd").new()
		c.setup(["bun_bottom","patty","bun_top"] as Array[String],Color.WHITE,90.0,i,0,0,-1,{},true)
		game.customers_root.add_child(c); c.set_process(false)
		c.is_waiting = true; c.position = Vector3(i*1.3,.1,2.25)
		c.order_elapsed_sec = 12.0+i
		game.customers.append(c); customers.append(c)
	game.selected_customer = customers[0]
	social.conversation_bubble(customers[0],"That grill smells amazing.")
	await process_frame
	var bubble = game.get_node("UI/Root/CustomerConversation")
	bubble._process(.1)
	assert(bubble.get_child(0).text == "That grill smells amazing.")
	assert(bubble.position.x > game.camera.unproject_position(customers[0].global_position).x)
	bubble.queue_free()

	print("CONVERSATION_OK: 50 percent once per customer and right-side speech card")
	game.queue_free(); await process_frame; quit()
