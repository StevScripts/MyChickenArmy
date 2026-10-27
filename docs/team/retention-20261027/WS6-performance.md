# WS6 — Mobile performance and load time (plan, October 27)

Owner: WS6 worker (research + plan only; nothing in the repo or Studio was changed).
Data: `scratchpad/quit/journeys27.json` (903 journeys, 847 new), `summary125.json`, `raw125.json`
(live 1.25.0, Oct 26–27). Measurements: Pet Roll Test (place 96683186622050) solo playtest on
Stevin's Mac, dev profile (tutorial done, flock of effect chickens), read-only evals, script
profiler, scene analysis. The playtest was stopped; nothing was saved.

**Verdict in one line:** the whole mobile gap is the one-third of phone sessions running under
20 FPS. Phones at 20+ FPS play exactly like tablet/console/desktop. The main cost we control is
client Luau per frame (about 2 ms on a Mac, roughly 15 ms on a low-end phone), plus a loading veil
that waits on about 9 minutes of music. Fix order: (1) a measured performance tier that budgets
animation, VFX, eggs and podiums by distance, screen and FPS, (2) a lighter loading path,
(3) Studio-side render cuts (shadows, the 1,959 decor Textures).

---

## 1. Problem and evidence

### 1.1 What the FPS field is
`AnalyticsClient` counts Heartbeat frames starting from `AnalyticsClient.Start()`, which the
bootstrap calls *after* `AppController.new()` and `app:Start()`. It sends the first report 8 s
later, then one every 60 s. The journey `fps` is the mean of the reports.
Consequences:
- A session under about 68 s has exactly one sample: the **load window** (the veil orbit,
  preload, streaming and the first card).
- "Unknown" platform means the client never sent that first report. Those players left within
  about 8 s of app start, or before the app started at all.

### 1.2 FPS and ping by platform (new sessions, journey mean FPS)

| Platform | n | FPS p10 | p25 | median | p75 | <30 | <20 | ping median | ping p90 | median session | <60 s quits |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Mobile | 413 | 0 | 15 | 29 | 46 | **52%** | **33%** | 129 ms | 330 ms | 131 s | 23% |
| Tablet | 210 | 21 | 37 | 52 | 57 | 15% | 9% | 68 ms | 230 ms | 138 s | 22% |
| Console | 115 | 32 | 38 | 49 | 56 | 7% | 3% | 73 ms | 216 ms | 169 s | 20% |
| Desktop | 70 | 24 | 38 | 53.5 | 59 | 14% | 6% | 101 ms | 319 ms | 187.5 s | 23% |
| Unknown | 39 | – | – | – | – | – | – | **1,782 ms** | 5,472 ms | 10 s | 92% |

Per-report histograms (ledger `perf.fps|Mobile`, Oct 26+27, 5,252 reports):
- 35% of reports are 30 FPS or lower; 20% are 20 or lower; 9% are 10 or lower.
- `perf.fpsMin|Mobile`: 29% of reports had a one-second window at 10 FPS or lower (hitches).
- `perf.fps.tier.Low` (Oct 27): 77% of reports are 30 FPS or lower.

Steady state (sessions of 180 s or more, at least 3 reports): Mobile median 33 FPS, 37% under
30, 12% under 20. Tablet median 57 (7% under 30), Console 56 (4%), Desktop 56 (3%). Phones that
stay are still slow during gameplay, not only at load.

### 1.3 Session length and progress by FPS bucket (new sessions)

| Group | n | survive 60 s | 180 s | 300 s | 600 s | won Cluck Camp (mx 14 or more) | finished tutorial (mx 8 or more) |
|---|---|---|---|---|---|---|---|
| Mobile under 20 FPS | 136 | **59%** | **15%** | **5%** | 2% | **7%** | 46% |
| Mobile 20–40 FPS | 140 | 91% | 59% | 39% | 19% | 42% | 83% |
| Mobile 40+ FPS | 137 | 82% | 52% | 35% | 12% | 37% | 78% |
| Tablet/Console/Desktop | 395 | 78% | 46% | 32% | 12% | 41% | – |

Finer buckets, all platforms (median session): under 5 FPS 53 s (57% leave before 60 s);
5–15 FPS 69 s; 15–25 FPS 110 s; 25–35 FPS 257 s; 45+ FPS 190 s.
- Phones at 20 FPS or more match the other platforms. The phone deficit (Cluck Camp 29% vs
  about 41%) comes entirely from the 33% of phone sessions under 20 FPS.
- Counterfactual, correlational only: if the under-20 phones won Cluck Camp at the 20+ rate
  (40%), phone Cluck Camp would rise from 29% to about 40%, about +45 players per 847 new
  sessions.
- Caveat: a short session has only the load-window sample. Some of the "under 5 FPS" group may
  be players who backgrounded the app while it loaded (Heartbeat stops, `os.clock` keeps
  running). Section 5 adds the telemetry to separate this.
- Exit step for phones under 20 FPS: Roll (card 1) 43, Complete 31, Start 11, Recruit 9. For
  40+ FPS phones: Complete 41, TipNextCamp2 33, Roll only 6. **Slow phones leave on card 1.**
- Ping does not separate phone sessions: ping under 100 ms gives a 195 s median, 250+ ms gives
  189.5 s. Network matters only for the Unknown group (ping median 1.8 s).

### 1.4 Under-one-minute quitters (214 new sessions)
- By platform: Mobile 93, Tablet 46, Unknown 36, Console 23, Desktop 16.
- 67 (31%) had load-window FPS under 20, and 36 (17%) never reported (Unknown). About half of
  sub-minute quits carry a load or performance signal. 97 of the 214 never got past card 1
  (mx 2).
- Phone sub-minute quits by FPS: under 5: 32; 5–15: 19; 15–25: 9; 25–45: 13; 45+: 20.

### 1.5 Load time (ledger)
- `load.readySeconds` (server: join to first guide card with a character), Oct 27: 55% at 5 s
  or less, 28% at 5–10 s, **17% over 10 s**, 4.5% over 20 s.
- `ui.load.ready` (client `time()` when the veil lifts): 55% at 5 s or less, 35% at 5–10 s,
  9.4% over 10 s.
