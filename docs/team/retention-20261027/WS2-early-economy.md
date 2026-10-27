# WS2: Early economy, the price cliff and the waiting middle (minutes 3–20)

> **Lead note (Oct 27):** after the combined-package check (§9), Army Size II stays **6,000**;
> only Army Size I drops to 300. Fort Roost strength is 0.60. See `docs/team/RETENTION_PLAN_20261027.md` §4.

Research and plan only. No repo file was edited. Build analysed: live 1.25.0-eight-cards
(Oct 26–27 ledger export) plus `main` at c6153d1 (Config.Version "1.26.0-first-minute").
Scratch tools are in `<scratchpad>/retention/ws2/`:
- `early.luau`: the first-session agent model.
- `psim.luau`: ProgressionSimulation with the WS2 patches.
- `run.sh`: the profiles.
- `out_*.txt` / `f_*.txt` / `c_*.txt`: raw outputs.

## 0. The recommendation in one paragraph

Ship four small, switchable changes and one feedback change. Each one is backed by the data
and the simulations below.

1. **Starter prices on the podium.** Empty-start profiles (`introRebirth ~= nil`) see podium
   offers at 25% of the catalog price. The price rises linearly back to 100% as the player
   owns 2 → 20 chickens. Coins round up to 5. It is never below 150 (the basic Chicken's
   price) and never above the catalog price. The catalog is untouched. This works like the
   owner's own `StarterLadder` (the second Chicken at 20).
2. **Rebirth 0 keeps the Upgrades tree and Feed levels.** It still costs 1,700, resets
   Coins and carried eggs, gives +30 Gems and x1.5.
3. **Army Size I costs 300 and Army Size II costs 2,500** (were 1,200 / 6,000). Flat for
   every rank.
4. **The "+N/s" moment.** Every Coins purchase that raises steady income floats "+N/s"
   with the gold coin from the Coins readout. A bought chicken that goes to storage now
   says how to make it lay.

The result:
- **Typical player** (calibrated to the live data): Coins/s at minute 10 rises from 56 to 79.
  With the Army tip (WS1/WS5), Army power reaches 106 at about minute 11 (now about minute
  25). The median gap between meaningful purchases before minute 10 falls from 69 s to 49 s.
- **Engaged player:** Fort Roost power by minute 9.6 (now 11.6), and a purchase every 12 s
  before minute 10.
- **Rebirth pacing:** Rebirth 1–10 stay within the fit's ±7% (fast R10 188 → 181 min,
  casual 190 → 188 min).
- **The bigger Rebirth 1 lever belongs to WS4:** the Rebirth 1 find, Ironbeak at 1 in 146.
  Swapping it for a Common of about 1 in 27 lifts Rebirth 1 by minute 30 from 7/30 to 19/30
  for typical players. That is a dated owner rule, so WS4 owns the decision.

---

## 1. Problem and evidence

Data: `<scratchpad>/quit/journeys27.json` (903 journeys, 847 new; trails capped at 60
events, about 3 min) and `summary125.json` (Report.Summarize, 2 days, 1,530 sessions).
Every number below comes from `python3 -I` over those files (queries in §1.6).

### 1.1 Purchases stall right after the tutorial

- The tutorial completes at a median of **63 s** (p25 50, p75 87, p90 123; n=484 with
  `ob:TutorialDone` in the trail). The "~2.5 min" in the brief is the survivor view; the
  economy problem starts at minute 1.
- **134 of 484** tutorial finishers left before buying another chicken (trail ended before
  the cap). **215** bought one, at a median of **32 s** after completion (p75 65 s). That
  is mostly the favoured basic Chicken at 150.
- Among the 85 trails that cover at least 2 minutes after the tutorial (median window 155 s):
  - chicken buys per minute: median **0** (p75 0.39);
  - lever pulls: **0.58/min**;
  - tree buys: 0.44/min, including the free Egg Vacuum claim and post-Rebirth-0 re-buys;
  - failed buys per minute: p75 0.38.
- Rejected actions across all new players:
  - "Buy": **1,817 rejections from 402 of 847 players**. Each is "Not enough coins…".
  - "UpgradeChicken": 275. "Roll": 254.

### 1.2 Rolls and recruits are rare for the whole session

Rolls per minute by session length are flat at about 1/min (median 1.1, 1.1, 1.1, 1.0, 0.9).

| Session length | n | Rolls/min p50 | Chicken buys p50 (incl. 2 tutorial) | Earned/min p50 | Rebirth 0 reached | Cluck Camp won |
|---|---|---|---|---|---|---|
| 2–4 min | 165 | 1.1 | 2 | 423 | 39% | 28% |
| 4–6 min | 82 | 1.1 | 3 | 512 | 74% | 62% |
| 6–8 min | 65 | 1.1 | 4 | 701 | 94% | 82% |
| 8–12 min | 67 | 1.0 | 5 | 803 | 90% | 88% |
| 12–20 min | 40 | 0.9 | 7 | 1,384 | 100% | 100% |

The Roll feature funnel (summary `featureFunnels`):
- Recruited: 1,125 players.
- **Recruited10: 181 players (16.1%).** This is the worst step in the funnel.

The economy sinks over 2 days:
- Recruit:Common: 4,888 buys at an average of 1,269 Coins. That is a mix of 150 and 20
  Chickens with 1,900–3,000 Commons.
- Upgrade:Flock1: 1,325. Rebirth0: 485. EggSpeed1: 562. EggValue1: 443. Flock2: 366.
  ArmySize1: 348. ArmySize2: 256.
- Late players' re-buys after each Rebirth inflate all of these.

### 1.3 Earning is real but flat

New players earn about 420–800 Coins a minute in minutes 2–12. That is roughly 7–13 Coins/s
on average. The first-session agent model reproduces this (§3.2 calibration):
- 2,119 earned by minute 5 (data about 2,500);
- 7,886 by minute 10 (data about 8,000);
- 4–5 chickens at minute 10 (data 4–6);
- 14 pulls in 20 minutes (data 0.6–1.1 a minute).

In that model, Coins/s sit at **24 from minute 6 to minute 9**. That is the "waiting middle".

### 1.4 The price cliff in numbers

Catalog values, from `tools/sim/odds_table.luau`. Power comes from `Rules.PetPower`.

| Chicken | Odds | Price | Income/s | Power | Payback in an empty Flock slot | Payback replacing a basic Chicken |
|---|---|---|---|---|---|---|
| Chicken (Duck) | 1 in 3.6 | 150 | 4 | 13 | 38 s | – |
| Rooster | 1 in 7.4 | 1,900 | 6 | 16 | 317 s | 950 s |
| Party Chicken | 1 in 17 | 2,300 | 10 | 19 | 230 s | 383 s |
| Bonsai Bantam | 1 in 78 | 3,000 | 17 | 20 | 176 s | 231 s |
| Bee Chicken (first Uncommon) | 1 in 87 | 3,400 | 18 | 30 | 189 s | 243 s |
| Robo-Cluck (first Rare) | 1 in 661 | 8,000 | 30 | 38 | 267 s | 308 s |

After the basic Chicken, every Common costs 12.7–20x more for 1.5–4x the income. Payback is
5–16 minutes at base value.

Right after the tutorial the player earns 8 Coins/s (two Chickens). One non-Chicken offer
therefore costs **4 minutes of waiting**. Even the favoured pulls are only about 70% Chicken
(the 60% favour plus the base 28%).

The podium's "This offer will wait for you" means a typical player stands there or wanders
off. The data shows 0 buys per minute after the tutorial and 1,817 "Not enough coins"
rejections.

### 1.5 Three structural traps behind the cliff (from code)

1. **Rebirth 0 undoes itself.** Rebirth 0 at 1,700 (`RebirthService.RebirthIntro`,
   `src/server/RebirthService.luau:490-492`) resets the whole tree and Feed levels.
   - The tutorial's Flock Size I (10 Coins) drops, so the Flock falls from 4 to 3. The
     player's 4th chicken stops laying.
   - Egg Speed I, Egg Value I, Flock II and Roll Slot I bought before Rebirth 0 are lost.
   - The Egg Vacuum hex resets too, so it has to be claimed again.
   - Four Chickens make 16 Coins/s before Rebirth 0 and 3 × 4 × 1.5 = **18 Coins/s after
     it**. The x1.5 reward is +12%, not +50%, until Flock I is bought again.
   - In the agent model the typical player re-buys Flock I about 1 minute later.
