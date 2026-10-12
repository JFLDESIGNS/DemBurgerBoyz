extends RefCounted
const LIMIT := 29.0
const FORT_HEIGHT := 3.5
const PICKUPS := [Vector2(0,0),Vector2(0,10),Vector2(0,-10),Vector2(10,0),Vector2(-10,0),Vector2(15,11),Vector2(-15,11),Vector2(15,-11),Vector2(-15,-11),Vector2(0,19),Vector2(0,-19),Vector2(19,0),Vector2(-19,0)]
var players:Dictionary={}
var phase:="waiting"
var clock:=0.0
var sequence:=0
var winners:Array[int]=[]
var match_complete:=false
var events:Array=[]
var event_serial:=0
var shots:Array=[]
var shot_serial:=0
var pickups:Array=[]
var navigation:=AStar3D.new()
func setup(roster:Array)->void:
 players.clear();shots.clear();pickups.clear();events.clear();winners.clear();phase="waiting";clock=0;sequence=0;match_complete=false;event_serial=0;shot_serial=0
 var spawns:=[Vector3(-6,0,-6),Vector3(6,0,6),Vector3(-6,0,6),Vector3(6,0,-6)]
 for i in roster.size():
  var at:Vector3=spawns[i%4]
  players[int(roster[i].id)]={"position":at,"angle":atan2(-at.x,-at.z),"speed":0.0,"vertical":0.0,"velocity":Vector3.ZERO,"alive":true,"hp":4,"ammo":0,"cooldown":0.0,"shield":0.0,"input":Vector2.ZERO,"input_age":0.0,"burst":false,"travel":0.0,"stuck":0.0,"slide":0.0,"turn":0.0,"bump_cooldown":0.0,"boost":1.0,"boosting":false,"boost_locked":false,"boost_wait":0.0}
 for pos in PICKUPS:pickups.append({"position":Vector3(pos.x,height_at(pos)+.8,pos.y),"cooldown":0.0})
 _build_navigation()
static func height_at(p:Vector2)->float:
 # Broad forts, gentle six-unit ramps, and four solid connecting causeways.
 for sx in [-1.0,1.0]:
  for sz in [-1.0,1.0]:
   var center:=Vector2(sx*15,sz*15)
   if absf(p.x-center.x)<=7 and absf(p.y-center.y)<=7:
    if absf(p.x-sx*19.3)<1.8 and absf(p.y-sz*19.3)<1.8:return 6.1
    return FORT_HEIGHT
   if absf(p.y-center.y)<=3 and p.x*sx>=2 and p.x*sx<8:return (p.x*sx-2)*FORT_HEIGHT/6.0
   if absf(p.x-center.x)<=3 and p.y*sz>=2 and p.y*sz<8:return (p.y*sz-2)*FORT_HEIGHT/6.0
 if absf(p.x)<=8 and absf(absf(p.y)-19)<=1.8:return FORT_HEIGHT
 if absf(p.y)<=8 and absf(absf(p.x)-19)<=1.8:return FORT_HEIGHT
 return 0.0
func input_for(id:int,axis:Vector2,fire:bool)->void:
 if not players.has(id) or not axis.is_finite():return
 players[id].input=axis.clamp(Vector2(-1,-1),Vector2(1,2));players[id].input_age=0.0
 if fire:players[id].burst=true
func drop_peer(id:int)->void:
 if players.has(id):players[id].alive=false;players[id].hp=0
func begin_countdown()->void:
 if phase=="waiting":phase="countdown";clock=0
func emit_event(kind:String,strength:float=1.0)->void:
 event_serial+=1;events.append({"id":event_serial,"kind":kind,"strength":strength})
 if events.size()>24:events.pop_front()
