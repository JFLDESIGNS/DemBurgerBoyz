extends SceneTree
func _initialize():call_deferred("run")
func run():
 var sim=load("res://scripts/pal_ball_simulation.gd").new()
 sim.setup([{"id":1},{"id":2}]);sim.begin_countdown()
 for i in 241:sim.step(1.0/60.0)
 assert(sim.phase=="playing")
 sim.players[1].position=Vector2(-.5,0);sim.players[2].position=Vector2(.5,0)
 sim.players[1].velocity=Vector2(4,0);sim.players[2].velocity=Vector2(-4,0)
 sim.step(1.0/60.0)
 assert(sim.players[1].velocity.x<0 and sim.players[2].velocity.x>0)
 sim.players[2].position=Vector2(8,0);sim.step(1.0/60.0)
 assert(sim.phase=="results" and sim.winners==[1] and sim.scores[1]==1 and not sim.match_complete)
 var sequence=sim.sequence
 for i in 430:sim.step(1.0/60.0)
 assert(sim.phase=="playing" and sim.round_number==2 and sim.players[2].alive and sim.sequence>sequence)
 sim.players[2].position=Vector2(8,0);sim.step(1.0/60.0)
 assert(sim.match_complete and sim.scores[1]==2 and sim.winners==[1])
 sim.setup([{"id":1},{"id":2}]);sim.phase="playing";sim.clock=51;sim.step(1.0/60.0)
 assert(not sim.match_complete and sim.scores[1]==0 and sim.scores[2]==0)
 for i in 181:sim.step(1.0/60.0)
 assert(sim.round_number==1 and sim.phase=="countdown")
 sim.setup([{"id":1},{"id":2}]);sim.phase="playing"
 for loser in [2,1,2]:
  sim.players[loser].position=Vector2(8,0);sim.step(1.0/60.0)
  if not sim.match_complete:
   for i in 430:sim.step(1.0/60.0)
 assert(sim.match_complete and sim.round_number==3 and sim.scores[1]==2 and sim.scores[2]==1)
 var bot=load("res://scripts/pal_ball_bot.gd")
 var choice=bot.choose({"position":Vector2(3.7,0),"velocity":Vector2(4,0),"cooldown":0},[{"position":Vector2(4.1,0),"velocity":Vector2.ZERO,"alive":true}],4.6)
 assert(choice.direction.x<0 and not choice.burst,"Bot brakes before it slides off")
 choice=bot.choose({"position":Vector2.ZERO,"velocity":Vector2.ZERO,"cooldown":0},[{"position":Vector2(1.4,0),"velocity":Vector2.ZERO,"alive":true}],4.6)
 assert(choice.direction.x>0 and choice.burst,"Bot times a nearby safe attack")
 sim.setup([{"id":1},{"id":2}]);sim.phase="playing"
 sim.players[1].position=Vector2(-.5,0);sim.players[2].position=Vector2(.5,0)
 sim.players[1].velocity=Vector2(5,0);sim.players[2].velocity=Vector2(-2,0)
 sim.step(1.0/60.0)
 assert(sim.players[1].velocity.x>0 and sim.players[2].velocity.x>5,"Faster pal wins the collision")
 sim.setup([{"id":1},{"id":2}]);sim.phase="playing"
 sim.players[1].position=Vector2.ZERO;sim.players[2].position=Vector2(1.5,0)
 sim.input_for(1,Vector2.ZERO,true)
 for i in 32:sim.step(1.0/60.0)
 assert(sim.players[2].velocity.x>3 and absf(sim.players[2].velocity.y)<.01,"Jump shockwave pushes outward")
 assert(sim.events.any(func(e):return e.kind=="slam"))
 sim.setup([{"id":1},{"id":2}]);sim.phase="playing"
 sim.players[1].position=Vector2(4,4);sim.step(1.0/60.0)
 assert(not sim.players[1].alive,"Outside the round bun falls away")
 sim.setup([{ "id":1},{"id":2}]);sim.phase="playing"
 sim.players[1].position=Vector2.ZERO;sim.players[1].velocity=Vector2(5,0);sim.players[2].position=Vector2(-4,-4)
 for i in 12:sim.input_for(1,Vector2.LEFT,false);sim.step(1.0/60.0)
 assert(sim.players[1].velocity.x>3,"Reversing requires sustained input")
 assert(load("res://scripts/pal_ball_break.gd")!=null)
 assert(load("res://scripts/game.gd")!=null)
 print("PAL_BALL_RULES_OK");quit()
