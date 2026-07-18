## Procedural 2D food textures for burger stations + spatula cursor.
## Ingredient art prefers sliced PNGs from assets/ingredients/ when present.
extends RefCounted
class_name FoodSprites

const INGREDIENT_DIR := "res://assets/ingredients/"

static var _cache: Dictionary = {}
static var _content_aspect_cache: Dictionary = {}


static func texture_content_aspect(tex: Texture2D) -> float:
	## Opaque-pixel aspect (h/w) — ignores empty sheet padding (e.g. burger_cheese).
	if tex == null:
		return 1.0
	var key: int = tex.get_instance_id()
	if _content_aspect_cache.has(key):
		return _content_aspect_cache[key]
	var img: Image = tex.get_image()
	if img == null:
		_content_aspect_cache[key] = 1.0
		return 1.0
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	if w < 1 or h < 1:
		_content_aspect_cache[key] = 1.0
		return 1.0
	var min_x := w
	var max_x := -1
	var min_y := h
	var max_y := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.08:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		_content_aspect_cache[key] = float(h) / float(w)
		return _content_aspect_cache[key]
	var cw := float(max_x - min_x + 1)
	var ch := float(max_y - min_y + 1)
	var aspect := ch / maxf(cw, 1.0)
	_content_aspect_cache[key] = aspect
	return aspect


