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
