extends SceneTree

class SalesGame extends Node:
	var order_history: Array = []
	var day := 1
	var playing := false

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game := SalesGame.new()
	root.add_child(game)
	var ui := Node.new()
	ui.name = "UI"
	game.add_child(ui)
	var holder := Control.new()
	holder.name = "Root"
	ui.add_child(holder)
	var parent := VBoxContainer.new()
	holder.add_child(parent)
	var app = load("res://scripts/order_insights.gd").new()
	game.add_child(app)
	app.setup(game, parent)
	var image := Image.create(160, 160, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	game.order_history = [{"number": 1, "day": 1, "sale": 10, "tip": 2, "cost": 3.0, "profit": 9.0, "photo": image.save_png_to_buffer()}]
	app.refresh()
	assert(app.ledger.get_child_count() == 0, "Hidden sales page must not construct cards")
	assert(app.photo_cache.is_empty(), "Hidden sales page must not decode photos")
	app.show_app("orders")
	var original: Texture2D = app.photo_cache[1].texture
	assert(app.ledger.get_child_count() == 3)
	game.order_history[0]["review"] = "Updated review"
	app.refresh()
	assert(app.photo_cache[1].texture == original, "Review changes must reuse decoded photo")
	image.fill(Color.BLUE)
	game.order_history[0]["photo"] = image.save_png_to_buffer()
	app.refresh()
	assert(app.photo_cache[1].texture != original, "Replacement photos must invalidate cache")
	assert(app.photo_cache[1].texture.get_image().get_pixel(80, 80).b > 0.99)
	app.show_app("home")
	game.order_history.clear()
	app.refresh()
	app.show_app("orders")
	assert(app.photo_cache.is_empty(), "Removed orders must release cached photos when the page opens")
	game.queue_free()
	await process_frame
	print("ORDER_INSIGHTS_CACHE_OK")
	quit()
