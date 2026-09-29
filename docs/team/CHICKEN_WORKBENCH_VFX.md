# Workbench VFX transfer — September 27, 2026

Completed; Studio ownership released. Scope: authored effects from
Workspace.ChickenVFX_Workbench.Chickens to corresponding species in
ReplicatedStorage.PetRoll.ChickenAssets. Preserve rig/mesh/texture/gameplay data.
Source models and workbench stay Studio-owned. No mapped source changes planned.
Canonical Pet Roll Test 96683186622050, instance:w6a-k5r, Edit.
Other active ownership: fuse-flow UI and egg-processing correction; untouched.
No Play session, publishing, purchases or profile work in this request.

Transferred Magma/Knight, Frost, Shadow/Wizard, Diamond, Golden/Dragon,
Glitch/IceDuck, Galaxy/StormDuck and Storm: 55 particle emitters and 48 beams.
Unchanged Bonsai effects were retained. Native ScaleTo normalizes the different
workbench preview sizes into each template's original scale. Particle rates,
textures, colors and authored settings are retained. Existing imported-effect
lifecycle in BlenderPetView/SpecialChickenVFX handles visibility and culling;
no runtime script edit was needed. New game spawns clone these source templates.

Diamond, Golden and Galaxy each contained an invisible Central part hundreds of
studs from its parent attachment. Converted only those copied carriers to nested
attachments at the intended parent anchor, retaining rotation/child endpoint
layouts. This avoids distant geometry and allows the VFX to follow the chicken.
The original workbench remains untouched.

Frost's two beams already lack Attachment1 in the workbench. Preserved that
authored state; these two beams need an endpoint to render. Its five particle
emitters were transferred normally. All other beam references stay within their
destination model, including separate same-named endpoint attachments.

Readback: all eight templates retain their original scale, Body size/CFrame,
mesh ID and BasePart count. No external beam references remain. No Play or
visual gameplay test was run. The open Edit place contains the asset changes;
there was no Roblox Save/Publish or Git commit/push.

Recovery: ServerStorage.ChickenWorkbenchVFXRecovery20260927 contains complete
Before templates and WorkbenchSource copies. Local transfer script and manifest:
assets/workbench-vfx-20260927/.

## Revision 2 — latest workbench edits

Completed; source and Studio ownership released. Magma/Knight and Galaxy/StormDuck changed; other
previously transferred effects match the prior workbench snapshot. Own the two
templates and narrow imported-Light support in BlenderPetView and
SpecialChickenVFX. Both source files were clean in Git and matched their unique
Studio copies before edits. Preserve the other tasks' dirty files and all rigs.

Magma now contains eight particle emitters and one PointLight. Galaxy contains
five emitters, ten beams and one PointLight. Replaced the preceding VFX roots,
including removed emitters, rather than accumulating duplicates. Reapplied the
Galaxy carrier correction. Added Light to the existing imported-effect selection
in BlenderPetView and SpecialChickenVFX; authored lights now use the same
hide/defeat/reduced-motion/distance/cleanup behavior as imported particles.
No new animation loop or controller was introduced.

Readback matches both exact local Rojo sources. Both templates retain their
Body geometry, position and scale; beam endpoints are internal. Recovery:
ServerStorage.ChickenWorkbenchVFXRecovery20260927_Revision2. Evidence and the
repeat transfer script are in revision2-applied.json and apply-revision2.luau.
No Play session, tests, save/publish, commit/push or real-profile changes.

## Approved eight — workbench addition

Added Lollipop, Honeycomb, Toxic, Water, Solar Flare, Heavenly, Devil and Jungle
as editable authoring copies under `Workspace.ChickenVFX_Workbench.Chickens`.
The workbench now has 40 chickens and 40 labeled pedestals. New pedestals 33–40
form the front row at Z=36.25, X=423 through 521 with the existing 14-stud spacing.
The deck extends forward to fit that row; previous chicken/VFX edits remain intact.
The previous platform is preserved in
`ServerStorage.WorkbenchApprovedEightAddition20260927.Platform`.

