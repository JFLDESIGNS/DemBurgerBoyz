extends Node
const SIM = preload("res://scripts/pal_ball_simulation.gd")
const COLORS = [Color("FFB348"),Color("61DCEE"),Color("B0E96A"),Color("F78AC4")]
var game: Node
var generation := 0
var roster: Array = []
var simulation = SIM.new()
var hosting := false
var ready_peers: Dictionary = {}
var view: Dictionary = {}
var actors: Dictionary = {}
var layer: CanvasLayer
var arena: MeshInstance3D
var rim: MeshInstance3D
var viewport: SubViewport
var title: Label
var status: Label
var timer_label: Label
var legend: Label
var help: Label
var prior_pause := false
var net_process_mode := Node.PROCESS_MODE_INHERIT
var fixed_time := 0.0
var send_time := 0.0
var retry_time := 0.0
var waited := 0.0
var last_sequence := -1
var finished := false
var burst_queued := false
var touch_origin := Vector2.ZERO
var touch_direction := Vector2.ZERO
var touch_down := false
var visual_enabled := true
var bot_think := 0.0

func setup(owner_game: Node, match_id: int, entries: Array, draw_view: bool = true) -> void:
 game=owner_game;generation=match_id;roster=entries.duplicate(true);hosting=not game.mp_enabled or NetManager.is_host();visual_enabled=draw_view
 process_mode=Node.PROCESS_MODE_ALWAYS
 simulation.setup(roster);view=simulation.snapshot()
 prior_pause=get_tree().paused;net_process_mode=NetManager.process_mode
 NetManager.process_mode=Node.PROCESS_MODE_ALWAYS
 if draw_view:_build_view()
 get_tree().paused=true
 if hosting:
  ready_peers[NetManager.my_id()]=true
  for entry in roster:
   if bool(entry.get("bot",false)):ready_peers[int(entry.id)]=true
 elif NetManager.is_online():game.mp_pal_ball_ready.rpc_id(1,generation)
 set_process(true)

func _input(event: InputEvent) -> void:
 if finished:return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_SPACE:burst_queued=true
 if event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_A:burst_queued=true
 if event is InputEventScreenTouch:
  touch_down=event.pressed;touch_origin=event.position;touch_direction=Vector2.ZERO
 if event is InputEventScreenDrag and touch_down:touch_direction=(event.position-touch_origin).limit_length(90.0)/90.0
 if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventScreenTouch:
  get_viewport().set_input_as_handled()

func steering() -> Vector2:
 var axis:=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
 var pads:=Input.get_connected_joypads()
 if not pads.is_empty():
  var stick:=Vector2(Input.get_joy_axis(pads[0],JOY_AXIS_LEFT_X),Input.get_joy_axis(pads[0],JOY_AXIS_LEFT_Y))
  if stick.length()>.18:axis+=stick
 if touch_down:axis+=touch_direction
 return axis.limit_length(1.0)

