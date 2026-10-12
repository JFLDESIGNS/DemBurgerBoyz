extends SceneTree
class Walker extends Node3D:
 var _wawa_click_area := Area3D.new()
 func _init() -> void: add_child(_wawa_click_area)
class ShadowCat extends Node3D:
 func window_shadow_size() -> Vector2:
  return Vector2(1.2,1.0) if visible else Vector2.ZERO
func _initialize() -> void: call_deferred("run")
func no_shadows(node: Node) -> void:
 if node is MeshInstance3D: assert(node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
 for child in node.get_children(): no_shadows(child)
func run() -> void:
 create_timer(25).timeout.connect(func(): quit(1))
 var game = load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/main_ticket_harness.gd"))
 root.add_child(game); current_scene = game
 game.street_matte = MeshInstance3D.new()
 game.street_matte.position = Vector3(0,3.5,11.5)
 game.street_matte.rotation.y = PI
 game.world.add_child(game.street_matte)
 game._sync_mill_market_layers(game.STREET_BG_MILL1_PATH)
 var street = game._mill_market_layer()
 no_shadows(street)
 var walker := Walker.new()
 game.world.add_child(walker)
 game.bg_people.append(walker)
 game.bg_people_active.append(true)
 game.bg_people_wait.append(0.0)
 game.bg_people_dir.append(1.0)
 game.bg_people_is_run.append(false)
 game.bg_people_is_pair.append(false)
 assert(street.try_building_departure(0,true))
 assert(street.is_building_walker(walker))
 for i in range(140):
  street.tick_building_traffic(1.0/60.0)
  street.door_animations.advance(1.0/60.0)
 assert(game.bg_people_active[0] and walker.visible)
 assert(not street.is_building_walker(walker))
 assert(absf(walker.global_position.z-game._bg_people_z())<.01)
 street._traffic_wait=0.0
 var foot: Vector3=street._door_foot("old_poodle",-.28)
 walker.global_position=Vector3(foot.x,game._bg_people_y(),game._bg_people_z())
 street.tick_building_traffic(.01)
 assert(street.is_building_walker(walker))
 var original_snapshot: Dictionary = street.traffic_snapshot()
 street.apply_traffic_snapshot(original_snapshot)
 for door in street._hinges: assert(street._hinges[door].quaternion.is_equal_approx(original_snapshot.angles[door]))
 for i in range(140): street.tick_building_traffic(1.0/60.0)
 assert(not walker.visible and not game.bg_people_active[0])
 assert(walker._wawa_click_area.collision_layer==0)
 assert(not street.is_building_walker(walker))
 game.bg_people_active[0]=true;walker.visible=true
 assert(street.try_building_departure(0,true))
 street.cancel_building_traffic()
 assert(not street.is_building_walker(walker) and street._trip.is_empty())
 var capsule := MeshInstance3D.new()
 capsule.mesh = CapsuleMesh.new()
 walker.add_child(capsule)
 game.bg_people_active[0] = true
 walker.visible = true
 game.camera.current = true
 var height: float = 1.7 * walker.scale.y
 walker.global_position = street.to_global(Vector3(-3.4,-2.5,0.028)) - Vector3.UP * height * .7
 street._update_walker_reflections()
 street._update_canopy_walker_shade()
 assert(street._walker_reflections.get_shader_parameter("person_count") == 1)
 assert(capsule.material_overlay != null)
 assert(capsule.material_overlay.get_shader_parameter("shade_amount") > .65)
 assert(capsule.material_overlay.get_shader_parameter("upper_body_start") < capsule.material_overlay.get_shader_parameter("upper_body_end"))
 walker.visible = false
 street._update_walker_reflections()
 street._update_canopy_walker_shade()
 assert(street._walker_reflections.get_shader_parameter("person_count") == 0)
 assert(capsule.material_overlay.get_shader_parameter("shade_amount") == 0.0)
 walker.visible = true
 street._update_walker_reflections()
 street._update_canopy_walker_shade()
 for i in 5: await process_frame
 var first_rect: Vector4 = street._walker_reflections.get_shader_parameter("people")[0]
 walker.rotation.y += PI
 street._update_walker_reflections()
 var reversed_rect: Vector4 = street._walker_reflections.get_shader_parameter("people")[0]
 assert(first_rect.is_equal_approx(reversed_rect),"Silhouette offset must not flip with facing")
 var market_foot: Vector3 = street._door_foot("market",-.28)
 var base_scale: Vector3 = walker.scale
 street._begin_trip(0,"market",true,market_foot,Vector3(market_foot.x,game._bg_people_y(),game._bg_people_z()))
 assert(walker.scale.is_equal_approx(base_scale*.84))
 assert(bool(walker.get_meta("market_shopping_bag",false)))
 street._update_market_bags()
 var shopping_bag := walker.get_node_or_null("MarketShoppingBag")
 assert(shopping_bag != null and shopping_bag.visible)
 var sound_serial: int = street._shop_sound_serial
 street.apply_traffic_snapshot(street.traffic_snapshot())
 assert(street._shop_sound_serial == sound_serial,"The same snapshot must not retrigger sound")
 for i in range(140): street.tick_building_traffic(1.0/60.0)
 assert(not street.is_building_walker(walker),"A full doorway trip finishes within 2.34 seconds")
 assert(walker.scale.is_equal_approx(base_scale),"Exiting restores normal size")
 street.cancel_building_traffic()
 street._update_market_bags()
 assert(not shopping_bag.visible)
 var cat := ShadowCat.new()
 game.world.add_child(cat)
 game.window_cat = cat
 cat.global_position = walker.global_position
 street._update_walker_reflections()
 var cat_rect: Vector4 = street._walker_reflections.get_shader_parameter("cat_blob")
 assert(cat_rect.z > 0.0 and cat_rect.w > 0.0,"Walking cat must have a window shadow")
 cat.rotation.y = PI
 street._update_walker_reflections()
 assert(cat_rect.is_equal_approx(street._walker_reflections.get_shader_parameter("cat_blob")))
 cat.visible = false
 street._update_walker_reflections()
 assert(street._walker_reflections.get_shader_parameter("cat_blob") == Vector4.ZERO,"Hidden cat must clear its shadow")
 print("MILL_BUILDING_TRAFFIC_OK: entry, exit, cancellation, replicated angles, no background shadows")
 await process_frame
 quit()
