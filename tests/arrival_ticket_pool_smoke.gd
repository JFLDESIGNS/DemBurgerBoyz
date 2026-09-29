extends SceneTree
var animation_changes = 0
func _initialize(): call_deferred("run")
func run() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	var g = load("res://scenes/main.tscn").instantiate()
	g.set_script(load("res://tests/main_ticket_harness.gd")); root.add_child(g); current_scene = g
	g.stations = [{"items":[],"patties":[]}]
	g._gameplay_load_in_progress = true
	await g._prewarm_order_ticket_render()
	g._gameplay_load_in_progress = false
	assert(g.tickets.is_empty() and g.selected_customer == null and g._ticket_motion_pool.size() == 1)
	var renderer = g._ticket_motion_pool[0]
	var scene_id = renderer._model.get_instance_id()
	var library = renderer._player.get_animation_library(renderer._player.get_animation_library_list()[0])
	for cycle in 6:
		var c = load("res://scripts/mobile_ticket_owner.gd").new(); g.add_child(c)
		c.order.assign(["bun_bottom","patty","cheese","bun_top"] if cycle % 2 else ["bun_bottom","patty","lettuce","tomato","pickle","bun_top"])
		g._create_ticket(c); g.selected_customer = c; g._highlight_tickets()
		var motion = g.tickets[c].get_meta("ticket_motion")
		assert(motion == renderer and motion._model.get_instance_id() == scene_id)
		assert(motion._note.get_parent() == motion._source and motion.active)
		assert(motion._player.get_animation_library(motion._player.get_animation_library_list()[0]) == library)
		g._remove_ticket(c); g.selected_customer = null; c.queue_free()
		await process_frame
		assert(not renderer.active and renderer._view.render_target_update_mode == SubViewport.UPDATE_DISABLED)
		assert(renderer._source.get_child_count() == 0 and g._ticket_motion_pool.size() == 1)
	var customer = load("res://scripts/customer.gd").new()
	customer.setup(["bun_bottom","patty","bun_top"] as Array[String],Color.WHITE,45,0,0,0,-1,{},true)
	g.customers_root.add_child(customer); customer.set_process(false)
	var tap = customer._anim_player.get_animation("kenney_button/Button")
	tap.changed.connect(func(): animation_changes += 1)
	for i in 3:
		customer._cancel_order_announce(); customer._play_anim("idle"); customer._start_order_button()
		assert(customer._anim_player.current_animation == "kenney_button/Button")
		assert(tap.loop_mode == Animation.LOOP_NONE)
	assert(animation_changes == 0, "Starting an order must not invalidate shared animation caches")
	g.queue_free(); await process_frame
	print("ARRIVAL_TICKET_POOL_OK: prewarm, render reuse, rebinding, cleanup, immutable gesture animation")
	quit()
