extends SceneTree
class VoiceProbe extends "res://scripts/game_audio.gd":
 var calls: Array = []
 func _ready(): pass
 func _play_announcer_stream(key: String, _path: String, _gain: float = .65, _pitch: float = 1.0): calls.append(key)
func _initialize(): call_deferred("run")
func run():
 var audio=VoiceProbe.new();root.add_child(audio)
 for late in [0.0,2.0,5.0]:audio.play_flip_grade_announcer("late",late)
 audio.play_delivery_time_announcer(22);audio.play_challenge_fail_ohhh()
 assert(audio.calls.is_empty(),"Ohh is reserved for a flip more than five seconds late")
 audio.play_flip_grade_announcer("late",5.01)
 assert(audio.calls==["order_ohhh_announcer"])
 var g=load("res://scenes/main.tscn").instantiate()
 g.set_script(load("res://tests/mobile_packing_fixture.gd"));root.add_child(g);current_scene=g
 g.stations=[{"items":[],"patties":[]}]
 var phone=VBoxContainer.new();g.get_node("UI/Root").add_child(phone)
 var m=load("res://scripts/grubbah.gd").new();g.add_child(m);m.set_process(false);g._grubbah=m;m.setup(g,phone)
 m.state={"number":3,"items":["bun_bottom","patty","bun_top"],"phase":"bagging","base":20}
 m.refresh();m.build_props();m.driver_style=3
 m.age=.2;m.update_visuals(.02)
 var initial=m.wrapped.rotation
 m.age=.35;m.update_visuals(.15)
 assert(m.wrapped.rotation.distance_to(initial)>.5,"Wrapped burger must tumble in flight")
 m.age=m.BURGER_BAG_FLIGHT*.84;m.update_visuals(.17)
 m.age+=.05;m.update_visuals(.05)
 assert(m.bag.scale.y<.95,"Item arrival must visibly compress the bag")
 m.state["side_packs"]={"fries":{"kind":"fries","elapsed":m.SIDE_BAG_FLIGHT*.84}}
 m.bag_bounce_age=2.0;m.update_side_visuals()
 assert(is_zero_approx(m.bag_bounce_age),"Fries landing triggers its own impact")
 m.bag_bounce_age=2.0;m.update_side_visuals()
 assert(is_equal_approx(m.bag_bounce_age,2.0),"A landed item must not retrigger every frame")
 m.state.side_packs["soda_cola"]={"kind":"drink","elapsed":m.SIDE_BAG_FLIGHT*.84}
 m.update_side_visuals()
 assert(is_zero_approx(m.bag_bounce_age),"Drink landing triggers its own impact")
 m.state.phase="sealed";m.age=m.BAG_PICKUP_FLIGHT*.4;m.update_visuals(.1)
 assert(absf(m.bag.rotation.y)>.5,"Bag must bank toward pickup")
 assert(m.pickup_bag_position(1,Vector3.ZERO,Vector3.ONE).is_equal_approx(Vector3.ONE))
 m.state.phase="pickup";m.age=0;m.update_visuals(.1)
 g.camera.position=Vector3(.2,2.2,3);g.camera.look_at(m.bag.global_position+Vector3(0,.2,0))
 assert(m._bag_finish_hit(g.camera.unproject_position(m.bag.global_position+Vector3(0,.2,0))),"Pickup bag remains tappable")
 var a=load("res://scripts/mobile_ticket_owner.gd").new();var b=load("res://scripts/mobile_ticket_owner.gd").new()
 g.add_child(a);g.add_child(b);g.selected_customer=a;g._create_ticket(a);g._create_ticket(b)
 var queued=g.tickets[b].get_meta("ticket_motion")
 assert(queued.active and queued.state==&"fly","Queued ticket starts rolled arrival")
 assert(is_equal_approx(queued.display_scale,g.TICKET_SMALL_SCALE))
 queued.set_process(false);queued._advance_arrival(.6)
 assert(queued.state==&"unroll")
 g.selected_customer=b;g._highlight_tickets()
 assert(queued.state==&"unroll" and is_equal_approx(queued.display_scale,.8),"Promotion preserves rollout progress")
 print("BAG_POLISH_OK: tumble, impact, banking, tapping, queued rollout, late voice boundary")
 quit()
