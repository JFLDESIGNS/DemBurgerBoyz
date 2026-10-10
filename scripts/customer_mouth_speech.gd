extends Node
var materials: Array[ShaderMaterial] = []
var elapsed := 0.0
var duration := 0.0
var rate := 1.0
var amount := 0.0
func start(seconds: float, pitch: float = 1.0) -> void:
 materials.clear()
 for mesh in get_parent().find_children("*", "MeshInstance3D", true, false):
  var material=mesh.material_override
  if material is ShaderMaterial and material.get_meta("wawa_mouth",false):materials.append(material)
 elapsed=0.0;duration=maxf(0.0,seconds);rate=pitch
 set_process(not materials.is_empty())
func stop() -> void:
 duration=elapsed
 set_process(not materials.is_empty())
func _process(delta: float) -> void:
 elapsed+=delta
 var target:=0.0
 if elapsed<duration:
  var syllable:=pow(.5+.5*sin(elapsed*TAU*4.8*rate),.7)
  target=syllable*smoothstep(0.0,.06,elapsed)*(1.0-smoothstep(maxf(0.0,duration-.12),duration,elapsed))
 amount=lerpf(amount,target,1.0-exp(-delta*32.0))
 if elapsed>=duration and amount<.005:amount=0.0;set_process(false)
 for material in materials:material.set_shader_parameter("speech_round",amount)
