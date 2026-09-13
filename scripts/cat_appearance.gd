extends RefCounted
const FUR = preload("res://shaders/cat_fur.gdshader")
static func apply_fur(root: Node) -> void:
	var material:=ShaderMaterial.new()
	material.shader=FUR
	for part_name in ["Cat_Body","Cat_Tail"]:
		var part=root.find_child(part_name,true,false) as MeshInstance3D
		if part: part.material_override=material
