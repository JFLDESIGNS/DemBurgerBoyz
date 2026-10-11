extends "res://tests/burger_serve_fixture.gd"
var throw_samples: Array = []
var garbage_hits := 0
func _physical_garbage_react() -> void: garbage_hits += 1
func _sample_rejected_burger_throw(stack: Control, origin: Vector2, start_scale: Vector2, progress: float) -> void:
	super._sample_rejected_burger_throw(stack, origin, start_scale, progress)
	throw_samples.append({"progress":progress,"origin":origin,"center":stack.get_global_transform()*stack.pivot_offset,"target":camera.unproject_position(_garbage_lerp_target_world())})