2. **Bought chickens often don't lay.** The Flock is 3 laying, then I: 4 (10), II: 5 (900),
   III: 6 (2,000), IV: 7 (25,000) (`src/shared/UpgradeCatalog.luau:105-108`). Typical
   players buy Flock II at about minute 9–11 in the model. Until then a 5th chicken goes
   to storage (`RollService.luau:290` "In storage.") and earns nothing.
3. **Army power is capped by 3 slots.** Fort Roost has power 106: Close fight at
   ≥138 (1.3x), Should win at ≥212 (2x) (`TutorialGuide.luau:283-284`). Three slots of
   Commons give at most 57, and three Uncommons 90. Reaching 106 needs Army Size I
   (1,200) plus four Uncommons (Uncommons are 6% of rolls), or Army Size II (6,000) plus
   six Commons. The typical model buys Army Size I at minute 15 and never buys Army
   Size II within 20 minutes.

### 1.6 Queries used (reproducible)

```
python3 -I -c "import json; d=[j for j in json.load(open('journeys27.json')) if j['new']]; ..."
```

- Buckets by `s`: r/(s/60), b, earned/(s/60), mx≥13 (Rebirth 0), mx≥14 (Cluck Camp).
- Per trail: TutorialDone time; the first 'Buy' after it; the first 'Buy!' after it;
  'BuyUpgrade'/'Roll'/'menu:Upgrades' per minute in the window after it.
- `rej`: parse "Buyx2" and similar into counts per action and players per action.
- Summary: `economy.sinks`, `rolls.byRarity`, `featureFunnels[Roll]`.

---

## 2. Root cause in code

| Lever | Where | Current value |
|---|---|---|
| Podium price | `RollService:Roll` (`src/server/RollService.luau:93-94`) | `Rules.RecruitPrice(species, level)` = `Catalog.price * 2^(level-1)` (`Rules.luau:59-63`). The only exception is the tutorial ladder (`Config.Economy.StarterLadder`, `Config.luau:10`: Chicken 0, Chicken 20). |
| Favoured basic Chicken | `RollService.favoredSpecies` (`RollService.luau:36-46`) | `Config.Economy.FavoredRolls = {rolls=5, chance=0.6, species="Duck"}` (`Config.luau:14`) |
| Chicken income | `Rules.EggRate`/`Rules.Income` (`Rules.luau:35-56`) | Catalog `income` is Coins/s at Egg Value 0. Coins/s = Σ over the best `FlockSize` layers × Egg Speed × Egg Value × Rebirth multiplier × Rebirth 0 x1.5 × territory (`PlayerSession.luau:233-290, 611-645`). |
| Rebirth 0 | `Config.Rebirth.Intro` (`Config.luau:125`), `RebirthService.RebirthIntro` (`RebirthService.luau:470-517`) | Cost 1,700, x1.5, 30 Gems. Resets Coins, tree (`keptTree`), Feed levels, carried eggs and Gold counts. |
| Flock tiers | `UpgradeCatalog.luau:105-108` | 4/10, 5/900, 6/2,000, 7/25,000, 8/250,000 … |
| Army Size tiers | `UpgradeCatalog.luau:113-116` | 4/1,200, 6/6,000, 8/25,000, 10/90,000 (base 3, `Config.StartingSlots`) |
| Egg Speed / Value | `UpgradeCatalog.luau:77-83` | Speed x1.25/400, x1.5/2,000, x2/250K. Value x1.5/600, x2/3,000, x3/400K. |
| Feed | `Rules.ChickenUpgradePrice` (`Rules.luau:87-98`) | Chicken Lv1→2 costs 68, then 270 and 1,080 (x1.6 eggs, +25% power a level). The tool is 1,000. First use p50 is 15 min and only 140 players used it in 2 days. |
| Playtime Coins | `PlaytimeRewards.Tiles`, `DailyService.Income` floor `MinIncome=10` (`DailyService.luau:28`) | 1 min: 240, 3 min: 360, 5 min: 600 at the floor. These are small and fine. |
| Rebirth 1 | `Config.Rebirth.Costs[1]=5e4`, `FindRanks=15`, `PetCatalog.RebirthFinds[1]="Ironbeak"` (`PetCatalog.luau:371`) | Ironbeak is 1 in 146 (0.68% a podium). A typical 14 pulls in 20 min gives about a 9% chance of the find. |

So the price cliff is real, but it is one of four traps. Lowering catalog prices is forbidden
(Oct 23 "Every chicken its own odds and value") and would not fix the other three: the
Rebirth 0 reset, idle chickens and the Army slot cap.

---

## 3. Options considered and the recommended design

### 3.1 Models used

**A. First-session agent model** (`<scratchpad>/retention/ws2/early.luau`, new). It uses the
real modules: PlayerSession, RollService (rolls, ladder, favoured rolls, offers),
UpgradeService:BuyNode, RebirthService.RebirthIntro/Rebirth (finds), DailyService (day 1 and
Playtime tiles), CombatRewards, PetCatalog and Rules. Behaviour runs on a 1 s tick from
tutorial completion (63 s) to minute 20 or 30. 30 seeds per row.

The agent:
- sells the bag every `sellEvery` seconds at efficiency `eff`, with Gold Rush x2 for 5 of
  every 20 minutes at a seeded phase;
- claims the vacuum at +20 s and every Playtime tile;
- pulls the lever when the podiums are empty or an offer has waited `rollPatience` seconds
  (with `pullGap` seconds between visits);
- buys an offer when it can afford it and the chicken would lay (beats the weakest Flock
  layer or fills a free slot), join the Army, or is the Rebirth find;
- before Rebirth 0, buys only Flock in the tree;
- after Rebirth 0, buys the cheapest useful node: Flock if a chicken is idle, Egg Speed,
  Egg Value, Army Size if the Army is full, Roll Slot I, Chicken Feed. It buys
  `treePerVisit` per visit, once every `treeGap` seconds;
- takes Rebirth 0 and Rebirth 1 when eligible;
- attacks Cluck Camp at 3 Army chickens and Fort Roost at power ≥106 (90 s away).

The profiles:

| Profile | pullGap | rollPatience | sellEvery | eff | treeGap | treePerVisit | Feed |
|---|---|---|---|---|---|---|---|
| typical | 45 | 120 | 90 | 0.6 | 120 | 1 | off |
| engaged | 15 | 45 | 60 | 0.85 | 30 | 2 | after 5 min |

"typical" is calibrated to §1.3. "Meaningful purchase" means one that raises steady Coins/s
or Army power by at least 5%, or a Rebirth.

**B. `tests/ProgressionSimulation`** (greedy optimiser) through
`<scratchpad>/retention/ws2/psim.luau`. It applies the same patches. Runs: 16 seeds, 5 h,
up to Rebirth 10, fast and casual profiles. This measures Rebirth pacing.

### 3.2 Calibration: current build, typical profile (30 seeds)

| Minute | Coins | Coins/s | Earned | Power | Chickens | Flock | Army |
|---|---|---|---|---|---|---|---|
| 3 | 373 | 4 | 600 | 38 | 4 | 4 | 3 |
| 5 | 118 | 18 | 2,119 | 38 | 4 | 3 | 3 |
| 6 | 2,263 | 24 | 4,274 | 38 | 4 | 4 | 3 |
| 7 | 2,263 | 24 | 4,274 | 38 | 4 | 4 | 3 |
| 8 | 2,149 | 30 | 5,570 | 38 | 4 | 4 | 3 |
| 9 | 4,055 | 30 | 7,693 | 41 | 4 | 4 | 3 |
| 10 | 2,074 | 56 | 7,886 | 44 | 5 | 4 | 3 |
| 12 | 5,945 | 96 | 15,579 | 54 | 6 | 4 | 3 |
| 15 | 27,517 | 132 | 44,839 | 57 | 9 | 5 | 3 |
| 20 | 65,766 | 208 | 95,908 | 77 | 11 | 6 | 4 |

