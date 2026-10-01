extends Node3D
## Host-authoritative grill hazards; clients only interpolate the presentation.
const RADIUS = .254 # Ten inches, in game metres.
const COOK_SECONDS = 2.0
const RELEASE = .65
const FLIGHT = .65
const THROW_SOUND = preload("res://sounds/boss/hotdog_throw.wav")
const SIZZLE_SOUND = preload("res://sounds/boss/hotdog_sizzle.wav")
const POP_SOUND = preload("res://sounds/boss/hotdog_pop.wav")
var boss: Node
var game: Node
var hazards: Dictionary = {}
var next_id = 0
var blast_count = 0
var held_id = -1
var drag_send_left = 0.0

func setup(owner_boss: Node) -> void:
 boss=owner_boss;game=boss.game;name="HotdogProjectiles"

func hand_position() -> Vector3:
 if is_instance_valid(boss.customer) and is_instance_valid(boss.customer.rig):
  var rig: Skeleton3D=boss.customer.rig
  var bone=rig.find_bone("Fist.R")
  if bone>=0:return rig.to_global(rig.get_bone_global_pose(bone).origin)+Vector3(0,.12,0)
 return boss.boss_position+Vector3(0,2.5,0)

func launch() -> void:
 if not boss.host() or hazards.size()>=3:return
 var bounds:Vector2=game._grill_cook_x_bounds()
 var target=Vector3(randf_range(bounds.x+.13,bounds.y-.13),game.GRILL_SURFACE_Y+.03,game.GRILL_SURFACE_Z+randf_range(-.28,.28))
 var candidates=[]
 for p in game.grill:
  if is_instance_valid(p) and not p.is_held and not game._is_in_warmer_zone(p.global_position):candidates.append(p)
 if not candidates.is_empty() and randf()<.65:
  target.x=clampf(candidates.pick_random().global_position.x,bounds.x+.13,bounds.y-.13)
 next_id+=1
 spawn_local({"id":next_id,"age":0.0,"heat":0.0,"start":hand_position(),"target":target,"round":boss.generation})
 broadcast()

func material(color: Color) -> StandardMaterial3D:
 var mat=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=1;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 return mat

func mesh_node(mesh: Mesh, mat: Material, parent: Node3D) -> MeshInstance3D:
 var node=MeshInstance3D.new();node.mesh=mesh;node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node);return node

func spawn_local(row: Dictionary) -> void:
 var id=int(row.id)
 if hazards.has(id):return
 var h=row.duplicate(true)
 h.holder=int(row.get("holder",0));h.carry=row.get("carry",row.target)
 var root=Node3D.new();add_child(root);h.node=root
 var body=Node3D.new();root.add_child(body);h.body=body
 var capsule=CapsuleMesh.new();capsule.radius=.035;capsule.height=.28;capsule.radial_segments=12;capsule.rings=3
 h.mat=material(Color("CE4D26"));var sausage=mesh_node(capsule,h.mat,body);sausage.rotation.z=PI*.5
 for x in [-.07,0,.07]:
  var slash=BoxMesh.new();slash.size=Vector3(.012,.004,.046)
  var cut=mesh_node(slash,material(Color("733020")),body);cut.position=Vector3(x,.034,0);cut.rotation.y=-.4
 var mustard=BoxMesh.new();mustard.size=Vector3(.20,.006,.01);var stripe=mesh_node(mustard,material(Color("FFCB36")),body);stripe.position=Vector3(0,.039,.006)
 var ringmesh=TorusMesh.new();ringmesh.inner_radius=RADIUS-.005;ringmesh.outer_radius=RADIUS;ringmesh.rings=32;ringmesh.ring_segments=4
 h.ring=mesh_node(ringmesh,material(Color("FFB22E")),self);h.ring.position=h.target;h.ring.position.y=game.GRILL_SURFACE_Y+.005
 var timer_label=Label3D.new();timer_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;timer_label.no_depth_test=false;timer_label.font_size=48;timer_label.pixel_size=.0018;timer_label.outline_size=8;timer_label.modulate=Color("FFF3B3");root.add_child(timer_label);timer_label.position.y=.15;h.label=timer_label
 var sound=AudioStreamPlayer.new();sound.stream=SIZZLE_SOUND.duplicate();sound.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;sound.stream.loop_end=int(sound.stream.get_length()*sound.stream.mix_rate);sound.bus="SFX";sound.volume_db=-12;root.add_child(sound);h.sizzle=sound
 h.launched=false;hazards[id]=h;update_visual(h)