func step(dt:float)->void:
 dt=clampf(dt,0,1.0/30.0);clock+=dt;sequence+=1
 if phase in ["waiting","results"]:return
 if phase=="countdown":
  if clock>=3:phase="playing";clock=0
  return
 for pickup in pickups:pickup.cooldown=maxf(0,pickup.cooldown-dt)
 for id in players:
  var p:Dictionary=players[id]
  if not p.alive:continue
  p.input_age+=dt;p.cooldown=maxf(0,p.cooldown-dt);p.shield=maxf(0,p.shield-dt)
  var axis:Vector2=p.input if p.input_age<.35 else Vector2.ZERO
  var wants_boost:=axis.y>1.1
  axis.y=clampf(axis.y,-1,1)
  if not wants_boost:p.boost_locked=false
  p.boosting=wants_boost and not p.boost_locked and p.boost>0
  if p.boosting:
   p.boost=maxf(0,p.boost-dt*.6);p.boost_wait=.8
   if p.boost<=0:p.boost_locked=true
  else:
   p.boost_wait=maxf(0,p.boost_wait-dt)
   if p.boost_wait<=0:p.boost=minf(1,p.boost+dt*.22)
  var before:Vector3=p.position
  var velocity:Vector3=p.velocity;velocity.y=0
  var old_forward:=Vector3(sin(p.angle),0,cos(p.angle))
  var signed_speed:=velocity.dot(old_forward)
  # Godot's chase camera sees world -X as screen-right when facing +Z.
  var turn_target:float=-axis.x*(1.2+minf(velocity.length(),10)*.10)*clampf(velocity.length()/2.0,.15,1.0)*(1 if signed_speed>=-.2 else -1)
  p.turn=move_toward(p.turn,turn_target,8.0*dt)
  p.angle+=p.turn*dt
  var forward:=Vector3(sin(p.angle),0,cos(p.angle))
  var side:=Vector3(forward.z,0,-forward.x)
  var grounded:bool=before.y<=height_at(Vector2(before.x,before.z))+.04
  if grounded:
   velocity+=forward*axis.y*(36.0 if p.boosting else (17.0 if axis.y>=0 else 11.0))*dt
   var lateral:=velocity.dot(side)
   # Low lateral grip during a fast turn keeps the truck drifting.
   var grip:=2.0 if absf(axis.x)>.15 and velocity.length()>4 else 4.6
   velocity-=side*lateral*(1-exp(-grip*dt))
   velocity*=exp(-(.68 if absf(axis.y)>.1 else .95)*dt)
  velocity=velocity.limit_length((20.0 if p.boosting else 12.0) if signed_speed>=0 else 5.5)
  p.slide=absf(velocity.dot(side))
  p.bump_cooldown=maxf(0,p.bump_cooldown-dt)
  var next:Vector3=before+velocity*dt
  var collided:=false
  # Resolve axes separately: glancing impacts slide along walls instead of sticking.
  if absf(next.x)>LIMIT or height_at(Vector2(next.x,before.z))>before.y+.6:
   next.x=before.x;velocity.x*=-.55;collided=true
  if absf(next.z)>LIMIT or height_at(Vector2(next.x,next.z))>before.y+.6:
   next.z=before.z;velocity.z*=-.55;collided=true
  if collided and p.bump_cooldown<=0:
   emit_event("hit",clampf(velocity.length()*.1,.2,.7));p.bump_cooldown=.3
  var ground:=height_at(Vector2(next.x,next.z))
  p.vertical-=22.0*dt;next.y=before.y+p.vertical*dt
  if next.y<=ground or (grounded and ground>=before.y-.04):
   next.y=ground;p.vertical=maxf(0,(next.y-before.y)/dt)
  p.position=next;p.velocity=velocity;p.speed=velocity.dot(forward);p.travel+=Vector2(next.x-before.x,next.z-before.z).length()
  for pickup in pickups:
   if pickup.cooldown<=0 and p.ammo<6 and next.distance_to(pickup.position-Vector3.UP*.8)<1.3:
    p.ammo=mini(6,p.ammo+3);pickup.cooldown=7.0;emit_event("pickup",.65)
  if p.burst and p.ammo>0 and p.cooldown<=0:
   p.ammo-=1;p.cooldown=.4;shot_serial+=1
   shots.append({"id":shot_serial,"owner":id,"position":next+Vector3.UP*.32+forward*1.2,"direction":forward,"vertical":0.0,"life":3.0});emit_event("shot",.6)
  p.burst=false
 var ids:=players.keys()
 for i in ids.size():
  for j in range(i+1,ids.size()):
   var a:Dictionary=players[ids[i]];var b:Dictionary=players[ids[j]]
   if not a.alive or not b.alive:continue
   var offset:Vector3=b.position-a.position;offset.y=0
   if offset.length()<1.65 and absf(a.position.y-b.position.y)<1.0:
    var n:=offset.normalized() if offset.length()>.01 else Vector3.RIGHT
    var correction:=n*(1.65-offset.length())*.5
    a.position-=correction;b.position+=correction
    var closing:float=(a.velocity-b.velocity).dot(n)
    if closing>0:
     var impulse:=n*closing*.85
     a.velocity-=impulse;b.velocity+=impulse
     if a.bump_cooldown<=0:emit_event("hit",clampf(closing*.08,.2,1));a.bump_cooldown=.25
 for index in range(shots.size()-1,-1,-1):
  var shot:Dictionary=shots[index];var before:Vector3=shot.position
  shot.position+=shot.direction*25.0*dt;shot.life-=dt
  var at:Vector3=shot.position
  var ground:=height_at(Vector2(at.x,at.z))+.28
  var previous_ground:=height_at(Vector2(before.x,before.z))+.28
  var dead:bool=shot.life<=0 or absf(at.x)>LIMIT or absf(at.z)>LIMIT or ground>before.y+.7
  # Rise along continuous ramps, drop ballistically over an edge, then skim the floor.
  shot.vertical=float(shot.get("vertical",0.0))-28.0*dt
  at.y=before.y+shot.vertical*dt
  if ground>=previous_ground-.04 and before.y<=previous_ground+.12 and not dead:
   at.y=ground;shot.vertical=0.0
  elif at.y<=ground:
   at.y=ground;shot.vertical=0.0
  shot.position=at
  if not dead:
   for id in players:
    var p:Dictionary=players[id]
    if id==shot.owner or not p.alive:continue
    var center:Vector3=p.position+Vector3.UP*.8
    if Geometry3D.get_closest_point_to_segment(center,before,at).distance_to(center)<.85:
     dead=true
     if p.shield<=0:
      p.hp-=1;p.shield=.65;p.velocity=p.velocity*.65+shot.direction*2.8;emit_event("hit",1)
      if p.hp<=0:p.alive=false;emit_event("fall",.8)
     break
  if dead:shots.remove_at(index)
 var alive:Array[int]=[]
 for id in players:
  if players[id].alive:alive.append(id)
 if alive.size()<=1 or clock>=150:
  winners=alive
  if alive.size()>1:
   var best:=0
   for id in alive:best=maxi(best,players[id].hp)
   winners=alive.filter(func(id):return players[id].hp==best)
  phase="results";clock=0;match_complete=true;emit_event("win",1)