- Rebirth 0 at 3.9 min. Rolls: 14 in 20 min.
- Purchases from the tutorial to minute 10: 7, median gap 69 s.
- Army Size I at minute 15. Army Size II never.
- Fort Roost (106): 1/30 by minute 20. Rebirth 1: 5/30 by minute 20.

(The engaged profile on the current build: Coins/s 18 at 5 min, 212 at 10, 785 at 20.
Fort Roost at 11.6 min. 26 purchases before minute 10.)

### 3.3 Options

| Option | Verdict | Why |
|---|---|---|
| Lower catalog prices or raise Common income | **Rejected** | Owner rule Oct 23: prices and income come from `valueOneIn`, rise along the odds order and are never below the old values. Enemies use only hp/damage. |
| **Starter prices: a podium quote for new profiles (25% → 100% as owned chickens go 2 → 20)** | **Recommended** | Same mechanism as `StarterLadder`: the podium's quote, not the catalog. Every offer becomes 25–90 s of income at minutes 3–8. Fading by owned count means no cliff at Rebirth 1 and no new save field. Engaged Coins/s at 5 min: 18 → 36; Fort Roost 11.6 → 9.6 min. |
| Starter prices that end at Rebirth 1 (flat 25%) | Considered | Almost the same early curve, but prices jump x4 at Rebirth 1, just as the tree resets. That is a second cliff at the moment we celebrate. |
| **Rebirth 0 keeps the tree and Feed** | **Recommended** | Removes the post-Rebirth-0 dip (§1.5.1). Typical Coins/s at 5 min: 18 → 24. Pure upside and a one-line change. |
| Rebirth 0 multiplier x2.5 instead of x1.5 | **Rejected** | Strong income (engaged 945 Coins/s at 10 min), but Rebirth 1's x2 then *lowers* the multiplier. A Rebirth that makes you poorer is worse than none. Rebirth 0 must stay below x2. |
| Rebirth 0 cheaper or earlier, MinIncome floor | Not needed | Rebirth 0 is already reached at about 3–5 min by those who reach it. The problem is after it. |
| **Army Size I 300, II 2,500** | **Recommended** | Gives the stepping stone and the Fort Roost path (§3.5): 4 slots at about minute 5 and 6 slots at about minute 7–8 when the guide points there. These prices are not part of the P5 fit (Army Size isn't an economy node). |
| Flock II/III cheaper (300/900) | Not recommended now | Moves the typical Coins/s by under 7% in the model (58.5 vs 54 at min 7). The real fix for idle chickens is the storage message plus WS5's tip. Keep it as a fallback lever. |
| Longer tutorial-speed eggs (1 s) after the tutorial | Leave to WS5 | It changes how income feels, not how much. Out of WS2's lane. |
| FavoredRolls off | **Owner-rule conflict** | AGENTS.md (Oct 25, Stevin) makes the next five pulls favour the basic Chicken at 60%. The model shows it slightly *hurts* the typical player once starter prices exist (unwanted Chickens when the Flock is full; Coins/s at 9 min is 98 off vs 67 on). Compliant choice: **keep it**. WS4 may raise it with Stevin as part of roll variety. |
| Rebirth 1 find to a Common | **WS4's decision; strongest Rebirth 1 lever** | See §3.6. |

### 3.4 The recommended design, with exact numbers

**(1) Starter prices.**
- New key: `Config.Economy.StarterPrices = {Enabled=true, Fraction=0.25, FullAt=20, Floor=150, Step=5}`.
- Applies when `session.introRebirth ~= nil` (empty-start profiles; legacy saves never) to
  every podium offer except the free starter roll and the tutorial ladder step.
- `owned = session:Count()`.
- `f = Fraction + (1 − Fraction) × clamp((owned − 2) / (FullAt − 2), 0, 1)`.
  - `owned` 2 → 25%; 5 → 37.5%; 8 → 50%; 11 → 62.5%; 14 → 75%; 20 → 100%.
- `listPrice = Rules.RecruitPrice(species, level)`.
- `price = min(listPrice, max(Floor, ceil(listPrice × f / Step) × Step))`.
- Whole numbers only. Strictly increasing along the odds order: catalog steps are at least
  100, and 25 ≥ Step 5, so every species still has a different price.

Example quotes at 25%:

| Chicken | Starter price |
|---|---|
| Chicken | 150 (floor = catalog) |
| Rooster | 475 |
| Rubber Ducky | 500 |
| Bonsai | 750 |
| Bee | 850 |
| Lollipop | 1,125 |
| Robo-Cluck | 2,000 |
| Frost | 3,275 |
| Magma (Epic) | 14,400 |
| Golden Emperor (Legendary) | 24,000 |
| Glitch (Mythic) | 419,250 |

Paybacks at the base x1 value, empty slot: Rooster 79 s, Party 58 s, Bonsai 44 s, Bee 47 s.

Safety:
- No exploit. Investment = the price paid, and a sale refunds 50% of that
  (`Rules.SellValue`).
- Rebirth finds and event offers use the same quote.
- The Coins-shortfall `needCoins` (WS3) automatically uses the lower price.

**(2) Rebirth 0 keeps the Upgrades tree and Feed levels.**
- New key: `Config.Rebirth.Intro.KeepTree = true`.
- Rebirth 0 still costs 1,700, still sets Coins to 0, empties carried eggs and vacuum cargo,
  resets Gold roll counts, releases camps, gives +30 Gems and sets x1.5.
- It no longer resets `upgradeTree` or Feed levels.
- Ranks 1–50 are unchanged: Rebirth 1 still resets everything, as the reference does.

**(3) Army Size I = 300, Army Size II = 2,500** (were 1,200 / 6,000). Army Size III
(25,000) and IV (90,000) are unchanged. Flat for every rank (Oct 22 rule respected). Tier
meaning is unchanged, so no `TreeMigrations` step is needed.

**(4) Number-goes-up feedback.** These change no HUD layout. WS5 owns the HUD.

- **(a) Income gain float.** Successful `Buy`, `BuyUpgrade`, `FeedChicken` and
  `RebirthIntro` replies carry `income = {before = n, after = n}`. These are whole steady
  Coins/s from `DailyService.SteadyIncome(session)`, read before and after the handler.
  - When `after > before`, the client floats **"+N/s"** with the gold coin image
    (`"+" .. Theme.Coins(after-before) .. "/s"`; fallback text "+N Coins/s") from the Coins
    readout.
  - Motion: one UIMotion float, gold (`UIColors.Coins`). It is reduced-motion aware and
    plays at most once a second, so a burst of buys shows one summed float.
  - It never shows a negative change (Rebirth 1 resets).
- **(b) Storage message** (`RollService:Buy` status, copy only).
  - Was: "In storage."
  - New, for a chicken that neither lays nor joins the Army and while the next Flock tier
    exists: **"In storage. Grow your Flock in Upgrades so it lays eggs."**
  - At the last Flock tier: "In storage."
- **(c) Podium deal marker** (`RollStation` billboard).
  - When `offer.listPrice > offer.price`, the price row shows the starter price in gold
    and, after it, the list price in grey with a strikethrough (RichText `<s>1,900</s>`,
    20 px, `UIColors.TextMuted` or similar).
  - The buy prompt stays "Buy Rooster · 475 Coins".
  - No new words. "Sale", "FREE" and "%" are not used.

### 3.5 Results: proposal vs current (first-session agent, 30 seeds)

**Typical profile. Proposal = (1)+(2)+(3), FavoredRolls kept.**

| Minute | Coins/s (current → proposal) | Power | Chickens | Earned |
|---|---|---|---|---|
| 4 | 16.8 → 18.9 | 38 → 41 | 4 → 4 | 1,710 → 1,710 |
| 5 | 18 → **24** | 38 → 41 | 4 → 4 | 2,119 → 2,224 |
| 6 | 24 → 28.5 | 38 → **54** | 4 → 4 | 4,274 → 5,923 |
| 8 | 30 → 41 | 38 → 57 | 4 → 5 | 5,570 → 7,705 |
| 9 | 30 → 45 | 41 → 60 | 4 → 6 | 7,693 → 10,806 |
| 10 | 56 → **79** | 44 → **64** | 5 → 6 | 7,886 → 10,806 |
| 12 | 96 → 118 | 54 → 70 | 6 → 8 | 15,579 → 22,135 |
| 15 | 132 → 141 | 57 → 77 | 9 → 9 | 44,839 → 53,962 |
| 20 | 208 → 149* | 77 → 112 | 11 → 12 | 95,908 → 112,084 |

\*The minute-20 rate dips because more seeds took Rebirth 1 just before (the tree reset).

- Purchases from the tutorial to minute 10: 7 → 8. Median gap **69 s → 49 s**.
- Army Size I: minute 15.1 → **5.1**. Army Size II: never → 19.1 (22/30).
- Rebirth 1 by minute 20: 5/30 → 6/30 (the find binds; §3.6).

**Typical profile with the Army tip.** The `armyFirst` agent option models a WS1/WS5 tip
that points at Army Size when the Army is full and Fort Roost is next. Proposal plus tip,
compared with the current build plus the same tip:

| Minute | Power (proposal + tip) | Power (current + tip) |
|---|---|---|
| 5 | 51 | 38 |
| 7 | 67 | 38 |
| 9 | 93 | 51 |
| 11 | **109** | 61 |
| 13 | 113 | 70 |

- Fort Roost (≥106): **11.1 min (30/30)** vs 16.6 min (27/30).
- This meets the WS1 plan: a ~50–60 stepping stone at minutes 5–6 and ~106 by minutes 10–12.

**Engaged profile, same proposal.**

| Minute | Coins/s (current → proposal) | Power | Chickens |
|---|---|---|---|
| 5 | 18 → **36** | 38 → 51 | 5 → 8 |
| 6 | 36 → 63 | 41 → 61 | 6 → 9 |
| 7 | 70 → **113** | 45 → 77 | 7 → 10 |
| 8 | 126 → 188 | 58 → 89 | 9 → 12 |
| 9 | 182 → 263 | 87 → **109** | 10 → 14 |
| 10 | 212 → 322 | 98 → 144 | 12 → 16 |
| 15 | 702 → 641 | 214 → 221 | 18 → 20 |

- Purchases before minute 10: 26 → 28. Median gap 15 s → **12 s** (p90 56 → 51 s).
- Fort Roost: 11.6 → **9.6 min**. Rebirth 1 by 20 min: 8/30 → 10/30.
- From minute 15 the two converge: the discount has faded, and both are capped by the
  P5-tamed tier prices and the Rebirth 1 find. That convergence is what keeps Rebirth
  pacing intact.

Targets from the brief:
- **A meaningful purchase every 30–60 s through minute 10.** Met: typical 49 s median,
  engaged 12 s. Current typical: 69 s.
- **Every 1–2 min after minute 10.** Typical 49–64 s; engaged 30 s median. The engaged p90
  is 180 s while saving for Rebirth 1 and its find (§3.6).
- **Power of about 50–60 at minutes 5–6 and about 106 by minutes 10–12.** Met with the
  Army tip (51 at 5, 109 at 11). Without the tip, typical reaches 64 at minute 10 and
  needs WS5 guidance to Army Size II.

### 3.6 Rebirth pacing (ProgressionSimulation, 16 seeds, played minutes, medians)

Proposal = starter prices with fade, Rebirth 0 keeps the tree, FavoredRolls off (worst case
for speed), Army Size 300/2,500.

| Milestone | fast current | fast proposal | casual current | casual proposal |
|---|---|---|---|---|
| Rebirth 0 | 4.8 | 4.8 | 4.0 | 4.0 |
| Coins/s at 5 min | 18 | 45 | 18 | 33 |
| Coins/s at 10 min | 427 | 686 | 368 | 235* |
| All 3 camps | 15.5 | 12.8 | 16.5 | 13.5 |
| Rebirth 1 (target ~10) | 12.0 | **10.8** | 13.5 | 13.0 |
| Rebirth 2 (target 18–20) | 20.0 | 22.0 | 20.0 | 20.0 |
| Rebirth 3 | 28.8 | 28.0 | 31.5 | 29.8 |
| Rebirth 5 (target ~55) | 67.0 | 62.8 (−6%) | 72.0 | 72.0 |
| Rebirth 7 | 111.2 | 104.5 (−6%) | 110.0 | 110.0 |
| Rebirth 10 (target ~2.9 h) | 188.2 | 180.8 (−4%) | 190.5 | 187.8 (−1%) |

\*Casual at 10 min is just after Rebirth 1 in more seeds (the tree was reset).

- Component runs (fast): starter prices only gives Rebirth 1 12.0, Rebirth 10 183.0.
  Rebirth 0 keeps tree only gives Rebirth 1 11.2, Rebirth 10 186.8.
- Every rank stays inside the fit's tolerance (REBIRTH_PACING / RARITY_REBALANCE: "within
  about 7% at every rank to 40").
- **No Rebirth cost re-fit is needed.**
- Rebirth 2 moving +2 min in fast is seed noise from find waits (6–16 seeds; Rebirth 2's
  find is Detective at 1 in 174).

**Rebirth 1's binding constraint is the find, not Coins** (first-session agent, 30 min,
proposal applied):

