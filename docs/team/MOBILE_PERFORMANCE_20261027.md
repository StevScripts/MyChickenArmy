# Mobile performance and load (October 27, WS6)

Contract for the client performance tiers, the animation and effect budgets, the lighter
loading path and the performance telemetry. Plan and evidence:
[retention-20261027/WS6-performance.md](retention-20261027/WS6-performance.md). Integration:
[RETENTION_PLAN_20261027.md](RETENTION_PLAN_20261027.md).

Why: a third of new phone sessions average under 20 FPS, and that group keeps 15% at 3 minutes
and wins Cluck Camp 7% (phones at 20+ FPS play like every other platform). The biggest cost we
control is client Luau per frame (about 2 ms on a Mac, roughly 15 ms on a low-end phone), mostly
the chicken presentation loop, plus a loading veil that waited on 549 s of music.

Owner rules kept: game feel stays (budgets lower counts and rates, never a whole effect class;
the nearest chickens always animate at full rate; every interaction still animates with VFX and
sound), one layout for every device (tiers never change a position or size), voxel chickens and
voxel eggs only, reduced motion wins over every tier, the camera stays with the player.

## Switches (`Config.Performance`)

| Key | Default | Off / nil restores |
|---|---|---|
| `TiersEnabled` | true | `PerfTier` pins "high"; WorldFeel and CoinBurst go back to the old touch/desktop rule |
| `AnimLOD` | true | DuckAnimator steps every rig every frame with no particle cap (Oct 26 behaviour) |
| `VeilCapSeconds` | 4 | nil: the veil waits for the whole preload |
| `StagedBoot` | false | not used yet (Wave 2) |

Studio only: `ReplicatedStorage.PetRoll:SetAttribute("PerfTierOverride", "low" | "mid" | "high")`
forces a tier (cleared with nil).

Tuning keys still live as defaults inside `src/client/PerfTier.luau` (move them into
`Config.Performance` once Studio captures confirm them): `AVERAGE_SECONDS 1.0`,
`DEMOTE_FRAME 0.040` for `DEMOTE_SECONDS 4`, `PROMOTE_FRAME 0.020` for `PROMOTE_SECONDS 20`,
`CRITICAL_FRAME 0.045` for `CRITICAL_SECONDS 10`, `RECOVER_FRAME 0.028` for
`RECOVER_SECONDS 30`, `HITCH_FRAME 0.1`, `PHONE_SHORT_SIDE 700` and the budget table below.
DuckAnimator keeps `RANK_SECONDS 0.1`, `SLEEP_HZ 1`, `FX_MIN_HZ 10`, `SCREEN_MARGIN 0.15`,
`SCREEN_PAD 4`; EggController `PARK_REFRESH 0.5`; LoadingController `SKIP_AFTER 4`,
`PARK_OUT 70`, `PARK_UP 55`; LeaderboardBoards `BUILD_DISTANCE 200`.

## PerfTier (`src/client/PerfTier.luau`)

Interface for every stream that adds VFX or motion (no private budgets):
`PerfTier.Start()` (bootstrap, first), `PerfTier.Get(): "low"|"mid"|"high"`,
`PerfTier.Critical()`, `PerfTier.Budget()`, `PerfTier.Changed:Connect(fn(tier))`,
`PerfTier.Stats()`, `PerfTier.Enabled()`. Pure state machine for tests:
`PerfTier.NewState`, `PerfTier.Advance(state, dt)`, `PerfTier.Initial(savedLevel, touchOnly, shortSide)`.

- Start: a manual graphics level fixes the ceiling (1–4 low, 5–7 mid, 8–10 high). Automatic:
  touch-only with a short side under 700 px starts low, touch-only tablets mid, the rest high
  (a touch device whose viewport is still unknown at boot starts low and moves to mid once it
  reads as a tablet).
- Heartbeat EMA of the frame time (τ 1 s; frames over 1 s and unfocused windows reset it).
  Under 25 FPS for 4 s drops a tier and lowers the ceiling (never re-promoted this session);
  50+ FPS for 20 s climbs one tier up to the ceiling. Critical: low and under 22 FPS for 10 s;
  clears after 30 s at 36+ FPS.