- `ui.load.gui` (AnalyticsUiObserver start, about when `app:Start` returns): 94% at 5 s or less.
  The UI build is not the main wait. The wait sits between the UI build and the veil lift,
  which is the profile load plus `PreloadAsync`.
- `load.serverSeconds`: 100% at 5 s or less, so the profile load is fast.
- Neither load metric is split by platform today (section 5 fixes this).
- Memory: `perf.memMb|Mobile` is over 1 GB in 63% of reports and over 1.5 GB in 18.5%. That
  sits close to the out-of-memory kill line on 3–4 GB phones. A memory kill looks like a quit.

---

## 2. Root cause: measured and estimated costs

Measurement notes:
- Studio on an M-series Mac. Luau on a low-end Android or older iPhone runs about 6–10× slower;
  I use **×8** for the phone column. That is an estimate, not a device measurement.
- Memory breakdowns from Studio cover the whole process (edit + server + client), so they are
  only indicative.

### 2.1 What the client holds (playtest client, dev profile, one player)
- Workspace on the client: 18,591 instances, 9,471 BaseParts.
  - `PetRollWorld.Decor` alone holds 2,290 parts and **1,959 `Texture` objects, all
    rbxassetid://6372755229**.
  - Each Plot holds about 333 parts; each Lane about 613.
- Also on the client: 138 ParticleEmitters, 82 Beams, 189 BillboardGuis, 61 Highlights (47 are
  disabled `MysterySilhouette`s), 70 PointLights, 936 Bones.
- Lighting: GlobalShadows on, Bloom, SunRays, ColorCorrection; DepthOfField off. The menu
  `BlurEffect` turns on with every menu (Upgrades opened 7,634 times in 2 days).
- StreamingEnabled is on. The radius properties are not script-readable. The client held about
  the whole map (9,471 client parts vs 8,973 server), so streaming does not shed anything on a
  770-stud island.
- Render snapshot (`GetTriangleCompositionAsync`, client view):
  - 188 draw calls and 147K triangles in total.
  - **The shadow pass is 111 draw calls and 103K triangles (70% of all triangles).**
  - Opaque is 46 draw calls and 30K triangles.
- Voxel chicken (V3): 2 parts and 18 Bones (several mirrored skeleton copies per surface).
  - Effect chickens carry **3–11 ParticleEmitters each** (StormDuck 8–11, IceDuck 10,
    RiftWalker 3).
  - Plot1's flock emits about 300 particles/s in total; the Hill "Cyberpunk Sparks" emits
    210/s.
- PlayerGui: 16,587 instances.
  - `PetRollGui` has 7,420 descendants (3,430 in the template, so the scripts built about 4,000).
  - 18 leaderboard SurfaceGuis (6 plots × 3 boards), 500×750 FixedSize, about 300 instances
    each, so about 5,400.
  - `StarterGui.GUI` (3,257 instances, disabled) and `StarterGui.MainGUI` (487, disabled) are
    the owner's references. Roblox clones them into every PlayerGui. No code reads them; only a
    comment in ShopBrowser mentions them.
  - On screen after the tutorial: 2,169 GuiObjects and 1,763 UIStrokes.
- Sounds: `MyChickenArmyAudio.Music` is 4 tracks, **549 s**. The whole library is 143 sounds and
  694 s.

### 2.2 Client Luau per frame (script profiler, steady state, 52 V3 chickens on the client, 15 within 170 studs)
Total client Luau: 117 ms/s, so **1.95 ms/frame on the Mac, about 15 ms/frame on a low-end
phone**. At a 33 ms frame budget, that is half the phone's frame before rendering.

| # | Function | Mac µs/frame | Phone est. | Why |
|---|---|---|---|---|
| a | `DuckAnimator._step` (RenderStepped), inclusive | 1,000 | 8 ms | Every record, every frame: about 8 `GetAttribute` calls, `fx:Step`, `glitch:Step`, `blender:Step`, `KingVisual`. |
| a1 | ↳ `SpecialChickenVFX.Step` | 420 | 3.4 ms | Runs before any LOD. Visibility is distance-only, with no screen or count cap. |
| a2 | ↳ `VoxelChickenAnimator.Step` | 400 | 3.2 ms | **V3 rigs bypass DuckAnimator's 30 Hz/10 Hz distance LOD** (the `continue` after `blender:Step`). They pose all bones and every mirror every frame within 170 studs, on or off screen. |
| a3 | ↳ `Instance.GetAttribute` (C) | 250 | 2 ms | Attributes read every frame instead of cached. |
| a4 | ↳ FlowingChickenTexture / Glitch | 150 | 1.2 ms | UV and mesh updates. |
| b | `RollPresentationController` RenderStepped | 270–290 | 2.3 ms | Steps **every podium on all 6 plots** every frame. Rescans `world:GetChildren()` and each plot's children every 0.25 s. |
| c | `EggController.Step` (`EggView.Set` 160) | 250 | 2 ms | Every settled egg within 120 studs is re-CFramed (bob + face camera) every frame, 2 parts each. |
| d | `BaseController` Heartbeat | 150 | 1.2 ms | `StepArrival` every frame; polls at 10 Hz. |
| e | `AppController.Receive` / UI | 70 | 0.6 ms | |

Startup one-offs (10 s capture right after a playtest start):
- **`ChickenTexturePattern.Create` + `noise`: 487 ms on the Mac** (FlowingChickenTexture 500 ms
  inclusive). This bakes a 512² Galaxy/Rainbow field in Luau and yields only every 32 rows, so a
  phone would freeze for about 4 s in roughly 250 ms frames.
  - It runs only when `ChickenEffectQuality` reaches "animated".
  - Automatic quality starts "static" and promotes after 12 s of frames at 18 ms or less, so
    most phones never hit it. Desktops and good tablets do, mid-session.

Startup structure (static):
- About 10 full-tree scans at boot: `workspace:GetDescendants()` in DuckAnimator,
  PromptStyleController, GalaxyCrateVisuals and LeaderboardBoards, plus `world:GetDescendants()`
  in BaseController, BattleController, EggProcessorController, UpgradeBoardController,
  AutoCollectStandController and IntroCutscene.
