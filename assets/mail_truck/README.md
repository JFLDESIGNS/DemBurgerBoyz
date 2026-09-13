# Delivery truck

The game model is `mail_truck.glb`: 20,078 triangles with a stationary `TruckBody` and four independently rotating wheel meshes. It uses the user's latest saved truck edits, simplified smooth surfaces, flattened badge/instrument faces, no mud flaps, and continuous roof/grille trim.

The original editable source remains `models/mail_star_truck/source/mail_star_truck_editable_parts.blend`. The exact user snapshot for this export is `user_edits_before_game_export.blend`; the optimized Blender scene is `mail_star_truck_game.blend` in that same directory.

`scripts/mail_delivery_truck.gd` implements the in-world arrival, seat exit hop, wobbling box walk, delivery, return hop and departure. Normal traffic finishes its current pass before the truck enters; new cars wait until departure. The existing stock-credit flow runs on package landing. Shift cleanup restores the normal window cat and releases the road.

Runtime model scale is 0.78 (about 5.1 m long). Parking uses the configured road height and sits behind the customers, slightly nearer than normal traffic. Wheel rotation and body bounce are separate.

Validation covers sequence phases, waiting for traffic, four wheel nodes, once-only stock credit, and cancellation cleanup. The release build also checks the packaged model and opening/loading media.
