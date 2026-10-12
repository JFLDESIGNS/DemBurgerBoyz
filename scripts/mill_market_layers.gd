extends Node3D
## Layered street asset. +Z points toward the street/viewer.
## Put walkers in WalkerLayer (z=0.35), behind CanopyForeground (z=0.65).
const ASSETS := "res://assets/backgrounds/mill_market_layers/"
var door_animations: AnimationPlayer
var _hinges: Dictionary = {}
var _axes: Dictionary = {}
var _game: Node = null

func _ready() -> void:
 _layer("CanopyBacking", "canopy_backing.png", -0.01)
 _layer("StreetBackground", "street_base_cutout.png", 0.0)
 _layer("StreetWindows", "street_glass.png", 0.028)
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
 if is_instance_valid(_game): _update_canopy_depth()

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