- 11 `DescendantAdded` listeners: 6 on all of `workspace`, 5 on the world.
- While roughly 18.6K instances stream in at join, that is on the order of 200K Lua callbacks on
  the main thread (estimate).
- `AppController.new` builds every menu eagerly: Army, Sell, Shop, Index, Research/Upgrades,
  Rebirth, Daily, FreeGift, Operations, AutoRoll. `Start` then builds the leaderboards (5.4K
  instances), Intro/Hill/March films, ScreenFeel, WorldFeel and the rest. A new player sees only
  card 1 for the first minute.

### 2.3 Loading veil (LoadingController)
- The camera orbits at 1.5× the island radius (578 studs out, 366 up) looking at the island
  centre. That frames the **whole map**: all 6 plots, all 138 emitters, the shadow pass. This
  worst-case view is the one the load-window FPS sample measures.
- `RequestStreamAroundAsync(Vector3.new(0,2,0))` streams around the **island centre, not the
  player's plot**.
- `openingAssets` preloads the LoadingOverlay, the whole HUD tree, the sound folders
  `Music, Collection, Rolling, UI` (Music is **549 s, about 8–9 MB at 128 kbps**) and the whole
  own Plot.
  - It preloads in **sequential batches of 8**, one round trip each. At phone ping (129 ms
    median, 330 ms p90) the round trips alone add up.
- The veil waits for `profileReady` and (`assetsReady` or Skip). "SKIP LOADING" appears at 7 s.
- During the tutorial the HUD is hidden anyway (Oct 25 rule), so preloading it buys a new player
  nothing.

### 2.4 Other
- Every roaming chicken is a server-owned Humanoid moved with MoveTo and replicated (31
  Humanoids on an empty server). `health.serverFrameMaxMs` p90 is 250 ms or less. WS6 leaves
  movement alone (server lane, high risk) and only notes it for WS7 server fill.
- GUI stays heavy after the tutorial: 1,763 UIStrokes on screen, TextScaled everywhere (owner
  rule; fine while static), and the menu BlurEffect is a full-screen pass on phones.

### 2.5 Top 10 costs, ranked by estimated low-end-phone impact

| Rank | Cost | Evidence | Phone impact (est.) |
|---|---|---|---|
| 1 | Chicken presentation loop (DuckAnimator + VoxelChickenAnimator + SpecialChickenVFX) with no screen cull, no count cap and V3 bypassing LOD | 1.0 ms/frame on the Mac at 52 chickens; scales linearly with chickens in the server | 6–10 ms/frame |
| 2 | Loading veil: music in the preload, serial batches, whole-map orbit, stream-around at the centre | ready over 10 s for 17%; under-5-FPS load windows on 13% of phones | 2–8 s of load; a slide-show first impression |
| 3 | Shadow pass from thousands of small decor and plot parts | 111 of 188 draw calls, 103K of 147K triangles | GPU-bound on mid phones at Automatic levels with shadows |
| 4 | RollPresentationController steps all 48 podiums plus 0.25 s rescans | 0.28 ms/frame on the Mac | about 2.3 ms/frame |
| 5 | Egg per-frame CFrame for every settled egg | 0.25 ms on the Mac at about 15 eggs; tutorial lays every second | 2 ms or more per frame |
| 6 | Particle load: effect chickens 3–11 emitters each, Hill sparks 210/s, distance-only cull (110/220/400) | 138 emitters, about 300/s from one flock | GPU overdraw and particle sim |
| 7 | Startup scans and DescendantAdded fan-out (11 listeners) plus eager menu, leaderboard and film builds | about 10 full scans, about 9K GUI instances built at boot | 1–3 s of main-thread stalls during load |
| 8 | Draw-call bloat: 1,959 decor `Texture`s, 70 PointLights, Bloom + SunRays + menu Blur | composition counts | several ms GPU on phones |
| 9 | GUI: 18 leaderboard SurfaceGuis (about 27 MB of canvas if all render), 3,744 cloned reference GUI instances, 1,763 visible strokes | counts | memory (63% of phone reports over 1 GB) and boot time |
| 10 | Galaxy/Rainbow Luau texture bake (512² noise) | 487 ms of CPU on the Mac | multi-second hitch wherever it runs at "animated" |

---

## 3. Options and recommended fixes (ranked by FPS gain per effort)

| Pri | Fix | Gain (est.) | Effort | Risk |
|---|---|---|---|---|
| **P1** | `PerfTier`: one client performance governor (measured FPS + device class), feeding budgets to every presentation system | enables everything below | S | low |
| **P2** | Chicken LOD in DuckAnimator: screen + distance + count-capped scheduler for V3 rigs too, attribute caching, VFX nearest-N cap | 50–75% of a1–a3 (4–7 ms on phones) | M | low–med |
| **P3** | Loading path: drop Music and HUD from the preload, one parallel PreloadAsync, veil cap 4 s after profile, no orbit on low tier, stream around own plot, earlier telemetry | 2–6 s less to control on phones; smooth load window | S | low |
| **P4** | Podium LOD (RollPresentationController) and egg LOD (EggController) | 2–4 ms/frame on phones | S | low |
| **P5** | Low-tier render budget: Bloom/SunRays off, menu blur replaced by its existing dim, WorldFeel/coin caps, emitter Rate ×0.5, Hill VFX cull; "critical" sub-tier drops GlobalShadows locally | several ms GPU | S | low (looks; owner-visible) |
| **P6** | Studio (Stevin): CastShadow off on Decor/fences/small props, 1,959 Textures → one MaterialVariant, move reference GUIs out of StarterGui, trim PointLights | large GPU and draw-call cut | S (Studio) | low |
| **P7** | Boot work: one shared world watcher instead of 11 DescendantAdded and about 10 scans; staged/yielding construction; build leaderboards by proximity; skip films when ineligible | 1–3 s smoother boot | M | med |
| **P8** | Pre-bake the Galaxy/Rainbow pattern as an uploaded image (no Luau noise) | removes the 0.5 s Mac / about 4 s phone hitch | S (+1 upload) | low |
| P9 | Streaming: StreamingTargetRadius 512, MinRadius 128, ModelStreamingMode Atomic for chickens (Studio) | memory and far-plot cost | S | **med**: code assumes far plots exist; do it after P7, with a test |
| P10 | Server chicken movement (client-interpolated anchored CFrames instead of Humanoids) | network and server frame | L | high: out of WS6 scope; note for WS7 |

