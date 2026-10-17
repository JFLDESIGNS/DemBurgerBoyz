extends SceneTree
func _initialize():
 var g=load("res://scripts/game.gd").new()
 var dims=g._garbage_tray_dims()
 g.physical_garbage_root=Node3D.new()
 g.add_child(g.physical_garbage_root)
 var bag=g._make_tied_garbage_bag()
 g._apply_tied_bag_sit_transform(bag)
 var body=bag.get_child(0)
 assert(body.material_override is StandardMaterial3D)
 var bounds=body.mesh.get_aabb().size*bag.scale
 assert(bounds.x<float(dims.x) and bounds.z<float(dims.z))
 g._add_garbage_liner(g.physical_garbage_root,dims)
 g.garbage_fill=29
 g._refresh_garbage_liner_fill()
 assert(g.garbage_liner_root.get_node("Sack").scale.x==1.0)
 g.free()
 print("TRASH_BAG_FIT_OK")
 quit()
