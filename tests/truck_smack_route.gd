extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(40).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load(get_script().resource_path.get_base_dir().path_join("delivery_network_fixture.gd")));root.add_child(g);current_scene=g;g.playing=true
 var outside=Node3D.new();g.add_child(outside);g._build_background_people(outside);g._start_background_person(0)
 var actor=g.bg_people[0]
 var reaction=load("res://scripts/customer_truck_smack.gd").new();g.add_child(reaction);reaction.setup(g,actor,actor.global_position);reaction.set_process(false)
 assert(is_equal_approx(reaction.route[1].z,actor.WAIT_Z))
 assert(reaction.route[1].x<-8)
 for tick in 1000:
  reaction._process(1.0/60)
  if reaction.phase=="strike":break
 assert(reaction.phase=="strike" and is_equal_approx(actor.global_position.z,1.8096))
 assert(actor.scale.is_equal_approx(Vector3.ONE),"Background attacker must match foreground customer height")
 for tick in 90:reaction._process(1.0/60)
 assert(reaction.phase=="escape" and reaction.hit)
 assert(reaction.route[0].x<-10 and is_equal_approx(reaction.route[0].z,reaction.contact.z))
 var previous_x:float=actor.global_position.x
 for tick in 150:
  reaction._process(1.0/60)
  assert(actor.global_position.x<=previous_x,"Attacker must run toward screen right")
  assert(is_equal_approx(actor.global_position.z,reaction.contact.z),"Exit must not head toward buildings")
  previous_x=actor.global_position.x
  if reaction.is_queued_for_deletion():break
 assert(not actor.visible and not g.bg_people_active[0],"Attacker must leave, not resume building traffic")
 assert(not actor.get_meta("building_trip",false))
 print("TRUCK_SMACK_ROUTE_OK: right entrance, customer lane, impact two feet back, rightward exit without building traffic")
 quit()
