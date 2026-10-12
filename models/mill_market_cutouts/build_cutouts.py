import bpy, math, json
import numpy as np
from pathlib import Path
ROOT=Path(r'C:/Users/joe/Desktop/burgergame');OUT=ROOT/'models/mill_market_cutouts'
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
source=bpy.data.images.load(str(ROOT/'assets/backgrounds/mill1.png'))
W,H=source.size;sx,sy=W/2048,H/1153
arr=np.empty(W*H*4,dtype=np.float32);source.pixels.foreach_get(arr);src=arr.reshape(H,W,4)[::-1].copy();del arr
windows=[
('Records_Upper_Left',[(224,538),(278,534),(284,650),(226,649)]),
('Records_Upper_Right',[(361,532),(400,528),(409,652),(362,649)]),
('Records_Display',[(186,741),(353,736),(361,900),(204,916)]),
('Market_Upper_Wide',[(560,550),(714,542),(714,637),(572,643)]),
('Market_Upper_Narrow',[(774,541),(811,532),(810,628),(780,632)]),
('Market_Display',[(632,778),(825,777),(835,919),(633,933)]),
('Poodle_Upper_Left',[(933,564),(997,549),(994,636),(930,635)]),
('Poodle_Upper_Right',[(1107,543),(1160,554),(1158,641),(1122,640)]),
('Poodle_Display_Left',[(878,763),(992,758),(1009,866),(880,866)]),
('Poodle_Door_Glass',[(1037,763),(1101,762),(1107,873),(1033,874)]),
('Poodle_Display_Right',[(1136,752),(1237,747),(1231,859),(1143,864)]),
('Motel_Top_Left',[(1326,369),(1426,361),(1424,463),(1334,466)]),
('Motel_Top_Right',[(1470,363),(1558,350),(1569,462),(1474,467)]),
('Motel_Middle_Left',[(1344,521),(1418,517),(1412,610),(1351,614)]),
('Motel_Middle_Right',[(1490,521),(1567,518),(1574,607),(1492,611)]),
('Motel_Lower_Left',[(1339,783),(1383,779),(1383,939),(1350,938)]),
('Motel_Door',[(1417,805),(1485,796),(1481,865),(1423,871)]),
('Motel_Transom',[(1425,777),(1456,768),(1472,779)]),
('Motel_Lower_Right',[(1534,781),(1561,775),(1570,933),(1535,935)]),
('Cafe_Upper_Left',[(1640,590),(1696,588),(1700,673),(1656,676)]),
('Cafe_Upper_Middle',[(1754,590),(1803,583),(1822,666),(1771,673)]),
('Cafe_Upper_Right',[(1841,576),(1881,576),(1873,661),(1851,665)]),
('Cafe_Display',[(1748,804),(1874,790),(1880,908),(1749,917)])]
doors=[
('Old_Poodle_Door',[(1031,755),(1108,752),(1116,930),(1025,935)],20,1),
('Mill_Market_Door',[(530,788),(598,782),(602,934),(539,926)],48,-1)]
def polygon(points):
 q=np.array([(x*sx,y*sy) for x,y in points]);x0=max(0,int(q[:,0].min()));x1=min(W,int(np.ceil(q[:,0].max()))+1);y0=max(0,int(q[:,1].min()));y1=min(H,int(np.ceil(q[:,1].max()))+1)
 yy,xx=np.mgrid[y0:y1,x0:x1];xx=xx+.5;yy=yy+.5;mask=np.zeros(xx.shape,dtype=bool)
 for i in range(len(q)):
  ax,ay=q[i];bx,by=q[(i+1)%len(q)]
  if abs(by-ay)>1e-6:mask^=((ay>yy)!=(by>yy))&(xx<(bx-ax)*(yy-ay)/(by-ay)+ax)
 return (x0,y0,x1,y1),mask
def image(name,data):
 h,w=data.shape[:2];im=bpy.data.images.new(name,width=w,height=h,alpha=True)
 im.pixels.foreach_set(np.ascontiguousarray(data[::-1]).ravel());im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();return im
def mask_image(name,m):
 a=np.ones((*m.shape,4),np.float32);a[:,:,:3]=m[:,:,None];return image(name,a)
