extends SceneTree
class BossGate extends Node:
 var enabled = true
 func active(): return enabled
func _initialize(): call_deferred("run")
func run():
 create_timer(25).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate()
 g.set_script(load("res://tests/mobile_boss_pause_fixture.gd"));root.add_child(g);g.playing=true
 var phone=VBoxContainer.new();g.get_node("UI/Root").add_child(phone)
 var m=load("res://scripts/grubbah.gd").new();g.add_child(m);m.setup(g,phone);m.set_process(false)
 m.state={"number":42,"items":["bun_bottom","patty","bun_top"],"phase":"accepted","base":15,"quality":1.0}
 m.sync_ticket();assert(is_instance_valid(m.ticket_owner))
 var gate=BossGate.new();root.add_child(gate);g._hotdog_challenge=gate
 m.age=4.0;m.wait_time=12.0;m._process(3.0)
 assert(not is_instance_valid(m.ticket_owner));assert(m.age==4.0 and m.wait_time==12.0)
 assert(m.state.number==42 and m.state.phase=="accepted")
 m.apply_command("cancel",42,1);assert(not m.state.is_empty())
 gate.enabled=false;m.sync_ticket()
 assert(is_instance_valid(m.ticket_owner) and g.tickets.has(m.ticket_owner))
 assert(g.get_node("UI/Root/WindowTicketRail").position.x==270.0)
 print("MOBILE_BOSS_PAUSE_OK: ticket hidden, timers frozen, order preserved and restored; rail shifted 50px")
 quit()
