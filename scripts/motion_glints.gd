extends MeshInstance3D
var previous_position := Vector3.ZERO
var previous_basis := Basis.IDENTITY
var initialized := false
func _process(delta: float) -> void:
 if not initialized:
  previous_position=global_position;previous_basis=global_basis;initialized=true
 var speed := global_position.distance_to(previous_position)/maxf(delta,.001)
 var turning := (global_basis.x-previous_basis.x).length()/maxf(delta,.001)
 if material_override is ShaderMaterial:
  material_override.set_shader_parameter("motion_amount",smoothstep(.025,.6,speed+turning*.1))
 previous_position=global_position;previous_basis=global_basis
