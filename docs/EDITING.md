# Editing My Chicken Army in VS Code

This folder is the editable code project. Rojo sends its scripts into the existing **Pet Roll Test** place (`96683186622050`). The map, chicken meshes, textures and other authored models stay in Studio. [CODE_MAP.md](CODE_MAP.md) shows where each feature lives.

## The everyday workflow

1. Open this folder in VS Code and open Pet Roll Test in Studio. Stop Play before connecting or applying changes.
2. In VS Code, run **Terminal → Run Task → Rojo: Serve**. Alternatively, run this from the project root:

   ```sh
   python3 tools/rojo.py serve
   ```

3. In Studio's Rojo plugin, connect to the address shown in that terminal. Review the initial sync: it should concern the mapped code containers, not replace the map. If it proposes deleting builder content, cancel and inspect the project mapping.
4. Edit a `.luau` file in VS Code and save it. While connected, Rojo updates its matching script in Studio.
5. Start a fresh Play session to try the change. Stop and restart Play after edits to code that has already loaded: changing a ModuleScript's source does not rerun its existing objects.
6. Review the change in VS Code's Source Control panel. Save the place separately when you want the synced scripts stored with its Studio assets.

The Python wrapper downloads the project's pinned Rojo version locally when needed. Keep its serving terminal running while editing; stop it with **Ctrl+C**. A terminal command alone does not connect the Studio plugin.

## An old error returns despite synced code

Check for duplicate same-named ModuleScripts under the same parent. Roblox's
displayed full paths can be identical, so inspecting just one named child does
not establish which copy a `require` loads. Compare every candidate against the
codebase, preserve the stale copy outside the runtime tree, and restart Play.
Do not overwrite mapped script source through Studio to work around this.

On September 24, a duplicate `EggProcessorController` still accessed
`UpgradeCost` at line 68 while the Rojo-synced copy already contained the fix.
The stale module is recoverable in
`ServerStorage.EggProcessorDuplicateBackup_1790306379.EggProcessorController`.
The active module matches `src/client/EggProcessorController.luau`.

On September 25, an additional stale `UpgradeBoardController` lacked the shared
button animation. It is preserved in
`ServerStorage.PurchaseButtonRecovery20260925.UpgradeBoardController` and exported
under `assets/purchase-buttons-20260925/stale-UpgradeBoardController.luau`.
One active controller remains and matches the Rojo source.

## A small first edit

Open `src/client/RollPresentationController.luau`. Near the top are:

```lua
local ROLL_ZOOM_DEGREES = 2
local ROLL_ZOOM_OUT_SECONDS = 0.35
local ROLL_ZOOM_OUT_EASING = Enum.EasingStyle.Back
local ROLL_ZOOM_OUT_DIRECTION = Enum.EasingDirection.Out
```

Change just one value, save, then restart Play and roll. This gives you direct control over the effect without changing camera controls or purchase logic. Shared menu animations live in `src/client/UIMotion.luau`.

## What belongs where

| Work | Edit in |
|---|---|
| Gameplay, UI, effects and animation clip data | VS Code, under `src/` |
| Map geometry, buildings, chicken models and imported art | Studio |
| Code history and branches | Git / VS Code Source Control |
| Saved place and release publication | Studio / Roblox |

**Rojo sync is one way: files → Studio.** A script change made directly in Studio is not automatically copied back into these files. Copy or export that change into its matching source file before reconnecting; otherwise the next sync can replace it. Ask other agents to edit this project when working on scripts.

Keep the current `PetRoll` names and relative module locations unless you also update their `require` paths and Rojo mapping. Legacy IDs such as `Duck`, `Mallard` and `DuckArmy_Pond_v2` are compatibility names used by existing data.

## Editor tools and local builds

Use the recommended **Luau Language Server** and **Rojo** VS Code extensions. The Studio Rojo plugin is a separate component; the VS Code extension does not replace it.

```sh
python3 tools/rojo.py sourcemap
python3 tools/rojo.py build
```

The source map helps the editor understand Roblox instance paths. The build command checks that the mapped code can be assembled; its generated place is **not a full backup of the authored game**. Continue opening the existing Pet Roll Test for normal gameplay. Tests, archived scripts and editor/plugin helpers are outside the default runtime sync; consult their separate configuration before using them.

## Putting changes on GitHub

No GitHub remote is created by these instructions. Keep the repository private until you deliberately choose to share it. Do not commit credentials, local recovery places or generated caches.

For a feature, use a small branch and inspect the diff before committing. For example:

```sh
git switch -c stevin/roll-camera-feel
git diff
git add src/client/RollPresentationController.luau
git commit -m "Adjust roll camera feel"
```

After you create an empty private GitHub repository, add its URL once as `origin`. Then push the current branch:

```sh
git remote add origin YOUR_GITHUB_REPOSITORY_URL
git push -u origin HEAD
```

If `origin` already exists, inspect `git remote -v` instead of adding or replacing it. GitHub stores the committed code; it does not publish the Roblox game or upload its Studio-only map and models.

**These are separate saves:** saving a file changes local code; committing records code history; pushing uploads commits; saving in Studio stores the place; publishing updates the Roblox experience. Player progress is a separate DataStore concern.

## Restoring egg processing

The September 29 seller archive is an explicit exception to the normally unmapped
`archive/` folder: its 13 inert ModuleScript source backups map to
`ServerStorage.EggProcessingArchive20260929.Code`. The six original boards are
Studio-owned siblings under `Boards`, protected by `$ignoreUnknownInstances`.
The active implementations remain gated for save compatibility and simple
restoration. See [the restore steps](team/INSTANT_EGG_SALES.md).
