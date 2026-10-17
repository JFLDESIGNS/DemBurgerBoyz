extends SceneTree
func _initialize():call_deferred("run")
func run():
 var arena=load("res://scripts/truck_arena.gd").new()
 root.add_child(arena)
 var click=InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
 arena._input(click)
 assert(arena.burst_queued)
 arena.burst_queued=false;click.pressed=false
 arena._input(click)
 assert(not arena.burst_queued)
 click.pressed=true;click.button_index=MOUSE_BUTTON_RIGHT
 arena._input(click)
 assert(not arena.burst_queued)
 var key=InputEventKey.new();key.keycode=KEY_E;key.pressed=true
 arena._input(key)
 assert(arena.burst_queued)
 arena.burst_queued=false;arena.finished=true;click.button_index=MOUSE_BUTTON_LEFT
 arena._input(click)
 assert(not arena.burst_queued)
 arena.free()
 print("TRUCK_MOUSE_FIRE_OK")
 quit()
