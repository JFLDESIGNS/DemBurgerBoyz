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
TARGET_BOUNDS = {
    'bottom': ([-.085267417, -.088065624, -.0002788], [.089054488, .092354313, .039797354]),
    'top': ([-.092374131, -.088901907, -.000612535], [.093562223, .096975684, .066694915]),
}
for part, filename in [('bottom','bun_bot.fbx'),('top','bun_top.fbx')]:
    target = OUTPUT / ('SM_BurgerBunUntoasted' + part.title() + '.glb')
    clear()
    old_min, old_max = TARGET_BOUNDS[part]
    bpy.ops.import_scene.fbx(filepath=str(SOURCE / filename))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for obj in bpy.context.scene.objects:
        obj.animation_data_clear()
    # The supplied top half has its cut face upward; seat its crown upward in-game.
    if part == 'top':
        for obj in meshes:
            obj.matrix_world = Matrix.Rotation(math.pi, 4, 'X') @ obj.matrix_world
    bpy.context.view_layer.update()
    low, high = bounds(meshes)
    report[part] = {'old_bounds':[old_min,old_max], 'source_bounds':[low,high], 'objects':[o.name for o in meshes]}
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
        # Bake source placement, then fit to the existing inventory footprint and height.
        obj.data.transform(obj.matrix_world)
        obj.parent = None
        obj.matrix_world = Matrix.Identity(4)
        for vertex in obj.data.vertices:
            for axis in range(3):
                vertex.co[axis] = old_min[axis] + (vertex.co[axis]-low[axis])/(high[axis]-low[axis])*(old_max[axis]-old_min[axis])
        obj.data.materials.clear()
        obj.data.materials.append(material)
        for polygon in obj.data.polygons:
            polygon.material_index = 0
            polygon.use_smooth = True
        obj.name = 'Bun_' + part
        obj.data.update()
    bpy.context.view_layer.update()
    fitted_min, fitted_max = bounds(meshes)
    assert all(abs(fitted_min[i]-old_min[i]) < 1e-5 and abs(fitted_max[i]-old_max[i]) < 1e-5 for i in range(3)), 'Bun bounds changed'
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes: obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB', use_selection=True, export_animations=False, export_yup=True)
    report[part]['export_bounds'] = bounds(meshes)
    assert all(abs(report[part]['export_bounds'][0][i]-old_min[i]) < 1e-5 for i in range(3))
print('BUN_BOUNDS ' + json.dumps(report))
