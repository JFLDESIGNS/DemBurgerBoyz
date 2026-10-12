extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/delivery_network_fixture.gd"));root.add_child(g);current_scene=g;g.playing=true
 var outside=Node3D.new();g.add_child(outside);g._build_background_people(outside);g._start_background_person(0)
 var actor=g.bg_people[0]
 var reaction=load("res://scripts/customer_truck_smack.gd").new();g.add_child(reaction);reaction.setup(g,actor,actor.global_position);reaction.set_process(false)
 assert(is_equal_approx(reaction.route[1].z,actor.WAIT_Z))
 assert(reaction.route[1].x<-8)
 for tick in 1000:
  reaction._process(1.0/60)
  if reaction.phase=="strike":break
 assert(reaction.phase=="strike" and is_equal_approx(actor.global_position.z,1.2))
 for tick in 90:reaction._process(1.0/60)
 assert(reaction.phase=="escape" and reaction.hit)
 assert(reaction.route[0].z==20 and is_equal_approx(reaction.route[0].x,reaction.contact.x))
 print("TRUCK_SMACK_ROUTE_OK: right entrance, customer lane, closer impact, upward exit")
 quit()
