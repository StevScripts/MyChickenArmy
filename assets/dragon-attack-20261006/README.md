# Galaxy Dragon flying attack — Forward Swoop v3

Revised October 6, 2026 for the large blue Galaxy Dragon following the correction that the smoother attack looked sideways. Forward Swoop v3 keeps the approved smoothness, vertical arc, pitch and timing, while directing the lunge straight forward. The user approved this version and requested Roblox implementation. It is now installed on both Galaxy Dragon models in Pet Roll Test, with group-owned native animation assets and client playback through DuckAnimator. The existing 1.2-second flight source and its flight action remain preserved. The blue dragon remains a staged Galaxy-box asset; its reward/catalog/army deployment has not been enabled.

The attack is a 1.4-second curved rise, forward swoop and beak strike, followed by an arcing recovery into flight. Lateral root translation, yaw and bank are zero. Forward reach is 20% stronger than Curved Swoop v2; the approved vertical arc and pitch are unchanged. Motion continues through the strike: contact is at frame 33, maximum forward reach at frame 45 and the lowest point at frame 48, so the body keeps following its curve after the beak connects. It contains 85 samples at 60 fps. Entry and exit are identical and match phase zero of the existing `Dragon Flight | Forward Cupped Wings` action; comparison with its older evaluated export differs only by floating-point roundoff (maximum matrix-element difference `3.58e-7`). `AttackContact` is at **32/60 seconds (0.533333 seconds)**. The clip does not loop.

## Files

- `Galaxy-Dragon-Flying-Attack.blend`: editable Blender review scene.
- `Galaxy-Dragon-Forward-Attack-Preview.mp4`: current normal-speed flight → attack → flight from two angles, then the attack at half speed.
- `GalaxyDragon-Attack.fbx`: baked attack on a compatible 23-bone rig, with embedded original textures.
- `author_attack.py`: current Forward Swoop v3 Blender authoring source.
- `Before-Forward-Lunge.blend` and `author_attack_v2.py`: preserved Curved Swoop v2 scene and authoring source.
- `Before-Curved-Swoop.blend` and `author_attack_v1.py`: preserved first attack scene and authoring source.
- `attack-cycle.json`: evaluated local bone deltas and the original 23-bone hierarchy.
- `GalaxyDragon-Attack.rbxmx`: standalone native `Attack` KeyframeSequence imported into the existing Dragon rig. It contains the animation only, not a replacement mesh or rig.
- `package_attack.py`: reproducible XML packaging and readback verification; run with Python 3 from any working directory.
- `export-check.json`: results of local XML structure, timing, marker and matrix checks. It is not proof of Studio playback or visual approval.

The Blender viewport repeats frames 1–84 for review; frame 85 is the matching endpoint retained in the action/export. This avoids showing the duplicate endpoint twice during preview playback. The attack preserves the flight's moving entry and exit tangents. The original flight action remains selectable on the same rig.

`animation-check.json` records evaluated endpoint matching, continued travel through contact, arc dimensions and finite skinned vertices throughout the attack. `camera-framing.json` fits all flight and attack poses with margin. `fbx-export-report.json` records the export-only four-influence limit; the authored mesh and weights are preserved.

## Native animation contract

The XML sequence is nonlooping and uses `Enum.AnimationPriority.Action` ([Roblox enum documentation](https://create.roblox.com/docs/reference/engine/enums/AnimationPriority)). Each keyframe has an identity `DragonChickenMesh` wrapper pose with weight 0, then `FlightRoot` and all 23 bone poses in their original hierarchy with weight 1. Samples use linear interpolation.

Blender deltas are converted with `Y180 * delta * Y180`, where `Y180 = diag(-1, 1, -1, 1)`. This mapping was compared with the previously verified 1.2-second native flight clip across all of that clip's 73 samples and 23 bones. The current attack package has 85 samples, each read back against its source JSON. Translation remains in the original authoring units: do not multiply it by the enlarged model scale. Roblox's native Animator applies the model's scale.

## Roblox integration — October 6, 2026

Installed alongside `Animations.FlightLoop` on both `ReplicatedStorage.GalaxyCrateChickenAssets20261002.DragonChickenFlight` and `Workspace.GalaxyCratePreview.DragonChickenFlight`. The mesh, all 23 bones, 10.9193372726 model scale, flight sequence and the world's 11 particle emitters are preserved.

| Clip | Published asset | Native behavior |
|---|---|---|
| FlightLoop | `rbxassetid://107847012846776` | 1.2 seconds, looped, Movement priority |
| Attack | `rbxassetid://91418238280745` | 1.4 seconds, nonlooping, Action priority |

Both assets were created under Kiru Experiences (group `778575811`). `RuntimeAnimations` holds the Animation objects. `Animations` retains editable KeyframeSequences. A native attack source also lives at `ServerStorage.DragonAttackImport20261006.Attack`.

`src/client/GalaxyDragonAnimator.luau` owns the native tracks. `DuckAnimator` discovers models with `GalaxyDragonAnimation=true` and the `ChickenVisual` tag. The flight track plays immediately; setting `AttackStartedAt=workspace:GetServerTimeNow()` then incrementing `AttackSerial` triggers the attack. A local preview can instead set `LocalAttackAt=os.clock()` if `AttackSerial` is absent. The adapter blends in over 0.12 seconds and back to flight over the last 0.14 seconds. It handles hidden, defeated and reduced-motion models and destroys its connections/tracks with the existing lifecycle.

Only these two client modules were synced through `.tools/galaxy-dragon-animation.project.json` on port 34874. Both Studio sources matched their local files byte-for-byte, with exactly one active copy each. Rojo packaging succeeded.

`runtime-check.json` records an isolated real Studio client check through DuckAnimator: both published clips loaded, animated flight changed bones, the attack reached full weight with zero lateral root displacement, a second attack regained full weight, flight resumed at speed 1, reduced-motion/hidden states suppressed playback, stale events were skipped, and cleanup left zero playing tracks. Game bootstraps were temporarily disabled during the check and restored afterward; no player profile was loaded by this check. Test clones were removed. `Roblox-Attack-Contact.jpg` shows the native clip on a temporary clone at the contact frame. A client-only attempt to manually call `StepAnimations` was rejected by its Plugin capability requirement; the visual check used normal runtime evaluation instead.

`AttackContact` remains an animation marker. Damage logic was not added. The regular catalog `Dragon` is Golden Emperor, a different model. OuterSpaceCrate rewards and blue dragon army deployment remain disabled. No experience publication or Git push was performed.

Saved the updated Pet Roll Test to Roblox at `2026-10-06T05:30:34.906Z` (save, not publish). Full authored-place backup: `MyChickenArmy-Dragon-Attack-20261006.rbxl` (5,749,816 bytes), with a matching Studio save log at `2026-10-06T05:31:09.039Z`. `studio-integration-status.json` records asset IDs, scope, checks and backup checksum.
