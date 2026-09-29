extends SceneTree
const PattyScript=preload("res://scripts/patty.gd")
func _initialize(): call_deferred("run")
func run():
	var stage:=Node3D.new();root.add_child(stage)
	var camera:=Camera3D.new();stage.add_child(camera)
	camera.position=Vector3(0,1.7,2.5);camera.look_at(Vector3.ZERO)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.1;camera.current=true
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.22,.23,.25)
	stage.add_child(env)
	var after=load("res://scripts/patty.gd")
	for row in 2:
		for i in 5:
			var p=after.new()
			p.prepared_pool_images={"seed":12345}
			stage.add_child(p);p.set_process(false)
			p.reset_for_grill_spawn(i,i,Vector3((i-2)*.37,0,(row-.5)*.48),0,true,false)
			p.cook_time=[0,8,16,25,42][i];p.flipped_once=i>=2;p.first_side_time=16
			p.refresh_cook_visuals()
			if row==0:
				var material:=StandardMaterial3D.new()
				material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
				material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
				material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
				material.render_priority=p.PATTY_BODY_PRIORITY
				material.albedo_texture=ImageTexture.create_from_image(reference_cook_image(p))
				p._mesh.material_override=material
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/cooking_before_after.png")
	print("COOKING_RENDER_OK")
	quit()

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
