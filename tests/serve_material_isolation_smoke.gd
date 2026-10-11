extends SceneTree

func _initialize(): call_deferred("run")

func run():
	var side_script=load("res://scripts/side_food_serve.gd")
	var a=side_script.new()
	var b=side_script.new()
	var bounds=AABB(Vector3.ZERO,Vector3.ONE)
	var shared=a._bite_material(Color.YELLOW,null,bounds)
	assert(shared==a._bite_material(Color.YELLOW,null,bounds),"Identical fries in one serving share bite uniforms")
	assert(shared!=a._bite_material(Color.RED,null,bounds),"Different food colors stay independent")
	var other=b._bite_material(Color.YELLOW,null,bounds)
	shared.set_shader_parameter("consumed",.67)
	assert(shared!=other and is_zero_approx(float(other.get_shader_parameter("consumed"))),"Eating one serving cannot consume another")
	var customer_script=load("res://scripts/customer.gd")
	var first=customer_script.new()
	var second=customer_script.new()
	var source=StandardMaterial3D.new()
	source.albedo_color=Color.YELLOW
	var faded=first._material_for_fade(source)
	assert(faded==first._material_for_fade(source),"Repeated limb materials share one private fade copy")
	assert(faded!=source and faded!=second._material_for_fade(source),"Customers must own independent fade copies")
	first._set_material_alpha(faded,.25)
	assert(is_equal_approx(source.albedo_color.a,1.0),"Fading leaves the original appearance unchanged")
	var shader_code="shader_type spatial; uniform vec4 tint : source_color = vec4(1.0); void fragment(){ ALBEDO=tint.rgb; }"
	for color in [Color.RED,Color.BLUE]:
		var material=ShaderMaterial.new()
		material.shader=Shader.new()
		material.shader.code=shader_code
		material.set_shader_parameter("tint",color)
		var copy=first._shader_material_for_fade(material)
		assert(copy.get_shader_parameter("tint")==color,"Shared fade shaders must preserve each material's own values")
		assert(copy.shader.code.contains("fade_alpha"),"The copied material must use the fade shader")
	a.free();b.free();first.free();second.free()
	print("SERVE_MATERIAL_ISOLATION_OK")
	quit()