func _process(delta: float) -> void:
 if finished:return
 if game.mp_enabled and not NetManager.is_online():finish();return
 var axis:=steering()
 send_time-=delta;retry_time-=delta
 if hosting:
  if game.mp_enabled:game._mp_service_bootstrap() # Joining cooks can finish loading while the kitchen is frozen.
  var peers:=NetManager.connected_peer_ids()
  for id in simulation.players:
   if int(id)>0 and not peers.has(int(id)):simulation.drop_peer(int(id));ready_peers[id]=true
  if simulation.phase=="waiting":
   waited+=delta
   var all_ready:=true
   for id in simulation.players:
    if not ready_peers.has(id):all_ready=false
   if all_ready or waited>15.0:
    for id in simulation.players:
     if not ready_peers.has(id):simulation.drop_peer(int(id))
    simulation.begin_countdown()
  simulation.input_for(NetManager.my_id(),axis,burst_queued);burst_queued=false
  bot_think-=delta
  if bot_think<=0:
   bot_think=.16;_think_bots()
  fixed_time+=minf(delta,.15)
  while fixed_time>=1.0/60.0:
   simulation.step(1.0/60.0);fixed_time-=1.0/60.0
  view=simulation.snapshot()
  if send_time<=0:
   send_time=.05
   if game.mp_enabled:game.mp_pal_ball_state.rpc(generation,view)
  if retry_time<=0 and game.mp_enabled:
   retry_time=1.0
   for id in peers:
    if id!=NetManager.my_id() and not ready_peers.has(id):game.mp_pal_ball_begin.rpc_id(id,generation,roster,view)
  if simulation.phase=="results" and simulation.clock>=4.0:
   if game.mp_enabled:game.mp_pal_ball_end.rpc(generation)
   else:game.mp_pal_ball_end(generation)
   return
 else:
  if send_time<=0:
   send_time=.033;game.mp_pal_ball_input.rpc_id(1,generation,axis,burst_queued);burst_queued=false
 if visual_enabled:_render(delta,axis)

func apply_state(data: Dictionary) -> void:
 if hosting or int(data.get("sequence",-1))<=last_sequence:return
 last_sequence=int(data.sequence);view=data.duplicate(true)

func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
 var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.5;mat.metallic=metallic;return mat

func _label(parent: Control, text: String, size: int, pos: Vector2, area: Vector2) -> Label:
 var label:=Label.new();label.text=text;label.position=pos;label.size=area
 label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 label.add_theme_font_override("font",preload("res://assets/fonts/Nunito-ExtraBold.ttf"))
 label.add_theme_font_size_override("font_size",size)
 label.add_theme_color_override("font_color",Color("FFF0C4"))
 label.add_theme_color_override("font_shadow_color",Color("10233F"));label.add_theme_constant_override("shadow_offset_y",3)
 parent.add_child(label);return label

func _build_view() -> void:
 layer=CanvasLayer.new();layer.layer=110;add_child(layer)
 var container:=SubViewportContainer.new();container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_STOP;layer.add_child(container)
 viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(viewport)
 var stage:=Node3D.new();viewport.add_child(stage)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("162D49");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("B9D9EB");env.environment.ambient_light_energy=.3;stage.add_child(env)
 var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(0,8.2,13.8);camera.look_at(Vector3(0,.2,0));camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=47.0;camera.current=true
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-35,0);sun.light_energy=.85;sun.shadow_enabled=true;stage.add_child(sun)
 arena=MeshInstance3D.new();var disk:=CylinderMesh.new();disk.top_radius=SIM.START_RADIUS;disk.bottom_radius=SIM.START_RADIUS;disk.height=1.1;disk.radial_segments=96;arena.mesh=disk;arena.material_override=_material(Color("23666E"));arena.position.y=-.55;stage.add_child(arena)
 rim=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=SIM.START_RADIUS-.09;torus.outer_radius=SIM.START_RADIUS+.09;rim.mesh=torus;rim.material_override=_material(Color("FFCC70"),.25);rim.position.y=.025;stage.add_child(rim)
 _decorate_arena(stage)
 for i in roster.size():
  var entry:Dictionary=roster[i];var color:Color=COLORS[i%4]
  var actor:=Node3D.new();stage.add_child(actor)
  var ball:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=SIM.BALL_RADIUS;sphere.height=SIM.BALL_RADIUS*2.0;sphere.radial_segments=32;sphere.rings=16;ball.mesh=sphere;ball.material_override=_material(color,.12);actor.add_child(ball)
  var band:=MeshInstance3D.new();var stripe:=TorusMesh.new();stripe.inner_radius=.505;stripe.outer_radius=.537;stripe.rings=32;stripe.ring_segments=8;band.mesh=stripe;band.material_override=_material(color.lightened(.65));ball.add_child(band)
  var pal=game.CustomerScript.new();pal.set_meta("delivery_driver",true);pal.is_street_pedestrian=true
  pal.setup(["bun_bottom","patty","bun_top"] as Array[String],color,9999.0,0,int(entry.skin),-1,-1,{},true)
  actor.add_child(pal);pal.set_process(false);pal.set_physics_process(false)
  pal.scale=Vector3.ONE*.85;pal.position=Vector3(0,SIM.BALL_RADIUS,0);pal.play_street_run(.8)
  for label in pal.find_children("*","Label3D",true,false):label.hide()
  var name_tag:=Label3D.new();name_tag.text=str(entry.name)+( "  YOU" if int(entry.id)==NetManager.my_id() else "");name_tag.font_size=40;name_tag.pixel_size=.007;name_tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED;name_tag.position.y=2.7;name_tag.modulate=color;name_tag.outline_size=9;actor.add_child(name_tag)
  actors[int(entry.id)]={"root":actor,"ball":ball,"pal":pal,"tag":name_tag}
 var ui:=Control.new();ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(ui)
 # A fixed design canvas scales with the window without changing arena input.
 var canvas:=Control.new();ui.add_child(canvas)
 var resize:=func():canvas.scale=ui.size/Vector2(1280,720)
 ui.resized.connect(resize);resize.call()
 title=_label(canvas,"MIDDAY BREAK  /  BUMPER PALS",32,Vector2(0,18),Vector2(1280,45))
 timer_label=_label(canvas,"",28,Vector2(1080,78),Vector2(165,45))
 status=_label(canvas,"",38,Vector2(80,78),Vector2(1120,65))
 legend=_label(canvas,"",20,Vector2(60,595),Vector2(1160,35))
 help=_label(canvas,"WASD / ARROWS / LEFT STICK: ROLL    •    SPACE / A: BUMP BURST",19,Vector2(20,638),Vector2(1240,35))
 _label(canvas,"Bump the other pals off. Last pal standing wins. Your kitchen is paused.",18,Vector2(30,677),Vector2(1220,28))

