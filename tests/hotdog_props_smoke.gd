extends SceneTree
func _initialize(): call_deferred("run")
func run():
 create_timer(45).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/hotdog_challenge_fixture.gd"));root.add_child(g)
 g.playing=true;g._kitchen_ready=true;g.stations=[{"items":[],"patties":[]}]
 var boss=g._ensure_hotdog_challenge();boss.set_process(false)
 g.window_bunting_root=Node3D.new();g.add_child(g.window_bunting_root);g.window_bunting_root.position=Vector3(0,2.57,1.52)
 g.open_closed_sign=Node3D.new();g.add_child(g.open_closed_sign)
 for n in ["OpenFace","ClosedFace"]:
  var face=MeshInstance3D.new();face.name=n;face.material_override=ShaderMaterial.new();g.open_closed_sign.add_child(face)
 var bun=Node3D.new();g.add_child(bun);g.bun_pile_stacks.append(bun)
 g.tip_jar_root=Node3D.new();g.add_child(g.tip_jar_root)
 assert(boss.start());assert(not boss.decorations_hit,"Entrance rumble must not knock down bunting")
 boss.phase="idle_smash";boss.impact(.4)
 assert(boss.decorations_hit and g.window_bunting_root.get_meta("boss_fallen"))
 assert(not g.service_window_closed,"Sign reaction must not close gameplay")
 await create_timer(.17).timeout
 assert(bun.position.y>.1 and g.tip_jar_root.position.y>.09)
 await create_timer(.65).timeout
 assert(is_equal_approx(g.window_bunting_root.position.y,.035))
 assert(is_equal_approx(g.open_closed_sign.rotation_degrees.y,180.0))
 assert(bun.position.is_equal_approx(Vector3.ZERO) and g.tip_jar_root.position.is_equal_approx(Vector3.ZERO))
 var fallen=g.window_bunting_root.transform;boss.hit_decorations();assert(g.window_bunting_root.transform==fallen)
 g.street_car_active=true;g.street_car_wait=0;g._update_street_car(1)
 assert(not g.street_car_active and g.street_car_wait>=5)
 for outcome in ["sinking","defeat_sinking"]:
  boss.phase=outcome;boss.advance_phase()
  assert(not boss.decorations_hit)
  await create_timer(1).timeout
  assert(g.window_bunting_root.position.is_equal_approx(Vector3(0,2.57,1.52)))
  assert(is_zero_approx(g.open_closed_sign.rotation_degrees.y))
  if outcome=="sinking":boss.hit_decorations()
 print("HOTDOG_PROPS_OK: traffic paused; first hit drops bunting and flips sign; buns/jar jump and land; decorations restore after both outcomes")
 quit()
