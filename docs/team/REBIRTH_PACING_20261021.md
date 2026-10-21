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
