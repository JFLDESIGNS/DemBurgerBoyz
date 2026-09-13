extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(40).timeout.connect(func(): quit(1))
	var game=load("res://scenes/main.tscn").instantiate()
	game.set_script(load(get_script().resource_path.get_base_dir().path_join("interaction_delivery_fixture.gd")))
	root.add_child(game);current_scene=game;game.playing=true;game.money=10000
	game.window_cat=load("res://scripts/window_cat.gd").new();game.world.add_child(game.window_cat)
	for id in [game.SHOP_FRYER_MACHINE,game.SHOP_SODA_MACHINE]:
		var target:=Node3D.new();game.world.add_child(target);target.position=Vector3(-1,0.7,-0.2)
		var shape:=MeshInstance3D.new();shape.mesh=BoxMesh.new();target.add_child(shape)
		if id==game.SHOP_FRYER_MACHINE: game.fryer_root=target
		else: game.soda_root=target
		game.owned_machines[id]=false
		var before:float=game.money
		game._buy_shop_item_local(id)
		assert(game.pending_machine_deliveries.has(id) and not target.visible)
		assert(game.mail_delivery_truck!=null)
		game._buy_shop_item_local(id)
		assert(is_equal_approx(game.money,before-game._shop_item_cost(id)),"No duplicate charge")
		var saw_flight:=false
		for i in 1600:
			game._update_supply_orders(1.0/60.0)
			for fx in game.supply_delivery_fx:
				if fx.get("kind")=="machine" and fx.mesh.visible: saw_flight=true
		assert(saw_flight and target.visible and not game.pending_machine_deliveries.has(id))
		assert(game.mail_delivery_truck==null and game.supply_delivery_fx.is_empty())
		assert(target.position.is_equal_approx(Vector3(-1,0.7,-0.2)),"Final placement preserved")
	game._start_machine_delivery(game.SHOP_FRYER_MACHINE)
	game._clear_supply_delivery_fx()
	assert(game.pending_machine_deliveries.is_empty() and game.fryer_root.visible,"Cleanup preserves paid equipment")
	print("MACHINE_DELIVERY_OK")
	quit()