- Lighting (local copy only): Bloom and SunRays follow the budget; GlobalShadows goes off only
  while critical. Authored values are remembered once and restored on promotion.

| Budget key | low | mid | high |
|---|---|---|---|
| `animFullRadius` (every frame) | 30 | 45 | 60 |
| `animMidRadius` / `animMidHz` | 70 / 15 | 100 / 20 | 120 / 30 |
| `animFarRadius` / `animFarHz` | 120 / 5 | 150 / 8 | 170 / 10 |
| `animFullMax` (nearest at full rate) | 10 | 20 | 999 |
| `offscreenHz` | 2 | 4 | 6 |
| `fxMaxChickens` (nearest on screen with particles) | 6 (3 critical) | 12 | 24 |
| `fxCull` (studs, min with the quality setting) | 70 | 110 | 400 |
| `fxRateScale` | 0.5 | 0.75 | 1 |
| `eggBobRadius` / `eggHz` | 40 / 20 | 80 / 30 | 120 / 60 |
| `podiumOtherPlotHz` (Wave 2) | 4 | 10 | 30 |
| `worldFeelLimit` | 8 | 14 | 28 |
| `coinsMaxActive` | 8 | 14 | 28 |
| `menuBlur` / `bloom` / `sunRays` | off / off / off | on / on / off | on / on / on |
| `beacon` (WorldFeel:Beacon) | on (off while critical) | on | on |
| `textureCeiling` (ChickenEffectQuality Automatic) | static | animated | masked |
| `hillVfxRadius` (Hill sparks pause beyond) | 150 | – | – |

## What each system does

- **DuckAnimator** (P2). Every 0.1 s each record is ranked by camera distance and an on-screen
  test (frustum dot products, 15% margin, 4-stud pad). On screen: every frame within
  `animFullRadius` for the nearest `animFullMax`, then `animMidHz`, `animFarHz`, then 1 Hz
  beyond `animFarRadius`; off screen `offscreenHz`. V3 rigs now follow the same schedule (they
  used to pose every bone each frame within 170 studs). A faster rate or a particle change
  applies at once; Celebrate steps the rig next frame. Only the nearest `fxMaxChickens` on screen
  within the cull run particles, and those step at least 10 Hz. One cached `GetAttribute` per
  model (invalidated by `AttributeChanged`) is shared with SpecialChickenVFX, RareChickenVFX and
  VoxelChickenAnimator.
- **SpecialChickenVFX / RareChickenVFX**: `Step(..., fxAllowed, rateScale)`. Outside the budget
  the particles, beams and lights switch off like distance does; the animated texture and the
  mutation tint stay. Emitter rates multiply by `fxRateScale` (with the calm Giant rate).
  The VFXLoop sound rule (42 studs) is unchanged.
- **VoxelChickenAnimator**: dt clamp 0.25 (was 0.15) so a 4–5 Hz rig keeps its clip speed. The
  plan's "coarse mirror" mode was not built (it needs a profile first).
- **ChickenEffectQuality**: Automatic never rises above the tier's texture ceiling (not counted as
  a failure, so it climbs again with the tier). Manual levels are unchanged.
- **Eggs**: settled eggs bob at `eggHz` inside `eggBobRadius` of the camera; farther eggs park
  (no bob) and re-face the camera twice a second. Hover, flights and the lay pop stay every
  frame. `EggView:Set` skips the write when position, size, tilt and a 5° facing step match.
- **WorldFeel**: `Limit()` = `worldFeelLimit`. New `WorldFeel:Beacon(position, color?, seconds?)`
  for WS7: a client-local 2 × 140-stud Neon cylinder that fades in and out with one tween and a
  positioned "RareFind" cue; skips `Near`, takes a slot, one at a time, still under reduced
  motion, off while critical.
- **CoinBurst**: coins alive at once capped by `coinsMaxActive`; the rest counts in at once.
- **HillIntro**: the Hill sparks' emitter rates scale by `fxRateScale`; on low they pause while
  the camera is over 150 studs from the arena (never during the film).
- **LeaderboardBoards**: a board's SurfaceGui is built when the camera first comes within 200 studs
  (checked once a second) instead of all 18 at boot.
- **AppController** (one hunk): `SetMenuBlur` keeps owners but uses blur size 0 when
  `menuBlur` is off; the loading veil keeps its blur.
