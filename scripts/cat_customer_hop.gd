extends Node3D
# A separate visual pivot lets the cat hop without fighting its visit/animation pose.
var progress := 0.0
var hold_left := 0.0

static func attach(visual: Node3D) -> void:
	if not is_instance_valid(visual): return
	var pivot = load("res://scripts/cat_customer_hop.gd").new()
	pivot.name = "CustomerPassingHop"
	visual.get_parent().add_child(pivot)
	visual.reparent(pivot, false)

func path_needs_room(person: Node3D, origin: Vector3) -> bool:
	if not is_instance_valid(person) or not person.is_visible_in_tree() or person.is_ragdoll: return false
	var goal: float = person.LEAVE_OFFSCREEN_X if person.is_leaving else person.target_x
	if person.is_leaving:
		match person._leave_phase:
			"walk_off": pass
			"sidestep": goal = person._leave_dance_x
			"walk_to_review", "walk_partner_wait": goal = person._leave_start_x
			_: return false
	var dx := goal-person.global_position.x
	if absf(dx)<.05: return false
	if absf(person.global_position.z-origin.z)>1.15: return false
	var ahead := (origin.x-person.global_position.x)*signf(dx)
	return ahead> -1.15 and ahead<2.2 and (goal-origin.x)*signf(dx)>-.35

func _process(delta: float) -> void:
	var game := get_tree().current_scene
	if not is_instance_valid(game) or not get_parent().is_visible_in_tree():
		progress=0.0;hold_left=0.0;position=Vector3.ZERO
		return
	var origin: Vector3 = get_parent().global_position
	var people: Array = []
	var current = game.get("customers")
	if current is Array: people.append_array(current)
	for person in get_tree().get_nodes_in_group("cat_passing_customers"):
		if not people.has(person):people.append(person)
	var passing := false
	for person in people:
		if path_needs_room(person,origin):passing=true;break
	if passing:hold_left=.8
	else:hold_left=maxf(0.0,hold_left-delta)
	var before := progress
	progress=move_toward(progress,1.0 if hold_left>0.0 else 0.0,delta/(.28 if hold_left>0.0 else .5))
	var lift := sin(PI*progress)*.36 if not is_equal_approx(before,progress) else 0.0
	var offset := Vector3(0,lift,1.25*smoothstep(0.0,1.0,progress))
	position=get_parent().global_basis.inverse()*offset
