import bpy, math, ast, json
import numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:/Users/joe/Desktop/burgergame');OUT=ROOT/'models/mill_market_cutouts';DEST=ROOT/'assets/backgrounds/mill_market_layers';DEST.mkdir(exist_ok=True)
s=bpy.context.scene;s.frame_set(1);bpy.context.view_layer.update()
def pixels(im):
 w,h=im.size;a=np.empty(w*h*4,np.float32);im.pixels.foreach_get(a);return a.reshape(h,w,4)[::-1].copy()
def image(name,a,save=True):
 h,w=a.shape[:2];im=bpy.data.images.new(name,width=w,height=h,alpha=True);im.pixels.foreach_set(np.ascontiguousarray(a[::-1]).ravel())
 if save:im.filepath_raw=str(DEST/(name+'.png'));im.file_format='PNG';im.save()
 im.pack();return im
def mat(name,im):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear();l=m.node_tree.links;o=n.new('ShaderNodeOutputMaterial');p=n.new('ShaderNodeBsdfPrincipled');p.inputs['Roughness'].default_value=.85;p.inputs['Emission Strength'].default_value=.65;t=n.new('ShaderNodeTexImage');t.image=im;l.new(t.outputs['Color'],p.inputs['Base Color']);l.new(t.outputs['Color'],p.inputs['Emission Color']);l.new(t.outputs['Alpha'],p.inputs['Alpha']);l.new(p.outputs[0],o.inputs[0]);m.surface_render_method='DITHERED';return m
def pos(x,y,z=0):return ((x-1024)/100,(576.5-y)/100,z)
raw=pixels(bpy.data.images.load(str(ROOT/'assets/backgrounds/mill1.png'),check_existing=False));H,W=raw.shape[:2];sx,sy=W/2048,H/1153
# Smooth tiling cartoon cloud opacity: overlapping rounded puffs, not streaks.
N=512;yy,xx=np.mgrid[0:N,0:N]/N;cloud=np.zeros((N,N),np.float32)
for cx,cy,rx,ry in [(.18,.30,.13,.05),(.11,.28,.055,.065),(.19,.25,.075,.085),(.27,.28,.06,.065),(.69,.73,.16,.05),(.60,.70,.065,.06),(.69,.65,.08,.10),(.78,.70,.065,.075)]:
 dx=np.minimum(abs(xx-cx),1-abs(xx-cx));dy=np.minimum(abs(yy-cy),1-abs(yy-cy));p=np.clip((1-(dx/rx)**2-(dy/ry)**2)*4,0,1);p=p*p*(3-2*p);cloud=np.maximum(cloud,p)
a=np.ones((N,N,4),np.float32);a[:,:,:3]=cloud[:,:,None];cloudim=image('cloud_reflection_tile',a)
tree=ast.parse((OUT/'build_cutouts.py').read_text(encoding='utf-8-sig'));windows=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='windows' for t in n.targets))
upper=np.zeros_like(raw);lower=np.zeros_like(raw);uppermask=np.zeros((H,W),np.float32);lowermask=uppermask.copy();metadata=[]
for name,pts in windows:
 im=bpy.data.images.load(str(OUT/(name+'.png')),check_existing=False);a=pixels(im);h,w=a.shape[:2];x0=int(min(p[0] for p in pts)*sx);y0=int(min(p[1] for p in pts)*sy)
 is_upper=any(k in name for k in ['Upper','Top','Middle']);door=name in ['Poodle_Door_Glass','Motel_Door']
 if not is_upper:
  v=np.linspace(0,1,h)[:,None];blend=np.clip((v-.62)/.38,0,1);blend=blend*blend*(3-2*blend)*.84;a[:,:,:3]=a[:,:,:3]*(1-blend[:,:,None])+np.array([.48,.36,.22])*blend[:,:,None]
 fresh=image(name+'_glass',a,False);ob=bpy.data.objects[name+'_GLASS'];m=ob.data.materials[0];n=m.node_tree.nodes;l=m.node_tree.links;tex=next(t for t in n if t.type=='TEX_IMAGE');tex.image=fresh;emit=next(t for t in n if t.type=='EMISSION');l.new(tex.outputs['Color'],emit.inputs['Color'])
 if is_upper:
  uv=n.new('ShaderNodeTexCoord');mapping=n.new('ShaderNodeMapping');l.new(uv.outputs['UV'],mapping.inputs[0]);mapping.inputs['Scale'].default_value=(w/W*3,h/H*2,1)
  for frame,offset in [(1,0),(240,.095)]:mapping.inputs['Location'].default_value=(x0/W*3+offset,(1-(y0+h)/H)*2,0);mapping.inputs['Location'].keyframe_insert('default_value',frame=frame)
  t=n.new('ShaderNodeTexImage');t.image=cloudim;t.extension='REPEAT';l.new(mapping.outputs[0],t.inputs[0]);gain=n.new('ShaderNodeMath');gain.operation='MULTIPLY';gain.inputs[1].default_value=.24;l.new(t.outputs['Color'],gain.inputs[0]);mix=n.new('ShaderNodeMixRGB');mix.inputs[2].default_value=(.88,.91,.83,1);l.new(gain.outputs[0],mix.inputs[0]);l.new(tex.outputs['Color'],mix.inputs[1]);l.new(mix.outputs[0],emit.inputs['Color'])
 layer=upper if is_upper else lower;mask=uppermask if is_upper else lowermask
 mask[y0:y0+h,x0:x0+w]=np.maximum(mask[y0:y0+h,x0:x0+w],a[:,:,3])
 if not door:
  region=layer[y0:y0+h,x0:x0+w];sel=a[:,:,3]>0;region[sel]=a[sel]
 # Individual full-image aligned masks permit per-window effects in Godot.
 ma=np.ones_like(a);ma[:,:,:3]=a[:,:,3,None];ma[:,:,3]=1;image(name+'_mask',ma)
 metadata.append({'name':name,'upper':is_upper,'door_glass':door,'pixel_rect':[x0,y0,w,h],'mask':name+'_mask.png'})