- **ChickenTexturePattern** (P8 path only): `Pattern.ImageIds.Galaxy/Rainbow` (nil today). When
  set to an uploaded 512 × 512 image it is used instead of the Luau bake; any failure falls back.

## Loading (P3)

- Bootstrap order: `PerfTier.Start()`, `AnalyticsClient.Start` (spawned), `load.phase boot`,
  LoadingController, AppController, `load.phase app`, `loading:Bind(app)`.
- Preload: LoadingOverlay, the guide card (`Shell/OTHER/CommanderGuide`), the HUD only when the
  player is not mid-tutorial, sound folders Collection/Rolling/UI (no Music; it streams on
  first play), Intro only when eligible, and from the own plot only `RollStation`(s) and
  `Pets`. One `ContentProvider:PreloadAsync` with a per-asset progress callback.
- The veil lifts at most `VeilCapSeconds` after the profile is ready (`load.phase timeout`); the
  preload carries on behind it. SKIP shows after 4 s.
- Phones and the low tier do not orbit: the camera parks on a still, high three-quarter view
  of the player's plot once the state names it (the blur and breathing logo stay). Streaming
  centres on the own plot as soon as it is known (desktop keeps its orbit).

## Telemetry (schema 16)

Client report (`AnalyticsClient`): first report at 4 s (was 8), started before the app.
New fields: `window` ("load" for the first report and while the veil is up, "play" after; the
window restarts when the veil lifts), `tier`, `critical`, `demotions`, `hitches` (frames over
100 ms), `focusLost`, `frameMsP90`. Client events: `load.phase` boot / app / profile / assets /
timeout (plus the observer's gui / ready). The client allowlist also gained the version-16
events `coins.gated`, `moment.seen`, `moment.missed`, `invite.sent`.

Server (`Analytics:ClientReport`): `perf.fpsLoad|<platform>`, `perf.fpsPlay|<platform>`,
`perf.fps.perfTier.<tier>` (windows with focus lost are left out and counted in
`perf.focusLost|<platform>`), `perf.tier.<tier>|<platform>` (first report), `perf.demoted|` and
`perf.critical|<platform>` (once a session), `perf.hitches|<platform>` (count bucket),
`perf.frameMsP90|<platform>` (frameMs bucket). `ui.load.<phase>|<platform>` beside the existing
`ui.load.<phase>` (buffered until the first report names the platform). Journey keys: `fl`
(load-window FPS), `fp` (mean play-window FPS), `tier`, `fo` (focus lost), `lr` (veil-lift
seconds). `AnalyticsReport` adds `summary.perfTiers` (tier mix by platform, FPS by tier,
demoted/critical/focusLost, load phases by platform with the share over 10 s) and two flags:
Mobile play-window median FPS at 30 or less (high) and over 10% of Mobile veils lifting after
10 s (medium).

Success metrics (2 days of new sessions after release): Mobile sessions under 20 FPS 33% → ≤15%;
Mobile `fpsPlay` under 30 37% → ≤20%; Mobile Cluck Camp wins 29% → ≥35%; `ui.load.ready` over
10 s 9.4% → ≤4%. Guardrails: desktop/console FPS, tablet Cluck Camp, `err.client` sources and the
Mobile share over 1.5 GB must not get worse.

## Not in this wave

- P4 podium-preview LOD in `RollPresentationController` (Wave 2, after WS4 merges; budget key
  `podiumOtherPlotHz` is ready).
- P7 `WorldIndex` and `StagedBoot` (Wave 2, after measuring P1–P5).
- P8 needs Stevin's two uploaded 512 × 512 images (Galaxy and Rainbow fields exported from the
  current generator); then set `Pattern.ImageIds`.
- The VoxelChickenAnimator coarse mirror mode (only if a profile shows bone writes still
  dominate).

## Lead checks in Studio (none of this was run; no Studio access in WS6)

1. Baseline before merging, then after: plan §6 scenarios A (fresh profile) and B (full yard,
   4 players), script profiler 5–10 s on client-1, micro profiler 2 s, `get_scene_analysis
   triangle_composition`. Targets on the Mac: client Luau ≤ 0.8 ms/frame, DuckAnimator ≤ 0.35 ms,
   EggController ≤ 0.10 ms; fresh-profile veil lift ≤ 3 s.
