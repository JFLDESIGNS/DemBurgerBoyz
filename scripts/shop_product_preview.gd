extends SubViewportContainer

## Lightweight 3D product turntable used by the phone marketplace.
var turntable: Node3D = null
var _dragging := false
var _auto_resume := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process(true)


func bind_turntable(node: Node3D) -> void:
	turntable = node


func _gui_input(event: InputEvent) -> void:
	## RMB drag avoids fighting the phone's normal left-drag scrolling.
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mouse.pressed
			_auto_resume = 1.4
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		if turntable != null and is_instance_valid(turntable):
			turntable.rotation.y -= motion.relative.x * 0.018
		_auto_resume = 1.4
		accept_event()


func _process(delta: float) -> void:
	if turntable == null or not is_instance_valid(turntable) or not is_visible_in_tree():
		return
	if _dragging:
		return
	if _auto_resume > 0.0:
		_auto_resume = maxf(0.0, _auto_resume - delta)
		return
	turntable.rotation.y += delta * 0.38
