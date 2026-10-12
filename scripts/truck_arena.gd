extends "res://scripts/pal_ball_break.gd"
const TRUCK_SIM=preload("res://scripts/truck_arena_simulation.gd")
var stage:Node3D
var chase:Camera3D
var pickup_meshes:Array[Node3D]=[]
var projectile_meshes:Dictionary={}
var hud:Label
var center_text:Label
var engine:AudioStreamPlayer
var camera_ready:=false
func setup(owner_game:Node,match_id:int,entries:Array,draw_view:bool=true)->void:
 simulation=TRUCK_SIM.new()
 super.setup(owner_game,match_id,entries,draw_view)
 if is_instance_valid(theme):theme.volume_db=-19
func steering()->Vector2:
 var axis:=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)))
 var pads:=Input.get_connected_joypads()
 if not pads.is_empty():axis+=Vector2(Input.get_joy_axis(pads[0],JOY_AXIS_LEFT_X),-Input.get_joy_axis(pads[0],JOY_AXIS_LEFT_Y))
 return axis.clamp(Vector2(-1,-1),Vector2.ONE)
func _think_bots()->void:
 for entry in roster:
  if entry.get("bot",false):simulation.bot_input(int(entry.id))
func _box(at:Vector3,dimensions:Vector3,color:Color)->MeshInstance3D:
 var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=dimensions;mesh.mesh=box;mesh.material_override=_material(color);mesh.position=at;stage.add_child(mesh);return mesh
func _patty()->MeshInstance3D:
 var mesh:=MeshInstance3D.new();var shape:=CylinderMesh.new();shape.top_radius=.42;shape.bottom_radius=.43;shape.height=.2;shape.radial_segments=16;mesh.mesh=shape;mesh.material_override=_material(Color("773622"));return mesh
func _ramp(center:Vector3,rotation:float,color:Color)->void:
 var mesh:=MeshInstance3D.new();var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var points:=[Vector3(-2.3,0,0),Vector3(2.3,0,0),Vector3(2.3,3,4),Vector3(-2.3,3,4),Vector3(-2.3,0,4),Vector3(2.3,0,4)]
 for index in [0,2,1,0,3,2,0,4,3,1,2,5]:st.add_vertex(points[index])
 st.generate_normals();mesh.mesh=st.commit();var mat:=_material(color);mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mesh.material_override=mat;mesh.position=center;mesh.rotation.y=rotation;stage.add_child(mesh)
func _build_view()->void:
 layer=CanvasLayer.new();layer.layer=110;add_child(layer)
 var container:=SubViewportContainer.new();container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_STOP;layer.add_child(container)
 viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_2X;container.add_child(viewport)
 stage=Node3D.new();viewport.add_child(stage)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("A5D4EB");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("E9F5FF");env.environment.ambient_light_energy=.55;stage.add_child(env)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-58,-30,0);sun.light_energy=1.2;sun.shadow_enabled=true;stage.add_child(sun)
 _box(Vector3(0,-.6,0),Vector3(48,1.2,48),Color("DED7BB"))
 for x in range(-22,24,4):
  for z in range(-22,24,4):
   if (x+z)%8==0:_box(Vector3(x,.005,z),Vector3(4,.01,4),Color("CCC8AF"))
 for side in [-1,1]:
  _box(Vector3(side*24,.6,0),Vector3(.8,1.2,48),Color("F2F0D7"));_box(Vector3(0,.6,side*24),Vector3(48,1.2,.8),Color("F2F0D7"))
 var colors:=[Color("DE6255"),Color("4D9DD1"),Color("81B85C"),Color("E1B746")];var index:=0
 for sx in [-1.0,1.0]:
  for sz in [-1.0,1.0]:
   var color:Color=colors[index];index+=1
   _box(Vector3(sx*12,1.5,sz*12),Vector3(10,3,10),color)
   _box(Vector3(sx*14.8,4.4,sz*14.8),Vector3(3,2.8,3),color.lightened(.18))
   _ramp(Vector3(sx*3,0,sz*12),PI*.5*sx,color.lightened(.15))
   _ramp(Vector3(sx*12,0,sz*3),0 if sz>0 else PI,color.lightened(.15))
   for stripe in 3:_box(Vector3(sx*12,3.02,sz*(8+stripe*.6)),Vector3(3,.035,.2),Color("F7E9BD"))
 for entry in roster:
  var root:=Node3D.new();stage.add_child(root)
  var model=preload("res://assets/menu_truck/burger_pals_truck.glb").instantiate();root.add_child(model);model.scale=Vector3.ONE*.22;model.rotation.y=-PI*.5
  var anim=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
  if anim:anim.stop()
  var truck=model.find_child("TruckRoot",true,false) as Node3D;truck.position=Vector3.ZERO;truck.rotation=Vector3.ZERO
  var tag:=Label3D.new();tag.text=str(entry.name);tag.position.y=1.8;tag.font_size=48;tag.pixel_size=.008;tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED;tag.modulate=COLORS[actors.size()%4];root.add_child(tag)
  var wheels:Array=[]
  for part in ["WheelFrontLeft","WheelFrontRight","WheelRearLeft","WheelRearRight"]:wheels.append(model.find_child(part,true,false))
  actors[int(entry.id)]={"root":root,"model":model,"wheels":wheels,"tag":tag}
 for pickup in view.pickups:
  var marker:=Node3D.new();stage.add_child(marker);marker.position=pickup.position
  var patty:=_patty();marker.add_child(patty)
  var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.55;torus.outer_radius=.62;torus.rings=24;torus.ring_segments=6;ring.mesh=torus;ring.material_override=_material(Color("FFF194"));ring.position.y=-.5;marker.add_child(ring)
  pickup_meshes.append(marker)
 chase=Camera3D.new();chase.fov=66;chase.current=true;chase.far=130;stage.add_child(chase)
 var canvas:=Control.new();canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(canvas)
 hud=_label(canvas,"",25,Vector2(20,18),Vector2(670,70));hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
 center_text=_label(canvas,"",38,Vector2(220,160),Vector2(840,140))
 var instructions:=_label(canvas,"WASD / ARROWS  DRIVE    •    SPACE  SHOOT    •    COLLECT PATTIES",19,Vector2(10,674),Vector2(1260,34))
 instructions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);instructions.offset_top=-44;instructions.offset_bottom=-8
 engine=AudioStreamPlayer.new();engine.bus="SFX";engine.volume_db=-28;add_child(engine)
 var sound:=AudioStreamWAV.new();sound.format=AudioStreamWAV.FORMAT_16_BITS;sound.mix_rate=22050;sound.loop_mode=AudioStreamWAV.LOOP_FORWARD;sound.loop_end=22050
 var data:=PackedByteArray();data.resize(44100)
 for i in 22050:data.encode_s16(i*2,int((sin(TAU*60*i/22050.0)*.5+sin(TAU*120*i/22050.0)*.2)*18000))
 sound.data=data;engine.stream=sound;engine.play()
