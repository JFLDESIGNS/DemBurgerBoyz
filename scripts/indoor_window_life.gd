extends Node3D
const ASSETS="res://assets/backgrounds/mill_market_layers/"
var windows: Dictionary={}
var events: Array=[]
var wait_left:=1.5
var game: Node
var door_cues: Dictionary={}
var recent_cat_windows: Array[String]=[]
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
  mat.set_shader_parameter("floor_y",1.32 if float(rect[1])<1600.0 else 1.25)
  mat.set_shader_parameter("aspect",float(rect[2])/float(rect[3]))
  mat.set_shader_parameter("window_mask",load(ASSETS+str(spec.mask)))
  mesh.material_override=mat
  mesh.visible=false
  add_child(mesh)
  windows[str(spec.name)]={"mesh":mesh,"material":mat,"door":bool(spec.door_glass)}
func cue_door(door: String,amount: float) -> void:
 var key: String={"motel":"Motel_Door","old_poodle":"Poodle_Door_Glass"}.get(door,"")
 if not windows.has(key): return
 door_cues[key]=amount
 render_events()

func _render_door_cue(key: String,amount: float) -> void:
 var entry: Dictionary=windows[key]
 entry.mesh.visible=amount>.001
 entry.material.set_shader_parameter("cat",false)
 entry.material.set_shader_parameter("drift",(1.0-amount)*.20)
 entry.material.set_shader_parameter("depth_scale",lerpf(.62,1.0,amount))
 entry.material.set_shader_parameter("depth_lift",(1.0-amount)*.14)
 entry.material.set_shader_parameter("opacity",amount*.52)
func tick(delta: float,authority: bool,active: bool) -> void:
 if not active: return
 for event in events:
  event.age+=delta
 events=events.filter(func(e):return e.age<e.duration)
 if authority:
  wait_left-=delta
  if wait_left<=0.0 and events.size()<3:
   var is_cat := randf()<.55
   var choices: Array=[]
   for key in windows:
    if float(door_cues.get(key,0.0))<=.001 and key != "Motel_Transom" and not events.any(func(e):return e.key==key): choices.append(key)
   if is_cat:
    var fresh := choices.filter(func(key):return not recent_cat_windows.has(str(key)))
    if not fresh.is_empty(): choices=fresh
   if not choices.is_empty():
    var chosen: String=choices.pick_random()
    if is_cat:
     recent_cat_windows.append(chosen)
     if recent_cat_windows.size()>3: recent_cat_windows.pop_front()
    events.append({"key":chosen,"age":0.0,"duration":randf_range(5.0,8.0),"variant":randi_range(0,1),"cat":is_cat,"move":randf()<.65,"direction":-1.0 if randf()<.5 else 1.0})
   wait_left=randf_range(2.5,4.5)
 render_events()
func render_events() -> void:
 for key in windows:
  windows[key].mesh.visible=false
 for event in events:
  if not windows.has(event.key): continue
  var entry: Dictionary=windows[event.key]
  var age:=float(event.age)
  var duration:=float(event.duration)
  var retreat:=smoothstep(duration-2.6,duration,age)
  var approach:=smoothstep(0.0,1.2,age)
  # Walk diagonally back into the room before fading into its depth.
  var fade:=approach*(1.0-smoothstep(.65,1.0,retreat))
  entry.material.set_shader_parameter("depth_scale",lerpf(.82,1.0,approach)*lerpf(1.0,.46,retreat))
  entry.material.set_shader_parameter("depth_lift",retreat*.18)

  entry.mesh.visible=fade>.001
  entry.material.set_shader_parameter("opacity",fade*.52)
  entry.material.set_shader_parameter("cat",bool(event.cat))
  entry.material.set_shader_parameter("variant",float(event.get("variant",0)))
  entry.material.set_shader_parameter("phase",float(event.age)*2.0)
  entry.material.set_shader_parameter("drift",(sin(age/duration*PI*2.0)*.18 if event.move else sin(age*1.4)*.025)*(1.0-retreat)+retreat*.38*float(event.direction))
 for key in door_cues:
  if float(door_cues[key])>.001: _render_door_cue(key,float(door_cues[key]))
func reset() -> void:
 door_cues.clear()
 events.clear()
 recent_cat_windows.clear()
 for entry in windows.values(): entry.mesh.visible=false