Decision: ship P1–P5 and P8 as one client release (WS6 code), ask Stevin for P6 in the same
window, and ship P7 as a second pass after measuring. P9 follows P7. P10 goes to WS7.

Owner fit:
- Game feel stays. Every tier keeps animation, sound and VFX; low only budgets *how many* and
  *how often* (exactly what `ChickenEffectQuality` and the touch budgets already do).
- One UI layout: tiers change effects, never positions or sizes.
- Voxel chickens and voxel eggs stay. No PetView fallback, still one or two parts per egg.
- Reduced motion keeps priority over tiers.

---

## 4. Implementation steps (file by file)

### 4.1 NEW `src/client/PerfTier.luau` (P1)
One module-level singleton, required by everyone, started by the bootstrap.
```
PerfTier.Start()                 -- idempotent; Heartbeat sampler + focus listeners
PerfTier.Get(): "low"|"mid"|"high"
PerfTier.Critical(): boolean     -- low AND still < 22 FPS after 10 s at low
PerfTier.Budget(): Budget        -- table below for the current tier
PerfTier.Changed: BindableEvent-like signal (tier: string)
PerfTier.Stats(): {fps: number, hitches: number, focusLost: boolean, tier: string, demotions: number}
```

Initial tier (decided once at Start):
- Read `UserGameSettings.SavedQualityLevel` (0 = Automatic), the same way as
  `ChickenEffectQuality.savedLevel`.
- A manual level of 1–4 gives `low`, 5–7 `mid`, 8–10 `high`. A manual level fixes the
  *ceiling*; automatic demotion still runs.
- Automatic: touch-only with viewport short side under 700 ("Mobile", same rule as
  `AnalyticsClient.platform`) starts `low`; touch-only tablets start `mid`; everything else
  starts `high`.

