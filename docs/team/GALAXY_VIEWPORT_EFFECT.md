# Galaxy quality tiers and viewport masking — October 2, 2026

## Current scope — shared roaming material, reveal-only mask

The later multiple-Galaxy decision supersedes the one-roaming-mask rollout below.
Every visible roaming Galaxy now shares the high-detail UV-scrolled material at
graphics 5–10. Graphics 1–4 retain the original static texture. The expensive
viewport is eligible only for a final Galaxy roll offer explicitly marked
`GalaxyMaskPreview`; mystery shuffles and roaming actors are excluded. The
one-mask cap, whole body including feet, preserved eyes/beak and aura still apply.

See [moving texture quality](MOVING_TEXTURE_QUALITY.md) for current runtime owners,
measurements, screenshots and lifecycle checks. The historical atlas animation,
world-selection behavior and checks described below do not describe the new
shared material implementation.

## Historical rollout and fixes

Implemented for Galaxy Overlord (`StormDuck` / `Galaxy`) only. The first rollout
is intentionally one nearby advanced Galaxy per client; other variants retain
their current effects. Shadow is the next masking candidate. Water, Magma and
Solar Flare should first be evaluated for ordinary animated material effects.

## Runtime owners

- `client/ChickenEffectQuality.luau`: saved graphics preference and measured
  frame-time policy; no server changes or protected graphics APIs.
- `client/DuckAnimator.luau`: supplies the existing frame clock, forwards material
  quality, and updates the mask after the world rig's bones have been posed.
- `client/GalaxyViewportEffect.luau`: one local world-depth masked surface,
  stable selection, native surface occlusion, face preservation and resource lifetime.
- `client/SpecialChickenVFX.luau`: acquires the existing Galaxy atlas only while
  eligible and releases it on static quality, hiding, reduced motion or distance.
  The selected masked chicken uses its original static material underneath,
  avoiding repeated atlas allocation during brief occlusion or loading.
- Existing `GalaxyTextureAnimator` retains its authored animation and material
  restoration. Its source was not changed.

