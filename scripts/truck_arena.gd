extends "res://scripts/pal_ball_break.gd"
const TRUCK_SIM=preload("res://scripts/truck_arena_simulation.gd")
var stage:Node3D
var chase:Camera3D
var pickup_meshes:Array[Node3D]=[]
var projectile_meshes:Dictionary={}
var hud:Control
var engine:AudioStreamPlayer
var camera_ready:=false
var skid:AudioStreamPlayer
var dust:Array=[]
var dust_time:=0.0
func setup(owner_game:Node,match_id:int,entries:Array,draw_view:bool=true)->void:
 simulation=TRUCK_SIM.new()
 super.setup(owner_game,match_id,entries,draw_view)
 if is_instance_valid(theme):
  theme.stop();theme.stream=preload("res://sounds/boss/concrete_crack_boss.mp3").duplicate();theme.stream.loop=true;theme.volume_db=-13;theme.play()
func _input(event:InputEvent)->void:
 if finished:return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.physical_keycode==KEY_E or event.keycode==KEY_E:burst_queued=true
  if event.physical_keycode==KEY_SPACE or event.keycode==KEY_SPACE:
   if hosting:simulation.jump_for(NetManager.my_id())
   else:game.mp_truck_arena_jump.rpc_id(1,generation)
 if event is InputEventJoypadButton and event.pressed:
  if event.button_index==JOY_BUTTON_X:burst_queued=true
  if event.button_index==JOY_BUTTON_A:
   if hosting:simulation.jump_for(NetManager.my_id())
   else:game.mp_truck_arena_jump.rpc_id(1,generation)
 if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:get_viewport().set_input_as_handled()

func steering()->Vector2:
 var axis:=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)))
 var pads:=Input.get_connected_joypads()
 if not pads.is_empty():axis+=Vector2(Input.get_joy_axis(pads[0],JOY_AXIS_LEFT_X),-Input.get_joy_axis(pads[0],JOY_AXIS_LEFT_Y))
 axis=axis.clamp(Vector2(-1,-1),Vector2.ONE)
 var boosting:=Input.is_physical_key_pressed(KEY_SHIFT)
 if not pads.is_empty():boosting=boosting or Input.is_joy_button_pressed(pads[0],JOY_BUTTON_RIGHT_SHOULDER)
 if boosting and axis.y>.1:axis.y=2.0
 return axis
func _think_bots()->void:
 for entry in roster:
  if entry.get("bot",false):simulation.bot_input(int(entry.id))
func _box(at:Vector3,dimensions:Vector3,color:Color)->MeshInstance3D:
 var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=dimensions;mesh.mesh=box;mesh.material_override=_material(color);mesh.position=at;stage.add_child(mesh);return mesh
func _patty()->MeshInstance3D:
 var mesh:=MeshInstance3D.new();var shape:=CylinderMesh.new();shape.top_radius=.42;shape.bottom_radius=.43;shape.height=.2;shape.radial_segments=16;mesh.mesh=shape;mesh.material_override=_material(Color("773622"));return mesh
func _ramp(center:Vector3,rotation:float,color:Color)->void:
 var mesh:=MeshInstance3D.new();var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var points:=[Vector3(-3,0,0),Vector3(3,0,0),Vector3(3,3.5,6),Vector3(-3,3.5,6),Vector3(-3,0,6),Vector3(3,0,6)]
 for index in [0,2,1,0,3,2,0,4,3,1,2,5]:st.add_vertex(points[index])
 st.generate_normals();mesh.mesh=st.commit();var mat:=_material(color);mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mesh.material_override=mat;mesh.position=center;mesh.rotation.y=rotation;stage.add_child(mesh)
