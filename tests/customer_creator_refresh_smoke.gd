extends SceneTree
var failures: Array[String] = []
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
 if not ok: failures.append(message)
func run():
 root.size = Vector2i(1100,720)
 root.content_scale_size = root.size
 var c = load("res://scenes/character_creator/character_creator.tscn").instantiate()
 root.add_child(c)
 for i in 8: await process_frame
 var studio = c._studio
 check(c.save_button.text == "Save customer","Save label")
 check(c.character.get_world_3d() != root.world_3d,"Creator must be isolated from game world")
 check(studio.stage_truck != null,"Optimized background truck missing")
 check(studio.stage_truck.find_child("TruckRoot",true,false).position == Vector3.ZERO,"Truck driving offset must be reset")
 for category in ["Hair","Accessories"]:
  studio.select_category(category)
  var key = "Hair" if category == "Hair" else "Hats"
  var count = studio.selectors[key].item_count
  for i in count:
   studio.select_style(key,i)
   for frame in 3: await process_frame
   studio.frame_view("Face")
   var bounds = studio.head_bounds(c.character)
   for corner in 8:
    var point = c.camera.unproject_position(bounds.get_endpoint(corner))
    check(point.x >= studio.stage_rect.position.x and point.x <= studio.stage_rect.end.x,"Head width clipped %s %d" % [key,i])
    check(point.y >= studio.stage_rect.position.y and point.y <= studio.stage_controls.position.y,"Head height clipped %s %d" % [key,i])
  studio.catalog_query[key] = ""
  for turn in ceili(count/3.0):
   var visible = 0
   for card in studio.cards[key]:
    if card.button.visible: visible += 1
   check(visible > 0 and visible <= 3,"Three styles per page")
   studio.catalog_turn(key,1)
  studio.catalog_query[key] = "no_such_style_123"
  studio.filter_catalog(key)
  check(studio.catalog_counters[key].text == "No matching styles","Search empty state")
  check(studio.catalog_arrows[key][0].disabled and studio.catalog_arrows[key][1].disabled,"Empty search arrows")
 c.character.hat_style = 1
 c.character.hat_color = Color.WHITE
 for i in 3: await process_frame
 for mesh in c.character.get("_hat_root").find_children("*","MeshInstance3D",true,false):
  for surface in mesh.mesh.get_surface_count():
   var mat = mesh.get_active_material(surface)
   check(is_equal_approx(mat.albedo_color.r,mat.albedo_color.g) and is_equal_approx(mat.albedo_color.g,mat.albedo_color.b),"Hat neutral base")
 var footwear = load("res://scripts/fitted_footwear.gd")
 var source = StandardMaterial3D.new()
 source.albedo_color = Color(0.8,0.1,0.3)
 var recolored = footwear.shoe_material(source,Color(0.2,0.4,0.8))
 check(is_equal_approx(recolored.albedo_color.b,recolored.albedo_color.r*4),"Shoe tint must replace authored hue")
 check(source.albedo_color == Color(0.8,0.1,0.3),"Source materials must remain unchanged")
 c.queue_free()
 for i in 3: await process_frame
 if failures.is_empty(): print("CUSTOMER_CREATOR_REFRESH_OK")
 else:
  for failure in failures: push_error(failure)
 quit(0 if failures.is_empty() else 1)