Sampling (RunService.Heartbeat dt):
- Use an EMA with τ = 1.0 s. Ignore samples with dt > 1 (app suspended) or while
  `WindowFocusReleased` (copy ChickenEffectQuality's focus pattern).
- **Demote** one tier when the EMA frame time is over 40 ms (under 25 FPS) for 4 s in a row.
  The ceiling becomes the new tier, so a session never re-promotes into a tier it failed at.
- **Promote** one tier when the EMA is 20 ms or less (50+ FPS) for 20 s and the tier is below
  the ceiling.
- **Critical**: tier is low, EMA over 45 ms (under 22 FPS) for 10 s. It clears after 30 s at
  28 ms or less.
- Count hitches as frames over 100 ms, for telemetry.

Budget table (exact starting values; tune with section 6 captures):

| key | low | mid | high |
|---|---|---|---|
| `animFullRadius` (every frame) | 30 | 45 | 60 |
| `animMidRadius` / `animMidHz` | 70 / 15 | 100 / 20 | 120 / 30 |
| `animFarRadius` / `animFarHz` | 120 / 5 | 150 / 8 | 170 / 10 |
| `animFullMax` (nearest rigs at full rate) | 10 | 20 | 999 |
| `offscreenHz` (rig outside the viewport + 15% margin) | 2 | 4 | 6 |
| `fxMaxChickens` (nearest with emitters on) | 6 | 12 | 24 |
| `fxCull` (studs) | 70 | 110 | 220 (existing) |
| `fxRateScale` | 0.5 | 0.75 | 1.0 |
| `eggBobRadius` / `eggHz` (settled eggs) | 40 / 20 | 80 / 30 | 120 / 60 |
| `podiumOtherPlotHz` (stations beyond 80 studs) | 4 | 10 | 30 |
| `worldFeelLimit` | 8 | 14 | 28 |
| `coinsMaxActive` | 8 | 14 | 28 |
| `menuBlur` | false | true | true |
| `bloom` / `sunRays` | false / false | true / false | true / true |
| `textureCeiling` (ChickenEffectQuality) | static | animated | masked |

`critical` additionally sets local `Lighting.GlobalShadows=false` and halves `fxMaxChickens`.
Restore the authored value when critical clears.

### 4.2 `src/bootstraps/PetRollClient.client.luau` (P1, P3, telemetry)
Order:
1. `require(PerfTier).Start()`.
2. `task.spawn(AnalyticsClient.Start)` **before** `LoadingController.new` and `AppController`, so
   the first report and platform arrive early. AnalyticsClient already `WaitForChild`s its
   remote. Emit `load.phase "boot"` with `time()`.
3. LoadingController, AppController (unchanged), `loading:Bind(app)`.
4. Emit `load.phase "app"` after `app:Start()` returns.

### 4.3 `src/client/ChickenEffectQuality.luau` (P1)
- In `Quality.Advance`, clamp `state.ceiling` to the `PerfTier` texture ceiling (static=1,
  animated=2, masked=3).
- Subscribe to `PerfTier.Changed` to clamp `state.tier` immediately on demotion.
- No other behaviour change. Manual-level semantics stay as they are.

### 4.4 `src/client/DuckAnimator.luau` (P2), the largest win
1. **Attribute cache.** In `discover`, store `record.attr = {PetId, AtHome, Defeated,
   PresentationHidden, ReducedMotion, ChickenKing, GalaxyMaskPreview}` and connect
   `model.AttributeChanged` to update the entry; disconnect on removal. Replace the per-frame
   `model:GetAttribute(...)` calls in `_step` with `record.attr.X`.
2. **Scheduler (applies to V3 rigs too).** At the top of the loop compute
   `pos = record.root or model.PrimaryPart`, the distance to the camera and the on-screen flag
   (`camera:WorldToViewportPoint`, with a margin of 15% of the viewport and a "behind" check).
   - Off screen: interval = 1/offscreenHz.
   - On screen: interval 0 within animFullRadius (and among the nearest animFullMax), else
     1/animMidHz within animMidRadius, else 1/animFarHz within animFarRadius, else sleep.
   - Keep `record.nextAt`. When `now < record.nextAt`, skip the record but keep cheap bookkeeping
     (the cluck reservoir uses the cached `pos`).
   - Rank for `animFullMax`: only when more than animFullMax on-screen rigs fall within
     animFullRadius, do a partial selection (keep a k-largest-distance cut; fine at 50–150
     records).
   - Remove the "V3 bypasses LOD" path: `blender:Step(now, reduced, camera)` runs only when the
     scheduler says the record is due. `VoxelChickenAnimator.Step` already computes its own dt
     from `lastStep`.
3. **VFX budget.** Pass `fxAllowed` (rank among the nearest `fxMaxChickens` that are on screen
   and within `fxCull`) and `fxRateScale` to `record.fx:Step(...)`. FX `Step` keeps its own
   20 Hz internal cadence but is called only when due (at least 10 Hz while visible) and
   immediately on visibility change.
4. Galaxy/Rainbow material steps (`FlowingChickenTexture`) stay shared per appearance (one
   update per frame, already cheap), gated by the texture ceiling.
5. Keep `workspace.DescendantAdded` discovery until P7 replaces it. Add a cheap early-out:
   `if not item:IsA("Model") then return end` is already first. Fine.

### 4.5 `src/client/VoxelChickenAnimator.luau` (P2)
- `Step`: raise the dt clamp from 0.15 to 0.25 so a 5 Hz far step still advances the clip
  correctly.
- `_events` cue ages: keep the `< 0.75` gate. With offscreenHz 2 a cue can be up to 0.5 s late,
  which is acceptable because it is off screen.
- Add `Step(..., coarse: boolean?)`. When coarse (far tiers), write only the primary bone of
  each mirror group (the first entry of `self.mirrors[i]`) when that mirror group is a
  hat/armor duplicate. **Measure first**: only ship it if the profile shows bone writes
  dominate after the scheduler; otherwise skip it.

### 4.6 `src/client/SpecialChickenVFX.luau` and `src/client/RareChickenVFX.luau` (P2/P5)
- `Special.Step(self, now, reduced, camera, textureTier, cullDistance, fxAllowed, rateScale)`:
  `visible = ... and fxAllowed ~= false`.
- In `_visible` / `_calm`, apply `rateScale` to the saved authored rates (`self.authored[effect]
  .rate`, `record.rate`). It is already the pattern used for `CALM_RATE`, so multiply
  `rate * (calm and CALM_RATE or 1) * rateScale`.
- Mirror the same two parameters in `RareChickenVFX.Step`.
- Keep the `VFXLoop` spatial-audio rule (42 studs) unchanged. Sound is not culled by tier.

### 4.7 `src/client/RollPresentationController.luau` (P4)
- Replace the 0.25 s full `world:GetChildren()` and plot-children rescan with `ChildAdded` on
  `world` and on each plot (plus one initial scan). Keep a 2 s safety rescan.
- In the RenderStepped loop:
  - Stations on the **local player's plot**, or within 80 studs of the camera, step every frame.
  - Other stations step at `podiumOtherPlotHz` (track `record.nextStepAt`), and their preview
    VFX obey the same `fxAllowed` budget (count against `fxMaxChickens`).
  - The lever arm/knob CFrame writes (line ~697) run only while the lever animates.

### 4.8 `src/client/EggController.luau` and `src/client/EggView.luau` (P4)
- In `Eggs:Step`, for settled eggs (no `flightAt`, age ≥ EggSettleSeconds):
  - Beyond `eggBobRadius`, call `view:Set` once with bob = 0, then mark `view.parked=true` and
    skip until hover/tap/flight/size changes.
  - Within the radius, update at `eggHz` (track `view.nextBobAt`). Flights and lay pops stay
    every frame (they are short and are the feel).
- `EggView:Set`: skip the CFrame write when position, scale and the camera yaw bucket (5°)
  match the last write.
- Tap badges keep their shared beat (`tapPulse` is a tween; unchanged).

### 4.9 `src/client/LoadingController.luau` (P3)
1. `openingAssets(gui, state, intro)`:
   - Keep `LoadingOverlay`.
   - Add the guide card tree (the CommanderGuide root under `PetRollGui.Shell`; implementer:
     find its container name in `CommanderGuide.new`).
   - Add the HUD tree **only if `(state.tutorial or {}).guideCompleted == true`** (returning
     players).
   - Sound folders `{"Collection","Rolling","UI"}`; **remove `"Music"`**. Keep Intro only when
     eligible.
   - Own Plot: only the RollStation/lever model and the `Pets` folder, not every decor
     descendant.
2. Replace the batch loop with one `ContentProvider:PreloadAsync(assets, function(_, _)
   done += 1; self:SetProgress(done, total) end)`. That is one request burst instead of
   `ceil(n/8)` serial round trips.
3. New constant `MAX_VEIL_AFTER_PROFILE = 4`: when `profileReady` turns true, start a timer.
   After 4 s, set `skipRequested`-equivalent `self.assetsTimedOut = true` and `MaybeDismiss()`.
   The preload continues in the background; dismissal does not cancel it.
4. `SKIP_AFTER` 7 → 4.
5. `StartOrbit`:
   - If `PerfTier.Get() == "low"`, or touch-only, do **not** orbit. Park the camera once on a
     static high three-quarter view of the player's plot (`world["Plot"..state.plotIndex]`
     pivot; before the state arrives, the current character camera). The blur and logo still
     breathe; feel is kept.
   - Desktop/console keep the orbit.
   - Stream around **the own plot pivot** instead of `(0,2,0)` once `state.plotIndex` is known
     (call again from `ConsiderState`).
6. After `Dismiss`, call `app.audio:WarmMusic()` (or simply let AudioController's first song
   load on demand). Music then streams after control, not before.
7. Emit `load.phase` "profile" (profileReady), "assets" (assetsReady or timeout, with detail
   `assets`/`timeout`), alongside the existing "ready".

### 4.10 `src/client/AppController.luau` (P5, P7). SHARED FILE, see section 8
- `SetMenuBlur(owner, visible)`: when `PerfTier.Budget().menuBlur == false`, keep the existing
  dim layer and set the BlurEffect `Size` to 0 (or never create it). The layout is unchanged.
