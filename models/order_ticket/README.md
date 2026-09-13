# Flexible order ticket

Open `source/order_ticket.blend` in Blender. Press Space to play the marked timeline; it demonstrates all seven states. The second scene, `Ticket | state contact sheet`, contains the presentation. The asset scene contains the editable mesh, rig, packed image, camera, and lighting. Only the paper mesh and rig are in the exported GLB.

## Files

- `order_ticket.glb`: self-contained game asset, embedded artwork and seven skeletal clips.
- `order_ticket.tscn`: reusable Godot 4 scene with click/touch interaction and state controller.
- `order_ticket.gd`: controller with public methods below.
- `source/order_ticket.blend`: editable Blender source. This source directory has `.gdignore` to avoid importing duplicate Blender assets and preview files into Godot.
- `textures/ticket_albedo.png`: printed front / clean reverse atlas.
- `textures/ticket_blank.png`: blank front and reverse atlas.
- `source/ticket_design.json`: editable order number, five ingredient lines, footer, and bar fill.
- `source/make_texture.py`: regenerate artwork with Python + Pillow using the project's Caveat font.
- `source/build_ticket.py`: rebuild Blender source, GLB, and previews using Blender 5.1.
- `asset_manifest.json` and `source/validation.json`: dimensions, clips, counts, and export checks.

## Animation states

| Clip | Duration | Use |
| --- | --- | --- |
| static | 1.0 s, loop | Gentle natural paper shape, no motion |
| roll | 1.2 s | Roll upward into a spiral, then transition to rolled |
| rolled | 1.0 s, loop | Hold the curled pose |
| unroll | 1.2 s | Return to the flat resting shape |
| shake | 0.8 s | Short attention shake; settles to rest |
| wave | 2.4 s, loop | Soft continuous breeze with bend and twist |
| tap | 0.7 s | Quick deflection with damped settling |

Loop flags are configured by the Godot wrapper. glTF stores the animation curves but does not standardize a loop flag. If using the GLB directly, enable looping on static, rolled, and wave in your engine.

## Godot usage

Drag `order_ticket.tscn` into a 3D scene. The origin is at the top center, with the paper extending downward. The printed side faces local +Z. Authoring size is 18 x 28 cm; scale the scene root to suit your game.

```gdscript
$OrderTicket.tap()
$OrderTicket.shake()
$OrderTicket.set_wind(true)        # Returns to wind after tap/shake
$OrderTicket.set_wind(true, 0.7)   # Slower animation playback
$OrderTicket.roll_up()            # Automatically holds in rolled
$OrderTicket.unroll()             # From rolled back to idle/wind
$OrderTicket.set_state(&"static")
$OrderTicket.set_ticket_texture(load("res://models/order_ticket/textures/ticket_blank.png"))
```

A left mouse click or touch triggers tap when camera/viewport physics picking is enabled. `TapArea` is a fixed interaction box covering the unrolled ticket, not a deformed paper collider. It does not collide as a solid body. Change its collision layer to match your game's picking setup. Turn off `interactable` to disable picking. The wrapper avoids tap/shake interrupts while the ticket is rolling or rolled. `set_state` is the unrestricted low-level API; use `roll_up` / `unroll` for normal fold transitions. `set_wind`'s speed scales all clips on that ticket, not only the breeze. If replacing a texture before `_ready`, defer the call until the scene has entered the tree.

## Custom artwork and rig

UVs: front is the LEFT half of the 2048 x 2048 atlas; reverse is the RIGHT half. Each half maps the complete paper surface. All artwork deforms with the same skin, so there are no floating text objects. The number and ingredients in this example are texture artwork, not live game labels. Replace the atlas through `set_ticket_texture`, draw your own dynamic atlas, or edit the JSON and regenerate. Keep a narrow perimeter margin so text never falls into the side-wall UV seam.

The ticket uses one mesh, one material, 3,208 triangles, 24 deform bones, one anchor bone, and at most two skin weights per vertex. There are no cloth caches, constraints, shape keys, or runtime subdivision requirements. The rig's local X rotations bend the paper; local Y rotations twist it; local Z rotations sway it sideways. The anchor moves the entire ticket. Use additive animation or engine bone overrides for directional wind and stronger/weaker motion. The current wave is a baked gentle breeze; this is not a cloth-physics simulation.

In Blender, the `PREVIEW | play timeline` NLA track plays the full sequence. Mute it before enabling a single named state track. Each state also exists as an Action. Cameras, lights, and contact-sheet meshes are excluded from export. Rebuild via the script to export only the seven state tracks rather than the preview sequence.

## Rebuild

From the project root:

```powershell
python models/order_ticket/source/make_texture.py
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --factory-startup --python models/order_ticket/source/build_ticket.py
python models/order_ticket/source/validate_glb.py
```

The generator replaces its own output files. Edit a copy of the Blender source if you want to preserve manual changes across a rebuild. Nothing in the existing game scenes is automatically replaced by this package.

## Food Flip main-ticket integration

The main game's selected order now uses `scripts/animated_order_ticket.gd` and `shaders/order_ticket_live.gdshader`. Existing live UI controls supply the paper's text, checkmarks, patience meter, timer, and challenge quantity. New/promoted main tickets unroll; tapping reacts; half-strength intermittent breeze follows a 9–18 second quiet interval. Waiting tickets remain static. The integration uses a 45% wave-strength copy, one active print viewport, and one active 3D viewport. Demoted renderers are disabled.

Regression coverage lives in `tests/main_ticket_animation_smoke.gd` and `tests/main_ticket_harness.gd`. `tools/build_ticket_release.py` builds, validates, backs up, and installs the executable. See `build/ticket_release/CHECKPOINT.md` for the current release checkpoint.


### Main-ticket arrival sequence

In Food Flip, a selected main ticket flies in from the lower left while rolled (0.55 seconds), unrolls at its final slot (1.2 seconds), then receives `models/thumbtack/thumbtack_red.glb` at its top edge (0.48 seconds). The pin stays seated during taps and breeze motion. Input during any arrival phase queues a tap until placement finishes. The sequence cancels safely when an order is removed or demoted. Queued tickets keep their existing static presentation.


### Refined main-ticket interactions (September 13)

- Click an open ticket: paper tap, with a short CC0 paper-contact recording.
- Grab either bottom corner and pull: shake plus paper rustle; release is captured even outside the ticket.
- Double-click: roll up and hold. Click the rolled ticket to reopen without replaying pin placement.
- No elapsed-time action retracts, folds, or reopens a ticket. Occasional breeze only moves an open ticket.
- The red pin is now 3.6 scale (twice the previous 1.8), angled more strongly, with a swoop, rotation, quick press, and spring settle over 0.76 seconds.
- Main-ticket header clearance is 8 px, with a 5 px top content inset. Waiting tickets retain their original layout.
- Real diffuse lighting, soft directional shadows, a slight turn of the rolled paper, separate front/back/rim normals, and disabled thin-mesh LODs make the curl readable and remove bright edge artifacts.

Paper audio credits: `sounds/ticket/CREDITS.md`, sourced from Luckius's CC0 Various Paper Sound Effects on OpenGameArt.

Open-paper lighting refinement: the live ticket uses even, unlit paper color in static, tap, shake, wave and pinned states. Studio lighting fades in only while rolling/unrolling and remains on the fully rolled tube. The thumbtack retains its own 3D lighting.
