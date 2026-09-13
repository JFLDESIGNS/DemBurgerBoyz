extends SceneTree
const Voice = preload("res://scripts/customer_voice.gd")
const Customer = preload("res://scripts/customer.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(90).timeout.connect(func(): push_error("VOICE_TEST_TIMEOUT");quit(1))
	for gender in ["male","female"]:
		for eating in [true,false]:
			var stream := Voice.stream(gender,eating)
			assert(stream != null and stream.get_length()>.2,"Voice recording missing")
	assert(Voice.resolve({"customer_voice":"female"})=="female")
	assert(Voice.resolve({"customer_voice":"male"})=="male")
	assert(Voice.resolve({"name":"Old Customer"})==Voice.resolve({"name":"Old Customer"}))
	var audio=load("res://scripts/game_audio.gd").new();root.add_child(audio)
	for gender in ["male","female"]:
		var customer:=Customer.new();customer._custom_character_preset={"customer_voice":gender}
		# Test the voice trigger without constructing a full animated customer.
		customer.set_script(null)
		root.add_child(customer)
		audio.play_customer_nom_nom(gender,customer)
		var player=customer.get_node("CustomerEatingVoice")
		assert(player.stream==Voice.stream(gender,true) and player.playing)
		customer.queue_free()
	audio.play_customer_wawa_click(.5,"female")
	assert(audio._female_customer_wawa.stream==Voice.stream("female",false))
	var creator=load("res://scenes/character_creator/character_creator.tscn").instantiate()
	root.add_child(creator)
	for i in 8: await process_frame
	assert(creator._studio.pages.has("Voice"),"Creator needs a Voice section")
	creator._studio.select_category("Voice")
	creator._studio.voice_select.item_selected.emit(1)
	assert(creator.character.customer_voice=="female","Female voice selection")
	var snapshot: Dictionary=creator._studio.capture(false)
	assert(snapshot.properties.customer_voice=="female","Voice survives saved creator state")
	creator.character.apply_saved_preset({"customer_voice":"male"})
	assert(creator.character.customer_voice=="male","Preset restores male voice")
	creator._studio.preview_customer_voice(true)
	assert(creator._studio.voice_preview.stream==Voice.stream("male",true))
	var old:=Customer.new();old._custom_character_preset={"name":"Old Customer"}
	assert(old.get_customer_voice() in ["male","female"],"Existing characters receive voices")
	old.free()
	print("CUSTOMER_VOICE_SMOKE_OK");quit()
