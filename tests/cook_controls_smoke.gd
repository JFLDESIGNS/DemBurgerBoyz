extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var game = load("res://scenes/main.tscn").instantiate()
 game.set_script(load(get_script().resource_path.get_base_dir().path_join("cook_controls_fixture.gd")))
 root.add_child(game);current_scene=game;game.playing=true
 game.grill.resize(game.GRILL_SLOTS);game.slot_positions.resize(game.GRILL_SLOTS)
 game.stations=[{"items":["bun_bottom","patty"],"patties":[]}]
 spawn_patty(game,0,901)
 var patty=game.grill[0];patty.set_process(false);patty.cook_time=20.0;patty.first_side_time=20.0;patty.flipped_once=true
 patty.set_meta("chef_done_at",Time.get_ticks_msec())
 game._quick_transfer_patty(patty)
 await create_timer(0.5).timeout
 assert(game.chef_points==20,"Quick HOLD earns 20 points once")
 assert(game._is_in_warmer_zone(patty.position) and not patty.is_held,"Done click must move to HOLD")
 game._quick_transfer_patty(patty)
 await create_timer(0.5).timeout
 assert(game.stations[0].patties.has(patty) and game.grill[0]==null,"HOLD click must clear grill and enter Build")
 game.stations[0].items=["bun_bottom"];game.stations[0].patties=[]
 spawn_patty(game,2,903)
 var direct=game.grill[2];direct.set_process(false);direct.cook_time=20.0;direct.first_side_time=20.0;direct.flipped_once=true
 game._quick_transfer_patty(direct)
 assert(direct.is_held and bool(direct.get_meta("click_transfer",false)))
 await create_timer(0.5).timeout
 assert(game.stations[0].patties.has(direct) and game.grill[2]==null,"Needed patty flips straight to Build")
 spawn_patty(game,1,902)
 var other=game.grill[1];other.set_process(false);other.cook_time=20.0;other.first_side_time=20.0;other.flipped_once=true
 game._on_patty_clicked(other)
 assert(game.spatula_patty==other,"Scoop action must still carry burger")
 game._trash_spatula_patty();assert(game.spatula_patty==null,"Scooped burger must be trashable")
 game._mp_sender_override=55
 game.mp_patty_pose(901,0,3,0,true)
 assert(game._mp_remote_patty_targets.is_empty(),"Stale carry packet must not resurrect released ownership")
 game.owned_machines[game.SHOP_FRYER_MACHINE]=true
 game.fryer_pit_offset=Vector3(0.09,0.08,0.03)
 game._build_fryer_machine()
 await process_frame;await physics_frame
 var basket=game.fryer_baskets[0].root
 var home_local=game.fryer_root.to_local(basket.global_position)
 var oil_local=game._fryer_oil_local_for_index(0)
 assert(abs(home_local.x-oil_local.x)<0.001 and abs(home_local.z-oil_local.z+0.04)<0.001,"Basket must follow pit offsets")
 var screen=game.camera.unproject_position(basket.to_global(Vector3(0,0.105,0.08)))
 assert(game._fryer_basket_index_at(screen)==0,"Actual offset basket must be clickable")
 game._try_fryer_basket_click(screen);assert(game.fryer_baskets[0].state=="raw")
 game._begin_fryer_basket_hold(0);game._fryer_auto_mode="cook"
 for i in 480:game._update_held_fryer_basket(1.0/60.0)
 assert(game.fryer_baskets[0].state=="done" and game.fryer_held_index==-1,"Click dunk must cook and release")
 game._begin_fryer_basket_hold(0);game._fryer_auto_mode="shake"
 for i in 480:game._update_held_fryer_basket(1.0/60.0)
 assert(game.fryer_ready_servings==2 and game.fryer_baskets[0].state=="empty","Click shake must finish one batch")
 assert(game._begin_fryer_basket_hold(0),"Manual grab remains available")
 game._release_fryer_basket()
 var customer=load("res://scripts/customer.gd").new()
 var order:Array[String]=["bun_bottom","patty","bun_top"]
 customer.setup(order,Color.WHITE,300.0,0,0,0,-1,{},true)
 game.customers_root.add_child(customer);game.customers.append(customer)
 customer.is_waiting=true
 game._close_service_window()
 assert(customer.is_leaving and not game.customers.has(customer),"Closing must send the current customer away")
 game._apply_location_local("market_street")
 await process_frame
 assert(not is_instance_valid(customer),"Customer cannot appear in the new town")
 print("COOK_CONTROLS_OK")
 game.queue_free()
 for i in 8:await process_frame
 quit()

func spawn_patty(game, index:int, net_id:int) -> void:
 var p=load("res://scripts/patty.gd").new()
 p.slot_index=index;p.net_id=net_id;p.base_y=game.GRILL_SURFACE_Y+game.PATTY_SIT_Y
 p.position=Vector3(game.GRILL_CENTER_X,p.base_y,game.GRILL_SURFACE_Z)
 p._rest_x=p.position.x;p._rest_z=p.position.z
 game.patties_root.add_child(p);game.grill[index]=p
