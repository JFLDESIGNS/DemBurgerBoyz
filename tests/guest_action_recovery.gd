extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/guest_action_fixture.gd"));root.add_child(g);current_scene=g;g.playing=true
 g._serve_fly_busy=true;g._mp_sender_override=7
 for n in 16:assert(g._mp_queue_food_request("mp_fries_hand",[n]))
 assert(g._mp_queue_food_request("mp_fries_hand",[99]))
 assert(g._mp_side_requests.size()==16 and g.acks==[[7,"fries",false]])
 g._mp_queue_food_request("mp_drink_hand",[99,"cola"])
 assert(g.acks.back()==[7,"drink",false])
 g._mp_fries_pickup_pending=true;g._mp_fries_release_pending=true
 g.mp_fries_taken(true,0,2)
 assert(g.released and not g.fries_pack_held and not g._mp_fries_release_pending)
 g._mp_fries_pickup_pending=true;g.mp_fries_taken(false,0,0)
 assert(not g._mp_fries_pickup_pending and g.feedback.back().contains("already taken"))
 g.supply_stock.potato=4;g.supply_fresh.potato=0.1;g._update_supply_freshness(1000)
 assert(g.supply_stock.potato==4,"Frozen potatoes must not spoil")
 g._apply_economy_to_gamedata()
 assert(g.GameDataScript.PRICE_SODA==3 and g.GameDataScript.PRICE_FRIES==4 and g.GameDataScript.PRICE_ICECREAM==5)
 print("GUEST_ACTION_RECOVERY_OK: overflow, early release, feedback, frozen stock, margins")
 g.queue_free();await process_frame;quit()
