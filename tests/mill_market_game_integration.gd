extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 create_timer(30).timeout.connect(func(): quit(1))
 var game = load("res://scenes/main.tscn").instantiate()
 game.set_script(load("res://tests/main_ticket_harness.gd"))
 root.add_child(game)
 current_scene = game
 game.street_matte = MeshInstance3D.new()
 game.street_matte.name = "StreetMatte"
 game.street_matte.position = Vector3(0,3.5,11.5)
 game.street_matte.rotation.y = PI
 game.street_matte.material_override = StandardMaterial3D.new()
 game.world.add_child(game.street_matte)
 game.camera.current = true
 game._sync_mill_market_layers(game.STREET_BG_MILL1_PATH)
 await process_frame
 await process_frame
 var street = game.street_matte.get_node("MillMarketLayers")
 assert(game.street_matte.mesh == null)
 for region in ["upper_windows", "street_windows", "doors", "canopy"]:
  assert(game.get_street_effect_mask(region) != null)
 game.play_street_door_animation("both_open")
 street.door_animations.advance(.85)
 for key in street._hinges:
  assert(street._hinges[key].quaternion.is_equal_approx(Quaternion(street._axes[key], deg_to_rad(110))))
 street._update_canopy_depth()
 var canopy: Node3D = street.get_node("CanopyForeground")
 assert(canopy.global_position.z < game._bg_people_z())
 var base_screen: Vector2 = game.camera.unproject_position(street.global_position)
 var canopy_screen: Vector2 = game.camera.unproject_position(canopy.global_position)
 assert(base_screen.distance_to(canopy_screen) < .1, "Canopy must stay aligned when moved ahead of walkers")
 game._sync_mill_market_layers(game.STREET_BG_MILL1_PATH)
 assert(game.street_matte.get_child_count() == 1)
 game._sync_mill_market_layers(game.STREET_BG_ORIGINAL_PATH)
 await process_frame
 await process_frame
 assert(game.street_matte.mesh is QuadMesh)
 assert(game.street_matte.get_node_or_null("MillMarketLayers") == null)
 assert(game.get_street_effect_mask("canopy") == null)
 game._sync_mill_market_layers(game.STREET_BG_MILL1_PATH)
 await process_frame
 await process_frame
 assert(game.get_street_effect_mask("canopy") != null)
 print("MILL_GAME_INTEGRATION_OK")
 await process_frame
 quit()
