# Customer Creator

The Food Flip creator and standalone creator now share `scripts/doll_studio.gd` (mirrored into `character_creator_app/scripts`). Both keep their existing character catalogs, game integration, and preset formats.

The studio uses a dark charcoal/plum theme with coral accents. Category navigation, focused face/outfit sections, paginated thumbnail catalogs, readable labels, numeric slider entry, per-control resets, linked facial adjustments, section locks/randomization, starter looks, recent/favorite colors, and undo/redo replace the previous long exposed slider panels.

Hair layers have selection, thumbnail previews, persistent visibility, add/remove, and undo support in both apps. Saved customers have a searchable gallery, Save As, duplication, and saved/unsaved status. Dress, Pose, and Paint tools are separated. Camera shortcuts and light/dark preview backgrounds remain available throughout editing. The legacy accessory fitting and sculpt workspaces remain accessible.

## Builds

- `build/FoodTruckFlip.exe`
- `build/BurgerCharacterCreator.exe`

Both exports embed their resources. Existing character presets are retained. The prior executables are backed up in `build/doll_studio_previous` when installing this update.

## Validation

`tests/doll_studio_smoke.gd` checks category navigation, catalog paging, release-safe defaults, numeric adjustment undo/redo, hair layering, symmetry, locks, paint history, mode transitions, and widths from 900x620 through 1440x900. The same suite runs against each embedded export in an isolated release directory.

`tests/doll_studio_save_smoke.gd` checks saving, portrait generation, hidden-layer persistence, and painted skin reload. It restores the previous last-character file and removes its uniquely named test preset afterward.

`tests/doll_studio_visual.gd` renders the active categories, a compact window, and a 150% scaled view. Food Flip uses Forward+; the standalone uses Compatibility. Original paint smoke coverage remains in place.

When editing the shared UI, copy `scripts/doll_studio.gd` to `character_creator_app/scripts/doll_studio.gd`, then rebuild both exports. Keep controller-specific catalog and game-return behavior intact.


## Customer Creator refresh

The shared UI is named Customer Creator and saves with Save customer. Catalogs show three larger, cached 3D previews at a time with previous/next cycling and search. Hair and hats use bounds-based framing, including tall crowns and wide brims. Hair layers expand below the picker. View shortcuts sit in a dedicated control panel, and the introductory overlay text is removed.

The creator world is isolated in a SubViewport, preventing the game environment from leaking into the preview. The optimized menu truck GLB is parked behind the customer with its imported driving offset reset. Tops, bottoms, hats and shoes use neutral luminance before the selected tint, preserving trim contrast without mixing the authored hue. Original asset materials remain untouched. The standalone retains its own catalogs.
