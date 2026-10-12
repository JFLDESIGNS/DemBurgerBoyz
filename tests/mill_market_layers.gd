extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var world := Node3D.new()
 root.add_child(world)
 var street = load("res://scenes/mill_market_layers.tscn").instantiate()
 world.add_child(street)
 await process_frame
 assert(street.door_animations.get_animation_list().size() == 6)
 street.open_door()
 street.door_animations.advance(0.85)
 for key in street._hinges:
  var hinge: Node3D = street._hinges[key]
  var axis: Vector3 = street._axes[key]
  assert(hinge.quaternion.is_equal_approx(Quaternion(axis, deg_to_rad(110.0))))
  var leaf: MeshInstance3D = hinge.find_child("*Leaf*",true,false)
  assert(leaf != null)
  var center: Vector3 = leaf.global_transform * leaf.get_aabb().get_center()
  assert(center.z < -0.2, "Door must swing inward")
 street.close_door()
 street.door_animations.advance(0.85)
 for key in street._hinges:
  assert(street._hinges[key].quaternion.is_equal_approx(Quaternion.IDENTITY))
 assert(street.get_node("CanopyForeground").position.z > street.get_node("WalkerLayer").position.z)
 street.open_door()
 street.door_animations.advance(0.85)
 var camera := Camera3D.new()
 camera.position = Vector3(0,-0.8,18)
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 13.3
 world.add_child(camera)
 camera.current = true
 await process_frame
 await process_frame
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://output/mill_layers_godot.png")
  for shot in [["motel",Vector3(4.35,-2.85,6.0),2.4],["old_poodle",Vector3(.5,-2.7,6.0),2.8]]:
   camera.position=shot[1]
   camera.size=shot[2]
   await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://output/"+shot[0]+"_door_open.png")
 print("MILL_LAYERS_OK")
 quit()
