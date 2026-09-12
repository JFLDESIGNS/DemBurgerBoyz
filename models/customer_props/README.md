# Refined customer props — 30 assets

All 30 props were enlarged 2x. The final requested adjustments are applied on top: umbrella 25% smaller with a rounder dome; skateboard 20% smaller overall and 45% wider across the deck before the overall reduction; shopping bag 20% smaller; both phones black and 15% larger. Geometry and GripPoint positions are baked into the individual GLB exports.

Updated shapes: deeper scalloped umbrella canopy, folded/gusseted shopping bag, seven tulips with shaped petals, smooth orange basketball with black panel seams, rounded concave skateboard with kicked ends. Slot 20 is now a black cell phone; glasses are removed. Stronger saturated materials throughout.

## Blender preview scenes
- CHARACTER PREVIEWS | Refined six: the six revised props on copies of the supplied characterMedium model.
- CHARACTER PREVIEWS | All 30: one character fit example for every prop.
- CUSTOMER PROPS | 30: labeled prop-only catalog; display sizes are normalized.

The supplied character uses the game's CHAR_SCALE = 0.552 from scripts/customer.gd. The imported FBX skin alpha was restored from zero to one in the preview only, so the model is visible. Original FBX is unchanged. Held props are attached to the RightHand bone and aligned with their grip markers; the backpack is shown worn. These are editable example poses, not animation integration.

## Files
- customer_props.blend: models, material palette, posed character previews.
- glb/: exactly 30 individual prop assets, one mesh each, with embedded solid-color PBR materials and a GripPoint child.
- customer_props_preview.png: prop catalog.
- refined_character_preview.png: revised six on the supplied model.
- all_30_character_preview.png: all 30 on the supplied model.
- manifest.json / validation.json: dimensions, grip positions, triangle counts, export checks.
- build_customer_props.py then build_character_previews.py: rebuild geometry/exports/catalog and then character previews.
- before_refinement/: prior version.

GLBs are Y-up, in meter units at the requested oversized game scale. Blender is Z-up. Root transforms are identity; import at scale 1. For hand attachment, align GripPoint to the desired hand contact and adjust orientation for the character animation. No textures, animation, collision shapes, or customer behavior changes are included.

## Included assets

- 01 Open Umbrella — 8,460 triangles
- 02 Folded Umbrella — 472 triangles
- 03 Roller Suitcase — 1,408 triangles
- 04 Briefcase — 852 triangles
- 05 Handbag — 844 triangles
- 06 Shopping Bag — 1,046 triangles
- 07 Backpack — 920 triangles
- 08 Duffel Bag — 1,088 triangles
- 09 Gift Box — 880 triangles
- 10 Parcel — 480 triangles
- 11 Smartphone — 876 triangles
- 12 Tablet — 588 triangles
- 13 Headphones — 1,056 triangles
- 14 Camera — 764 triangles
- 15 Book — 840 triangles
- 16 Notebook Pen — 1,612 triangles
- 17 Newspaper — 752 triangles
- 18 Wallet — 588 triangles
- 19 Keys — 1,156 triangles
- 20 Cell Phone — 2,228 triangles
- 21 Water Bottle — 492 triangles
- 22 Thermos — 492 triangles
- 23 Flower Bouquet — 5,616 triangles
- 24 Basketball — 2,368 triangles
- 25 Skateboard — 2,624 triangles
- 26 Walking Cane — 508 triangles
- 27 Takeaway Coffee — 684 triangles
- 28 Soda Cup — 552 triangles
- 29 Takeaway Bag — 496 triangles
- 30 Burger Box — 648 triangles
