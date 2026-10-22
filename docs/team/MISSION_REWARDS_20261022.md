# Mission rewards: a share of the next Rebirth (October 22, 2026)

**Report (tester, through Stevin):** the random Mission sites "give a CRAZY amount of
money"; finishing one attack was enough to Rebirth.

## What happened

`OperationService.Reward` paid `max(replayCash, 8–15 minutes of egg income)`, doubled on
gold sites, then `EarnedAmount("battle")`. Three problems:

1. **The floor was from the October 8 cash economy.** `replayCash` was 250K / 750K / 1.5M
   (Veteran), 2.5M–15M (Elite) and 25M–250M (Royal); the no-site fallback even paid
   `firstCash` (2.5M for Scout Landing). The October 21 ladder costs 50K for Rebirth 1 and
   1M for Rebirth 2, so the cheapest Veteran site paid five Rebirths after a King clear, and
   Veteran Assault paid Rebirth 2 outright (3M on a gold site).
2. **Minutes of end-of-run income are too big as well.** A run multiplies income about
   x1000, so the next Rebirth costs only 2–30 minutes of the income the player has right
   before it (the pacing simulation's "income before reset" rows). Eight minutes of that
   income is often more than the Rebirth. The same reasoning retired the end-of-run Time
   Skip on October 22.
3. The 2x Coins pass was counted twice: `DailyService.Income` already includes it, and the
   payout went through `EarnedAmount("battle")`, which applies it again.

## The rule now

`OperationCatalog.Reward(id, incomePerSecond, nextRebirthCost, rare)`:

```
reward = floor(min(income × RewardMinutes[tier] × 60, RebirthShare[tier] × nextRebirthCost))
gold sites × 2
RewardMinutes = {8, 12, 15}      RebirthShare = {0.03, 0.04, 0.05}
```

- `income` is the steady egg income (Rebirth multiplier and Coin Boost in, 2x Coins out).
- `nextRebirthCost` is `RebirthService.Cost(rank + 1)`; at the top rank, the last cost.
- 2x Coins, Gold Rush and Friend Boost apply once afterwards, when the Coins are paid
  (`EarnedAmount("battle")`), as for every battle.
- Early in a run the minutes bind (a head start like the Time Skip); late in a run the share
  binds, so one site is never more than 3–5% of the next Rebirth (a gold Royal 10%).
- The no-site fallback in `Resolve` pays the same formula; `firstCash` / `replayCash` are
  removed from the catalog. The hidden legacy Missions screens show "3% of a Rebirth".
- `tests/ProgressionSimulation` pays `OperationService.Reward` (it used the fixed amounts
  before); `tests/RebirthV2Checks` covers the formula, the cap at every rank and the pass.

## Numbers

At the end of a run (income before the reset from `REBIRTH_PACING_20261021.md`):

| Rank → next | next cost | income | old payout (Veteran, 8 min, floored) | now (3%) |
|---|---|---|---|---|
| 0 → 1 (King cleared) | 50K | ~1K/s | 480K (floor 250K) ≈ 10 Rebirths | 1.5K |
| 2 → 3 | 14.6M | 106K/s | 51M ≈ 3.5 Rebirths | 438K |
| 4 → 5 | 5.79B | 7.76M/s | 3.7B ≈ 0.6 Rebirths | 174M |
| 9 → 10 | 4.15T | 2.14B/s | 1.0T ≈ 0.25 Rebirths | 125B |

Right after a Rebirth the minutes bind instead: 8–15 minutes of the fresh income.

## Levers

`OperationCatalog.RewardMinutes` and `OperationCatalog.RebirthShare`. Re-run the simulation
(`tools/sim/README.md`) before moving them; a share of 10% would let a chain of Royal sites
match the egg economy's pace rank for rank.

## Simulation (October 22, `tests/ProgressionSimulation` headless, 10 h, before vs after)

The simulated player attacks a Mission when its payout beats the squad's laying while away
(150 s). Before, replays never paid (fixed amounts), so Missions were 1–3B of 300–600T
earned. Now they are 70–130T of 500–600T (8 first clears, 47–74 replays in 10 h): about
one Mission every 7–12 minutes late in the run.

| | fast seeds 1–3 (played min) | casual seeds 11–12 |
|---|---|---|
| Rebirth 5 | 59 / 55 / 55 → 56 / 58 / 51 | 63 / 70 → 63 / 68 |
| Rebirth 10 | 170 / 161 / 183 → 169 / 160 / 166 | 159 / 186 → 158 / 185 |
| Rebirth 15 | 376 / 365 / 413 → 336 / 320 / 330 | 334 / 385 → 314 / 330 |
| Rebirth 18 | 577 / 555 / – → 524 / 500 / 509 | 495 / – → 510 / 539 |

Ranks 1–10 are unchanged; ranks 11–18 come 5–20% sooner because a Royal or Veteran replay
now adds 3–5% of the next Rebirth each. The largest single payout in every run was exactly
5% of the next Rebirth (Royal Vanguard at rank 15); a first payout per rank was 3–280 s of
the income at that moment. Still "more, not harder": the egg path is untouched, Missions
are a bonus for a player who keeps the army busy. If that bonus should be smaller, lower
`RebirthShare` (2%/3%/4% roughly halves it).