- One `applyLighting(tier)` helper subscribed to `PerfTier.Changed`:
  - Set local `Lighting.Bloom.Enabled` and `Lighting.SunRays.Enabled` from the budget.
  - Under `Critical()`, set `Lighting.GlobalShadows=false`.
  - Store the authored values at first run and restore them on promotion.
  - Ignore `PetRollHillTint`/`GoldRushTint` (cheap ColorCorrection).
- P7, staged construction:
  - Wrap the heavy constructors in `AppController.new`/`Start` that the first minute does not
    need (`IndexBrowser`, `ShopBrowser`, `SellMenu`, `OperationsPanel`, `AutoRollMenu`,
    `HillIntro`, `MarchFilm`, `GalaxyCrateVisuals`, `LeaderboardBoards`) in
    `self:_Stage(name, fn)`. Run them in order on a `task.defer` chain with `task.wait()`
    between items after the first `StateChanged`.
  - Each public entry point that opens one of them calls `self:Ensure(name)` first, which builds
    it synchronously if it is still pending.
  - `IntroCutscene.new` is cheap; `Intro:Begin` does the heavy work and already checks
    eligibility. Leave it.
  - **Gate P7 on measurement**: instrument each constructor with `debug.profilebegin(name)` and
    an `os.clock()` delta printed in Studio. Stage only the constructors that take over 15 ms on
    the Mac (over about 120 ms on phones).

### 4.11 `src/client/WorldFeel.luau`, `src/client/CoinBurst.luau` (P5)
- `WorldFeel:Limit()` returns `PerfTier.Budget().worldFeelLimit` (low 8, mid 14, high 28). The
  current touch=14 rule becomes the mid default.
- CoinBurst: use `math.min(Feel.Collection.PhoneMaxActive or MaxActive, Budget.coinsMaxActive)`
  for touch, and `MaxActive` vs the budget otherwise. Coins never disappear: the extra value
  "counts in at once" (existing rule).

### 4.12 `src/client/HillIntro.luau` (P5)
- The cloned `PetRollHillVFX` ("Cyberpunk Sparks", 210/s): on low, scale the emitter `Rate` by
  `fxRateScale` and disable it while the camera is more than 150 studs from the Hill.

### 4.13 `src/client/ChickenTexturePattern.luau` (P8)
- Stevin uploads two 512² PNGs (Galaxy and Rainbow fields), exported once from the current
  generator. The implementer runs `Pattern.Create` in Studio and saves via
  `EditableImage:ReadPixelsBuffer` → PNG with a tools script. That is an asset upload, which is
  Studio-owned.
- `Pattern.Create` returns `AssetService:CreateEditableImageAsync(Content.fromUri(id))` for
  these appearances, with the Luau bake as fallback only when the id is missing.
- Keep the look identical.

### 4.14 `src/client/LeaderboardBoards.luau` (P7). SHARED with WS7
- `Attach` builds the SurfaceGui rows lazily: the first `Render` happens when the board's screen
  comes within 200 studs of the camera (check at 1 Hz).
- On `low`, only the local player's plot boards and the nearest other set render. The others
  keep `Enabled=false` until approached.

### 4.15 P7 world watcher (optional second pass): NEW `src/client/WorldIndex.luau`
- One `workspace:GetDescendants()` pass and one `workspace.DescendantAdded` connection.
- Dispatch by cheap predicates: `IsA("Model")` plus attribute probes for DuckAnimator and
  GalaxyCrateVisuals, `IsA("ProximityPrompt")` for PromptStyleController, `IsA("SurfaceGui")`
  for EggProcessor/UpgradeBoard, the board names for LeaderboardBoards.
- Each consumer registers `WorldIndex.Watch(predicate, callback)`.
- Then migrate DuckAnimator, PromptStyleController, GalaxyCrateVisuals, LeaderboardBoards,
  UpgradeBoardController and EggProcessorController.

### 4.16 Studio-owned changes: Stevin (P6, P9). WS6 cannot make these
Do these in Edit, then save and publish with the normal "Migrate To Latest Update":
1. **Shadows**: set `CastShadow=false` on every part under `Decor`, the plot fences/rails/grass
   tufts and Lane trims (keep it on chickens, characters, roll machines and big landmarks).
   Expect the shadow pass to fall from 103K triangles to well under half. Command-bar
   one-liner: loop `ServerStorage/authoring source of PetRollWorld.Decor` descendants →
   `CastShadow=false`. That edits the template AuthoredMap clones, which the implementer
   locates (`src/server/AuthoredMap.luau`).
2. **Decor studs**: replace the 1,959 `Texture` instances (id 6372755229) with one
   `MaterialVariant` (stud ColorMap on the base Material of those parts) in `MaterialService`,
   and set the parts' `MaterialVariant` name. That is one material instead of 1,959 per-face
   draws. (The `UITheme.Studs` rule is for UI; this is world geometry.)
3. Move `StarterGui.GUI` and `StarterGui.MainGUI` into `ServerStorage.UIReference` (no runtime
   code reads them; only a comment in ShopBrowser mentions them). That saves 3,744 instances
   cloned into every player at join. Update the AGENTS.md line that says "the restored
   `StarterGui.GUI.FRAMES`" to the new path.
4. Lights: 70 PointLights in the world. Disable `Shadows` on all of them (already off) and
   remove decorative ones under 4 studs of range or merge them. Target 40 or fewer.
5. P9 (after P7 ships and is tested): `Workspace.StreamingTargetRadius = 512`,
   `StreamingMinRadius = 128`, chicken models `ModelStreamingMode = Atomic`, plot roots
   `Persistent` only if code requires them (RollPresentationController and BaseController scan
   all plots).
6. Verify the Hill VFX emitter `Rate` in its template (210/s) is intended.

---

## 5. Analytics (append-only; Schema.Version 15 → 16)

### 5.1 Client (`src/client/AnalyticsClient.luau`)
- Started from the bootstrap before AppController (4.2).
- The first report is sent at **4 s** (`FIRST_REPORT_SECONDS` 8 → 4) and flagged
  `report.window="load"` while the LoadingOverlay exists. Later reports use `"play"`.
- New report fields (all optional; the server clamps them):
  - `tier` (PerfTier.Get), `critical` (bool), `demotions` (int).
  - `hitches` (frames over 100 ms in the window).
  - `focusLost` (bool, window focus released at any time in the window → the server excludes it
    from FPS histograms).
  - `frameMsP90` (90th-percentile frame time in the window, from a 64-bin dt histogram).
