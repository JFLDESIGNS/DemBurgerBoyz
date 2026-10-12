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

func setup(roster: Array) -> void:
 players.clear();winners.clear();phase="waiting";clock=0.0;round_left=ROUND_SECONDS;arena_radius=START_RADIUS;sequence=0
 for i in roster.size():
  var angle := TAU*float(i)/float(roster.size())+PI*.25
  players[int(roster[i].id)]={"position":Vector2(cos(angle),sin(angle))*2.55,"velocity":Vector2.ZERO,"alive":true,"fall":0.0,"cooldown":0.0,"input":Vector2.ZERO,"input_age":0.0,"burst":false}

func input_for(peer: int, direction: Vector2, burst: bool) -> void:
 if not players.has(peer) or not direction.is_finite(): return
 players[peer].input=direction.limit_length(1.0)
 players[peer].input_age=0.0
 if burst: players[peer].burst=true

func drop_peer(peer: int) -> void:
 if players.has(peer): players[peer].alive=false

func begin_countdown() -> void:
 if phase=="waiting":phase="countdown";clock=0.0

func step(dt: float) -> void:
 dt=clampf(dt,0.0,1.0/30.0);clock+=dt;sequence+=1
 for p in players.values():
  if not p.alive:p.fall+=dt
 if phase=="waiting" or phase=="results":return
 if phase=="countdown":
  if clock>=4.0:phase="playing";clock=0.0
  return
 round_left=maxf(0.0,ROUND_SECONDS-clock)
 arena_radius=lerpf(START_RADIUS,2.4,clampf((clock-30.0)/20.0,0.0,1.0))
 for p in players.values():
  if not p.alive:continue
  p.cooldown=maxf(0.0,float(p.cooldown)-dt)
  p.input_age+=dt
  var direction: Vector2=p.input if p.input_age<.3 else Vector2.ZERO
  var velocity: Vector2=p.velocity
  velocity=velocity.move_toward(Vector2.ZERO,3.0*dt)+direction*16.0*dt
  if p.burst and p.cooldown<=0 and direction.length()>.2:
   velocity+=direction.normalized()*3.1;p.cooldown=2.4
  p.burst=false
  p.velocity=velocity.limit_length(7.5 if p.cooldown>1.95 else 4.8)
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
    var impulse:=(-closing*.93)+.7
    one.velocity-=normal*impulse;two.velocity+=normal*impulse
 for p in players.values():
  if p.alive and p.position.length()>arena_radius+.12:p.alive=false;p.fall=0.0
 var alive:Array[int]=[]
 for id in players:
  if players[id].alive:alive.append(int(id))
 if alive.size()<=1 or round_left<=0:
  winners=alive;phase="results";clock=0.0

func snapshot() -> Dictionary:
 var poses:Dictionary={}
 for id in players:
  var p:Dictionary=players[id]
  poses[id]={"position":p.position,"velocity":p.velocity,"alive":p.alive,"fall":p.fall,"cooldown":p.cooldown}
 return {"phase":phase,"clock":clock,"left":round_left,"radius":arena_radius,"players":poses,"winners":winners,"sequence":sequence}