static func get_tex(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var tex: Texture2D = _try_load_ingredient(id)
	if tex == null:
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
			"wood":
				tex = _make_toon_wood()
			"wood_inset":
				tex = _make_toon_wood_inset()
			"warmer_tray":
				tex = _make_warmer_tray()
			"cutting_board":
				tex = _make_toon_wood_inset()
			_:
				tex = _make_round_layer(Color.WHITE, 80, 20)
	_cache[id] = tex
	return tex


static func burger_cheese_tex(cook_color: Color = Color(0.45, 0.24, 0.14), char_amount: float = 0.0) -> Texture2D:
	## Patty + melted cheese sheet for Build stacks (replaces separate cheese layer art).
	var char_q := snappedf(clampf(char_amount, 0.0, 1.0), 0.05)
	var key := "burger_cheese_%s_c%.2f" % [cook_color.to_html(false), char_q]
	if _cache.has(key):
		return _cache[key]
	var base := _get_burger_cheese_sheet_image()
	var tex: Texture2D
	if base != null:
		var img := base.duplicate()
		_tint_patty_sheet(img, cook_color, char_q)
		tex = ImageTexture.create_from_image(img)
	else:
		tex = get_tex("cheese")
	_cache[key] = tex
	return tex


static var _burger_cheese_sheet_img: Image = null


static func _get_burger_cheese_sheet_image() -> Image:
	if _burger_cheese_sheet_img != null:
		return _burger_cheese_sheet_img
	var path := INGREDIENT_DIR + "burger_cheese.png"
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			var img: Image = res.get_image()
			if img != null:
				if img.is_compressed():
					img.decompress()
				img.convert(Image.FORMAT_RGBA8)
				_knockout_dark_backdrop(img)
				img = _crop_to_opaque(img)
				_burger_cheese_sheet_img = img
				return _burger_cheese_sheet_img
	var fallback := "res://IMAGES/BURGERCHEEESE.png"
	if ResourceLoader.exists(fallback):
		var fb = load(fallback)
		if fb is Texture2D:
			var img2: Image = fb.get_image()
			if img2 != null:
				if img2.is_compressed():
					img2.decompress()
				img2.convert(Image.FORMAT_RGBA8)
				_knockout_dark_backdrop(img2)
				img2 = _crop_to_opaque(img2)
				_burger_cheese_sheet_img = img2
				return _burger_cheese_sheet_img
	return null


static func _crop_to_opaque(img: Image, alpha_cut: float = 0.08) -> Image:
	## Trim transparent / knocked-out padding so TextureRect aspect matches the food.
	if img == null:
		return img
	var w := img.get_width()
	var h := img.get_height()
	if w < 2 or h < 2:
		return img
	var min_x := w
	var max_x := -1
	var min_y := h
	var max_y := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > alpha_cut:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return img
	## Tiny pad so melt edges aren't clipped.
	min_x = maxi(0, min_x - 2)
	min_y = maxi(0, min_y - 2)
	max_x = mini(w - 1, max_x + 2)
	max_y = mini(h - 1, max_y + 2)
	var cw := max_x - min_x + 1
	var ch := max_y - min_y + 1
	if cw >= w - 1 and ch >= h - 1:
		return img
	return img.get_region(Rect2i(min_x, min_y, cw, ch))


static func prep_ingredients_tex() -> Texture2D:
	## Wire baskets + produce beside the Build board (left of grill).
	if _cache.has("prep_ingredients"):
		return _cache["prep_ingredients"]
	var tex: Texture2D = null
	const path := "res://assets/props/prep_ingredients.png"
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			tex = res
			var img: Image = tex.get_image()
			if img != null and img.get_width() > 0 and img.get_height() > 0:
				if img.is_compressed():
					img.decompress()
				img.convert(Image.FORMAT_RGBA8)
				_knockout_dark_backdrop(img)
				tex = ImageTexture.create_from_image(img)
	if tex == null:
		push_warning("Prep ingredients texture missing or failed import: %s" % path)
	_cache["prep_ingredients"] = tex
	return tex


static func _try_load_ingredient(id: String) -> Texture2D:
	## Load sliced sheet art when available (transparent PNG).
	match id:
		"bun_top", "bun_bottom", "patty", "cheese", "lettuce", "tomato", "onion", "bacon", "pickle", "ketchup", "mustard", "cutting_board":
			pass
		_:
			return null
	var path := INGREDIENT_DIR + id + ".png"
	## Export-safe: imported Texture2D first (Image.load(res://) fails in shipped builds).
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			var img: Image = res.get_image()
			if img != null:
				if img.is_compressed():
					img.decompress()
				img.convert(Image.FORMAT_RGBA8)
				_knockout_dark_backdrop(img)
				if id != "cutting_board":
					img = _crop_to_opaque(img)
				return ImageTexture.create_from_image(img)
			return res
	## Editor fallback when import isn't ready yet.
	var abs_try := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or FileAccess.file_exists(abs_try):
		var img2 := Image.new()
		var err := img2.load(abs_try if FileAccess.file_exists(abs_try) else path)
		if err == OK:
			_knockout_dark_backdrop(img2)
			if id != "cutting_board":
				img2 = _crop_to_opaque(img2)
			return ImageTexture.create_from_image(img2)
	return null


static func prep_layer_image_for_composite(src: Image) -> Image:
	## Knock out studio-black padding and trim — used by review burger snapshots.
	if src == null:
		return null
	var img := src.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	_knockout_dark_backdrop(img)
	img = _crop_to_opaque(img)
	return img


static func _knockout_dark_backdrop(img: Image) -> void:
	## Ensure studio black behind cutting-board art stays fully transparent.
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var m := maxf(c.r, maxf(c.g, c.b))
			var chroma := maxf(absf(c.r - c.g), maxf(absf(c.g - c.b), absf(c.r - c.b)))
			if m < 0.22 and chroma < 0.09:
				c.a = 0.0 if m < 0.07 else c.a * clampf((m - 0.07) / 0.15, 0.0, 1.0)
				img.set_pixel(x, y, c)


static var _patty_sheet_img: Image = null


static func patty_tex(color: Color, char_amount: float = 0.0) -> Texture2D:
	## Station / ticket stack uses cutout sheet art, tinted + charred by cook state.
	var char_q := snappedf(clampf(char_amount, 0.0, 1.0), 0.05)
	var key := "patty_art_%s_c%.2f" % [color.to_html(false), char_q]
	if _cache.has(key):
		return _cache[key]
	var base := _get_patty_sheet_image()
	var tex: Texture2D
	if base != null:
		var img := base.duplicate()
		_tint_patty_sheet(img, color, char_q)
		tex = ImageTexture.create_from_image(img)
	else:
		tex = _make_patty(color)
	_cache[key] = tex
	return tex


static func _get_patty_sheet_image() -> Image:
	if _patty_sheet_img != null:
		return _patty_sheet_img
	var path := INGREDIENT_DIR + "patty.png"
	## Must use imported texture on export — raw Image.load(res://) is stripped.
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			var img: Image = res.get_image()
			if img != null:
				if img.is_compressed():
					img.decompress()
				img.convert(Image.FORMAT_RGBA8)
				_knockout_dark_backdrop(img)
				_patty_sheet_img = img
				return _patty_sheet_img
	var abs_try := ProjectSettings.globalize_path(path)
	var img2 := Image.new()
	var err := img2.load(abs_try)
	if err != OK:
		err = img2.load(path)
	if err == OK:
		_knockout_dark_backdrop(img2)
		_patty_sheet_img = img2
		return _patty_sheet_img
	return null


static func _tint_patty_sheet(img: Image, cook: Color, char_amount: float = 0.0) -> void:
	## Cook hue + progressive charcoal so Build burgers match grill burntness.
	var char_t := clampf(char_amount, 0.0, 1.0)
	## Bare cook tint is mild; ramps hard once meat starts charring.
	var tint_str := lerpf(0.42, 0.78, char_t)
	var soot := Color(0.04, 0.03, 0.02)
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var p := img.get_pixel(x, y)
			if p.a < 0.05:
				continue
			var lum := p.get_luminance()
			## Yellow cheese stays a bit readable; meat takes the charcoal.
			var is_cheese := p.r > 0.55 and p.g > 0.4 and p.b < 0.35 and (p.r - p.b) > 0.2
			var local_char := char_t * (0.35 if is_cheese else 1.0)
			var local_darken := lerpf(1.0, 0.22, local_char)
			var local_tint := tint_str * (0.55 if is_cheese else 1.0)
			var tinted := p.lerp(Color(cook.r, cook.g, cook.b, p.a), local_tint)
			## Preserve existing dark grill marks a bit.
			if lum < 0.18:
				tinted = p.lerp(tinted, 0.35)
			tinted.r *= local_darken
			tinted.g *= local_darken
			tinted.b *= local_darken
			if local_char > 0.01:
				tinted = tinted.lerp(Color(soot.r, soot.g, soot.b, p.a), local_char * 0.72)
			tinted.a = p.a
			img.set_pixel(x, y, tinted)


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
	## Side-on burger-stack buns: clear dome / heel, no hollow center.
	var w := 168
	var h := 64
	var img := _img(w, h)
	var cx := w * 0.5
	if is_top:
		_paint_top_bun(img, cx, 34.0)
	else:
		_paint_bottom_bun(img, cx, 30.0)
	return ImageTexture.create_from_image(img)


static func _paint_top_bun(img: Image, cx: float, cy: float) -> void:
	var rx := 64.0
	var ry := 24.0
	## Soft contact shadow under the crown.
	_fill_ellipse(img, cx, cy + 10.0, rx + 4.0, ry * 0.55, Color(0.15, 0.07, 0.02, 0.28), Color(0.15, 0.07, 0.02, 0.0))
	## Outer crust dome.
	_fill_ellipse(img, cx, cy, rx, ry, Color(0.86, 0.58, 0.28), Color(0.62, 0.36, 0.14))
	## Inner dough body (slightly higher so it reads as volume, not a hole).
	_fill_ellipse(img, cx, cy - 2.0, rx * 0.88, ry * 0.78, Color(0.98, 0.78, 0.48), Color(0.88, 0.60, 0.30))
	## Soft highlight on the crown.
	_fill_ellipse(img, cx - 4.0, cy - 10.0, rx * 0.42, ry * 0.32, Color(1.0, 0.92, 0.70, 0.85), Color(1.0, 0.88, 0.62, 0.0))
	## Cut-face lip along the bottom edge (warm toasted rim).
	for x in img.get_width():
		for y in range(int(cy + 6), int(cy + ry + 2)):
			var p := img.get_pixel(x, y)
			if p.a < 0.2:
				continue
			var t := clampf((float(y) - (cy + 6.0)) / 10.0, 0.0, 1.0)
			img.set_pixel(x, y, p.lerp(Color(0.70, 0.40, 0.16), t * 0.45))
	## Sesame seeds — small soft ovals, not sparkles.
	var seeds := [
		Vector2(cx - 22, cy - 10), Vector2(cx - 10, cy - 16), Vector2(cx + 2, cy - 18),
		Vector2(cx + 14, cy - 14), Vector2(cx + 26, cy - 8), Vector2(cx - 16, cy - 2),
		Vector2(cx - 2, cy - 4), Vector2(cx + 12, cy - 2), Vector2(cx + 22, cy + 2),
		Vector2(cx - 8, cy + 4), Vector2(cx + 6, cy + 6), Vector2(cx + 18, cy - 10),
	]
	for s in seeds:
		_paint_sesame(img, int(s.x), int(s.y))


static func _paint_bottom_bun(img: Image, cx: float, cy: float) -> void:
	var rx := 66.0
	var ry := 17.0
	## Soft shadow.
	_fill_ellipse(img, cx, cy + 9.0, rx + 4.0, ry * 0.75, Color(0.12, 0.05, 0.01, 0.35), Color(0.12, 0.05, 0.01, 0.0))
	## Heel body — warm golden (reads clearly under a dark patty).
	_fill_ellipse(img, cx, cy, rx, ry, Color(0.98, 0.78, 0.42), Color(0.78, 0.48, 0.18))
	## Bright cut-face crumb on top — high contrast vs brown meat.
	_fill_ellipse(img, cx, cy - 5.0, rx * 0.88, ry * 0.58, Color(1.0, 0.94, 0.78), Color(0.98, 0.82, 0.52))
	## Toasted rim around the cut face.
	for x in img.get_width():
		for y in img.get_height():
			var nx := (float(x) - cx) / (rx * 0.92)
			var ny := (float(y) - (cy - 1.5)) / (ry * 0.9)
			var d := nx * nx + ny * ny
			if d < 0.7 or d > 1.05:
				continue
			var p := img.get_pixel(x, y)
			if p.a < 0.2:
				continue
			img.set_pixel(x, y, p.lerp(Color(0.82, 0.52, 0.2), 0.4))
	## Toasted underside strip.
	for x in range(int(cx - rx + 4), int(cx + rx - 4)):
		for y in range(int(cy + 5), int(cy + ry + 2)):
			var p := img.get_pixel(x, y)
			if p.a < 0.2:
				continue
			var t := clampf((float(y) - (cy + 5.0)) / 8.0, 0.0, 1.0)
			img.set_pixel(x, y, p.lerp(Color(0.55, 0.3, 0.1), 0.35 + t * 0.45))


static func _fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col_center: Color, col_edge: Color) -> void:
	## Soft shaded ellipse — bright toward center/top, darker at rim (no hollow look).
	for y in img.get_height():
		for x in img.get_width():
			var nx := (float(x) - cx) / rx
			var ny := (float(y) - cy) / ry
			var d := nx * nx + ny * ny
			if d > 1.0:
				continue
			var edge := sqrt(d)
			var col := col_center.lerp(col_edge, edge * edge)
			## Soft top-left light so volume reads.
			var lit := clampf(0.12 - nx * 0.06 - ny * 0.1, -0.08, 0.14)
			col = col.lightened(lit) if lit > 0.0 else col.darkened(-lit)
			var existing := img.get_pixel(x, y)
			if existing.a > 0.05:
				col = existing.lerp(col, col.a)
			img.set_pixel(x, y, col)


