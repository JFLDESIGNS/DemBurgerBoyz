extends Node3D
var game: Node
var sign_node: Node3D
var dragging := false
var swing := 0.0
var speed := 0.0
var target := 0.0
var drag_distance := 0.0
var remote_hold := 0.0
var send_clock := 0.0
var was_dragging := false
func setup(g: Node, sign: Node3D) -> void:
 game=g
 sign_node=sign
func begin_drag(_screen_pos: Vector2) -> bool:
 if not is_instance_valid(game.camera): return false
 drag_distance=0.0
 dragging=true
 remote_hold=0.0
 target=swing
 _send_pose()
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
 remote_hold=maxf(0.0,remote_hold-delta)
 if is_instance_valid(game) and game.mp_enabled:
  send_clock+=delta
  if dragging and send_clock>=.05:
   send_clock=0.0
   _send_pose()
  elif was_dragging and not dragging: _send_pose()
 was_dragging=dragging
 var held:=dragging or remote_hold>0.0
 var dt:=minf(delta,0.033)
 var stiffness:=65.0 if held else 16.0
 var damping:=10.0 if held else 2.2
 speed+=((target if held else 0.0)-swing)*stiffness*dt
 speed*=exp(-damping*dt)
 swing=clampf(swing+speed*dt,-0.95,0.95)
 rotation.z=swing

func _send_pose() -> void:
 if is_instance_valid(game) and game.mp_enabled and NetManager.is_online(): game.mp_sign_motion.rpc(swing,speed,dragging,target)

func apply_network_pose(angle: float,velocity: float,held: bool,aim: float) -> void:
 dragging=false
 was_dragging=false
 swing=clampf(angle,-.95,.95)
 speed=clampf(velocity,-8.0,8.0)
 target=clampf(aim,-.85,.85)
 remote_hold=.35 if held else 0.0
 rotation.z=swing
