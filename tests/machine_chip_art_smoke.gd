extends SceneTree
func _init():
 var visual=Node3D.new()
 for fid in ["ice","cola"]:
  var pad=MeshInstance3D.new()
  pad.name="FlavorChip_"+fid
  pad.mesh=BoxMesh.new()
  visual.add_child(pad)
 preload("res://scripts/machine_badges.gd").soda(visual)
 for fid in ["ice","cola"]:
  var graphic=visual.get_node("FlavorChip_"+fid+"/FlavorGraphic_"+fid)
  assert(graphic.material_override.albedo_texture.resource_path=="res://assets/machine_decals/"+fid+"_flavor_chip.png")
 visual.free()
 print("ACTUAL_MACHINE_CHIP_ART_OK")
 quit()