static func _paint_sesame(img: Image, cx: int, cy: int) -> void:
	## Tiny soft oval seed (cream with a faint brown rim).
	var cream := Color(0.96, 0.90, 0.72)
	var rim := Color(0.78, 0.62, 0.38, 0.9)
	for oy in range(-1, 2):
		for ox in range(-2, 3):
			var px := cx + ox
			var py := cy + oy
			if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height():
				continue
			var nx := float(ox) / 2.2
			var ny := float(oy) / 1.2
			if nx * nx + ny * ny > 1.0:
				continue
			var existing := img.get_pixel(px, py)
			if existing.a < 0.2:
				continue
			var col := cream if abs(ox) + abs(oy) <= 1 else rim
			img.set_pixel(px, py, col)


static func _make_patty(col: Color) -> ImageTexture:
	## Force a meat-dark base so it never reads as bun crumb.
	var meat := col.darkened(0.12)
	if meat.get_luminance() > 0.38:
		meat = meat.darkened(0.22)
	var img := _img(118, 40)
	## Soft shadow under the patty (separates it from the bun below).
	_set_circle(img, 59, 24, 54, 12, Color(0.02, 0.01, 0.0, 0.45))
	## Main patty — slightly narrower than bottom bun so golden rim peeks out.
	_set_circle(img, 59, 18, 48, 12, meat)
	## Darker edge crust
	for y in 40:
		for x in 118:
			var nx := (x - 59.0) / 48.0
			var ny := (y - 18.0) / 12.0
			var d := nx * nx + ny * ny
			if d > 0.65 and d <= 1.0:
				var p := img.get_pixel(x, y)
				if p.a > 0.2:
					img.set_pixel(x, y, p.darkened(0.32))
	## Grill marks
	for gi in 4:
		var gx := 28 + gi * 16
		for y in range(9, 28):
			for x in range(gx - 1, gx + 2):
				if x < 0 or x >= 118:
					continue
				var p := img.get_pixel(x, y)
				if p.a > 0.25:
					img.set_pixel(x, y, p.darkened(0.5 if x == gx else 0.32))
	## Speckle fat bits
	for i in 12:
		var sx := 24 + (i * 17) % 70
		var sy := 11 + (i * 5) % 14
		var p := img.get_pixel(sx, sy)
		if p.a > 0.3:
			img.set_pixel(sx, sy, p.lightened(0.14))
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