func sound_once(stream: AudioStream, volume: float) -> void:
 var audio=AudioStreamPlayer.new();audio.stream=stream;audio.bus="SFX";audio.volume_db=volume;add_child(audio);audio.finished.connect(audio.queue_free);audio.play()

func _process(delta: float) -> void:
 if not is_instance_valid(boss) or not is_instance_valid(game):return
 if not boss.active() or boss.phase in ["victory","sinking","results","defeat","defeat_laugh","defeat_smash","defeat_sinking"]:
  clear();return
 if not game.playing or get_tree().paused:return
 if held_id>=0 and hazards.has(held_id):
  var pos=pointer_world(get_viewport().get_mouse_position())
  hazards[held_id].carry=pos
  drag_send_left-=delta
  if drag_send_left<=0:
   drag_send_left=.05;send_command("move",held_id,pos)
 advance(delta)

func advance(delta: float) -> void:
 for id in hazards.keys():
  var h=hazards[id];var old_age=float(h.age);h.age+=delta
  if old_age<RELEASE:h.start=hand_position()
  if boss.host() and h.holder>0 and boss.online() and h.holder!=multiplayer.get_unique_id() and not multiplayer.get_peers().has(h.holder):h.holder=0
  var cooking_delta=maxf(0,h.age-maxf(old_age,RELEASE+FLIGHT))
  if game.grill_on and h.holder==0 and not game._is_in_warmer_zone(h.target):h.heat=minf(COOK_SECONDS,h.heat+cooking_delta)
  update_visual(h)
  if boss.host() and h.heat>=COOK_SECONDS:detonate(id)

func update_visual(h: Dictionary) -> void:
 var airborne=h.age<RELEASE+FLIGHT
 var held=int(h.holder)>0 or int(h.id)==held_id
 h.ring.position=Vector3(h.target.x,game.GRILL_SURFACE_Y+.005,h.target.z)
 h.ring.visible=not held
 if held:
  h.node.global_position=h.carry;h.body.rotation=Vector3(0,.2,-.2);h.body.scale=Vector3.ONE
  h.label.visible=true;h.label.text="TO TRASH";h.sizzle.stream_paused=true
  return
 if h.age<RELEASE:
  h.node.global_position=hand_position();h.body.rotation=Vector3(0,0,.4)
 elif airborne:
  if not h.launched:sound_once(THROW_SOUND,-3);h.launched=true
  var u=clampf((h.age-RELEASE)/FLIGHT,0,1)
  h.node.global_position=h.start.lerp(h.target,u)+Vector3.UP*sin(u*PI)*1.1
  h.body.rotation.z=u*TAU*1.5
 else:
  h.node.global_position=h.target
  h.body.rotation=Vector3(0,.2,sin(h.age*42)*.055*(h.heat/COOK_SECONDS))
  h.body.scale=Vector3.ONE*(1+.10*sin(h.age*(15+h.heat*8))*h.heat/COOK_SECONDS)
  if not h.sizzle.playing:h.sizzle.play()
  h.sizzle.stream_paused=not game.grill_on or game._is_in_warmer_zone(h.target)
 h.label.visible=not airborne
 h.label.text="%.1f"%maxf(0,COOK_SECONDS-h.heat) if game.grill_on and not game._is_in_warmer_zone(h.target) else "COOL"
 h.mat.albedo_color=Color("CE4D26").lerp(Color("FFDD45"),maxf(0,sin(h.age*(12+h.heat*10)))*h.heat/COOK_SECONDS)

func detonate(id: int) -> void:
 if not boss.host() or not hazards.has(id):return
 var pos:Vector3=hazards[id].target
 var victims:Array[int]=[]
 for p in game.grill.duplicate():
  if not is_instance_valid(p):continue
  var offset:Vector3=p.global_position-pos
  if Vector2(offset.x,offset.z).length()<=RADIUS and absf(offset.y)<=RADIUS:
   victims.append(int(p.net_id));game._boss_destroy_grill_patty(p)
 show_blast(id,pos)
 if boss.online():
  receive_blast.rpc(id,pos,victims,boss.generation)
  game._mp_broadcast_grill()

@rpc("authority","call_remote","reliable")
func receive_blast(id: int, pos: Vector3, victims: Array, round_id: int) -> void:
 if round_id!=boss.generation or not boss.active():return
 for net_id in victims:
  var p=game._patty_by_net_id(int(net_id))
  if is_instance_valid(p):game._boss_destroy_grill_patty(p)
 show_blast(id,pos)