func _render(delta: float, axis: Vector2) -> void:
 if view.is_empty():return
 var scale_factor:float=float(view.radius)/SIM.START_RADIUS
 arena.scale=Vector3(scale_factor,1,scale_factor);rim.scale=arena.scale
 var names:Array[String]=[]
 for entry in roster:
  var id:=int(entry.id)
  if not view.players.has(id):continue
  var p:Dictionary=view.players[id];var visual:Dictionary=actors[id]
  var point:Vector2=p.position
  if not hosting and id==NetManager.my_id() and p.alive and view.phase=="playing":point+=axis*.09
  var height:=SIM.BALL_RADIUS-float(p.fall)*float(p.fall)*7.0
  var goal:=Vector3(point.x,height,point.y)
  visual.root.position=visual.root.position.lerp(goal,minf(1.0,delta*20.0)) if last_sequence>=0 or hosting else goal
  visual.root.visible=float(p.fall)<1.4
  var velocity:Vector2=p.velocity
  if velocity.length()>.08:
   visual.ball.rotate(Vector3(velocity.y,0,-velocity.x).normalized(),velocity.length()*delta/SIM.BALL_RADIUS)
   visual.pal.rotation.y=lerp_angle(visual.pal.rotation.y,atan2(velocity.x,velocity.y),minf(1.0,delta*10.0))
  visual.pal.rotation.z=-velocity.x*.035;visual.pal.rotation.x=velocity.y*.025
  if is_instance_valid(visual.pal._anim_player):visual.pal._anim_player.speed_scale=clampf(velocity.length()*.3,.05,1.8)
  names.append(str(entry.name)+( "  OUT" if not p.alive else ""))
 legend.text="     •     ".join(names)
 timer_label.text="%02d SEC" % int(ceil(float(view.left)))
 match str(view.phase):
  "waiting":status.text="Everyone ready?";timer_label.text="GET READY"
  "countdown":status.text="ROLL IN  %d" % maxi(1,int(ceil(4.0-float(view.clock))));timer_label.text="GET READY"
  "playing":
   var mine:Dictionary=view.players.get(NetManager.my_id(),{})
   if mine.is_empty() or not bool(mine.get("alive",false)):status.text="You're watching — cheer on your pal!"
   else:status.text="WATCH THE EDGE!" if float(view.left)<=20.0 else "BUMP THEM OFF!"
   if not mine.is_empty():help.text="WASD / ARROWS / LEFT STICK: ROLL    •    "+("SPACE / A: BURST READY" if float(mine.cooldown)<=0 else "BURST RECHARGING %.1fs" % float(mine.cooldown))
  "results":
   var winning:Array[String]=[]
   for entry in roster:
    if view.winners.has(int(entry.id)):winning.append(str(entry.name))
   status.text=(winning[0]+" WINS!" if winning.size()==1 else "DRAW — NICE BUMPING!")
   timer_label.text="BACK TO WORK"

