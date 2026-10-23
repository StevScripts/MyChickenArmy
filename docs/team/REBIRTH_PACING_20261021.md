# Rebirth pacing: how long the game takes, and "more or harder?" (October 21, 2026)

Stevin asked for simulations of how long the game takes to beat, with a view to
retention ("a reason to come back, fun, not too hard") and the open question whether
Rebirths should be more or harder. This page records the runs, the numbers and the
recommendation. Nothing in `Config` was changed by this work.

## Method

`tests/ProgressionSimulation.luau` run headless with Lune 0.10.5 against main
(commit 7ac89f3 plus the simulation change below), one seed per process, 15 s ticks.
The simulation uses the real modules (tree prices, Feed quotes, RollService,
RebirthService, Gem Upgrades, Playtime Rewards); its header lists every assumption.
Fights are always won, spending is greedy, Rebirth happens as soon as the quote is
eligible. Real players took 1.5–1.8x the fast simulation's time at launch.

New this round (assumption 9 in the file): a **login model**. `playMinutes` and
`awayMinutes` make the player play, sell, leave and return to the real
`OfflineCash.Reward` (10% of the steady Flock rate, 8 h cap), the daily streak reward
(`DailyService.Check`) and a fresh Playtime clock. Milestones record wall-clock and
played time. Variants patch `Config.Rebirth.Costs` before the run.

Players simulated:

| Name | Behaviour |
|---|---|
| Fast nonstop | plays without stopping, sells every 60 s, rolls every 8 s (8 seeds, 40–60 h) |
| Casual nonstop | sells every 120 s, rolls every 20 s, 60-min Playtime visits (4 seeds) |
| 2 h a day | fast profile, one 2 h visit, 22 h away (3 seeds, 30 days) |
| 2 x 30 min | casual profile, two 30 min visits a day (3 seeds, 30 days) |
| 45 min a day | casual profile, one 45 min visit a day (3 seeds, 30 and 60 days) |

## Results with the live ladder (50K … 340T, 30 ranks)

Median time to reach each Rebirth (wall clock; login players in days):

| Rebirth | Fast nonstop | Casual nonstop | 2 h a day | 2 x 30 min | 45 min a day |
|---|---|---|---|---|---|
| 1 | 8 min | 8 min | 5 min | 5 min | 5 min |
| 5 | 48 min | 50 min | 50 min | day 1 | day 2 |
| 10 | 2.6 h | 2.5 h | day 2 | day 3 | day 4 |
| 15 | 5.9 h | 5.3 h | day 3 | day 5 | day 6 |
| 20 | 10.2 h | 9.2 h | day 5 | day 11 | day 12 |
| 25 | 18.6 h | 16.8 h | day 10 | day 15 | day 21 |
| 30 (the end) | 37 h (28–58 h) | 35 h | day 17 (one seed still at 29 on day 30) | day 22 | day 32 for two seeds; one stuck at 28 for 60 days |

Minutes of play between consecutive Rebirths (fast nonstop, medians):

| Ranks | 1–10 | 10–20 | 20–25 | 26–30 |
|---|---|---|---|---|
| Gap | 8–30 min | 30–70 min | 70–130 min | 200–430 min |

Where the Coins come from (share of all Coins over a game):

| Player | Eggs sold | Playtime tiles | Time Skip | Daily streak | Offline |
|---|---|---|---|---|---|
| Fast nonstop | 74% | 16% | 10% | 0 | 0 |
| 45 min a day | 52–56% | 21–22% | 9–11% | 10–11% | 2–7% |
| 2 x 30 min | 46–52% | 29–31% | 9–11% | 7–8% | 3% |

Rebirths per visit for the 45-min-a-day player: 2–4 a day in the first week, one a
day until about day 12, then every second to fourth day; 12–13 of the first 31 days
have no Rebirth. The 60-day seed with poor rolls spent days 31–60 at Rebirth 28–30
(two Rebirths in 30 days). The Gem board is complete at about Rebirth 25 in every
profile, so Gems have no use after that.

Reading: the opening and middle are in a good place (a Rebirth every 8–30 minutes
for the first 2.5 hours, every 30–70 minutes to Rebirth 20). The last five ranks are
where it hurts: 3.5–7 hours of play each for the fast player, which for a once-a-day
player is 3–10 days without a Rebirth. And the game ends at Rebirth 30 after roughly
one week of heavy play or three weeks of regular play, with nothing left to earn.

## Variants (fast nonstop, 3 seeds each, 80–120 h horizon)

| Ladder | R10 | R20 | R30 | R40 | R50 | Late gap (play) |
|---|---|---|---|---|---|---|
| Live | 2.6 h | 10 h | 37 h | – | – | 3.5–7 h (R26–30) |
| Harder: x2 from R6 | 3.7 h | 16.6 h | 72 h (1 of 3 within 80 h) | – | – | 9–13 h |
| Harder: x4 from R10 | 3.3 h | 28 h | not within 80 h | – | – | 5–8 h already at R21–25 |
| More: extend to 50 at x1.4 per rank | 2.6 h | 9.8 h | 28.5 h | not within 80 h | – | 4.4 → 12.5 h over R31–35 |
| More: extend to 50 at x1.2 per rank | 2.6 h | 9.8 h | 28.5 h | 98 h (2 of 3) | not within 120 h | 3.9 → 14.6 h over R31–41 |
| More: extend to 50 at x1.12 per rank | 2.6 h | 9.8 h | 28.5 h | 76 h | not within 120 h | 3.7 → 9.3 h over R31–45 |
| **Reshaped: x1.2 per rank from R21, x1.12 past R30, 50 ranks** | 2.6 h | 9.8 h | 16.9 h | 26 h | 40 h (38–59 h) | 40–120 min, rising slowly |

