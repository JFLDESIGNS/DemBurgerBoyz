extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	for path in ["game", "customer", "customer_social", "boss_machine_showcase", "window_cat", "game_audio", "character_footsteps", "hotdog_challenge"]:
		var script = load("res://scripts/"+path+".gd")
		assert(script != null and script.can_instantiate(),path)
	print("SOCIAL_PARSE_OK")
	quit()
