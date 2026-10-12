extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();game.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(game)
 var paths: Array[String]=[]
 for path in game._gameplay_preload_paths():
  if path.get_extension() not in ["gdshader","png","jpg","ogg","wav"]:continue
  var file=FileAccess.open(path,FileAccess.READ)
  if file!=null and file.get_length()<=524288:paths.append(path)
 var out=FileAccess.open("res://scripts/menu_preload_manifest.gd",FileAccess.WRITE)
 out.store_string("extends RefCounted\n# Small resource sources (at most 512 KiB each); valid in exported builds too.\nconst PATHS: Array[String] = "+JSON.stringify(paths,"\t")+"\n")
 print("MENU_MANIFEST ",paths.size());game.queue_free();await process_frame;quit()