| Rebirth 1 find | typical: Rebirth 1 by 30 min | engaged: Rebirth 1 by 30 min |
|---|---|---|
| Ironbeak (1 in 146), today | 7/30 (current build 5/30) | 16/30 (current 14/30), median 17.8 min |
| Gamer Chicken (Common, 1 in 27) | **19/30** | **29/30**, median 12.0 min |

This is handed to WS4 (§8). AGENTS.md "Rebirth finds" says to re-run the discovery probe
before changing the find. Also, Rebirth 1 resets Army Size, so a player who takes Rebirth 1
before Fort Roost drops back to 3 slots. WS1 should know that Rebirth 1 can come before
Fort Roost once the find is easier (typical with Gamer: Fort Roost 18/30 by 30 min vs 24/30).

---

## 4. Implementation steps (file by file)

Server modules own prices and Coins; the client only presents. No `DataRevision` bump and
no new saved field. Offers already live in the session, and `listPrice` is an extra field
on an offer table.

### 4.1 `src/shared/Config.luau` (edit, SHARED FILE)

1. In `Economy`, after `FavoredRolls`:
   ```lua
   -- October 27 (WS2 retention, live data: 46% of Buy attempts lacked Coins; Recruited10 16%):
   -- empty-start profiles see podium offers at a starter price, Fraction of the catalog quote
   -- while they own 2 chickens, rising linearly to the full quote at FullAt owned chickens.
   -- Rounded up to Step, never below Floor or above the catalog. Catalog prices are untouched
   -- (Every chicken its own odds and value, Oct 23); this is the podium's quote, like StarterLadder.
   StarterPrices = {Enabled = true, Fraction = 0.25, FullAt = 20, Floor = 150, Step = 5},
   ```
2. In `Rebirth.Intro`, add `KeepTree=true` with a comment: "Oct 27 (WS2): Rebirth 0 keeps the
   Upgrades tree and Feed levels; it costs the Coins and pays Gems and x1.5. false = Oct 23
   behaviour".
3. The `Version` label is the lead's call; WS2 does not change it.

### 4.2 `src/shared/Rules.luau` (edit)

Add a pure function next to `Rules.RecruitPrice`:

```lua
-- October 27 (WS2): a new profile's podium quote (Config.Economy.StarterPrices). `listPrice`
-- is Rules.RecruitPrice; `owned` the chickens owned when the offer is rolled. Pure, so the
-- simulation and checks share it.
function Rules.StarterPrice(listPrice: number, owned: number): number
	local s = Config.Economy.StarterPrices
	if type(s) ~= "table" or s.Enabled ~= true or listPrice <= 0 then return listPrice end
	local full = math.max(3, s.FullAt or 20)
	local f = (s.Fraction or 1) + (1 - (s.Fraction or 1)) * math.clamp(((owned or 0) - 2) / (full - 2), 0, 1)
	if f >= 1 then return listPrice end
	local step = math.max(1, s.Step or 5)
	return math.min(listPrice, math.max(s.Floor or 0, math.ceil(listPrice * f / step) * step))
end
```

### 4.3 `src/server/RollService.luau` (edit, LIKELY SHARED WITH WS4)

