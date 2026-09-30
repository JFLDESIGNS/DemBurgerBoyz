extends SceneTree
func _initialize():call_deferred("run")
func run():
 var model=load("res://assets/characters/Model/characterMedium.fbx").instantiate();root.add_child(model)
 var player=AnimationPlayer.new();model.add_child(player)
 var lib=load("res://assets/characters/Animations/CourierGrab.res")
 player.add_animation_library("courier",lib);player.play("courier/Courier_Grab")
 for i in 100:await process_frame
 print("GRAB_RESOURCE_OK")
 model.queue_free();await process_frame;quit()
