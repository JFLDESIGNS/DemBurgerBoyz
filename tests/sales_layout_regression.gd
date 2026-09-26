extends SceneTree
func _initialize():call_deferred("run")
func run():
 create_timer(30).timeout.connect(func():quit(1))
 var g=load("res://scenes/main.tscn").instantiate();g.set_script(load("res://tests/delivery_network_fixture.gd"));root.add_child(g)
 g.get_node("UI").hide();g._setup_stations_data()
 g.stations[0].items.assign(["bun_bottom","patty","tomato","onion","pickle","bacon","bun_top"])
 var photo=g._render_review_burger_snapshot(0)
 assert(photo!=null);photo.get_image().save_png("res://build/sales_burger_checked.png")
 g.order_history=[{"number":1,"day":1,"items":"bun_bottom, patty, tomato, onion, pickle, bacon, bun_top","sale":12.0,"tip":2.0,"cost":5.75,"profit":8.25,"photo":photo.get_image().save_png_to_buffer(),"stats":{"accuracy":"100%","doneness":"PERFECT 93%","seasoning":"SEASONED","freshness":"FRESH 100%"},"review":"Cooked just right, with every topping I asked for.","stars":4.5}]
 var phone=VBoxContainer.new();root.add_child(phone);phone.position=Vector2(40,20);phone.size=Vector2(210,900)
 var app=load("res://scripts/order_insights.gd").new();g.add_child(app);app.setup(g,phone);app.show_app("orders")
 await create_timer(1).timeout
 assert(app.ledger.size.x<=210)
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/sales_layout_checked.png")
 print("SALES_LAYOUT_REGRESSION_OK");quit()
