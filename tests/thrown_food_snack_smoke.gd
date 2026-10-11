extends SceneTree
const Snack = preload("res://scripts/thrown_food_snack.gd")
func _initialize(): call_deferred("run")
func run():
	create_timer(60).timeout.connect(func(): push_error("SNACK_TIMEOUT"); quit(1))
	for id in ["bacon","cheese"]:
		var accepted := 0
		for i in 1000:
			var roll := float(i)/1000.0
			if Snack.accepts(id,false,roll): accepted += 1
			assert(Snack.accepts(id,true,roll),"Cat must always accept bacon/cheese")
		assert(accepted == 800)
	for id in ["lettuce","tomato","onion","pickle","ketchup","mustard","bun_top"]:
		var accepted := 0
		for i in 1000:
			if Snack.accepts(id,false,float(i)/1000.0): accepted += 1
		assert(accepted == 250)
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/main_ticket_harness.gd"))
	root.add_child(g); current_scene = g
	var c := Node3D.new(); g.world.add_child(c)
	var mouth := MeshInstance3D.new(); mouth.name="SmileMouth"; mouth.mesh=QuadMesh.new(); c.add_child(mouth)
	mouth.position=Vector3(0,1,.1)
	var home := mouth.transform
	var at := Vector3(.17,1.02,.13)
	g._apply_customer_ingredient_hit(c,"cheese",at,"face",1)
	var snack = c.get_node("ThrownFoodSnack")
	snack.set_process(false); snack.sample(.16)
	assert(mouth.position.is_equal_approx(home.origin),"Mouth must remain attached to the face")
	for time in [.31,.57,.83]:
		snack.sample(time)
		assert(mouth.scale.y>1.3,"Three visible chewing beats")
	snack.sample(.98)
	assert(not snack.food.visible,"Food must be swallowed")
	g._start_flung_food_snack(c,"bacon",at)
	assert(c.get_child_count()==2,"Repeated throws must replace, not stack, mouth animations")
	var second=c.get_node("ThrownFoodSnack"); second.finish()
	assert(mouth.transform.is_equal_approx(home),"Mouth must restore cleanly after eating")
	second.queue_free()
	g.queue_free(); await process_frame
	print("THROWN_FOOD_SNACK_OK: 80% favorites, 25% others, cat favorites 100%, mouth reach, three chews, swallow, repeat cleanup")
	quit()
