# Burger Character Creator

This folder is a standalone Godot project. Open `project.godot` directly to
work on the creator without loading Food Truck Flip.

The Windows export is configured as **Windows Character Creator** and builds
to `../build/BurgerCharacterCreator.exe`.

Current features:

- the same chunky Kenney rig used by the game's current toon customers;
- texture-free adjustable skin color;
- black flattened-sphere eyes with independent width, height, spacing, vertical-position, and face-depth controls;
- paired white eye highlights with size, left/right, up/down, and face-depth controls;
- independent left-eye and right-eye yaw controls, with each highlight attached to its eye;
- optional three-tube eyelashes on each eye with color, scale, length, thickness, height, spacing, depth, fan-angle, and independent yaw controls;
- optional radial-gradient rosy cheeks with color/alpha, scale, width, height, vertical position, spacing, and face-depth controls;
- straight, arched, angry, and worried/shocked eyebrow styles with customizable color, scale, width, thickness, height, spacing, face depth, and independent left/right yaw;
- none/button/point noses with independent width, height, vertical-position, face-depth, and color controls (red by default);
- half-circle, flat, and open modular mouths with width, height, vertical-position, face-depth, and color controls;
- paired cylinder ears with scale, spacing, face-depth, and color controls;
- fifteen selectable hair/facial-hair choices, including eleven newly sourced CC0 pieces, with scalable and positionable hair;
- six sourced CC0 hats/hoods plus procedural top-hat and baseball-cap choices;
- procedural top hat and baseball cap;
- scalable and positionable hats/headwear;
- separate exact-weight Tops, Bottoms, and Shoes sections with independent colors and fit controls;
- T-shirt, tank top, long-sleeve shirt, pants, and shorts choices;
- ten colorable, scalable, and positionable CC-BY T-shirt graphics: skull, heart, star, lightning, flame, flower, cat, moon, burger, and crown;
- sneakers, ankle boots, high tops, loafers, and sandals generated from the original Kenney skin weights;
- orbit, middle-mouse pan, and zoom preview camera;
- corrected parent-space Wave, Walk in Place, and Celebrate skeleton previews that preserve bone lengths and avoid imported-axis twisting;
- a 15-control manual pose rig for head, spine, both arms, elbows, legs, and knees, with pose reset and saved-preset support;
- named JSON character presets saved under the app's `user://characters`;
- named customer designs with automatically captured portrait thumbnails and clickable saved-customer cards;
- module slots ready for clothes and accessories.

The base mesh is Kenney Animated Characters Protagonists, CC0 1.0. The
original license is included in `assets/base/LICENSE-KENNEY-CC0.txt`.

Hair and hats come from Quaternius, João Baltieri's Cartoon Capsule Pack Lite,
and Damin De Silva's Low Poly Male and Female Models. These 3D packs are CC0.
T-shirt graphics come from Game-Icons.net under CC BY 3.0. Full source links,
authors, adaptations, and attribution are recorded in `assets/ASSET_LICENSES.md`.
The Tops, Bottoms, and Shoes menus generate exact-weight modules from the Kenney body's own skinned mesh. Their vertices retain the original Skin bind indices and weights, so shirts, shorts, pants, and all five footwear styles deform with the same skeleton and animations.

## Rig and wardrobe update

- Draggable 3D hand and foot IK targets now pose the character directly in the preview. Reach and elbow/knee bend limits are enforced, while all precision sliders remain available.
- Pose and preview-animation rotations are converted from visible world axes through skeleton space into each bone parent's rest space, fixing the imported Z-up/mirrored-axis raise-versus-forward swap.
- The wardrobe now contains eleven tops and seven bottoms, including crop top, blouse, hoodie, sweater, off-shoulder top, cardigan, leggings, capris, and three skirt styles. Every option is derived from the current body mesh and keeps its exact Skin bind indices and weights.
- Ten CC0 iPoly3D glasses/sunglasses, four makeup styles, and four jewelry styles have dedicated sections with color, scale, and 3-axis placement controls.
- Hats have pitch/yaw/roll controls; sourced low-poly hats and glasses rebuild smooth normals where topology permits.
- Cheek and T-shirt graphic depth ranges are widened so both can be pulled flush to the face or garment.
