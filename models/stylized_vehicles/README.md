# Sugar Street vehicles — Food Truck Flip

Open Sugar_Street_Vehicles.blend. Press Space over the 3D viewport to play the driving loop: frames 1–48 at 24 fps. Frame 49 matches the loop start. Each vehicle has four independently animated wheels, a subtle suspension bounce/lean, and four recessed charcoal wheel-well liners attached to its body. The vehicle ROOT remains still so the game owns travel distance.

Each numbered collection contains one ROOT, one body, four wheels, and four well liners. Blender coordinates are meters, +Z up and +X forward. Wheel axles are local Y. The glTF exporter converts to Godot's +Y-up coordinates; wheel rotation becomes local -Z.

Game exports are in assets/vehicles/sugar_street, with DriveLoop stored in each GLB. The clip is exactly two seconds, rolls four turns, and starts at time zero. scripts/street_vehicle.gd synchronizes playback with road speed and model scale. scripts/game.gd uses all seven models in the existing occasional-traffic lane, preserving spacing, sounds, pause behavior, and tuning controls. The former 2D cars and smear sprites are no longer spawned.

Current complexity: 2,473–2,754 mesh polygons / 5,298–5,524 triangles per vehicle including the recessed wells. Materials use portable opaque Principled BSDF colors and roughness/metallic values. No external image textures are needed. Windows are opaque blue glass. Studio objects never enter the GLB exports.

To re-export edits, run export_animated_vehicles.py in Blender. The original model rebuild and add_wells_and_animation.py scripts are optional construction utilities; use the saved .blend for normal editing. .gdignore keeps Blender source files, studio objects, and backups out of automatic Godot imports.

Validation: tests/street_vehicles_smoke.gd checks all seven imports, four wheels and four wells per model, scale and ground origin, wheel direction/speed, suspension, loop continuity, and the actual game's spawn/pause/despawn lifecycle.
