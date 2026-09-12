# Food Truck Flip hats

Ten refined hats from `assets/hats/hat_collection.blend`, fitted to the supplied
`characterMedium.fbx`. The standalone creator project is not changed.

`scripts/modular_character_base.gd` owns the catalog. Each GLB contains only one
hat's grouped mesh parts, with original materials, baked modifiers, and a shared
head-bone origin. The baseball bill and crown share a welded mesh edge.

Geometry includes the creator's 0.7 body scale and head-rest orientation. Attach
with `_unit * hat_scale`, plus the user's offset and rotation; do not normalize by
the brim's bounding box. White tint preserves the original colors.

Catalog version 2 maps retired hats to replacement styles and discards their
incompatible fitting transforms. New saved designs and accessory fits carry the
catalog version. Every new hat has a built-in default fit.

Re-export from the Blender file with `tools/export_refined_hats.py`. Run
`tests/refined_hats_smoke.gd` with Godot to check the catalog, materials, transforms,
selection, tint isolation, saved presets, and the integrated creator UI.
