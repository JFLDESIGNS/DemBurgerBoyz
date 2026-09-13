import bpy, re, json, struct
from pathlib import Path
out=Path('C:/Users/joe/Desktop/burgergame/assets/machines')
scene=bpy.context.scene
original_frame=scene.frame_current
original_selection=[o.name for o in bpy.context.selected_objects]
original_active=bpy.context.view_layer.objects.active.name if bpy.context.view_layer.objects.active else None
scene.frame_set(1)
originals=list(bpy.data.collections['GRILL | Export'].all_objects)
cache={o:o.name for o in originals};copies={}
export=bpy.data.collections.new('TEMP Export');scene.collection.children.link(export)
dg=bpy.context.evaluated_depsgraph_get()
for o in originals:
    name=cache[o];o.name='SOURCE__'+name
    if o.type in {'MESH','FONT'}:
        mesh=bpy.data.meshes.new_from_object(o.evaluated_get(dg),depsgraph=dg);c=bpy.data.objects.new(name,mesh)
    else:
        c=o.copy();c.name=name
    export.objects.link(c);copies[o]=c
for o,c in copies.items():
    c.parent=copies.get(o.parent);c.matrix_parent_inverse=o.matrix_parent_inverse.copy();c.matrix_basis=o.matrix_basis.copy()
bpy.context.view_layer.update()
export_root=copies[bpy.data.objects['SOURCE__StylizedGrill']]
export_knob=copies[bpy.data.objects['SOURCE__PowerKnob']]
# Batch by material while retaining the independent cooking plate, lamp, and rotary pivot.
buckets={}
for c in list(export.objects):
    if c.type!='MESH' or c.name in {'CookingSurface','PowerIndicator'}:continue
    parent=export_knob if c in export_knob.children_recursive else export_root
    material=c.data.materials[0]
    buckets.setdefault((parent,material),[]).append(c)
for (parent,material),objects in buckets.items():
    for c in objects:
        world=c.matrix_world.copy();c.parent=parent;c.matrix_world=world
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT')
    for c in objects:c.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    if len(objects)>1:bpy.ops.object.join()
    objects[0].name=('Rotary_' if parent==export_knob else 'Housing_')+re.sub('[^A-Za-z0-9]+','_',material.name.split('|')[0]).strip('_')

# Drop empty organizational groups after static batching.
while True:
    unused=[o for o in export.objects if o.type=='EMPTY' and not o.children and o!=export_root and o!=export_knob]
    if not unused:break
    for o in unused:bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.object.select_all(action='DESELECT')
for c in export.objects:c.select_set(True)
bpy.context.view_layer.objects.active=export_root
bpy.ops.export_scene.gltf(filepath=str(out/'stylized_grill.glb'),export_format='GLB',use_selection=True,export_animations=True,export_yup=True,export_extras=True,export_cameras=False,export_lights=False)
for c in list(export.objects):bpy.data.objects.remove(c,do_unlink=True)
bpy.data.collections.remove(export)
for o,name in cache.items():o.name=name
# Restore editing state. Export never rewrites the artist's source blend.
bpy.ops.object.select_all(action='DESELECT')
for name in original_selection:
    if name in bpy.data.objects:bpy.data.objects[name].select_set(True)
if original_active and original_active in bpy.data.objects:bpy.context.view_layer.objects.active=bpy.data.objects[original_active]
scene.frame_set(original_frame)
b=(out/'stylized_grill.glb').read_bytes();n=struct.unpack_from('<I',b,12)[0];g=json.loads(b[20:20+n])
stats={'triangles':sum(g['accessors'][a['indices']]['count']//3 for m in g['meshes'] for a in m['primitives']),'meshes':len(g['meshes']),'bytes':len(b),'animations':[a.get('name') for a in g.get('animations',[])]}
(out/'stylized_grill_stats.json').write_text(json.dumps(stats,indent=2))
print('EXPORT_STATS',stats)
