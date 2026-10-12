extends SceneTree
const SIM=preload("res://scripts/truck_arena_simulation.gd")
func _initialize():call_deferred("run")
func run():
 var s=SIM.new();s.setup([{"id":1},{"id":2}]);s.phase="playing"
 assert(is_equal_approx(s.height_at(Vector2(12,5)),1.5))
 assert(is_equal_approx(s.height_at(Vector2(12,10)),3.0))
 s.players[1].position=Vector3.ZERO;s.step(1.0/60)
 assert(s.players[1].ammo==3 and s.pickups[0].cooldown>0)
 for pickup in s.pickups:pickup.cooldown=100.0
 s.players[1].position=Vector3(0,0,-4);s.players[1].angle=0;s.players[1].ammo=6
 s.players[2].position=Vector3(0,0,4)
 for hit in 4:
  s.input_for(1,Vector2.ZERO,true)
  for tick in 65:s.step(1.0/60)
  assert(s.players[2].hp==3-hit)
 assert(s.phase=="results" and s.winners==[1] and s.match_complete)
 s.setup([{"id":1},{"id":-1}]);s.phase="playing"
 for tick in 2400:
  if tick%5==0:s.bot_input(-1)
  s.step(1.0/60)
 var fired:=false
 for event in s.events:
  if event.kind=="shot":fired=true
 assert(fired, "Bot must navigate, collect ammo and shoot")
 print("TRUCK_ARENA_RULES_OK: ramps, pickups, four hits, bot collects and shoots")
 quit()
