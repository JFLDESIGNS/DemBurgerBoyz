extends RefCounted
static var wet_texture: Texture2D

static func wet_orm() -> Texture2D:
 if wet_texture == null:
  var pixels := Image.create(1,1,false,Image.FORMAT_RGBA8)
  pixels.fill(Color(1.0,0.27,0.0,1.0))
  wet_texture = ImageTexture.create_from_image(pixels)
 return wet_texture

## Sample the visible mesh surface, rather than the customer's broad click target.
static func surface(body: Node3D, point: Vector3, outward: Vector3) -> Dictionary:
 var result := {"position":point,"normal":outward}
 if not is_instance_valid(body): return result
 var start := point + outward * 0.65
 var end := point - outward * 0.85
 var distance := INF
 for node in body.find_children("*","MeshInstance3D",true,false):
  var mesh := node as MeshInstance3D
  if mesh.mesh == null or not mesh.is_visible_in_tree(): continue
  if mesh.mesh is QuadMesh or mesh.mesh is PlaneMesh: continue
  var geometry: Mesh = mesh.mesh
  if mesh.skin != null and DisplayServer.get_name() != "headless" and mesh.get_node_or_null(mesh.skeleton) is Skeleton3D:
   var baked := mesh.bake_mesh_from_current_skeleton_pose()
   if baked != null: geometry = baked
  var triangles := geometry.generate_triangle_mesh()
  if triangles == null: continue
  var hit := triangles.intersect_segment(mesh.to_local(start),mesh.to_local(end))
  if hit.is_empty(): continue
  var pos: Vector3 = mesh.to_global(hit.position)
  var d := start.distance_squared_to(pos)
  if d >= distance: continue
  distance = d
  var normal: Vector3 = (mesh.global_basis.inverse().transposed() * hit.normal).normalized()
  if normal.dot(outward) < 0.0: normal = -normal
  result = {"position":pos + normal * 0.006,"normal":normal}
 return result

static func drop(mesh: MeshInstance3D, parent: Node3D, velocity: Vector3, liquid: bool = false) -> RigidBody3D:
 var pose := mesh.global_transform
 var body := RigidBody3D.new()
 body.name = "SauceDroplet" if liquid else "FallingIngredient"
 body.mass = 0.015 if liquid else 0.045
 body.collision_layer = 0
 body.collision_mask = 1
 body.continuous_cd = true
 body.linear_damp = 0.3
 body.angular_damp = 0.7
 var material := PhysicsMaterial.new()
 material.bounce = 0.12 if liquid else 0.3
 material.friction = 0.8
 body.physics_material_override = material
 parent.add_child(body)
 body.global_transform = pose
 mesh.reparent(body,true)
 var collision := CollisionShape3D.new()
 var shape := BoxShape3D.new()
 var size := mesh.get_aabb().size * mesh.scale.abs()
 shape.size = Vector3(maxf(size.x,0.008),maxf(size.y,0.008),maxf(size.z,0.008))
 collision.shape = shape
 body.add_child(collision)
 body.linear_velocity = velocity
 body.angular_velocity = Vector3(randf_range(-3,3),randf_range(-2,2),randf_range(-4,4))
 var life := 1.5 if liquid else 3.0
 body.get_tree().create_timer(life).timeout.connect(func():
  if is_instance_valid(body): body.queue_free()
 )
 return body
