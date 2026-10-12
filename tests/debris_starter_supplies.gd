extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g
 g.grill_root=Node3D.new();g.world.add_child(g.grill_root)
 g._add_scraped_debris_pile(Vector3(g.GRILL_CENTER_X,g.GRILL_SURFACE_Y,g.GRILL_SURFACE_Z),.5)
 for i in 100:
  if g.debris_piles.is_empty():break
  var at:Vector3=g.debris_piles[0].root.position
  g._nudge_debris_piles(at,Vector2(.02 if i%2==0 else -.02,0),.02)
 assert(g.debris_piles.is_empty(),"Repeated brushing must remove loose debris")
 g._add_scraped_debris_pile(g._debris_trap_origin(),.5)
 g._nudge_debris_piles(g.debris_piles[0].root.position,Vector2(.001,0),.001)
 assert(g.debris_piles.is_empty(),"Piles swept into the trap must be disposed")
 g.supply_stock={"milk":0,"potato":0}
 g._grant_machine_starter_supplies(g.SHOP_FRYER_MACHINE)
 g._grant_machine_starter_supplies(g.SHOP_ICECREAM_MACHINE)
 assert(g.supply_stock.milk==1 and g.supply_stock.potato==8)
 print("DEBRIS_STARTER_SUPPLIES_OK")
 await create_timer(.25).timeout;g.queue_free();await process_frame;quit()
