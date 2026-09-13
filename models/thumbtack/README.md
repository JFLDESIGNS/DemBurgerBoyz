# Thumbtack

Original modeled asset for Food Truck Flip: rounded molded-plastic pushpin with
a recessed underside, fine rim groove, and polished nickel-colored steel needle.
The top cap has a flat face and fine beveled rim above a compact bottom cap
whose curved flare transitions into the stem at a moderate height. The top diameter is about 69% of
the bottom cap, with a 1.65 mm steel prong.
No downloaded models or third-party textures were used.

## Files

- `thumbtack_red.glb` — main asset, 3,792 triangles, about 90 KiB.
- `thumbtack_teal.glb`, `thumbtack_yellow.glb`, `thumbtack_ivory.glb` — alternate plastic colors.
- `thumbtack_red_low.glb` — simplified 720-triangle version for small or distant props.
- `source/thumbtack.blend` — editable mesh, materials, optional low-detail meshes,
  and a separate studio preview scene.
- `source/thumbtack_preview.png` — studio render.
- `source/build_thumbtack.py` — reproducible Blender generator.
- `source/validation.json` — export measurements and geometry counts.

## Godot placement

Drag a GLB into a 3D scene. Each contains only the plastic head and steel pin,
with two PBR materials, smooth normals, and UVs. No textures are required.

Assets use meters: 20.64 mm overall height, 9 mm bottom cap diameter,
6.2 mm top cap diameter, and 10.2 mm exposed needle with a 1.65 mm shaft diameter.
Increase the instance scale for oversized game props.
The origin sits at the mounting surface: the head extends along local +Y and
the needle points along local -Y in Godot/glTF. Blender uses +Z/-Z instead.
For a bulletin board, point the head axis out from the board surface.

Plastic and steel are separate named mesh parts, so colors can be overridden
without recoloring the needle. Steel looks best with an environment or reflection
probe. The low-detail GLB is a separate asset, not an automatically linked LOD.
Collision and gameplay behaviors are not included.

The `source` folder is ignored by Godot, avoiding automatic Blender imports and
keeping the studio setup out of game resources.

## Rebuild

Run Blender with `--background --factory-startup --python source/build_thumbtack.py`.
The script exports all five GLBs, checks closed manifold meshes and outward
normals, verifies materials and UVs, saves the Blender source, and renders the preview.