The three "extend" rows show that extending the live ladder alone does not work: ranks
31+ inherit the 3.7-hour gap of Rebirth 30 and grow from there even at x1.12. The
extension only pays off after the Rebirth 21–30 tail is flattened, which is why the
reshaped ladder does both.

Reshaped ladder for the 45-min-a-day player (3 seeds, 60 days): Rebirth 30 on
day 21, 40 on day 38, 50 on day 45 for the lucky seed and after day 60 for the
others; most days from day 12 on alternate one Rebirth, no Rebirth, with no
multi-day droughts in two of three seeds. It earns about 21,000 Gems by Rebirth 50
against a 5,235-Gem board.

Reshaped costs (Coins): R1–R20 unchanged; R21 9.96T, R22 12T, R23 14.3T, R24 17.2T,
R25 20.7T, R26 24.8T, R27 29.7T, R28 35.7T, R29 42.8T, R30 51.4T, then x1.12 a rank:
R35 ≈ 90.6T, R40 ≈ 160T, R45 ≈ 281T, R50 ≈ 496T.

Why x1.12 past 30: each rank adds +1 to the egg multiplier (about +3% at rank 30)
plus a little from Gem Coin Boost and new chickens, so income grows roughly 5–10% a
rank late. A cost ratio near that keeps the gap flat; x1.4 makes each rank 30%
longer than the last.

## Recommendation

**More, not harder.** Making the ladder harder (x2 or x4) only lengthens the
already-slow tail: late ranks become 9–13 hours of play each, a week or more per
rank for a daily player, and Time Skip stops mattering. It does not add anything to
come back for.

1. Keep Rebirth 1–20 exactly as they are. That pace is the fun loop.
2. Flatten Rebirth 21–30 to about x1.2 a rank (R30 ≈ 51T instead of 340T) so a
   daily player keeps getting a Rebirth every day or two instead of every 3–10 days.
3. Extend the ladder past 30 at about x1.12 a rank (50 ranks, or an endless formula)
   so heavy players have weeks of runway instead of finishing in one.
4. Give Gems a sink before extending (more Coin Boost / Keep Upgrades levels, or a
   new row), otherwise ranks 26+ pay Gems nobody can spend.
5. Offline Coins are 2–7% of a login player's income, so they are not the come-back
   hook today; Playtime tiles (per visit) and the daily streak are. Raising offline
   efficiency (10% → 20%, 8 h cap kept) is the lever if a stronger reason to log in
   is wanted; the October 15 cut happened when offline was 52% of all cash, in the
   old economy.

Not modelled: the Hill, Missions replays after the first clears, passes and Robux,
Friend Boost, PvP, other players. Luck of rolls spreads seeds about 2x (28 vs 58 h
to Rebirth 30), so a run with no Mythic or mutation sits at the late wall far longer
than the medians.

## Shipped (October 21, Stevin: "That works lets do that")

- `Config.Rebirth`: `MaxRank` 50; `Costs` keep ranks 1–20, then 9.96T, 12T, 14.3T,
  17.2T, 20.7T, 24.8T, 29.7T, 35.7T, 42.8T, 51.4T (x1.2) and 5.76e13 … 4.96e14 (x1.12,
  rounded to three figures). `EnemyScaleMaxRank` 30: `RebirthService.EnemyScale` stays
  x8 past Rebirth 30, so the new ranks do not make camps or the King harder than today.
- Gem sink (`GemUpgradeCatalog`): Roll Speed and Extra Luck 5 → 8 levels (100, 160,
  250), Vacuum Capacity 3 → 5 (100, 175), Time Skip 6 → 9 (230, 320, 430), Offline
  Coins 4 → 8 (210, 280, 360, 450), Army Power 5 → 10 (550, 725, 925, 1150, 1400):
  about 7,300 more Gems, board total about 12,500. Coin Boost and Keep Upgrades are
  unchanged (more would speed every run and undo the fit). Saved levels keep their
  meaning; `Read` clamps to the new maxima, so no migration.