1. In `RollService:Roll`, where each offer's `price` is computed (`:93-94`), split the quote:
   - `list = Rules.RecruitPrice(species, level)`;
   - `price = if starter then StarterRecruitPrice elseif slot==1 and ladder then ladder.price
     elseif session.introRebirth ~= nil then Rules.StarterPrice(list, session:Count()) else list`;
   - store `listPrice = if price < list and not starter and not (slot==1 and ladder) then list else nil`
     on the offer.
2. `RollService:Buy` already charges `offer.price`. No change except the analytics hand-off:
   add `listPrice = offer.listPrice` to the returned `offer` table, which
   `GameServer:CountRecruit` reads.
3. Storage copy (`:290`). When `not selected and not laying`, write the status as
   `if nextFlockTier then "In storage. Grow your Flock in Upgrades so it lays eggs." else "In storage."`.
   `nextFlockTier` is `UpgradeCatalog.Tier(session.upgradeTree,"Flock") < #Families.Flock.tiers`.
4. Auto Roll needs no change: it buys at `offer.price`.

### 4.4 `src/server/RollStation.luau` (edit, LIKELY SHARED WITH WS4)

1. In `offerLabel`, add a third child to `PriceRow`: a `TextLabel` named "ListPrice",
   LayoutOrder 3, `RichText=true`, TextSize 20, grey (`UIColors.TextMuted`, or the existing
   muted token), `AutomaticSize=X`, with the same UIStroke style. Empty by default.
2. In `RollStation:Step`, the offer branch:
   - `self.listLabel.Text = if self.offer.listPrice and self.offer.listPrice > price then "<s>" .. commas(self.offer.listPrice) .. "</s>" else ""`;
   - clear it in the rolling, idle and `Clear` branches.
3. The buy prompt text is unchanged ("Buy X · 475 Coins").

### 4.5 `src/server/RebirthService.luau` (edit)

1. In `RebirthIntro` (`:490-492`), guard the two resets:
   `if not (intro.KeepTree == true) then session.upgradeTree = keptTree(session); resetFeedLevels(session) end`.
   `session:RefreshEffects()` stays.
2. In `introQuote`: when `KeepTree`, build `resets = {"All your Coins", "Carried eggs"}` and
   `keeps = {"Every chicken and the Index", "Every upgrade in the Upgrades tree", "Chicken levels bought with Chicken Feed", "Gems and Gem Upgrades"}`
   instead of `manifest(session)`. Add the field `keepTree = true`.
3. Update the header comment (`:12-13`) and the RebirthIntro doc comment (`:464-469`).

### 4.6 `src/client/RebirthPanel.luau` (edit, check WS5)

At `:262`, in Render or `LayoutTiles` when `quote.intro`, set the tile text:
`self.keepReward.Text = if quote.keepTree then "Chickens & Upgrades" else "Chickens"`.
The tile header "KEEP YOUR" is unchanged. TextScaled already fits it (verify on a phone
capture).

### 4.7 `src/shared/UpgradeCatalog.luau` (edit, check WS1)

- `ArmySize` tiers: `{{4, 300}, {6, 2500}, {8, 25000}, {10, 90000}}`.
- Comment: "Oct 27 (WS2): I and II from 1,200/6,000 so the 4th and 6th Army slots arrive with
  the Fort Roost stepping stone. Flat for every rank; tier meaning unchanged, no TreeMigrations".

### 4.8 `src/server/GameServer.luau` (edit, SHARED FILE: WS3/WS5)

1. At the top of the request handler, next to `balanceBefore`, add
   `local incomeBefore = if action is Buy/BuyUpgrade/FeedChicken/RebirthIntro then DailyService.SteadyIncome(session) else nil`.
   DailyService is already a server module; require it if it isn't.
2. Before `self:Send`:
   `local income = if ok and incomeBefore then {before = math.floor(incomeBefore + 0.5), after = math.floor(DailyService.SteadyIncome(session) + 0.5)} else nil`.
   Add `income = income` to the sent table.
3. Analytics emits (§5). Also in `CountRecruit`: when `recruit.offer.listPrice`, call
   `LaunchCount("econ.starterRecruit")` and `LaunchCount("econ.starterSaved", listPrice - price)`.
   The price comes from `balanceBefore - session.coins`, or pass `price` in the receipt's
   `offer` table.

### 4.9 Client float: `src/client/ActionFeedback.luau` (edit) plus a one-line hook in `src/client/AppController.luau` (SHARED)

1. `Feedback:IncomeGain(before, after)`:
   - If `after > before`, add `after - before` to a pending total.
   - Within 1 s, play one float from the HUD Coins readout: `UIMotion` float, text
     `"+" .. Theme.Coins(delta) .. "/s"`, gold, about 1.2 s, rise and fade. Use the
     existing float helper; no private animation (Game feel contract).
   - Reduced motion: a static fade.
2. In `AppController`'s result block (around `:1052-1068`):
   `if result.ok and type(result.income)=="table" then self.feedback:IncomeGain(result.income.before, result.income.after) end`.
3. No sound cue. A purchase already plays UIPurchase: one emphasis per event.

### 4.10 Player-facing copy (exact)

| Where | String |
|---|---|
| Storage receipt | "In storage. Grow your Flock in Upgrades so it lays eggs." |
| Income float | "+" coin image "N/s" (fallback "+N Coins/s") |
| Rebirth 0 keep tile | "KEEP YOUR" / "Chickens & Upgrades" |
| Rebirth 0 resets list | "All your Coins", "Carried eggs" |
| Rebirth 0 keeps list | "Every chicken and the Index", "Every upgrade in the Upgrades tree", "Chicken levels bought with Chicken Feed", "Gems and Gem Upgrades" |
| Podium | unchanged words; the struck-through list price is a number only |

None of these use "$", "pets", "cash", "merge", "Tap" or "Press".

### 4.11 Docs (lead, after the merge)

- New `docs/team/EARLY_ECONOMY_20261027.md`: this design, the tables and the switches.
- An AGENTS.md section of about 6 lines.
- One line each in `REBIRTH_SCREEN.md` "Rebirth 0" and `COMMANDER_TUTORIAL.md` (Rebirth 0
  keeps the tree; starter prices).
- Commit the probe as `tools/sim/first_session_probe.luau` (a cleaned `early.luau`) plus a
  README line, so later economy changes re-run the same first-session check.

---

## 5. Analytics (append-only, Schema.Version 16, shared bump with the other workstreams)

### 5.1 `src/server/AnalyticsSchema.luau` (SHARED; the lead serialises the version bump)

1. `Schema.Buckets.rate = {5, 10, 20, 40, 80, 160, 320, 640, 1280, 2560, 5120}`. This is a new
   kind, appended.
2. LaunchCounters:
   - `["econ.starterRecruit"] = true`: a recruit bought at a starter price.
   - `["econ.starterSaved"] = true`: n = Coins under the list price.
3. LaunchHistograms:
   - `["econ.buyGap"] = "seconds"`: suffix `.early` (≤600 s of total play) or `.mid`
     (600–1,200 s). The value is the seconds since the previous successful Coins purchase
     (Buy, BuyUpgrade with price > 0, FeedChicken, RebirthIntro). Empty-start profiles in
     their first 20 min of play only.
   - `["econ.rate"] = "rate"`: suffix `.m5`, `.m10` or `.m20`. Steady Coins/s
     (`DailyService.SteadyIncome`) when total play first passes 300, 600 and 1,200 s.
     Empty-start profiles only.
   - `["econ.buys"] = "count"`: suffix `.m10`. Coins purchases made by 600 s of total play,
     recorded once at the 600 s mark.
4. A version-16 note in the header list.

### 5.2 Emitters

- `GameServer`: on each successful purchase in the window, compute the gap from
  `session.econLastBuyAt` (session-only, not saved).
- The 300/600/1,200 s marks come from a once-a-second check in `GameServer:Step` or the
  existing analytics observe. Use `Analytics:PlaySeconds` and a session-only
  `econMarks` table.
- Analytics never changes gameplay.

### 5.3 Success metrics (1.25.0 vs the new build; new profiles; read with `AnalyticsReport` from Studio Edit, `env="live"`)