all_windows=np.zeros((H,W),np.float32);all_doors=np.zeros((H,W),np.float32);layers={}
for name,points in windows:
 box,poly=polygon(points);x0,y0,x1,y1=box;crop=src[y0:y1,x0:x1].copy();r,g,b=crop[:,:,0],crop[:,:,1],crop[:,:,2]
 blue=(g>r*1.12)&(b>r*1.15)&(g>.12)&(b>.12)
 alpha=(poly&blue).astype(np.float32);crop[:,:,3]=alpha;all_windows[y0:y1,x0:x1]=np.maximum(all_windows[y0:y1,x0:x1],alpha)
 layers[name]=(box,image(name,crop),mask_image(name+'_mask',alpha))
for name,points,start,direction in doors:
 box,poly=polygon(points);x0,y0,x1,y1=box;all_doors[y0:y1,x0:x1]=np.maximum(all_doors[y0:y1,x0:x1],poly.astype(np.float32))
mask_image('windows_mask',all_windows);mask_image('doors_mask',all_doors)
cut=src.copy();cut[:,:,3]=1-np.maximum(all_windows,all_doors);back=image('street_with_cutouts',cut);del cut
def material(name,im=None,color=(.1,.08,.07,1),shine=False):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear();l=m.node_tree.links
 out=n.new('ShaderNodeOutputMaterial');emit=n.new('ShaderNodeEmission');emit.inputs['Color'].default_value=color
 trans=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader');l.new(trans.outputs[0],mix.inputs[1]);l.new(emit.outputs[0],mix.inputs[2]);mix.inputs[0].default_value=1;l.new(mix.outputs[0],out.inputs[0])
 if im:
  tex=n.new('ShaderNodeTexImage');tex.image=im;l.new(tex.outputs['Color'],emit.inputs['Color']);l.new(tex.outputs['Alpha'],mix.inputs[0])
  if shine:
   uv=n.new('ShaderNodeTexCoord');sep=n.new('ShaderNodeSeparateXYZ');l.new(uv.outputs['UV'],sep.inputs[0])
   mul=n.new('ShaderNodeMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=.4;l.new(sep.outputs['Y'],mul.inputs[0])
   add=n.new('ShaderNodeMath');add.operation='ADD';l.new(sep.outputs['X'],add.inputs[0]);l.new(mul.outputs[0],add.inputs[1])
   shift=n.new('ShaderNodeMath');shift.operation='SUBTRACT';l.new(add.outputs[0],shift.inputs[0])
   for frame,offset in [(1,-.25),(240,1.75)]:shift.inputs[1].default_value=offset;shift.inputs[1].keyframe_insert('default_value',frame=frame)
   absolute=n.new('ShaderNodeMath');absolute.operation='ABSOLUTE';l.new(shift.outputs[0],absolute.inputs[0])
   ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.035;ramp.color_ramp.elements[0].color=(.7,.7,.7,1);ramp.color_ramp.elements[1].position=.12;ramp.color_ramp.elements[1].color=(0,0,0,1);l.new(absolute.outputs[0],ramp.inputs[0])
   tint=n.new('ShaderNodeMixRGB');tint.blend_type='SCREEN';tint.inputs[2].default_value=(.8,.96,1,1);l.new(ramp.outputs['Color'],tint.inputs[0]);l.new(tex.outputs['Color'],tint.inputs[1]);l.new(tint.outputs[0],emit.inputs['Color'])
 m.surface_render_method='DITHERED';return m
def pos(x,y,z=0):return ((x-1024)/100,(576.5-y)/100,z)
def mesh(name,points,mat,depth=0):
 ob=bpy.data.objects.new(name,bpy.data.meshes.new(name));scene.collection.objects.link(ob)
 ob.data.from_pydata([pos(x,y,depth) for x,y in points],[],[tuple(reversed(range(len(points))))]);ob.data.materials.append(mat);uv=ob.data.uv_layers.new()
 for loop in ob.data.loops:
  x,y=points[loop.vertex_index];uv.data[loop.index].uv=(x/2048,1-y/1153)
 return ob
def crop_uv(ob,points,box):
 x0,y0,x1,y1=box
 for loop in ob.data.loops:
  x,y=points[loop.vertex_index];ob.data.uv_layers[0].data[loop.index].uv=((x*sx-x0)/(x1-x0),1-(y*sy-y0)/(y1-y0))
mesh('STREET — alpha-cut background',[(0,0),(2048,0),(2048,1153),(0,1153)],material('Street paint — windows and doors removed',back))
hinges={};dark=material('Interior warm shadow',color=(.028,.043,.045,1));edge=material('Door painted timber edge',color=(.28,.19,.095,1))
for name,points,start,direction in doors:
 box,poly=polygon(points);x0,y0,x1,y1=box;crop=src[y0:y1,x0:x1].copy();crop[:,:,3]=poly.astype(float)*(1-all_windows[y0:y1,x0:x1]);im=image(name,crop)
 hinge=bpy.data.objects.new(name+'_HINGE',None);scene.collection.objects.link(hinge);hinge.location=pos(*points[0],.025);hinges[name]=hinge;bpy.context.view_layer.update()
 door=mesh(name,points,material(name+'_paint',im),.025);crop_uv(door,points,box);door.parent=hinge;door.matrix_parent_inverse=hinge.matrix_world.inverted()
 door.data.materials.append(edge);solid=door.modifiers.new('Solid timber thickness','SOLIDIFY');solid.thickness=.045;solid.material_offset=1;solid.material_offset_rim=1
 for frame,angle in [(1,0),(start,0),(start+42,math.radians(78)*direction),(start+86,math.radians(78)*direction),(start+130,0),(240,0)]:
  hinge.rotation_euler.y=angle;hinge.keyframe_insert('rotation_euler',frame=frame)
 mesh(name+'_Interior_Back',points,dark,-.42)
 for i in range(4):
  a=points[i];b=points[(i+1)%4];ob=bpy.data.objects.new(name+'_Jamb_'+str(i),bpy.data.meshes.new('Jamb'));scene.collection.objects.link(ob)
  ob.data.from_pydata([pos(*a,-.015),pos(*b,-.015),pos(*b,-.42),pos(*a,-.42)],[],[(0,1,2,3)]);ob.data.materials.append(edge)
scene.frame_set(1);bpy.context.view_layer.update()
for name,(box,im,mask) in layers.items():
 x0,y0,x1,y1=box;points=[(x0/sx,y0/sy),(x1/sx,y0/sy),(x1/sx,y1/sy),(x0/sx,y1/sy)]
 ob=mesh(name+'_GLASS',points,material(name+'_animated_shine',im,shine=True),.028);crop_uv(ob,points,box);ob['mask_file']=mask.filepath_raw
 if name=='Poodle_Door_Glass':
  hinge=hinges['Old_Poodle_Door'];ob.parent=hinge;ob.matrix_parent_inverse=hinge.matrix_world.inverted()
scene.frame_start=1;scene.frame_end=240;scene.render.fps=30;scene.render.engine='CYCLES';scene.cycles.samples=12
camera=bpy.data.objects.new('CAMERA — full street',bpy.data.cameras.new('Street orthographic'));scene.collection.objects.link(camera);camera.location=(0,0,30);camera.data.type='ORTHO';camera.data.ortho_scale=20.48;scene.camera=camera
scene.render.resolution_x=2048;scene.render.resolution_y=1153;scene.render.resolution_percentage=75;scene.view_settings.view_transform='Standard';scene.render.image_settings.file_format='PNG';scene.render.film_transparent=True
scene['instructions']='Space plays the 8 second doors and window-shine animation. Frame 1 closed; frame 90 open. GLASS objects have matching PNG masks. Original game texture remains unchanged.'
for name,frame in [('CLOSED',1),('POODLE OPENS',20),('MARKET OPENS',48),('BOTH OPEN',90),('CLOSING',140),('CLOSED LOOP',240)]:scene.timeline_markers.new(name,frame=frame)
scene.frame_set(90)
for im in bpy.data.images:
 try:im.pack()
 except:pass
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Mill_Market_Animated_Doors.blend'))
scene.render.filepath=str(OUT/'doors_open_preview.png');bpy.ops.render.render(write_still=True)
scene.frame_set(1);scene.render.filepath=str(OUT/'doors_closed_preview.png');bpy.ops.render.render(write_still=True)
(OUT/'manifest.json').write_text(json.dumps({'source':'assets/backgrounds/mill1.png','resolution':[W,H],'window_groups':len(windows),'doors':[d[0] for d in doors],'frames':240,'fps':30,'window_mask_pixels':int((all_windows>0).sum()),'door_mask_pixels':int((all_doors>0).sum())},indent=2))
print('STREET_CUTOUTS_DONE',flush=True)
