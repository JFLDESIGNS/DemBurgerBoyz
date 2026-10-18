extends SceneTree
class Walker extends Node3D:
 const LEAVE_OFFSCREEN_X=6.2
 var is_ragdoll=false
 var is_leaving=false
 var _leave_phase=""
 var target_x=3.0
 var _leave_start_x=3.0
 var _leave_dance_x=3.0
func _initialize():call_deferred("run")
func run():
 create_timer(60).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g
 var toast_count=0
 for i in 1000:
  assert(not g.GameDataScript.generate_order(.5,false,false,false,false).has("toasted_bun"))
  if g.GameDataScript.generate_order(.5,false,false,false,true).has("toasted_bun"):toast_count+=1
 assert(toast_count>0)
 for day in range(1,5):
  g.day=day
  assert(g._boss_daily_machine()==["",g.SHOP_FRYER_MACHINE,g.SHOP_SODA_MACHINE,g.SHOP_ICECREAM_MACHINE][day-1])
 g.day=1;g.playing=true
 for i in 10:g._record_boss_served_customer()
 assert(not g._boss_fryer_pending)
 g.day=2;g._record_boss_served_customer();assert(g._boss_fryer_pending)
 var life=load("res://scripts/customer_life.gd").new()
 life.debris_cooldown=0
 for i in 3:
  var pile=Node3D.new();g.add_child(pile);pile.position=Vector3(i,1,0)
  g.debris_piles.append({"root":pile})
 var glance=life._debris_glance(.1,g,true)
 assert(glance.is_finite())
 life.debris_switch_left=0
 assert(life._debris_glance(.1,g,true)!=glance)
 assert(not life._debris_glance(.1,g,false).is_finite())
 g.debris_piles.clear();life.debris_cooldown=0
 assert(not life._debris_glance(.1,g,true).is_finite())
 var cat=Node3D.new();g.add_child(cat);cat.position=Vector3(0,.7,2.45);cat.rotation.y=PI
 var visual=Node3D.new();cat.add_child(visual)
 load("res://scripts/cat_customer_hop.gd").attach(visual)
 var hop=cat.get_node("CustomerPassingHop");hop.set_process(false)
 var person=Walker.new();g.add_child(person);g.customers.append(person);person.position=Vector3(-1.7,0,2.25)
 assert(hop.path_needs_room(person,cat.position))
 hop._process(.14)
 assert(visual.global_position.z>cat.position.z+.4 and visual.global_position.y>cat.position.y+.2,"Cat hops backward and up, regardless of facing")
 person.is_leaving=true
 for phase in ["walk_off","sidestep","walk_to_review","walk_partner_wait"]:
  person._leave_phase=phase;assert(hop.path_needs_room(person,cat.position))
 person._leave_phase="review";assert(not hop.path_needs_room(person,cat.position))
 person.is_leaving=false
 person.position.x=3;person.target_x=3
 for i in 100:hop._process(.02)
 assert(hop.position.is_zero_approx(),"Cat returns after passage")
 assert(not hop.path_needs_room(person,cat.position),"Stationary customer does not trigger a hop")
 life.free()
 print("DAY_PROGRESSION_CAT_GLANCES_OK")
 g.queue_free();await process_frame;quit()
