# Coding notes

## Open / Closed window sign textures

- Files: `IMAGES/WEAREOPEN.png`, `IMAGES/WEARECLOSED.png` (alpha cuts already in the PNGs).
- Status: QuadMesh hang-sign faces (`_build_open_closed_sign` in `scripts/game.gd`), same seat as the old text sign `(-1.08, 1.78, 1.14)`.
- Load via `FileAccess.get_file_as_bytes` + `Image.load_png_from_buffer` — never `Image.load(res://)` (broken in exports).
- Keep PNGs listed in `export_presets.cfg` `include_filter` so they ship inside the PCK (do not rely on `.import` / `.ctex`).
