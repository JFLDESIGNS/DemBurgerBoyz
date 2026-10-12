extends Node3D
## Layered street asset. +Z points toward the street/viewer.
## Put walkers in WalkerLayer (z=0.35), behind CanopyForeground (z=0.65).
const ASSETS := "res://assets/backgrounds/mill_market_layers/"
var door_animations: AnimationPlayer
var _hinges: Dictionary = {}
var _axes: Dictionary = {}
var _game: Node = null
var _walker_reflections: ShaderMaterial
var _canopy_shades: Dictionary = {}

func _ready() -> void:
 _layer("CanopyBacking", "canopy_backing.png", -0.01)
 _layer("StreetBackground", "street_base_cutout.png", 0.0)
 var street_windows := _layer("StreetWindows", "street_glass.png", 0.028)
 _walker_reflections = ShaderMaterial.new()
 _walker_reflections.shader = preload("res://shaders/mill_walker_reflections.gdshader")
 _walker_reflections.set_shader_parameter("glass_texture", load(ASSETS + "street_glass.png"))
 street_windows.material_override = _walker_reflections
 var upstairs := _layer("UpperWindows", "upper_glass.png", 0.029)
 var clouds := ShaderMaterial.new()
 clouds.shader = preload("res://shaders/mill_window_clouds.gdshader")
 clouds.set_shader_parameter("glass_texture", load(ASSETS + "upper_glass.png"))
 clouds.set_shader_parameter("cloud_texture", load(ASSETS + "cloud_reflection_tile.png"))
 upstairs.material_override = clouds
 _layer("CanopyForeground", "market_canopy.png", 0.65)
 var walkers := Node3D.new()
 walkers.name = "WalkerLayer"
 walkers.position.z = 0.35
 add_child(walkers)
 var doors := (load(ASSETS + "street_doors.glb") as PackedScene).instantiate() as Node3D
 doors.name = "Doors"
 doors.rotation.x = PI / 2.0 # Undo glTF's Blender-to-Y-up conversion for this XY artwork.
 add_child(doors)
 _painted_materials(doors)
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ASSETS + "layers.json"))
 for spec: Dictionary in data["doors"]:
  var key := "old_poodle" if spec["name"] == "Old_Poodle_Door" else "motel"
  var hinge := doors.find_child(spec["hinge"], true, false) as Node3D
  assert(hinge != null, "Missing door hinge: " + str(spec["hinge"]))
  _hinges[key] = hinge
  var a: Array = spec["axis_gltf"]
  _axes[key] = Vector3(a[0], a[1], a[2]).normalized() * float(spec["direction"])
 door_animations = AnimationPlayer.new()
 door_animations.name = "DoorAnimations"
 add_child(door_animations)
 var library := AnimationLibrary.new()
 for key: String in _hinges:
  library.add_animation(key + "_open", _animation([key], true))
  library.add_animation(key + "_close", _animation([key], false))
 library.add_animation("both_open", _animation(["old_poodle", "motel"], true))
 library.add_animation("both_close", _animation(["old_poodle", "motel"], false))
 door_animations.add_animation_library("", library)

func _layer(node_name: String, texture_name: String, depth: float) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 node.name = node_name
 node.position.z = depth
 var quad := QuadMesh.new()
 quad.size = Vector2(20.48, 11.53)
 node.mesh = quad
 node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var material := StandardMaterial3D.new()
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
 material.alpha_scissor_threshold = 0.4
 material.cull_mode = BaseMaterial3D.CULL_DISABLED
 material.albedo_texture = load(ASSETS + texture_name)
 node.material_override = material
 add_child(node)
 return node

func _animation(keys: Array, opening: bool) -> Animation:
 var animation := Animation.new()
 animation.length = 0.85
 for key: String in keys:
  var track := animation.add_track(Animation.TYPE_VALUE)
  animation.track_set_path(track, NodePath(str(get_path_to(_hinges[key])) + ":quaternion"))
  animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
  var start := 0.0 if opening else deg_to_rad(110.0)
  var end := deg_to_rad(110.0) if opening else 0.0
  for i in range(17):
   var t := float(i) / 16.0
   var ease := t * t * (3.0 - 2.0 * t)
   animation.track_insert_key(track, t * animation.length, Quaternion(_axes[key], lerpf(start, end, ease)))
 return animation

func open_door(door: String = "both") -> void:
 door_animations.play(door + "_open")

func close_door(door: String = "both") -> void:
 door_animations.play(door + "_close")

func _painted_materials(node: Node) -> void:
 if node is MeshInstance3D:
  var mesh_node := node as MeshInstance3D
  mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  for i in mesh_node.mesh.get_surface_count():
   var source := mesh_node.get_active_material(i) as StandardMaterial3D
   if source == null: continue
   var paint := source.duplicate() as StandardMaterial3D
   if paint.albedo_texture == null and paint.emission_enabled:
    paint.albedo_color = paint.emission
   paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
   paint.emission_enabled = false
   mesh_node.set_surface_override_material(i, paint)
 for child in node.get_children():
  _painted_materials(child)