func _render(delta:float,_axis:Vector2)->void:
 if view.is_empty():return
 _play_match_sounds()
 var follow_id:=NetManager.my_id()
 if not view.players.has(follow_id) or not view.players[follow_id].alive:
  for id in view.players:
   if view.players[id].alive:follow_id=id;break
 for id in view.players:
  if not actors.has(id):continue
  var p:Dictionary=view.players[id];var actor:Dictionary=actors[id]
  actor.root.position=actor.root.position.lerp(p.position,minf(1,delta*18)) if camera_ready else p.position
  actor.root.rotation.y=lerp_angle(actor.root.rotation.y,p.angle,minf(1,delta*16))
  actor.model.visible=p.alive and (p.shield<=0 or int(Time.get_ticks_msec()/80)%2==0)
  actor.tag.text=str(roster.filter(func(e):return int(e.id)==int(id))[0].name)+"  "+str(p.hp)+"/4"
  for wheel in actor.wheels:wheel.rotation.z=-float(p.travel)/.18
 for i in pickup_meshes.size():
  pickup_meshes[i].visible=view.pickups[i].cooldown<=0;pickup_meshes[i].rotation.y+=delta*1.5;pickup_meshes[i].position.y=view.pickups[i].position.y+sin(Time.get_ticks_msec()*.003+i)*.12
 var seen:Dictionary={}
 for shot in view.shots:
  seen[shot.id]=true
  if not projectile_meshes.has(shot.id):
   var mesh:=_patty();stage.add_child(mesh);projectile_meshes[shot.id]=mesh
  var mesh:MeshInstance3D=projectile_meshes[shot.id];mesh.position=shot.position;mesh.rotation.y+=delta*14
 for id in projectile_meshes.keys():
  if not seen.has(id):projectile_meshes[id].queue_free();projectile_meshes.erase(id)
 if view.players.has(follow_id):
  var p:Dictionary=view.players[follow_id];var forward:=Vector3(sin(p.angle),0,cos(p.angle))
  var focus:Vector3=actors[follow_id].root.position+Vector3.UP*1.0
  var goal:=focus-forward*7.8+Vector3.UP*5.5
  goal.y=maxf(goal.y,TRUCK_SIM.height_at(Vector2(goal.x,goal.z))+2.5)
  chase.position=chase.position.lerp(goal,1-exp(-delta*6)) if camera_ready else goal
  chase.look_at(focus+forward*2.2);camera_ready=true
  engine.pitch_scale=.7+absf(p.speed)*.08;engine.volume_db=-30+absf(p.speed)*.6
 var mine:Dictionary=view.players.get(NetManager.my_id(),{})
 hud.text="TRUCK ARENA
"+("ARMOR  "+str(mine.get("hp",0))+" / 4     PATTIES  "+str(mine.get("ammo",0))+" / 6" if mine.get("alive",false) else "SPECTATING")
 center_text.text=""
 if view.phase=="waiting":center_text.text="WAITING FOR DRIVERS"
 elif view.phase=="countdown":center_text.text="FOUR HITS AND YOU'RE OUT!
"+str(maxi(1,int(ceil(3.0-view.clock))))
 elif view.phase=="results":
  var names:Array[String]=[]
  for entry in roster:
   if view.winners.has(int(entry.id)):names.append(str(entry.name))
  center_text.text=(names[0]+" WINS!" if names.size()==1 else "DRAW!")+"
BACK TO THE TRUCK"
func _play_match_sounds()->void:
 for event in view.get("events",[]):
  if int(event.id)<=last_sound_event:continue
  last_sound_event=int(event.id)
  var kind:String=event.kind
  _arena_sound("burst" if kind=="shot" else ("ready" if kind=="pickup" else ("bump" if kind=="hit" else kind)),float(event.strength))
 if view.phase=="countdown":
  var number:=int(ceil(3.0-view.clock))
  if number!=countdown_number:countdown_number=number;_arena_sound("ready",.65)

func _broadcast_state() -> void:
 var packet:=var_to_bytes(view)
 game.mp_truck_arena_state.rpc(generation,packet.size(),packet.compress(FileAccess.COMPRESSION_ZSTD))
