extends CanvasLayer
var game: Node
var parade: Node3D
var screen: ColorRect
var remaining := 0.0

func setup(owner_game: Node, march: Node3D) -> void:
 game=owner_game;parade=march
 layer=95
 screen=ColorRect.new()
 screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 screen.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var ink:=ShaderMaterial.new()
 ink.shader=preload("res://shaders/parade_film.gdshader")
 screen.material=ink
 add_child(screen)
 screen.hide()
 parade.parade_started.connect(func(reason):
  if reason != "challenge":
   stop_film()
   return
  remaining=8.0;screen.show()
  if reason == "challenge": game._show_challenge_banner("BURGER CHALLENGE — GO!",Color("FFE6A3"),2.5)
 )

func stop_film() -> void:
 remaining=0.0
 if is_instance_valid(screen): screen.hide()

func _process(delta: float) -> void:
 if remaining>0.0:
  remaining=maxf(0.0,remaining-delta)
  screen.material.set_shader_parameter("amount",minf(1.0,remaining/.6))
  if remaining<=0.0: screen.hide()
