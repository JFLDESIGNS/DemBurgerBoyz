"""Export the open Sugar Street Blender collection with its DriveLoop animation."""
import bpy, json, struct
from pathlib import Path
ROOT=Path(r"C:\Users\joe\Desktop\burgergame")
OUT=ROOT/"assets/vehicles/sugar_street"
OUT.mkdir(parents=True,exist_ok=True)
scene=bpy.context.scene
records=[]
vehicles=[]
for col in sorted(scene.collection.children,key=lambda c:c.name):
    roots=[o for o in col.objects if o.type=="EMPTY" and "asset_id" in o]
    if roots:
        vehicles.append((col,roots[0]))
if len(vehicles)!=7:
    raise RuntimeError("Open Sugar_Street_Vehicles.blend with all seven vehicles first.")
saved_end,saved_frame=scene.frame_end,scene.frame_current
scene.frame_end=49
try:
    for col,root in vehicles:
        original=root.location.copy()
        root.location=(0,0,0)
        scene.frame_set(1)
        bpy.ops.object.select_all(action="DESELECT")
        for ob in col.objects:
            ob.select_set(True)
        bpy.context.view_layer.objects.active=root
        path=OUT/(root["asset_id"]+".glb")
        try:
            bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",
                use_selection=True,export_yup=True,export_extras=True,
                export_animations=True,export_animation_mode="ACTIVE_ACTIONS",
                export_nla_strips_merged_animation_name="DriveLoop",
                export_frame_range=True,export_force_sampling=True,
                export_anim_slide_to_zero=True,export_optimize_animation_size=False,
                export_cameras=False,export_lights=False)
        finally:
            root.location=original
        meshes=[o for o in col.objects if o.type=="MESH"]
        for ob in meshes:
            ob.data.calc_loop_triangles()
        records.append(dict(id=root["asset_id"],file=path.name,
            triangles=sum(len(o.data.loop_triangles) for o in meshes),
            polygons=sum(len(o.data.polygons) for o in meshes),
            wheel_radius_m=root["wheel_radius_m"],
            drive_reference_speed_mps=root["drive_reference_speed_mps"],
            clip="DriveLoop",duration_seconds=2.0))
finally:
    scene.frame_end=saved_end
    scene.frame_set(saved_frame)
(OUT/"manifest.json").write_text(json.dumps(records,indent=2),encoding="utf8")
print("Exported seven animated traffic vehicles to",OUT)
