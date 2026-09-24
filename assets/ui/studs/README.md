# Shared stud artwork — September 24, 2026

## Current work

User direction: use one **full sheet of repeated studs**, cropped to the visible UI area. Do not construct individual studs as Frames/Parts, and do not use a single-stud tile as the final new artwork.

`stud-sheet.png` is the new full-area transparent PNG (1254 × 1254 output). It was generated with built-in image generation and visually inspected. The requested grid was 32 × 32; the returned art has approximately 24 × 24 cells, so do not assume the prompt dimensions are the actual asset dimensions.

`stud-tile.png` is the superseded first draft. Neither image has been uploaded. Permission to upload the full sheet is pending. The implementation temporarily retains the game's existing uploaded image (`114518181344801`) with its existing tiled-image rendering so UI art does not disappear during this handoff. **Full-sheet cropping is not yet deployed.**

After upload approval: import only `stud-sheet.png` under the experience's creator group (778575811), record its verified image ID, and update the shared helper plus all 12 active authored `StudTexture` ImageLabels. Use `ImageRectSize`/`ImageRectOffset` to select a region of the full sheet and `ScaleType.Crop`, not single-stud tiling. Recompute the crop region when a runtime surface resizes; bind cloned world-board surfaces too. Preserve current positions, scale, tint, opacity, and the user's ongoing board edits. Do not rerun the old board-building recipe over their rearrangement.

## Sweep findings

- `UITheme.Header`: generated 90 checker Frames before popup restyling.
- `UITheme.ApplyPopupStyle`: generated 120 studs, each with a face and stroke (360 descendants), per styled header.
- `ProgressionBrowser`: generated hollow studs/glints/strokes/corners in nested width/height loops for its header and seven controls.
- Egg-board authoring recipe: generated 18 studs plus 18 highlights per button, with 91 descendants per pattern container.
- Army/Index/shared buttons and the authored Upgrades board already used images. Army now routes through the shared helper instead of its private stud asset.
- Active Studio assets: replaced the two egg-button patterns and the Country UI preview header pattern with three ImageLabels, removing **242 active descendants**. Originals were moved intact to `ServerStorage.StudTextureBackup_1790282693`, with original-parent references and paths.
- A post-edit traversal found no remaining active Frame-based `StudPattern`, `FigmaStuds`, `PopupStudTexture`, or `CheckerPattern` containers outside backups.
- World art uses built-in `SurfaceType.Studs` (26,442 marked faces under the authored map); these are not individual stud Instances. No stud-named BaseParts were found outside backup content. The largest repeated sub-stud-size Part group examined was an authored wooden assembly, not a field of studs. Native surfaces, mesh details, fences, chickens, collisions, and historical backups were intentionally preserved.

## Ownership

`src/client/UITheme.luau` owns the shared image and presentation helper. `ProgressionBrowser`, `ChickenBrowser`, `IndexBrowser`, common headers/buttons, and `assets/egg-board/build.luau` consume it. Code changes go through Rojo. `migrate-studio.luau` edits only Studio-owned GUI assets and retains recoverable originals.

Evidence so far: source readback matched the three changed mapped modules; Studio inspection confirmed the migrated pattern count and preserved the user's current egg-board arrangement. No Play session, purchase, game publish, or cloud save was performed for this sweep. Do not describe this as a measured FPS improvement.

## Asset generation

First draft prompt: one transparent hollow square stud, dark outline and white upper-left bevel, intended at 28px. Rejected by the user in favor of an entire pattern sheet.

Full-sheet prompt: transparent 2048px square PNG with a uniform 32-by-32 grid of identical hollow square studs, dark outline and white upper-left bevel, transparent centers/gaps, orthographic, no text or backing. This is a full-area crop source, not a runtime per-stud builder.

Image crop properties: [Roblox ImageLabel documentation](https://create.roblox.com/docs/reference/engine/classes/ImageLabel).