Each copy retains its corrected source mesh, 18 bones and existing particles/lights;
all parts are anchored for editing. Species, SourceAssetPath, VFXAuthoringCopy and
PedestalIndex metadata identify the authoring copies for subsequent VFX transfer.
Source gameplay templates were not changed by this addition. Structural readback
confirmed all eight matching meshes and the 40-model/40-pedestal totals.

An independently started Play session became active during the request; it was
left running. Changes are in the Edit DataModel. No playtest was started or stopped,
and no local place save, Roblox save/publish or Git commit/push was performed for
this workbench addition. The preceding ApprovedEight RBXL snapshot predates it.
Workbench ownership released.

## September 28 — expanded workbench sync

Completed in canonical Pet Roll Test `96683186622050`, Edit instance `l70-su4`.
Synced all 18 VFX-bearing workbench species into their existing ChickenAssets
templates: Bonsai, Devil, Diamond, Dragon, Frost, Heavenly, Honeycomb, IceDuck,
Jungle, Knight, Lollipop, Rainbow, SolarFlare, Storm, StormDuck, Toxic, Water
and Wizard. The 22 effect-free species were untouched.

The transfer copies full effect subtrees at their existing mesh or bone anchors,
normalizes workbench scale with native ScaleTo, preserves cross-root beam
endpoints and replaces old VFX rather than accumulating duplicates. This includes
the user's removed beams/lights as well as newly added particles. The former
Frost beams with missing endpoints are absent from the latest workbench and were
removed from its template. No rig, geometry, animation or runtime source changes.

Separate Edit readback confirms all 128 effects match normalized authored
properties, beam endpoints stay inside their template, and every original mesh,
bone, size, transform and template scale is retained. The workbench is unchanged.
This is structural/property readback, not a visual gameplay test.

Recovery contains complete before-templates and authored snapshots at
`ServerStorage.ChickenWorkbenchVFXRecovery20260928`. Transfer script, before
inventory, result and repeatable readback are in `assets/workbench-vfx-20260928/`.
Changes are in the current open Studio Edit place; no Play/Stop, local place save,
Roblox Save/Publish, asset upload, Git commit/push or player-data change occurred.
Template and workbench ownership released.

## September 29 — revealed roll offers show chicken effects

`RollPresentationController.Preview` now sets its model's `ReducedMotion` override
only during the mystery shuffle. Revealing an offer clears that override, including
when the last shuffle bird is reused from the cache, so the existing client VFX
lifecycle shows authored effects while the chicken waits to be purchased. The
player's global reduced-motion setting still applies.

The single Studio controller matched the local source before editing and after
Rojo sync. An isolated Edit-mode check using the actual preview and VFX modules
passed for Lollipop (10 emitters) and Magma/Knight (9 emitters and one light):
hidden mystery, visible cached reveal and waiting offer, reduced-motion suppression,
reroll hiding and removal cleanup. Temporary objects were destroyed. No full Play
session, player-data change, place save/publish or Git commit/push was performed.

## September 29 — repeat workbench import

Completed in Pet Roll Test `96683186622050`, Edit peer of instance `l70-su4`.
Compared all 40 workbench chickens against their scale-normalized game templates.
Four species had changes: Devil, Glitch/IceDuck, Jungle and Galaxy/StormDuck.
Transferred their updated effect subtrees at the existing mesh/bone anchors,
replacing their prior effects rather than adding duplicates. Jungle now has seven
emitters, up from three; the other three retain their effect counts with updated
authored properties. All four comprise 44 effects after transfer.

Separate readback confirms authored properties and attachment/beam endpoints
match, all original mesh/texture/bone/transform/scale data is unchanged, and the
workbench is untouched. A second comparison across all 40 species reports no
remaining VFX differences. Existing BlenderPetView/SpecialChickenVFX lifecycle
already covers these effects; no runtime source edit was needed. The separate
roll-offer VFX source change and other local work were preserved.

Complete before-templates and source snapshots are preserved in
`ServerStorage.ChickenWorkbenchVFXRecovery20260929`. Local scripts, inventories
and readback receipts are in `assets/workbench-vfx-20260929/`. The existing Play
session was left alone; changes were applied to the Edit DataModel and appear
in newly instantiated chickens after restarting Play. No gameplay test, asset
upload, place save/publish, Git commit/push or player-data operation was performed.
Workbench/template ownership released.
