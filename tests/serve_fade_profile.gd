extends SceneTree
const Customer = preload("res://scripts/customer.gd")
func _initialize(): call_deferred("run")
func run():
 var world = Node3D.new()
 root.add_child(world)
 var camera = Camera3D.new()
 world.add_child(camera)
 camera.position = Vector3(0,1.8,4.5)
 camera.look_at(Vector3(0,1.3,0))
 var light = DirectionalLight3D.new()
 world.add_child(light)
 var preset = {"format_version":8,"name":"Serve profile","top_catalog_version":1,"top_style":1,"bottom_catalog_version":1,"bottom_style":2,"shoe_catalog_version":1,"shoe_style":1,"hair_style":12,"hat_catalog_version":2,"hat_style":1}
 var customers = Node3D.new()
 world.add_child(customers)
 var samples = []
 for index in 3:
  var c = Customer.new()
  c.setup(["bun_bottom","patty","bun_top"],Color.WHITE,9999,0,0,0,-1,preset,true)
  customers.add_child(c)
  c.set_process(false)
  c.position = Vector3.ZERO
  for frame in 15: await process_frame
  var before = []
  for mesh in c.find_children("*","MeshInstance3D",true,false):
   if mesh.material_override != null: before.append(mesh.material_override)
   elif mesh.mesh != null:
    for surface in mesh.mesh.get_surface_count(): before.append(mesh.get_active_material(surface))
  var start = Time.get_ticks_usec()
  c.complete_serve(12,false)
  var cpu = (Time.get_ticks_usec()-start)/1000.0
  var gaps = []
  var last = Time.get_ticks_usec()
  for frame in 12:
   await process_frame
   var now = Time.get_ticks_usec()
   gaps.append((now-last)/1000.0)
   last = now
  gaps.sort()
  samples.append({"customer":index,"serve_cpu_ms":cpu,"post_serve_max_frame_ms":gaps.back(),"post_serve_median_frame_ms":gaps[6]})
  c.queue_free()
  for frame in 3: await process_frame
 print("SERVE_FADE_PROFILE ",JSON.stringify(samples))
 world.queue_free()
 await process_frame
 quit()
