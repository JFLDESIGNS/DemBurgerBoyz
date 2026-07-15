## Procedural 2D food textures for burger stations + spatula cursor.
extends RefCounted
class_name FoodSprites

static var _cache: Dictionary = {}


static func get_tex(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var tex: ImageTexture
	match id:
		"plate":
			tex = _make_plate()
		"spatula":
			tex = _make_spatula()
		"bun_top":
			tex = _make_bun(true)
		"bun_bottom":
			tex = _make_bun(false)
		"patty":
			tex = _make_patty(Color("6D4C41"))
		"cheese":
			tex = _make_square_layer(Color("F4C430"), 90, 28, 4)
		"lettuce":
			tex = _make_wavy_layer(Color("4CAF50"), 96, 26)
		"tomato":
			tex = _make_round_layer(Color("E53935"), 88, 22)
		"onion":
			tex = _make_ring_layer(Color("CE93D8"), 86, 20)
		"bacon":
			tex = _make_bacon()
		"pickle":
			tex = _make_round_layer(Color("7CB342"), 70, 18)
		"ketchup":
			tex = _make_sauce(Color("D32F2F"))
		"mustard":
			tex = _make_sauce(Color("F9A825"))
		_:
			tex = _make_round_layer(Color.WHITE, 80, 20)
	_cache[id] = tex
	return tex


static func patty_tex(color: Color) -> Texture2D:
	var key := "patty_%s" % color.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var tex := _make_patty(color)
	_cache[key] = tex
	return tex


static func _img(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _set_circle(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var nx := (x - cx) / rx
			var ny := (y - cy) / ry
			if nx * nx + ny * ny <= 1.0:
				var edge := clampf(1.0 - (nx * nx + ny * ny), 0.0, 1.0)
				var c := col
				c.a *= 0.55 + edge * 0.45
				## Soft shade
				c = c.darkened((ny + 1.0) * 0.08)
				img.set_pixel(x, y, c)


static func _make_plate() -> ImageTexture:
	var img := _img(140, 140)
	_set_circle(img, 70, 70, 66, 66, Color("D7D7D7"))
	_set_circle(img, 70, 70, 54, 54, Color("F2F2F2"))
	_set_circle(img, 70, 70, 40, 40, Color("E8E8E8"))
	return ImageTexture.create_from_image(img)


static func _make_bun(is_top: bool) -> ImageTexture:
	var img := _img(120, 44)
	var base := Color("E8A85C") if is_top else Color("D4924A")
	_set_circle(img, 60, 28 if is_top else 18, 54, 18, base)
	if is_top:
		## Sesame dots
		for i in 8:
			var a := TAU * float(i) / 8.0
			var sx := int(60 + cos(a) * 28)
			var sy := int(22 + sin(a) * 8)
			if sx >= 0 and sy >= 0 and sx < 120 and sy < 44:
				img.set_pixel(sx, sy, Color("FFF8E1"))
				if sx + 1 < 120:
					img.set_pixel(sx + 1, sy, Color("FFF8E1"))
	return ImageTexture.create_from_image(img)


static func _make_patty(col: Color) -> ImageTexture:
	var img := _img(110, 34)
	_set_circle(img, 55, 17, 50, 14, col)
	## Grill lines
	for x in range(18, 92, 10):
		for y in range(10, 24):
			var p := img.get_pixel(x, y)
			if p.a > 0.2:
				img.set_pixel(x, y, p.darkened(0.25))
	return ImageTexture.create_from_image(img)


static func _make_square_layer(col: Color, w: int, h: int, radius: int) -> ImageTexture:
	var img := _img(w, h)
	for y in h:
		for x in w:
			var inset := mini(mini(x, w - 1 - x), mini(y, h - 1 - y))
			if inset >= 0:
				var corner_ok := true
				## soft corners
				if x < radius and y < radius:
					corner_ok = (x - radius) * (x - radius) + (y - radius) * (y - radius) <= radius * radius
				elif x >= w - radius and y < radius:
					corner_ok = (x - (w - radius - 1)) * (x - (w - radius - 1)) + (y - radius) * (y - radius) <= radius * radius
				elif x < radius and y >= h - radius:
					corner_ok = (x - radius) * (x - radius) + (y - (h - radius - 1)) * (y - (h - radius - 1)) <= radius * radius
				elif x >= w - radius and y >= h - radius:
					corner_ok = (x - (w - radius - 1)) * (x - (w - radius - 1)) + (y - (h - radius - 1)) * (y - (h - radius - 1)) <= radius * radius
				if corner_ok:
					img.set_pixel(x, y, col.darkened(float(y) / float(h) * 0.12))
	return ImageTexture.create_from_image(img)


static func _make_wavy_layer(col: Color, w: int, h: int) -> ImageTexture:
	var img := _img(w, h)
	for y in h:
		for x in w:
			var wave := sin(x * 0.35) * 3.0
			var top := 4.0 + wave
			var bot := h - 4.0 + sin(x * 0.4 + 1.0) * 2.0
			if y >= top and y <= bot:
				var edge := mini(y - top, bot - y) / 4.0
				var c := col.lightened(clampf(edge, 0.0, 0.2))
				c.a = clampf(edge + 0.5, 0.0, 1.0)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _make_round_layer(col: Color, w: int, h: int) -> ImageTexture:
	var img := _img(w, h)
	_set_circle(img, w * 0.5, h * 0.5, w * 0.45, h * 0.4, col)
	return ImageTexture.create_from_image(img)


static func _make_ring_layer(col: Color, w: int, h: int) -> ImageTexture:
	var img := _img(w, h)
	var cx := w * 0.5
	var cy := h * 0.5
	for y in h:
		for x in w:
			var nx := (x - cx) / (w * 0.42)
			var ny := (y - cy) / (h * 0.38)
			var d := nx * nx + ny * ny
			if d <= 1.0 and d >= 0.35:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _make_bacon() -> ImageTexture:
	var img := _img(100, 22)
	for y in 22:
		for x in 100:
			var stripe := int(x / 8) % 2 == 0
			var c := Color("C62828") if stripe else Color("FFCCBC")
			var wave := int(sin(x * 0.2) * 2.0)
			if y > 3 + wave and y < 18 + wave:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _make_sauce(col: Color) -> ImageTexture:
	var img := _img(90, 14)
	for y in 14:
		for x in 90:
			var wave := sin(x * 0.25) * 2.5
			if absf(y - 7.0 - wave) < 3.5:
				var c := col
				c.a = 0.9
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _make_spatula() -> ImageTexture:
	var img := _img(96, 96)
	## Handle
	for y in range(40, 90):
		for x in range(42, 54):
			img.set_pixel(x, y, Color("5D4037"))
	## Blade
	for y in range(12, 42):
		for x in range(18, 78):
			var c := Color("B0BEC5")
			if y < 16 or x < 22 or x > 74:
				c = Color("90A4AE")
			img.set_pixel(x, y, c)
	## Slots in blade
	for x in [30, 48, 66]:
		for y in range(18, 36):
			img.set_pixel(x, y, Color(0, 0, 0, 0))
			if x + 1 < 96:
				img.set_pixel(x + 1, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)
