# WS1 — Fort Roost / camp progression wall

> **Lead note (Oct 27, after the combined-package check):** the integrated plan sets Fort Roost
> strength to **0.60**, not 0.50, because WS2's prices and WS4's Lucky Start also raise early power.
> See `docs/team/RETENTION_PLAN_20261027.md` §4.

Worker: WS1 (research + plan only; no repo edits were made). Date: 2026-10-27.
Build studied: `main` @ c6153d1 (live 1.25.0 data, Oct 26–27).
Scratch tools written for this plan (copy into `tools/sim/` when building, see §6):
`docs/team/retention-20261027/sims/ws1/`
(`battle.luau` headless camp fights on the real `Battle.luau` + map geometry; `sweep1–5.body`
fight sweeps; `early.luau` data-calibrated early-player model; `sim_strength.luau` +
`simdrive2.body` ProgressionSimulation with per-camp strength; `ws2cross.txt` WS2-model cross-check).

## 0. Recommendation in one paragraph

Fort Roost is not a "hard camp", it is an impossible one for the Army a new player owns at
minutes 3–15: three Army slots of Commons top out at 57 power against 106, and the headless
fight needs about 1.2x (127) to win. Fix it with three pieces that need **no new map
geometry and no save change**: (1) a per-camp **strength** multiplier on the existing
garrisons (Fort Roost x0.50 → power 53, Ironbeak HQ x0.55 → 105; all six guard models,
names and Kill Coins unchanged; King unchanged), (2) a **readiness card** that replaces the
10-second "Next up: conquer Fort Roost!" with either "Your Army can take Fort Roost!" (only
at ≥1.3x) or the single cheapest step to get there (Army Size, the podium chicken, Chicken
Feed), always with an "ARMY 38 / 69" power bar, and (3) a **below-even-odds confirm** on the
Send Army prompt plus truthful odds bands (Very tough <1.0, Close fight 1.0–1.3, Should win
≥1.3). A data-calibrated model puts the first Fort Roost win at **~9.5 min p50 (p90 ~10.5)**
for a player who follows the card (today: ~17.7 min even when guided, and effectively never
for the unguided 79% who stay at 3 Army slots).

---

## 1. Problem & evidence

All numbers from `summary125.json` (ledger, both days, all players), `raw125.json` (per-day
ledger counters) and `journeys27.json` (847 new-player first sessions, 1.25.0). Queries were
run with `python3 -I` over the JSON; the exact snippets are reproducible from the field
names below.

### 1.1 The camp funnel (ledger `camp.*`, Oct 26+27)

| Camp | Attempts | First wins | Fails (Defeated / Retreat) | Attempts before a win |
|---|---|---|---|---|
| Cluck Camp (12) | 1,354 | **558** | 147 (90 / 57) | 727 |
| Fort Roost (106) | 1,656 | **135** | 1,263 (1,066 / 197) | 1,542 |
| Ironbeak HQ (192) | 411 | 78 | 184 (131 / 53) | 340 |
| King (497) | 191 | 21 | 54 | 159 |

- Fort Roost first wins / Cluck Camp first wins = 135 / 558 = **24%**.
- **1,214 of 1,656 Fort Roost attempts (73%) launched below 1.0x**, and 1,214 of its 1,263
  fails (96%) are those. One win below 1.0x, ever.
- ~11.4 attempts per eventual first win (1,542 / 135).

### 1.2 Win rate by odds band (ledger `camp.CampN.odds.<band>.<result>`)

| Band (attack/target power) | Cluck Camp | Fort Roost | Ironbeak HQ | King |
|---|---|---|---|---|
| Under 1.0 | – | 1 / 1,215 (0.1%) | 0 / 120 | 2 / 51 |
| 1.0–1.3 | 3 / 93 (3%, one-chicken Armies) | 37 / 70 (53%) | 20 / 70 (29%) | 10 / 15 (67%) |
| 1.3–2.0 | – | 65 / 77 (84%) | 41 / 51 (80%) | 8 / 8 |
| 2.0+ | 555 / 612 (91%) | 32 / 36 (89%) | 17 / 21 (81%) | 1 / 1 |

Today's bands (`TutorialGuide.luau:283-290`: Very tough <1.3, Close fight 1.3–2, Should win
≥2) are wrong at both ends: "Very tough" lumps a certain loss (<1.0) with a coin flip
(1.0–1.3), and the 1.3–2.0 "Close fight" band actually wins 80–84%.

### 1.3 The Army new players own (why <1.0x is the norm)

- `state.armySize` snapshots: **1,215 of 1,530 (79%) at 3 slots or fewer** (`Config.StartingSlots=3`).
- Army Size I bought 348 times in two days (84 + 264, `upgrade.buy.ArmySize1`) against 558
  Cluck Camp first wins — most players never buy a 4th slot.
- Power per chicken (`Rules.PetPower`, level 1, headless): basic Chicken 13.0, Commons 16.0–19.9,
  Uncommons 29.7, Rare Bucket 38.4. Feed adds +25% of base per level (`Config.PetCombatPerLevel`).
- Fort Roost guards: Roost Warden 38.4 + Roost Archer 29.7 + 2× Roost Recruit 19.3 = **106**.
- Best 3-slot Armies: 3 basic Chickens 38 (0.36x), 3 Commons 57 (0.53x), 3 Uncommons 89 (0.84x).
  **No 3-slot Army of the chickens a new player rolls in the first 15 minutes can reach 1.0x.**
- Cluck Camp winners (281 of 847 new first sessions, 33%): won Cluck Camp at median 159 s
  (p25 130, p75 239), then played a median 270 s more (p25 105, p75 488); session median
  458 s; 4 chickens (p25 3, p75 7); 5,342 Coins earned (p25 2,472, p75 13,643).
- Earned Coins at session end for Cluck Camp winners, by session length: 3–5 min 2.2K,
  5–8 min 5.5K, 8–12 min 9.1K, 12–18 min 17K, 18–30 min 272K (the model in §3.4 is
  calibrated to these).

### 1.4 What "74% exited on TipNextCamp2" really means