2. Force each tier with `PerfTierOverride` and play the feel script: pull the lever, take the
   chicken, tap 3 eggs, sell, feed a chicken, attack Cluck Camp. Every step animates with VFX
   and sound; chickens within 30 studs walk and idle smoothly on low; reduced motion still wins.
3. Turn the camera quickly past a flock on low: chickens coming into view should update within
   about 0.1 s and particles appear on the nearest six only.
4. Loading on a phone emulation (and with `Graphics quality 1`): the camera parks over the own
   plot (no island orbit), the veil lifts ≤ 4 s after the profile, music starts later without
   a gap or error, the HUD appears normally for a returning profile.
5. A menu on low shows the dim without the blur; on mid/high the blur is unchanged.
6. Bloom/SunRays off on low, back on after promotion; GlobalShadows only off while critical.
7. Leaderboards on other plots build when walked to; the own plot's boards show at spawn.
8. `print` `[PerfTier] start …` appears in Studio output; check `perf.*` keys in the
   `_Studio` ledger after a playtest (`AnalyticsReport`).
9. Verify property names on the live engine: `UserGameSettings.SavedQualityLevel`,
   `BloomEffect/SunRaysEffect.Enabled`, `Lighting.GlobalShadows`,
   `AssetService:CreateEditableImageAsync(Content.fromUri(...))` (P8 path only).

## Studio-only work for Stevin (P6, P9; WS6 cannot make these)

In Edit, then save; publish only on his own request with "Migrate To Latest Update":

1. **Shadows**: `CastShadow = false` on every part under `Decor`, the plot fences, rails, grass
   tufts and Lane trims (keep chickens, characters, roll machines and big landmarks). The
   shadow pass is 111 of 188 draw calls and 103K of 147K triangles; expect under half. Edit the
   template the AuthoredMap clones (`src/server/AuthoredMap.luau` names it).
2. **Decor studs**: replace the 1,959 `Texture` objects (rbxassetid://6372755229) with one
   `MaterialVariant` in `MaterialService` (stud ColorMap on the parts' base material) and set the
   parts' `MaterialVariant`. World geometry only; the UI keeps `UITheme.Studs`.
3. Move `StarterGui.GUI` and `StarterGui.MainGUI` to `ServerStorage.UIReference` (3,744 instances
   cloned into every player; no code reads them). Then update the AGENTS.md line about the
   restored `StarterGui.GUI.FRAMES` to the new path.
4. Lights: 70 PointLights; keep `Shadows` off and remove or merge decorative ones under 4 studs
   of range. Target 40 or fewer.
5. Check the Hill VFX template's emitter `Rate` (210/s "Cyberpunk Sparks") is intended.
6. Later (after P7 ships and is tested): `StreamingTargetRadius 512`, `StreamingMinRadius 128`,
   chicken models `ModelStreamingMode Atomic`; test 6 players on opposite plots first.
7. Upload the two pre-baked 512 × 512 pattern images (P8) and send the ids.

## Done in Studio (October 27, lead, on Stevin's request)

- Shadows: `CastShadow=false` on 5,942 of the map's 8,471 shadow-casting parts (every part
  under 2 studs, parts under 6 studs outside trees, Decor props under 12 studs outside trees,
  and anything named fence/rail/grass/trim/flower/bush). Trees and large structures keep their
  shadows (2,529 parts). One ChangeHistory waypoint; undo restores it.
- Reference GUIs: `StarterGui.GUI` and `StarterGui.MainGUI` (3,744 instances, all 15 scripts
  disabled, no code reads them) moved to `ServerStorage.UIReference`.
- Not done, on purpose: the stud Textures (1,844 parts, 2,076 Textures) are 80%-transparent
  dark overlays tiled 4–8 studs per part; a MaterialVariant cannot reproduce a translucent
  overlay without new art, so the swap would visibly change the island. Needs an art call.
- Lights: the edit-time map has no lights; the runtime ones come from chicken/VFX templates.
  Nothing trimmed.
- Hill sparks template rate is 150/s (not 210); PerfTier scales it by tier.
