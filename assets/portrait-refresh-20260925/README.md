# Fresh chicken portraits — September 25, 2026

User requested clearer photos where faces were missing or textures were blurry.
This pass replaces nine outdated captures and adds the current Jockey portrait:
Galaxy, Camo, Mushroom, Tiger, Zombie, Slime, Frost, Golden Emperor, Diamond and
Chicken Jockey. The runtime change is confined to `src/client/ChickenPortraits.luau`.

## Capture method

Fresh native Photobooth 2.10.2 captures use the current authored Studio models
through uncached copies of PetView and its shared dependencies. The current
BlenderPetView already makes Galaxy opaque; its old portrait predated that fix
and lost its eyes through transparency sorting. No model or texture was redrawn.

Capture settings: 512 × 512 transparent PNG, Edit quality Level21, cloned meshes
using Precise render fidelity, preloaded textures and a render settling delay.
The existing three-quarter angle and 33-degree camera field of view are retained.
Jockey framing moves upward to include the rider's deformed bones, which extend
above the mesh's rest-pose bounds. Camera, selection, ScreenGui enabled states
and Edit quality are restored after each capture. There are no permanent changes
to model materials, meshes, textures, lighting or game logic.

`png/` contains the native exports. `outlined-portraits/` contains the ten accepted
final PNGs. `add-borders.py` adds the previously approved 7px black silhouette
border. The border follows alpha >= 128 so faint captured bloom does not create
detached outline rings. The native RGBA capture is composited over that border;
all fully opaque artwork pixels remain exact. Borders do not clip the canvas.

First-pass Jockey framing and the no-bloom trial are retained in `first-pass/`
and `no-bloom-rejected/` for comparison; neither was uploaded. Fresh Glitch and
Shadow captures were inspected, but their existing approved portraits were
retained. Do not map every file in `png/`: `portrait-manifest.json` is the accepted
set and records previous IDs, final IDs, hashes and upload receipts.

## Applied and visually checked

All ten accepted images were uploaded to creator group 778575811 and their IDs
synced through Rojo. An Edit-only Army preview used the real ChickenBrowser
constructor with inert sample data. All ten replacements returned successful
fetches and `IsLoaded = true`; Galaxy was also inspected in the large detail
panel. `army-preview.png` is the native screenshot and `asset-load-checks.json`
records the loaded instances plus the mapped source byte length/hash.

The entire previous portrait sheet was inspected for missing faces and soft
patterns. The accepted replacement sheet was inspected before upload, including
Jockey framing and borders. These are authoring/render checks, not a live gameplay
session or physical-device test. No Roblox Save/Publish, Git commit/push, player
data changes or transactions were performed.

## Recovery and future refreshes

`ChickenPortraits.before.luau` preserves the previous mapping. Native receipt
folders live in `ServerStorage.PortraitRefreshUploads20260925`; temporary capture
objects and the disabled Army review are preserved under
`ServerStorage.PortraitRecapture20260925`, outside StarterGui. Local HTTP capture
and upload bridges were stopped after use. Helpers never write mapped Source.

Always photograph the current model after its textures have loaded, inspect the
eyes at full size and card size, and inspect the outlined result before upload.
Check deformed rigs such as Jockey visually; rest-pose mesh bounds can omit a rider.
Do not reuse an older portrait merely because the species name still matches.
