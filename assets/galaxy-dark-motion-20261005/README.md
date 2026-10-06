# Dark Matter flowing texture — October 5, 2026

This asset reuses the approved October 4 Dark Matter chicken and generated plasma artwork. Its body, neck, and head have flowing plasma. The white eyes, lilac beak, comb, feet, and feather wings remain fixed. The mesh geometry, skin weights, and 18-bone rig are preserved.

`Galaxy-Dark-Matter-Motion.blend` contains the packed material maps and a dedicated runtime export scene. `exports/dark-matter-flow.glb` is the Roblox import file. `build_dark_motion.py` reconstructs the export from the approved `galaxy-retexture-v2-20261004/Galaxy-Reference-Matched.blend`; it uses native Blender emission renders to create the maps and never edits image pixels in Python.

The atlas is 2048 × 2048. The upper half contains two identical horizontally mirrored plasma tiles, so advancing the UVs by half the atlas width returns to the same pattern without a wrap seam. The approved static atlas occupies the lower half. All six PBR maps use the same layout.

Roblox runtime contract:

- Model attribute: `GalaxyTextureMotion = "DarkMatter"`.
- Skinned MeshPart name: `Body`.
- Animated engine UVs: initial `0 < U < 0.5` and `0 < V < 0.5`.
- Protected engine UVs: `V >= 0.5`; never change them.
- Drive `U` from its original value to `U + 0.5` with an eight-second, linear, repeating TweenService phase.
- Blender uses the opposite V orientation; the exporter flips V. `motion-export-report.json` checks the actual exported glTF accessor values.

The export report records 672 authored vertices, 18 joints, 72 moving glTF UVs, 1080 protected glTF UVs, and an unchanged approved-source signature. Its absolute paths identify the working artifact directory; this canonical directory is an identical durable copy.

Studio import, rendering, and runtime motion validation are complete. This asset does not enable the Galaxy crate, purchases, or gameplay rewards.

Sources:

- Approved model/materials: `/Users/stevin/.codex/artifacts/galaxy-retexture-v2-20261004/`.
- Source object manifest: `/Users/stevin/.codex/artifacts/galaxy-retexture-20261004/source-manifest.json`.
- Existing generated plasma: `/Users/stevin/.codex/artifacts/galaxy-reference-textures/generated-textures/plasma.png`.

## Completed Studio integration

All four chickens are saved in canonical **Pet Roll Test** (place `96683186622050`). Their visible lineup is `Workspace.GalaxyCratePreview`; reusable templates are in `ReplicatedStorage.GalaxyCrateChickenAssets20261002`. The previous models and raw imports remain in `ServerStorage.GalaxyRetextureBackup20261005`.

Astronaut, Alien, and Dark Matter use matching display scale `0.6701631546`. Dragon is uniformly enlarged 2.5× from the recovered model: its mesh is 8.75 studs tall, with all 23 bones and the original 73-keyframe, 1.2-second looping `Animations.FlightLoop` intact. No published flight AnimationId was added.

The imported Dark Matter mesh is `rbxassetid://80179324175005`; its color map is `rbxassetid://115935302192700`. All material IDs and scales are recorded in `roblox-asset-manifest.json`.

`GalaxyCrateVisuals` and its AppController hooks match the local code after selective Rojo sync. Edit-time checks confirmed that 72 UVs move and 1080 protected UVs stay fixed, with the same Bone and SurfaceAppearance instances and unchanged part size/pose. A focused client Play check confirmed automatic discovery, advancing native tween phase and frame updates, reduced-motion pause/resume, and complete resource cleanup. Game bootstraps were temporarily disabled during that isolated check and restored afterward, so it did not run gameplay or player-data saves.

**Save confirmed:** Studio reported `Saved new changes in "Pet Roll Test" to Roblox.` at 2026-10-06 02:49:58 UTC (October 5 locally). This used **Save to Roblox**, not Publish. The full native backup is `MyChickenArmy-Galaxy-Updated-20261005.rbxl`, saved at 02:51:01 UTC. Its size and SHA-256 are in `studio-integration-status.json`.

`Galaxy-Roblox-Lineup.png` shows the four models in the actual Studio viewport. `DarkMatter-Roblox-Phase0.png` and `DarkMatter-Roblox-Phase25.png` show the changed energy pattern with fixed facial details. Studio's View → Show UI is toggled off to leave the model preview visible; the actual `StarterGui.PetRollGui.Enabled` remains true.

The assets remain staged for later rolling-box hookup. Purchases, rewards, and public-server rollout are outside this import task. The moving texture runs during Play; a static Edit viewport shows its first frame.
