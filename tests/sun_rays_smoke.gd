extends SceneTree
class Fixture extends Node:
 var camera: Camera3D
 var gfx_env: Environment
 var values: Dictionary
 var sun: DirectionalLight3D
func _initialize(): call_deferred("run")
func run():
 var fixture:=Fixture.new()
 root.add_child(fixture)
 fixture.values=load("res://scripts/light_balance.gd").DEFAULTS.duplicate()
 fixture.gfx_env=Environment.new()
 fixture.gfx_env.background_mode=Environment.BG_COLOR
 fixture.gfx_env.background_color=Color(0.12,0.16,0.22)
 var world_env:=WorldEnvironment.new()
 world_env.environment=fixture.gfx_env
 root.add_child(world_env)
 fixture.camera=Camera3D.new()
 root.add_child(fixture.camera)
 fixture.camera.position=Vector3(0,1.7,-3)
 fixture.camera.look_at(Vector3(0,1.7,2))
 fixture.sun=DirectionalLight3D.new()
 root.add_child(fixture.sun)
 fixture.sun.rotation_degrees=Vector3(-25,0,0)
 fixture.sun.shadow_enabled=true
 fixture.sun.light_energy=2.0
 for i in 5:
  var box:=MeshInstance3D.new()
  var mesh:=BoxMesh.new()
  mesh.size=Vector3(0.35,2,0.45)
  box.mesh=mesh
  box.position=Vector3((i-2)*0.8,1.2,1.0)
  root.add_child(box)
 var rays=load("res://scripts/sun_rays.gd").new()
 root.add_child(rays)
 rays.setup(fixture,fixture)
 for mode in [1,2,3,0]:
  fixture.values.rays_mode=mode
  rays.apply()
  assert(rays.screen.visible==(mode==1 or mode==3))
  assert(fixture.gfx_env.volumetric_fog_enabled==(mode==2 or mode==3))
  for i in 45: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/light_balance_release/rays_mode_%d.png"%mode)
 print("SUN_RAYS_OK rendered 2D, 3D, both, off")
 quit()

