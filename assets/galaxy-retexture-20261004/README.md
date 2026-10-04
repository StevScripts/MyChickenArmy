# Galaxy chicken retexture — October 4, 2026

Astronaut, Alien and Dark Matter have new materials. The unique Dragon is unchanged.

## Deliverables

- `Galaxy-Retextured.blend`: packed editable Blender project, opens on the three-character review scene.
- `Galaxy-Retexture-Preview.png`: actual Blender render of the completed materials.
- `exports/`: three GLBs with embedded textures and the existing 18-bone rigs.
- `textures/`: 2048px color, normal, metalness, roughness, emission and ORM atlases.
- `generated/`: built-in image generator material sources; exact prompts in `image-generation-prompts.json`.

## Material direction

Astronaut has ivory suit panels, navy inset modules, cyan indicators, muted gold trim and slate-blue feathers. Alien has jade skin, mint antenna tips, dark violet accents and clean black-teal eyes. Dark Matter has obsidian-purple nebula surfaces, restrained cyan veins, icy eyes and lavender accents.

## Preservation and checks

Mesh positions, topology, weights and authoring UV coordinates were preserved. Export accessory UV names were normalized to UVMap so their coordinates sample correctly through the primary texture channel; old exports placed accessory UVs in a second channel. The Alien's redundant eye/glint overlay surfaces have zero opacity, retaining the eyes painted on the head. Opaque body materials cull backfaces, removing the coincident transparent eye-box artifact. No vertices were removed.

Original geometry/weights/UV signatures match after material baking. GLBs were checked against original exports for geometry and weights; final files retain 18 joints each. Final GLB material flags and file sizes are recorded in `final-export-validation.json`. The actual final Blender render and viewport were inspected.

## Roblox status

IMPORT NOT COMPLETED. Studio opened the Astronaut import preview, but native computer control began returning `noWindowsAvailable` for clicks. No retextured model has been inserted, and existing Studio assets remain unchanged. User was asked to foreground Studio and keep the Mac awake. No experience publication, crate activation or gameplay integration was performed.

When resuming: re-open the final GLBs from this exports folder. Import as Model, Upload to Roblox, creator Kiru Experiences (778575811), Add to Workspace, Keep Zero Influence Bones, Set Pivot to Scene Origin, Anchored. Do not import as Package. Preserve original staged and world models under a new ServerStorage.GalaxyRetextureBackup20261004 before replacing them. Preserve original visible sizes and world placements. Astronaut/DarkMatter old model scale is 0.6701631546; Alien old world model scale is 1 (4.89 studs high). Verify SurfaceAppearance.AlphaMode is Transparency, especially for Astronaut visor and Alien invisible overlay faces. Keep DragonChickenFlight scale 10.9193372726 and its entire rig/animation unchanged. Capture a Studio lineup and save a separate full .rbxl file after integration.

Existing staged folder: ReplicatedStorage.GalaxyCrateChickenAssets20261002. Alien old world path: Workspace.GAME EXPORT | Alien Chicken.002.

## Reproduction sources

Python sources are archived here for reference; their working-root paths currently point to /Users/stevin/.codex/artifacts/galaxy-retexture-20261004 and they expect the reconstructed live Blender driver namespace. The packed .blend and GLBs are standalone deliverables. Apply alien_eye_cleanup.py and alien_backface_cleanup.py after any fresh Alien bake, before exporting. Do not run a separate background Blender against the live scene.
