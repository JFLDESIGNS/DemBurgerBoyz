# Baron Brat background character

`baron_brat_bg.glb` contains the character, local ground and 14 animations, including `slump` and `revive`. Import as a scene in Godot. Use `idle_sway`, `idle_wave` or `idle_bounce` on the AnimationPlayer.

Current Blender source: `models/hotdog_villains/Baron_Brat_Replacement_Body.blend`. The body uses the supplied HotDog.fbx and painted textures, with a slightly wider sausage fitted to the original face. The original arms, gloves, crown, facial controls, ground, 95-bone skeleton, and all original 12 animation clips are retained. The new body uses normalized weights on the existing eight spine bones. The face sits 12 cm lower and follows the sausage surface through the animations. The character stands 18 cm higher, with the ground and fist contact heights preserved. See `face_fit_validation.json` beside the Blender file for the latest checks.

The breakout tucks both arms beside the body and turns the character 180 degrees from back-facing to front-facing in about 0.49 seconds during the rise. Mouth and eyebrow outlines are restored from the intact source geometry, with unlit facial ink to prevent faceted shading. Keep automatic mesh LOD generation disabled: the noodle arms use coincident rest-pose rings, which automatic simplification can remove. See `spin_face_repair_validation.json` for the latest entrance and face changes.

Gloves adapted from "Cartoon closed hand" by Ricardo Grillo: https://www.printables.com/model/1723392-cartoon-closed-hand . Licensed CC BY 4.0: https://creativecommons.org/licenses/by/4.0/ . Changes: decimation, rigging, scaling, posing and material changes. Retain this attribution in distributed assets/game credits.


Fake-outs use `slump` and revive with the crown attached. Final victory uses `slump_defeat`: a deeper collapse and a detached crown fall, followed by sinking in the defeated pose. The fallen crown remains at ground height throughout the sink.

`throw_hotdog` is a 1.25-second right-arm wind-up, forward release, and recovery. The game releases the held hotdog at 0.65 seconds. The projectile cooks for two powered-grill seconds before a ten-inch blast. Original synthesized throw, sizzle and pop sounds are in `sounds/boss/hotdog_*.wav`.
