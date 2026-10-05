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

Studio import, rendering, and runtime motion validation are pending. This asset does not enable the Galaxy crate, purchases, or gameplay rewards.

Sources:

- Approved model/materials: `/Users/stevin/.codex/artifacts/galaxy-retexture-v2-20261004/`.
- Source object manifest: `/Users/stevin/.codex/artifacts/galaxy-retexture-20261004/source-manifest.json`.
- Existing generated plasma: `/Users/stevin/.codex/artifacts/galaxy-reference-textures/generated-textures/plasma.png`.

## Studio integration checkpoint

Astronaut was imported and visually checked in canonical Pet Roll Test on October 5. Its old world and template instances are preserved in `ServerStorage.GalaxyRetextureBackup20261005`. Alien/Dark Matter import, Dragon recovery, runtime sync/validation, and native/cloud place saving remain pending because the native UI bridge is returning `noWindowsAvailable`. See `studio-integration-status.json`. The local art and runtime files are saved; do not assume the open place or Roblox cloud has been saved.
