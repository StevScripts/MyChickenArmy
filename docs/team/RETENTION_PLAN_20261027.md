# Retention plan: why new players quit, and the parallel build to fix it (October 27, 2026)

Stevin: "make a very detailed run agents for each thing do deep deep research and an
implementation plan to fix ALL of these issues ... so I can implement all of them in tandem".

This is the lead's integration document. Seven research workers each wrote a full plan
(evidence, root cause in code, design with numbers, file-by-file steps, analytics,
verification, risks). They live next to this file:

| WS | Problem | Plan | Lines |
|---|---|---|---|
| WS1 | Fort Roost is unwinnable when the game points at it | [WS1-camp-progression-wall.md](retention-20261027/WS1-camp-progression-wall.md) | 607 |
| WS2 | Price cliff after the tutorial; the "waiting" middle loop | [WS2-early-economy.md](retention-20261027/WS2-early-economy.md) | 788+ |
| WS3 | Robux checkout opens on every Coins shortfall | [WS3-coins-shortfall-prompt.md](retention-20261027/WS3-coins-shortfall-prompt.md) | 627 |
| WS4 | Rolls rarely show anything new | [WS4-roll-discovery.md](retention-20261027/WS4-roll-discovery.md) | 528 |
| WS5 | No goal on screen after the tutorial; everything appears at once | [WS5-post-tutorial-flow.md](retention-20261027/WS5-post-tutorial-flow.md) | 966 |
| WS6 | Phones under 20 FPS; slow load | [WS6-performance.md](retention-20261027/WS6-performance.md) | 681 |
| WS7 | Players share servers but never meet; the listing over-promises | [WS7-social.md](retention-20261027/WS7-social.md) | 612 |

The workers' scratch simulations (Lune, real modules) are in
[retention-20261027/sims/](retention-20261027/sims/). Run them from `tools/sim` like the
other probes (`lune run harness.luau ../.. <script>`). The raw data (journeys27, summary125,
raw125 JSON) was exported from the live ledger for Oct 26–27 and is not committed; every
number used is reproduced in the plans.

Each WS plan is the build spec for that stream. This document adds what the plans cannot
say alone: what the data really says once all seven are read together, which conflicts the
lead resolved, the owner rules this package changes, the parallel build order with one
writer per file, and the measurement plan.

---

## 1. What the research changed in the diagnosis

The October 27 quitting analysis had three readings that the deeper work corrected:

1. **"74% of Cluck Camp winners left on 'Next up: conquer Fort Roost!'" is an artefact.**
   The journey's exit step is resolved on the server, which never times cards out; the client
   shows that card for 10 s. In fact **88% of tutorial finishers (438 of 496) left with no
   actionable card on screen** (WS5 §1.2). Fort Roost is still a real wall (below), but the
   bigger leak is the empty screen.
2. **Servers are not empty.** Server size is 6 (one player per plot). Only 9.8% of joins land
   alone and 86% of player-minutes have someone else present. The "1–2 players" figure was
   per server-minute. The problem is that nobody interacts: 5 chat messages in 1,530
   sessions, plots ~311 studs apart behind streaming, roll reveals visible only to the roller
   (WS7 §1.1).
3. **Journey field `c` is Coins, not camps.** Cluck Camp wins are `mx >= 14` (WS6 §1.4). The
   plans use the corrected field.

The corrected picture, minute by minute, for a new player on live 1.25.0:

| Play time | What happens | Evidence | Stream |
|---|---|---|---|
| 0:00–1:00 | Load; a third of phones run under 20 FPS; 17% of under-1-minute quitters never finished loading | 33% of new phone sessions average <20 FPS; that group keeps 15% at 3 min and wins Cluck Camp 7% (vs ~40%) | WS6 |
| ~1:03 | Tutorial completes (median). Every HUD piece, the Daily popup (7–19 s later, randomly, covering the first tip) | 21.5% of finishers gone by 60 s after completion, 48.8% by 180 s | WS5 |
| 1–3 min | Vacuum tips; then an empty gap; 72% of leavers there own only 2 chickens and nothing says the Attack tip needs 3 | post-vacuum gap: 26% of finisher exits, median gap 37.5 s | WS5 |
| 1–5 min | Next Commons cost 1,900–3,000 against 4–18 Coins/s; Buy fails | 46% of 7,886 Buys failed; 1,817 "Not enough Coins" in the first ~3 min (2.1 per new player) | WS2 |
| 1–10 min | Each failed Buy opens a Robux checkout | 2,429 Coins-pack auto-prompts, 3 bought (0.12%); 6.6 prompts per prompted player; 75% of first prompts before 7.5 min of play | WS3 |
| 1–10 min | Pulls show the same Commons; FavoredRolls puts the basic Chicken on 60% of the first 5 | median first Uncommon at post-tutorial pull 13 (reached by 14%), first Rare at pull 87; median player gets ~5 pulls | WS4 |
| ~3:40 | Cluck Camp won; "Next up: Fort Roost" shows 10 s, then nothing | 73% of Fort Roost attacks start below 1.0x and win 1 in 1,215; 24% of Cluck Camp winners ever win Fort Roost | WS1 |
| ~4:00 | Rebirth 0 resets the tree: the Egg Vacuum and Flock Size I vanish silently; then ~4 minutes of empty screen | the typical winner rebirths at 4:00 and leaves near 8:00; ~1/3 of rebirthers never re-claim the vacuum | WS5, WS2 |
| all | Others in the server are invisible; listing promises a horde and "Cash"/"Fuse" | 79% of sessions end with an Army of 3 or fewer | WS7 |

