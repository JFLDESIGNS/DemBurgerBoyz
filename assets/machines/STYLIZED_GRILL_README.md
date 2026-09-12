# Stylized grill — game asset

## Files
- stylized_grill.blend: organized editable source.
- stylized_grill.glb: optimized runtime model used by scripts/game.gd.
- export_stylized_grill.py: regenerate the GLB from the open source file.
- stylized_grill_stats.json: actual mesh, triangle, animation, and file-size results.
- stylized_grill_preview.png: latest preview (shows the existing cooking-surface reference).

## Blender organization
GRILL | Export contains Body, Splashguards, Grease drawer, Ventilation, Power control, and Feet collections.
REFERENCE | Game cooking surface contains the original-sized plate for visual context only.
STUDIO | Preview only contains the camera, lights, and floor; hidden from viewport framing and excluded from export.

The centered viewport and selected body make orbiting predictable. Numpad period frames the selected body.

## Placement and runtime contract
Units are meters. The root origin is the center of the existing cooking plane.
Blender uses Z up; GLB export converts to Godot Y up with the front facing Godot -Z.
Mount at the existing grill surface transform. The game's steel top stays at local Y +0.0225 m.
The reference cooking plate, studio, lights, and cameras are not exported.
Existing game code owns collisions, food placement, FULL/HALF/HOLD heat zones, seasoning and effects.

Keep the names PowerKnob and PowerIndicator: scripts/stylized_grill.gd finds these nodes.
PowerKnob retains its pivot, 90-degree OFF-to-ON motion, and 1.26 world scale relative to the original small dial.
Frames 1 and 16 are OFF and ON. The GLB contains Power_OFF_to_ON; the game drives the same pivot using its burner state.
The click radius scales with the knob. The amber indicator uses its own material instance in-game.

## Export
Open stylized_grill.blend, then execute export_stylized_grill.py using Blender's Text Editor or:
blender --background stylized_grill.blend --python-exit-code 1 --python export_stylized_grill.py

The exporter gathers only GRILL | Export (including child collections), evaluates bevels,
batches static geometry by material, preserves the knob and indicator, strips empty organizational
groups, and leaves the saved Blender source unchanged. The editable source remains organized.
Historical build/revision scripts are not needed for normal edits; use the saved blend as the source.

## Validation
Godot: --headless --path <project> --script res://tests/stylized_grill_smoke.gd
Checks import, mounting, absence of duplicate reference plate, control scale/position,
rotation, LED state, physical click handling, and retained cooking zones.