| Metric | Baseline | Target |
|---|---|---|
| Chicken buys in the first 2.5 min after the tutorial (journeys export; same query as §1.1) | p50 0 | p50 ≥ 1 |
| Tutorial finishers who leave without a further chicken buy | 134/484 = 28% | ≤ 18% |
| "Buy" rejections per new player (journeys `rej`) | 2.1 | ≤ 1.0 |
| `econ.buyGap.early` p50 | (new) | ≤ le60 |
| `econ.rate.m10` p50 | (new) | bucket ≥ le80 (model 56 → 79) |
| `econ.buys.m10` p50 | (new) | ≥ 8 |
| Roll funnel Recruited10 / Recruited | 16% | ≥ 30% |
| Session survival at 5 and 10 min | 36% / 21% | ≥ 40% / ≥ 24% (shared with WS1/WS5) |
| Cluck Camp winners who also win Fort Roost | read `camps` | +10 points, with WS1 |

Watch so they don't regress:
- `rebirth0.count` / new players (36%).
- Robux prompts (WS3; fewer shortfalls means fewer prompts; 99.7% were cancelled anyway).
- `rebirth2.playSeconds.1–5` medians against the 1.25.0 cohort, within ±10%.

How to read it:
- `Report.Summarize({days=2, env="live"})` for the funnels and sinks (`Recruit:*` average
  price should drop for new players).
- A new `Report.EarlyEconomyText` (optional, in AnalyticsReport, SHARED) prints the
  `econ.*` histograms by version.
- The journeys export query in §1.6, re-run on the new build.

---

## 6. Verification

### 6.1 Headless (Lune, `tools/sim`)

1. `runsuite.luau` (one suite per process; compare against a `git archive HEAD` copy).
   - **New `tests/StarterPriceChecks.luau`**, or add to `RulesAndBattles`. Checks:
     - for every `RollPool` species at owned 2, 5, 11, 19 and 20, `Rules.StarterPrice(list, owned)`
       is a whole number, ≤ list, ≥ Floor, and strictly increasing along the odds order
       (no two equal);
     - owned 20 or more gives exactly `list`;
     - `Enabled=false` gives `list`;
     - the Chicken stays at 150.
   - `RebirthV2Checks`: with `Intro.KeepTree=true`, `RebirthIntro` keeps `upgradeTree`
     (Flock1, EggVacuum, ArmySize1) and Feed levels. It still zeroes Coins, carried eggs and
     vacuum cargo, grants 30 Gems and sets x1.5. With `KeepTree=false`, the Oct 23
     behaviour holds.
   - `RecruitIntentChecks` or `ShopIndexChecks`:
     - a fresh empty-start session's non-ladder offer carries `listPrice` and the discounted
       `price`;
     - a legacy session (`introRebirth=nil`) gets the list price;
     - `Buy` charges `offer.price` and sets `investment` to it;
     - selling refunds 50% of the price paid.
   - `CommanderGuideChecks:40` fixture: update `ArmySize1` price 1200 → 300 if it asserts
     the catalog.
   - `AnalyticsChecks`: Version 16; the new names resolve through `launchPrefix`; the
     `rate` bucket exists.
2. Economy:
   - `first_session_probe.luau profile=typical|engaged seeds=30`. Expect Coins/s at 10 min
     ≥ 70 typical and ≥ 300 engaged, and Army Size I ≤ 6 min for both.
   - `ProgressionSimulation` 16 seeds, fast and casual, `hours=5 targetRank=10`.
     Rebirth 1–10 within ±7% of the 1.25.0 table in §3.6.
3. Luau static check: luau-lsp `analyze` per `local-luau-checks` memory, against a HEAD
   baseline.

### 6.2 Studio playtest script (lead or Stevin; Pet Roll Test 96683186622050, Edit then Play, a disposable profile via `TestNewPlayer`)

1. Finish the tutorial. The second Chicken still costs 20, from the ladder.
2. Pull the lever five or more times. Every non-Chicken podium shows a gold starter price
   with the grey struck-through list price (Rooster 475 ~~1,900~~). The buy prompt says
   "Buy Rooster · 475 Coins".
3. Buy one. Coins drop by exactly 475. My Army's refund for it reads 237.
4. Buy Egg Speed I. A gold "+N/s" floats from the Coins readout, and N matches the steady
   income change.
5. Buy a 5th chicken with Flock 4. The receipt reads "In storage. Grow your Flock in Upgrades
   so it lays eggs."
6. Reach 1,700 and take Rebirth 0.
   - The screen's third tile reads "KEEP YOUR / Chickens & Upgrades".
   - Afterwards Flock Size I is still owned (4 laying), the Egg Vacuum is still equipped and
     Egg Speed I is still owned.
   - Coins are 0 and Gems +30. The Coins/s readout jumps x1.5.
7. Upgrades: Army Size I costs 300 and Army Size II costs 2,500.
8. With about 12 owned chickens, quotes are about 69% of the list. With 20, the list price
   shows and the strikethrough is gone.
9. On a legacy profile (any pre-Oct-23 save without `introRebirth`), podium prices equal the
   catalog and nothing is struck through.
10. Phone viewport (WS6 device list): the price row with the struck-through number fits
    inside the 340-px billboard for a 7-digit Mythic quote.

---

## 7. Risks, owner-rule conflicts and rollback

| Risk or conflict | Assessment | Mitigation or rollback |
|---|---|---|
| **"Every chicken its own odds and value" (Oct 23):** "prices … never below the old values" | The catalog (`PetCatalog` price/income/valueOneIn) is unchanged. Starter prices are a temporary podium quote for new profiles, the same kind of exception as the owner's `StarterLadder` (Chicken 20 vs 150, Oct 26). Ordering and distinct whole prices are preserved and checked (§6.1). | If Stevin reads it as a conflict: set `StarterPrices.Enabled=false`. The compliant fallback is (2)+(3) alone (typical Coins/s at 10 min 56 → about 65, power path intact). |
| **FavoredRolls (AGENTS.md Oct 25)** | Kept as is. The model says it costs the typical player a little once starter prices exist. | WS4 may bring it to Stevin. No WS2 change. |
| **Rebirth 0 contract (Oct 23, "resets like a Rebirth")** | Changes a contract detail in `COMMANDER_TUTORIAL.md` and `REBIRTH_SCREEN.md`, not an AGENTS.md hard rule (AGENTS.md lists "+30 Gems, x1.5 eggs while rank 0, keeps chickens"). Stevin's standing order is "just do it". | `Config.Rebirth.Intro.KeepTree=false` restores Oct 23 exactly. |
| Tree prices "the same all the time" (Oct 22) | Army Size I/II stay flat across ranks; only the base number changes. Not rank-scaled. | Two numbers back to 1,200/6,000. |
| Rebirth pacing | Simulated within ±7% (§3.6). No cost re-fit needed. | Re-run psim; revert switches. |
| Podium price differs from the Index price | Mitigated by showing the struck-through list price. | – |
| Robux revenue (WS3) | Fewer Coins shortfalls means fewer pack prompts. 2,582 prompts were 99.7% cancelled (Oct 23 memory), so the expected loss is tiny. | WS3 owns the prompt rules. |
| Starter price on a rare early find (an Epic at 14,400) | A deliberate rarity moment, bounded by owned count and odds (Epic 0.04%). No Coins can be minted (refund 50% of paid). | – |
| Many purchases make the "+N/s" float spammy | Summed and throttled to 1 a second; reduced-motion aware. | Remove the AppController hook line. |
| Model limits | The agent is calibrated on earned, chickens and rolls from the 2-day export (n of 40–165 per bucket). The tree-browsing cadence is a guess. Absolute minutes can be off ±30%; the deltas between variants are the reliable part. | Read the `econ.*` metrics after publish. |

Single switches:
- `Config.Economy.StarterPrices.Enabled`
- `Config.Rebirth.Intro.KeepTree`
- Army Size prices: two numbers
- The float: one hook line

None of them touch saves.

---

## 8. FILES TOUCHED and cross-workstream interfaces

### 8.1 WS2 files