- `ShopCatalog.RebirthSkip3` covers ranks 16–50 (the live product is still named "Skip
  Rebirth 16-30" on the Creator Dashboard; rename it there when convenient).
- Tests: `RebirthV2Checks` pins the 50 costs, the tail ratios and the enemy-scale cap.
  `ProgressionSimulation` reports Rebirth 35/40/45/50 rows.

Check runs on the shipped config (same harness, 15 s ticks; fast nonstop 4 seeds,
45 min a day 3 seeds over 60 days), medians:

| Rebirth | Fast nonstop | 45 min a day (wall clock) | 45 min a day (played) |
|---|---|---|---|
| 10 | 2.6 h | day 4 | 2.3 h |
| 20 | 10.6 h | day 12 | 9.4 h |
| 30 | 21.1 h (was 37 h) | day 21 (was day 32) | 16.1 h |
| 40 | 34 h | day 31 | 23.3 h |
| 50 (the new end) | 38–45 h for 2 of 4 seeds; the others at 46 and 49 after 70 h | day 44 for 2 of 3; the unlucky seed at 43 after 60 days | 33 h |

- Minutes of play per Rebirth from 21 to 50: 40–150 (fast), 30–95 (daily). No rank
  takes more than 2.5 hours of play.
- The daily player from day 12 on: the two ordinary seeds have 5 days without a
  Rebirth and never two in a row; the unlucky seed has 25 such days but its longest
  drought is 3 days (it was 10–30 days on the old ladder).
- The Gem board (12,500 after the sink) completes at Rebirth 41 in every run, with
  about 20,600 Gems earned by Rebirth 50 (More Gems included), so roughly 7,000 are
  still unspent at the end; a later row can take them.

## Reproducing

Lune harness (scratch, not committed): a fake DataModel that mounts `src/shared`,
`src/server` and `tests/`; see the `headless-luau-with-lune` memory note for the
shape. Entry scripts take `key=value` options and write JSON per run:

```
lune run harness.luau <repo> sim.luau seeds=1 firstSeed=3 hours=720 profile=casual playMinutes=45 awayMinutes=1395 out=daily45-3.json
lune run harness.luau <repo> variant.luau seeds=1 firstSeed=1 hours=120 profile=fast lateFrom=21 lateRatio=1.2 maxRank=50 extendRatio=1.12 out=flat50-1.json
```

From Studio: `require(game.ServerStorage.PetRollTests.ProgressionSimulation).Run({hours=720, profile="casual", playMinutes=45, awayMinutes=1395})`.

## October 21 later: reference-shaped ladder (P5, reference parity pass)

Stevin, from the third Drop a Fruit recording: "The rebirth value goes from 50,000 for
number one to 1 million; our jump is too high … make the barrier to entry easier, but
also don't make it super easy for players to get coins really fast." The live ladder
went 50K → 62M (Rebirth 2 cost 1,240x Rebirth 1). Contract:
`REFERENCE_PARITY_20261021.md` §2.5 (Costs[1] = 50K, Costs[2] = 1M; ratios 3–20
through Rebirth 10 and 1.1–3 after; the October 21 time targets; Coins no faster than
today in the first hour).

### Why Rebirth 2 had to cost 62M

A trace of the live economy (fast player, seed 1) shows it. Rebirth 1 comes at 9 min
with the Flock earning 680 Coins/s. The Time Skip pays 170K, which rebuys Egg Speed and
Egg Value I–IV at once (101K for x15), so the rate is 10K/s one minute later. Chicken
Feed then doubles a chicken's eggs per level and reaches Lv 5–6 within seven minutes
(x32), and the 12- and 15-minute Playtime tiles pay 11 minutes of that rate: 580K/s and
76M by minute 16. Every later run rebuys the whole tree in its first minute, so only
the first run is poor, and the ladder has to jump once.

### What changed

| Knob | Before | After | Where |
|---|---|---|---|
| Eggs per Chicken Feed level (Lv 1–10) | x2 | x1.6 | `Rules.EggLevelGrowth` |
| Feed quote | `RecruitPrice(level) × 0.75 × 2.5^(level−1)` (x5 a level) | `RecruitPrice(level) × 0.45 × 2^(level−1)` (x4 a level); each level pays back in the same time as before | `Config.Economy.ChickenUpgradeRecruitFraction`, `Rules.ChickenUpgradeGrowth` |
| Feed Lv 10 → 11 quote | 1.25 × the Lv 9 → 10 quote | 5/3 × (same payback as before) | `Rules.FeedPastCapFirst` |
| Egg Speed III / IV | 8K / 30K | 250K / 60M | `UpgradeCatalog` |
| Egg Value III / IV | 12K / 45K | 400K / 250M | `UpgradeCatalog` |
| Flock Size 7, 8, 10, 12, 15 | 4.5K, 9K, 18K, 35K, 70K | 25K, 250K, 3M, 80M, 2B | `UpgradeCatalog` |
| Rebirth egg multiplier | x(1 + rank): x2, x3 … x11 at 10, x31 at 30, x51 at 50 | x(1 + rank), times x1.7 for each of ranks 5–10 and x1.06 for each rank after, rounded: never below x(1 + rank) (table below) | `RebirthService.Multiplier`; `Config.Rebirth.EggBoostPerRank` 1.7, `EggBoostFromRank` 5, `EggBoostToRank` 10, `EggLateGrowthPerRank` 1.06 |
| Rebirth costs | 50K, 62M, 1B … 1.1T at 10, 51.4T at 30, 496T at 50 | 50K, 1M, 20M, 400M, 8B … 4.7T at 10, 384T at 30, 3.13e15 at 50 (table below) | `Config.Rebirth.Costs` |

Tier values are unchanged (only prices moved), so saved tiers keep their meaning and no
`TreeMigrations` step is needed. Saved Feed levels keep their numbers; a chicken fed to
Lv 10 lays 1.6^9 = 69x its base instead of 512x until the next Rebirth takes the levels
back. Time Skip, Gem Upgrades (prices and effects) and the 11 original tier species are
untouched. No `DataRevision` change.

### How the knobs were chosen (fast player, 4–6 seeds per row)

Ranks 1–2 are fixed (50K, 1M), so only income knobs move Rebirth 2; every other cost
was fitted with the P0 method (move each cost by the ratio of target gap to measured
gap, damped, inside the ratio bands).

| Variant | Result |
|---|---|
| Live income, 50K / 1M / then x5 | Rebirth 2–5 all inside minute 12–13: ranks 3–5 would need ratios far above 20 |
| Feed x1.6 only | Rebirth 2 at 12 min, 5 at 16 min: the tree is still rebought at once |
| Pricier Egg Speed/Value III–IV and Flock 7+ (several price sets), with or without Feed x1.6 or a +50%-a-rank egg multiplier | Rebirth 2 always lands at 14–15 min (see below) |
| Tree prices + Feed x2 | ranks 3–5 pinned at the x20 cap (Rebirth 3 at 16 min), ranks 8–10 pinned at the x3 floor and still late (Rebirth 9 at 2.8 h, target 2.4 h) |
| Tree prices + Feed x1.6 | Rebirth 3 at 21 min, 5 at 47 min; ranks 7–10 at the x3 floor and late (Rebirth 9 at 3.3 h) |
| Even pricier tree tops (Egg Value IV up to 100B) | slower still: Rebirth 7 at 2.2–2.4 h at the x3 floor |
| Tree prices + Feed x1.6 + egg multiplier x1.35 on ranks 5–10 | Rebirth 10 at 3.2 h with ratios at the x3 floor |
| ... + x1.5 on ranks 5–10 | on target through Rebirth 12 with ratios 3.0–4.8 (before the retune) |
| Tail at the x1.1 floor, no late growth (6 seeds, 40 h) | Rebirth 20 at 12.0 h, 30 at 27.8 h, 40 reached by 1 of 6 |
| Tail with +4% egg multiplier a rank past 10 | Rebirth 30 at 20.0 h, 40 at 32.6 h (3 of 4), 50 by 1 of 4; the fit wanted ratios below 1.1 |
| Tail with +6% a rank | Rebirth 30 at 15.7 h, 50 at 28.5 h with ratios 1.12–1.15 (too fast) |
| Tail with +5% a rank and ratios 1.31 / 1.17 / 1.11 (first confirmation, 6 fresh seeds) | too steep after a wall at Rebirth 16 (Royal Missions open at 15 and the simulated player spends on its army): Rebirth 20 at 12.8 h, 30 at 37.6 h (3 of 6) |
| After main's rarity pacing retune (41ee725: gentler Luck, Super/Mega Luck 5M–400B, Playtime Coins x0.4) with x1.5 on ranks 5–10 | Rebirth 1–5 on target (11, 17, 24, 38, 55 min) but ranks 6–9 at the x3 floor and Rebirth 10 at 3.0–4.0 h |
| ... with x1.7 on ranks 5–10 | Rebirth 6–10 on target with ratios 3–4.3 (chosen) |
| Tail on the retune, +5% and +7% a rank past 10 (5 seeds each, 40 h) | ranks 11–20 far too steep for the retuned Luck (Rebirth 15 at 9.1–9.4 h, 20 at 19–20 h), ranks 30–40 at about 35–40 min a rank with +7%; the costs were moved by each rank's target / measured gap, smoothed, with +6% (chosen) |
| First confirmation on the merged code (6 fast, 3 casual, 3 daily seeds) | fast Rebirth 20 at 13.6 h and 30 at 26.4 h (late), casual 11.5 h and 21.1 h, daily Rebirth 30 on day 22; a x1.41 step at Rebirth 32 made late casual ranks 100–180 min. Ranks 16–50 were lowered (16–18 to the x1.1 floor, 21–31 by 20%, the step at 32 removed): the shipped ladder |

Why the egg multiplier had to change: with the in-run explosion gone, income between
Rebirth 5 and 10 grows only about 1.8x a rank at the target gaps, so the contract's x3
floor would push Rebirth 10 to 3–4 h. The extra x1.7 a rank on ranks 5–10 puts the
between-run growth where the reference has its big steps and stops at 10. The late
x1.06 a rank exists for the same reason: Feed levels past 10 add only +25% each, so
late income grows about 5% a rank and the x1.1 floor alone made each late Rebirth longer
than the last (Rebirth 30 at 28 h, 40 reached by 1 of 6 seeds). Both factors are ≥ 1, so
no saved rank lays for less than its old x(1 + rank) (`RebirthV2Checks` asserts it).

| Rebirth | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Old egg multiplier | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 |
| New | 2 | 3 | 4 | 5 | 10 | 20 | 39 | 75 | 142 | 266 | 307 | 353 | 402 | 457 | 517 | 582 | 653 | 731 | 816 | 908 |

Rebirth 30 is x2,400 and Rebirth 50 x12,662 (were x31 and x51). The Rebirth screen's
multiplier tile reads `quote.multiplierNow/Next` from the server quote, i.e. this
function; no client computes the multiplier itself.

### Rebirth 2 and the Playtime tiles

Rebirth 1 comes at 8–11 minutes (50K, as before). Before the rarity pacing retune
(41ee725) the 12- and 15-minute Playtime tiles paid 11 minutes of steady income, so with
Gold Rush and the Time Skip a 1M Rebirth 2 at minute 19 would have needed a second run
earning less than the first run's last minute; every tamed variant landed Rebirth 2 at
13–15 minutes. The retune pays 0.4 of those minutes (2 and 2.4), and Rebirth 2 now lands
at 17 minutes on the merged code (target 18–20).

### Costs (`Config.Rebirth.Costs`, Coins; "x prev" is the ratio to the rank before)

| Rebirth | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Cost | 50K | 1M | 20M | 400M | 8B | 24B | 72B | 255B | 1.09T | 4.7T |
| x prev | – | 20.00 | 20.00 | 20.00 | 20.00 | 3.00 | 3.00 | 3.54 | 4.27 | 4.31 |
| Was | 50K | 62M | 1B | 8.6B | 36B | 56B | 120B | 260B | 600B | 1.1T |

| Rebirth | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
|---|---|---|---|---|---|---|---|---|---|---|
| Cost | 9.6T | 15T | 22T | 31.8T | 39T | 42.9T | 47.2T | 52T | 61.1T | 71.2T |
| x prev | 2.04 | 1.56 | 1.47 | 1.45 | 1.23 | 1.10 | 1.10 | 1.10 | 1.18 | 1.17 |
| Was | 1.2T | 2.2T | 2.9T | 3.8T | 4.5T | 5T | 5.5T | 6.3T | 7.3T | 8.3T |

| Rebirth | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 | 30 |
|---|---|---|---|---|---|---|---|---|---|---|
| Cost | 86.4T | 101T | 115T | 128T | 152T | 177T | 221T | 263T | 324T | 384T |
| x prev | 1.21 | 1.17 | 1.14 | 1.11 | 1.19 | 1.16 | 1.25 | 1.19 | 1.23 | 1.19 |
| Was | 9.96T | 12T | 14.3T | 17.2T | 20.7T | 24.8T | 29.7T | 35.7T | 42.8T | 51.4T |

| Rebirth | 31 | 32 | 33 | 34 | 35 | 36 | 37 | 38 | 39 | 40 |
|---|---|---|---|---|---|---|---|---|---|---|
| Cost | 456T | 510T | 580T | 642T | 712T | 788T | 870T | 959T | 1.07e15 | 1.18e15 |
| x prev | 1.19 | 1.12 | 1.14 | 1.11 | 1.11 | 1.11 | 1.10 | 1.10 | 1.12 | 1.10 |
| Was | 57.6T | 64.5T | 72.2T | 80.9T | 90.6T | 101T | 114T | 127T | 143T | 160T |

| Rebirth | 41 | 42 | 43 | 44 | 45 | 46 | 47 | 48 | 49 | 50 |
|---|---|---|---|---|---|---|---|---|---|---|
| Cost | 1.3e15 | 1.43e15 | 1.58e15 | 1.74e15 | 1.92e15 | 2.12e15 | 2.34e15 | 2.58e15 | 2.84e15 | 3.13e15 |
| x prev | 1.10 | 1.10 | 1.10 | 1.10 | 1.10 | 1.10 | 1.10 | 1.10 | 1.10 | 1.10 |
| Was | 179T | 200T | 224T | 251T | 281T | 315T | 353T | 395T | 443T | 496T |

The early ratios sit at the x20 cap through Rebirth 5 and near the x3 floor at 6–7:
the cap is binding (Rebirth 3 and 4 come at about 24 and 37 minutes instead of the
interpolated 30 and 42), the floor nearly so. Ranks 16–18 sit at the x1.1 floor because
of a wall at Rebirth 16 (Royal Missions open at 15 and the simulated player spends a
quarter of its Coins on its army while it cannot win them; the morning fit had x1.1 there
too), so Rebirth 16 stays the longest early rank.

### Results (merged code: P4 Time Skip claim + rarity pacing retune 41ee725)

Confirmation on fresh seeds with the committed code: fast nonstop seeds 121–126 (40 h),
casual 131–133 (40 h), 45 min a day 141–143 (60 days). "Before" is the morning economy
with the morning ladder (this doc's Shipped section and 3 fast seeds of d4d1e20). For
reference, the rarity retune with the morning ladder measured fast Rebirth 20 at 25.8 h
and 30 at 62.5 h, and the 45-min player's Rebirth 30 on day 51–57
(`RARITY_PACING_20261021.md` §5; that simulation never claimed the Time Skip, so it ran
11–17% short of Coins).

| Rebirth | Target (fast) | Fast, before | **Fast, after** | Casual, after | 45 min a day, before | **45 min a day, after** | 45 min a day, played |
|---|---|---|---|---|---|---|---|
| 1 | ~10 min | 8 min | 10 min | 12 min | 5 min | 8 min | 8 min |
| 2 | 18–20 min | 16 min | 17 min | 17 min | – | 16 min | 16 min |
| 5 | ~55 min | 48 min | 55 min | 59 min | day 2 | day 1 | 45 min |
| 10 | ~2.9 h | 2.6 h | 2.9 h | 2.8 h | day 4 | day 2 | 2.0 h |
| 20 | ~11 h | 10.5 h | 12.9 h | 11.3 h | day 12 | day 11 | 8.4 h |
| 30 | ~21 h | 19.6 h | 24.6 h | 20.5 h | day 21 | day 18 | 13.9 h |
| 40 | – | 30.5 h | 33.9 h (4 of 6) | 31.8 h | day 31 | day 27 | 20.3 h |
| 50 | ~40 h | 38 h (1 of 3) | 38.7 h (1 of 6) | – (0 of 3) | day 44 (2 of 3) | day 38 | 29.1 h |

Minutes of play per Rebirth (median across seeds; the longest single seed in brackets):

| Ranks | Fast | Casual | 45 min a day |
|---|---|---|---|
| 2–5 | 7–20 (22) | 7–24 (27) | 7–14 (16) |
| 6–10 | 17–34 (46) | 14–32 (34) | 7–26 (28) |
| 11–15 | 35–54 (59) | 31–52 (53) | 21–41 (43) |
| 16–20 | 68–93 (119) | 53–70 (90) | 35–56 (73) |
| 21–30 | 55–80 (101) | 51–64 (78) | 12–42 (59) |
| 31–40 | 62–89 (135) | 49–81 (101) | 31–52 (56) |
| 41–50 | 49–108 (122) | 46–116 (119) | 31–77 (81) |

45 min a day, one visit a day (60 days):

- seed 141: Rebirth 50 after 37 days (Rebirth 50 on day 36); 2 of days 12–37 without a Rebirth; longest drought 1 day
- seed 142: Rebirth 50 after 44 days (Rebirth 50 on day 43); 1 of days 12–44 without a Rebirth; longest drought 1 day
- seed 143: Rebirth 50 after 39 days (Rebirth 50 on day 38); 1 of days 12–39 without a Rebirth; longest drought 1 day

Against the targets: Rebirth 1 (10 min), 5 (55 min) and 10 (2.9 h) are on target and
Rebirth 2 is 17 min (target 18–20, 1–3 min early). The fast player is late from Rebirth
16: Rebirth 20 at 12.9 h (+1.9 h) and 30 at 24.6 h (+3.6 h, +17%), and only 1 of 6 seeds
reaches Rebirth 50 within 40 h (38.7 h; the morning economy also reached it with 1 of 3).
The 45-min-a-day player is early: Rebirth 30 on day 18 (target day 21), Rebirth 50 on day
36–43. Lowering ranks 16–50 further for the fast player would move the daily player
further ahead (the retune's Playtime cut hurts long visits more than daily logins), so
this ladder sits between the two; casual nonstop (60-minute visits) is on target (11.3 h,
20.5 h). No rank takes more than 2.5 h of play (longest single gap 135 min, a fast seed
at Rebirth 40), and the daily player never goes more than a day without a Rebirth after
day 12 (1–2 such days per seed).

### Coins per minute in the first hour (all sources, fast player, medians)

| Window | Morning economy, morning ladder | Retuned main (41ee725), morning ladder | **After (this ladder)** |
|---|---|---|---|
| 0–10 min | 188K | 69K | 25K |
| 10–30 min | 860M | 273M | 26.6M |
| 30–60 min | 3.91B | 2.31B | 493M |

Before columns: 6 fast seeds (11–16) of the same instrumented simulation on d4d1e20 and
on main 41ee725; after: the 6 confirmation seeds. Coins arrive slower than before in
every window of the first hour.

### Reproducing

Lune harness (scratch, see "Reproducing" above; `tools/sim/` now holds the same harness
in the repo). The fit ran the real modules with key=value knobs patched on top
(`eggGrowth`, `feedFirst`, `feedGrowth`, `pastFirst`, `multStep`/`multFrom`/`multTo`/
`multLate`, `tree=<patched UpgradeCatalog>`, `costs=<json>`); the confirmation runs use
the committed code with no patches:

```
lune run harness.luau <repo> sim.luau seeds=1 firstSeed=91 hours=40 profile=fast out=ff-91.json      # seeds 91-96
lune run harness.luau <repo> sim.luau seeds=1 firstSeed=101 hours=40 profile=casual out=fc-101.json  # seeds 101-103
lune run harness.luau <repo> sim.luau seeds=1 firstSeed=111 hours=1440 profile=casual playMinutes=45 awayMinutes=1395 out=fd-111.json  # 111-113
(cd tools/sim; ./lune run harness.luau ../.. rarity_probe.luau profile=fast hours=4 seeds=2)
```

`ProgressionSimulation` now plays to `Config.Rebirth.MaxRank` by default (was 30),
claims the Time Skip right after each Rebirth (P4), records the Coins earned with every
milestone, prints "Coins earned per minute" for the first hour and can trace a run
(`traceEvery=<seconds>`). From Studio:
`require(game.ServerStorage.PetRollTests.ProgressionSimulation).Run({hours=40, profile="fast"})`.

### Live notes

- Saved tiers keep their values; only the price of the next tier changed. A player who
  owns Egg Speed IV keeps x3.
- Fed chickens lay less until the next Rebirth (Lv 10: 69x base instead of 512x); the
  Feed quote for the next level is lower to match.
- Every rank from 5 up earns more egg Coins than before (Rebirth 8: x75, was x9); costs
  of ranks a player has not reached yet moved both ways (Rebirth 7 72B, was 120B;
  Rebirth 10 4.7T, was 1.1T; Rebirth 20 71.2T, was 8.3T).
- Offline Coins, daily rewards, Playtime tiles and Time Skip are minutes of steady
  income, so they grow with the multiplier as before.


## October 22: Time Skip head start

Stevin: "Every time I rebirth yea my money resets to zero but I get some type of bonus
that lets me easily unlock everything, thats too easy, yea I want a bonus but not to a
point where it easily unlocks everything!!"

### Cause

Time Skip paid its minutes (5, up to 45 with Gems) of the egg income the player had
*right before* the Rebirth: every tree tier, every Chicken Feed level. That rate is what
pays for a whole rank, so a few minutes of it is far more than the reset tree costs.
`tools/sim/timeskip_probe.luau` on the fast player (HEAD before the change):

| Rebirth | Time Skip | Tree tiers it buys (of 115) | x the tree just lost | Share of the next rank |
|---|---|---|---|---|
| 1 | 181K | 36 | 8.7x | 18% |
| 3 | 33M | 96 | 11x | 8% |
| 5 | 1.7B | 109 | 2.5x | 7% |
| 9 | 287B | 114 | 19x | 6% |
| 10 | 761B | all | 3.5x | 8% |
| 15 | 10T | all | 16x | 23% |
| 18 | 36T | all | 58x | 59% |

### Change

`RebirthService.TimeSkipCoins` now measures the income the player will have right
*after* the Rebirth: the best Flock-size chickens (the tree's Flock tiers reset, Gem
Flock slots stay) at the tiers Keep Upgrades leaves, with no Feed levels, at the next
rank's multiplier, with Coin Boost, 2x Coins and 2x Egg Spawn. It is a head start on
the new run: N minutes of what that run will earn at its start. A Skip Rebirth resets
nothing, so it measures the kept tree and Feed levels. Panel preview, claim popup,
saved `timeSkipPending` and Gem levels are unchanged.

| Rebirth | Time Skip | Tree tiers it buys | Share of the tree just lost |
|---|---|---|---|
| 1 | 30K | 20 | (the tree was 21K) |
| 3 | 1.7M | 66 | 19% |
| 5 | 6.7M | 84 | 1% |
| 10 | 434M | 106 | 0.2% |
| 18 | 10.7B | 111 | 1.7% |

The big tiers (Egg Speed/Egg Value IV, Flock 10–15, Super and Mega Luck) have to be
earned again in every run. The many cheap tiers (Army, Tools, early Luck) still come
back at once in late ranks: the tree's prices are flat while the egg multiplier grows,
so the new run's own income rebuys them within minutes too (`UpgradeCatalog.RankPriceGrowth`
is the knob if that should change; it is 0).

### Ladder re-fit

The old Time Skip was carrying part of every rank (6–8% early, 50–60% from Rebirth 17),
so without it the fast player reached Rebirth 10 at 3.3 h instead of 2.5 h and Rebirth 30
at 28.5 h instead of 20.3 h (seeds 121–123, 40 h). Costs of ranks 3–49 were moved by
(gap before / gap now)^0.8, smoothed over five ranks, one iteration (`tools/sim/cost_fit.luau`),
then rounded to three digits inside the ratio bands (x3–20 to Rebirth 10, x1.1–3 after).
Rebirth 1, 2 and 50 are unchanged (50K, 1M, 3.13e15).

| Rebirth | 3 | 5 | 10 | 15 | 20 | 25 | 30 | 40 | 45 |
|---|---|---|---|---|---|---|---|---|---|
| Was | 20M | 8B | 4.7T | 39T | 71.2T | 152T | 384T | 1.18e15 | 1.92e15 |
| Now | 14.6M | 5.79B | 4.15T | 31.8T | 52.8T | 102T | 299T | 1.01e15 | 1.67e15 |

Confirmation with the committed code (fresh seeds; fast 131–134 for 40 h, 45 min a day
141–142 for 60 days):

| Rebirth | Target (fast) | Fast, Oct 21 | **Fast, now** | 45 min a day, Oct 21 | **45 min a day, now** |
|---|---|---|---|---|---|
| 1 | ~10 min | 10 min | 9–12 min | 8 min | 6–8 min |
| 2 | 18–20 min | 17 min | 18–20 min | 16 min | 17–18 min |
| 5 | ~55 min | 55 min | 60–70 min | day 1 | day 1 |
| 10 | ~2.9 h | 2.9 h | 3.0–3.2 h | day 2 | day 3 |
| 20 | ~11 h | 12.9 h | 12.0–13.9 h | day 11 | day 12 |
| 30 | ~21 h | 24.6 h | 21.9–26.6 h | day 18 | day 20–22 |
| 40 | – | 33.9 h (4 of 6) | 34–39 h (2 of 4) | day 27 | day 28–32 |
| 50 | ~40 h | 38.7 h (1 of 6) | – (0 of 4) | day 36–43 | day 41–45 |

Play time per Rebirth is within noise of the October 21 ladder (fast slightly slower to
Rebirth 10, the daily player now on the day-21 target for Rebirth 30). Coins in the first
hour arrive slower than on October 21 (fast, per minute: 8K–30K for 0–10 min, was 25K;
5.7M–12.7M for 10–30, was 26.6M; 176M–260M for 30–60, was 493M) because no Rebirth pays
a lump sum any more; the cheaper ranks make up the time.

Live: saved ranks and Gem levels keep their meaning; an unclaimed `timeSkipPending`
keeps the amount it was saved with. No `DataRevision` or `TreeMigrations` change.

## October 22: unlock-everything check

Stevin: "see how easy it is to unlock everything, I want to make sure it's easy but
challenging enough at the same time." Measured on the committed code (eb0dc28: Time Skip
head start, re-fit ladder) with `tools/sim/unlock_probe.luau`: fast nonstop seeds 201–203
(40 h), casual nonstop 211–212 (40 h), 2 h a day 231–232 and 45 min a day 221–223 (60
days). Medians; "(n/m)" = seeds that got there. The tree has 115 hexes worth 677B Coins
in all (612B of it is Luck I–XII, Mega Luck IV alone 400B); the Gem board has 78 levels
for 13,560 Gems.

| Milestone | Fast, nonstop | Casual, nonstop | 2 h a day | 45 min a day |
|---|---|---|---|---|
| Rebirth 1 / 2 | 10 / 18 min | 8 / 16 min | 8 / 17 min | 9 / 15 min |
| Rebirth 5 | 57 min | 66 min | 59 min | day 1 |
| Rebirth 10 | 2.7 h | 3.0 h | day 1 | day 3 |
| Rebirth 20 | 12.3 h | 11.7 h | day 6 | day 12 |
| Rebirth 30 | 23.8 h | 21.6 h | day 10 | day 25 |
| Rebirth 40 | 35.1 h (2/3) | 34.3 h | day 16 | day 39 |
| Rebirth 50 (max) | never in 40 h (ranks 37–47) | never in 40 h (41, 45) | day 21–27 | day 50–60+ (2/3) |
| Gem board complete | 31.9 h (1/3) | 35.6 h | day 16 | day 41 |
| All 3 camps / King | 12 / 18 min | 14 / 18 min | 12 / 18 min | 14 / 20 min |
| First Legendary owned | 16 min | 18 min | 22 min | 20 min |
| First Mythic owned | 44 min | 2.4 h | day 3 | day 12 |
| First Secret offer / owned | 49 min / 6.2 h | 79 min / 6.4 h | 60 min / day 2 | 29 min / day 3 |
| All 8 podiums | 27 min (R3) | 31 min (R3) | 26 min (R2) | 28 min (R3) |
| All 4 Mutations | 37 min (R3) | 35 min (R3) | 44 min (R4) | 45 min (R4) |
| Luck IV (x3) | 20 min (R2) | 23 min (R2) | 22 min (R2) | 20 min (R2) |
| Egg Speed IV / Egg Value IV | 35 / 46 min (R4) | 38 / 47 min (R4) | 41 / 49 min (R4) | 38 / 45 min (R3–4) |
| Super Luck IV (x5) | 90 min (R6) | 106 min (R6) | 94 min (R6) | day 1 (R6) |
| Flock Size 15 | 95 min (R7) | 98 min (R6) | 94 min (R6) | day 2 (R7) |
| Mega Luck IV (x10) | 3.8 h (R11) | 4.0 h (R11) | day 1 (R11) | day 4 (R11) |

Play minutes per Rebirth (median, longest in brackets): ranks 1–5 10 (32), 6–10 17–23
(58), 11–15 33–42 (60), 16–20 52–75 (94), 21–30 47–68 (112), 31–40 55–82 (118), 41–50
62–90 (126). The 2-hour player never has a day without a Rebirth; the 45-minute player
has 9–18 such days in 60, never two in a row.

### Inside a run: the whole tree against the end-of-run income

Income just before each reset (fast nonstop; the daily player is within 20%) and the
whole tree (677B) as minutes of it. The simulated player never buys the Tools, Player
and Army hexes (48 hexes, 62B; clicking is free in the model), so "hexes owned" tops out
at 66–67; the minutes column uses all 115.

| Rebirth | cost | income before reset | whole tree in minutes | hexes owned | play min this rank |
|---|---|---|---|---|---|
| 3 | 16.6M | 106K/s | 107K (never) | 33 | 7 |
| 5 | 5.81B | 7.76M/s | 1,450 (never) | 53 | 20 |
| 8 | 215B | 247M/s | 46 | 57 | 22 |
| 10 | 4.16T | 2.14B/s | 5 | 60 | 28 |
| 12 | 11.9T | 5.72B/s | 2 | 62 | 38 |
| 15 | 31.9T | 10.4B/s | 1 | 62 | 52 |
| 20 | 53.0T | 34.8B/s | 0.3 | 66 | 80 |
| 30 | 301T | 151B/s | 0.07 | 66 | 93 |
| 40 | 1.01Qa | 427B/s | 0.03 | 66 | 84 |
| 50 | 3.16Qa | 1.30T/s | 0.01 | 67 | 80 |

Feed Max Level III (2.5M) shows up late (R36–42) only because the model's payback rule
never values Feed levels past 10; it is affordable from Rebirth 3.

### Verdict

- **Rebirths 1–10 (first 3 h, day 3 for a daily player): easy but challenging.** Every
  big unlock has a wait and lands where the October 21 fits put it: all podiums and all
  four Mutations inside the first 40 minutes, Egg Speed/Value IV at 35–50 min, Super
  Luck IV and Flock 15 at about 1.5 h, Mega Luck IV at 3.8 h, the first Mythic at 44 min
  (fast) to day 12 (45 min a day), the first Secret at about 6 h. Until Rebirth 5 the
  whole tree is out of reach inside a run (a day of income); at Rebirth 8 it is an hour.
- **Rebirth 10 and up: easy and flat inside each run.** From Rebirth 10 the whole tree
  costs five minutes of the run's income, from Rebirth 20 under a minute, so each run
  rebuys everything in its first minutes (the cheap hexes at once, see "Time Skip head
  start") and then waits 50–90 minutes for the next Rebirth with only Gem cards left to
  buy (board done at Rebirth 41). The tree's prices are flat while the egg multiplier
  grows x1.06–1.7 a rank. The challenge that remains is the ladder itself.
- **The ladder is long but moving:** Rebirth 30 at 22–24 h nonstop, day 10 at 2 h a day,
  day 25 at 45 min a day; Rebirth 50 needs more than 40 h nonstop (every 40-hour seed
  ended at rank 37–47), day 21–27 at 2 h a day, day 50 to past day 60 at 45 min a day.

Lever, if the flat late runs should change (owner decision, not done): tree prices that
grow with Rebirth rank. `UpgradeCatalog.RankPriceGrowth` exists but is linear
(`1 + growth × rank`) and cannot follow a ladder that grows x1.1–x3 a rank; a per-rank
multiplier (about x1.15–1.25 a rank, so the whole tree stays near 20–30% of the next
Rebirth) would make each run spend its first half rebuying and its second half saving.
That moves the Rebirth times, so it needs the ladder re-fit (`cost_fit.luau`) and these
tables re-run. Leaving it as is keeps the reference's shape: late runs are a wait for
the Rebirth, not a shopping trip.

Also shipped the same day: the Rebirth screen shows abbreviated numbers (`UITheme.Number`:
50K, 1M, 14.6M … 3.13Qa; `Qa`/`Qi` suffixes added) on its Coins bar and in "Need … more
Coins" instead of full digits.

## October 22 later: tree prices stay flat (owner decision)

Stevin, on the lever above: "No, don't change the tree prices from Rebirths; the tree
prices should be the same all the time. It's just that the Rebirth doesn't give you any
Coins and resets your Coins." The challenge of a run is the Coins reset itself, not a
pricier tree.

What was tried and reverted the same day (commit ef14870, reverted by 2b78eef on the
side branch; nothing reached main): every tree price x1.2 a Rebirth rank from Rebirth 5
to 30 and x1.12 after (`UpgradeCatalog.PriceScale`), which kept the whole tree near a
fifth of the next Rebirth, with the ladder re-fit on top. Measured with the simulation
rebuying its tree each run (eight fast seeds, 40 h): Rebirth 10 / 20 / 30 at 2.8 / 12.8 /
24.2 h against 2.7 / 12.3 / 23.8 h on the morning build, casual 20.0 h at Rebirth 30, the
45-minute player's Rebirth 30 on day 24 (was 26). The rank-priced tree barely changed the
pacing because the Luck a run rebuys more than pays for itself; late runs still waited
most of the time, just with a longer shopping trip first. Do not propose a rank-priced
tree again; the knob `UpgradeCatalog.RankPriceGrowth` stays 0.

Kept from that work: `tools/sim/gaps.py`, `fit.py` and `report.py` (the ladder fit and
the unlock tables are reproducible from `cost_fit.luau` / `unlock_probe.luau` output).
The live economy is the morning build (Time Skip head start, the re-fit ladder above).

