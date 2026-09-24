# Shared stud artwork — September 24, 2026

## Current work

User direction: use one **full sheet of repeated studs**, cropped to the visible UI area. Do not construct individual studs as Frames/Parts, and do not use a single-stud tile as the final new artwork.

`stud-sheet.png` is the new full-area transparent PNG (1254 × 1254 output). It was generated with built-in image generation and visually inspected. The requested grid was 32 × 32; the returned art has approximately 24 × 24 cells, so do not assume the prompt dimensions are the actual asset dimensions.

`stud-sheet.png` was uploaded through Studio Asset Manager using computer use under **Kiru Experiences**, the experience's creator group (778575811). Verified uploaded image ID: **93331178043153**. `stud-tile.png` is the superseded first draft and was not uploaded. The previous native picker issue was resolved; no browser sign-in is needed.

**Full-sheet cropping is applied in local code and Studio Edit.** `UITheme.Studs` uses one square full-sheet ImageLabel inside one transparent `StudClip` frame with `ClipsDescendants=true`. No single-stud tiling remains in the shared runtime helper. `StudSpacing` controls nominal cell size; the square enlarges if needed to cover a larger surface. Resize handling accounts for ancestor UIScales and does not depend on uploaded source resolution. The egg and upgrades controllers rebind cloned surfaces. Index cards retain their original 3px inset and 32px spacing.

`apply-sheet-studio.luau` migrated all 12 active authored images, preserving layout, tint, opacity, and the user's board arrangement. Original ImageLabels are recoverable in `ServerStorage.StudSheetBackup_1790287287`, with original-parent references. `StudClip` now owns each surface's Position/Size; move or resize that frame when arranging the texture area. Do not rerun the old board-building recipe over the user's rearrangement.

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

Figma reuse: the approved sheet is uploaded in file `4lJjZOqNhR8K7rfMbVIjaK` with image hash `90717abd1059ec66c34e8ef157d8632033975e15`. The compact Offline Earnings popup (`359:3508`) uses this image in its header and Continue button, with a square 672px sheet cropped to each surface. Its 52 individually authored button-stud layers were removed and its inherited header vector pattern suppressed. This is a scoped popup correction, not a migration of every older Figma screen. Future UI work must follow the mandatory image-reuse rule in AGENTS.md.

`src/client/UITheme.luau` owns the shared image and presentation helper. `ProgressionBrowser`, `ChickenBrowser`, `IndexBrowser`, common headers/buttons, and `assets/egg-board/build.luau` consume it. Code changes go through Rojo. `migrate-studio.luau` is the historical first pass; `apply-sheet-studio.luau` performs the final sheet migration. Both operate only on authored GUI art and retain recoverable originals.

Evidence: final source readback matched UITheme, IndexBrowser, EggProcessorController, and UpgradeBoardController. Studio inspection found all 12 authored images referencing the uploaded sheet inside clipping frames; both visible egg-board images reported loaded. An Edit viewport screenshot showed the sheet rendered and clipped on Finish Now and Upgrade, with the user's current board arrangement intact. No Play session, purchase, game publish, or cloud save was performed for this sweep. Runtime resizing has not been playtested. Do not describe this as a measured FPS improvement.

## Asset generation

First draft prompt: one transparent hollow square stud, dark outline and white upper-left bevel, intended at 28px. Rejected by the user in favor of an entire pattern sheet.

Full-sheet prompt: transparent 2048px square PNG with a uniform 32-by-32 grid of identical hollow square studs, dark outline and white upper-left bevel, transparent centers/gaps, orthographic, no text or backing. This is a full-area crop source, not a runtime per-stud builder.

Image crop properties: [Roblox ImageLabel documentation](https://create.roblox.com/docs/reference/engine/classes/ImageLabel).
