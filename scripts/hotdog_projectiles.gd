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
 advance(delta)

func advance(delta: float) -> void:
 for id in hazards.keys():
  var h=hazards[id];var old_age=float(h.age);h.age+=delta
  if old_age<RELEASE:h.start=hand_position()
  var cooking_delta=maxf(0,h.age-maxf(old_age,RELEASE+FLIGHT))
  if game.grill_on:h.heat=minf(COOK_SECONDS,h.heat+cooking_delta)
  update_visual(h)
  if boss.host() and h.heat>=COOK_SECONDS:detonate(id)

func update_visual(h: Dictionary) -> void:
 var airborne=h.age<RELEASE+FLIGHT
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
  h.sizzle.stream_paused=not game.grill_on
 h.label.visible=not airborne
 h.label.text="%.1f"%maxf(0,COOK_SECONDS-h.heat) if game.grill_on else "COOL"
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

func clear() -> void:
 for id in hazards.keys():remove_hazard(id)

func broadcast() -> void:
 if not boss.host() or not boss.online():return
 var rows=[]
 for h in hazards.values():rows.append({"id":h.id,"age":h.age,"heat":h.heat,"start":h.start,"target":h.target,"round":h.round})
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
   for key in ["age","heat","start","target"]:hazards[id][key]=row[key]
 for id in hazards.keys():
  if not present.has(id):remove_hazard(id)
