# Roster expansion: in-game integration (October 15, 2026)

The 83 roster-expansion chickens are in the canonical Pet Roll Test (96683186622050). They
used the same route as the September 27 approved-eight import. Art: `assets/chicken-roster-expansion-20261015/`.
Design list: `CHICKEN_ROSTER_EXPANSION.md`. Effects design: `CHICKEN_ROSTER_VFX_PLAN.md`.

## What changed

**Studio (Studio-owned, not in Rojo)**
- 83 new templates are in `ReplicatedStorage.PetRoll.ChickenAssets.<ID>`. No existing species was
  replaced; the import asserted this.
- Each template is one rigid-skinned MeshPart `Body`:
  - an 18-bone `<ID>_` skeleton
  - a 512 px atlas, with prop colors baked into unused atlas cells
  - `ScaleTo(0.670163170)` and an `AnimationController`
- All meshes, textures and 6 new particle sprites are group-owned assets (creator 778575811).
- The staging copy and receipts are in `ServerStorage.RosterExpansionImport20261015`.
- The recovery Model asset is **92097054203486**, holding all 83 templates with their effects.

**Code (synced by Rojo)**
- `src/shared/PetCatalog.luau`:
  - 77 roll chickens in the existing stat tiers.
  - Gingerbread and Firework are seasonal limiteds in the Pumpkin pattern: zero roll
    weight, hidden from the Index until owned or until their event runs. No event is
    configured for either yet.
  - Each Luck band keeps its exact total weight (Luck-0 percent odds). The new chickens share
    a set fraction of the band, and existing members keep their relative weights.
  - The basic Chicken is locked at 28%.
  - In the Index, each new chicken follows the last chicken of its rarity.
- `src/shared/ChickenAppearanceAssets.luau`: 83 entries (`bonePrefix = "<ID>_"`,
  `unitScale = 0.670163170`, `pivotRig = true`).
- `src/animations/<ID>.luau`: 83 aliases of the Bee master clips with the `<ID>_` bone prefix.
- `src/client/SpecialChickenVFX.luau`: a small hook added to the existing effect lifecycle.
  - Emitters tagged `RosterBurst` (`Attack` / `Hit` / `Victory`) fire `Emit(RosterBurstCount)`
    on the clip serials.
  - Lights tagged `RosterPulse` / `RosterPulseTime` pulse with a looping TweenService tween while
    visible.
  - Both follow the existing hide rules: reduced motion, distance cull, defeat and hidden.

**Not in the catalog yet:** Kingslayer and Ascendant. Their templates and clips are installed,
but how players earn them is still an owner decision (a new mechanic).

## Effects (55 chickens)

Effects are authored natively on bone attachments in the templates. Pattern: Sept 27 `install_vfx`.
Source: `roblox/install_vfx.luau`.
- 36 looping emitters, 48 action bursts and 22 lights (14 of them pulse).
- Textures: the existing `Glitter`/`Star`/`Smoke`, plus 6 new sprites (Bubble, Bat, Zzz, Note,
  Confetti, Ember).

| Chicken | Effects | Status |
|---|---|---|
| Kitsune | Foxfire as 3 fixed anchors | Simplified: the orbit motion from the plan is not done |
| Time Keeper, Airship Captain, Ascendant, Steampunk | Moving props (clock hands, propeller, halo rings, gears) | Not done: the props are part of the single skinned mesh |
| Ghost | Transparency | Not done: left opaque so the face and eyes stay readable |

## Checks run

**In Blender**
- All 83 runtime meshes have 18 bones and no unweighted vertices.
- Maximum 1,188 triangles.

**In Studio Edit** (fresh module copies, no player save loaded)
- 81 catalog chickens built through the real `BlenderPetView.Create`: all V3, all clip bones
  present.
- The `SpecialChickenVFX` lifecycle ran for all 81 without errors.
  - 37 showed loops or lights when visible.
  - 41 fired their bursts on serial changes.
  - 14 pulse lights started.
- `Rules.Odds` at Luck 0, 10 and 20 sums to exactly 1.000000, with 126 species.
- The basic Chicken is 27.997% at Luck 0.
- Limited and unreleased chickens are not rollable.
- Band totals were checked against the pre-change values (38 / 22 / 22 / 9 / 5 / 3 / 0.7 / 0.25 / 0.05 / 0.01).

**Packaging:** `rojo build default.project.json` succeeds.

**Not run**
- A live Play session with a real profile.
- Battle and fuse play with the new chickens.
- Native visual review of each chicken in-game.

**Not done**
- The place has not been saved to Roblox and nothing was published.
- No Git commit was made.

## Rebuild or redo

The art and runtime export are in the Blender staging folder
`~/.codex/artifacts/chicken-roster-expansion-20261015/`. Run in this order:
1. `source/runtime.py` (`RUNTIME(id)`)
2. `source/prepare_payload.py` (writes `transport/`)
3. Serve `transport/` on `127.0.0.1:18797`
4. In Studio Edit, run `loadstring(HttpService:GetAsync(".../import_one.luau"))()(id)`, then
   `install_vfx.luau`

The importer skips anything already in staging, and the installer refuses to overwrite an
existing `ChickenAssets` species.

## Follow-up (same day): portraits, roll preload, lineup

**Portraits**
- All 81 catalog chickens now have 512 px image portraits with the approved 7px black
  silhouette border.
- They're mapped in `src/client/ChickenPortraits.luau`, and `ChickenPreview` uses them instead of
  a 3D ViewportFrame.
- How they were made: Studio viewport captures at the Sept 25 Photobooth angle, shot against a far
  black backdrop and then a white one. The two are difference-matted into clean alpha, then
  outlined.
- Files: `assets/chicken-roster-expansion-20261015/roblox/portraits/`
  - `capture.luau` and `process.py`
  - `outlined/`
  - `portrait-receipts.json`
- Group image assets were uploaded through `AssetService`, and all 117 portrait IDs fetch
  successfully.

**Roll preload**
- `RollStation` sets `PendingSpecies` when a roll starts.
- `RollPresentationController:Warm` builds that chicken (and the shuffle birds) unparented, then
  runs `ContentProvider:PreloadAsync` on them.
- The reveal therefore appears with its mesh and texture already loaded. The reveal timing is
  unchanged.
- Trade-off: the result species is readable on the client about one roll duration early. The roll
  is already decided on the server, so this gives no advantage.
- Both scripts compile in Studio. This was not play-tested in a live roll.

**Lineup**
- `Workspace.ChickenLineup_Review` shows all 127 templates in rarity order with labels, at
  Y = 300 off the island.
- It's a temporary review model: delete it before saving or publishing, or it ships in the place.
