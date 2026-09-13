extends RefCounted
## Presentation timing comes from the selected authored clips, not fixed delays.
static func plan(grab_seconds: float, eat_seconds: float, elapsed_grab: float) -> Dictionary:
	return {
		"catch_hold": maxf(0.0, grab_seconds - elapsed_grab),
		"lift_to_bite": eat_seconds * .27,
		"bite_to_finish": eat_seconds * .73,
	}

static func append_handoff(tween: Tween, customer: Node3D, elapsed_grab: float, follow_hands: Callable, bite: Callable, finished: Callable) -> void:
	var grab := 1.6
	var eat := 2.2
	if is_instance_valid(customer) and customer.has_method("burger_animation_duration"):
		grab = customer.burger_animation_duration(false)
		eat = customer.burger_animation_duration(true)
	var timing := plan(grab,eat,elapsed_grab)
	if timing.catch_hold > .001:
		tween.tween_method(follow_hands,0.0,0.0,timing.catch_hold)
	# Three complete, faster lifts; each contact removes exactly one visible bite.
	var cycle_seconds := eat / 2.4
	for index in 3:
		var before := float(index) / 3.0
		var after := float(index + 1) / 3.0
		tween.tween_callback(func() -> void:
			if is_instance_valid(customer) and customer.has_method("start_eating_burger"):
				customer.start_eating_burger()
		)
		tween.tween_method(follow_hands,before,before,cycle_seconds * 0.27)
		tween.tween_callback(bite)
		tween.tween_method(follow_hands,before,after,0.07)
		tween.tween_method(follow_hands,after,after,maxf(0.01,cycle_seconds * 0.73 - 0.07))
	tween.tween_callback(finished)
