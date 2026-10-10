extends SceneTree
class ReadyPatty extends Area3D:
	func can_scoop() -> bool: return true
func _initialize(): call_deferred("run")
func run():
	var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/turbo_polish_fixture.gd"));root.add_child(g);current_scene=g;g.playing=true
	g.stations=[{"items":[],"patties":[]}]
	var bun=g._make_held_bun();bun.set_process(false)
	bun.cook_time=7.99;assert(not g._roomba_food_ready(bun))
	g._roomba_commit_scoop_patty(bun,0);assert(g.grill_roomba_carry_patty==null)
	bun.cook_time=8;assert(g._roomba_food_ready(bun))
	bun.is_held=false;bun.heating=true;bun.refresh_cook_visuals()
	assert(not bun.get_node("Top").position.is_zero_approx())
	assert(not bun.get_node("Bottom").position.is_zero_approx())
	bun.is_held=true;bun.refresh_cook_visuals();assert(bun.get_node("Top").position==Vector3.ZERO)
	var patty=ReadyPatty.new();g.add_child(patty);patty.position=Vector3(-1.0,1.0,1.0)
	g._roomba_commit_scoop_patty(patty,0);assert(g.tossed==1 and g.grill_roomba_carry_patty==null)
	var social=load("res://scripts/customer_social.gd").new();g.add_child(social);social.set_process(false)
	var a=Node.new();var b=Node.new();g.add_child(a);g.add_child(b)
	assert(social.encounter_outcome(a,b,.5)=="reply")
	for i in 100: assert(social.encounter_outcome(b,a,.86)!="love","No repeat love roll, including reversed pair order")
	var count=0
	for i in 100:
		a.remove_meta("romance_checked_partners");b.remove_meta("romance_checked_partners")
		if social.encounter_outcome(a,b,(i+.5)/100.0)=="love":count+=1
	assert(count==2)
	assert(load("res://scripts/shift_visits.gd")!=null)
	assert(load("res://scripts/customer.gd")!=null)
	print("TURBO_SOCIAL_POLISH_OK: 8s bun readiness, local simmer, distant Build toss, single 2% pair roll")
	quit()
