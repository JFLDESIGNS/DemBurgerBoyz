extends SceneTree
class Actor extends Node3D:
 var _anim_player: AnimationPlayer
 var is_street_pedestrian := false
class Game extends Node:
 var chef_points_hud: HBoxContainer
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var actor:=Actor.new();root.add_child(actor)
 var steps=load("res://scripts/character_footsteps.gd").new();actor.add_child(steps);steps.set_process(false)
 for i in 30:
  actor.position.x+=.04;steps._process(.04)
 assert(steps.step_count>=2,"Approaching steps must trigger without animation-phase dependence")
 var before:int=steps.step_count
 for i in 30:steps._process(.04)
 assert(steps.step_count==before,"Stationary people must stay silent")
 actor.position.x+=10;steps._process(.1);assert(steps.step_count==before,"Teleports must not create steps")
 actor.is_street_pedestrian=true
 for i in 30:
  actor.position.x+=.04;steps._process(.04)
 assert(steps.step_count>before and steps.audio.attenuation_model==AudioStreamPlayer3D.ATTENUATION_DISABLED)
 var game:=Game.new();root.add_child(game)
 var layer:=CanvasLayer.new();layer.name="UI";game.add_child(layer)
 var ui:=Control.new();ui.name="Root";layer.add_child(ui)
 game.chef_points_hud=HBoxContainer.new();ui.add_child(game.chef_points_hud);game.chef_points_hud.position=Vector2(600,20)
 var source:=Label.new();source.text="★★★★★";source.position=Vector2(100,200);ui.add_child(source)
 load("res://scripts/review_star_flight.gd").launch(game,source)
 await create_timer(.6).timeout
 assert(source.modulate.a==0.0)
 assert(ui.get_children().filter(func(n):return n is Label and n!=source).size()==5)
 await create_timer(2.2).timeout
 assert(ui.get_children().filter(func(n):return n is Label and n!=source).is_empty())
 print("FOOTSTEPS_AND_REVIEW_OK")
 actor.queue_free();game.queue_free();await process_frame;quit()
