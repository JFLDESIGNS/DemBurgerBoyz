import bpy, math, json
import numpy as np
from pathlib import Path
OUT=Path(r'C:/Users/joe/Desktop/burgergame/models/mill_market_cutouts')
scene=bpy.context.scene
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Before_Door_Window_Revision.blend'),copy=True)
scene.frame_set(1);bpy.context.view_layer.update()
def pos(x,y,z=0):return ((x-1024)/100,(576.5-y)/100,z)
def animate(hinge,start,sign):
 hinge.animation_data_clear()
 for f,a in [(1,0),(start,0),(start+42,sign*math.radians(78)),(start+86,sign*math.radians(78)),(start+130,0),(240,0)]:
  hinge.rotation_euler.y=a;hinge.keyframe_insert('rotation_euler',frame=f)
# Move Old Poodle's pivot to its right jamb while preserving its closed pose.
pub=bpy.data.objects['Old_Poodle_Door_HINGE']
children={o:o.matrix_world.copy() for o in pub.children}
pub.location=pos(1108,752,.025);pub.rotation_euler.y=0;bpy.context.view_layer.update()
for ob,world in children.items():ob.matrix_parent_inverse=pub.matrix_world.inverted();ob.matrix_world=world
animate(pub,20,-1)
market=bpy.data.objects['Mill_Market_Door_HINGE'];market.animation_data_clear();market.rotation_euler.y=0;market['animation']='Static: stays closed'
# Subtle, broad, slow glass variation replaces the conspicuous diagonal stripes.
for ob in [o for o in scene.objects if o.name.endswith('_GLASS')]:
 m=ob.data.materials[0];n=m.node_tree.nodes;l=m.node_tree.links
 im=next(node.image for node in n if node.type=='TEX_IMAGE' and node.image)
 w,h=im.size;data=np.empty(w*h*4,dtype=np.float32);im.pixels.foreach_get(data);data=data.reshape(h,w,4)
 v=np.linspace(0,1,h)[:,None];amount=np.clip((.76-v)/.76,0,1);amount=amount*amount*(3-2*amount)*.9
 lum=data[:,:,:3]@np.array([.2126,.7152,.0722],np.float32)
 grey=np.stack([lum*.94,lum*.985,lum],axis=2)
 data[:,:,:3]=data[:,:,:3]*(1-amount[:,:,None])+grey*amount[:,:,None]
 im.pixels.foreach_set(data.ravel());im.filepath_raw=str(OUT/(im.name.split('.')[0]+'_grey_bottom.png'));im.file_format='PNG';im.save();im.pack()
 m.node_tree.animation_data_clear();n.clear()
 out=n.new('ShaderNodeOutputMaterial');tex=n.new('ShaderNodeTexImage');tex.image=im
 emit=n.new('ShaderNodeEmission');trans=n.new('ShaderNodeBsdfTransparent');alpha=n.new('ShaderNodeMixShader')
 l.new(tex.outputs['Alpha'],alpha.inputs[0]);l.new(trans.outputs[0],alpha.inputs[1]);l.new(emit.outputs[0],alpha.inputs[2]);l.new(alpha.outputs[0],out.inputs[0])
 uv=n.new('ShaderNodeTexCoord');mapping=n.new('ShaderNodeMapping');l.new(uv.outputs['UV'],mapping.inputs[0])
 for f,x in [(1,0),(120,.24),(240,0)]:mapping.inputs['Location'].default_value.x=x;mapping.inputs['Location'].keyframe_insert('default_value',frame=f)
 noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=1.3;noise.inputs['Detail'].default_value=1;l.new(mapping.outputs[0],noise.inputs[0])
 ramp=n.new('ShaderNodeMapRange');ramp.inputs['To Min'].default_value=.012;ramp.inputs['To Max'].default_value=.065;l.new(noise.outputs['Fac'],ramp.inputs['Value'])
 reflection=n.new('ShaderNodeMixRGB');reflection.blend_type='SCREEN';reflection.inputs[2].default_value=(.45,.53,.56,1)
 l.new(ramp.outputs['Result'],reflection.inputs[0]);l.new(tex.outputs['Color'],reflection.inputs[1]);l.new(reflection.outputs[0],emit.inputs['Color'])
 ob['reflection']='Broad 1–6 percent soft ambient reflection, no moving stripe'
# Cut a real motel doorway from the background and add a solid hinged door leaf.
source=bpy.data.images.load(str(OUT.parent.parent/'assets/backgrounds/mill1.png'),check_existing=True)
W,H=source.size;sx,sy=W/2048,H/1153
raw=np.empty(W*H*4,np.float32);source.pixels.foreach_get(raw);raw=raw.reshape(H,W,4)[::-1].copy()
points=[(1408,795),(1489,785),(1496,925),(1413,933)]
q=np.array([(x*sx,y*sy) for x,y in points]);x0,y0=np.floor(q.min(axis=0)).astype(int);x1,y1=np.ceil(q.max(axis=0)).astype(int)+1
yy,xx=np.mgrid[y0:y1,x0:x1];xx=xx+.5;yy=yy+.5;mask=np.zeros(xx.shape,bool)
for i in range(4):
 ax,ay=q[i];bx,by=q[(i+1)%4]
 if abs(by-ay)>1e-6:mask^=((ay>yy)!=(by>yy))&(xx<(bx-ax)*(yy-ay)/(by-ay)+ax)
