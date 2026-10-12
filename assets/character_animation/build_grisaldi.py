import bpy, bmesh, math
from pathlib import Path
R=Path(r'C:/Users/joe/Desktop/burgergame');O=R/'assets/character_animation/grisaldi';O.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(R/'assets/shirts/glb/09_Ivory_Oxford.glb'))
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
print('SHIRT_DIMENSIONS',list(mesh.dimensions),list(mesh.scale))
red=bpy.data.materials.new('Grisaldi tomato red checks');red.diffuse_color=(.65,.018,.027,1)
black=bpy.data.materials.new('Grisaldi charcoal checks');black.diffuse_color=(.018,.023,.019,1)
for m in [red,black]:
 m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=m.diffuse_color;m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.86
mesh.data.materials.clear();mesh.data.materials.append(red);mesh.data.materials.append(black)
bm=bmesh.new();bm.from_mesh(mesh.data)
bmesh.ops.subdivide_edges(bm,edges=list(bm.edges),cuts=1,use_grid_fill=True)
coords=[v.co for v in bm.verts];width=max(v.x for v in coords)-min(v.x for v in coords)
cell=width/9
for face in bm.faces:
 c=face.calc_center_median();face.material_index=(math.floor(c.x/cell)+math.floor(c.z/cell))%2
bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.calc_center_median().z>2.44 and abs(f.calc_center_median().x)<.4],context='FACES')
bm.to_mesh(mesh.data);bm.free()
# Keep the collar a clean, solid red rather than carrying checks across its folds.
collar=bpy.data.materials.new('Grisaldi solid collar');collar.diffuse_color=(.55,.015,.024,1);collar.use_nodes=True;collar.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=collar.diffuse_color;mesh.data.materials.append(collar)
for face in mesh.data.polygons:
 if face.center.z>2.48:face.material_index=2
 face.use_smooth=True
# A short gold link necklace, weighted to Chest with the garment.
gold=bpy.data.materials.new('Grisaldi gold chain');gold.diffuse_color=(.82,.51,.08,1);gold.use_nodes=True
gold.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=gold.diffuse_color
gold.node_tree.nodes['Principled BSDF'].inputs['Metallic'].default_value=.72
parts=[mesh]
# Clean collar stand and two broad flat points, replacing the wrinkled original.
verts=[];faces=[]
for z in [2.43,2.51]:
 for i in range(32):
  a=i*math.tau/32;verts.append((.23*math.cos(a),.20*math.sin(a),z))
for i in range(32):faces.append((i,(i+1)%32,(i+1)%32+32,i+32))
for side in [-1,1]:
 j=len(verts);verts.extend([(side*.04,-.20,2.48),(side*.25,-.16,2.46),(side*.34,-.31,2.34),(side*.15,-.38,2.29)])
 faces.append(tuple(range(j,j+4)))
data=bpy.data.meshes.new('Clean pointed collar');data.from_pydata(verts,[],faces);data.materials.append(collar)
obj=bpy.data.objects.new('Grisaldi collar',data);bpy.context.collection.objects.link(obj)
obj.vertex_groups.new(name='Chest').add(list(range(len(verts))),1,'REPLACE')
parts.append(obj)
for i in range(15):
 angle=math.pi*i/14
 bpy.ops.mesh.primitive_torus_add(major_segments=10,minor_segments=5,major_radius=.039,minor_radius=.013,location=(.27*math.cos(angle),-.37-.055*math.sin(angle),2.42-.23*math.sin(angle)),rotation=(math.pi/2,0,0 if i%2==0 else .7))
 link=bpy.context.object;link.data.materials.append(gold);link.vertex_groups.new(name='Chest').add(list(range(len(link.data.vertices))),1,'REPLACE');parts.append(link)
bpy.ops.object.select_all(action='DESELECT')
for part in parts:part.select_set(True)
bpy.context.view_layer.objects.active=mesh;bpy.ops.object.join()
mesh.name='Grisaldi_Check_Shirt'
bpy.ops.wm.save_as_mainfile(filepath=str(O/'Grisaldi_Shirt.blend'))
bpy.ops.export_scene.gltf(filepath=str(R/'assets/shirts/glb/16_Grisaldi_Check.glb'),export_format='GLB',export_animations=False)
print('GRISALDI_SHIRT_READY')
