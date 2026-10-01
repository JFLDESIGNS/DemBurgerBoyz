extends SceneTree
class Patty extends Area3D:
 var net_id=0
 var is_held=false
class RemoteBoss extends Node:
 var generation=0
 var customer:Node3D
 var boss_position=Vector3.ZERO
 var phase="ready"
 func host():return false
 func online():return false
 func active():return true
func _initialize():call_deferred("run")
func run():
 create_timer(45).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/hotdog_challenge_fixture.gd"));root.add_child(g)
 g.playing=true;g._kitchen_ready=true;g.stations=[{"items":[],"patties":[]}]
 var boss=g._ensure_hotdog_challenge();boss.set_process(false);var hazards=boss.projectiles;hazards.set_process(false)
 assert(boss.start());boss.advance_phase();boss.advance_phase()
 boss.throw_left=.01;boss.ambient_left=99;boss._process(.1)
 assert(boss.phase=="throw" and boss.clip=="throw_hotdog" and hazards.hazards.size()==1)
 var remaining=boss.order_left;var recipe=boss.customer.order.duplicate();boss.advance_phase()
 assert(boss.phase=="ready" and boss.order_left==remaining and boss.customer.order==recipe)
 hazards.clear()
 var pos=Vector3(0,g.GRILL_SURFACE_Y+.03,g.GRILL_SURFACE_Z)
 var near=Patty.new();near.net_id=9001;g.add_child(near);near.position=pos+Vector3(.253,0,0)
 var far=Patty.new();far.net_id=9002;g.add_child(far);far.position=pos+Vector3(.255,0,0);g.grill=[near,far]
 hazards.spawn_local({"id":100,"age":0.0,"heat":0.0,"start":Vector3(0,3,7),"target":pos,"round":boss.generation})
 g.grill_on=true;hazards.advance(1.29);assert(hazards.hazards[100].heat==0,"Flight time must not count as cooking")
 g.grill_on=false;hazards.advance(3);assert(hazards.hazards[100].heat==0,"Cold grill pauses fuse")
 g.grill_on=true;hazards.advance(1.99);assert(hazards.hazards.has(100))
 hazards.advance(.02);assert(not hazards.hazards.has(100) and hazards.blast_count==1)
 assert(g.grill[0]==null and g.grill[1]==far,"Only burgers inside ten inches are destroyed")
 assert(near.is_queued_for_deletion());assert(not far.is_queued_for_deletion())
 hazards.spawn_local({"id":101,"age":0.0,"heat":0.0,"start":Vector3(0,3,7),"target":pos,"round":boss.generation})
 hazards.advance(3.301);assert(not hazards.hazards.has(101),"One large step must include only the landed part in cooking")
 hazards.spawn_local({"id":102,"age":0.0,"heat":0.0,"start":Vector3(0,3,7),"target":pos,"round":boss.generation})
 var remote=RemoteBoss.new();root.add_child(remote);remote.generation=boss.generation;remote.customer=boss.customer
 hazards.clear();hazards.boss=remote
 hazards.sync_hazards([{"id":200,"age":1.8,"heat":1.8,"start":Vector3(0,3,7),"target":pos,"round":boss.generation}],boss.generation)
 hazards.advance(1.0);assert(hazards.hazards.has(200),"Client must wait for the host explosion")
 var synced=Patty.new();synced.net_id=9003;g.patties_root.add_child(synced);synced.position=pos;g.grill.append(synced)
 hazards.receive_blast(200,pos,[9003],boss.generation)
 assert(not hazards.hazards.has(200) and synced.is_queued_for_deletion(),"Host explosion removes the same network burger on client")
 hazards.sync_hazards([{"id":201}],boss.generation-1);assert(hazards.hazards.is_empty(),"Old battle packets must be ignored")
 hazards.boss=boss
 hazards.spawn_local({"id":202,"age":0.0,"heat":0.0,"start":Vector3(0,3,7),"target":pos,"round":boss.generation})
 boss.cancel();assert(hazards.hazards.is_empty(),"Ending challenge clears all bombs")
 print("HOTDOG_PROJECTILES_OK: throw/recovery, 2 heated seconds, cold-grill pause, 10-inch boundary, client synchronization, cleanup")
 quit()
