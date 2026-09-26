extends TextureRect
var view: SubViewport
var steam: Node3D
var bubbles: Array=[]
var age:=0.0
var identity: Object
var born_ms:=0
func setup(game: Node, source: Object) -> void:
 name="PattyHeatOverlay"
 identity=source
 born_ms=Time.get_ticks_msec()
 if is_instance_valid(source):
  if not source.has_meta("build_heat_started_ms"): source.set_meta("build_heat_started_ms",born_ms)
  born_ms=int(source.get_meta("build_heat_started_ms"))
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 z_index=100
 z_as_relative=false
 expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 stretch_mode=TextureRect.STRETCH_SCALE
 view=SubViewport.new()
 view.size=Vector2i(512,512)
 view.transparent_bg=true
 view.own_world_3d=true
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 add_child(view)
 texture=view.get_texture()
 var camera:=Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.0
 camera.position=Vector3(0,.95,3)
 camera.current=true
 view.add_child(camera)
 var light:=DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-35,-25,0);light.light_energy=1.25
 view.add_child(light)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color("FFD3A1")
 environment.environment.ambient_light_energy=.5
 view.add_child(environment)
 steam=load(game.SMOKE2_SCENE_PATH).instantiate()
 view.add_child(steam)
 steam.scale=Vector3(.85,.72,.85)
 steam.position.y=.75
 var material:=ShaderMaterial.new()
 material.shader=preload("res://shaders/build_burger_vapor.gdshader")
 material.set_shader_parameter("alpha_tex",load(game.SMOKE2_ALPHA_TEX_PATH))
 game._apply_smoke2_materials_recursive(steam,material)
func _process(delta: float) -> void:
 if not is_visible_in_tree():
  if view: view.render_target_update_mode=SubViewport.UPDATE_DISABLED
  return
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 age+=delta
 if is_instance_valid(identity): age=float(Time.get_ticks_msec()-born_ms)/1000.0
 steam.rotate_y(deg_to_rad(-72.0*delta))

func _exit_tree() -> void:
 texture=null
 if is_instance_valid(view): view.render_target_update_mode=SubViewport.UPDATE_DISABLED
