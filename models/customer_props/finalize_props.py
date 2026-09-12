import bpy,json,struct,math
from pathlib import Path
from mathutils import Vector
OUT=Path(r'C:\Users\joe\Desktop\burgergame\models\customer_props')
bpy.ops.wm.open_mainfile(filepath=str(OUT/'customer_props.blend'))
manifest=json.loads((OUT/'manifest.json').read_text())
exp=bpy.data.scenes.new('Temporary export');bpy.context.window.scene=exp
report=[]
with bpy.context.temp_override(scene=exp,view_layer=exp.view_layers[0]):
 for item in manifest:
  source=bpy.data.objects[item['id']]
  obj=bpy.data.objects.new(item['id']+'_EXPORT',source.data);exp.collection.objects.link(obj)
  obj['prop_id']=item['id'];obj['size_multiplier']=2.0;obj['units']='meters'
  old=bpy.data.objects.get('GripPoint')
  if old:old.name='Original_'+old.name
  marker=bpy.data.objects.new('GripPoint',None);exp.collection.objects.link(marker);marker.parent=obj
  grip=Vector((item['grip_godot_xyz'][0],-item['grip_godot_xyz'][2],item['grip_godot_xyz'][1]))
  marker.location=grip;obj['grip_blender_xyz']=list(grip)
  bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);marker.select_set(True);bpy.context.view_layer.objects.active=obj;bpy.context.view_layer.update()
  source.data.calc_loop_triangles();tri=len(source.data.loop_triangles)
  item['triangles']=tri;item['size_m_blender_xyz']=list(obj.dimensions)
  path=OUT/'glb'/(item['id']+'.glb')
  bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_extras=True,export_apply=True)
  data=path.read_bytes();magic,ver,length=struct.unpack_from('<III',data);assert magic==0x46546c67 and ver==2 and length==len(data)
  jlen,jtype=struct.unpack_from('<II',data,12);doc=json.loads(data[20:20+jlen])
  assert len(doc['meshes'])==1 and not doc.get('textures')
  assert sum(1 for n in doc['nodes'] if n.get('name')=='GripPoint')==1
  exported_tri=0
  for primitive in doc['meshes'][0]['primitives']:
   assert 'NORMAL' in primitive['attributes']
   indices=doc['accessors'][primitive['indices']];assert indices['count']%3==0;exported_tri+=indices['count']//3
  assert exported_tri==tri,(item['id'],tri,exported_tri)
  report.append({'file':path.name,'triangles':tri,'materials':len(doc.get('materials',[])),'grip_point':True,'size_multiplier':2.0})
  bpy.data.objects.remove(marker,do_unlink=True);bpy.data.objects.remove(obj,do_unlink=True)
# Remove the superseded glasses asset now that its replacement is exported.
for name in ['20_Sunglasses.glb','20_Sunglasses.glb.import']:
 p=OUT/'glb'/name
 if p.exists():p.unlink()
assert len(list((OUT/'glb').glob('*.glb')))==30
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
(OUT/'validation.json').write_text(json.dumps({'count':30,'total_triangles':sum(x['triangles'] for x in report),'size_multiplier':2,'assets':report},indent=2),encoding='utf-8')
readme="""# Refined customer props — 30 assets

All 30 props were enlarged 2x. The final requested adjustments are applied on top: umbrella 25% smaller with a rounder dome; skateboard 20% smaller overall and 45% wider across the deck before the overall reduction; shopping bag 20% smaller; both phones black and 15% larger. Geometry and GripPoint positions are baked into the individual GLB exports.

Updated shapes: deeper scalloped umbrella canopy, folded/gusseted shopping bag, seven tulips with shaped petals, smooth orange basketball with black panel seams, rounded concave skateboard with kicked ends. Slot 20 is now a black cell phone; glasses are removed. Stronger saturated materials throughout.

## Blender preview scenes
- CHARACTER PREVIEWS | Refined six: the six revised props on copies of the supplied characterMedium model.
- CHARACTER PREVIEWS | All 30: one character fit example for every prop.
- CUSTOMER PROPS | 30: labeled prop-only catalog; display sizes are normalized.

The supplied character uses the game's CHAR_SCALE = 0.552 from scripts/customer.gd. The imported FBX skin alpha was restored from zero to one in the preview only, so the model is visible. Original FBX is unchanged. Held props are attached to the RightHand bone and aligned with their grip markers; the backpack is shown worn. These are editable example poses, not animation integration.

## Files
- customer_props.blend: models, material palette, posed character previews.
- glb/: exactly 30 individual prop assets, one mesh each, with embedded solid-color PBR materials and a GripPoint child.
- customer_props_preview.png: prop catalog.
- refined_character_preview.png: revised six on the supplied model.
- all_30_character_preview.png: all 30 on the supplied model.
- manifest.json / validation.json: dimensions, grip positions, triangle counts, export checks.
- build_customer_props.py then build_character_previews.py: rebuild geometry/exports/catalog and then character previews.
- before_refinement/: prior version.

GLBs are Y-up, in meter units at the requested oversized game scale. Blender is Z-up. Root transforms are identity; import at scale 1. For hand attachment, align GripPoint to the desired hand contact and adjust orientation for the character animation. No textures, animation, collision shapes, or customer behavior changes are included.

## Included assets
"""
for r in report:readme+='\n- '+r['file'][:-4].replace('_',' ')+f" — {r['triangles']:,} triangles"
(OUT/'README.md').write_text(readme+'\n',encoding='utf-8')
print('FINAL_EXPORT_VALIDATION_PASS',len(report),sum(x['triangles'] for x in report),flush=True)
for scenename,filename in [('CHARACTER PREVIEWS | Refined six','refined_character_preview.png'),('CUSTOMER PROPS | 30','customer_props_preview.png'),('CHARACTER PREVIEWS | All 30','all_30_character_preview.png')]:
 s=bpy.data.scenes[scenename]
 bpy.context.window.scene=s;s.render.filepath=str(OUT/filename)
 bpy.ops.render.render(write_still=True,scene=s.name)
 print('RENDER_COMPLETE',filename,flush=True)
print('FINAL_DELIVERY_COMPLETE',flush=True)
