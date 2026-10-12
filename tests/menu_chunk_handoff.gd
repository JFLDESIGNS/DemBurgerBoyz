extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();game.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(game)
 game._preload_small_menu_chunks()
 await create_timer(2.0).timeout
 assert(game._gameplay_resource_cache.size()>0)
 game._gameplay_load_in_progress=true
 await create_timer(.5).timeout
 assert(not game._menu_chunk_pending)
 var count=game._gameplay_resource_cache.size()
 await create_timer(.5).timeout
 assert(game._gameplay_resource_cache.size()==count)
 print("MENU_CHUNK_HANDOFF_OK ",count)
 quit()
