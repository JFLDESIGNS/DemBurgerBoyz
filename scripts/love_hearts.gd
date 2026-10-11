extends RefCounted
## Shared, cached candy hearts: five sprites per burst, no per-frame scripts.
static var texture: ImageTexture
static func heart_texture() -> ImageTexture:
	if texture != null: return texture
	var image := Image.create(96,96,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in 96:
		for x in 96:
			var hx := (float(x)/95.0*2.0-1.0)*1.45
			var hy := (1.0-float(y)/95.0*2.0)*1.45+.12
			var a := hx*hx+hy*hy-1.0
			var shape := a*a*a-hx*hx*hy*hy*hy
			if shape >= 0.0: continue
			var color := Color("F34E83").lerp(Color("B92152"),float(y)/95.0*.65)
			if shape > -.07: color = Color("AD254D")
			var glint := Vector2(hx+.43,(hy-.57)*1.7).length()
			if glint < .19: color = color.lerp(Color("FFE3EC"),.85)
			color.a = clampf(-shape*100.0,0,1)
			image.set_pixel(x,y,color)
	image.generate_mipmaps()
	texture = ImageTexture.create_from_image(image)
	return texture

static func burst(parent: Node3D, at: Vector3, size: float = 1.0) -> void:
	for i in 5:
		var heart := Sprite3D.new()
		heart.name = "LoveHeart"
		heart.texture = heart_texture()
		heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		heart.pixel_size = .0022*size
		heart.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		heart.position = at + Vector3((i-2)*.075*size,0,0)
		heart.modulate.a = 0.0
		heart.scale = Vector3.ONE*.25
		parent.add_child(heart, true)
		var tw := heart.create_tween()
		tw.tween_interval(i*.10)
		tw.tween_property(heart,"modulate:a",1.0,.12)
		tw.parallel().tween_property(heart,"scale",Vector3.ONE*(.75+.16*(i%3)),.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(heart,"position",heart.position+Vector3((i-2)*.065*size,(.48+.07*(i%3))*size,0),1.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(heart,"modulate:a",0.0,.38)
		tw.parallel().tween_property(heart,"scale",Vector3.ONE*.45,.38)
		tw.tween_callback(heart.queue_free)