func _build_view()->void:
 layer=CanvasLayer.new();layer.layer=110;add_child(layer)
 var container:=SubViewportContainer.new();container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_STOP;layer.add_child(container)
 viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_2X;container.add_child(viewport)
 stage=Node3D.new();viewport.add_child(stage)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("A5D4EB");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("E9F5FF");env.environment.ambient_light_energy=.55;stage.add_child(env)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-58,-30,0);sun.light_energy=1.2;sun.shadow_enabled=true;stage.add_child(sun)
 var ground:=_box(Vector3(0,-.6,0),Vector3(60,1.2,60),Color.WHITE)
 var asphalt:=ShaderMaterial.new();asphalt.shader=preload("res://shaders/truck_arena_asphalt.gdshader");ground.material_override=asphalt
 for side in [-1,1]:
  for stripe in range(-29,30,2):
   var color:=Color("E7DCC3") if stripe%4==1 else Color("C85D4E")
   _box(Vector3(side*30,.5,stripe),Vector3(.8,1,2),color);_box(Vector3(stripe,.5,side*30),Vector3(2,1,.8),color)
 var colors:=[Color("DE6255"),Color("4D9DD1"),Color("81B85C"),Color("E1B746")];var index:=0
 for sx in [-1.0,1.0]:
  for sz in [-1.0,1.0]:
   var color:Color=colors[index];index+=1
   _box(Vector3(sx*15,1.75,sz*15),Vector3(14,3.5,14),color)
   _box(Vector3(sx*19.3,4.8,sz*19.3),Vector3(3.6,2.6,3.6),color.lightened(.14))
   _ramp(Vector3(sx*2,0,sz*15),PI*.5*sx,color.lightened(.12))
   _ramp(Vector3(sx*15,0,sz*2),0 if sz>0 else PI,color.lightened(.12))
   for stripe in 4:
    _box(Vector3(sx*15,3.515,sz*(9+stripe*.5)),Vector3(4,.035,.15),Color("F7E9BD"))
   for line in range(9,22,2):
    _box(Vector3(sx*line,3.525,sz*15),Vector3(.025,.025,14),color.darkened(.12))
 for side in [-1,1]:
  # Continuous deck above a six-unit drive-through opening.
  _box(Vector3(0,3.2,side*19),Vector3(16,.6,3.6),Color("537E85"))
  _box(Vector3(side*19,3.2,0),Vector3(3.6,.6,16),Color("537E85"))
  for support in [-1,1]:
   _box(Vector3(support*5.5,1.45,side*19),Vector3(5,2.9,3.6),Color("537E85"))
   _box(Vector3(side*19,1.45,support*5.5),Vector3(3.6,2.9,5),Color("537E85"))
  for edge in [-1,1]:
   _box(Vector3(0,3.52,side*19+edge*1.65),Vector3(16,.04,.12),Color("EED180"))
   _box(Vector3(side*19+edge*1.65,3.52,0),Vector3(.12,.04,16),Color("EED180"))
 for entry in roster:
  var root:=Node3D.new();stage.add_child(root)
  var model=preload("res://assets/menu_truck/burger_pals_truck.glb").instantiate();root.add_child(model);model.scale=Vector3.ONE*.22;model.rotation.y=-PI*.5
  var anim=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
  if anim:anim.stop()
  var truck=model.find_child("TruckRoot",true,false) as Node3D;truck.position=Vector3.ZERO;truck.rotation=Vector3.ZERO
  var tag:=Label3D.new();tag.text=str(entry.name);tag.position.y=1.8;tag.font_size=48;tag.pixel_size=.008;tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED;tag.modulate=COLORS[actors.size()%4];root.add_child(tag);tag.hide()
  var wheels:Array=[]
  for part in ["WheelFrontLeft","WheelFrontRight","WheelRearLeft","WheelRearRight"]:wheels.append(model.find_child(part,true,false))
  var ammo_visuals:Array=[]
  for i in TRUCK_SIM.MAX_AMMO:
   var held:=_patty();root.add_child(held);held.scale=Vector3.ONE*.65;held.position=Vector3((i-1)*.62,2.0+(.15 if i==1 else 0.0),0);held.hide();ammo_visuals.append(held)
  actors[int(entry.id)]={"root":root,"model":model,"wheels":wheels,"tag":tag,"ammo":ammo_visuals}
 for pickup in view.pickups:
  var marker:=Node3D.new();stage.add_child(marker);marker.position=pickup.position
  var patty:=_patty();marker.add_child(patty)
  var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.55;torus.outer_radius=.62;torus.rings=24;torus.ring_segments=6;ring.mesh=torus;ring.material_override=_material(Color("FFF194"));ring.position.y=-.5;marker.add_child(ring)
  pickup_meshes.append(marker)
 chase=Camera3D.new();chase.fov=60;chase.current=true;chase.far=130;stage.add_child(chase)
 var canvas:=Control.new();canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(canvas)
 hud=preload("res://scripts/truck_arena_hud.gd").new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.add_child(hud)
 engine=AudioStreamPlayer.new();engine.bus="SFX";engine.volume_db=-28;add_child(engine)
 var sound:=AudioStreamWAV.new();sound.format=AudioStreamWAV.FORMAT_16_BITS;sound.mix_rate=22050;sound.loop_mode=AudioStreamWAV.LOOP_FORWARD;sound.loop_end=22050
 var data:=PackedByteArray();data.resize(44100)
 var motor_rng:=RandomNumberGenerator.new();motor_rng.seed=491
 var filtered:=0.0
 for i in 22050:
  var t:=i/22050.0
  filtered=lerpf(filtered,motor_rng.randf_range(-1,1),.14)
  var firing:=pow(.5+.5*sin(TAU*48*t),5)
  var exhaust:=sin(TAU*48*t)*.35+sin(TAU*96*t)*.22+sin(TAU*192*t)*.1
  var rumble:=exhaust*(.85+.15*sin(TAU*7*t))+filtered*(.12+.42*firing)
  data.encode_s16(i*2,int(clampf(rumble,-1,1)*20000))
 sound.data=data;engine.stream=sound;engine.play()
 skid=AudioStreamPlayer.new();skid.bus="SFX";skid.volume_db=-80;add_child(skid)
 var squeal:AudioStreamMP3=preload("res://sounds/vehicles/mail_truck_tire_screech.mp3").duplicate()
 squeal.loop=true;squeal.loop_offset=.1;skid.stream=squeal;skid.play()
