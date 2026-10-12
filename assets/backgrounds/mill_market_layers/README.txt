MILL MARKET LAYERED GODOT ASSET

Instance res://scenes/mill_market_layers.tscn. The asset faces +Z and is 20.48 x 11.53 world units.
Integrated in Burger Pals whenever the Mill Market (mill1) background is selected, including the shipped first-location default. Location changes restore other backgrounds normally.

Call after ready:
  street.open_door("old_poodle")
  street.close_door("motel")
  street.open_door() # both
Or call DoorAnimations.play("old_poodle_open"), "old_poodle_close", "motel_open", "motel_close", "both_open", "both_close".
Both hinges are on the left, opening outward 110 degrees over 0.85 seconds.
The AnimationPlayer is created by the scene script at runtime. One animation can control both doors together.

WalkerLayer is at z=0.35; CanopyForeground is z=0.65. Add walkers under WalkerLayer or place them between z=0.15 and 0.55 to let the awning occlude them.
The canopy has a separate alpha texture, grayscale mask, and a painted backing layer.

upper_glass.png: upstairs glass, animated cloud shader applied only here.
street_glass.png: brighter warm lower-window gradient. Door glazing is in street_doors.glb.
upper_windows_mask.png / street_windows_mask.png / doors_mask.png: full 4778x2689 masks, white means selected.
Each window also has a cropped mask; layers.json supplies its full-image pixel rectangle.
market_canopy.png and street_base_cutout.png align to the same full-image origin.
Cloud reflection opacity and speed are exposed on the shader material.

Blender source: models/mill_market_cutouts/Mill_Market_Animated_Doors.blend
Export script: models/mill_market_cutouts/export_godot_layers.py

Game API: get_street_effect_mask("windows"), "upper_windows", "street_windows", "doors", or "canopy" returns a Texture2D.
Game API: play_street_door_animation("both_open") or any of the six animation names above.
In the game the canopy is projected ahead of the existing walker lane while preserving its exact screen alignment.

Occasional host-controlled walkers enter and leave the two buildings. Multiplayer snapshots synchronize doorway travel, visibility, facing, and door poses.
All scenery layers have shadow casting disabled to avoid rectangular shadows over the painted street.
The warm gradient is limited to the bottom 38 percent of street-level glass, with a darker amber base.
