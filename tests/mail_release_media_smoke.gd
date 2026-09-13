extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(20).timeout.connect(func(): quit(1))
	var screen=load("res://scripts/cinematic_video.gd").new()
	screen.video_path="res://assets/cinematics/burger_pals_intro.ogv"
	root.add_child(screen);screen.size=Vector2(1280,720);screen.play()
	assert(screen.video.stream!=null and screen.video.is_playing(),"Packaged opening must load and play")
	await create_timer(1.0).timeout
	assert(screen.video.stream_position>0.3,"The new opening must decode and advance")
	var lettering=load("res://scripts/loading_screen_lettering.gd").new();root.add_child(lettering);lettering.size=Vector2(1280,720);lettering._layout()
	var baseline:Vector2=lettering.letters[0].get_meta("baseline")
	assert(is_equal_approx(baseline.y,300.0),"Headline must move 30 pixels down")
	var width:float=lettering.FONT.get_string_size(lettering.TITLE,HORIZONTAL_ALIGNMENT_LEFT,-1,26).x
	assert(is_equal_approx(baseline.x,(1280.0-width)/2.0+15.0),"Headline must move 15 pixels left")
	screen.stop()
	print("MAIL_RELEASE_MEDIA_OK")
	quit()
