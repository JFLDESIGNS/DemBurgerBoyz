# Current editable source

**Game integration completed:** the later user save now has a separate 20,078-triangle runtime export at `assets/mail_truck/mail_truck.glb`, with optimized source `mail_star_truck_game.blend`. See `assets/mail_truck/README.md`. The notes below record the preceding cab-editing pass; the editable master remains separate from the game export.

Start the next pass from `mail_star_truck_editable_parts.blend`. `mail_star_truck.blend` contains the same scene. The user's saved edits before the cab refinement are preserved in `user_edits_before_cab_refine.blend`.

This source has 237 vehicle meshes and 67,033 base-mesh triangles. The existing GLB and its export statistics predate the user's edits and this refinement.

## Cab refinement

- Each mirror is a connected mounting shoe, bent support and housing mesh, plus separate glass: `Mirror_L_Assembly`, `Mirror_L_Glass`, `Mirror_R_Assembly`, `Mirror_R_Glass`. Assembly origins sit at their mounts; the glass follows its assembly.
- `Cab_Grab_Handle_L` and `Cab_Grab_Handle_R` each contain a continuous bent handle and connected mounting feet.
- `Pedal_Brake` and `Pedal_Accelerator` have rubber pads, raised tread and support hardware. The brake mounts to the sloped inner cowl below the dashboard; the accelerator mounts to the floor. Both pads sit in the usable footwell behind the cowl.
- New parts have UVs, cleaned normals, applied scale and descriptive names. The body, cab, trim and wheel collections remain editable.
- The refinement preserves 230 other meshes, including the studio floor. Four tire centers are checked against their wheel pivots. See `cab_refinement_validation.json`.

## Next game-model pass

1. Work on a duplicate of this source; retain this editable master. Do not regenerate from the original truck builder because it does not include the user's subsequent edits.
2. Finish UVs on the 25 meshes listed in `cab_refinement_validation.json`; consolidate material slots or atlas textures as appropriate.
3. Create an export copy with final triangulation and reviewed normals; optimize hidden geometry and small detail according to the target budget. Check evaluated triangle count after modifiers.
4. Keep wheels separate with their existing axle pivots; combine stationary components for fewer draw calls. Retain separate transparent glass and any intended moving controls.
5. Create simple collision and optional LODs, exclude the studio, export GLB, and verify size, glass, normals and wheel transforms in Godot.

No final game export, collision or LODs have been produced in this cab-editing pass.