So the answer to "is it just boring?" stands, sharpened: the first minute works, then the game
stops giving the player a next thing to do, and each thing they try (buy, attack, roll) fails
or shows nothing new, while a Robux popup appears on every miss, often at under 20 FPS.

---

## 2. The package, one paragraph per stream

**WS1 Camp ladder.** A per-camp strength multiplier on the existing garrisons (same hook as the
Rebirth enemy scale in `BattleService` `scaledRoster`/`scaledPower`): Fort Roost x0.60
(power 106 → 64; WS1's plan says 0.50, the combined package in §4 needs 0.60), Ironbeak HQ
x0.55 (192 → 105); Cluck
Camp and the King unchanged; guard models, names and Kill Coins unchanged; no map geometry, no
save change. A new pure `src/shared/CampGuide.luau` replaces the 10-second "Next up" with a
readiness card: "Your Army can take Fort Roost! Attack!" only at ≥1.3x, otherwise the single
cheapest power step (Army Size, the podium chicken, Feed, or "Collect eggs: N more Coins for
…"), always with an "ARMY 38 / 69" bar. Odds bands become truthful (Very tough <1.0, Close
fight 1.0–1.3, Should win ≥1.3; today 1.3/2.0, and the headless fight threshold is ~1.2–1.3x).
Below 1.0x the first Send Army press warns and turns the prompt into "Attack anyway" for 5 s.
A loss says how much power is needed. Target: Fort Roost wins / Cluck Camp wins 24% → ≥55%;
attacks below 1.0x 73% → ≤20%; first Fort Roost win at 8–12 min.

**WS2 Early economy.** (1) Starter prices: empty-start profiles see podium offers at 25% of the
catalog quote, rising linearly to 100% as owned chickens go 2 → 20; rounded up to 5; never
below 150 or above the catalog (the catalog is untouched; this extends the owner's own
`StarterLadder` idea). (2) Rebirth 0 keeps the Upgrades tree and Feed levels (it still costs
1,700, resets Coins, pays +30 Gems and x1.5), which also removes the silent vacuum loss.
(3) Army Size I 300 (was 1,200; II stays 6,000 after the combined check, §4), still flat for
every rank. (4) "+N/s" gold
float after any purchase that raises income; the storage receipt says how to make the
chicken lay; the list price is struck through on the podium. Typical player: Coins/s at
minute 10 56 → 79, median purchase gap before minute 10 69 s → 49 s, Army Size I at minute 5
instead of 15; Rebirth 1–10 pacing inside the ±7% fit.

**WS3 Coins-shortfall prompt.** A server gate `CommerceService:CoinsPromptGate`
(`Config.CoinsPrompt`): the Robux checkout opens on a shortfall only after 10 minutes of
lifetime play or Rebirth 1, with the tutorial done; at most 2 a session, 10 minutes apart;
never when steady income covers the gap within 60 s. When held back: an info toast with no
error sound, "You need 1,240 more Coins! Collect eggs and sell them on the green pad.", a
"Need N" float at the target, podium and Feed prompts reading "Need N more Coins" with a
0.5 s hold while unaffordable (stray E presses stop firing; the lever also uses E), and once a
session a Shop-button glow for big gaps (never a checkout). `Mode = "Legacy"` restores Oct 23
exactly. Targets: pack prompts per session 1.59 → ≤0.25; sessions ending on a closed checkout
4.8% → ≤1.5%; failed podium Buys 46% → ≤25%. Worst-case revenue cost: ~147 R$ over two
days of current traffic (about US$0.36 after Roblox's cut).

**WS4 Roll discovery.** Lucky Start (new `src/server/LuckyStart.luau`, saved additive
`luckyStart`, empty-start profiles only, after the tutorial): post-tutorial pull 2 shows an
Uncommon on podium 1 and pull 8 a Rare, each drawn by today's odds inside that rarity; any
natural or forced offer pushes the next one 5 / 10 pulls later; at most 2 forced each; stops
once that rarity is owned or after 40 pulls. A visible "Rare in 6 Rolls" countdown on the
existing counter billboard and a "Lucky roll · Rare!" tag. A one-time guard before rolling
past a lucky offer or the next Rebirth find (Auto Roll exempt). "NEW!" podium tag for chickens
missing from the Index, the already-computed `PlayerSession:OfferAdvice` finally shown ("+18
Coins/s in your Flock"), a "NEW!" reveal float, the RollRare cue for Rares and a first-Rare
celebration, and "NEW CHICKEN! Bee Chicken · Index 4/83" via a shared `IndexProgress`.
Median first Uncommon / Rare: pull 13 / 87 → 2 / 8. Long-run Rare share over 300 pulls 0.77% →
1.1–1.4%; Epic and above, the Luck window, LuckBands and every "1 in X" label untouched.

**WS5 Post-tutorial flow.** A goal ladder inside the existing tip system, one card at a time,
never empty until Rebirth 1 (priority: Rebirth → Vacuum → Rebuild (after any Rebirth that
removed the vacuum) → Attack, extended ("Roll a chicken for your Army! (2/3)", the settle
wait shown as a count) → Camp (WS1's CampGuide) → Grow (up to three Upgrades nudges) → GOAL
progress (Rebirth 0 Coins, then the Rebirth 1 find, then Rebirth 1 Coins)). GOAL cards persist
for the first 15 minutes of a visit, then peek. Daily stays at completion (Stevin's choice) but
is granted the moment the tutorial completes, opens in a fixed order (payoff → Daily → first
tip), and waits for an open menu instead of force-closing it. A small beat queue spaces payoffs,
reveals and cards; corner notices wait while anything modal is open. Progressive HUD reveal
(same positions, timing only, each with a pop and a "NEW!" tag): Army, Rebirth, Settings at
completion; Playtime after the vacuum tips; Index at the first new species; Shop at 2,000 Coins
earned or Rebirth 0; Free Gift at 5 min; Gold Rush and boosts after Rebirth 0; everything by
8 minutes after completion. Analytics: a 15-event tail ring buffer per player (sees past the
60-event cap) and the card the client actually shows. Targets: leaving within 120 s of
completion 36.8% → ≤28%; exits with no visible card ~88% → ≤25%.

**WS6 Performance.** `PerfTier` (new client module) sets low/mid/high budgets from measured FPS
and device class (down a tier below 25 FPS for 4 s, up after 20 s at 50 FPS). DuckAnimator LOD
by screen, distance and a capped count of full-rate chickens, including voxel rigs that today
skip all limits and pose every bone every frame (the single largest client cost, 1.0 of
1.95 ms/frame on a Mac, ~8x on a low-end phone); cached attributes in the VFX code. Lighter
load path: no music or HUD in the preload (it preloads 549 s of music in serial batches of 8),
one parallel preload, the veil lifts at most 4 s after the profile is ready, no camera orbit
on the low tier, stream around the player's plot. Podium-preview and egg LOD. Low-tier render
budget (Bloom, SunRays, menu blur off; shadows off only under 22 FPS sustained). A pre-baked
Galaxy/Rainbow pattern image (the Luau generator freezes ~4 s on a phone). Studio work for
Stevin: CastShadow off on decor (the shadow pass is 70% of triangles), the 1,959 decor
Textures → one MaterialVariant, the ~3,744 instances of disabled reference GUIs moved out of
StarterGui, fewer PointLights. Targets: phone sessions <20 FPS 33% → ≤15%; loading veil
>10 s 9.4% → ≤4%; phone Cluck Camp wins 29% → ≥35%.

**WS7 Social and listing.** Server Moments: other players' firsts in the same server (first
Rare+ find, first Fort Roost / Ironbeak HQ / King win, Rebirth N, Hill winner; about 12 per
server-hour) as a system chat line ("{Name} found {Chicken}! 1 in {X}"); Epic+ and the King
also get a toast and a far light beam over that plot; nothing during the viewer's own
tutorial. A Visit button on Epic+ toasts (teleport to that plot sign, sharing the GoBase
cooldown). One Roblox invite prompt per session after Rebirth 0, the player's own Epic+ find
or the first Fort Roost win, only after 240 s, never with a friend present, never within 60 s of
a purchase prompt. Stevin: rewrite the listing (it still says Cash, Fuse, "Start with three
chickens"), drop the "Attack" thumbnail and A/B one creative showing lever → "1 in 9,400" →
Coins; Server Fill "Customize" with 1 social slot; custom matchmaking weights (Friends 30,
Occupancy 8, Language 6, Text Chat 2; 32% of sessions are Spanish or Portuguese). Phase 2:
Experience Notifications. Primary metric: 10-minute survival with vs without a seen moment,
+3 pp.

---

## 3. Conflicts the lead resolved

| # | Conflict | Decision | Why |
|---|---|---|---|
| C1 | FavoredRolls: WS4 cuts 5 × 60% to 3 × 50%; WS2 keeps it (owner Oct 25) | **3 pulls × 50%** (WS4). | Five favoured pulls cover the median player's whole post-tutorial session and halve the new species seen (1.37 vs 3.10). With starter prices the favoured Chicken is no longer the only affordable buy. Not 0: Stevin chose the favoured pulls a few days ago, so the cut is partial and one Config line. |
| C2 | Fort Roost strength (WS1 x0.50) stacks with cheaper Army Size and prices (WS2) and guaranteed early Uncommon/Rare (WS4) | **Strength 0.60 (power 64), and Army Size II stays 6,000** (§4). WS1 and WS2 follow these, not their own plans' 0.50 / 2,500. | Each plan hit 8–12 min alone; together at 0.50 the first win came at minute 6. |
| C3 | Shop reveal (WS5, 2,000 Coins earned) vs Robux gate (WS3, 10 min / Rebirth 1) | **Both, separately.** `Config.Guide.ShopRevealEarned = 2000` only reveals the Shop button. The checkout gate is `Config.CoinsPrompt`. `CommerceController.COINS_PROMPT_EARNED` is removed (WS3); `LegacyEarned` keeps 2,000 for `Mode = "Legacy"`. | Seeing the Shop is harmless; being pushed into checkout is the leak. |
| C4 | WS5 Rebuild card (re-claim vacuum and Flock I after Rebirth 0) vs WS2 KeepTree (Rebirth 0 no longer resets the tree) | **Build Rebuild generically**: it fires after any Rebirth that left the Egg Vacuum or Flock Size I unowned. With KeepTree it never fires after Rebirth 0, but it covers Rebirth 1+ (which still resets the tree) and `KeepTree = false`. | One card, both configurations. |
| C5 | WS2 asks WS5 for an Army Size tip; WS1's CampGuide already names Army Size as a step | **CampGuide owns it.** WS5's Grow list stays EggSpeed1, EggValue1, ArmySize1 but skips a node CampGuide is currently pointing at. | One voice per goal. |
| C6 | `firstFind`: WS7 wants it on `recruit.offer`; WS4 puts it on the receipt | **Both**: WS4 sets `recruit.firstFind` and `recruit.offer.firstFind`, plus `found`/`total`. | WS7 reads the offer; WS4's toast reads the receipt. |
| C7 | WS5 timeline still shows "the favoured basic Chicken (60%)" | Superseded by C1 and Lucky Start; WS5's copy reads the live offer, so nothing to change in code. | — |
| C8 | Rebirth 1 find (Ironbeak 1 in 146) is the biggest Rebirth 1 brake (WS2: swapping for a ~1 in 27 Common lifts Rebirth 1 by minute 30 from 7/30 to 19/30 typical) | **Not in this package.** Lucky Start makes the first Uncommon arrive at pull 2 and gives the Ironbeak 11% odds per forced Uncommon. Re-measure Rebirth 1 after publish; if Rebirth-1-by-30-min stays under 25%, change the find with the discovery probe (dated owner rule "Rebirth finds"). | One owner rule at a time where the data can't separate effects. |
| C9 | One `Schema.Version` bump, one `Config.Version` label | **Lead, Wave 0**: `Schema.Version = 16`, `Config.Version = "1.27.0-retention"`. | Every stream asked for it. |

---

## 4. Combined-package simulation (Fort Roost strength)

WS2's first-session model (30 seeds) and ProgressionSimulation (16 seeds a profile) ran the
whole package together: WS2 starter prices, Army Size I 300 and KeepTree; WS1 strength and the
readiness card; WS4 Lucky Start and FavoredRolls 3 × 50%. Full output:
[WS2 §9](retention-20261027/WS2-early-economy.md) and `retention-20261027/sims/ws2/combo/`.

**Decision: Fort Roost strength 0.60 (power 64), Ironbeak HQ 0.55 (105), and Army Size II
stays 6,000** (WS2's own plan had cut it to 2,500; together with everything else that made Fort
Roost a minute-6 formality).

First Fort Roost win, median / p90 (minutes):

| Package | Typical, follows the card | Typical, ignores it | Engaged |
|---|---|---|---|
| Current build | 28.6 (18 of 30 seeds) / never | — | 11.6 / 13.6 |
| 0.50, Army Size II 2,500 | 6.0 / 7.0 (too early) | — | 6.4 |
| 0.70, Army Size II 2,500 | 7.8 / 8.8 | — | 7.5 |
| **0.60, Army Size II 6,000** | **8.2 / 10.1** | **9.1 / 12.4** | **7.4 / 8.6** |
| 0.70, Army Size II 6,000 (fallback) | 8.7 / 10.4 | 11.2 / 12.7 | — |

At 0.60 / II 6,000, the typical player's Coins/s at minutes 5 / 10 go 18 / 56 → 38 / 160, Army
power 38 / 44 → 68 / 107, and the median gap between purchases before minute 10 69 s → 35 s.
Why the strength had to rise: the cheap fourth slot (about minute 3), Lucky Start's Uncommon
and Rare, and 150-Coin Chickens put power at 64–71 by minute 5.

Rebirth pacing (played minutes, current → package):

| Rebirth | Fast | Casual |
|---|---|---|
| 1 | 12.2 → 10.1 | 13.5 → 11.7 |
| 5 | 67.2 → 60.6 | 72.5 → 69.2 |
| 10 | 188.5 → 185.2 | 190.7 → 193.1 |
| 20 | 759 → 749 | 714.6 → 718.6 |

Ranks 10–20 stay within ±2%, so no Rebirth cost re-fit. Rebirth 1 comes 14–18% earlier, which
lands it on the fit's ~10-minute target (the current build runs 2–3.5 min over it). If Rebirth 1
should stay where it is, `StarterPrices.FullAt = 15` gives back about a minute.

Model limits: fights are won at ≥1.3x and never tried below it; the typical profile is fitted to
live earnings (absolute minutes ±30%; the differences between variants are the reliable part);
Lucky Start was approximated inside WS2's agent, not with WS4's probe; WS5's tip order was not
modelled. **Live rule:** if the median first Fort Roost win comes before minute 8, move to
0.70; after minute 13, to 0.50.

---

## 5. Owner rules this package changes

Stevin said "dont ask me for permission no more just do it", so these are decided. Each has a
Config switch that restores the old behaviour, and each needs a dated AGENTS.md line (the lead
writes them once, in Wave 3).

| Rule (date) | Change | Switch back |
|---|---|---|
| Coins shortfall opens a Coins pack directly (Oct 23) | Gated to 10 min play or Rebirth 1, 2 a session, 10 min apart | `Config.CoinsPrompt.Mode = "Legacy"` |
| Rebirth 0 resets the tree (Oct 23 contract, REBIRTH_SCREEN.md) | Rebirth 0 keeps the tree and Feed levels | `Config.Rebirth.Intro.KeepTree = false` |
| FavoredRolls 5 × 60% (Oct 25) | 3 × 50% | `Config.Economy.FavoredRolls` |
| Fort Roost ~107 (Oct 8) / guards keep exact strength (Oct 26 CAMP_GUARDS.md) | Per-camp strength multiplier | `Config.CampLadder.Strength = {1,1,1}` |
| Everything on the HUD once the tutorial is over (Oct 25) | Progressive reveal by 8 min | `Config.Guide.HudReveal = false` |
| No instructions after Daily (Oct 21) / three tip chains | Goal ladder until Rebirth 1, with a "Goal hints" Settings toggle | `Config.Guide.Goals/Rebuild/Grow = false` |
| Each chicken's price never below the old values (Oct 23) | Unchanged in the catalog; only the podium quote for new profiles is discounted (like StarterLadder) | `Config.Economy.StarterPrices.Enabled = false` |
| Army Size I 1,200 (Oct 20 tree) | 300 (II stays 6,000; still flat for every rank, Oct 22) | the tier price in `UpgradeCatalog` |
| Rarity shares (Oct 22) | Unchanged in the long run; the first 40 post-tutorial pulls of a new profile get two forced Uncommons and Rares at most | `Config.LuckyStart.Enabled = false` |

Not changed: Daily at completion, the eight tutorial cards, the 20-Coin second chicken, the
Luck window, every "1 in X", the Rebirth ladder costs, flat tree prices, voxel-only chickens,
the HUD layout, the Shop format, Stevin's sound library.

---

## 6. Parallel build: who writes what

Branching: each stream works in its own worktree on a branch cut from local `main` **after
Wave 0 is committed** (memory "Local main ahead of origin": fast-forward from local main, never
from `origin/main`). Rojo serves `main` only, so Studio checks happen on `main` after merges.
Workers never write mapped scripts through Studio MCP, never save or publish the place, never
push.

### Wave 0 — lead, before anyone starts (about an hour)

One commit on `main` that every branch starts from, so no worker edits these two files:

1. `src/shared/Config.luau`: every new block and value, exactly as written in the plans:
   - `Version = "1.27.0-retention"`.
   - `Economy.FavoredRolls = {rolls = 3, chance = 0.5, species = "Duck"}` (C1).
   - `Economy.StarterPrices = {Enabled = true, Fraction = 0.25, FullAt = 20, Floor = 150, Step = 5}` (WS2 §4.1).
   - `Rebirth.Intro.KeepTree = true` (WS2 §4.1).
   - `CampLadder = {Strength = {1, 0.6, 0.55}, ReadinessTip = true, AttackWarning = true}` (WS1 §4.1; 0.6 from §4, not WS1's 0.5).
   - `CoinsPrompt = {...}` (WS3 §3.1).
   - `LuckyStart = {...}`, `Discovery = {NewTag = true, Advice = true}` (WS4 §4.1).
   - `Guide = {...}` (WS5 §4.1).
   - `Performance = {TiersEnabled = true, AnimLOD = true, VeilCapSeconds = 4, StagedBoot = false, ...}` (WS6 §4.1–4.9; the full key list is in those sections).
   - `Social = {...}` (WS7 §4.1).
2. `src/server/AnalyticsSchema.luau`: `Schema.Version = 16` and the union of every stream's new
   names (WS1 §4.9, WS2 §5.1, WS3 §5.1, WS4 §5, WS5 §5, WS6 §5.2, WS7 §5.1), appended in that
   order. Append only; never rename or reorder.
3. Update `tests/AnalyticsChecks.luau` for Version 16 so the suite stays green.

### Wave 1 — seven streams in parallel, exclusive files

Every file below has exactly one writer. A stream that needs something in another stream's
file uses the interface in §7; it never edits the file.

| Stream | Exclusive files (new files in bold) |
|---|---|
| WS1 | **`src/shared/CampGuide.luau`**, `src/shared/Progression.luau`, `src/server/BattleService.luau` (including WS7's nil-safe `onFirstWin` callback, WS7 §4.6), `src/client/BaseController.luau`, **`tests/CampGuideChecks.luau`**, `tests/FoundationChecks.luau`, **`tools/sim/camp_probe.luau`**, **`docs/team/CAMP_LADDER_20261027.md`**, `docs/team/CAMP_GUARDS.md` |
| WS2 | `src/shared/Rules.luau` (`Rules.StarterPrice`), `src/shared/UpgradeCatalog.luau`, `src/server/RebirthService.luau`, `src/client/RebirthPanel.luau`, `src/client/ActionFeedback.luau`, `tests/ProgressionSimulation.luau` (including WS1's `campPower × strength` and attack-ratio hunks, WS1 §6.1), `tests/RebirthV2Checks.luau`, **`tests/StarterPriceChecks.luau`**, **`tools/sim/first_session_probe.luau`**, **`docs/team/EARLY_ECONOMY_20261027.md`**, `docs/team/REBIRTH_SCREEN.md` |
| WS3 | `src/server/CommerceService.luau`, `src/client/CommerceController.luau` (including `LastPromptAt()` for WS7), `src/client/UpgradeBoardController.luau`, `src/client/ToolController.luau`, `src/client/ResearchBrowser.luau`, **`tests/CoinsPromptChecks.luau`**, `docs/team/COINS_SHORTFALL_PROMPT.md` |
| WS4 | **`src/server/LuckyStart.luau`**, **`src/shared/IndexProgress.luau`**, `src/server/RollService.luau` and `src/server/RollStation.luau` (WS4 applies WS2's price hunks, WS2 §4.3–4.4, WS3's "Need N" / hold branch, WS3 §4.8, and WS7's `firstFind`, C6), `src/server/PlayerSession.luau`, `src/client/RollPresentationController.luau` (WS4 parts only; WS6's come in Wave 2), `src/client/IndexBrowser.luau`, **`tests/LuckyStartChecks.luau`**, **`tools/sim/discovery_probe.luau`**, **`docs/team/LUCKY_START_20261027.md`** |
| WS5 | `src/shared/TutorialGuide.luau`, `src/client/CommanderGuide.luau`, `src/client/HudController.luau` (including `HintShop` for WS3), `src/client/DailyRewardController.luau`, `src/client/CornerNotice.luau`, `src/client/PlaytimePanel.luau`, `src/client/GoldRushController.luau`, `src/client/BoostReadout.luau`, `src/server/TutorialService.luau` (including WS1's `AttackWarned` / `AttackAnyway` signal names), `tests/CommanderGuideChecks.luau` (including WS2's Army Size fixture and WS4's favoured-pull assertion), `tests/DailyChecks.luau`, `tests/PlaytimeChecks.luau`, **`docs/team/POST_TUTORIAL_FLOW_20261027.md`**, `docs/team/COMMANDER_TUTORIAL.md` (including the WS2 Rebirth 0 and WS4 favoured-pull notes), `docs/analytics/ONBOARDING_FUNNEL.md` |
| WS6 | **`src/client/PerfTier.luau`**, `src/bootstraps/PetRollClient.client.luau`, `src/client/ChickenEffectQuality.luau`, `src/client/DuckAnimator.luau`, `src/client/VoxelChickenAnimator.luau`, `src/client/SpecialChickenVFX.luau`, `src/client/RareChickenVFX.luau`, `src/client/EggController.luau`, `src/client/EggView.luau`, `src/client/LoadingController.luau`, `src/client/WorldFeel.luau` (including WS7's `Beacon`, WS7 §4.12, with a low-tier off switch), `src/client/CoinBurst.luau`, `src/client/HillIntro.luau`, `src/client/ChickenTexturePattern.luau`, `src/client/LeaderboardBoards.luau`, `src/client/AnalyticsClient.luau`, `src/client/AnalyticsUiObserver.luau`, **`docs/team/MOBILE_PERFORMANCE_20261027.md`** |
| WS7 | **`src/shared/SocialMoments.luau`**, **`src/server/SocialService.luau`**, **`src/client/ServerMoments.luau`**, `src/client/FriendBoost.luau`, `src/server/HillService.luau`, `src/server/AnalyticsPlayer.luau`, **`docs/team/SOCIAL_MOMENTS.md`**, `docs/team/GAME_FEEL_20261021.md` |

**Wiring files.** Five files take small hunks from almost every stream:
`src/server/GameServer.luau`, `src/client/AppController.luau`, `src/server/Analytics.luau`,
`src/server/AnalyticsReport.luau`, `src/server/AnalyticsFunnels.luau`. On its own branch, a
stream may edit **only the hunks its plan lists** for these files (each plan's §4 names them),
wrapped in a `-- Oct 27 WSn:` comment. The lead merges them in the order of Wave 3 and resolves
any textual conflict. Nobody else edits these files during the build. This is the one
exception to one-writer-per-file, and it is safe because the branches are separate worktrees.

### Wave 2 — sequential follow-ups (after the Wave 1 branch they depend on is merged)

| Follow-up | Writer | Waits for |
|---|---|---|
| WS6 P4 podium-preview LOD in `RollPresentationController.luau` (WS6 §4.7) | WS6 | WS4 merged |
| WS6 P7 shared world watcher: **`src/client/WorldIndex.luau`**, `PromptStyleController`, `GalaxyCrateVisuals`, `UpgradeBoardController`, `EggProcessorController` (WS6 §4.15) | WS6 | WS3 merged; measured after P1–P5 |
| WS6 P8 pre-baked Galaxy/Rainbow image | WS6 | Stevin uploads the image |

### Wave 3 — lead integration, in this merge order

1. **WS6** (client-only, isolated; gives every later stream `PerfTier.Budget()` for new VFX).
2. **WS5** (tip/goal framework, `ModalBusy`, `Beat`, `TutorialComplete`, `HintShop`).
3. **WS1** (CampGuide plugs into WS5's Camp slot; the hook tolerates its absence).
4. **WS2** (`Rules.StarterPrice`, Army Size, KeepTree).
5. **WS4** (RollService/RollStation with WS2/WS3/WS7 hunks; needs `Rules.StarterPrice`).
6. **WS3** (needs `Hud:HintShop`, `app:ModalBusy`).
7. **WS7** (needs `TutorialComplete`, `LastPromptAt`, `onFirstWin`, `firstFind`, `Beacon`).
8. Wave 2 items.
9. Docs: `AGENTS.md` (one dated paragraph per §5 row, replacing nothing silently),
   `tools/sim/README.md` (one bullet per new probe), `docs/analytics/AGENT_GUIDE.md` and
   `TRACKING_PLAN.md`.

After each merge: run the headless suites the stream lists in its §6 plus the shared ones
(`CommanderGuideChecks`, `AnalyticsChecks`, `FoundationChecks`), and luau-lsp `analyze` against
the HEAD baseline (memory "Local Luau checks"). Fix forward on `main` before the next merge.

### Stevin-only work (any time; no code)

| Task | From | Time |
|---|---|---|
| CastShadow off on Decor, fences and small props; the 1,959 decor Textures → one MaterialVariant; move `StarterGui.GUI` / `MainGUI` reference GUIs to `ServerStorage.UIReference`; trim PointLights; save the place | WS6 §4.16 | ~1 h in Studio |
| Upload the pre-baked Galaxy/Rainbow pattern image | WS6 §4.13 | 10 min |
| Listing: paste the new description; drop the "Attack" thumbnail; A/B one new creative | WS7 §3.4 | 30 min + creative |
| Server Fill "Customize" with 1 social slot (server size stays 6); custom matchmaking weights | WS7 §3.1 | 15 min |
| Phase 2 only: an Open Cloud key with the notifications scope in Secrets | WS7 §3.5 | later |

---

## 7. Interfaces between streams (contracts)

| Provider | Interface | Used by |
|---|---|---|
| WS1 | `CampGuide.When(state, facts): boolean`, `CampGuide.Card(state, facts): card?` with `{id, text, target ("Camp<n>" / "Upgrades" / "RollStation" / "FeedTool" / "Yard" / "EggDeposit" / nil), node?, outside?, index, total, tag, progress}`, `CampGuide.Ids`, `CampGuide.EvenRatio = 1.0`, `CampGuide.ReadyRatio = 1.3` | WS5 (Camp slot, priority 5; renders `progress` as a bar) |
| WS1 | `BattleService.onFirstWin(attacker, campIndex, isKing)` (nil-safe callback set by GameServer) | WS7 |
| WS2 | `Rules.StarterPrice(listPrice: number, owned: number): number` (pure; WS2 §4.2); offers carry `listPrice` when discounted; Buy replies carry `income` | WS4 (price line), WS3 (`needCoins` uses the offer price automatically), WS1 (advice reads live prices) |
| WS3 | `CommerceController:LastPromptAt(): number` (os.clock of the last Roblox purchase prompt); no checkout within 60 s of `FriendBoost.lastInviteAt`; server replies carry `needCoins` only when the gate allows, and always `shortCoins` and `coinsGate` | WS7, WS5 (shortfall copy) |
| WS4 | Buy receipt `firstFind`, `found`, `total` (also on `recruit.offer.firstFind`); `IndexProgress.Count(session)`; offers carry `new` and `lucky`; `state.luckyStart` in the snapshot | WS7, WS5 (Index reveal, optional "Save for your Rare!" tip) |
| WS5 | `app:ModalBusy(): boolean`, `app:Beat(kind, seconds)`, `app:BeatBusy(): boolean`, `app:TutorialComplete(): boolean`, `Hud:HintShop(seconds): boolean` (false until Shop is revealed), `Hud:Revealed(name)`; shortfall wording matches `TutorialGuide`'s `earn()` ("Sell your eggs on the green pad") | WS3, WS4 (big reveals call `Beat`), WS7 (invite counts as modal) |
| WS6 | `PerfTier.Get()`, `PerfTier.Budget()` (`worldFeelLimit`, `fxMaxChickens`, …), `PerfTier.Changed`; journey keys `fl/fp/tier/fo/lr` | every stream that adds VFX or motion (owner rule: shared vocabulary, no private budgets) |
| WS7 | `FriendBoost.lastInviteAt`, `friendBoost.invitePromptOpen` (feeds `ModalBusy`) | WS3, WS5 |

---

## 8. Verification before publish (lead, on `main`, after Wave 3)

1. **Headless (Lune).** All suites in `tests/` that each plan's §6 lists, plus
   `tools/sim/camp_probe.luau`, `first_session_probe.luau`, `discovery_probe.luau`,
   `rarity_probe.luau` (long-run shares unchanged) and `ProgressionSimulation` (16 seeds, fast
   and casual: Rebirth 1/5/10/20 inside ±7% of the current fit).
2. **Studio, fresh profile** (`TestNewPlayer`, Pet Roll Test 96683186622050, Rojo connected by
   Stevin), the combined script:
   - Tutorial to completion: payoff → Daily → first tip, no menu force-closed; HUD shows only
     Army, Rebirth, Settings (WS5).
   - Vacuum chain; Playtime reveals after it; the Attack card counts "2/3" chickens (WS5).
   - Post-tutorial pull 2 shows an Uncommon with "NEW!" and the advice line; the counter reads
     "Rare in N Rolls"; the price shows the starter quote with the list price struck through
     (WS4, WS2).
   - Tap Buy short of Coins: info toast and "Need N" float, no Robux checkout; the podium
     prompt needs a hold (WS3).
   - Cluck Camp won → readiness card with the ARMY bar names one step; attack Fort Roost below
     1.0x: the warning, then "Attack anyway" (WS1).
   - Rebirth 0: the vacuum and Flock Size I stay; the GOAL card follows (WS2, WS5).
   - A second test player in the server sees a chat line for the first player's Rare (WS7,
     `multiplayer_playtest`).
3. **Phones.** Studio device emulation for a low-end phone with a full yard: profiler before
   and after per WS6 §6; check the tier drops and the game still animates and sounds (owner
   rule: game feel stays).
4. **Owner-visible art check.** Screenshots of the readiness card, the podium tags, the Lucky
   counter, the toast and the NEW tags, sent to Stevin.

Publishing stays Stevin's call (File > Publish, "Migrate To Latest Update").

---

## 9. Measuring after publish

Compare `1.27.0-retention` against 1.25.0 and 1.26.0 by `version`, new profiles, equal-length
ranges, read with `AnalyticsReport` from Studio Edit (`env="live"`). Two days of traffic at the
current ad spend is enough for the large effects; the social metric needs a week.

| Metric | Baseline (1.25.0) | Target | Stream |
|---|---|---|---|
| Still playing at 3 / 10 / 30 min | 48% / 21% / 7% | 55% / 30% / 12% | all |
| Finishers gone within 120 s of completion | 36.8% | ≤28% | WS5 |
| Exits with no visible card | ~88% | ≤25% | WS5 |
| Post-vacuum-gap exits | 26% | ≤8% | WS5 |
| Fort Roost wins / Cluck Camp wins | 24% | ≥55% | WS1 |
| Fort Roost attacks below 1.0x | 73% | ≤20% | WS1 |
| Median play at first Fort Roost win | — (~18 min modelled) | 8–12 min | WS1, WS2 |
| Failed podium Buys | 46% | ≤25% | WS2, WS3 |
| Median purchase gap before minute 10 | 69 s (model) | ≤50 s | WS2 |
| Coins-pack prompts per session | 1.59 | ≤0.25 | WS3 |
| Sessions ending on a closed checkout | 4.8% | ≤1.5% | WS3 |
| Finishers owning Uncommon+ / Rare+ in session 1 | ~5% / ~1% (estimates) | ≥35% / ≥10% | WS4 |
| Phone sessions under 20 FPS | 33% | ≤15% | WS6 |
| Loading veil over 10 s | 9.4% | ≤4% | WS6 |
| Phone Cluck Camp wins | 29% | ≥35% | WS6 |
| 10-min survival, saw a moment vs not | — | +3 pp | WS7 |
| Next-day return (profile scan) | Fort Roost winners 39% vs 2.4% | more players in the first group | WS1 |
| Robux per day | 754 R$ / 2 days | not below −40% without a retention gain (then lower the WS3 play gate to 5 min) | WS3 |

If a metric misses: each stream's §7 names its rollback switch (§5 above), and the WS5 tail
ring buffer shows the last 15 events before each exit, so the next diagnosis does not depend
on the first three minutes of a journey.
