"""Run with Blender --background --python convert.py from the project root."""
from pathlib import Path
import bpy
from mathutils import Vector, Matrix
import json
import math

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).resolve().parent
OUTPUT = ROOT / 'models/burgerpack/try2'

def clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

def bounds(objects):
    points = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
    return [min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)]

report = {}
# One shared uniform scale preserves the supplied halves' relative proportions.
MODEL_SCALE = .18 / 1.511281132698059
for part, filename in [('bottom','bun_bot.fbx'),('top','bun_top.fbx')]:
    target = OUTPUT / ('SM_BurgerBunUntoasted' + part.title() + '.glb')
    clear()
    bpy.ops.import_scene.fbx(filepath=str(SOURCE / filename))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for obj in bpy.context.scene.objects:
        obj.animation_data_clear()
    # FBX object transforms are a tilted presentation pose, not the bun's axes.
    # The mesh itself is upright; discard the pose rather than baking it in.
    for obj in meshes:
        obj.parent = None
        obj.matrix_world = Matrix.Identity(4)
        if part == 'bottom':
            # Bottom half rests on its crust, with the cut face toward the top half.
            obj.data.transform(Matrix.Rotation(math.pi, 4, 'X'))
    bpy.context.view_layer.update()
    low, high = bounds(meshes)
    report[part] = {'source_bounds':[low,high], 'objects':[o.name for o in meshes], 'uniform_scale':MODEL_SCALE}
    material = bpy.data.materials.new('Supplied_Bun_' + part)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value = .8
    color = nodes.new('ShaderNodeTexImage')
    color.image = bpy.data.images.load(str(SOURCE / 'hamburger_bun_bun_BColor.png'), check_existing=True)
    links.new(color.outputs['Color'], bsdf.inputs['Base Color'])
    normal = nodes.new('ShaderNodeTexImage')
    normal.image = bpy.data.images.load(str(SOURCE / 'hamburger_bun_bun_Normal.png'), check_existing=True)
    normal.image.colorspace_settings.name = 'Non-Color'
    normal_map = nodes.new('ShaderNodeNormalMap')
    normal_map.inputs['Strength'].default_value = .55
    links.new(normal.outputs['Color'], normal_map.inputs['Color'])
    links.new(normal_map.outputs['Normal'], bsdf.inputs['Normal'])
    for obj in meshes:
        center = Vector((.5*(low[0]+high[0]), .5*(low[1]+high[1]), low[2]))
        for vertex in obj.data.vertices:
            vertex.co = (vertex.co-center)*MODEL_SCALE
        obj.data.materials.clear()
        obj.data.materials.append(material)
        for polygon in obj.data.polygons:
            polygon.material_index = 0
            polygon.use_smooth = True
        obj.name = 'Bun_' + part
        obj.data.update()
    bpy.context.view_layer.update()
    fitted_min, fitted_max = bounds(meshes)
    assert abs(fitted_min[2]) < 1e-5
    assert all(abs((fitted_max[i]-fitted_min[i])-(high[i]-low[i])*MODEL_SCALE) < 1e-5 for i in range(3)), 'Nonuniform bun scaling'
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes: obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB', use_selection=True, export_animations=False, export_yup=True)
    report[part]['export_bounds'] = bounds(meshes)
    assert abs(report[part]['export_bounds'][0][2]) < 1e-5
print('BUN_BOUNDS ' + json.dumps(report))