Manual graphics levels 1–4 use static textures; 5–7 use the existing animated
texture; 8–10 use masking. Explicit levels are stable choices: frame rate and
window focus do not override them. Automatic starts static. Its 0.75-second
frame-time average permits promotion after 12 seconds at <=18 ms to animated,
then 30 seconds at <=18 ms to masked. Three seconds above 24 ms for masked, or
33 ms for animated, reduces the tier and its session ceiling together. Automatic
never retries a tier that already exceeded its budget until the graphics setting
changes or a new session starts. This prevents repeatedly enabling the effect
just because disabling it improved FPS. These are initial policy settings, not
physical-device guarantees. Reduced Motion separately suppresses these effects.
Window focus transitions clear Automatic sample history and pause its sampling,
while retaining the current material and resources. This uses Roblox's documented
[window focus events](https://create.roblox.com/docs/reference/engine/classes/UserInputService#WindowFocused).

The advanced effect starts within 65 studs and at least 36 projected pixels.
An existing selection is retained until 70 studs or below 28 projected pixels,
avoiding rapid allocation at the distant boundary. There is no upper size/area
cutoff: zooming in must not swap a nearby chicken back to its static texture.
Selection runs at 10 Hz only when the current bird is no longer
eligible; a passing Galaxy does not take its effect away. Partly offscreen
chickens use native clipping rather than unloading at the first outside corner. One full-screen
ViewportFrame lives in a camera-facing world SurfaceGui with `AlwaysOnTop=false`;
no new ScreenGui is created. The surface follows the near edge of the chicken's
bounds and uses the camera's projection. Foreground geometry, particles and egg
billboards can render in front of it. Camera projection and the 18 bone poses are copied from
the original world chicken. Star/cloud drift uses native looping linear tweens.
The source mesh, rig, opacity, physical actor and gameplay state are unchanged.

## Character2 visual reference correction

The user's supplied 21-second Character2 clip is the visual target: bright
lavender/white clouds and drifting stars inside a black silhouette. Both star
planes and both cloud planes use the original untinted SurfaceAppearances.
The viewport background is pure black. The four reference rotations and wrapped
local offsets were recovered from the reference place's CFrames; the simplified
JSON export had omitted them. Loop periods remain 42.5/120 seconds for the stars
and 75/180 seconds for the clouds, using TweenService. A shared 0.28 pattern scale
fits the cloud detail to the smaller chicken without adding layers or resources.

The initial correction hid Galaxy's external aura while masking. The user's
subsequent VFX report supersedes that behavior: the aura and ordinary stars now
remain enabled at every material quality tier, subject to the existing distance,
hiding and Reduced Motion rules. Only eyes/highlights and beak remain opaque in
the masked mesh. Two historical Studio
screenshots show different running phases:
`assets/galaxy-masking-20261002/galaxy-reference-match-a.jpg` and
`assets/galaxy-masking-20261002/galaxy-reference-match-b.jpg`.

Three focused aura transitions passed. Fresh-client checks confirmed four moving
layers, all 18 mirrored bones, suppressed aura, static resource release and aura
restoration, preserved source material, and clean mask resumption. The isolated
visual fixture selected the masked tier; this is visual/lifecycle validation,
not a device performance measurement. It was removed and the camera, UI and
original quality controller were restored before stopping Play.

## Occlusion and asset limits

The world SurfaceGui depth-tests
against foreground visuals, including `CanQuery=false` geometry and egg sprites.
It replaces the original ScreenGui overlay, which could draw over those objects
and world particles. Its depth is a flat plane near the front of the chicken,
**not the mesh's per-pixel depth**; geometry intersecting that thin depth interval
can still differ from a native material. The old whole-mask raycast fallback was
removed after live tracing showed it alternating between ready and occluded
several times per second during ordinary movement. Occlusion now clips the
covered pixels rather than swapping the entire material. Do not extend this to a whole flock or describe it as native
world-material rendering. The technique can also show transparency
dithering/banding, depending on Roblox's renderer.

The mesh guard requires Galaxy mesh `90513010317322`. A runtime foreground atlas
preserves only the exact eyes/highlights and beak from texture `88919583329083`.
The rest of the atlas is transparent, so the whole body, including the wattle,
legs and feet, shares one continuous galaxy effect in the same ViewportFrame.
This reflects the user's October 2 correction; feet have no separate viewport
or retained foreground texture. Template/texture failures
leave the original chicken visible and permit the ordinary fallback. No per-frame
image generation, asset loading or mesh cloning occurs.

Studio-owned templates: `ReplicatedStorage.PetRoll.GalaxyViewportAssets`.
The four zero-alpha planes and their textures come from **6mikael6's
[ViewportFrame Masking tutorial](https://devforum.roblox.com/t/viewportframe-masking/2964839)**.
Only inert mesh/material assets are used; downloaded demo scripts were inspected,
not executed. Asset IDs, reproduction script and reference are recorded in
`assets/galaxy-masking-20261002/`. No new mesh or texture upload was needed.

## Validation and delivery state

- Normal-game integration: a fresh isolated session granted StormDuck through
  the existing server Debug action. The normal AppController/DuckAnimator
  discovered the physical yard actor, rendered one corrected mask and suppressed
  its redundant animated atlas. This exposed and fixed false obstruction from
  the invisible yard boundary. Five checks against the actual occlusion helper
  passed, including an opaque wall behind an invisible part and the skip limit.
  Six additional injected-focus lifecycle checks passed. Screenshot:
  `assets/galaxy-masking-20261002/galaxy-in-game.jpg`. The visual check temporarily
  supplied the masked tier to the existing controller; the real quality policy
  and camera were restored before stopping Play. No saved inventory changed.
- Whole-body correction: a fresh isolated Play session confirmed all 126 atlas
  tile centers retain alpha only for the beak and eyes/highlights, with one
  viewport and all 18 mirrored bone pairs. Visual check showed the galaxy effect
  across the legs, feet and wattle. Updated screenshot:
  `assets/galaxy-masking-20261002/galaxy-whole-body-preview.jpg`.
- Eight deterministic quality-policy checks passed against the actual module.
- Eleven Studio Edit assertions passed for low-tier allocation, shared ownership,
  cancelled async loads, static PBR restoration and complete image-cache release.
- Eighteen live client assertions passed across rendering, tween movement,
  copied poses, wall occlusion/restoration, one-mask limit, reduced motion,
  distance/hiding cleanup, integrated quality switching and final teardown.
- Final renderer was exercised after a fresh Play restart. Actual DuckAnimator,
  SpecialChickenVFX, quality and mask modules were used together on a disposable
  local chicken. Screenshot: `assets/galaxy-masking-20261002/galaxy-preview.jpg`.
- Studio's background frame intervals around 66 ms triggered the expected
  downgrade. For the final visual acceptance screenshot, the disposable fixture
  supplied 1/60-second policy samples to keep masking visible; user graphics
  settings were not changed. This is **not** a measured masking cost or a low-end
  device benchmark. Physical phones and device-safe-area variants remain untested.
- Source compiled; local diff whitespace check passed. Scoped independent code
  review found no actionable lifecycle issues. The four modules matched their
  single Studio copies at final readback.

Play used the existing `PetRollPlaytestSessionOnly=true` profile isolation.
Temporary models, overlays, images, tweens and fixture connections were removed,
the camera was restored, and Studio returned to Edit. The integrated game and
new templates were saved as a full local place copy at
`assets/galaxy-masking-20261002/MyChickenArmy-Galaxy-Integrated-20261002.rbxl`
(complete Roblox binary file, updated after the Character2 visual correction). The canonical connected place
remains Pet Roll Test, `96683186622050`. No Roblox cloud save/publish, asset upload,
real purchase/profile mutation or Git commit/push was performed. Source and
Studio ownership are released.

## Reopened-place repair — October 2

The user reopened cloud version 136, which contained the synced source but lacked
`ReplicatedStorage.PetRoll.GalaxyViewportAssets`. The earlier full local snapshot
had not saved these Studio-owned templates to the cloud place. The real runtime
reported `assets-unavailable` even at graphics level 10 and the natural masked
tier. This was a delivery omission, not a texture or quality-policy failure.

The four inert templates were restored to the canonical Edit place and the
running isolated session using `install-assets.luau`. The same mesh IDs,
SurfaceAppearance ColorMaps and Transparency alpha modes were read back on the
client. Studio **Save to Roblox** then confirmed “Saved new changes in
\"Pet Roll Test\" to Roblox.” This is an unpublished cloud save; no publish was
performed. A fresh Play session was started afterward. The user's graphics
setting had changed to level 1 during diagnosis; that setting deliberately
selects the original static texture.

After the user requested graphics level 8, it was set through Roblox's Settings
menu and read back as `QualityLevel8`. A Galaxy was granted through the existing
Debug action in the isolated session. The real AppController/DuckAnimator quality
controller naturally selected `masked` with measured frame intervals around
17–18 ms in this Studio session. The real yard actor reached `ready`, with one
visible viewport, four layers and 18 mirrored bones. Screenshot:
`assets/galaxy-masking-20261002/galaxy-repaired-quality8.jpg`. No synthetic frame
samples or quality override were used. This is still not a physical-device
performance benchmark. Temporary diagnostic references and the preview camera
binding were removed, the normal camera was restored, and Play remains running
at the requested level 8. The debug grant exists only in the isolated test.

## VFX and foreground overlap correction — October 2

The user's next playtest exposed two issues with the screen overlay: the mask
explicitly disabled Galaxy's aura, and its raycasts missed non-queryable chicken
meshes and egg billboards. The viewport now uses one invisible, non-interactive
world Part adorned by a PlayerGui-hosted `SurfaceGui` with `AlwaysOnTop=false`,
`MaxDistance=75`, and camera-matched dimensions. A viewport parented under the
Part did not render in the final client check; the explicit PlayerGui host and
Adornee fixed that. Native world depth handles foreground geometry
and sprite occlusion. The original body and its aura remain intact. All other
chicken VFX retain their existing ownership and culling.

The 30-second promotion window now tolerates an 18 ms averaged frame time;
17 ms repeatedly reset recovery on a roughly 60 FPS Studio client. Low manual
graphics settings, the 24/33 ms downgrade thresholds and slow recovery periods
are preserved. Nine deterministic quality checks passed, including normal
60 Hz timing variation after a background slowdown. Source compilation and
Rojo readback passed. Eight focused live assertions passed for world hosting,
four animated layers, 18 bones, simultaneous aura, and complete surface/image/
tween release on static fallback. That lifecycle check supplied explicit tiers
temporarily and restored the real quality controller afterward.

Prototype visual checks showed both a `CanQuery=false` solid obstacle and a
cloned real egg sprite in front of the masked chicken. They also showed the
Galaxy, Glitch, Magma and Rainbow effects running together. All temporary
prototype surfaces, clones, camera bindings and quality overrides were removed.
The flat-depth limitation described above still applies; this is not a measured
mobile performance result.

The revised quality controller naturally recovered to `masked` in a fresh
isolated client at the existing graphics level 10, with about 16.7 ms averaged
frame time. `galaxy-depth-aura.jpg` shows the moving material and original aura
together; `galaxy-depth-occlusion.jpg` shows the deliberately placed non-queryable
bar and actual egg sprite covering the mask. Those shots used the explicit
PlayerGui host before it was copied into source. A final fresh Play after that
source change showed the correct host, texture and aura without reparenting;
an explicit masked tier was used only for that focused lifecycle check. Static
fallback destroyed both the PlayerGui surface and workspace Part and released
the image. The original quality method and camera were restored, temporary
objects were removed, and Studio returned to Edit. No saved player data changed.

Delivery: the final renderer matched Studio at 18,406 bytes (djb2 hash
3,880,212,243). Studio's native log confirmed **Saved new changes in "Pet Roll
Test" to Roblox** at 2026-10-03 00:54:08 UTC after the final host correction.
The save is unpublished. The earlier local `.rbxl` snapshot predates this fix;
the canonical synced source and cloud save are the updated version. No Git
commit/push, publish, or new asset upload was performed.

## Flicker correction — October 2

Live tracing reproduced the user's flicker with graphics held at the masked tier:
the previous renderer alternated `ready:true` / `occluded:false` six times within
about one second while the real yard chicken moved. The whole-mask raycast gate
was redundant with world-surface depth and visibly swapped materials whenever a
sample became obstructed. It is removed. The viewport also no longer receives
a false/true visibility assignment every rendered frame.

Selection now retains its current eligible Galaxy, accepts partially offscreen
bounds and uses separate entry/exit size and distance limits. Quality, hidden/
defeated state, missing assets and Reduced Motion still fall back as before.
Foreground occlusion remains native SurfaceGui depth; no AlwaysOnTop change.

Fresh-client tracing recorded only loading → ready, with no material switches
or renderer rebuilds during movement, repeated crossings by a queryable test
obstacle, and partial screen clipping. A closer eligible second Galaxy did not
steal the selection. Static fallback released the world Part, PlayerGui surface
and image while preserving the aura. Exact frame counts and timing are in
`assets/galaxy-masking-20261002/flicker-validation.json`. These are rendering
regression checks with an explicit tier, not a device benchmark. All diagnostic
wrappers, models, tweens and camera bindings were removed, the original quality
method and camera were restored, and Play stopped. Source compiled and matched
Studio at 16,821 bytes (djb2 4,205,977,704).

Studio confirmed the unpublished cloud save at 2026-10-03 01:03:40 UTC.
No player-profile changes, Git commit/push or publish were performed.

## Normal-quality switching correction — October 2

The preceding forced-tier check missed a second cause. With the actual saved
graphics level 10 and no quality override, live tracing recorded masked → animated
at 2.53 seconds and animated → static at 5.60 seconds. Background Studio frames
were about 67 ms. The FPS policy was overriding the user's explicit preference;
focus loss also returned static and destroyed the renderer. Manual quality is now
stable, focus pauses sampling without changing materials, and Automatic lowers
its ceiling when it downgrades so removing the effect cannot cause a promotion
loop. Only an actual graphics-setting change resets that ceiling.

The upper projected-size and screen-area gates were also removed. They made
ordinary zooming/approaching switch to the original texture. Minimum visible
size, distance, hidden/defeated state and Reduced Motion checks remain.

Nine focused quality checks pass, including every manual level at 5–120 FPS,
repeated focus changes, Automatic cost-feedback stability, and settings cleanup.
Both edited modules compile and match their single Rojo-synced Studio instances.

A fresh isolated Play session used the real AppController/DuckAnimator, saved
graphics level 10 and actual frame times throughout. No quality method override
or synthetic dt was used. The real roaming yard Galaxy stayed ready for 209.55
seconds / 10,936 frames after initial loading, with zero texture-state switches,
one renderer generation, one surface/viewport, four playing layers and 18 mirrored
bones. Repeated camera zooms covered 3.8–13 studs; projected bounds reached 746
pixels and 53% of viewport area, exceeding the previous exit thresholds. The
eight original/generated emitters remained enabled and screenshot inspection
showed the whole-body mask, normal beak/eyes and aura. Actual frame intervals
included a 1.017-second hitch without changing manual quality.

Evidence: `assets/galaxy-masking-20261002/normal-quality-validation.json` and
`galaxy-stable-normal-quality.jpg`. This demonstrates the switching fix in Studio,
not a physical low-end device performance benchmark. Diagnostic wrappers, camera
binding, observer and zoom tween were removed and the original camera restored
before returning to Edit. No real profile was changed. Graphics remains at the
pre-existing level 10; these checks did not change the player's setting.

Delivery: the final Edit readback matched `ChickenEffectQuality` at 5,465 bytes /
djb2 2,653,772,251 and `GalaxyViewportEffect` at 16,823 bytes / djb2 4,215,131,715.
All four asset templates are present. Studio's native log confirmed the
unpublished **Save to Roblox** at 2026-10-03 01:29:00 UTC. No publish, asset upload,
Git commit or push was performed.
