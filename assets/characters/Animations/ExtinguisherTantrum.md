# Extinguisher tantrum

`ExtinguisherTantrum.res` is a Godot AnimationLibrary containing `Tantrum`: a
four-second, non-looping animation sampled at 30 FPS. It contains 174 bone
transform tracks and no meshes, materials, skins, images, or external resource
dependencies. Customers retain their existing appearance.

Source: `assets/character_animation/characterMedium_angry_hands_up.blend`, action
`Anger • Toon hopping tantrum`, frames 1–120. The three hops, arm throw, head shake,
and squash/stretch are baked into bone motion. `ExtinguisherTantrum.motion.json`
preserves the source rest matrices and sampled poses for rebuilding the library.

The animation targets `Root/Skeleton3D` on the existing Kenney customer rig.
Blender deformation matrices are mapped onto the game's imported rest pose,
including the FBX bone-unit conversion. Root motion is baked into the bones, so
the customer queue node, colliders, and multiplayer positions remain controlled
by gameplay code.

`customer.gd` starts the clip on the first extinguisher hit, allows subsequent
powder buildup without restarting it, and clears the pose before normal walking
resumes. Customers lacking an animation player retain the procedural fallback.

Validation: `tests/customer_extinguisher_reaction_smoke.gd` covers standard and
custom customers, each hop, repeat hits, preserved appearance, the full duration,
and the transition back to walking.