func finish() -> void:
 if finished:return
 finished=true
 if is_instance_valid(game):game._pal_ball_finished_serial=maxi(game._pal_ball_finished_serial,generation)
 get_tree().paused=prior_pause
 NetManager.process_mode=net_process_mode
 queue_free()

func _exit_tree() -> void:
 if not finished:
  if get_tree():get_tree().paused=prior_pause
  if is_instance_valid(NetManager):NetManager.process_mode=net_process_mode


func _think_bots() -> void:
 for entry in roster:
  if not bool(entry.get("bot",false)):continue
  var id:=int(entry.id)
  var me:Dictionary=simulation.players[id]
  if not me.alive:continue
  var target:=Vector2.ZERO
  var nearest:=INF
  for other_id in simulation.players:
   if other_id==id or not simulation.players[other_id].alive:continue
   var other:Dictionary=simulation.players[other_id]
   var distance:float=me.position.distance_to(other.position)
   if distance<nearest:nearest=distance;target=other.position+other.velocity*.12
  var direction:Vector2=(target-me.position).normalized()
  var radial:Vector2=me.position
  var margin:float=simulation.arena_radius-radial.length()
  if margin<1.15:direction=(direction*.25-radial.normalized()*1.5).normalized()
  else:direction=direction.rotated(sin(simulation.clock*1.6)*.14)
  simulation.input_for(id,direction,nearest<1.75 and margin>1.5 and randf()<.35)

func _decorate_arena(stage: Node3D) -> void:
 # Recessed sides and alternating rim bolts give the floating platform depth.
 var under:=MeshInstance3D.new();var base:=CylinderMesh.new();base.top_radius=4.25;base.bottom_radius=3.75;base.height=.55;base.radial_segments=64;under.mesh=base;under.material_override=_material(Color("172E48"));under.position.y=-1.3;arena.add_child(under)
 under.position.y=-.75
 for i in 16:
  var bolt:=MeshInstance3D.new();var bead:=SphereMesh.new();bead.radius=.065;bead.height=.13;bolt.mesh=bead;bolt.material_override=_material(Color("FFF1B5"));var a:=TAU*i/16.0;bolt.position=Vector3(cos(a)*4.42,.59,sin(a)*4.42);arena.add_child(bolt)
 var key:=OmniLight3D.new();key.position=Vector3(-4,4,2);key.light_color=Color("8ECDE0");key.light_energy=.7;key.omni_range=14;stage.add_child(key)
 for i in 7:
  var plinth:=MeshInstance3D.new();var shape:=CylinderMesh.new();shape.top_radius=.6+float(i%3)*.35;shape.bottom_radius=shape.top_radius*.75;shape.height=1.5+float(i%2);shape.radial_segments=6;plinth.mesh=shape;plinth.material_override=_material(Color("233E58"));plinth.position=Vector3(-10+i*3.4,-3.5,-6.0-float(i%2)*2);stage.add_child(plinth)