func snapshot()->Dictionary:
 return {"players":players.duplicate(true),"phase":phase,"clock":clock,"left":maxf(0,150-clock),"sequence":sequence,"winners":winners.duplicate(),"match_complete":match_complete,"events":events.duplicate(true),"shots":shots.duplicate(true),"pickups":pickups.duplicate(true)}
func _build_navigation()->void:
 navigation.clear()
 for x in 29:
  for z in 29:
   var point:=Vector2(x*2-28,z*2-28);var h:=height_at(point)
   if h>3.6:continue
   navigation.add_point(x*29+z,Vector3(point.x,h,point.y))
 for id in navigation.get_point_ids():
  for offset in [1,29]:
   var other:int=id+offset
   if not navigation.has_point(other) or (offset==1 and int(id/29)!=int(other/29)):continue
   if absf(navigation.get_point_position(id).y-navigation.get_point_position(other).y)<=1.55:navigation.connect_points(id,other)
func bot_input(id:int)->void:
 var me:Dictionary=players[id]
 if not me.alive:return
 var target:Vector3=Vector3.ZERO
 var closest:=INF
 var enemy:Dictionary={}
 for other_id in players:
  if other_id==id or not players[other_id].alive:continue
  var other:Dictionary=players[other_id];var distance:float=me.position.distance_to(other.position)
  if distance<closest:closest=distance;enemy=other;target=other.position+other.velocity*.25
 if me.ammo<2:
  closest=INF
  for pickup in pickups:
   var distance:float=me.position.distance_to(pickup.position)
   if pickup.cooldown<=0 and distance<closest:closest=distance;target=pickup.position-Vector3.UP*.8
 var route:=navigation.get_point_path(navigation.get_closest_point(me.position),navigation.get_closest_point(target))
 var waypoint:=target
 for point in route:
  if Vector2(point.x-me.position.x,point.z-me.position.z).length()>2.0:waypoint=point;break
 if me.ammo>=2 and not enemy.is_empty() and me.position.distance_to(enemy.position)<16:
  var clear:=true
  for sample in range(1,13):
   var point:Vector3=me.position.lerp(enemy.position,sample/12.0)
   if height_at(Vector2(point.x,point.z))>me.position.y+.5:clear=false
  if clear:waypoint=enemy.position+enemy.velocity*.18
 var delta:Vector3=waypoint-me.position
 var difference:=wrapf(atan2(delta.x,delta.z)-float(me.angle),-PI,PI)
 var throttle:=1.0 if absf(difference)<.65 else .3
 if me.ammo>=2 and not enemy.is_empty() and me.position.distance_to(enemy.position)<8:throttle=.25
 if absf(me.speed)<.3:me.stuck+=.08
 else:me.stuck=0.0
 if me.stuck>1.2:throttle=-1.0
 if me.stuck>2.0:me.stuck=0.0
 var fire:=false
 if not enemy.is_empty() and me.ammo>0:
  var aim:Vector3=enemy.position+enemy.velocity*.18-me.position
  fire=absf(wrapf(atan2(aim.x,aim.z)-float(me.angle),-PI,PI))<.17 and aim.length()<18 and absf(aim.y)<.65
  for step_index in range(1,8):
   var p:Vector3=me.position.lerp(enemy.position,step_index/8.0)
   if height_at(Vector2(p.x,p.z))>me.position.y+.7:fire=false
 input_for(id,Vector2(clampf(-difference*1.8,-1,1),2.0 if absf(difference)<.06 and me.boost>.85 and closest>16 else throttle),fire)