func get_effect_mask(region: String) -> Texture2D:
 var masks := {"windows": "windows_mask.png", "upper_windows": "upper_windows_mask.png", "street_windows": "street_windows_mask.png", "doors": "doors_mask.png", "canopy": "market_canopy_mask.png"}
 if not masks.has(region): return null
 return load(ASSETS + str(masks[region])) as Texture2D

func configure_for_game(game: Node) -> void:
 _game = game
 _update_canopy_depth()

func _process(_delta: float) -> void:
 if is_instance_valid(_game):
  _update_canopy_depth()
  _update_walker_reflections()
  _update_canopy_walker_shade()

func _update_canopy_depth() -> void:
 var camera := get_viewport().get_camera_3d()
 if camera == null: return
 var canopy := get_node_or_null("CanopyForeground") as Node3D
 if canopy == null: return
 # Keep exactly the same projected artwork while putting the canopy ahead of walkers.
 var back := global_transform
 var target_z: float = _game._bg_people_z() - 1.0
 var distance := back.origin.z - camera.global_position.z
 if absf(distance) < 0.1: return
 var ratio := clampf((target_z - camera.global_position.z) / distance, 0.1, 1.0)
 canopy.global_transform = Transform3D(back.basis.scaled(Vector3.ONE * ratio), camera.global_position + (back.origin - camera.global_position) * ratio)

# Only the host chooses doorway traffic; snapshots carry the complete poses and door angles.
var _trip: Dictionary = {}
var _traffic_wait := 10.0

func _door_foot(door: String, depth: float = 0.12) -> Vector3:
 var pixel := Vector2(1070, 930) if door == "old_poodle" else Vector2(1452, 929)
 return to_global(Vector3((pixel.x - 1024.0) / 100.0, (576.5 - pixel.y) / 100.0, depth))

func is_building_walker(walker: Node) -> bool:
 return bool(walker.get_meta("building_trip", false))

func try_building_departure(idx: int, force: bool = false) -> bool:
 if not is_instance_valid(_game) or not _trip.is_empty(): return false
 if _game.mp_enabled and not NetManager.is_host(): return false
 if not force and (_traffic_wait > 0.0 or randf() > 0.28): return false
 var walker: Node3D = _game.bg_people[idx]
 if bool(walker.get_meta("grisaldi", false)) or bool(walker.get_meta("grisaldi_claimed", false)): return false
 var door := "old_poodle" if randf() < 0.5 else "motel"
 var from := _door_foot(door, -0.28)
 var to := Vector3(from.x + float(_game.bg_people_dir[idx]) * 0.8, _game._bg_people_y(), _game._bg_people_z())
 _begin_trip(idx, door, true, from, to)
 return true

func _begin_trip(idx: int, door: String, departing: bool, from: Vector3, to: Vector3) -> void:
 var walker: Node3D = _game.bg_people[idx]
 walker.set_meta("building_trip", true)
 walker._wawa_click_area.collision_layer = 0
 walker.global_position = from
 walker.rotation.y = atan2(to.x - from.x, to.z - from.z)
 _trip = {"index": idx, "door": door, "departing": departing, "time": 0.0, "from": from, "to": to, "closed": false}
 open_door(door)

func cancel_building_traffic() -> void:
 if is_instance_valid(_game):
  for walker in _game.bg_people:
   if is_instance_valid(walker): walker.set_meta("building_trip", false)
 _trip.clear()
 _traffic_wait = 10.0
 door_animations.stop()
 for hinge in _hinges.values(): hinge.quaternion = Quaternion.IDENTITY

func tick_building_traffic(delta: float) -> void:
 if not is_instance_valid(_game): return
 if _game.mp_enabled and not NetManager.is_host(): return
 if not _trip.is_empty():
  var idx := int(_trip["index"])
  if idx >= _game.bg_people.size() or not bool(_game.bg_people_active[idx]):
   cancel_building_traffic()
   return
  var walker: Node3D = _game.bg_people[idx]
  _trip["time"] = float(_trip["time"]) + delta
  var elapsed := float(_trip["time"])
  var u := clampf((elapsed - 0.85) / 2.6, 0.0, 1.0)
  walker.global_position = (_trip["from"] as Vector3).lerp(_trip["to"], u)
  if u >= 1.0 and not bool(_trip["closed"]):
   _trip["closed"] = true
   close_door(str(_trip["door"]))
   if not bool(_trip["departing"]):
    walker.visible = false
    walker._wawa_click_area.collision_layer = 0
  if elapsed >= 4.4:
   walker.set_meta("building_trip", false)
   if bool(_trip["departing"]):
    walker._wawa_click_area.collision_layer = _game.CUSTOMER_WAWA_COLLISION_LAYER
    walker.rotation_degrees.y = 90.0 if float(_game.bg_people_dir[idx]) > 0 else -90.0
   else:
    _game.bg_people_active[idx] = false
    _game.bg_people_wait[idx] = randf_range(8.0, 15.0)
   _trip.clear()
   _traffic_wait = randf_range(12.0, 22.0)
  return
 _traffic_wait -= delta
 if _traffic_wait > 0.0: return
 for idx in _game.bg_people.size():
  if not bool(_game.bg_people_active[idx]) or bool(_game.bg_people_is_run[idx]) or bool(_game.bg_people_is_pair[idx]): continue
  var walker: Node3D = _game.bg_people[idx]
  if bool(walker.get_meta("grisaldi", false)) or bool(walker.get_meta("grisaldi_claimed", false)) or str(walker.get_meta("street_hail", "")) != "": continue
  if int(walker.get_meta("food_stop_until", 0)) > Time.get_ticks_msec(): continue
  for door in ["old_poodle", "motel"]:
   var foot := _door_foot(door, -0.28)
   if absf(walker.global_position.x - foot.x) < 0.4:
    _begin_trip(idx, door, false, walker.global_position, foot)
    return

