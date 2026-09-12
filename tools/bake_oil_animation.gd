extends SceneTree
## Rebuild the oil animation from the original procedural mask. No executable export.
var _baked_image: Image
var _oil_blob_tex: ImageTexture
var _oil_burn_tex: ImageTexture
var _oil_burn_noise: FastNoiseLite
var _oil_burn_tex_cool := 0.0
var _bake_time := 0.0
const OIL_BURN_TEX_INTERVAL := 0.055
func _init() -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 1.0 / OIL_BURN_TEX_INTERVAL)
	for i in 160:
		_bake_time = float(i) * OIL_BURN_TEX_INTERVAL
		_tick_oil_burn_noise_texture(OIL_BURN_TEX_INTERVAL)
		# Keep the CPU image: dummy rendering cannot read back texture updates.
		frames.add_frame("default", ImageTexture.create_from_image(_baked_image))
	DirAccess.make_dir_recursive_absolute("res://assets/effects")
	var err := ResourceSaver.save(frames, "res://assets/effects/oil_burn_frames.res", ResourceSaver.FLAG_COMPRESS)
	print("OIL_ANIMATION_BAKE frames=", frames.get_frame_count("default"), " error=", err)
	quit(0 if err == OK else 1)


func _get_oil_blob_texture() -> ImageTexture:
	## Chunky grease blotch — hard edges, not a soft feathered disc.
	if _oil_blob_tex != null:
		return _oil_blob_tex
	var w := 64
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	var mid := Vector2(w * 0.5, w * 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for y in w:
		for x in w:
			var n := (Vector2(x + 0.5, y + 0.5) - mid) / (w * 0.5)
			var r := n.length()
			var ang := atan2(n.y, n.x)
			## Irregular hard silhouette (lobed, not round soft).
			var edge := 0.72 + 0.18 * sin(ang * 3.0 + 0.6) + 0.12 * cos(ang * 7.0 - 1.1)
			edge += 0.06 * sin(ang * 11.0)
			var inside := r < edge
			## Chunk bites / holes punched near the rim.
			var bite := sin(float(x) * 0.55 + float(y) * 0.41) * cos(float(x + y) * 0.33)
			if inside and r > edge * 0.55 and bite > 0.55:
				inside = false
			if not inside:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				## Sharp falloff only in the outer 4% — chunky core stays solid.
				var rim := clampf((edge - r) / maxf(edge * 0.04, 0.01), 0.0, 1.0)
				var a := lerpf(0.85, 0.98, rim)
				var shade := lerpf(0.09, 0.18, r * r)
				img.set_pixel(x, y, Color(shade, shade * 0.7, shade * 0.32, a))
	_oil_blob_tex = ImageTexture.create_from_image(img)
	return _oil_blob_tex


func _ensure_oil_burn_noise() -> void:
	if _oil_burn_noise != null:
		return
	_oil_burn_noise = FastNoiseLite.new()
	_oil_burn_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_oil_burn_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_oil_burn_noise.fractal_octaves = 3
	_oil_burn_noise.frequency = 0.085
	_oil_burn_noise.fractal_gain = 0.5


func _tick_oil_burn_noise_texture(delta: float) -> ImageTexture:
	## Shared animated mask — noise punches holes through burning grease.
	_oil_burn_tex_cool -= delta
	if _oil_burn_tex != null and _oil_burn_tex_cool > 0.0:
		return _oil_burn_tex
	_oil_burn_tex_cool = OIL_BURN_TEX_INTERVAL
	_ensure_oil_burn_noise()
	var base_tex := _get_oil_blob_texture()
	var base := base_tex.get_image()
	if base == null:
		return _oil_burn_tex
	var w := base.get_width()
	var h := base.get_height()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var t := _bake_time
	## Drift the field so holes crawl / flicker across the puddle.
	_oil_burn_noise.offset = Vector3(t * 22.0, t * 15.5, t * 9.0)
	for y in h:
		for x in w:
			var c := base.get_pixel(x, y)
			if c.a <= 0.01:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var nv := _oil_burn_noise.get_noise_2d(float(x), float(y))
			## Second slower layer so holes open/close instead of just sliding.
			var nv2 := _oil_burn_noise.get_noise_2d(float(x) * 0.55 + 40.0, float(y) * 0.55 - t * 8.0)
			var n := nv * 0.65 + nv2 * 0.35
			## Below threshold → that patch of oil is “burned off” (transparent).
			var gate := smoothstep(-0.08, 0.22, n)
			if gate <= 0.02:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			## Hot ember tint on what remains.
			var hot := Color(0.55, 0.18, 0.04, c.a * gate)
			var cool := Color(c.r * 1.6, c.g * 0.9, c.b * 0.45, c.a * gate)
			img.set_pixel(x, y, cool.lerp(hot, clampf(n * 0.55 + 0.35, 0.0, 1.0)))
	_baked_image = img
	if _oil_burn_tex == null:
		_oil_burn_tex = ImageTexture.create_from_image(img)
	else:
		_oil_burn_tex.set_image(img)
	return _oil_burn_tex


