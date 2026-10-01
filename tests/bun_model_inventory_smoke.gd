extends SceneTree
func world_bounds(node: Node3D) -> AABB:
 var result=AABB()
 var initialized=false
 for mesh in node.find_children("*","MeshInstance3D",true,false):
  var box: AABB=mesh.global_transform*mesh.mesh.get_aabb()
  result=result.merge(box) if initialized else box
  initialized=true
 return result
func _initialize():call_deferred("run")
func run():
 create_timer(60).timeout.connect(func():quit(1))
 var game=load("res://scenes/main.tscn").instantiate();game.set_script(load("res://tests/grubbah_fixture.gd"));root.add_child(game);current_scene=game
 game._build_bun_inventory_piles(game.world)
 assert(game.bun_pile_stacks.size()==game.BUN_PILE_PAIR_SLOTS)
 game.supply_stock.bun_bottom=game._ingredient_stock_cap("bun_bottom");game.supply_stock.bun_top=game._ingredient_stock_cap("bun_top")
 game._refresh_bun_inventory_piles()
 for pair in game.bun_pile_stacks:
  assert(pair.visible and pair.has_node("Top") and pair.has_node("Bottom") and pair.get_node("BunPairGrab").input_ray_pickable)
  var bottom_box=world_bounds(pair.get_node("Bottom"))
  var top_box=world_bounds(pair.get_node("Top"))
  var bottom=pair.get_node("Bottom")
  var top=pair.get_node("Top")
  assert(is_equal_approx(bottom.scale.y/bottom.scale.x,1.30))
  assert(is_equal_approx(top.scale.y/top.scale.x,1.10))
  assert(absf(top_box.position.y-bottom_box.end.y)<.002,"Bun halves must meet without a gap or overlap")
  for half in [pair.get_node("Top"),pair.get_node("Bottom")]:
   var meshes=half.find_children("*","MeshInstance3D",true,false)
   assert(not meshes.is_empty())
   var material=meshes[0].get_active_material(0)
   assert(material.albedo_texture!=null and material.normal_enabled and material.normal_texture!=null)
  if pair.get_meta("pair_i")==1:
   for lower in game.bun_pile_stacks:
    if lower.get_meta("tower_i")==pair.get_meta("tower_i") and lower.get_meta("pair_i")==0:
     var overlap=world_bounds(lower.get_node("Top")).end.y-bottom_box.position.y
     assert(overlap>0 and overlap<.015*bottom.scale.x,"Stacked pairs nest slightly against the curved crown")
 game.supply_stock.bun_bottom=0;game.supply_stock.bun_top=0;game._refresh_bun_inventory_piles()
 for pair in game.bun_pile_stacks:assert(not pair.visible and not pair.get_node("BunPairGrab").input_ray_pickable)
 print("BUN_INVENTORY_OK")
 game.queue_free();await process_frame;quit()