- New client events: `load.phase` details `boot`, `app`, `profile`, `assets`, `timeout` (the
  kind is already "free"; no new names needed client-side).

### 5.2 Server (`src/server/Analytics.luau`, `AnalyticsSchema.luau`, `AnalyticsReport.luau`)
- `AnalyticsSchema.luau`: `Schema.Version = 16` with a changelog line ("16 (Oct 27): perf
  windows, tiers, load phases by platform"). Append `Schema.PerfTiers = {"low","mid","high"}`.
  Append bucket `frameMs = {16, 22, 33, 50, 66, 100, 200}` to `Schema.Buckets`.
- `Analytics:ClientReport`:
  - When `report.focusLost == true`, skip the FPS histograms (count `perf.focusLost|<platform>`).
  - When `report.window == "load"`, Hist `perf.fpsLoad|<platform>`; otherwise
    `perf.fpsPlay|<platform>`. Keep the existing `perf.fps|<platform>` unchanged for continuity.
  - Hist `perf.fps.perfTier.<tier>`, Count `perf.tier.<tier>|<platform>` on the first report
    and `perf.demoted|<platform>` when demotions > 0.
  - Hist `perf.hitches|<platform>`.
  - Session state: track `st.fpsLoad` (first load-window value) and running sums for play
    windows.
- Load phases: in the `load.phase` handler (line ~773) also write
  `ui.load.<phase>|<platform>` when the platform is known. Before that, buffer the phase and
  write it on the first report.
- Journey record (line ~949): add fields `fl` (load-window FPS), `fp` (mean play-window FPS),
  `tier` (last tier), `fo` (focus lost, bool), `lr` (veil-lift seconds). These are new keys;
  the old ones are unchanged.
- `AnalyticsReport.luau`: add a `perf` block with `fpsLoad`/`fpsPlay`/`tier` mixes by platform
  and the `ui.load.*|platform` tables. Add a flag rule: Mobile `fpsPlay` p50 ≤ 30 (high), and
  the Mobile `ui.load.ready` share over 10 s above 10% (medium).
- Docs: append a "Performance windows (v16)" section to `docs/analytics/AGENT_GUIDE.md` and
  `docs/analytics/TRACKING_PLAN.md` §4.

### 5.3 Success metrics (measure on 2 days of new sessions after release; same ad mix)
Primary:
- **Mobile new sessions with mean FPS under 20: 33% → 15% or less.**
- **Mobile `fpsPlay` under 30: 37% → 20% or less** (steady state).

Secondary:
- Mobile Cluck Camp win (mx 14 or more): 29% → 35% or more.
- Mobile 3-minute survival: 48% → 52% or more.
- Card-1 exits (mx 2) on phones: −30%.
- Load: `ui.load.ready` over 10 s, 9.4% → 4% or less; phones with veil lift at 5 s or less,
  55% → 75% or more; "Unknown"-platform sessions 4.6% → 3% or less (the earlier first report
  catches more).
- Guardrails (must not regress): desktop/console FPS unchanged; tablet Cluck Camp unchanged;
  `err.client` zero new sources; mobile memMb share over 1.5 GB not up.

---

## 6. Verification protocol

Before any code change, capture the **baseline** with the same steps. Write the numbers into the
contract doc (section 8).

1. Studio device emulation: "iPhone SE / 375×667" and a 360×800 Android preset.
   - Studio's emulator does not slow the CPU, so also run with **Studio > Settings > Rendering
     > Graphics quality 1** (manual) and, separately, with Automatic.
   - Read Luau cost as ms/frame from the script profiler and multiply by 8 for the phone
     estimate, as in this plan.
2. Scenario A, fresh profile (new-player path): use the project's existing new-player test
   switch (`state.newPlayerTest`, Settings/Admin; do not hand-edit saves).
   - Join, measure time to veil lift (`ui.load.ready` printed) and time to the first card.
   - Run the script profiler for 10 s from playtest start (`capture_script_profiler
     duration 10000`, client-1).
3. Scenario B, full yard: a dev profile with Flock 15, Army 10, all 8 podiums filled, plus
   2–3 extra clients (`multiplayer_playtest`, 4 players) so other plots have flocks.
   - Stand in the yard with the camera at default zoom. Run the script profiler for 5 s and the
     micro profiler for 2 s on client-1.
   - Read `get_scene_analysis triangle_composition` (draw calls, shadow share).
4. Record: client Luau ms/frame (DuckAnimator, RollPresentation, EggController, BaseController
   rows); draw calls, triangles, shadow share; emitters on and their total Rate; GUI instances;
   veil-lift seconds; `fpsMin` over 60 s.
5. Targets after P1–P5 and P8 (Mac numbers, scenario B):
   - Client Luau **≤ 0.8 ms/frame** (from 1.95), DuckAnimator ≤ 0.35 ms, RollPresentation
     ≤ 0.08 ms, EggController ≤ 0.10 ms.
   - Veil lift on a fresh profile ≤ 3 s in Studio.
   - After P6: shadow-pass triangles ≤ 45% of total; draw calls ≤ 140 in the yard view.
6. Feel check (owner rule):
   - On each tier, pull the lever, take the chicken, tap 3 eggs, sell, feed a chicken, attack
     Cluck Camp.
   - Every interaction must still animate with VFX and sound. Reduced motion still wins over
     tier.
   - A low-tier phone run of the tutorial must show the lever pull reveal, the egg lay pop, the
     coin burst and the chicken walk/idle within 30 studs.
7. Force tiers for testing: `ReplicatedStorage.PetRoll:SetAttribute("PerfTierOverride", "low")`,
   read by PerfTier in Studio only (`RunService:IsStudio()`).
8. After release: section 5.3 metrics at +2 days in AnalyticsReport, split by `perf.tier.*`.
   Expect the low tier to hold most former under-20 phones at 25 FPS or more.

---

## 7. Risks and rollback

| Risk | Mitigation | Rollback |
|---|---|---|
| Low tier looks visibly poorer to Stevin | Budgets reduce counts and rates, never remove a whole effect class; nearest chickens always animate at full rate; promotion after 20 s of good frames | `Config.Performance.TiersEnabled=false` (new key in `src/shared/Config.luau`): PerfTier returns "high" always, which is today's behaviour |
| Wrong FPS readings (Studio throttling, backgrounded app) cause flapping | dt over 1 s ignored, focus-release pause, ceiling after demotion (proven pattern from ChickenEffectQuality) | same flag |
| Off-screen chickens miss a cue (attack/hit pose) | cues are age-gated (0.75 s) and off-screen updates run at 2 Hz or more; visible chickens unaffected | `Config.Performance.AnimLOD=false` keeps the scheduler at today's per-frame stepping |
| Veil lifts before HUD images load for returning players | HUD tree still preloaded for completed-tutorial profiles; 4 s cap only after profile ready; preload continues | `Config.Performance.VeilCapSeconds=nil` restores the wait |
| Music starts later | it starts after control (on-demand load) | none needed |
| Staged construction (P7) calls a menu before it exists | `Ensure(name)` on every entry point; ship P7 separately with a Studio pass through every HUD button | `Config.Performance.StagedBoot=false` |
| Streaming radius (P9) breaks code that scans all plots | only after P7's WorldIndex; test with 6 players on opposite plots | revert the Workspace properties in Studio |
| Analytics bump | append-only keys; old histograms kept | none (analytics never changes gameplay) |
| Galaxy pre-baked image missing or moderated | fallback to the Luau bake | id nil = old path |

All new flags live in one `Config.Performance = {TiersEnabled=true, AnimLOD=true,
VeilCapSeconds=4, StagedBoot=false, ...}` table in `src/shared/Config.luau` (append; no existing
key changes).

---

## 8. Files touched and interfaces

### 8.1 Code (WS6 writes these)
- NEW `src/client/PerfTier.luau`
- NEW `src/client/WorldIndex.luau` (P7, second pass)
- `src/bootstraps/PetRollClient.client.luau`
- `src/client/ChickenEffectQuality.luau`
- `src/client/DuckAnimator.luau`
- `src/client/VoxelChickenAnimator.luau`
- `src/client/SpecialChickenVFX.luau`
- `src/client/RareChickenVFX.luau`
- `src/client/RollPresentationController.luau`
- `src/client/EggController.luau`
- `src/client/EggView.luau`
- `src/client/LoadingController.luau`
- `src/client/WorldFeel.luau`
- `src/client/CoinBurst.luau`
- `src/client/HillIntro.luau`
- `src/client/ChickenTexturePattern.luau`
- `src/client/AnalyticsClient.luau`
- `src/client/AnalyticsUiObserver.luau` (load phases only)
- `src/server/Analytics.luau`
- `src/server/AnalyticsSchema.luau` (Version 16)
- `src/server/AnalyticsReport.luau`
- `src/shared/Config.luau` (append `Performance` table only)
- P7 consumers: `src/client/PromptStyleController.luau`, `src/client/GalaxyCrateVisuals.luau`,
  `src/client/UpgradeBoardController.luau`, `src/client/EggProcessorController.luau`
- Docs: NEW `docs/team/MOBILE_PERFORMANCE_20261027.md` (contract: tiers, budgets, baseline and
  after numbers); `docs/analytics/AGENT_GUIDE.md`, `docs/analytics/TRACKING_PLAN.md`; one
  AGENTS.md paragraph ("Performance tiers (Oct 27)").

### 8.2 Shared files: coordinate with the lead (one writer per file)
- **`src/client/AppController.luau`**: WS5 (post-tutorial flow/HUD) and likely WS3 (shortfall
  prompt via CommerceController hooks) touch it. WS6 needs only two small additions:
  `SetMenuBlur` tier check and an `applyLighting` subscription, plus the optional P7
  `_Stage`/`Ensure`. Proposal: WS6 hands the lead a 20-line patch; the lead applies it after
  WS5.
- **`src/client/LeaderboardBoards.luau`**: WS7 (social/server fill) may change the boards. WS6
  needs only lazy render plus low-tier enablement. If WS7 owns the file, WS7 applies section
  4.14.
- **`src/client/EggController.luau`**: WS2 (early economy) may touch egg lay or tutorial egg
  timing (`TutorialEggLaySeconds`). WS6 edits only `Eggs:Step`'s settled-egg branch and
  `EggView:Set`. Conflicts are textual only.
- **`src/client/LoadingController.luau` / bootstrap**: WS5 may change the first-minute HUD
  reveal. WS6's preload rule reads `state.tutorial.guideCompleted` and must follow WS5's
  definition of "HUD visible".
- **`src/server/Analytics*.luau` / `AnalyticsSchema.luau`**: several workstreams will add
  analytics. **Only one Schema.Version bump per release.** The lead merges all WS schema
  appends into Version 16 together.
- **`src/shared/Config.luau`**: append-only `Performance` table. WS2 and WS4 edit other keys.
- **`src/client/RollPresentationController.luau`**: WS4 (roll variety) may change podium/roll
  presentation. WS6 touches only the RenderStepped scheduler and the scan (section 4.7). WS4
  should land first if it restructures records.

### 8.3 Interfaces offered to other workstreams
- `PerfTier.Get()`, `PerfTier.Budget()`, `PerfTier.Changed`: any new VFX/UI motion from WS1, WS4
  or WS5 must read `Budget().worldFeelLimit`/`fxMaxChickens` instead of inventing a private
  budget (owner rule: the shared vocabulary).
- `load.phase` details (`boot/app/profile/assets/timeout/ready`) and journey keys
  `fl/fp/tier/fo/lr` for any WS that segments by device performance (WS5 HUD-reveal tests, WS1
  camp-wall analysis on phones).
- WS7 note: more players per server multiplies roaming chickens (server Humanoids, client
  records). P2's count caps make the client side scale; server movement (P10) stays a WS7/lead
  decision.

### 8.4 Studio-owned (Stevin; section 4.16)
- CastShadow on Decor and small props
- Decor Textures → MaterialVariant
- Move `StarterGui.GUI`/`MainGUI` → `ServerStorage.UIReference`
- PointLight trim
- Galaxy/Rainbow pattern image upload (P8)
- Streaming settings (P9, later)

Save the place after the edits; publish only on his explicit request.