func show_blast(id: int, pos: Vector3) -> void:
 remove_hazard(id);blast_count+=1;sound_once(POP_SOUND,0)
 game._start_slot_camera_shake(.16,.018)
 var effect=Node3D.new();add_child(effect);effect.global_position=pos
 var burst=Node3D.new();effect.add_child(burst)
 var fan=ImmediateMesh.new();fan.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 20:
  var a=TAU*i/20;var b=TAU*(i+1)/20
  fan.surface_add_vertex(Vector3.ZERO)
  fan.surface_add_vertex(Vector3(cos(a),sin(a),0)*(.30 if i%2==0 else .13))
  fan.surface_add_vertex(Vector3(cos(b),sin(b),0)*(.30 if (i+1)%2==0 else .13))
 fan.surface_end()
 var yellow=material(Color("FFDB3F"));yellow.cull_mode=BaseMaterial3D.CULL_DISABLED
 mesh_node(fan,yellow,burst)
 burst.position.y=.12
 if is_instance_valid(game.camera):burst.look_at(game.camera.global_position)
 burst.scale=Vector3.ONE*.08
 var pop=burst.create_tween();pop.tween_property(burst,"scale",Vector3.ONE*1.4,.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT);pop.tween_property(burst,"scale",Vector3.ONE*.01,.20)
 for i in 8:
  var sphere=SphereMesh.new();sphere.radius=.055;sphere.height=.11;sphere.radial_segments=8;sphere.rings=4
  var puff=mesh_node(sphere,material(Color("F5D6A1") if i%2 else Color("E58D35")),effect)
  var end=Vector3(cos(i*TAU/8)*.32,.10+float(i%3)*.045,sin(i*TAU/8)*.32)
  var tw=puff.create_tween().set_parallel(true);tw.tween_property(puff,"position",end,.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT);tw.tween_property(puff,"scale",Vector3.ONE*1.6,.17);tw.chain().tween_property(puff,"scale",Vector3.ONE*.01,.3)
 var word=Label3D.new();word.text="POP!";word.font_size=72;word.pixel_size=.002;word.outline_size=16;word.modulate=Color("FFF2B1");word.billboard=BaseMaterial3D.BILLBOARD_ENABLED;effect.add_child(word);word.position.y=.22
 var tween=effect.create_tween();tween.tween_property(word,"position:y",.48,.4);tween.tween_property(word,"scale",Vector3.ONE*.01,.18);tween.tween_callback(effect.queue_free)

func remove_hazard(id: int) -> void:
 if not hazards.has(id):return
 var h=hazards[id];h.sizzle.stop();h.node.queue_free();h.ring.queue_free();hazards.erase(id)
 if held_id==id:held_id=-1

func clear() -> void:
 for id in hazards.keys():remove_hazard(id)

func broadcast() -> void:
 if not boss.host() or not boss.online():return
 var rows=[]
 for h in hazards.values():rows.append({"id":h.id,"age":h.age,"heat":h.heat,"start":h.start,"target":h.target,"round":h.round,"holder":h.holder,"carry":h.carry})
 sync_hazards.rpc(rows,boss.generation)

@rpc("authority","call_remote","reliable")
func sync_hazards(rows: Array, round_id: int) -> void:
 if boss.host() or not boss.active() or round_id!=boss.generation:return
 if boss.phase in ["victory","sinking","results","defeat","defeat_laugh","defeat_smash","defeat_sinking"]:
  clear();return
 var present=[]
 for row in rows:
  var id=int(row.id);present.append(id)
  if not hazards.has(id):spawn_local(row)
  else:
   for key in ["age","heat","start","target","holder"]:hazards[id][key]=row.get(key,0)
   if id!=held_id:hazards[id].carry=row.get("carry",row.target)
   if int(hazards[id].holder)>0 and int(hazards[id].holder)!=local_peer() and held_id==id:held_id=-1
 for id in hazards.keys():
  if not present.has(id):remove_hazard(id)

func local_peer() -> int:
 return multiplayer.get_unique_id() if boss.online() else 1

func pointer_world(screen: Vector2) -> Vector3:
 if not is_instance_valid(game.camera):return Vector3.ZERO
 var origin:Vector3=game.camera.project_ray_origin(screen);var ray:Vector3=game.camera.project_ray_normal(screen)
 if absf(ray.y)<.001:return Vector3.ZERO
 var distance=(game.GRILL_SURFACE_Y+.22-origin.y)/ray.y
 return (origin+ray*maxf(0,distance)).clamp(Vector3(-4,game.GRILL_SURFACE_Y+.1,-3),Vector3(4,game.GRILL_SURFACE_Y+2,4))

