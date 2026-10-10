extends SceneTree
func _initialize(): call_deferred("run")
func run():
	root.size = Vector2i(960,720)
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/mobile_packing_fixture.gd"));root.add_child(g);current_scene=g;g.playing=true
	g.get_node("UI").hide()
	var m = load("res://scripts/grubbah.gd").new();g.add_child(m);m.game=g;m.set_process(false)
	m.state={"number":1,"items":["bun_bottom","patty","cheese","bun_top"],"phase":"bagging"}
	var owner=load("res://scripts/mobile_ticket_owner.gd").new();g.add_child(owner);owner.order.assign(m.state.items);owner.set_meta("mobile_order",true)
	m.ticket_owner=owner;g.selected_customer=owner;g._create_ticket(owner)
	for i in 5: await process_frame
	m.props=Node3D.new();g.add_child(m.props)
	m.flying_ticket=Sprite3D.new();m.props.add_child(m.flying_ticket);m.flying_ticket.hide()
	m.prepare_bag_ticket()
	m.bag=m.fitted("SM_FastFoodBagClosed",.4);m.props.add_child(m.bag);m.add_bag_label();m.bag_glow.hide();m.bag_finish.hide();m.bag_ticket.show()
	print("BAG_BOUNDS ",g._shop_preview_bounds(m.bag)," TICKET ",m.bag_ticket.position)
	var light=DirectionalLight3D.new();g.add_child(light);light.rotation_degrees=Vector3(-30,20,0)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;g.add_child(env)
	g.camera.position=Vector3(.35,.4,-.95);g.camera.look_at(Vector3(0,.2,0))
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/customer_polish_qa/bag_attached_ticket.png")
	print("BAG_ATTACHED_TICKET_RENDERED")
	quit()