static func _make_toon_wood() -> ImageTexture:
	## Chunky toon plank — warm boards with dark grain lines, no red plastic look.
	var w := 96
	var h := 96
	var img := _img(w, h)
	var base := Color(0.62, 0.42, 0.24)
	var light := Color(0.78, 0.58, 0.36)
	var dark := Color(0.42, 0.26, 0.14)
	var grain := Color(0.28, 0.16, 0.08, 0.55)
	for y in h:
		for x in w:
			## Vertical board stripes
			var board := int(x / 24)
			var local_x := x - board * 24
			var shade := 0.0
			if local_x < 2 or local_x > 21:
				shade = -0.12 ## seam
			elif local_x < 6:
				shade = 0.08
			## Soft horizontal grain waves
			var wave := sin(float(y) * 0.35 + float(board) * 1.7) * 0.06
			var n := sin(float(x) * 0.9 + float(y) * 0.15) * 0.04
			var t := clampf(0.45 + shade + wave + n, 0.0, 1.0)
			var col := dark.lerp(light, t)
			## Occasional dark grain fleck
			if int(x * 17 + y * 31) % 47 == 0:
				col = col.lerp(Color(grain.r, grain.g, grain.b), 0.55)
			## Top-left toon rim light
			if x < 4 or y < 4:
				col = col.lightened(0.12)
			if x > w - 5 or y > h - 5:
				col = col.darkened(0.1)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	## A few bold grain strokes
	for stroke in 6:
		var sx := 8 + stroke * 14
		for y in range(6, h - 6):
			var ox := int(sin(float(y) * 0.22 + float(stroke)) * 2.0)
			var px := clampi(sx + ox, 0, w - 1)
			var prev := img.get_pixel(px, y)
			img.set_pixel(px, y, prev.lerp(Color(0.22, 0.12, 0.06), 0.45))
			if px + 1 < w:
				var prev2 := img.get_pixel(px + 1, y)
				img.set_pixel(px + 1, y, prev2.lerp(Color(0.22, 0.12, 0.06), 0.25))
	return ImageTexture.create_from_image(img)


