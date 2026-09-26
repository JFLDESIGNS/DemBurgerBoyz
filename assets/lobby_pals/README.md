# Burger Pals street parade

Three independently importable 3D GLBs and a reusable Godot 4 scene.
Instance `res://assets/lobby_pals/street_parade.tscn` under the street and call
`start_parade("challenge")` or `start_parade("end_of_day")`.

The root position defines the street height/depth. `start_x`, `finish_x`,
`duration`, `spacing`, and `color_tint` are adjustable in the Inspector.
Default travel is right-to-left for the game's camera, which looks along +Z.
Burger leads, followed by Mustard and Ketchup. The models face the camera.

Each GLB contains `MarchLoop`: a four-second loop sampled at 12 poses/second.
The compact deformation bake preserves Blender's curved limbs, shoe rolls,
hand opening/closing, body squash/stretch, blinks and sauce without requiring
Blender hooks, constraints, armatures or external textures in Godot.
The controller changes the pose only at 12 Hz. It hides and stops processing
between passes. Repeated triggers do not restart an active march; an end-of-day
pass can queue behind a challenge pass.

This is a baked marching asset, not a retargetable humanoid skeleton. The glove
art and facial details were authored for the front/street camera angle.
Use the original film rig for creating entirely new character performances.

Separate editable Blender file:
`models/lobby_pals/godot_source/Burger_Pals_Game_Optimized.blend`.
See `asset_stats.json` for measured geometry and file sizes.

The game creates this scene with the outdoor street, starts one pass when a
challenge is accepted (including the client's active-phase transition), and
starts or queues a pass when the shift ends. Shift results remain immediately
available through “Show results” and appear automatically when the parade ends.
Starting/restarting a run or returning to the lobby clears the parade and queue.

Validation: `tests/lobby_pals_asset_smoke.gd` verifies imported morphs, all eight
glove cards per character, looping, queueing and sleeping between events.
`tests/lobby_pals_game_smoke.gd` exercises the real challenge and end-day methods,
results shortcut and repeated multiplayer state messages.
