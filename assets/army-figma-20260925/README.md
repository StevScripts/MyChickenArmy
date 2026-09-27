# Army Figma proportions and larger portraits — September 25

## Requested result

Match the approved Army reference's top and bottom proportions, enlarge chicken
portraits, tighten the name/DPS gap, and add/upload black silhouette outlines to
all current chicken portrait images.

Reference: `/Users/stevin/.codex/attachments/9eff1292-3a52-47b5-889f-5ecd94d1eae5/image-1.png`.
Figma: file `4lJjZOqNhR8K7rfMbVIjaK`, Army frame `221:2294`, toolbar
`221:3040`, card `221:3253`, inspector `221:3363`.

## Implemented layout

- AppController keeps a 1474:976 Army window aspect ratio on desktop, fitted to
  the available screen area. Compact layouts keep their responsive flow.
- ChickenBrowser uses the Figma single-row Flock/Army/Select Best/Stats toolbar,
  four desktop columns, inline inspector, horizontal stats, wide Equip and
  narrower centered Sell.
- Card portraits are larger and account for transparent source padding. Native
  name/DPS text draws above the art with a one-pixel gap between label boxes.
- Resizing restores compact scrollbar/padding settings. Sale confirmation grows
  its detail scroll range as needed and restores the normal range on dismissal.
- Stud patterns use the approved full-sheet image through UITheme.Studs.

## Evidence gathered

Studio Flow Edit-only checks used the real AppController.FitPanel and
ChickenBrowser constructors, fake inventory and disconnected requests. Native
screenshots inspected desktop, portrait and landscape authoring previews.

| Safe area | Army panel | Columns | Card size | Name/DPS gap |
| --- | --- | --- | --- | --- |
| 1451 × 650 | 923 × 611 | 4 | 131 × 137 | 1 px |
| 1918 × 1080 | 1533 × 1015 | 4 | 218 × 228 | 1 px |
| 1022 × 767 | 981 × 650 | 4 | 139 × 145 | 1 px |
| 389 × 762 | 366 × 701 | 2 | 138 × 144 | 1 px |
| 749 × 368 | 704 × 339 | 2 | 175 × 120 | 1 px |

The same browser was resized back to desktop after both phone sizes. All six
states kept Sell within the normal canvas, expanded the canvas past the sale
confirmation, and restored its height on dismissal. Temporary audit objects
were destroyed. These checks are not a physical-device or full gameplay test.

## Outlined portraits — complete

31 captured PNGs are currently referenced by ChickenPortraits. Jockey retains
its existing 3D fallback because its old capture predates the revised rider.
Original captures are in the historical prototype's
`assets/ui/chicken-portraits-20260923/png/`; retain these originals.
All 31 unchanged originals are also retained in `original-portraits/`, with
original/replacement asset IDs, dimensions and SHA-256 hashes recorded in
`portrait-manifest.json`. The outlined PNGs are in `outlined-portraits/`.

The user explicitly approved direct PNG editing with “Yes add border.”
`add-borders.py` adds a 7px black silhouette border with an antialiased outer
edge and preserves every original pixel with nonzero alpha, including its RGBA
values. All originals remain 512 × 512 and no borders reach the canvas edge.
Per-image checks are in `border-checks.json`; both contact sheets were visually
inspected before upload.

All 31 outlined images were uploaded through Studio Flow/AssetService to creator
group 778575811 and applied in `src/client/ChickenPortraits.luau`. No original
portrait IDs remain in active source. Upload receipts are also recoverable in
`ServerStorage.ArmyPortraitOutlineUploads20260925`. The existing Jockey model
fallback remains; its outdated capture was not reinstated.

All 31 images returned successful ContentProvider fetch results and showed
`IsLoaded = true` after being attached to the authoring review GUI. The native
all-portrait sheet was visually inspected. The first unparented-image probe
returned successful fetches but false IsLoaded values; the attached GUI check
is the authoritative render evidence, recorded in `asset-load-checks.json`.
Desktop and portrait-phone previews were rebuilt from the actual constructors
and visually checked with the uploaded assets. All 13 images in the desktop
Army preview loaded. There was no gameplay session or physical-device test.

The two `generated-*-not-applied.png` files are discarded imagegen experiments;
neither was uploaded or used. Production assets use the direct PNG method.

## Recovery and authoring previews

`before/` contains the four initial source copies. `create-review.luau` makes
inert Studio authoring snapshots from the actual menu constructors. It refuses
to overwrite existing previews. Original MCA_Tune_Army previews and their
baseline are preserved separately; Shop previews were not changed.

Review screens are authoring-only, not runtime features. Keep them disabled
before Play. After visual inspection, the three disabled review screens were
moved to `ServerStorage.MCA_ArmyFigmaReviewCurrent20260925`, outside StarterGui.
After the asset upload, the final outlined previews were likewise disabled and
preserved in `ServerStorage.MCA_ArmyOutlinedReview20260925`. The all-portrait
review GUI is disabled inside `ArmyPortraitOutlineUploads20260925`.
Final byte lengths and source hashes for AppController, ChickenBrowser and
the updated ChickenPortraits match Studio; see `source-readback.json`.
No player data, purchase, Roblox Save/Publish or Git history
operation was performed by this layout pass.
