# Modular character foundation

The texture-free player foundation lives at:

`res://scenes/character_creator/modular_character_base.tscn`

It currently provides:

- the same chunky Kenney toon rig used by the game's current customers;
- a flat, runtime-adjustable skin material (`skin_color`);
- a blank face because the baked face/clothing texture is not used;
- empty module roots for hair, eyes, mouth, clothes, and accessories.
- creator-ready procedural eyes, noses, mouths, a top hat, and a baseball cap;
- CC0 Quaternius hairstyles and ranger hoods staged in `hair/` and `headwear/`.

The original FBX mesh is reused directly. Its baked texture is replaced by a
flat toon skin material, so the original face and clothing do not appear.

## Asset source

- **Pack:** Animated Characters Protagonists
- **Creator:** Kenney
- **Source:** https://kenney.nl/
- **License:** CC0 1.0 Universal

The creator's original license text is preserved at
`res://assets/characters/License-Kenney.txt`.