func _render(delta:float,_axis:Vector2)->void:
 if view.is_empty():return
 _play_match_sounds()
 dust_time-=delta
 for item in dust.duplicate():
  item.life-=delta;item.node.position.y+=delta*.25;item.node.scale+=Vector3.ONE*delta*.45
  item.node.transparency=clampf(1-item.life/.55,0,1)
  if item.life<=0:item.node.queue_free();dust.erase(item)
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
  actor.tag.visible=false
  actor.model.rotation.x=lerpf(actor.model.rotation.x,-float(p.get("turn",0))*minf(absf(p.speed),10)*.007,minf(1,delta*9))
  actor.model.position.y=lerpf(actor.model.position.y,sin(float(p.travel)*2.6)*minf(absf(p.speed)*.00045,.006),1-exp(-delta*8))
  for i in actor.ammo.size():
   var held:MeshInstance3D=actor.ammo[i];held.visible=p.alive and i<int(p.ammo);held.position.y=2.0+(.15 if i==1 else 0.0)+sin(Time.get_ticks_msec()*.002+i)*.055;held.rotation.y+=delta*.7
  if p.alive and (p.get("slide",0)>1.0 or p.get("boosting",false)) and dust_time<=0:
   var puff:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.16;sphere.height=.22;sphere.radial_segments=8;sphere.rings=4;puff.mesh=sphere;puff.material_override=_material(Color("8BE6EE") if p.get("boosting",false) else Color("D9DAD3"));stage.add_child(puff);puff.position=p.position+Vector3.UP*.14;dust.append({"node":puff,"life":.55})
  for wheel in actor.wheels:wheel.rotation.z=-float(p.travel)/.18
 if dust_time<=0:dust_time=.065
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
  var focus:Vector3=actors[follow_id].root.position+Vector3.UP*.65
  var goal:=focus-forward*3.8+Vector3.UP*1.65
  goal.y=maxf(goal.y,TRUCK_SIM.height_at(Vector2(goal.x,goal.z),goal.y)+.65)
  chase.position=chase.position.lerp(goal,1-exp(-delta*6)) if camera_ready else goal
  chase.look_at(focus+forward*2.8);camera_ready=true
  var motor_speed:=absf(p.speed)
  var target_pitch:float=.8+fmod(motor_speed,5.0)*.14+floor(motor_speed/5.0)*.09+(.18 if p.get("boosting",false) else 0.0)
  engine.pitch_scale=lerpf(engine.pitch_scale,target_pitch,minf(1,delta*5))
  engine.volume_db=lerpf(engine.volume_db,-27+minf(motor_speed,12)*.5,minf(1,delta*6))
  var slip:float=p.get("slide",0)
  skid.volume_db=lerpf(skid.volume_db,-25+minf(slip,4) if slip>.8 and view.phase=="playing" else -80,minf(1,delta*10))
  skid.pitch_scale=.93+minf(slip,4)*.025
 var mine:Dictionary=view.players.get(NetManager.my_id(),{})
 hud.state=view;hud.mine=mine;hud.won=view.winners.has(NetManager.my_id());hud.queue_redraw()
func _play_match_sounds()->void:
 _prepare_weapon_audio()
 for event in view.get("events",[]):
  if int(event.id)<=last_sound_event:continue
  last_sound_event=int(event.id)
  var kind:String=event.kind
  _arena_sound("cannon" if kind=="shot" else ("patty_pickup" if kind=="pickup" else ("bump" if kind=="hit" else ("burst" if kind=="jump" else kind))),float(event.strength))
 if view.phase=="countdown":
  var number:=int(ceil(3.0-view.clock))
  if number!=countdown_number:countdown_number=number;_arena_sound("ready",.65)

func _broadcast_state() -> void:
 var packet:=var_to_bytes(view)
 game.mp_truck_arena_state.rpc(generation,packet.size(),packet.compress(FileAccess.COMPRESSION_ZSTD))


func _prepare_weapon_audio()->void:
 if sound_cache.has("cannon"):return
 var rate:=22050
 var rng:=RandomNumberGenerator.new();rng.seed=7182
 for kind in ["cannon","patty_pickup"]:
  var duration:=.30 if kind=="cannon" else .24
  var data:=PackedByteArray();data.resize(int(rate*duration)*2)
  var phase:=0.0;var filtered:=0.0
  for i in data.size()/2:
   var t:=float(i)/rate
   var sample:=0.0
   if kind=="cannon":
    filtered=lerpf(filtered,rng.randf_range(-1,1),.3)
    phase+=TAU*lerpf(150,48,minf(t/.16,1))/rate
    sample=sin(phase)*exp(-t*20)*.72+filtered*exp(-t*15)*.65
   else:
    var frequency:=660.0 if t<.09 else 990.0
    phase+=TAU*frequency/rate
    sample=(sin(phase)+sin(phase*2)*.15)*sin(PI*minf(t/.012,1)*.5)*exp(-t*12)*.6
   data.encode_s16(i*2,int(clampf(sample,-1,1)*26000))
  var stream:=AudioStreamWAV.new();stream.mix_rate=rate;stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.data=data;sound_cache[kind]=stream
