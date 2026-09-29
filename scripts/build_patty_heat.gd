extends TextureRect
var view: SubViewport
var steam: Node3D
var age := 0.0
var identity: Object
var game_ref: Node
var resume_at := 0
var last_screen := Vector2.ZERO
var tracked := false
var born_ms := 0
var render_age := 0.0
const POOL_KEY := "build_vapor_view_pool"
static func prewarm(game: Node) -> void:
 if game.has_meta(POOL_KEY): return
 var pool: Array[SubViewport] = []
 for i in 2:
  pool.append(_make_view(game))
 game.set_meta(POOL_KEY,pool)
static func _make_view(game: Node) -> SubViewport:
 var viewport := SubViewport.new()
 viewport.size=Vector2i(256,256)
 viewport.transparent_bg=true
 viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 game.add_child(viewport)
 var camera:=Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.0
 camera.position=Vector3(0,.95,3);camera.current=true
 viewport.add_child(camera)
 var vapor=load(game.SMOKE2_SCENE_PATH).instantiate()
 vapor.name="Vapor"
 viewport.add_child(vapor)
 vapor.scale=Vector3(.85,.72,.85);vapor.position.y=.75
 var material:=ShaderMaterial.new()
 material.shader=preload("res://shaders/build_burger_vapor.gdshader")
 material.set_shader_parameter("alpha_tex",load(game.SMOKE2_ALPHA_TEX_PATH))
 game._apply_smoke2_materials_recursive(vapor,material)
 return viewport
func setup(game: Node, source: Object) -> void:
 game_ref=game;identity=source;name="PattyHeatOverlay"
 born_ms=Time.get_ticks_msec()
 if is_instance_valid(source):
  if not source.has_meta("build_heat_started_ms"): source.set_meta("build_heat_started_ms",born_ms)
  born_ms=int(source.get_meta("build_heat_started_ms"))
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 z_index=100;z_as_relative=false
 expand_mode=TextureRect.EXPAND_IGNORE_SIZE;stretch_mode=TextureRect.STRETCH_SCALE
func _acquire_view() -> void:
 if is_instance_valid(view): return
 prewarm(game_ref)
 var pool: Array=game_ref.get_meta(POOL_KEY)
 view=_make_view(game_ref) if pool.is_empty() else pool.pop_back()
 texture=view.get_texture();steam=view.get_node("Vapor")
 render_age=1.0
func _release_view() -> void:
 texture=null
 if not is_instance_valid(view): return
 view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 if is_instance_valid(game_ref) and game_ref.has_meta(POOL_KEY):
  var pool: Array=game_ref.get_meta(POOL_KEY)
  if not pool.has(view): pool.append(view)
 view=null;steam=null
func _process(delta: float) -> void:
 age=float(Time.get_ticks_msec()-born_ms)/1000.0
 if not is_visible_in_tree():
  _release_view();return
 var first := true
 var row := get_parent()
 for sibling in row.get_parent().get_children():
  if sibling==row: break
  if sibling is Control and sibling.visible and sibling.has_node("PattyHeatOverlay"): first=false
 var screen := global_position
 var moving: bool = not game_ref._whole_burger_drag.is_empty() or (tracked and screen.distance_to(last_screen)>1.0)
 if moving: resume_at=Time.get_ticks_msec()+450
 last_screen=screen;tracked=true
 var show_steam := first and Time.get_ticks_msec()>=resume_at
 modulate.a=1.0 if show_steam else 0.0
 if not first:
  _release_view();return
 if not show_steam:
  if view: view.render_target_update_mode=SubViewport.UPDATE_DISABLED
  return
 _acquire_view()
 steam.rotate_y(deg_to_rad(-72.0*delta))
 render_age+=delta
 if render_age>=1.0/30.0:
  render_age=fmod(render_age,1.0/30.0)
  view.render_target_update_mode=SubViewport.UPDATE_ONCE
func _exit_tree() -> void:
 _release_view()
