extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/hotdog_challenge_fixture.gd"))
	root.add_child(g); current_scene = g
	g.playing = true; g._kitchen_ready = true
	var c = load("res://scripts/customer.gd").new()
	c.setup([] as Array[String],Color.WHITE,90.0,0,0,0,-1,{},true)
	g.customers_root.add_child(c); c.set_process(false)
	c.position = Vector3(-1,.1,2.25); c.is_waiting = true
	g.customers.append(c); g._create_ticket(c)
	var home = c.transform
	var hud = load("res://scripts/chef_points_hud.gd").new()
	g.get_node("UI/Root").add_child(hud)
	var boss = g._ensure_hotdog_challenge(); boss.set_process(false)
	assert(boss.start())
	assert(c.visible and boss.fleeing.size() == 1)
	assert(boss.street_saved.size() == 6)
	assert(boss.spectator_target(0).distance_to(boss.spectator_target(2)) > .6)
	hud._process(0); hud.set_total(50,50,"test")
	assert(not hud.visible and not is_instance_valid(hud.active_pop) and hud.reward_queue.is_empty())
	boss.update_fleeing(.5)
	assert(c.position.x < home.origin.x-2)
	assert(c.get_node("MouthSpeech").elapsed > 0)
	boss.update_fleeing(2)
	assert(not c.visible)
	boss.cancel(); hud._process(0)
	assert(c.visible and c.transform == home and hud.visible)
	print("BARON_ARRIVAL_OK: fleeing, mouth reaction, six separated spectators, hidden points, cleanup")
	g.queue_free(); await process_frame; quit()
