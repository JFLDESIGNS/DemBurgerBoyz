extends RefCounted
const FUR = preload("res://shaders/cat_fur.gdshader")
static func apply_fur(root: Node) -> void:
	var material:=ShaderMaterial.new()
	material.shader=FUR
	for part_name in ["Cat_Body","Cat_Tail"]:
		var part=root.find_child(part_name,true,false) as MeshInstance3D
		if part: part.material_override=material

static func apply_eyes(root: Node) -> void:
	for eye_name in ["Cat_Eye_L", "Cat_Eye_R"]:
		var eye := root.find_child(eye_name,true,false) as MeshInstance3D
		if eye:
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/cat_eyes.gdshader")
			material.set_shader_parameter("pupil_gaze",Vector2.ZERO)
			eye.material_override = material