| File | New/Edit | What | Expected overlap |
|---|---|---|---|
| `src/shared/Config.luau` | edit | `Economy.StarterPrices`; `Rebirth.Intro.KeepTree` | **HIGH**: WS1 (Camps), WS4 (FavoredRolls, finds?), WS3 (shortfall knobs), WS6. Lead: one integrator applies the Config hunks. |
| `src/shared/Rules.luau` | edit | `Rules.StarterPrice` | low |
| `src/server/RollService.luau` | edit | offer `price`/`listPrice`; storage copy; receipt `listPrice` | **HIGH with WS4** (roll variety, favoured rolls, finds). The WS2 hunk is about 8 lines at `:93-94` and `:290`. |
| `src/server/RollStation.luau` | edit | ListPrice label (strikethrough) | **MEDIUM with WS4** (podium presentation and rarity moments) |
| `src/server/RebirthService.luau` | edit | `KeepTree` in `RebirthIntro` and `introQuote` | low; WS4 if it touches finds in `Quote` |
| `src/client/RebirthPanel.luau` | edit | keep tile text | low (WS5 if it restages the Rebirth screen) |
| `src/shared/UpgradeCatalog.luau` | edit | Army Size I/II prices | **MEDIUM with WS1** (Army path); WS5 if tips reference hexes |
| `src/server/GameServer.luau` | edit | `income` reply field; `econ.*` emits; `CountRecruit` starter counts | **HIGH**: WS3 (`needCoins`), WS5, WS7 |
| `src/client/ActionFeedback.luau` | edit | `IncomeGain` float | low (WS5 game feel) |
| `src/client/AppController.luau` | edit | one hook line | **HIGH**: WS3/WS5 |
| `src/server/AnalyticsSchema.luau` | edit | `rate` bucket, `econ.*` names, Version 16 | **HIGH**: every WS adding analytics. One shared Version 16. |
| `src/server/AnalyticsReport.luau` | edit (optional) | `EarlyEconomyText` | shared |
| `tests/StarterPriceChecks.luau` | **new** | §6.1 | – |
| `tests/RebirthV2Checks.luau` | edit | KeepTree cases | low |
| `tests/CommanderGuideChecks.luau` | edit (if needed) | ArmySize1 fixture price | WS5 may also edit it |
| `tests/AnalyticsChecks.luau` | edit | Version 16 / names | shared |
| `tools/sim/first_session_probe.luau` | **new** | cleaned `early.luau` | – |
| `tools/sim/README.md` | edit | one line | – |
| `docs/team/EARLY_ECONOMY_20261027.md` | **new** | design doc | – |
| `docs/team/REBIRTH_SCREEN.md`, `docs/team/COMMANDER_TUTORIAL.md`, `AGENTS.md` | edit (lead) | short notes | lead only |

### 8.2 Interfaces WS2 needs from other workstreams