209 of 281 winners have `ex = TipNextCamp2`. The card is on screen for only 10 s
(`Guide.NextCampTipSeconds`, `TutorialGuide.luau:362`; client skip at
`CommanderGuide.luau:392-396`), but the **server** resolves the guide without the client's
skip list (`TutorialService.luau:190`, `Guide.Resolve(state)`), so the recorded step stays
`TipNextCamp2` until Fort Roost is won. So the true reading is: 74% of Cluck Camp winners
left while their only goal was a camp they could not win, with no card on screen for ~4.5
minutes and a "NEXT: FORT ROOST" world marker (`BaseController.luau:632-651`) pulling them
into it. (WS5 found the same, `WS5-post-tutorial-flow.md` §1.)

### 1.5 Why it matters

Fort Roost winners return next day 39% vs 2.4% (brief). Survival 21% at 10 min; 42% of new
sessions end after minute 3 and 74% of those had already won Cluck Camp — they were engaged
and hit the wall.

---

## 2. Root cause in code

| Where | What |
|---|---|
| `src/shared/Progression.luau:63-72` | Rosters: Cluck Camp `{"Duck"}` (12); Fort Roost Warden+Archer+2 Recruits L1 (106, Oct 8 tuning "so about five Uncommon/Rare level-1 chickens can take it"); Ironbeak 2 Grunts L2 + Sapper L2 + Major L1 (192). The Oct 23 empty start lowered only Cluck Camp (38→12); the step to camp 2 went from 2.8x to **8.8x**. |
| `src/shared/Rules.luau:192-203` | `PetPower = sqrt(hp·damage/interval)` (×1.35 splash); `Power` = floor of the sum. Linear in Feed level; Army upgrades (Damage/Health) are not counted. |
| `src/server/Battle.luau:225-238, 101-118, 535-541` | Capture needs every guard down at once **and** the meter full (20 s at camp 2, `Config.ConquestSecondsByCamp={12,20,25}`); guards respawn every 10–15 s (`DefenderRespawnMin/MaxSeconds`); an Army that is fully knocked out at once loses (`LostFoothold`); fallen attackers respawn at home after 5 s (`AttackerRespawnSeconds`) and walk ~150 studs back (Fort Roost at radius 161.5, homes at 314.5, `MoveSpeed=13`). Result: a sharp threshold, not a gradient (§3.1). |
| `src/server/BattleService.luau:30-50, 367, 771-773, 330` | Garrisons pass through `scaledRoster(roster, enemyScale(session))`, which already multiplies hp and damage and reports `scaledPower`. Only Rebirth rank feeds it (1 at rank 0). This is the hook used below. |
| `src/shared/UpgradeCatalog.luau:113-116` | Army Size tiers 4/6/8/10 slots at 1,200 / 6,000 / 25,000 / 90,000 Coins. Fort Roost at ≥1.2x with Commons needs 6–7 slots (7,200 Coins of slots alone). |
| `src/shared/TutorialGuide.luau:283-290` | Bands 1.3 / 2.0 (see §1.2). |
| `src/shared/TutorialGuide.luau:359-377, 446-451` | `NextCamp` chain: one timed 10 s card "Next up: conquer <camp>!", no odds check. |
| `src/client/BaseController.luau:78-86, 726-729` | Prompt hint "Very tough · 4 defenders · …" — nothing stops or warns a 0.36x attack; `HoldDuration=0.15`. |
| `src/client/BaseController.luau:632-651` | NEXT marker over the next camp whenever no guide card shows, regardless of odds. |
| `src/server/BattleService.luau:1029` | Defeat line: "Army defeated. Your chickens respawn at home; send them again whenever you're ready." — no reason, no target. |

---

## 3. Options considered and the recommended design

### 3.1 How fights actually resolve (headless, real `Battle.luau`, real map geometry)

`ws1/battle.luau` runs `Battle.new(...)` with target `camp:2`, the army leaving
`MapLayout.HomeFrame(1)` and the camp at `Config.CampRadii[2]` on that spoke, `March.Approach`
for the walk, 0.1 s steps, no actors. 12–30 seeds per row (only the guard respawn timer is random).

Fort Roost (106), uniform armies:

| Army | Power | Ratio | Win |
|---|---|---|---|
| 4 Commons L3 / 6 Commons L1 / 6 Chickens L3 / 4 Uncommons | 115–118 | 1.08–1.11 | 0% |
| 5 Commons L2 | 120 | 1.13 | 0% |
| 8 Chickens L2 / 5 Chickens L5 | 129 | 1.22 | 85% |
| 7 Commons / 6 Chickens L4 / 4 Commons L4 | 135–136 | 1.27–1.28 | 95–100% |
| 6 Commons L2 and up | ≥144 | ≥1.36 | 100% |

Same armies against a scaled Fort Roost (hp and damage ×s, exactly what `scaledRoster` does):

| Army (realistic minute 5–12) | Power | ×1.00 (106) | ×0.60 (64) | ×0.50 (53) | ×0.45 (48) |
|---|---|---|---|---|---|
| 3 Chickens | 38 | 0% | 0% | 0% | 0% |
| Chicken + 2 Commons | 48 | 0% | 0% | 0% (0.90) | 0% (1.00) |
| 3 Commons | 57 | 0% | 0% | 0% (1.07) | 92% (1.19) |
| 4 Chickens | 51 | 0% | 0% | 0% (0.96) | 0% (1.06) |
| 2 Chickens + 2 Commons | 61 | 0% | 0% | 0% (1.14) | 100% (1.27) |
| 4 Chickens L2 | 64 | 0% | 0% | 33% (1.20) | 100% |
| 4 Commons | 73 | 0% | 0% | 100% (1.37) | 100% |
| 3 Chickens + 2 Commons | 74 | 0% | 25% | 100% | 100% |
| 4 Chickens L3 / 6 Chickens | 77 | 0% | 33–92% | 100% | 100% |

Ironbeak HQ (level-2 guards plus the Major) needs ~1.35–1.4x headless (5 Uncommons L4 1.35 →
40%; 7 Rares 1.40 → 90%); live 1.3–2.0 wins 80%. Single-chicken Armies need more (Cluck Camp:
one Common at 1.25x wins 33%, at 1.58x 100%), which matches the live 3% at 1.0–1.3.

Conclusion: across compositions the win threshold is ~1.2–1.3x for multi-chicken Armies
(1.35–1.4x for level-2 garrisons). Live play is noisier (1.0–1.3 wins 53% at Fort Roost).
**"Should win" belongs at 1.3x, "Very tough" below 1.0x.**