func traffic_snapshot() -> Dictionary:
 var angles := {}
 for door in _hinges: angles[door] = _hinges[door].quaternion
 return {"angles": angles}

func apply_traffic_snapshot(data: Dictionary) -> void:
 door_animations.stop()
 for door in data.get("angles", {}):
  if _hinges.has(door): _hinges[door].quaternion = data["angles"][door]


func _reflection_uv(world_point: Vector3, camera: Camera3D) -> Vector2:
 var origin := to_local(camera.global_position)
 var point := to_local(world_point)
 var depth := point.z - origin.z
 if absf(depth) < 0.01: return Vector2(-10,-10)
 var hit := origin + (point-origin) * ((0.028-origin.z)/depth)
 return Vector2(hit.x/20.48+0.5, 0.5-hit.y/11.53)

func _update_walker_reflections() -> void:
 var camera := get_viewport().get_camera_3d()
 if camera == null: return
 var people := PackedVector4Array()
 var gait := PackedFloat32Array()
 for i in _game.bg_people.size():
  var walker: Node3D = _game.bg_people[i]
  if not is_instance_valid(walker) or not walker.visible or not bool(_game.bg_people_active[i]): continue
  var height := 1.7 * walker.scale.y
  var feet := _reflection_uv(walker.global_position,camera)
  var head := _reflection_uv(walker.global_position+Vector3.UP*height,camera)
  var side := _reflection_uv(walker.global_position+camera.global_basis.x*height*0.5,camera)
  people.append(Vector4(feet.x,feet.y,maxf(absf(side.x-feet.x)*2.0,.001),maxf(feet.y-head.y,.001)))
  gait.append(Time.get_ticks_msec()*0.001*(9.0 if bool(_game.bg_people_is_run[i]) else 5.0)+i)
  if people.size()==8: break
 var count := people.size()
 people.resize(8)
 gait.resize(8)
 _walker_reflections.set_shader_parameter("people",people)
 _walker_reflections.set_shader_parameter("gait",gait)
 _walker_reflections.set_shader_parameter("person_count",count)


func _update_canopy_walker_shade() -> void:
 var camera := get_viewport().get_camera_3d()
 if camera == null: return
 for i in _game.bg_people.size():
  var walker: Node3D = _game.bg_people[i]
  if not is_instance_valid(walker): continue
  var id := walker.get_instance_id()
  if not _canopy_shades.has(id):
   var shade := ShaderMaterial.new()
   shade.shader = preload("res://shaders/mill_canopy_walker_shade.gdshader")
   var meshes: Array = []
   for mesh in walker.find_children("*", "MeshInstance3D", true, false):
    if mesh.material_overlay != null: continue
    mesh.material_overlay = shade
    meshes.append(mesh)
   _canopy_shades[id] = {"material": shade, "meshes": meshes, "refresh": Time.get_ticks_msec()}
  var material: ShaderMaterial = _canopy_shades[id]["material"]
  if Time.get_ticks_msec() - int(_canopy_shades[id]["refresh"]) > 1000:
   for mesh in walker.find_children("*", "MeshInstance3D", true, false):
    if mesh.material_overlay == null:
     mesh.material_overlay = material
     _canopy_shades[id]["meshes"].append(mesh)
   _canopy_shades[id]["refresh"] = Time.get_ticks_msec()
  var height := 1.7 * walker.scale.y
  var uv := _reflection_uv(walker.global_position + Vector3.UP * height * 0.7, camera)
  var left := smoothstep(455.0/2048.0, 495.0/2048.0, uv.x)
  var right := 1.0 - smoothstep(842.0/2048.0,881.0/2048.0,uv.x)
  var amount := left * right * 0.30 if walker.visible and bool(_game.bg_people_active[i]) else 0.0
  material.set_shader_parameter("upper_body_start",walker.global_position.y+height*.42)
  material.set_shader_parameter("upper_body_end",walker.global_position.y+height*.64)
  material.set_shader_parameter("shade_amount",amount)

func _exit_tree() -> void:
 for entry in _canopy_shades.values():
  for mesh in entry["meshes"]:
   if is_instance_valid(mesh) and mesh.material_overlay == entry["material"]:
    mesh.material_overlay = null
 _canopy_shades.clear()