image('upper_glass',upper);image('street_glass',lower)
for name,mask in [('upper_windows_mask',uppermask),('street_windows_mask',lowermask)]:
 a=np.ones_like(raw);a[:,:,:3]=mask[:,:,None];image(name,a)
# Doors open beyond a right angle toward positive depth (street/camera side).
doors=[]
for name,sign,start in [('Old_Poodle_Door',1,20),('Motel_Door',1,48)]:
 h=bpy.data.objects[name+'_HINGE'];worlds={o:o.matrix_world.copy() for o in h.children};h.animation_data_clear()
 top,bottom=((1033,757),(1028,932)) if name=='Old_Poodle_Door' else ((1412,800),(1416,931))
 axis=(Vector(pos(*top))-Vector(pos(*bottom))).normalized();h.location=pos(*top,.04);h.rotation_axis_angle=(0,*axis);bpy.context.view_layer.update()
 for child,world_matrix in worlds.items():child.matrix_parent_inverse=h.matrix_world.inverted();child.matrix_world=world_matrix
 for f,angle in [(1,0),(start,0),(start+42,sign*math.radians(110)),(start+86,sign*math.radians(110)),(start+130,0),(240,0)]:h.rotation_axis_angle=(angle,*axis);h.keyframe_insert('rotation_axis_angle',frame=f)
 doors.append({'name':name,'hinge':h.name,'axis_gltf':[axis.x,axis.z,-axis.y],'direction':sign,'open_degrees':110})
 edge=bpy.data.objects[name+'_Leaf'].data.materials[1];edge.use_nodes=True;n=edge.node_tree.nodes;old=next(t for t in n if t.type in ['EMISSION','BSDF_PRINCIPLED']);color=old.inputs[0].default_value[:];n.clear();p=n.new('ShaderNodeBsdfPrincipled');p.inputs['Base Color'].default_value=color;p.inputs['Roughness'].default_value=.8;o=n.new('ShaderNodeOutputMaterial');edge.node_tree.links.new(p.outputs[0],o.inputs[0])
# Reuse the painted building palette inside the doorways, avoiding black voids.
for ob in s.objects:
 if ob.name.endswith('_Interior_Back') and ob.name.startswith(('Old_Poodle','Motel')):
  color=(.085,.055,.028,1) if ob.name.startswith('Old_Poodle') else (.075,.055,.105,1)
  for material in ob.data.materials:
   for node in material.node_tree.nodes:
    if node.type=='EMISSION':node.inputs[0].default_value=color
# Give inward-opening leaves enough recessed room behind the facade.
for ob in s.objects:
 if ob.type=='MESH' and (ob.name.endswith('_Interior_Back') or '_Jamb_' in ob.name) and ob.name.startswith(('Old_Poodle','Motel')):
  for vertex in ob.data.vertices:
   if vertex.co.z < -.3:vertex.co.z=-1.3
# Bake glazing into each door face, rather than floating it over a thin alpha plane.
# Front, back and edge get independent materials, so timber sides never sample glass.
def painted(name,color=None,texture=None):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear();l=m.node_tree.links;o=n.new('ShaderNodeOutputMaterial');e=n.new('ShaderNodeEmission');l.new(e.outputs[0],o.inputs[0])
 if texture:
  t=n.new('ShaderNodeTexImage');t.image=texture;l.new(t.outputs['Color'],e.inputs[0])
 else:e.inputs[0].default_value=color
 return m
