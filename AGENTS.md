# My Chicken Army — canonical editable scripts

This repository is the code source of truth starting with the September 24, 2026 Rojo migration. Read README.md and docs/CODE_MAP.md first. The legacy pet-roll-prototype tree under Documents/ChatGPT/RobloxGameIdeas is historical; do not copy its scripts over these files without comparing changes.

Edit code in this repository and sync with Rojo. Do not simultaneously write mapped scripts through Studio MCP; Rojo can overwrite those edits. Use Studio Flow for readback and asset work. Canonical Pet Roll Test place ID: 96683186622050. Check its identity and Edit state before connecting. Do not publish or push to a GitHub remote without user authorization.

The map, rigs, assets, world settings, saved profiles and builder geometry remain Studio-owned. The default Rojo project owns only the existing named code containers and two bootstraps. Preserve `$ignoreUnknownInstances` and the place-ID allowlist. Do not load a scripts-only build over the existing place or treat it as a map backup.

Preserve the current relative module paths, internal PetRoll/Duck IDs and save compatibility. Server modules own state, money and transactions; client modules own input/presentation. No unrelated framework, file reshuffle or formatting pass. The user prefers quick PC iteration and small relevant checks over extensive suites.

## Simple animations — use TweenService
When a simple animation can be expressed with a normal Roblox TweenService tween, use a tween. Use TweenInfo repeat/reverse settings for looping or back-and-forth motion. Do not build custom frame-by-frame interpolation, timing loops, springs, or animation frameworks for these cases. Keep cancellation and cleanup small. Use a more complex approach only when the requested behavior genuinely cannot be achieved with a tween, and explain why before expanding the implementation.

## Stud texture — mandatory image reuse
ALWAYS use the approved generated full-sheet image for My Chicken Army stud patterns in Roblox UI, authored GUI art, and Figma. Source: `assets/ui/studs/stud-sheet.png`; uploaded Roblox image: `rbxassetid://93331178043153`. Reuse `UITheme.Studs` in runtime UI and the same uploaded image fill in Figma. Preserve the square sheet's proportions and crop it to the visible surface at a consistent stud scale. Never create or clone individual studs, per-stud Frames/Parts/vectors/rectangles/highlights, procedural stud grids, or single-stud tiles. Existing vector-based kit patterns are not an exception. Keep labels and controls separately editable. If the image is unavailable, report the missing asset rather than recreating studs. See `assets/ui/studs/README.md` for the asset and crop contract.

Merging is retained but disabled for release. Do not enable dormant features merely because code is present. `tests/` is optional historical checks; `archive/` contains exported backup/library/plugin code and previous-local variants. Neither is in default sync.

One writer per file. For parallel tasks, assign explicit files and contracts. Workers do not control canonical Studio, Blender, Git history or further agents; the root integrates. Keep changes scoped and preserve user work.

Before editing or syncing, inspect Git and compare any unsynced Studio changes. Record local commits, Roblox saves/publishes and player-data changes separately. A Rojo build verifies packaging, not Luau runtime correctness. Do not claim checks that were not run.
