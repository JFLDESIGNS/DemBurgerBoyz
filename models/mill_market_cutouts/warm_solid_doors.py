import bpy, math, json
import numpy as np
from pathlib import Path
from mathutils import Vector
OUT=Path(r'C:/Users/joe/Desktop/burgergame/models/mill_market_cutouts')
s=bpy.context.scene;s.frame_set(1);bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Before_Warm_Solid_Doors.blend'),copy=True)
def pos(x,y,z=0):return Vector(((x-1024)/100,(576.5-y)/100,z))
def pixels(im):
 w,h=im.size;a=np.empty(w*h*4,np.float32);im.pixels.foreach_get(a);return a.reshape(h,w,4)[::-1].copy()
def img(name,a):
 h,w=a.shape[:2];im=bpy.data.images.new(name,width=w,height=h,alpha=True);im.pixels.foreach_set(np.ascontiguousarray(a[::-1]).ravel());im.pack();return im
source=bpy.data.images.load(str(OUT.parent.parent/'assets/backgrounds/mill1.png'),check_existing=False)
raw=pixels(source);H,W=raw.shape[:2];sx,sy=W/2048,H/1153
# Always restore original window pixels, so no previous grey tint accumulates.
for ob in [o for o in s.objects if o.name.endswith('_GLASS')]:
 name=ob.name[:-6];im=bpy.data.images.load(str(OUT/(name+'.png')),check_existing=False);a=pixels(im)
 lower=not any(k in name for k in ['Upper','Top','Middle'])
 if lower:
  h=a.shape[0];v=np.linspace(0,1,h)[:,None];blend=np.clip((v-.30)/.70,0,1);blend=blend*blend*(3-2*blend)*.70
  # Muted warm amber: brighter than the old grey, without glowing white.
  warm=np.array([.52,.37,.21],np.float32)
  a[:,:,:3]=a[:,:,:3]*(1-blend[:,:,None])+warm*blend[:,:,None]
 im=img(name+'_WarmLower' if lower else name+'_Original',a)
 mat=ob.data.materials[0];n=mat.node_tree.nodes
 tex=next(x for x in n if x.type=='TEX_IMAGE');tex.image=im
 # Remove residual animated reflection from upper windows completely.
 if not lower:
  emit=next(x for x in n if x.type=='EMISSION');mat.node_tree.links.new(tex.outputs['Color'],emit.inputs['Color'])
 ob['warm_gradient']=lower
# Rebuild the background from the untouched original using precise matching masks.
def poly(points):
 q=np.array([(x*sx,y*sy) for x,y in points]);x0,y0=np.floor(q.min(0)).astype(int);x1,y1=np.ceil(q.max(0)).astype(int)+1
 yy,xx=np.mgrid[y0:y1,x0:x1];xx=xx+.5;yy=yy+.5;m=np.zeros(xx.shape,bool)
 for i in range(len(q)):
  ax,ay=q[i];bx,by=q[(i+1)%len(q)]
  if abs(by-ay)>1e-6:m^=((ay>yy)!=(by>yy))&(xx<(bx-ax)*(yy-ay)/(by-ay)+ax)
 return (x0,y0,x1,y1),m
