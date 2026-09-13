extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var game = load("res://scripts/game.gd").new()
 var names := ["gfx_settings.cfg","audio_settings.cfg","truck_location.cfg","level_dressing.cfg","doll_studio.cfg"]
 game._seed_first_run_configs()
 for name in names:
  var bundled := ConfigFile.new()
  var local := ConfigFile.new()
  assert(bundled.load("res://defaults/" + name) == OK)
  assert(local.load("user://" + name) == OK)
  for section in bundled.get_sections():
   for key in bundled.get_section_keys(section):
    assert(local.get_value(section,key) == bundled.get_value(section,key), "Default mismatch: " + name + "/" + section + "/" + key)
 var local := ConfigFile.new()
 local.load("user://audio_settings.cfg")
 local.set_value("audio","master",0.37)
 local.save("user://audio_settings.cfg")
 game._seed_first_run_configs()
 local.load("user://audio_settings.cfg")
 assert(is_equal_approx(local.get_value("audio","master"),0.37), "Relaunch overwrote user adjustment")
 local.set_value("release_profile","tuned_defaults_version",2)
 local.set_value("future","keep",true)
 local.save("user://audio_settings.cfg")
 game._seed_first_run_configs()
 local.load("user://audio_settings.cfg")
 var bundled := ConfigFile.new()
 bundled.load("res://defaults/audio_settings.cfg")
 assert(local.get_value("audio","master") == bundled.get_value("audio","master"))
 assert(local.get_value("future","keep"), "Migration removed unrelated setting")
 game.free()
 print("RELEASE_DEFAULTS_SMOKE_OK")
 quit()
