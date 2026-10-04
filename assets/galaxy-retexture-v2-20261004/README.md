# Galaxy reference-matched materials v2 — October 4, 2026

Supersedes the rejected muted October 4 retexture. User wanted the richer textures of the earlier generated concept images. Original reference is references/original-lineup.png (top row).

- Astronaut: white/royal blue suit, cobalt-violet galaxy face, yellow-gold details, cyan lamps.
- Alien: electric lime skin, emerald patches, vivid purple appendages, glossy eyes with lime highlights.
- Dark Matter: deep violet/plum cells with bright magenta plasma, white-pink eyes and a pink comb.

The existing image-generated plasma/cosmic/feather sources were reused; no new image generation was needed. Original built-in image-generation prompts are preserved in source-image-generation-prompts.json. Reference materials were revised and baked in Blender using reference_materials.py plus atlas_tools.py. Materials preserve all original mesh geometry, weights, rigs and authored UV coordinates, with UV channel naming correction on export copies. See material-validation.json and export-validation.json. Each model retains 18 joints. Dragon is untouched.

Galaxy-Reference-Matched.blend is packed and editable. Galaxy-Reference-Matched-Preview.png is a real Blender render. Exports contain three GLBs with embedded maps. Separate PNG maps are included alongside the project.

Preview uses Blender Standard color management, exposure 0, restrained studio lighting and emission strength 2.2. No glow compositor or external effects were added. This is not an in-game screenshot, and exact in-game emission/lighting remains unverified. Studio import is still pending from the previous turn's native-window-control failure. No gameplay code, box activation or publication occurred.

The previous muted version remains in assets/galaxy-retexture-20261004. Use this v2 folder for future imports. Preserve the existing model sizes, pivots and backups during integration, including the enlarged Dragon. Confirm SurfaceAppearance transparency on Astronaut's visor and Alien's invisible legacy eye overlay surfaces, and keep body backface culling.

The shader and export scripts preserve working paths under ~/.codex/artifacts/galaxy-retexture-v2-20261004 and expect the reconstructed live Blender driver namespace. The packed Blender project and GLBs are standalone.