### 3.2 Options for the ladder

| Option | Verdict |
|---|---|
| A. New stepping-stone camp between Cluck Camp and Fort Roost | Rejected. Needs authored scenery on all six lanes (camps are `AuthoredScenery`, `WorldBuilder.BuildCamp:316-321`; the lane radii 232/161/93 are filled and the outposts list is empty because the builder map has no outpost sites, `Progression.luau:81`). Camp ids are positional: inserting one shifts `firstWins[2/3]` in every save; appending it as camp 4 puts it in the wrong place on the road and changes `KingUnlocked` (all camps) for players who already beat three. |
| B. Swap guards for weaker ones / fewer guards (e.g. Archer + 2 Recruits = 68, 3 Recruits = 58) | Rejected. Drops Stevin's Oct 26 guard lineup (Warden/Archer models unused) and the closest compositions land at 58–68, still a 4-slot-with-Feed requirement (2 Chickens + 2 Commons at 61 vs 3 Recruits loses headless). |
| C. Change the guard species' catalog stats | Rejected. The guard species are shared with the camps' idle display and keep "copies the stats of" (Oct 26 doc); a stat edit is invisible in review and hard to roll back. |
| D. **Per-camp strength multiplier on the existing garrison** (same hook as Rebirth enemy scale) | **Recommended.** One number per camp, all four guard models and names stay, Kill Coins unchanged (they follow `economyBase`), saves untouched, rollback = `1`. |
| E. Only make players stronger (cheaper Army Size, cheaper Commons) | WS2's lane. WS2's own model (`retention/ws2`, typical profile, fort power 138 = 106×1.3) still reaches Fort Roost in 2–3 of 30 runs by minute 25 even with its proposal (Army Size I 300, II 2,500, chickens ×0.25). Necessary but not sufficient. |
| F. Only guidance (keep 106) | Model: a perfect follower still needs ~16 min (§3.4); the typical player 18+. Not sufficient. |

### 3.3 Recommended ladder (D)

| Camp | Garrison (unchanged) | Base power | Strength | **Power shown and fought** | Should win at (×1.3) | Step from previous |
|---|---|---|---|---|---|---|
| Cluck Camp | 1 basic Chicken | 12 | 1.00 | 12 | 16 | – |
| Fort Roost | Warden, Archer, 2 Recruits (L1) | 106 | **0.50** | **53** | 69 | ×4.4 (was ×8.8) |
| Ironbeak HQ | 2 Grunts L2, Sapper L2, Major | 192 | **0.55** | **105** | 137 | ×2.0 |
| King | unchanged (`KingEncounter`) | 497 | – | 497 | 647 | ×4.7 |

Why 0.50 and not 0.45 or 0.60: at 0.45 three Commons already win with 3 slots (the step "buy a
4th slot" disappears and Fort Roost becomes a second Cluck Camp; the guided model gains only
0.3 min). At 0.60 the guided median is 9.4 min ready / ~11 min win and the WS2 typical
profile 16+ min. 0.50 lands the guided median in the target band and keeps the lesson "your
Army needs to grow" (4 slots + one Common or Feed).

Ironbeak at 0.55 = 105 puts the old Fort Roost number exactly one camp later, where players
with Army Size II reach it (headless: 6 Commons L2 1.36x → 80%, 5 Uncommons 1.40x → 100%).
Without it the new step 53 → 192 (×3.6) recreates a wall at minute ~15. It is a separate
value; if the lead wants the smallest change, ship Fort Roost alone and keep Ironbeak at 1.0.

Enemy scale for Rebirth ranks multiplies on top (`RebirthService.EnemyScale`); the strength
is the same on every lane (other commanders' camps), so lanes stay fair.

### 3.4 Time to the first Fort Roost win (simulated)

**Model** (`ws1/early.luau`): starts after the tutorial (two basic Chickens, Flock 4, 0 Coins
at 1.5 min); income from the real `Rules.Income` of the best Flock-size layers × collection
efficiency 0.6; a lever pull every 45 s with the real zero-Luck odds and the five favoured
basic-Chicken pulls (60%); real prices (Commons 1,900–3,000, Army Size, Feed quotes).
Calibration (policy A = today's behaviour: buys chickens and early economy hexes, never Army
Size): earned 3.1K at 6 min, 9.6K at 10 min, 25K at 15 min vs the data's 5.5K / 9.1K / 17K,
power 38 at 6 min, 41–51 at 10 min (79% of snapshots ≤3 slots). Policy B = follows the
readiness card exactly (§3.5 advice, best power per Coin). "Ready" = power ≥ 1.3x. 300 seeds.

| Fort Roost | Unguided (A): ready by 10 / 15 min | Guided (B): ready p25 / p50 / p90 | ≈ first win (p50 + ~1.5 min march+fight) |
|---|---|---|---|
| 106 (today) | 0% / 0% | 15.6 / 16.2 / 17.8 min | ~17.7 min |
| 64 (×0.60) | 0% / 0% | 9.2 / 9.4 / 10.2 | ~10.9 |
| **53 (×0.50)** | 1% / 7% | **7.8 / 8.0 / 8.8** | **~9.5** |
| 48 (×0.45) | 5% / 13% | 7.4 / 7.7 / 8.6 | ~9.2 |

Sensitivity at ×0.50 (guided p50): collection 0.45 → 10.2 min, 0.8 → 6.3 min; lever every
30 / 60 / 90 s → 7.9 / 7.9 / 8.1 min. At ×1.00: 21.1 / 12.8 min. Both pieces are needed:
strength alone barely moves unguided players (they stay at 3 slots); guidance alone leaves 16+ min.

**Cross-check with WS2's independent model** (`retention/ws2/early.luau`, its own spending
policy, attacks at a fixed power; I set it to the Should-win power):

| WS2 profile | Prices | Fort Roost ready = 69 (×0.50) | = 138 (today) |
|---|---|---|---|
| typical | today | 16.6 min (29/30 by 25 min) | 2/30 by 25 min |
| typical | WS2 proposal (Army Size I 300, II 2,500, chickens ×0.25) | **11.3 min (30/30)** | 3/30 by 25 min |
| engaged | today | 9.6 min | 11.6 min |
| engaged | WS2 proposal | 6.6 min | 9.1 min |

