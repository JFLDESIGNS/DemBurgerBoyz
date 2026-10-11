extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1280,720)
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/main_ticket_harness.gd"));root.add_child(g);current_scene=g
 g._build_gameplay_loading_screen();var overlay=g._gameplay_load_overlay;overlay.show();g._loading_video.hide();overlay.get_node("LoadingStill").show()
 overlay.get_node("KitchenLoadingProgress").set_process(false)
 for amount in [20,90]:
  var progress=overlay.get_node("KitchenLoadingProgress");progress.bar.value=amount;progress.caption.text="WARMING UP THE GRILL  %d%%" % amount
  overlay.get_node("LoadingFilmOverlay").material.set_shader_parameter("progress",float(amount)/100.0)
  overlay.get_node("LoadingFilmOverlay").material.set_shader_parameter("film_time",2.1)
  await create_timer(.4).timeout
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://output/loading_film_%d.png" % amount)
 print("LOADING_FILM_PREVIEW_OK");quit()