bg=raw.copy();win=pixels(bpy.data.images.load(str(OUT/'windows_mask.png'),check_existing=False))[:,:,0];bg[:,:,3]=1-win
specs=[('Old_Poodle_Door',[(1033,757),(1106,754),(1113,928),(1028,932)],1,20,1,'Poodle_Door_Glass_GLASS'),('Motel_Door',[(1412,800),(1486,790),(1491,925),(1416,931)],0,48,-1,'Motel_Door_GLASS')]
door_mask=np.zeros((H,W),np.float32)
def flatmat(name,color):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear();o=n.new('ShaderNodeOutputMaterial');e=n.new('ShaderNodeEmission');e.inputs[0].default_value=color;m.node_tree.links.new(e.outputs[0],o.inputs[0]);return m
for name,points,hinge_i,start,direction,glassname in specs:
 hinge=bpy.data.objects[name+'_HINGE'];hinge.animation_data_clear();hinge.rotation_euler=(0,0,0)
 glass=bpy.data.objects[glassname];world=glass.matrix_world.copy();glass.parent=None;glass.matrix_world=world
 for ob in list(s.objects):
  if ob==hinge:continue
  if ob.name==name or ob.name==name+'_Leaf' or ob.name.startswith(name+'_Jamb_') or ob.name==name+'_Interior_Back' or (name=='Motel_Door' and (ob.name.startswith('Motel_Jamb_') or ob.name=='Motel_Interior_Back')):
   bpy.data.objects.remove(ob,do_unlink=True)
 box,mask=poly(points);x0,y0,x1,y1=box;bg[y0:y1,x0:x1,3][mask]=0;door_mask[y0:y1,x0:x1][mask]=1
 a=raw[y0:y1,x0:x1].copy();a[:,:,3]=1 # Geometry defines the edge; no torn alpha on solid timber.
 im=img(name+'_SolidPaint',a);m=flatmat(name+'_SolidPaint',(1,1,1,1));tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;m.node_tree.links.new(tex.outputs['Color'],next(n for n in m.node_tree.nodes if n.type=='EMISSION').inputs[0])
 edge=flatmat(name+'_SolidEdge',(.33,.22,.10,1) if hinge_i else (.24,.20,.32,1))
 me=bpy.data.meshes.new(name+'_SolidMesh');me.from_pydata([pos(*p,.04) for p in points],[],[(3,2,1,0)]);me.materials.append(m);me.materials.append(edge)
 ob=bpy.data.objects.new(name+'_Leaf',me);s.collection.objects.link(ob);uv=me.uv_layers.new()
 for loop in me.loops:
  x,y=points[loop.vertex_index];uv.data[loop.index].uv=((x*sx-x0)/(x1-x0),1-(y*sy-y0)/(y1-y0))
 bpy.context.view_layer.objects.active=ob;ob.select_set(True)
 solid=ob.modifiers.new('Solid 10 cm timber','SOLIDIFY');solid.thickness=.10;solid.offset=-1;solid.material_offset=0;solid.material_offset_rim=1;bpy.ops.object.modifier_apply(modifier=solid.name)
 bevel=ob.modifiers.new('Soft timber edges','BEVEL');bevel.width=.006;bevel.segments=2
 # Keep the original slanted jamb as the actual axis of rotation.
 top=pos(*points[hinge_i],.04);bottom=pos(*points[2 if hinge_i else 3],.04);axis=(top-bottom).normalized()
 hinge.location=top;hinge.rotation_mode='AXIS_ANGLE';hinge.rotation_axis_angle=(0,*axis);bpy.context.view_layer.update()
 for child in [ob,glass]:
  world=child.matrix_world.copy()
  if child==glass:world.translation.z=.043
  child.parent=hinge;child.matrix_parent_inverse=hinge.matrix_world.inverted();child.matrix_world=world
 for frame,ang in [(1,0),(start,0),(start+42,direction*math.radians(68)),(start+86,direction*math.radians(68)),(start+130,0),(240,0)]:
  hinge.rotation_axis_angle=(ang,*axis);hinge.keyframe_insert('rotation_axis_angle',frame=frame)
 # Four full-depth jambs surround a warm shadowed interior.
 inside=flatmat(name+'_Interior',(.045,.037,.03,1))
 for i in range(5):
  verts=[pos(*p,-.40) for p in points] if i==4 else [pos(*points[i],0),pos(*points[(i+1)%4],0),pos(*points[(i+1)%4],-.40),pos(*points[i],-.40)]
  mesh=bpy.data.meshes.new(name+'_Recess');mesh.from_pydata(verts,[],[(0,1,2,3)]);mesh.materials.append(inside if i==4 else edge);o=bpy.data.objects.new(name+('_Interior_Back' if i==4 else '_Jamb_'+str(i)),mesh);s.collection.objects.link(o)
 ob['thickness_m']=.10;hinge['swing']='Outward; reversed from previous version'
# Market stays painted shut; remove its obsolete cutout geometry.
for ob in s.objects:
 if ob.name.startswith('Mill_Market_Door'):ob.hide_render=True;ob.hide_set(True)
background=bpy.data.objects['STREET — alpha-cut background'];next(n for n in background.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE').image=img('Street_Clean_Door_Cutouts',bg)
a=np.ones((H,W,4),np.float32);a[:,:,:3]=door_mask[:,:,None];img('Corrected_Door_Mask',a)
s['instructions']='Ground-floor windows only have warm amber bottoms. Upstairs original blue. Solid 10cm doors swing outward on slanted jambs. Market stays shut. Frames 1 closed / 90 open.'
s.frame_set(90);bpy.context.view_layer.update()
s.camera=bpy.data.objects['CAMERA — doors closeup'];s.render.resolution_x=1600;s.render.resolution_y=1000;s.render.resolution_percentage=85;s.render.filepath=str(OUT/'warm_solid_doors_preview.png');bpy.ops.render.render(write_still=True)
s.frame_set(1);s.render.filepath=str(OUT/'warm_solid_doors_closed.png');bpy.ops.render.render(write_still=True)
s.frame_set(90);s.camera=bpy.data.objects['CAMERA — full street']
# Verify the door leaves have genuine depth and only ground-floor glass is tinted.
for name,*_ in specs:assert len(bpy.data.objects[name+'_Leaf'].data.vertices)==8
assert sum(bool(o.get('warm_gradient',False)) for o in s.objects if o.name.endswith('_GLASS'))==10
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Mill_Market_Animated_Doors.blend'),compress=True)
print('WARM_SOLID_DOORS_OK',flush=True)

