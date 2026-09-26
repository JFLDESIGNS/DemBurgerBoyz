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

static var drip_texture: Texture2D
static func sauce_drip_texture() -> Texture2D:
 if drip_texture!=null:return drip_texture
 var pixels=Image.create(48,128,false,Image.FORMAT_RGBA8)
 for y in 128:
  var t=float(y)/127.0
  var center=.5+sin(t*8.0)*.055
  var width=.10+.08*(1.0-t)+.23*exp(-pow((t-.88)/.105,2.0))
  for x in 48:
   var distance=absf(float(x)/47.0-center)
   var alpha=clampf((width-distance)*80.0,0.0,1.0)*clampf((1.0-t)*24.0,0.0,1.0)*clampf(t*30.0,0.0,1.0)
   pixels.set_pixel(x,y,Color(1,1,1,alpha))
 drip_texture=ImageTexture.create_from_image(pixels)
 return drip_texture


static var sauce_drop_mesh: SphereMesh
static var sauce_drop_materials: Dictionary = {}
static var active_sauce_drops := 0
static func sauce_drop(spot: Decal, parent: Node, tint: Color) -> void:
 if not is_instance_valid(parent) or active_sauce_drops>=36:return
 if sauce_drop_mesh==null:
  sauce_drop_mesh=SphereMesh.new()
  sauce_drop_mesh.radius=.012;sauce_drop_mesh.height=.032
  sauce_drop_mesh.radial_segments=8;sauce_drop_mesh.rings=4
 if not sauce_drop_materials.has(tint):
  var mat:=StandardMaterial3D.new()
  mat.albedo_color=tint;mat.roughness=.24
  mat.emission_enabled=true;mat.emission=tint;mat.emission_energy_multiplier=.4
  sauce_drop_materials[tint]=mat
 var drop:=MeshInstance3D.new()
 drop.name="SauceDroplet"
 drop.mesh=sauce_drop_mesh;drop.material_override=sauce_drop_materials[tint]
 drop.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(drop)
 drop.global_position=spot.global_position+spot.global_basis.z*spot.size.z*.45+spot.global_basis.y*.018
 var start:=drop.global_position
 var velocity:=Vector3(randf_range(-.06,.06),-.08,randf_range(-.03,.03))
 active_sauce_drops+=1
 drop.tree_exiting.connect(func():active_sauce_drops=maxi(0,active_sauce_drops-1))
 var fall:=drop.create_tween()
 fall.tween_method(func(t: float):
  drop.global_position=start+velocity*t+Vector3.DOWN*2.8*t*t
  drop.scale=Vector3.ONE*clampf((.85-t)*6.0,0.0,1.0)
 ,0.0,.85,.85)
 fall.tween_callback(drop.queue_free)


static var sauce_emission_masks: Dictionary = {}
static func sauce_emission_mask(texture: Texture2D) -> Texture2D:
 if texture==null:return null
 if sauce_emission_masks.has(texture):return sauce_emission_masks[texture]
 var pixels:=texture.get_image()
 if pixels.is_compressed():pixels.decompress()
 pixels.convert(Image.FORMAT_RGBA8)
 pixels.premultiply_alpha()
 var mask:=ImageTexture.create_from_image(pixels)
 sauce_emission_masks[texture]=mask
 return mask
