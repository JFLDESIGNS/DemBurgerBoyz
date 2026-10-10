extends Node3D
var materials: Array[ShaderMaterial] = []
var previous := Transform3D.IDENTITY
var initialized := false
func _ready() -> void:
	for mesh in get_parent().find_children("*","MeshInstance3D",true,false):
		collect(mesh.material_override)
	collect(get_parent().material_override)
func collect(material: Material) -> void:
	if material == null: return
	if material is ShaderMaterial and not materials.has(material): materials.append(material)
	if material.next_pass: collect(material.next_pass)
func _process(delta: float) -> void:
	var pose := global_transform
	var motion := 0.0
	if initialized:
		motion = smoothstep(.025,.6,(pose.origin.distance_to(previous.origin)+(pose.basis.x-previous.basis.x).length()*.1)/maxf(delta,.001))
	previous = pose; initialized = true
	for material in materials: material.set_shader_parameter("motion_amount",motion)