- **WS1 (camp wall).**
  - WS2 delivers Army Size I = 300 and II = 2,500, plus a power curve (typical with an Army
    tip: 51 at 5 min, 67 at 7, 93 at 9, 109 at 11; engaged 109 at 9).
  - WS1 should size the stepping-stone camp at power about 50–60 (it then reads "Close
    fight" at ≥65–78, so pick the power with the 1.3x rule in mind).
  - WS1 should keep Fort Roost at 106 or show its verdict honestly.
  - Note that Rebirth 1 resets Army Size. If WS4 makes the Rebirth 1 find easier, some
    players will take Rebirth 1 before Fort Roost and drop to 3 slots. Consider keeping
    Fort Roost's requirement reachable at 3 slots plus Feed, or tip Army Size again after
    Rebirth 1.
- **WS5 (post-tutorial flow).**
  - (a) An Army Size tip when the Army is full and Fort Roost is the next target. This is the
    single biggest typical-player power lever in the model (Fort Roost 24+ min → 11 min).
  - (b) A "Grow your Flock" tip or arrow when a chicken goes to storage. WS2 changes the
    receipt copy; WS5 owns the tip chain.
  - (c) The HUD Coins readout anchor for the "+N/s" float. WS2 adds no HUD element. If WS5
    adds a Coins/s readout, the float should come from it.
- **WS4 (roll variety and rarity).**
  - (a) **Rebirth 1 find**: Ironbeak (1 in 146) → a Common at about 1 in 25–35 (e.g. Gamer
    Chicken 1 in 27). Rebirth 1 by 30 min goes 7 → 19 of 30 (typical) and 16 → 29 (engaged).
    Re-run the discovery probe (AGENTS.md "Rebirth finds").
  - (b) FavoredRolls stays (owner Oct 25). If WS4 proposes changing it, starter prices make
    the favoured Chicken less necessary.
  - (c) RollService and RollStation edits must be merged with WS4's: the WS2 hunks are the
    offer price lines and the price row only.
- **WS3 (Coins shortfall prompt).** `needCoins` is computed from the starter price
  automatically. Expect fewer prompts for new profiles. The 2,000-Coins-earned gate is
  unchanged.
- **WS6 (mobile and performance).** The extra billboard label and one UI float are
  negligible. Please include the podium price row in the phone capture pass.
- **WS7 (social and ad match).** No dependency. Ads that promise "rare chickens" match the
  starter-price rarity moments better.

### 8.3 Order for the lead's no-overlap matrix

1. Config/Rules/UpgradeCatalog/RebirthService/RebirthPanel: WS2 only, except the Config
   hunks.
2. RollService/RollStation: WS2 and WS4 in sequence (WS2 first: small hunks).
3. GameServer/AppController/AnalyticsSchema: integrate last, by the lead, with WS3/WS5/WS7
   hunks and one Version 16 bump.

---

## 9. Combined package check (lead request)

### 9.1 Recommendation

**Fort Roost strength 0.60 (power 63, readiness goal 82) and Ironbeak HQ 0.55. WS2 keeps
Army Size II at 6,000 and ships only the Army Size I cut (300).**

| Player | First Fort Roost win, p50 / p90 (min) |
|---|---|
| Typical, following the readiness card | 8.2 / 10.1 |
| Typical, not following it | 9.1 / 12.4 |
| Engaged | 7.4 / 8.6 |

Both typical medians land in the 8–12 min target. The WS2 + WS4 economy makes a 6-slot Army
cheap enough that Fort Roost at 0.50 falls in about 6 minutes (WS1's own warning). If the
Army Size II cut to 2,500 is kept as well, the matching strength is 0.8–0.9.

Rebirth pacing:
- Rebirth 10 and Rebirth 20 stay within ±2%.
- Rebirth 1 moves from 12.2 to 10.1 min (fast) and from 13.5 to 11.7 min (casual). This
  is toward its ~10 min fit target, not away from it.
- Rebirth 5 at −10% (fast) sits inside the current run's own seed spread (IQR 60.5–70.5).

**Change to §3.4 (3):** Army Size II stays 6,000 when it ships together with the WS1 strength.

### 9.2 What was simulated

**First-session agent** (`retention/ws2/early.luau`; the pre-change copy is `early_ws2only.luau`).
30 seeds, 30 minutes, the §3.1 profiles. New options model the other workstreams:

- **WS1:**
  - Fort Roost is fought at `floor(106 × strength)`.
  - The army attacks only when ready (≥ 1.3x, `strength=`); the headless win rate there is
    about 100%.
  - Marching to the camp and back takes 90 s.
  - `guided=true` is the readiness card. After Cluck Camp and until Fort Roost falls, the
    player buys the single best power-per-Coin step: Army Size (spare chickens, or 13 for
    each slot still empty plus 150 each to fill it), Get Feed, or a Feed level on an Army
    chicken.
  - The player follows the card `cardDelay` seconds after the last step: 20 s typical,
    5 s engaged. A 60 s delay gives identical results.
  - While saving for the card's step, the player buys nothing else from the tree.
  - Podium chickens that improve the Army are bought as before.
- **WS4:**
  - `lucky=true` is Lucky Start: post-tutorial pull 2 gives an Uncommon and pull 8 a Rare
    on podium 1, drawn inside the rarity. A natural offer pushes the next forced one 5 / 10
    pulls later. At most 2 of each, within a 40-pull window, and only while that rarity is
    not owned.
  - The roll-past guard is modelled as twice the patience on a lucky, Rare+ or Rebirth-find
    offer.
  - `favoredSpec=3x0.5`.
- **WS2:** starter prices (25% → 100% from 2 → 20 owned chickens), Rebirth 0 keeps the tree,
  and Army Size I 300 (II 2,500 unless the row says "II 6,000").

Column definitions:
- **Coins/s** is the steady rate with the Army counted at home. A marching Army's chickens do
  not lay, which would otherwise make the minute-5 sample noisy.
- **Gap** is the median gap between meaningful purchases (+5% income or power, or a
  Rebirth) from tutorial completion to minute 10.

### 9.3 Results (30 seeds; first Fort Roost win; "never" = not by minute 30)

**Typical player**

| Variant | Fort Roost power / goal | Win p50 | Win p90 | Coins/s at 5 / 10 min | Power at 5 / 10 min | Gap |
|---|---|---|---|---|---|---|
| Current build (no package, goal 138, unguided) | 106 / 138 | 28.6 (18/30) | never | 18 / 56 | 38 / 44 | 69 s |
| Package, strength 0.50 | 53 / 69 | **6.0** | 7.0 | 38 / 157 | 71 / 106 | 36 s |
| Package, strength 0.60 | 63 / 82 | 7.7 | 8.6 | 38 / 236 | 68 / 125 | 34 s |
| Package, strength 0.70 | 74 / 97 | 7.8 | 8.8 | 38 / 239 | 68 / 135 | 32 s |
| Package, strength 0.80 | 84 / 110 | 8.4 | 9.9 | 38 / 223 | 68 / 138 | 32 s |
| Package, strength 0.90 | 95 / 124 | 9.6 | 11.2 | 38 / 181 | 68 / 127 | 29 s |
| Package, strength 1.00 | 106 / 138 | 9.8 | 11.5 | 38 / 198 | 68 / 139 | 26 s |
| Package (II 6,000), strength 0.50 | 53 / 69 | 6.0 | 7.0 | 38 / 155 | 68 / 103 | 40 s |
| **Package (II 6,000), strength 0.60** | **63 / 82** | **8.2** | **10.1** | 38 / 160 | 68 / 107 | 35 s |
| Package (II 6,000), strength 0.70 | 74 / 97 | 8.7 | 10.4 | 38 / 149 | 68 / 116 | 34 s |
| Package (II 6,000), strength 0.80 | 84 / 110 | 9.2 | 11.6 | 38 / 149 | 68 / 118 | 34 s |
| **Unguided** package, strength 0.50 | 53 / 69 | 6.7 | 8.6 | 48 / 204 | 55 / 103 | 42 s |
| **Unguided** package, strength 0.60 | 63 / 82 | **9.1** | **12.4** | 48 / 170 | 55 / 94 | 48 s |
| **Unguided** package, strength 0.70 | 74 / 97 | 11.2 | 12.7 | 48 / 149 | 55 / 87 | 46 s |
| **Unguided** package, strength 0.80 | 84 / 110 | 13.2 | 22.3 | 48 / 148 | 55 / 87 | 49 s |

The Army Size II price does not matter for unguided players: they win before they buy it,
and both price variants gave identical numbers.

**Engaged player**

| Variant | Win p50 | Win p90 | Coins/s at 5 / 10 min | Power at 5 / 10 min | Gap |
|---|---|---|---|---|---|
| Current build (goal 138) | 11.6 | 13.6 | 18 / 323 | 38 / 98 | 15 s |
| Package, 0.50 | 6.4 | 7.4 | 34 / 396 | 64 / 135 | 21 s |
| Package, 0.60 | 7.2 | 8.1 | 34 / 338 | 64 / 126 | 20 s |
| Package, 0.70 | 7.5 | 8.1 | 34 / 336 | 64 / 126 | 20 s |
| Package, 0.80 | 7.7 | 8.3 | 34 / 336 | 64 / 127 | 19 s |
| Package (II 6,000), 0.50 | 6.4 | 7.4 | 34 / 424 | 64 / 120 | 21 s |
| **Package (II 6,000), 0.60** | **7.4** | **8.6** | 34 / 435 | 64 / 126 | 23 s |
| Package (II 6,000), 0.70 | 7.8 | 8.8 | 34 / 362 | 64 / 126 | 23 s |

Why a lower strength barely helps here: once Army Size I costs 300, the 4th slot arrives at
about minute 3. Lucky Start then puts an Uncommon (30 power, at a starter price of about
1,000) and a Rare (38–60) on the podium. Basic Chickens at 150 fill the spare slots, so power
reaches about 64–71 by minute 5. With Army Size II at 2,500 the 6th slot comes at about
minute 6.5, and Fort Roost falls around minute 6–8 for any strength from 0.5 to 0.7.

Why the engaged gap goes up from 15 s: more of its early purchases are cheap Army steps and
basic Chickens that add under 5% each, so they don't count as meaningful. The engaged player
still buys more often in total.

### 9.4 Rebirth pacing (ProgressionSimulation, 16 seeds per profile, played minutes, medians)

Package as recommended:
- WS2: starter prices with fade, Rebirth 0 keeps the tree, Army Size I 300, II 6,000.
- WS1: strength 0.60 / 0.55, odds bands 1.0 / 1.3.
- WS4: Lucky Start, FavoredRolls 3 × 50%.

The run used `psim.luau` with `strength2=0.6 strength3=0.55 ratios=ws1 lucky=true favoredSpec=3x0.5`,
hours 18, up to Rebirth 20. Seeds 1–16 ran as four processes of four seeds. The per-seed rows
are in `retention/ws2/combo/psim/*.txt`.

| Milestone | Fast, current | Fast, package | Δ | Casual, current | Casual, package | Δ |
|---|---|---|---|---|---|---|
| First camp | 3.5 | 1.8 | – | 2.8 | 1.8 | – |
| All 3 camps | 15.5 | 9.2 | −41% | 16.5 | 9.5 | −42% |
| Rebirth 0 | 4.8 | 3.0 | – | 4.0 | 3.5 | – |
| Rebirth 1 (fit target ~10) | 12.2 | **10.1** | −18% | 13.5 | **11.7** | −14% |
| Rebirth 2 (target 18–20) | 20.0 | 20.5 | +3% | 20.0 | 22.0 | +10% |
| Rebirth 5 (target ~55) | 67.2 | 60.6 | −10% | 72.5 | 69.2 | −5% |
| Rebirth 10 (target ~2.9 h) | 188.5 | 185.2 | **−2%** | 190.7 | 193.1 | **+1%** |
| Rebirth 15 | 388.6 | 375.9 | −3% | 377.3 | 379.3 | +1% |
| Rebirth 20 (target ~11 h) | 759.0 | 749.4 | **−1%** | 714.6 | 718.6 | **+1%** |

How to read the deviations:
- **Rebirth 1** comes earlier, which moves it onto the fit's ~10 min target. The current
  build runs 2–3.5 min over that target in this model.
- **Rebirth 2** at +10% (casual) and **Rebirth 5** at −10% (fast) are within seed noise. Fast
  Rebirth 5 had an IQR of 60.5–70.5 on the current build and 59.5–67.5 with the package.
  Casual Rebirth 2 depends on the find (Detective, 1 in 174).
- **Ranks 10–20 are within ±2%.** The Oct 23 cost fit holds, so no Rebirth cost re-fit is needed.
- If the lead wants Rebirth 1 at exactly the current value, the lever is `StarterPrices.FullAt`
  20 → 15. That shortens the discount window and changed Rebirth 1 by about 1 min in the
  first-session agent.

### 9.5 Caveats

- **The fights are optimistic and conservative at once.** They are always won at ≥ 1.3x and
  never tried below it. Real players also attack at "Close fight" (1.0–1.3x) and sometimes
  win, which would be earlier; and live wins are noisier than headless ones, which would be
  later. WS1's battle table supports the 1.3x rule.
- **The typical profile is calibrated to live earnings, not to fights.** Absolute minutes can
  be off by about ±30%. Strength 0.60 is the value whose guided and unguided medians both sit
  inside 8–12 min with the most room on both sides. 0.70 is the fallback if live data shows
  wins before minute 8.
- **The FavoredRolls, Lucky Start and roll-past guard behaviour is approximated** in the agent
  (see §9.2). WS4's own probe owns the exact per-pull numbers.
- **Not simulated:** WS5's tip ordering and its delay before the readiness card shows. The
  card was assumed visible immediately after Cluck Camp.
