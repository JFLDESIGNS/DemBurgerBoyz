extends RefCounted
const LIMIT := 23.0
const PICKUPS := [Vector2(0,0),Vector2(0,10),Vector2(0,-10),Vector2(10,0),Vector2(-10,0),Vector2(12,10),Vector2(-12,10),Vector2(12,-10),Vector2(-12,-10)]
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
  players[int(roster[i].id)]={"position":at,"angle":atan2(-at.x,-at.z),"speed":0.0,"vertical":0.0,"velocity":Vector3.ZERO,"alive":true,"hp":4,"ammo":0,"cooldown":0.0,"shield":0.0,"input":Vector2.ZERO,"input_age":0.0,"burst":false,"travel":0.0,"stuck":0.0}
 for pos in PICKUPS:pickups.append({"position":Vector3(pos.x,height_at(pos)+.8,pos.y),"cooldown":0.0})
 _build_navigation()
static func height_at(p:Vector2)->float:
 for sx in [-1.0,1.0]:
  for sz in [-1.0,1.0]:
   var center:=Vector2(sx*12,sz*12)
   if absf(p.x-center.x)<=5 and absf(p.y-center.y)<=5:
    if absf(p.x-(center.x+sx*2.8))<1.5 and absf(p.y-(center.y+sz*2.8))<1.5:return 5.8
    return 3.0
   if absf(p.y-center.y)<2.3 and p.x*sx>=3 and p.x*sx<7:return (p.x*sx-3)*.75
   if absf(p.x-center.x)<2.3 and p.y*sz>=3 and p.y*sz<7:return (p.y*sz-3)*.75
 return 0.0
func input_for(id:int,axis:Vector2,fire:bool)->void:
 if not players.has(id) or not axis.is_finite():return
 players[id].input=axis.clamp(Vector2(-1,-1),Vector2.ONE);players[id].input_age=0.0
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
  p.speed=move_toward(p.speed,axis.y*(10.0 if axis.y>=0 else 4.5),(13.0 if absf(axis.y)>.1 else 6.0)*dt)
  p.angle+=axis.x*(1.8+minf(absf(p.speed),8)*.07)*dt*(1 if p.speed>=0 else -1)
  var forward:=Vector3(sin(p.angle),0,cos(p.angle))
  var before:Vector3=p.position
  var next:Vector3=before+forward*p.speed*dt
  var ground:=height_at(Vector2(next.x,next.z))
  if absf(next.x)>LIMIT or absf(next.z)>LIMIT or ground>float(p.position.y)+.6:
   p.speed*=-.35;next.x=before.x;next.z=before.z;ground=height_at(Vector2(before.x,before.z))
  p.vertical-=22.0*dt;next.y+=p.vertical*dt
  if next.y<=ground:next.y=ground;p.vertical=0.0
  p.position=next;p.velocity=(next-before)/dt;p.travel+=before.distance_to(next)
  for pickup in pickups:
   if pickup.cooldown<=0 and p.ammo<6 and next.distance_to(pickup.position-Vector3.UP*.8)<1.3:
    p.ammo=mini(6,p.ammo+3);pickup.cooldown=7.0;emit_event("pickup",.65)
  if p.burst and p.ammo>0 and p.cooldown<=0:
   p.ammo-=1;p.cooldown=.4;shot_serial+=1
   shots.append({"id":shot_serial,"owner":id,"position":next+Vector3.UP*.85+forward*1.2,"direction":forward,"life":2.0});emit_event("shot",.6)
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
    a.position-=correction;b.position+=correction;a.speed*=.7;b.speed*=.7
 for index in range(shots.size()-1,-1,-1):
  var shot:Dictionary=shots[index];var before:Vector3=shot.position;shot.position+=shot.direction*25.0*dt;shot.life-=dt
  var at:Vector3=shot.position
  var dead:bool=shot.life<=0 or absf(at.x)>24 or absf(at.z)>24 or height_at(Vector2(at.x,at.z))>at.y-.1
  if not dead:
   for id in players:
    var p:Dictionary=players[id]
    if id==shot.owner or not p.alive:continue
    var center:Vector3=p.position+Vector3.UP*.8
    if Geometry3D.get_closest_point_to_segment(center,before,at).distance_to(center)<.85:
     dead=true
     if p.shield<=0:
      p.hp-=1;p.shield=.65;p.speed*=.55;emit_event("hit",1)
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
 for x in 23:
  for z in 23:
   var point:=Vector2(x*2-22,z*2-22);var h:=height_at(point)
   if h>3.1:continue
   navigation.add_point(x*23+z,Vector3(point.x,h,point.y))
 for id in navigation.get_point_ids():
  for offset in [1,23]:
   var other:int=id+offset
   if not navigation.has_point(other) or (offset==1 and int(id/23)!=int(other/23)):continue
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
 var delta:Vector3=waypoint-me.position
 var difference:=wrapf(atan2(delta.x,delta.z)-float(me.angle),-PI,PI)
 var throttle:=1.0 if absf(difference)<1.3 else .25
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
 input_for(id,Vector2(clampf(difference*1.8,-1,1),throttle),fire)
