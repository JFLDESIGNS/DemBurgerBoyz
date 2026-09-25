extends Node3D
var game: Node
var sign_node: Node3D
var dragging := false
var swing := 0.0
var speed := 0.0
var target := 0.0
var drag_distance := 0.0
func setup(g: Node, sign: Node3D) -> void:
 game=g
 sign_node=sign
func begin_drag(_screen_pos: Vector2) -> bool:
 if not is_instance_valid(game.camera): return false
 drag_distance=0.0
 dragging=true
 target=swing
 return true
func _input(event: InputEvent) -> void:
 if not dragging: return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
  dragging=false
  get_viewport().set_input_as_handled()
 elif event is InputEventMouseMotion:
  drag_distance+=event.relative.length()
  if drag_distance>4.0: game._open_sign_last_click_ms=-1
  target=clampf(target-event.relative.x*0.008,-0.85,0.85)
  get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
 if not is_instance_valid(game) or not game.playing:
  dragging=false
 if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): dragging=false
 var dt:=minf(delta,0.033)
 var stiffness:=65.0 if dragging else 16.0
 var damping:=10.0 if dragging else 2.2
 speed+=((target if dragging else 0.0)-swing)*stiffness*dt
 speed*=exp(-damping*dt)
 swing=clampf(swing+speed*dt,-0.95,0.95)
 rotation.z=swing
