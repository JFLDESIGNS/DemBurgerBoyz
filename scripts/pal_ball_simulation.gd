extends RefCounted
## Fixed-step, host-owned arena rules. No scene or rendering dependencies.
const ROUND_SECONDS := 50.0
const BALL_RADIUS := .53
const START_RADIUS := 4.6
var players: Dictionary = {}
var phase := "waiting"
var clock := 0.0
var round_left := ROUND_SECONDS
var arena_radius := START_RADIUS
var winners: Array[int] = []
var sequence := 0
var event_serial := 0
var events: Array = []
var scores: Dictionary = {}
var round_number := 1
var match_complete := false
var entries: Array = []
var disconnected: Array[int] = []

func setup(roster: Array) -> void:
 scores.clear();round_number=1;match_complete=false;entries=roster.duplicate(true);disconnected.clear()
 for entry in roster:scores[int(entry.id)]=0
 players.clear();winners.clear();events.clear();event_serial=0;phase="waiting";clock=0.0;round_left=ROUND_SECONDS;arena_radius=START_RADIUS;sequence=0
 for i in roster.size():
  var angle := TAU*float(i)/float(roster.size())+PI*.25
  players[int(roster[i].id)]={"position":Vector2(cos(angle),sin(angle))*2.55,"velocity":Vector2.ZERO,"alive":true,"fall":0.0,"cooldown":0.0,"input":Vector2.ZERO,"input_age":0.0,"burst":false,"knockback":0.0,"jump":0.0,"pulse":0.0}

func input_for(peer: int, direction: Vector2, burst: bool) -> void:
 if not players.has(peer) or not direction.is_finite(): return
 players[peer].input=direction.limit_length(1.0)
 players[peer].input_age=0.0
 if burst: players[peer].burst=true

func drop_peer(peer: int) -> void:
 if players.has(peer):
  players[peer].alive=false
  if not disconnected.has(peer):disconnected.append(peer)

func begin_countdown() -> void:
 if phase=="waiting":phase="countdown";clock=0.0

func step(dt: float) -> void:
 dt=clampf(dt,0.0,1.0/30.0);clock+=dt;sequence+=1
 for p in players.values():
  if not p.alive:p.fall+=dt
 if phase=="waiting":return
 if phase=="results":
  if clock>=3.0 and not match_complete:_next_round()
  return
 if phase=="countdown":
  if clock>=4.0:phase="playing";clock=0.0
  return
 round_left=maxf(0.0,ROUND_SECONDS-clock)
 arena_radius=lerpf(START_RADIUS,2.4,clampf((clock-30.0)/20.0,0.0,1.0))
 for p in players.values():
  if not p.alive:continue
  var previous_jump:float=p.jump
  p.jump=maxf(0.0,float(p.jump)-dt);p.pulse=maxf(0.0,float(p.pulse)-dt)
  if previous_jump>.12 and p.jump<=.12:
   p.pulse=.28;emit_event("slam",1.0)
   for other in players.values():
    if other==p or not other.alive:continue
    var away:Vector2=other.position-p.position
    var distance:=away.length()
    if distance<2.0:
     var normal:=away.normalized() if distance>.001 else Vector2.RIGHT
     other.velocity+=normal*(3.0+6.0*(1.0-distance/2.0));other.knockback=.65
  p.cooldown=maxf(0.0,float(p.cooldown)-dt)
  p.input_age+=dt
  p.knockback=maxf(0.0,float(p.knockback)-dt)
  var direction: Vector2=p.input if p.input_age<.3 else Vector2.ZERO
  var velocity: Vector2=p.velocity
  var acceleration:=5.0 if direction.dot(velocity)<0.0 else 8.0
  velocity=velocity.move_toward(Vector2.ZERO,.65*dt)+direction*acceleration*dt*(.3 if p.knockback>0 else 1.0)
  if p.burst and p.cooldown<=0:
   if direction.length()>.2:velocity+=direction.normalized()*3.8
   p.cooldown=2.4;p.jump=.6
   emit_event("burst",.7)
  p.burst=false
  p.velocity=velocity.limit_length(12.0 if p.knockback>0 else (8.5 if p.cooldown>1.95 else 5.4))
  p.position+=p.velocity*dt
 var ids:=players.keys()
 for a in ids.size():
  for b in range(a+1,ids.size()):
   var one: Dictionary=players[ids[a]];var two: Dictionary=players[ids[b]]
   if not one.alive or not two.alive:continue
   var offset: Vector2=two.position-one.position
   var distance:=offset.length()
   if distance>=BALL_RADIUS*2.0:continue
   var normal:=offset/distance if distance>.0001 else Vector2.RIGHT
   var overlap:=BALL_RADIUS*2.0-distance
   one.position-=normal*overlap*.5;two.position+=normal*overlap*.5
   var closing:float=(two.velocity-one.velocity).dot(normal)
   if closing<0:
    var speed_one:float=one.velocity.length()
    var speed_two:float=two.velocity.length()
    # Faster balls carry more effective mass: the slower pal takes the launch.
    var mass_one:=1.0+maxf(0.0,speed_one-speed_two)*1.3
    var mass_two:=1.0+maxf(0.0,speed_two-speed_one)*1.3
    var impulse:=(-closing*1.9+.7)/(1.0/mass_one+1.0/mass_two)
    one.velocity-=normal*impulse/mass_one;two.velocity+=normal*impulse/mass_two
    one.knockback=.65;two.knockback=.65
    if closing<-.5:emit_event("bump",clampf(-closing/8.0,.35,1.0))
 for p in players.values():
  if p.alive and maxf(absf(p.position.x),absf(p.position.y))>arena_radius+.12:
   p.alive=false;p.fall=0.0;emit_event("fall",1.0)
 var alive:Array[int]=[]
 for id in players:
  if players[id].alive:alive.append(int(id))
 if alive.size()<=1 or round_left<=0:
  winners=alive;phase="results";clock=0.0
  if alive.size()==1:
   scores[alive[0]]=int(scores.get(alive[0],0))+1
   match_complete=int(scores[alive[0]])>=2
  if players.size()-disconnected.size()<=1:match_complete=true
  emit_event("win",1.0)

func snapshot() -> Dictionary:
 var poses:Dictionary={}
 for id in players:
  var p:Dictionary=players[id]
  poses[id]={"position":p.position,"velocity":p.velocity,"alive":p.alive,"fall":p.fall,"cooldown":p.cooldown,"knockback":p.knockback,"jump":p.jump,"pulse":p.pulse}
 return {"phase":phase,"clock":clock,"left":round_left,"radius":arena_radius,"players":poses,"winners":winners,"sequence":sequence,"events":events.duplicate(true),"scores":scores.duplicate(),"round":round_number,"match_complete":match_complete}


func emit_event(kind: String, strength: float) -> void:
 event_serial+=1;events.append({"id":event_serial,"kind":kind,"strength":strength})
 if events.size()>16:events.pop_front()


func _next_round() -> void:
 if winners.size()==1:round_number+=1
 winners.clear();phase="countdown";clock=0.0;round_left=ROUND_SECONDS;arena_radius=START_RADIUS
 for i in entries.size():
  var id:=int(entries[i].id)
  var angle:=TAU*float(i)/float(entries.size())+PI*.25+float(round_number-1)*PI*.5
  players[id]={"position":Vector2(cos(angle),sin(angle))*2.55,"velocity":Vector2.ZERO,"alive":not disconnected.has(id),"fall":0.0,"cooldown":0.0,"input":Vector2.ZERO,"input_age":0.0,"burst":false,"knockback":0.0,"jump":0.0,"pulse":0.0}
