import bpy, bmesh, math
from pathlib import Path
R=Path(r'C:/Users/joe/Desktop/burgergame');O=R/'assets/character_animation/grisaldi';O.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(R/'assets/shirts/glb/02_Sunshine_Bowling.glb'))
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
print('SHIRT_DIMENSIONS',list(mesh.dimensions),list(mesh.scale))
red=bpy.data.materials.new('Grisaldi tomato red checks');red.diffuse_color=(.65,.018,.027,1)
black=bpy.data.materials.new('Grisaldi charcoal checks');black.diffuse_color=(.018,.023,.019,1)
for m in [red,black]:
 m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=m.diffuse_color;m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.86
mesh.data.materials.clear();mesh.data.materials.append(red);mesh.data.materials.append(black)
bm=bmesh.new();bm.from_mesh(mesh.data)
bmesh.ops.subdivide_edges(bm,edges=list(bm.edges),cuts=3,use_grid_fill=True)
coords=[v.co for v in bm.verts];width=max(v.x for v in coords)-min(v.x for v in coords)
cell=width/9
for face in bm.faces:
 c=face.calc_center_median();face.material_index=(math.floor(c.x/cell)+math.floor(c.z/cell))%2
bm.to_mesh(mesh.data);bm.free()
mesh.name='Grisaldi_Check_Shirt'
bpy.ops.wm.save_as_mainfile(filepath=str(O/'Grisaldi_Shirt.blend'))
bpy.ops.export_scene.gltf(filepath=str(R/'assets/shirts/glb/16_Grisaldi_Check.glb'),export_format='GLB',export_animations=False)
print('GRISALDI_SHIRT_READY')
