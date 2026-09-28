# Eight approved traits — September 27

Imported in canonical Pet Roll Test (96683186622050), normal roster now 40. Source edits synced through Rojo. New IDs: Lollipop, Honeycomb, Toxic, Water, SolarFlare, Heavenly, Devil, Jungle. Existing save IDs and total rarity/stat-band weights are preserved. Each new bird uses the same master skeleton and six authored clips.

Water: rebuilt twisted curved trim, mirrored outward-facing wings, moved foam onto its visible surface. Heavenly: replaced overlapping halo bars with a continuous ring. Lollipop: simplified spiral geometry. All eight: single texture atlas and one rigid skinned mesh.

## Evidence

- `index-preview.png`: actual runtime Index cards, showing all eight native 3D previews. Existing ChickenPreview fallback supports these without new static portrait uploads.
- `verification.json`: actual Studio/client/server checks.
- `server-checks.json`: normalized roll odds and isolated synthetic merges/discovery.
- `asset-receipts.json`: group-owned image/mesh IDs and native recovery Model asset 133147408408338. Recovery pack was loaded and all eight checked.
- `runtime-manifest.json`: final Blender export geometry counts.

The native templates live in ReplicatedStorage.PetRoll.ChickenAssets. Import receipts and recoveries are in ServerStorage.ApprovedEightImport20260927. No original species replaced. Native particles/lights are on bone attachments and use the existing imported-effect lifecycle.

## Completed

Computer Use inspection is complete: all eight were reviewed in native Studio, including close Water front/rear views and Heavenly halo inspection. The temporary review stage is preserved under ServerStorage.ApprovedEightImport20260927 and the editor camera was restored. The full local place was saved through Studio Save to File As and its binary RBXL header and size checked.

Local place: `/Users/stevin/Documents/ChatGPT/My Chicken Army/output/roblox/MyChickenArmy-ApprovedEight-20260927.rbxl` (13,731,992 bytes). No game publication, Git push or player-save changes. An isolated playtest temporarily disabled both bootstraps; they were restored to enabled after stopping Play.

## Blender source

`/Users/stevin/Documents/ChatGPT/My Chicken Army/output/blender/chicken-traits-approved8/revision2/Chicken-Traits-Approved8-v2.blend`

Use revision2/runtime GLBs, not the initial exports directory. Authoring source has named TRAIT scenes; runtime meshes have prefixed 18-bone rigs. `prepare_payload.py` decodes the exported GLB; `import_one.luau` retains the known roster import method. The temporary local HTTP bridge is a tooling transport, not a runtime dependency.