for name,glassname,points,edgecolor in [('Old_Poodle_Door','Poodle_Door_Glass',[(1033,757),(1106,754),(1113,928),(1028,932)],(.35,.225,.105,1)),('Motel_Door','Motel_Door',[(1412,800),(1486,790),(1491,925),(1416,931)],(.27,.215,.34,1))]:
 ob=bpy.data.objects[name+'_Leaf'];x0=int(min(p[0] for p in points)*sx);y0=int(min(p[1] for p in points)*sy);x1=int(np.ceil(max(p[0] for p in points)*sx))+1;y1=int(np.ceil(max(p[1] for p in points)*sy))+1
 face=raw[y0:y1,x0:x1].copy();face[:,:,3]=1
 spec=next(d for d in metadata if d['name']==glassname);gx,gy,gw,gh=spec['pixel_rect'];glassob=bpy.data.objects[glassname+'_GLASS'];glassim=next(t.image for t in glassob.data.materials[0].node_tree.nodes if t.type=='TEX_IMAGE');ga=pixels(glassim)
 # Crop the original glass mask to the leaf and combine before export.
 left,top=max(x0,gx),max(y0,gy);right,bottom=min(x1,gx+gw),min(y1,gy+gh)
 g=ga[top-gy:bottom-gy,left-gx:right-gx];region=face[top-y0:bottom-y0,left-x0:right-x0];region[:,:,:3]=region[:,:,:3]*(1-g[:,:,3,None])+g[:,:,:3]*g[:,:,3,None]
 front=image(name+'_front',face);back=face.copy();back[:,:,:3]*=.89;rear=image(name+'_back',back)
 ob.data.materials.clear();ob.data.materials.append(painted(name+'_Front',texture=front));ob.data.materials.append(painted(name+'_Back',texture=rear));ob.data.materials.append(painted(name+'_Edges',color=edgecolor))
 for poly in ob.data.polygons:poly.material_index=0 if poly.normal.z>.5 else (1 if poly.normal.z<-.5 else 2)
 for loop in ob.data.loops:
  v=ob.data.vertices[loop.vertex_index].co;px=(v.x*100+1024)*sx;py=(576.5-v.y*100)*sy;ob.data.uv_layers[0].data[loop.index].uv=((px-x0)/(x1-x0),1-(py-y0)/(y1-y0))
 glassob.hide_render=True;glassob.hide_set(True)
# Match the hand-painted canopy silhouette, including the left folded flap.
pts=[(455,775),(511,721),(843,700),(881,746),(499,783),(507,752),(484,786)]
q=np.array([(x*sx,y*sy) for x,y in pts]);yy,xx=np.mgrid[0:H,0:W];xx=xx+.5;yy=yy+.5;mask=np.zeros((H,W),bool)
for i in range(len(q)):
 ax,ay=q[i];bx,by=q[(i+1)%len(q)]
 if abs(by-ay)>1e-6:mask^=((ay>yy)!=(by>yy))&(xx<(bx-ax)*(yy-ay)/(by-ay)+ax)
canopy=raw.copy();canopy[:,:,3]=mask;canopyim=image('market_canopy',canopy)
a=np.ones_like(raw);a[:,:,:3]=mask[:,:,None];image('market_canopy_mask',a)
backob=bpy.data.objects['STREET — alpha-cut background'];backtex=next(t for t in backob.data.materials[0].node_tree.nodes if t.type=='TEX_IMAGE');back=pixels(backtex.image);back[:,:,3][mask]=0;backtex.image=image('street_base_cutout',back)
# Painted dark backing stops the canopy opening revealing empty sky behind walkers.
fill=np.zeros_like(raw);fill[:,:,:3]=[.115,.17,.145];fill[:,:,3]=mask;fillim=image('canopy_backing',fill)
for name,im,depth in [('Market_Canopy_Foreground',canopyim,.65),('Market_Canopy_Backing',fillim,-.01)]:
 old=bpy.data.objects.get(name)
 if old:bpy.data.objects.remove(old,do_unlink=True)
 me=bpy.data.meshes.new(name);me.from_pydata([pos(0,0,depth),pos(2048,0,depth),pos(2048,1153,depth),pos(0,1153,depth)],[],[(3,2,1,0)]);ob=bpy.data.objects.new(name,me);s.collection.objects.link(ob);uv=me.uv_layers.new()
 for loop in me.loops:uv.data[loop.index].uv=[(0,1),(1,1),(1,0),(0,0)][loop.vertex_index]
 # Use painted emission to match the background exactly.
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear();l=m.node_tree.links;o=n.new('ShaderNodeOutputMaterial');e=n.new('ShaderNodeEmission');t=n.new('ShaderNodeTexImage');t.image=im;tr=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader');l.new(t.outputs['Color'],e.inputs[0]);l.new(t.outputs['Alpha'],mix.inputs[0]);l.new(tr.outputs[0],mix.inputs[1]);l.new(e.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],o.inputs[0]);me.materials.append(m)
# Export actual corrected masks, not the previous revision's door outlines.
dm=np.zeros((H,W),bool)
for points in [[(1033,757),(1106,754),(1113,928),(1028,932)],[(1412,800),(1486,790),(1491,925),(1416,931)]]:
 q=np.array([(x*sx,y*sy) for x,y in points]);part=np.zeros((H,W),bool)
 for i in range(4):
  ax,ay=q[i];bx,by=q[(i+1)%4]
  if abs(by-ay)>1e-6:part^=((ay>yy)!=(by>yy))&(xx<(bx-ax)*(yy-ay)/(by-ay)+ax)
 dm|=part