WS2's typical player is unguided (buys Army Size I at 15 min today, 7 min with WS2's price);
with the readiness card pushing Army Size first it moves toward the guided column. **Target
band 8–12 min holds with or without WS2's prices; do not combine WS2's price cut with a
strength below 0.50** (engaged players would win at ~6 min, before they have learned the
Army at all).

ProgressionSimulation (casual, 8 seeds × 6 h, `ws1/simdrive2.luau`, strength applied to
`campPower`): Fort Roost 11.8 → 9.5 min, Ironbeak 16.5 → 11.5 min, King 28.0 → 26.5 min,
**Rebirth 1 13.0 → 13.5, Rebirth 5 73 → 72, Rebirth 10 190.5 → 186.8 min** — the Rebirth
ladder (Oct 21–23 fits) is unaffected within seed noise. (The sim's economy runs ~3x faster
than real players in minutes 5–15; it is only used for the pacing check.)

### 3.5 Readiness card (replaces the timed NextCamp card)

Lives in a new shared module `src/shared/CampGuide.luau` (WS5's agreed provider interface:
`CampGuide.When`, `CampGuide.Card`, `CampGuide.Ids`; WS5 owns the chain slot, rendering and
`TutorialGuide.luau`). Snapshot-only, so the server's `TutorialService` resolve reports the
real card (fixes the §1.4 attribution as a side effect).

**When:** `tutorial.guideCompleted` and `CampGuide.NextCamp(state)` (first own-lane camp after
Cluck Camp not in `firstWins`, i.e. 2 then 3) and `Config.CampLadder.ReadinessTip`. Persistent
(no `seconds`): it is the post-tutorial goal; WS5's chain order keeps Rebirth/Vacuum/Attack
ahead of it. Never while the Army is away (framework rule).

