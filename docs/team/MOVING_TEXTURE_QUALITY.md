# Shared Galaxy and Rainbow materials — October 2, 2026

All visible roaming Galaxies use the same animated world material at manual
graphics levels 5–10. Levels 1–4 use the original static material, as do hidden,
defeated, distant and Reduced Motion birds. Automatic retains the existing
conservative quality policy. Original aura/particle effects remain enabled under
their existing visibility rules. No gameplay, stats or saved inventory changes.

The original authored atlas gave some body faces only 19 pixels at 512 resolution.
Enlarging that image alone cannot recover detail. `FlowingChickenTexture` remaps
only feather UVs into the unused upper half of a 1024 atlas. Two identical 512
pattern tiles let UVs scroll across a seamless boundary. The original lower half
and protected facial UVs stay intact. Galaxy includes the wattle, legs and feet;
Rainbow preserves its normal beak, eyes, red wattle and orange legs/feet.

`ChickenTexturePattern` bakes the continuous rainbow gradient or detailed galaxy
cloud/star field once per active appearance. TweenService owns the repeating phase.
EditableMesh UVs cannot be tweened directly, so the existing render callback copies
the tween phase into one shared mesh per appearance. Galaxy moves 384 UVs; no
per-frame image drawing, pixel loop, texture upload, mesh cloning or extra viewport
is used for roaming chickens. The original 504 vertices, skin weights and live
18-bone hierarchy are retained. The image is immutable after creation.

Galaxy emission is reduced from the authored strength 40 to 0.65 so it does not
wash out the new detail. The old atlas-space normal/metal/roughness maps are not
applied to remapped feather UVs. The complete authored material and mesh return
on fallback. Each active appearance retains one 4 MiB RGBA atlas plus a small
shared mesh; Galaxy also has a 4 KiB emission mask. Engine/GPU overhead is extra.
Temporary pattern/input images are destroyed after loading. Last-owner cleanup
cancels and destroys the tween and releases every shared resource.

`GalaxyTextureAnimator` and `RainbowTextureAnimator` remain the entry points, as
small wrappers over the shared helper. `SpecialChickenVFX` owns their eligibility
and lifetime. `DuckAnimator` supplies one timestamp per frame, so additional birds
reuse that appearance's update rather than doing the texture work again.

## Viewport boundary

The original four-plane mask remains available only for final Galaxy roll offers
at graphics 8–10, via `RollPresentationController.Preview` setting
`GalaxyMaskPreview=true`. Mystery shuffle birds and roaming actors never qualify.
Reveals keep their original mesh for the mask's guard; the shared material is
suppressed on that preview. One viewport covers the body, wattle, legs and feet;
eyes and beak retain their foreground material. This keeps the reference effect
for a focused presentation without adding a viewport for every flock member.

## Observed checks

Fresh isolated Play, actual saved graphics 10, with no quality override during
visual/performance checks:

- Ten additional Galaxies all reached `ready`, shared the same cache, and retained
  18 bones each. With the workbench Galaxy there were 11 shared references.
- Across 1,226 measured frames, the combined Galaxy/Rainbow material Step calls
  had median CPU time 0.103 ms and p95 0.112 ms. Whole-frame intervals were median
  16.65 ms and p95 17.40 ms. These are Studio observations, not GPU attribution or
  a physical low-end-device guarantee.
- A rejected image-copy prototype cost median 7.32 ms for the same material path.
  UV scrolling retained detail and removed that per-frame image work.
- Original vertex positions matched exactly; 120 protected UVs and the entire
  original lower-half pixel buffer matched. The two scrolling tiles were byte
  identical. The displayed image stayed byte identical while UVs moved.
- A real server-created yard Galaxy used the material during walking; all 18
  bones remained and 10 bone transforms changed between observations. Its aura
  played, with foreground eggs visible in front of its ordinary world mesh.
- A focused low-tier test supplied the actual quality controller's level-1 state
  temporarily, then restored its original state. All Galaxies restored their
  original mesh/material, Rainbow stopped, and shared image/mesh resources were
  released. Hidden, distance and Reduced Motion restoration also passed.
- The real Preview method was exercised with a disposable record: mystery had
  no mask; final Galaxy reached `ready` with its original mesh and no shared
  animator; detaching it released the viewport, surface and depth plane.
- Final Edit cleanup check loaded the synced helper, verified all resources
  including the tween reference were nil after the last consumer, restored the
  identical material object and original mesh, and cancelled a pending async
  load without a late attachment. Nine existing quality-policy groups passed.

Screenshots and raw measured results live in
`assets/moving-texture-quality-20261002/`. The prior atlas implementations are
preserved there as `.before.luau` files. Older smoothing tests describe that
historical implementation and are not current regression tests.

All fixtures, diagnostic hooks and camera/UI changes were removed; Play stopped.
The Debug Galaxy grant existed only in the existing session-only test profile.
No real profile, graphics preference, new asset upload, publish or Git push changed.
Source files are saved and synced to canonical Pet Roll Test. After native save
controls recovered, Studio confirmed the unpublished cloud save at
2026-10-03 03:41:24 UTC during the subsequent VFX-audio request.