a=np.ones_like(raw);a[:,:,:3]=dm[:,:,None];image('doors_mask',a)
world=s.world or bpy.data.worlds.new('World');s.world=world;world.use_nodes=True;world.node_tree.nodes.get('Background').inputs[0].default_value=(.55,.60,.65,1)
light=bpy.data.objects.get('Door edge softbox')
if not light:
 light=bpy.data.objects.new('Door edge softbox',bpy.data.lights.new('Door edge softbox','AREA'));s.collection.objects.link(light)
light.location=(-3,5,8);light.data.energy=1200;light.data.shape='DISK';light.data.size=8
# Save open and angled previews for clear outward-depth inspection.
s.frame_set(90);bpy.context.view_layer.update()
for d in doors:
 leaf=bpy.data.objects[d['name']+'_Leaf'];assert min((leaf.matrix_world@v.co).z for v in leaf.data.vertices)<-.5
s.camera=bpy.data.objects['CAMERA — doors closeup'];s.render.resolution_x=1600;s.render.resolution_y=1000;s.render.resolution_percentage=85;s.render.filepath=str(OUT/'godot_layers_preview.png');bpy.ops.render.render(write_still=True)
cam=bpy.data.objects.get('CAMERA — outward door proof')
if not cam:cam=bpy.data.objects.new('CAMERA — outward door proof',bpy.data.cameras.new('Outward perspective'));s.collection.objects.link(cam)
cam.location=(7,-.5,12);target=Vector((2,-2,0));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='PERSP';cam.data.lens=48;s.camera=cam;s.render.filepath=str(OUT/'outward_doors_perspective.png');bpy.ops.render.render(write_still=True)
# GLB carries only doors/recesses. Godot rotates its Y-up root by +90 degrees X.
s.frame_set(1);bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT');selected=[]
for ob in s.objects:
 if ob.name.startswith(('Old_Poodle_Door','Motel_Door_','Motel_Jamb_','Motel_Interior_Back')) or ob.name in ['Poodle_Door_Glass_GLASS','Motel_Door_GLASS']:
  if ob.type in ['MESH','EMPTY'] and not ob.hide_render:ob.hide_set(False);ob.select_set(True);selected.append(ob)
# Temporary export-compatible materials; restore Blender originals afterward.
restore=[]
for ob in selected:
 if ob.type!='MESH':continue
 for i,m in enumerate(ob.data.materials):
  if not m.use_nodes:continue
  tex=next((n for n in m.node_tree.nodes if n.type=='TEX_IMAGE'),None)
  if tex:restore.append((ob,i,m));ob.data.materials[i]=mat(m.name+'_GLTF',tex.image)
bpy.ops.export_scene.gltf(filepath=str(DEST/'street_doors.glb'),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
for ob,i,m in restore:ob.data.materials[i]=m
(DEST/'layers.json').write_text(json.dumps({'resolution':[W,H],'world_size':[20.48,11.53],'front_axis':'+Z','canopy_depth':.65,'walker_depth_range':[.15,.55],'windows':metadata,'doors':doors},indent=2))
s.frame_set(90);s.camera=bpy.data.objects['CAMERA — doors closeup'];s['instructions']='110-degree inward doors. Brighter amber lower glass. Moving cloud reflections upstairs. Separate canopy foreground at depth .65; walkers between .15 and .55. Godot-ready layers in assets/backgrounds/mill_market_layers.'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Mill_Market_Animated_Doors.blend'),compress=True)
print('LAYER_EXPORT_OK',flush=True)