background=bpy.data.objects['STREET — alpha-cut background'];bgtex=next(n for n in background.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
bg=bgtex.image;pixels=np.empty(W*H*4,np.float32);bg.pixels.foreach_get(pixels);pixels=pixels.reshape(H,W,4)[::-1].copy()
pixels[y0:y1,x0:x1,3]*=1-mask.astype(float)
bg.pixels.foreach_set(np.ascontiguousarray(pixels[::-1]).ravel());bg.filepath_raw=str(OUT/'street_with_cutouts.png');bg.save();bg.pack()
# Keep the exact original mask around motel glass; leave glazing to its separate object.
glass=bpy.data.objects['Motel_Door_GLASS'];glass_image=next(n.image for n in glass.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
crop=raw[y0:y1,x0:x1].copy();r,g,b=crop[:,:,0],crop[:,:,1],crop[:,:,2]
blue=(g>r*1.12)&(b>r*1.15)&(g>.12)&(b>.12)
crop[:,:,3]=(mask&~blue).astype(float)
im=bpy.data.images.new('Motel_Door_Leaf',width=x1-x0,height=y1-y0,alpha=True);im.pixels.foreach_set(np.ascontiguousarray(crop[::-1]).ravel());im.filepath_raw=str(OUT/'Motel_Door_Leaf.png');im.file_format='PNG';im.save();im.pack()
mat=bpy.data.materials.new('Motel painted door');mat.use_nodes=True;n=mat.node_tree.nodes;n.clear();l=mat.node_tree.links
out=n.new('ShaderNodeOutputMaterial');tex=n.new('ShaderNodeTexImage');tex.image=im;em=n.new('ShaderNodeEmission');tr=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader')
l.new(tex.outputs['Color'],em.inputs[0]);l.new(tex.outputs['Alpha'],mix.inputs[0]);l.new(tr.outputs[0],mix.inputs[1]);l.new(em.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs[0])
collection=bpy.data.collections.new('06 MOTEL — animated door');scene.collection.children.link(collection)
hinge=bpy.data.objects.new('Motel_Door_HINGE',None);collection.objects.link(hinge);hinge.location=pos(*points[0],.025);bpy.context.view_layer.update()
me=bpy.data.meshes.new('Motel door');me.from_pydata([pos(*p,.025) for p in points],[],[(3,2,1,0)])
door=bpy.data.objects.new('Motel_Door_Leaf',me);collection.objects.link(door);me.materials.append(mat);me.materials.append(bpy.data.materials['Door painted timber edge']);uv=me.uv_layers.new()
for loop in me.loops:
 x,y=points[loop.vertex_index];uv.data[loop.index].uv=((x*sx-x0)/(x1-x0),1-(y*sy-y0)/(y1-y0))
door.parent=hinge;door.matrix_parent_inverse=hinge.matrix_world.inverted()
solid=door.modifiers.new('Solid motel door edge','SOLIDIFY');solid.thickness=.045;solid.material_offset=1;solid.material_offset_rim=1
glass.parent=hinge;glass.matrix_parent_inverse=hinge.matrix_world.inverted()
me=bpy.data.meshes.new('Recessed motel room');me.from_pydata([pos(*p,-.42) for p in points],[],[(3,2,1,0)])
inside=bpy.data.objects.new('Motel_Interior_Back',me);collection.objects.link(inside);me.materials.append(bpy.data.materials['Interior warm shadow'])
for i in range(4):
 a=points[i];b=points[(i+1)%4];me=bpy.data.meshes.new('Motel jamb');me.from_pydata([pos(*a,-.02),pos(*b,-.02),pos(*b,-.42),pos(*a,-.42)],[],[(0,1,2,3)])
 ob=bpy.data.objects.new('Motel_Jamb_'+str(i),me);collection.objects.link(ob);me.materials.append(bpy.data.materials['Door painted timber edge'])
animate(hinge,48,1)
# Door mask now represents only the two animated doors.
maskim=bpy.data.images.load(str(OUT/'doors_mask.png'),check_existing=True)
maskpix=np.empty(W*H*4,np.float32);maskim.pixels.foreach_get(maskpix);maskpix=maskpix.reshape(H,W,4)[::-1].copy()
maskpix[int(775*sy):int(945*sy),int(525*sx):int(609*sx),:3]=0
region=maskpix[y0:y1,x0:x1,:3];region[mask]=1
maskim.pixels.foreach_set(np.ascontiguousarray(maskpix[::-1]).ravel());maskim.save();maskim.pack()
for marker in scene.timeline_markers:
 if marker.name=='MARKET OPENS':marker.name='MOTEL OPENS'
scene['instructions']='Space: play. Old Poodle opens from RIGHT jamb. Motel opens; Mill Market stays closed. Grey window bottoms and soft ambient reflection. No streak highlights.'
scene.frame_set(90)
for ob in scene.objects:ob.select_set(False)
pub.select_set(True);bpy.context.view_layer.objects.active=pub
scene.camera=bpy.data.objects['CAMERA — full street']
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Mill_Market_Animated_Doors.blend'))
print('REVISED: right-hinged pub, stationary market, animated motel, grey lower glass, soft reflections')
