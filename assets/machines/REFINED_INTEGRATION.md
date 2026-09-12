# Refined kitchen machine integration

The game now loads fryer.glb, pop_machine.glb, ice_cream_machine.glb, and the separate fryer_basket.glb from assets/machines.

- Blender master: models/kitchen_machine_studio/Burger_Pals_Kitchen_Atelier.blend.
- Regenerate the runtime GLBs with Blender's background Python runner and models/kitchen_machine_studio/export_refined_runtime.py. Export-specific parenting/material conversion does not alter the master .blend.
- Only the native asset scene is exported. Studio furniture, preview plaques, original reference models and source font meshes are excluded.
- Text uses embedded alpha-cutout atlas textures and authored ink colors. Blender materials have portable glTF PBR equivalents.
- Original station roots, world positions, tuning, ownership, multiplayer basket state and interaction logic remain in scripts/game.gd.
- The soda asset contains the original 1.88 source scale. Runtime scale is soda_station_scale / 1.88, without an additional 180-degree rotation.
- Valve_cola and Valve_ice follow the existing adjustable pour points. Stick_cola and Stick_ice provide separate lever pivots. FlavorChip nodes retain click areas, selection lights and slot-mode material hooks; lettering hides during slot mode.
- TrayAssembly retains the live cup-deck height and adjustable cup-rest Z. Cabinet/valve collision bounds match the new body, with the soda front correctly facing local -Z.
- FryerModel follows pit scale/offset; its oil anchor is (-0.17, -0.056, 0.68) in Godot coordinates. Runtime OilLiquid is a plane at the oil/cooking anchor. Bubbles, oil colors, basket potatoes, smoke, cooking, shaking, ready servings and multiplayer remain live.
- BasketModel is exported in basket-local coordinates. The game applies its original rest position, tilt and basket scale once. The food stack and dunk depth fit the shallow basin without the old below-floor plunge.
- SoftServeModel preserves the original spout anchor. The handle pivot animates with stream start/stop. Runtime waffle cones, cone rack/grab target, stream, droplets, fill ghosts and lamps remain. No decorative topper is added.
- The old snapshot exporter now writes to models/kitchen_machine_studio/runtime_snapshots so it cannot overwrite the approved runtime assets.
- The existing export preset includes the machine GLBs for its raw-file loader fallback.

No game execution, test suite, executable build or packaging was performed, as requested.
