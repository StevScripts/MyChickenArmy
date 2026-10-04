# Dragon chicken flight — staged Roblox import

Imported October 3, 2026 into **Pet Roll Test**, place `96683186622050`, using the latest Blender **Forward Cupped Wings** action. This is an asset handoff only; the Outer Space Crate remains disabled and its rewards, purchase processing and normal-roll Dragon have not changed.

## Studio location

`ReplicatedStorage.GalaxyCrateChickenAssets20261002.DragonChickenFlight`

- `DragonChickenMesh`: textured, skinned mesh with all 23 bones.
- `RootPart`: anchored, transparent PrimaryPart at ground level. Local **-Z** faces forward. Mesh is welded to this root; all parts have collision, touch and query disabled.
- `RootPart.RollBoxAttachment`: identity attachment for future rolling-box placement.
- `AnimationController.Animator`: native animation player, ready for later integration.
- `Animations.FlightLoop`: editable native KeyframeSequence, looping, Movement priority, 73 samples from 0 to 1.2 seconds at 60 fps. The last sample duplicates the first.
- `AnimSaves`: points to the model's own Animations folder so the exported model is self-contained.
- `HookupNotes` and attributes describe the intended use and source version.

Body height is 3.5 studs. `Model:GetScale()` is approximately 4.367735; use `Model:ScaleTo()` for future size changes so the native Animator also scales translation offsets. Do not individually resize the MeshPart.

## Future hookup

Clone the model, parent it to Workspace or a ViewportFrame WorldModel, then `PivotTo()` the rolling-box reveal CFrame. The primary root is the ground-level placement point. For an actual physical attachment, align RollBoxAttachment to the destination attachment, weld RootPart, and unanchor RootPart.

The animation is imported and verified in Studio but **has not been published as a runtime AnimationId**. At gameplay integration, publish FlightLoop to **Kiru Experiences** (group `778575811`), create an Animation with that ID, and load it with the supplied Animator. No temporary Studio preview ID is stored in the reusable model. Continue using the existing server-side crate/purchase systems; this asset adds no scripts.

## Files and recovery

- `DragonChickenFlight.rbxm`: native Studio selection export containing the complete staged model and editable clip.
- `DragonChicken-Flight.fbx`: original-size rig, embedded PBR textures and baked flight cycle.
- `DragonChicken-Rig.fbx`: rest-pose rig with embedded textures.
- `Roblox-Flight-Preview.jpg`: native Animator pose at 0.6 seconds in the target Studio place.
- `export-report.json` and `roblox-validation.json`: export and playback readback.
- Studio raw import and original clip: `ServerStorage.DragonFlightImport20261003`.
- Additional Animation Editor save: `ServerStorage.RBX_ANIMSAVES.DragonChickenFlight.FlightLoop`.
- Blender master remains `/Users/stevin/.codex/artifacts/dragon-chicken-flight-v2/Dragon-Chicken-Curved-Flight.blend`.

Mesh asset: `78420174763373`. SurfaceAppearance maps: color `131536918150698`, normal `96780526398825`, roughness `77657584456579`, metalness `123128471309639`. Uploaded to Kiru Experiences through Studio's importer.

## Checks performed

Native Animator loaded a 1.20000005-second loop and applied the rig at several times through the cycle, including near the wrap. The exact first/last imported poses have zero position and angular difference. The rig has 23 bones and the reusable model contains zero scripts. Textures and upper/lower wing poses were inspected in Studio. No gameplay playtest or experience publish was performed.

The export copy limits each vertex to four influences, as required by [Roblox's mesh specifications](https://create.roblox.com/docs/art/modeling/specifications). Only 38 of 9,537 vertices needed trimming; the greatest removed weight was 0.006616 before normalization. The Blender source was not changed. Native animation preview uses [Animator.StepAnimations](https://create.roblox.com/docs/reference/engine/classes/Animator/StepAnimations).
