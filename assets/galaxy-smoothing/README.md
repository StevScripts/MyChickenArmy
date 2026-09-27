# Galaxy face visibility and texture smoothing

September 25, 2026. Runtime edits are in the canonical codebase and synced through Rojo; no Studio-owned mesh or texture asset was modified.

- `BlenderPetView` creates Galaxy with `Body.Transparency = 0` instead of `0.08`. The eyes, beak and feathers are in the same skinned mesh; the entire mesh must not be made translucent to suggest a galaxy effect.
- `GalaxyTextureAnimator` preserves the 24 authored frames at six keys/second (a four-second loop). It now composites adjacent keys on DuckAnimator's existing render clock, including the last-to-first seam. All chickens share a stable displayed EditableImage and one scratch image; the latter adds at most 1 MiB for a 512×512 RGBA atlas. No per-pixel Luau render loop, new frame connection, asset uploads or speedup of the animation.
- `SpecialChickenVFX` forwards Galaxy updates before its 20 Hz particle/effect throttle. Reduced motion, visibility culling, material restoration and reference-counted cleanup remain in effect.
- Normal TweenService cannot interpolate image pixel buffers. The scratch image's alpha is multiplied by the blend fraction, then composited source-over the current key using native [EditableImage drawing methods](https://create.roblox.com/docs/reference/engine/classes/EditableImage) and [ImageCombineType](https://create.roblox.com/docs/reference/engine/enums/ImageCombineType). Neither the mesh nor its PBR transparency is animated.

## Focused verification

Run `checks.luau` through Studio Flow in Edit context. It uses temporary unparented models/camera/images, destroys them, and never operates Play/Stop or touches player data.

Latest run: 137 assertions passed. All 60 texture samples in one simulated second changed; scheduler forwarding, exact keys, the four-second period, all seam pixel colors/opacity, shared texture identity, reduced/hidden restoration, resumption and last-owner cleanup passed. Native 512×512 compositing averaged approximately 1.71 ms per sample in this Studio Edit run. This is not a client FPS measurement or a guarantee for other devices.

All four runtime modules compiled and matched disk, with one active copy per name. `git diff --check` passed. In-game front/back visibility and actual client render cadence were not visually verified; the observed Play session ended before the read-only live inspection. Use a fresh Play session for already-required modules to reload. No place save or publication was performed by this task.
