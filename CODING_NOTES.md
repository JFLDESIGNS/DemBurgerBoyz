# Coding notes

## Open / Closed window sign textures

- Files: `IMAGES/WEAREOPEN.png`, `IMAGES/WEARECLOSED.png`
- Status: PNGs are wired onto the 3D hang-sign (`_build_open_closed_sign` in `scripts/game.gd`).
- TODO: replace with proper alpha-channel cuts (black background is temporary). Keep the same paths so no code change is needed after the swap — just overwrite the PNGs and reimport.