static func _make_toon_wood_inset() -> ImageTexture:
	## Lighter cutting-board center for the burger stack well.
	var w := 64
	var h := 64
	var img := _img(w, h)
	for y in h:
		for x in w:
			var t := 0.55 + sin(float(x) * 0.4) * 0.05 + sin(float(y) * 0.25) * 0.04
			var col := Color(0.55, 0.38, 0.22).lerp(Color(0.82, 0.64, 0.42), clampf(t, 0.0, 1.0))
			if int(y) % 8 == 0:
				col = col.darkened(0.08)
			if x < 3 or y < 3:
				col = col.lightened(0.1)
			if x > w - 4 or y > h - 4:
				col = col.darkened(0.12)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _make_warmer_tray() -> ImageTexture:
	## Dark steel holding tray for cooked meat.
	var w := 220
	var h := 140
	var img := _img(w, h)
	var cx := w * 0.5
	var cy := h * 0.55
	## Soft shadow under tray.
	_fill_ellipse(img, cx, cy + 10.0, 98.0, 42.0, Color(0.02, 0.02, 0.03, 0.45), Color(0.02, 0.02, 0.03, 0.0))
	## Outer tray rim.
	_fill_ellipse(img, cx, cy, 96.0, 40.0, Color(0.38, 0.42, 0.48), Color(0.18, 0.2, 0.24))
	## Inner well.
	_fill_ellipse(img, cx, cy - 2.0, 82.0, 30.0, Color(0.22, 0.25, 0.3), Color(0.12, 0.14, 0.17))
	## Specular streak.
	_fill_ellipse(img, cx - 18.0, cy - 14.0, 28.0, 8.0, Color(0.75, 0.8, 0.88, 0.35), Color(0.75, 0.8, 0.88, 0.0))
	return ImageTexture.create_from_image(img)
