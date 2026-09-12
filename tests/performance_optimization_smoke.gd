extends SceneTree
const PattyScript = preload("res://scripts/patty.gd")
var failures: Array[String] = []
func _init() -> void:
	call_deferred("_run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
func _run() -> void:
	var game_script = load("res://scripts/game.gd")
	expect(game_script != null and game_script.can_instantiate(), "Game script must compile")
	var patty = load("res://scripts/patty.gd").new()
	patty._cook_img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	patty._cook_tex = ImageTexture.create_from_image(patty._cook_img)
	patty._sear_seed = 12345
	patty.first_side_time = 16.0
	patty.flipped_once = true
	patty.cook_time = 10.0
	patty._update_cook_gradient()
	var pixels: PackedByteArray = patty._cook_img.get_data()
	expect(pixels == reference_cook_image(patty).get_data(), "Cached sear must match original pixels exactly")
	for state in [[0.0, false, 1], [17.5, true, 982], [26.0, true, 52412]]:
		patty.cook_time = state[0]
		patty.flipped_once = state[1]
		patty._sear_seed = state[2]
		patty._update_cook_gradient()
		expect(patty._cook_img.get_data() == reference_cook_image(patty).get_data(), "Cooking/seed changes must preserve the original image")
	patty.cook_time = 10.0
	patty.flipped_once = true
	patty._sear_seed = 12345
	patty._update_cook_gradient()
	patty._update_cook_gradient()
	expect(pixels == patty._cook_img.get_data(), "Unchanged state must preserve pixels")
	patty.cook_time = 20.0
	patty._update_cook_gradient()
	expect(pixels != patty._cook_img.get_data(), "Cooking must still change the image")
	var samples: Array[float] = []
	for i in 200:
		patty.cook_time = 10.0 + float(i) * 0.001
		var began := Time.get_ticks_usec()
		patty._update_cook_gradient()
		samples.append(float(Time.get_ticks_usec() - began) / 1000.0)
	samples.sort()
	print("OPTIMIZED_PATTY median_ms=", samples[100], " p95_ms=", samples[189])
	patty.free()
	var host = load("res://scripts/social_feed_replication.gd").new()
	var guest = load("res://scripts/social_feed_replication.gd").new()
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var posts: Array = [{"id": 1, "text": "first", "pic": ImageTexture.create_from_image(image)}]
	var delta: Dictionary = host.build_delta(posts)
	expect(delta["upserts"].size() == 1, "New post must replicate")
	var received: Array = guest.apply_delta([], delta["upserts"], delta["removed"])
	var texture: Texture2D = received[0]["pic"]
	expect(host.build_delta(posts)["upserts"].is_empty(), "Unchanged feed must produce no packets")
	posts[0]["reply"] = "Thanks!"
	delta = host.build_delta(posts)
	received = guest.apply_delta(received, delta["upserts"], [])
	expect(received[0]["pic"] == texture, "Reply must reuse decoded photo")
	expect(received[0]["reply"] == "Thanks!", "Reply must update")
	posts.push_front({"id": 2, "text": "second"})
	delta = host.build_delta(posts)
	expect(delta["upserts"].size() == 1, "New post must not resend history")
	received = guest.apply_delta(received, delta["upserts"], [])
	expect(received[0]["id"] == 2, "Newest post must be first")
	posts.pop_back()
	delta = host.build_delta(posts)
	received = guest.apply_delta(received, delta["upserts"], delta["removed"])
	expect(received.size() == 1 and guest.decoded.is_empty(), "Removal must evict the image")
	if game_script != null and game_script.can_instantiate():
		var game = game_script.new()
		game._oil_fire_age = 1.0
		var frame: Texture2D = game._tick_oil_burn_noise_texture(0.06)
		expect(frame != null and frame == game._tick_oil_burn_noise_texture(0.06), "Oil frames must be shared")
		game._oil_fire_age = 3.0
		var later_frame: Texture2D = game._tick_oil_burn_noise_texture(0.06)
		expect(frame.get_image().get_data() != later_frame.get_image().get_data(), "Baked oil must animate over the fire lifetime")
		game.fire_root = Node3D.new()
		game.add_child(game.fire_root)
		game._oil_fire_trail_mode = true
		var oil := MeshInstance3D.new()
		game.add_child(oil)
		game.oil_slicks.append({"mesh": oil, "radius": 0.05, "on_fire": true})
		game._sync_fire_to_oil_area()
		var fire_texture: ImageTexture = game._fire_emit_tex
		var fire_pixels := fire_texture.get_image().get_data()
		game._sync_fire_to_oil_area()
		expect(game._fire_emit_tex == fire_texture and fire_pixels == fire_texture.get_image().get_data(), "Unchanged oil must reuse emission geometry")
		var old_anchors: Array = game._fire_anchor_state.duplicate(true)
		var old_path: PackedVector3Array = game._build_oil_fire_path_points()
		oil.position.x += 0.2
		game._sync_fire_to_oil_area()
		# Dummy rendering does not expose ImageTexture.update through get_image().
		expect(old_anchors != game._fire_anchor_state and old_path != game._build_oil_fire_path_points(), "Moved oil must invalidate cached anchors and change emission geometry")
		expect(game._fire_emit_tex == fire_texture, "Same-size emission changes must reuse the GPU allocation")
		var remote = PattyScript.new()
		game.add_child(remote)
		remote.is_held = true
		game.mp_enabled = true
		game._mp_remote_patty_targets[7] = {"patty": remote, "position": Vector3(0.2, 0, 0), "rotation": Quaternion.IDENTITY, "time": Time.get_ticks_msec()}
		game._update_remote_patty_interpolation(1.0 / 60.0)
		expect(remote.position.x > 0.0 and remote.position.x < 0.2, "Remote held poses must interpolate")
		game.dragging_patty = remote
		var local_position: Vector3 = remote.position
		game._update_remote_patty_interpolation(1.0 / 60.0)
		expect(remote.position == local_position and game._mp_remote_patty_targets.is_empty(), "Local control must cancel remote interpolation")
		game.free()
	for key in ["hiss", "spray", "shake", "soda", "ice", "softserve"]:
		var bed := load("res://sounds/cached_beds/%s.res" % key) as AudioStreamWAV
		expect(bed != null and bed.loop_mode == AudioStreamWAV.LOOP_FORWARD and bed.loop_end > bed.loop_begin and bed.data.size() > 400000, "Cached bed must contain valid looping audio: " + key)
	for failure in failures:
		push_error(failure)
	print("PERFORMANCE_OPTIMIZATION_SMOKE_OK" if failures.is_empty() else "PERFORMANCE_OPTIMIZATION_SMOKE_FAILED")
	quit(0 if failures.is_empty() else 1)


func reference_cook_image(patty: PattyScript) -> Image:
	var image := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	## Cylinder UV: v=0 at top, v=1 at bottom. Heat climbs from the grill.
	for y in patty.COOK_TEX_H:
		var v := float(y) / float(patty.COOK_TEX_H - 1) ## 0 top → 1 bottom
		var c: Color
		if patty.flipped_once:
			## Flip turns the patty over: former grill side is now the top.
			## Mild cooked bias — browned, not charcoal.
			var cooked_boost := 2.0
			var first_t := patty.first_side_time + cooked_boost - v * patty.HEAT_LAG
			var second_t := patty.cook_time - (1.0 - v) * patty.HEAT_LAG
			c = patty.color_at_cook_time(maxf(first_t, second_t))
			## Soft sear wash on the flipped face.
			if v < 0.35:
				var face_t := patty.first_side_time + cooked_boost + 1.0
				var top_sear := patty.color_at_cook_time(face_t).darkened(0.08)
				var blend := clampf(1.0 - v / 0.35, 0.0, 1.0)
				c = c.lerp(top_sear, blend * 0.55)
				c = c.darkened(0.04 * blend)
		else:
			## Bottom (grill) cooks first; top stays raw longer.
			var local_t := patty.cook_time - (1.0 - v) * patty.HEAT_LAG
			c = patty.color_at_cook_time(local_t)
			## No vertical frost haze in this texture — cylinder top-cap UVs map V
			## across the diameter and caused a left/right haze split.
			## Top haze is a separate even disc; sides clear via the ice shell.
		var grill_side := v if not patty.flipped_once else (1.0 - v)
		c = c.darkened(grill_side * 0.1)
		for x in patty.COOK_TEX_W:
			var px := c
			## After flip: light sear mottling — browned flecks, not burnt crust.
			if patty.flipped_once and v < 0.45:
				var u := float(x) / float(patty.COOK_TEX_W)
				var n := patty._sear_noise(u * 6.0 + float(patty._sear_seed % 17), v * 7.5 + float((patty._sear_seed / 17) % 13))
				n = n * 0.55 + patty._sear_noise(u * 14.0 + 1.7, v * 12.0) * 0.3
				n += patty._sear_noise(u * 28.0, v * 22.0) * 0.15
				var top_w := clampf(1.0 - v / 0.45, 0.0, 1.0)
				var cook_w := clampf((patty.first_side_time - 8.0) / 14.0, 0.4, 1.0)
				if n > 0.58:
					var char_amt := ((n - 0.58) / 0.42) * top_w * cook_w
					px = px.darkened(clampf(0.12 + char_amt * 0.28, 0.0, 0.38))
				elif n > 0.45:
					px = px.darkened(0.08 * top_w * cook_w)
			image.set_pixel(x, y, px)
	return image


