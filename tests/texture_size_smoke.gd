extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(45).timeout.connect(func():quit(1))
 var args=OS.get_cmdline_user_args()
 var rows=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 for row in rows:
  var texture=load("res://"+str(row.source)) as Texture2D
  assert(texture!=null,"Missing optimized texture: "+str(row.source))
  assert(maxi(texture.get_width(),texture.get_height())<=int(row.limit),"Import size limit not applied: "+str(row.source))
 for path in ["res://scenes/main.tscn","res://scenes/boot_intro.tscn"]:
  assert(load(path)!=null,"Missing packed scene: "+path)
 print("TEXTURE_SIZE_SMOKE_OK ",rows.size()," textures and main scenes")
 quit()