func pick_hotdog(screen: Vector2) -> int:
 if not is_instance_valid(game.camera):return -1
 var selected=-1;var nearest=24.0
 for h in hazards.values():
  if h.age<RELEASE+FLIGHT or h.holder!=0 or game.camera.is_position_behind(h.node.global_position):continue
  var a:Vector2=game.camera.unproject_position(h.node.global_position+Vector3(-.14,0,0))
  var b:Vector2=game.camera.unproject_position(h.node.global_position+Vector3(.14,0,0))
  var distance=screen.distance_to(Geometry2D.get_closest_point_to_segment(screen,a,b))
  if distance<nearest:nearest=distance;selected=int(h.id)
 return selected

func handle_input(event: InputEvent) -> bool:
 if not boss.active() or not game.playing or game.get_tree().paused:return false
 if held_id>=0:
  if event is InputEventMouseMotion:
   if hazards.has(held_id):hazards[held_id].carry=pointer_world(event.position)
   return true
  if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
   var id=held_id;held_id=-1
   send_command("trash" if game._is_over_garbage(event.position) else "drop",id,game._grill_plane_from_screen(event.position))
   return true
  if event is InputEventMouseButton:return true
 if not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT or not event.pressed:return false
 if game.options_menu_open or game.shift_paused or game._phone_owns_pointer(event.position) or game._ui_blocks_world_click(event.position):return false
 if game._hands_busy_with_other_tool() or is_instance_valid(game.spatula_patty) or is_instance_valid(game.dragging_patty):return false
 var id=pick_hotdog(event.position)
 if id<0:return false
 held_id=id;hazards[id].carry=pointer_world(event.position);drag_send_left=0
 send_command("grab",id,hazards[id].carry)
 return true

func send_command(kind: String, id: int, pos: Vector3) -> void:
 if boss.host():apply_command(kind,id,pos,local_peer())
 else:request_command.rpc_id(1,kind,id,pos,boss.generation)

@rpc("any_peer","call_remote","reliable")
func request_command(kind: String, id: int, pos: Vector3, round_id: int) -> void:
 if not boss.host() or round_id!=boss.generation:return
 apply_command(kind,id,pos,multiplayer.get_remote_sender_id())

func apply_command(kind: String, id: int, pos: Vector3, peer: int) -> void:
 if not boss.host() or not boss.active() or not game.playing or not pos.is_finite():return
 if kind=="grab":
  var allowed=hazards.has(id) and hazards[id].age>=RELEASE+FLIGHT and hazards[id].holder==0
  for other in hazards.values():
   if other.holder==peer:allowed=false
  if allowed:hazards[id].holder=peer;hazards[id].carry=pos
  if boss.online() and peer!=local_peer():claim_reply.rpc_id(peer,id,allowed,boss.generation)
  elif not allowed and held_id==id:held_id=-1
  broadcast();return
 if not hazards.has(id) or int(hazards[id].holder)!=peer:return
 var h=hazards[id]
 if kind=="move":
  h.carry=pos.clamp(Vector3(-4,game.GRILL_SURFACE_Y+.1,-3),Vector3(4,game.GRILL_SURFACE_Y+2,4))
 elif kind=="trash" and game._garbage_ready_for_trash():
  discard_local(id)
  if boss.online():receive_discard.rpc(id,boss.generation)
  game._physical_garbage_react()
 elif kind in ["drop","trash"]:
  h.holder=0
  if not game._grill_zone_at(pos).is_empty():
   h.target=Vector3(pos.x,game.GRILL_SURFACE_Y+.03,pos.z);h.ring.position=Vector3(pos.x,game.GRILL_SURFACE_Y+.005,pos.z)
 broadcast()

@rpc("authority","call_remote","reliable")
func claim_reply(id: int, granted: bool, round_id: int) -> void:
 if round_id==boss.generation and not granted and held_id==id:held_id=-1

@rpc("authority","call_remote","reliable")
func receive_discard(id: int, round_id: int) -> void:
 if round_id==boss.generation:discard_local(id)

func discard_local(id: int) -> void:
 if not hazards.has(id):return
 var h=hazards[id];hazards.erase(id)
 if held_id==id:held_id=-1
 h.sizzle.stop();h.label.hide();h.ring.queue_free()
 var start:Vector3=h.node.global_position;var target:Vector3=game._garbage_lerp_target_world()
 var tween=h.node.create_tween()
 tween.tween_method(func(t:float):
  if is_instance_valid(h.node):
   h.node.global_position=start.lerp(target,t)+Vector3.UP*.18*sin(t*PI)
   h.node.scale=Vector3.ONE*lerpf(1,.1,t)
   h.body.rotation.z=t*TAU
 ,0.0,1.0,.32)
 tween.tween_callback(h.node.queue_free)
 sound_once(THROW_SOUND,-7)
