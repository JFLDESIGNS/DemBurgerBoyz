extends SceneTree
class BatchCustomer extends Node3D:
 var is_waiting:=true
 var is_challenge_guest:=true
func _initialize():call_deferred("run")
func run():
 create_timer(60).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/patty_pool_fixture.gd"));root.add_child(g);current_scene=g
 g.playing=true;g._setup_stations_data();g.grill.resize(g.GRILL_SLOTS);g.slot_positions.resize(g.GRILL_SLOTS)
 var p=load("res://scripts/patty.gd").new();g.patties_root.add_child(p);g._return_patty_to_spawn_pool(p)
 for cycle in 100:
  var nid=10000+cycle
  g.mp_spawn_patty(nid,0,0,0)
  assert(g._patty_by_net_id(nid)==p,"Pool continues supplying visible patties")
  assert(p.visible and not p.is_queued_for_deletion())
  p.set_meta("click_transfer",true)
  if cycle%2==0:
   g.grill[0]=null
   g._mp_cull_orphan_patties()
  else:
   g.mp_sync_grill([],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[])
  assert(g._patty_spawn_pool.size()==1)
  assert(g._patty_by_net_id(nid)==null)
  assert(not p.has_meta("click_transfer"))
  await process_frame
 # Absolute stock updates recover zero stock and restock without opening a phone.
 for stock in [5,0,12,3,0]:
  g.mp_sync_economy(10,0,0,1,0,0,0,0,["patty","cheese"],[stock,stock],[120.0,120.0])
  assert(g.supply_stock.patty==stock and g.supply_stock.cheese==stock)
 assert(g.stock_refreshes==5)
 assert(p._cook_halo.mesh==p._hold_meter.mesh)
 assert(p._cook_halo.transform==p._hold_meter.transform)
 assert(p._cook_halo.get_parent()==p._hold_meter.get_parent())
 var customer=BatchCustomer.new();g.add_child(customer);g.customers.append(customer);customer.set_meta("mp_net_id",77);customer.set_meta("serve_in_progress",true)
 g.mp_serve(77,0);g.mp_serve(77,0)
 assert(g.challenge_serves==2,"A challenge ticket accepts subsequent burgers")
 p.heating=true;p.heat_mul=1;p.is_held=false;p.cook_time=7.5;p._update_cook_halo()
 assert(p._cook_halo.visible and is_equal_approx(p._cook_halo_mat.get_shader_parameter("progress"),.5))
 p.cook_time=15;p._update_cook_halo();assert(not p._cook_halo.visible)
 p.flipped_once=true;p.cook_time=1;p._update_cook_halo();assert(p._cook_halo.visible)
 p.cook_time=15;p._update_cook_halo();assert(not p._cook_halo.visible)
 p.cook_time=3;p.heating=false;p._update_cook_halo();assert(not p._cook_halo.visible)
 p.heating=true
 p.is_held=true;p._update_cook_halo();assert(not p._cook_halo.visible)
 print("PATTY_POOL_100_CYCLES_STOCK_AND_HALO_OK");quit()
