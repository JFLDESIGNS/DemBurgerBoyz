extends Node3D
const ASSETS="res://assets/backgrounds/mill_market_layers/"
var windows: Dictionary={}
var events: Array=[]
var wait_left:=1.5
var game: Node
func setup(data: Dictionary) -> void:
 for spec in data.windows:
  var rect: Array=spec.pixel_rect
  var mesh:=MeshInstance3D.new()
  mesh.name="Indoor_"+str(spec.name)
  var quad:=QuadMesh.new()
  quad.size=Vector2(float(rect[2])/4778.0*20.48,float(rect[3])/2689.0*11.53)
  mesh.mesh=quad
  mesh.position=Vector3((float(rect[0])+float(rect[2])*.5)/4778.0*20.48-10.24,5.765-(float(rect[1])+float(rect[3])*.5)/2689.0*11.53,.046)
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var mat:=ShaderMaterial.new()
  mat.shader=preload("res://shaders/indoor_window_silhouette.gdshader")
  mat.set_shader_parameter("silhouette_atlas",preload("res://assets/backgrounds/mill_market_layers/indoor_silhouette_atlas.png"))
  mat.set_shader_parameter("aspect",float(rect[2])/float(rect[3]))
  mat.set_shader_parameter("window_mask",load(ASSETS+str(spec.mask)))
  mesh.material_override=mat
  mesh.visible=false
  add_child(mesh)
  windows[str(spec.name)]={"mesh":mesh,"material":mat,"door":bool(spec.door_glass)}
func cue_door(door: String,amount: float) -> void:
 var key: String={"motel":"Motel_Door","old_poodle":"Poodle_Door_Glass"}.get(door,"")
 if not windows.has(key): return
 var entry: Dictionary=windows[key]
 entry.mesh.visible=amount>.001
 entry.material.set_shader_parameter("cat",false)
 entry.material.set_shader_parameter("drift",0.0)
 entry.material.set_shader_parameter("opacity",amount*.72)
func tick(delta: float,authority: bool,active: bool) -> void:
 if not active: return
 for event in events:
  event.age+=delta
 events=events.filter(func(e):return e.age<e.duration)
 if authority:
  wait_left-=delta
  if wait_left<=0.0 and events.size()<3:
   var choices: Array=[]
   for key in windows:
    if not windows[key].door and not events.any(func(e):return e.key==key): choices.append(key)
   if not choices.is_empty(): events.append({"key":choices.pick_random(),"age":0.0,"duration":randf_range(5.0,8.0),"variant":randi_range(0,1),"cat":randf()<.35,"move":randf()<.65,"direction":-1.0 if randf()<.5 else 1.0})
   wait_left=randf_range(2.5,4.5)
 render_events()
func render_events() -> void:
 for key in windows:
  if not windows[key].door: windows[key].mesh.visible=false
 for event in events:
  if not windows.has(event.key): continue
  var entry: Dictionary=windows[event.key]
  var fade:=smoothstep(0.0,1.2,float(event.age))*(1.0-smoothstep(float(event.duration)-1.4,float(event.duration),float(event.age)))
  entry.mesh.visible=fade>.001
  entry.material.set_shader_parameter("opacity",fade*.76)
  entry.material.set_shader_parameter("cat",bool(event.cat))
  entry.material.set_shader_parameter("variant",float(event.get("variant",0)))
  entry.material.set_shader_parameter("phase",float(event.age)*2.0)
  entry.material.set_shader_parameter("drift",sin(float(event.age)/float(event.duration)*PI*2.0)*.18*float(event.direction) if event.move else 0.0)
func reset() -> void:
 events.clear()
 for entry in windows.values(): entry.mesh.visible=false
