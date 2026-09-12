# Burger Pals menu truck

`burger_pals_truck.glb` is the game export of `assets/truck3d/burger_pals_truck_optimized.blend`.
It contains the complete truck and the authored 180-frame, 30 fps approach, partial
donut, slide recovery, and accelerating exit. The body, burger sign, pennants, and
four axles retain their separate animation controls. Rigid geometry is combined
per animated assembly. Blender-only procedural shading is reduced to the material
palette; the Blender source is unchanged.

Godot uses +X forward, +Y up, and +Z toward the serving side. The root's Z scale of
1.15 preserves the requested extra side-to-side width. Forward wheel spin is -Z.

`scripts/truck_cinematic.gd` presents this asset in an isolated viewport. The menu
poses the truck at the origin and accelerates it out when a shift starts. The
loading view plays the Blender motion with camera cuts, runtime tire smoke, and
skid marks. Both viewports stop rendering when hidden. The existing first-shift
resource preload and minimum loading duration are retained.

Re-export with Blender 5.1 in background mode and `tools/export_menu_truck.py`.
Verify with `tests/truck_cinematic_smoke.gd` and `tests/startup_loading_smoke.gd`.

Polygon cleanup: 903,714 to 151,676 evaluated truck triangles (83.22% reduction).
Packed image decals replace the logo, flat stars and lettering. Two paint textures carry the red band around the body and rear doors. The refined truck includes recessed sealed windows, inner wheel wells, full-height rear doors, and restored rear logo artwork. The original
truck2 Blender file remains available as the full geometry source.