**Numbers:** `enemy = state.targets["camp:"..index].power` (already scaled by the server);
`goal = ceil(enemy × 1.3)`; `power = state.power`. Every card carries
`progress = {value = power, goal = goal, label = "ARMY 38 / 69"}` (WS5 renders it as a thin bar
under the text, fill = clamp(value/goal, 0, 1), tween 0.25 s with TweenService; Scale only).
Tag: `"NEXT: FORT ROOST"` (upper-case camp name; `index`/`total` = 1/1 if WS5's tag line needs them).

**Advice (best power gain per Coin; ties → the cheaper step):**

| Candidate | Available when | Gain (power) | Price (Coins) |
|---|---|---|---|
| Equip | `selectionMode=="Manual"`, free Army slots, a chicken not in the Army | best reserve's power | 0 |
| Recruit | `state.offer.improvesArmy` (server's own check) | offer power − weakest Army chicken (0 if a slot is free) | `offer.price` |
| Army Size | `state.nextSlot` exists | sum of the best spare chickens for the new slots + 13 (a basic Chicken) per slot still empty | `nextSlot.price` + 150 per empty slot |
| Feed | `effects.chickenFeed ≥ 1` | `PetPower(level+1) − PetPower(level)` of an Army chicken with `canUpgrade` | its `upgradePrice` |
| Get Feed | Feed not owned | best first Feed level gain | `nodes.ChickenFeed.price` (1,000) + that quote |
| Roll | nothing above has gain > 0 | – | 0 |

Worked example (3 basic Chickens, 3 slots, 0 Coins, Fort Roost 53/69): Army Size I with an
empty 4th slot = 13 / 1,350 ≈ 0.0096 per Coin; Get Feed = 3.2 / 1,068 = 0.003 → "Army Size I".
Then the empty slot → Recruit "Fills an army slot" → then Feed. Policy B in §3.4 is exactly
this rule.

**Cards (exact copy; `id` → text / target / node / outside / wrongTab):**

| id | Text | Target |
|---|---|---|
| `TipNextCamp2` / `TipNextCamp3` (ready, ≥1.3x) | "Your Army can take Fort Roost! Attack!" / "Your Army can take Ironbeak HQ! Attack!" | `Camp2` / `Camp3` |
| `TipCampArmySize` | "Buy Army Size I for more Army slots!" (tier numeral from `nextSlot.tier`) | `Upgrades`, node `ArmySize<tier>`, outside "Open Upgrades for more Army slots!", wrongTab "Open the Main category!" |
| `TipCampRecruit` | "Buy the chicken on your podium!" | `RollStation` |
| `TipCampRoll` | "Roll a stronger chicken for your Army!" | `RollStation` |
| `TipCampFeedGet` | "Get Chicken Feed to level up your Army!" | `Upgrades`, node `ChickenFeed`, outside "Open Upgrades for Chicken Feed!", wrongTab "Open the Tools category!" |
| `TipCampFeed` | "Feed your Army chickens to level them up!" | `FeedTool` |
| `TipCampEquip` | "Equip Best in My Army!" | nil (text only) |
| `TipCampCollect` (step not affordable) | "Collect eggs: 340 more Coins for Army Size I!" ("for the chicken" / "for Chicken Feed" / "for Feed") | `Yard` |
| `TipCampSell` (bag covers it) | "Sell your eggs for Army Size I!" | `EggDeposit` |

The "short" rule mirrors `earn()` (`TutorialGuide.luau:231-243`): `needed = price − coins`;
if `eggs.carriedValue ≥ needed` → Sell, else Collect with `Currency.Grouped(needed − carried)`.
Upgrades/podium cards appear only when affordable, so the card never walks a short player into
WS3's Coins-shortfall Robux prompt.

Close fight (1.0–1.3x) shows the advice card too (the player may attack; the prompt does not
warn there). Payoff when the camp falls: the existing "Camp captured!".

### 3.6 Odds bands and the pre-attack confirm

- `Guide.CloseFightRatio = 1.0`, `Guide.ShouldWinRatio = 1.3` (was 1.3 / 2.0), defined as
  `CampGuide.EvenRatio` / `CampGuide.ReadyRatio` and read by `TutorialGuide.Difficulty`.
  Words unchanged (owner glossary). Applies to camps, the King and Missions (finite Mission
  rosters are easier than respawning camps at the same ratio, so 1.3 is safe there).
- Prompt ObjectText: `"<band> · Army <power>/<goal> · <min>–<max> Coins/kill"`, e.g.
  "Very tough · Army 38/69 · 160–520 Coins/kill" (drops "4 defenders").
- Below 1.0x only (`Config.CampLadder.AttackWarning`): the first Send Army does not send. It
  shows a warning notice — "Fort Roost is too strong for your Army (38/69). Send Army again to
  attack anyway." (`app:Notify(text, "warning")`) — switches the prompt's ActionText to
  "Attack anyway" for 5 s and sends the client signal `AttackWarned`. A second Send Army within
  5 s attacks as today and sends `AttackAnyway`. The world heading reads "⚔ VERY TOUGH" in gold
  instead of red "⚔ ATTACK". The server is unchanged: agency stays with the player.
- The NEXT world marker (`BaseController:UpdateObjective`) shows over the next camp only when the
  readiness card says ready, or when `ReadinessTip` is off (old behaviour). With the persistent
  card the marker follows the card's own target (yard, pad, podium) as for every tip.

### 3.7 What losing gives

- Kill Coins already pay per guard knocked out (Warden 520, Archer 280, Recruit 160, +15% a
  level; `Config.KillCoins`) — unchanged by strength, so a lost fight at Fort Roost still pays.
- New defeat line for own-lane main-route camps before their first win (`outcome` B or Draw):
  "Fort Roost held! +440 Coins from the fight. Get your Army to 69 power, then attack again."
  (Coins part omitted when 0; `goal` from `battle.targetPower`).
- The readiness card names the next step as soon as the Army is home.
- No extra consolation Coins: the Oct 22 Mission rule (no Coins floors) and Release-Camp
  re-attack farming argue against it.

---

## 4. Implementation steps (file by file)

### 4.1 `src/shared/Config.luau` (one appended block; SHARED file)

```lua
-- October 27 camp ladder (docs/team/CAMP_LADDER_20261027.md). Strength multiplies a camp
-- garrison's hp and damage (and its shown power), like Rebirth enemy scale. {1,1,1} restores.
CampLadder={Strength={1,0.5,0.55},ReadinessTip=true,AttackWarning=true},
```

### 4.2 `src/shared/Progression.luau` (WS1)

- `function Progression.Strength(index): number` → `(Config.CampLadder.Strength or {})[index] or 1`
  (clamped 0.05–1; `require(script.Parent.Config)` — Config does not require Progression).
- `function Progression.CampPower(index, scale?): number` →
  `math.floor(Rules.Power(Progression.Roster(1,index)) * Progression.Strength(index) * (scale or 1))`.
  (Rules does not require Progression; no cycle.) Not used by BattleService (see 4.3), it is
  for the sim, checks and the fallback in CampGuide.
- Comment block dated Oct 27 under the Oct 26 guard note; rosters untouched.

### 4.3 `src/server/BattleService.luau` (WS1 hunks; SHARED with WS7)

- New local `campScale(session, index)` = `enemyScale(session) * Progression.Strength(index)`.
- `Targets` (`:367`): `power=scaledPower(Progression.Roster(promotion,i),campScale(session,i))`.
- `Attack` (`:771-773`): `defenderScale=campScale(session,campTarget)`.
- Unclaim resume (`:330`): `scaledRoster(..., campScale(session, location.index))`.
  (`scaledRoster` already clones combat stats when the scale ≠ 1; Kill Coins read species/level
  and do not change.)
- `RewardKills` (`:908-928`): `if kill.side=="B" and earner.userId==battle.attacker then battle.bounty=(battle.bounty or 0)+amount end`.
- `Finish` (`:1029`): when `outcome=="B" or "Draw"`, `battle.campIndex`, own lane and
  `wonBefore` false (capture it before the flags flip), set
  `attacker.lastResult = CampGuide.DefeatText(battle.name, battle.bounty or 0, battle.targetPower)`
  (string built in CampGuide so copy lives in one place). Else keep today's lines.

### 4.4 `src/shared/CampGuide.luau` (NEW, WS1)

```lua
--!strict
-- October 27 camp readiness (docs/team/CAMP_LADDER_20261027.md). Snapshot-only: never
-- changes prices, odds or actions. WS5's TutorialGuide NextCamp chain asks When/Card.
CampGuide.EvenRatio, CampGuide.ReadyRatio = 1.0, 1.3
CampGuide.Ids = {"TipNextCamp2","TipNextCamp3","TipCampArmySize","TipCampRecruit","TipCampRoll",
  "TipCampFeedGet","TipCampFeed","TipCampEquip","TipCampCollect","TipCampSell"}
function CampGuide.Enabled(): boolean            -- Config.CampLadder.ReadinessTip
function CampGuide.NextCamp(state): number?      -- own-lane camp 2..#Camps after firstWins[1]
function CampGuide.Goal(enemyPower): number      -- math.ceil(enemyPower*ReadyRatio)
function CampGuide.EnemyPower(state, index): number -- state.targets "camp:"..index, else Progression.CampPower(index)
function CampGuide.Advice(state, goal): {kind:string, price:number, gain:number, node:string?, tier:number?}
function CampGuide.When(state, facts): boolean
function CampGuide.Card(state, facts): any       -- tipCard shape + progress + tag
function CampGuide.DefeatText(name, bounty, enemyPower): string
function CampGuide.Warning(name, power, goal): string  -- the client notice copy
```
- Requires `Config`, `Rules`, `Progression`, `CurrencyLimits`, `PetCatalog` (basic Chicken
  power/price for empty slots: `Rules.PetPower("Duck",1,1)`, `PetCatalog.Duck.price`).
- Reads only: `state.power, capacity, selectionMode, pets[] (species, stars, level, giantSize,
  selected, canUpgrade, upgradePrice), nextSlot (capacity, price, tier), offer (species, level,
  price, improvesArmy), coins, eggs.carriedValue, effects.chickenFeed, upgradeTree.nodes.ChickenFeed,
  targets[], firstWins, tutorial.guideCompleted`.
- Pure functions, no instances; works identically on server (TutorialService resolve) and client.

### 4.5 `src/shared/TutorialGuide.luau` (WS5 owns; WS1 requests)

- `Guide.CloseFightRatio = 1.0`, `Guide.ShouldWinRatio = 1.3` (two constants; comment cites §1.2).
- NextCamp chain uses WS5's provider hook (`CampGuide.When/Card`); keep `quietEnd = true`.
- `tip()` keeps a provider-set `card.tag` (WS5 already plans this for GOAL cards) and passes
  `card.progress` through.
- `Guide.NextCampTipSeconds` stays for the fallback only.

### 4.6 `src/client/CommanderGuide.luau` (WS5 owns; WS1 requests)

- Render optional `current.progress` as a bar under the instruction (new Frame "Power" at
  Scale `(.18,.86)`/`(.795,.09)`, fill child + centred label "ARMY 38 / 69", UIColors gold
  fill over the Arcade track; fill tween via `Theme.Motion:Tween` 0.25 s; reduced motion snaps).
  WS5's GOAL cards ("976/1,700") can use the same field.
- (Optional) `TipCampEquip` ring: treat `id=="TipCampEquip"` like `id=="Select"`.

### 4.7 `src/client/BaseController.luau` (WS1 owns per WS5 §4.11)

- `CommandFor` (`:78-86`): `ratio = state.power/entry.power`; `goal = CampGuide.Goal(entry.power)`;
  hint `strength.." · Army "..power.."/"..goal.." · "..bounty`; return `ratio`, `goal`.
  Mission commands (`:127`) the same with `mission.power`.
- `CreateCommandPrompt` Triggered (`:421-428`): below `CampGuide.EvenRatio` and
  `Config.CampLadder.AttackWarning`: if `self.confirmTarget ~= command.targetId or os.clock() > self.confirmUntil`
  → set them (5 s), `self.app:Notify(CampGuide.Warning(command.title, power, goal), "warning")`,
  `self.commandPrompt.ActionText = "Attack anyway"`, signal `AttackWarned`
  (`self.app:Request("TutorialSignal",{signal="AttackWarned"})` as CommanderGuide does), return.
  Else send as today; if it was a confirmed below-even attack, signal `AttackAnyway`.
- `PollCommand` (`:726-729`): ActionText "Attack anyway" while armed for this target, else "Send Army".
- `UpdateCommandPresentation` (`:487-500`): heading "⚔ VERY TOUGH" (`C.gold`) below even, else "⚔ ATTACK".
- `UpdateObjective` (`:632-651`): the `nextCamp` branch only when
  `not CampGuide.Enabled() or state.power >= CampGuide.Goal(CampGuide.EnemyPower(state, nextCamp))`.

### 4.8 `src/server/TutorialService.luau` (SHARED; two names)

- `signals` += `AttackWarned=true, AttackAnyway=true` (Analytics counts them as `ui.AttackWarned` /
  `ui.AttackAnyway` through its default branch).

### 4.9 Analytics (SHARED; lead merges one Version bump)

- `src/server/Analytics.luau` `Progress` (`:540-552`): on `firstWin` also
  `Hist("camp."..step..".firstWin.play","seconds",self:_Play(st))` and, when `st.sessionIndex==1`,
  `Count("camp."..step..".firstWin.firstSession")`.
- `Analytics:Observe` (`:338-355`): per session, for camps 2–3 not yet in `firstWins`, the first
  time `state.power >= CampGuide.Goal(target power)` → `Count("camp.CampN.ready")`,
  `Hist("camp.CampN.ready.play","seconds",_Play(st))` (flag in `st.campReady[N]`).
- `src/server/AnalyticsReport.luau` camps block (`:~457` area / `Report.Summarize` camps):
  add `ready`, `firstWinPlay` (p50/p90), `firstSession`, and top-level `ui.AttackWarned/AttackAnyway`.
- `src/server/AnalyticsSchema.luau`: `Schema.Version = 16` (one bump for the release); document
  the new names in the camps section comment. **Do not append an Onboarding step**: steps are
  reached in any order and `LAST` defines "Post" (`AnalyticsTutorial.luau:170-190`); a 16th
  step after Rebirth 1 would redefine every session stage. Keep camp metrics in the ledger.
- `oddsBucket` (`BattleService:935-938`) stays: its edges (1.0, 1.3, 2.0) already match the new bands.

### 4.10 Save data, remotes, ownership

- No saved fields, no `DataRevision`, no `TreeMigrations`. Strength and readiness are derived.
- Remote payloads: none new (snapshot already carries `targets`, `power`, `nextSlot`, `offer`,
  pets with `selected/upgradePrice`). Client signals are two new names on the existing
  `TutorialSignal` action.
- Server owns fights and power; client owns the card, warning and marker.

### 4.11 Docs (lead or WS1 at build time)

- New `docs/team/CAMP_LADDER_20261027.md`: the ladder table, bands, card copy, flags, metrics.
- `docs/team/CAMP_GUARDS.md`: one dated line — guard stats unchanged, camp strength scales the fight.
- `AGENTS.md`: one dated paragraph (Fort Roost ×0.50 = 53, Ironbeak ×0.55 = 105; bands 1.0/1.3;
  the readiness card; the confirm), since it changes the Oct 8 "~107" tuning and the Oct 26
  "keeps its exact strength" note.

---

## 5. Analytics to compare and success metrics

Read with `AnalyticsReport` from Studio Edit (`docs/analytics/AGENT_GUIDE.md`), split by
`versions`, after ≥1 day and ≥300 Cluck Camp first wins on the new build.

| Metric | Source | Today (1.25.0) | Target |
|---|---|---|---|
| Fort Roost first wins / Cluck Camp first wins | `camp.Camp2.firstWin` / `camp.Camp1.firstWin` | 24% | **≥55%** |
| Same, first sessions only | `camp.Camp2.firstWin.firstSession` / Camp1 | n/a | ≥45% |
| Fort Roost attempts below 1.0x | `camp.Camp2.odds.Under1.*` / `camp.Camp2.attempt` | 73% | **≤20%** |
| Median play time at the first Fort Roost win | `camp.Camp2.firstWin.play` p50 | n/a (est. 15–20 min) | **8–12 min** |
| Reached Should win / Cluck Camp first wins | `camp.Camp2.ready` / `camp.Camp1.firstWin` | n/a | ≥65% |
| Ready → won | `camp.Camp2.firstWin` / `camp.Camp2.ready` | n/a | ≥85% |
| Warning overridden | `ui.AttackAnyway` / `ui.AttackWarned` | n/a | watch; >60% means the copy is ignored |
| Ironbeak first wins / Fort Roost first wins | `camp.Camp3.firstWin` / Camp2 | 58% | ≥50% (not lower with 3x more Fort Roost winners) |
| Card dwell and exits | `guide.enter.TipCamp*`, `guide.dwell.TipCamp*`, journeys `ex` | `ex=TipNextCamp2` 74% | the exit step now names the real step; Army Size card dwell p50 < 120 s |
| Shared: 10-min / 30-min survival (new sessions) | `play.s.*` | 21% / 7% | ≥26% / ≥9% (with WS2/WS5) |
| Shared: D1 return | `ret.d1` cohort | – | up; Fort Roost winners return 39% vs 2.4% |
| Battle Coins sanity (farming) | `econ.src.battle` share of earned, first sessions | baseline | no more than +5 pts |

---

## 6. Verification

### 6.1 Headless (Lune, `tools/sim`)

- `tests/FoundationChecks.luau:145-150`: keep `Rules.Power(Progression.Roster(1,i))` =
  "12,106,192" (guards untouched) and add `Progression.CampPower(i)` = "12,53,105".
- NEW `tests/CampGuideChecks.luau` (WS5 owns `CommanderGuideChecks`): bands at 0.99/1.0/1.29/1.3;
  `Goal(53)==69`, `Goal(105)==137`; Advice picks Army Size for 3 Chickens/3 slots; Recruit when
  `offer.improvesArmy` and a slot is free; Get Feed when Feed is cheaper per power; Feed when
  owned; Collect/Sell when short (carried < / ≥ needed); ready card at power 69 targets `Camp2`;
  `Camp3` after `firstWins={true,true}`; nil before Cluck Camp and after camp 3; every id in
  `CampGuide.Ids`; `DefeatText` with and without Coins.
- `tests/ProgressionSimulation.luau` (SHARED with WS2): `campPower` (`:213-215`) multiplies
  `Progression.Strength(index)`; `attackable` (`:259-263`) becomes explicit ratios so results
  do not shift with the band change: camps/King `power >= target.power * Guide.ShouldWinRatio`
  (1.3, same as before), Missions `>= 2.0` (`MISSION_RATIO`, was "Should win"); same at `:356`.
  Re-run the casual and fast tables; Rebirth 1/5/10 must stay within ±5% (measured: 13.0→13.5,
  73→72, 190.5→186.8 min, casual 8 seeds).
- NEW `tools/sim/camp_probe.luau` (from `ws1/battle.luau` + sweeps + `early.luau`):
  `mode=fights camp=2` prints the §3.1 tables with the live strength; `mode=early` prints §3.4.
  Expected: ×0.50 → "2 Chickens + 2 Commons" 0%, "4 Commons" 100%; guided ready p50 ≈ 8 min.
- `runsuite.luau RulesAndBattles`, `CampRespawnChecks`, `LaneConquestChecks`,
  `OrderedConquestChecks`: compare against a `git archive HEAD` copy; no new failures.
- luau-lsp analyze on touched files vs HEAD baseline (memory: Local Luau checks).

### 6.2 Studio playtest (Stevin or the lead; Rojo synced, fresh profile via TestNewPlayer)

1. Finish the tutorial and win Cluck Camp with three basic Chickens.
2. Card reads "Collect eggs: 1,200 more Coins for Army Size I!" with the bar "ARMY 38 / 69"
   (tag NEXT: FORT ROOST); beam to the yard. Phone and PC: bar inside the card, Scale only.
3. Walk to Fort Roost: prompt "Very tough · Army 38/69 · 160–520 Coins/kill", heading
   "⚔ VERY TOUGH". Send Army once: warning notice, prompt now "Attack anyway", no march. Wait
   6 s: back to "Send Army". Send twice: the Army marches (ledger `ui.AttackWarned/AttackAnyway`).
4. Lose: result line "Fort Roost held! +… Coins from the fight. Get your Army to 69 power,
   then attack again." Card returns when the Army is home.
5. Earn 1,200 (admin Coins are fine): card switches to "Buy Army Size I for more Army slots!",
   Upgrades opens on the Main map with the ring on Army Size I; buy → the card ticks to
   "Roll a stronger chicken…"/"Buy the chicken on your podium!".
6. Reach ≥69 (Feed or Commons): card "Your Army can take Fort Roost! Attack!", beam + NEXT
   marker on Fort Roost; prompt reads "Should win"; attack and win (expect ~20–40 s of fighting,
   four guards visible, smaller health bars). Payoff "Camp captured!". Card moves to Ironbeak HQ
   with "ARMY xx / 137".
7. Rebirth-rank sanity: a rank-1 test profile shows Fort Roost at 53 × EnemyScale(1).
8. Another commander's lane camp shows the same scaled power.

---

## 7. Risks, owner-rule conflicts, rollback

- **Owner rule history, post-tutorial instructions.** Oct 21 Stevin: "no instructions after the
  tutorial" removed a near-identical "Army 63 / Fort Roost 107: feed your Army chickens" plan.
  Superseded by his Oct 23 tips ("TIP • n/N") and his Oct 26 next-camp tip + marker; this plan
  uses that tip framework and one line at a time. Compliant fallback if he objects:
  `ReadinessTip=false` keeps the timed card but shows it only when ready, and keeps the bar
  on the prompt + the confirm.
- **Oct 26 camp guards note** ("each copies the stats of the guard it replaced, so every camp
  fight keeps its exact strength"): that sentence described the art swap, not a balance rule.
  Guard species, stats, models and names stay; the camp strength is a separate, visible number.
  The Oct 8 "~107 so about five Uncommon/Rare level-1 chickens can take it" tuning moves to
  Ironbeak HQ (105). Needs one AGENTS.md line (§4.11).
- **Never gate upgrades behind camps:** nothing is gated; the card only points at upgrades.
- **Words:** Army, Camp, Coins, "Should win / Close fight / Very tough", no "$", no "FREE", no
  "Press E/Tap" ("Send Army again"). "power" is already shown in Army sorts.
- **One UI layout / Scale only / TweenService:** the bar is Scale-sized; its fill uses one tween.
- **Farming:** a weaker Fort Roost + Release Camp re-attack pays ~1,120 Coins a clear (unchanged
  per kill) in a ~90–120 s loop ≈ 10–12 Coins/s, below a 10-minute player's egg income and
  without the +15% hold bonus while released. Watch `econ.src.battle`; if needed, scale
  Kill Coins by strength (`CombatRewards`, one line) — not recommended up front because the
  bounty is the loss consolation.
- **Easier Ironbeak shortens the run to the King's 497 wall** (×4.7). The King already gates on
  all three camps and Rebirths; the sim shows King time 28.0 → 26.5 min and no Rebirth change.
- **Band change touches Missions** (more "Should win" at 1.3–2.0). Finite Mission rosters favour
  the attacker; ProgressionSimulation's Mission rule is pinned at 2.0 so its numbers don't move.
- **Persistent card fatigue:** if `guide.dwell.TipCamp*` p90 is long and exits stay there, WS5's
  peek rule (GOAL cards) can apply to this chain too (show 10 s on change, then on idle).
- **Model risk:** the early model buys optimally; real followers are slower (hence the 8–12 band).
  Re-run `camp_probe mode=early` after WS2's prices land; do not go below 0.50 if WS2 cuts
  Army Size I to 300.
- **Rollback switches:** `Config.CampLadder.Strength={1,1,1}` (ladder), `ReadinessTip=false`
  (timed card as today), `AttackWarning=false` (prompt sends at once). Bands are two constants.

---

## 8. FILES TOUCHED and cross-WS interfaces

| Path | New/Edit | Owner | Shared with |
|---|---|---|---|
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/shared/CampGuide.luau` | NEW | WS1 | read by WS5's TutorialGuide hook |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/shared/Progression.luau` | Edit (Strength, CampPower) | WS1 | – |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/shared/Config.luau` | Edit (append `CampLadder`) | lead merge | **WS2, WS4, WS5, WS7** also append blocks |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/server/BattleService.luau` | Edit (campScale ×3, bounty sum, defeat line) | WS1 | **WS7** (camp first-win moments in `Finish`) |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/client/BaseController.luau` | Edit (prompt hint, confirm, heading, marker) | WS1 (per WS5 §4.11) | – |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/shared/TutorialGuide.luau` | Edit by **WS5** on WS1's request (bands 1.0/1.3, provider tag/progress passthrough) | WS5 | WS1 |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/client/CommanderGuide.luau` | Edit by **WS5** on WS1's request (progress bar; optional Equip ring) | WS5 | WS1 |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/server/TutorialService.luau` | Edit (2 signal names) | lead merge | **WS3, WS5, WS7** |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/server/Analytics.luau` | Edit (Progress hist/count, Observe ready) | lead merge | **all WS** |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/server/AnalyticsReport.luau` | Edit (camps block) | lead merge | **all WS** |
| `/Users/stevin/Documents/Projects/MyChickenArmy/src/server/AnalyticsSchema.luau` | Edit (Version 16 — one bump for all) | lead | **all WS** |
| `/Users/stevin/Documents/Projects/MyChickenArmy/tests/CampGuideChecks.luau` | NEW | WS1 | – |
| `/Users/stevin/Documents/Projects/MyChickenArmy/tests/FoundationChecks.luau` | Edit (camp powers) | WS1 | WS2/WS4 may edit other checks in it |
| `/Users/stevin/Documents/Projects/MyChickenArmy/tests/ProgressionSimulation.luau` | Edit (campPower × strength; explicit attack ratios) | lead merge | **WS2** |
| `/Users/stevin/Documents/Projects/MyChickenArmy/tools/sim/camp_probe.luau` | NEW | WS1 | – |
| `/Users/stevin/Documents/Projects/MyChickenArmy/tools/sim/README.md` | Edit (one bullet) | WS1 | WS2/WS4 may add bullets |
| `/Users/stevin/Documents/Projects/MyChickenArmy/docs/team/CAMP_LADDER_20261027.md` | NEW | WS1 | – |
| `/Users/stevin/Documents/Projects/MyChickenArmy/docs/team/CAMP_GUARDS.md` | Edit (one line) | WS1 | – |
| `/Users/stevin/Documents/Projects/MyChickenArmy/AGENTS.md` | Edit (one paragraph) | lead | all WS |

Not touched: `Battle.luau`, `Rules.luau`, `UpgradeCatalog.luau` (prices are WS2's),
`PetCatalog.luau`, `KingEncounter.luau`, map/Studio assets (no authored geometry needed).

**Interfaces:**
- **WS5 (post-tutorial flow):** WS1 provides `CampGuide.When(state, facts)`, `CampGuide.Card(state, facts)`
  (tipCard shape `{id, text, target, node?, outside?, wrongTab?, index=1, total=1, tag, progress}`;
  targets used: `Camp2/Camp3`, `Upgrades`, `RollStation`, `FeedTool`, `Yard`, `EggDeposit`, nil)
  and `CampGuide.Ids`. WS1 asks WS5 to: set `CloseFightRatio=1.0`, `ShouldWinRatio=1.3`
  (or read `CampGuide.EvenRatio/ReadyRatio`); keep a provider `tag`; render `progress`. Chain
  slot 5 ("Camp"), persistent, `quietEnd`. Merge order: WS5 first, then WS1.
- **WS2 (economy):** WS1's advice reads live prices (`nextSlot.price`, offer price, Feed quotes),
  so price changes flow through. WS1's strength 0.50 assumes today's or WS2's proposed prices;
  WS2's Army Size I = 300 / II = 2,500 plus the readiness card is fine (typical ~11 min in WS2's
  model); do not also lower strength. WS2 also edits `ProgressionSimulation.luau` — keep WS1's
  two hunks (`campPower`, `attackable`).
- **WS3 (Coins-shortfall prompt):** the readiness card only targets an Upgrades hex or the podium
  when affordable (Collect/Sell otherwise), so it never routes a short player into the Robux prompt.
- **WS4 (rolls):** guaranteed early Uncommons/Rares (power 30–60) make Fort Roost readiness
  faster; the advice handles it (Recruit gain is the real power). If WS4 guarantees a Rare
  before minute 5, re-run `camp_probe mode=early`; keep strength ≥0.5.
- **WS7 (social):** WS7's camp first-win "moments" hook into `BattleService:Finish` beside WS1's
  defeat line; different branches of the same function (win vs loss). The scaled power is the
  same on every lane.
- **WS6 (performance):** no new loops; one tween per bar change; no VFX.
- **Lead:** one `Schema.Version` bump (16) and one `Config.Version` label; analytics names above
  are new (append-only); no Onboarding step change.
