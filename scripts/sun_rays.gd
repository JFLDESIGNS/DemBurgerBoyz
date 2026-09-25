extends Node3D
var game: Node
var balance: Node
var screen: MeshInstance3D
var volume: FogVolume
var material: ShaderMaterial
func setup(g: Node, b: Node) -> void:
 game=g
 balance=b
 screen=MeshInstance3D.new()
 screen.name="DepthOccluded2DRays"
 var quad:=QuadMesh.new()
 quad.size=Vector2(2,2)
 screen.mesh=quad
 screen.extra_cull_margin=16384.0
 screen.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 material=ShaderMaterial.new()
 material.shader=load("res://shaders/sun_rays_screen.gdshader")
 material.render_priority=90
 screen.material_override=material
 add_child(screen)
 volume=FogVolume.new()
 volume.name="Window3DRays"
 volume.size=Vector3(5.5,3.0,5.5)
 volume.position=Vector3(0,1.8,0.6)
 volume.material=FogMaterial.new()
 add_child(volume)
 apply()
func apply() -> void:
 if not is_instance_valid(screen): return
 var v: Dictionary=balance.values
 var mode:=int(v.rays_mode)
 screen.visible=mode==1 or mode==3
 volume.visible=mode==2 or mode==3
 material.set_shader_parameter("strength",v.rays_strength)
 material.set_shader_parameter("reach",v.rays_reach)
 material.set_shader_parameter("blocker_distance",v.rays_blocker_distance)
 material.set_shader_parameter("ray_color",v.rays_color)
 volume.material.density=float(v.rays_density)
 volume.material.albedo=v.rays_color
 var env: Environment=game.gfx_env
 if env!=null:
  env.volumetric_fog_enabled=volume.visible
  env.volumetric_fog_density=0.0
  env.volumetric_fog_length=float(v.rays_length)
  env.volumetric_fog_ambient_inject=0.0
  env.volumetric_fog_sky_affect=1.0
  env.volumetric_fog_anisotropy=0.55
 if is_instance_valid(balance.sun):
  balance.sun.light_volumetric_fog_energy=float(v.rays_strength)*5.0
func _process(_delta: float) -> void:
 if not is_instance_valid(game.camera) or not is_instance_valid(screen): return
 screen.global_position=game.camera.global_position
 if not screen.visible: return
 var v: Dictionary=balance.values
 var pos: Vector2=Vector2(float(v.rays_x),float(v.rays_y))
 var visibility:=1.0
 if bool(v.rays_follow_sun) and is_instance_valid(balance.sun):
  var point: Vector3=game.camera.global_position+balance.sun.global_basis.z*30.0
  if game.camera.is_position_behind(point): visibility=0.0
  else: pos=game.camera.unproject_position(point)/get_viewport().get_visible_rect().size
 material.set_shader_parameter("source_uv",pos)
 material.set_shader_parameter("source_visibility",visibility)
