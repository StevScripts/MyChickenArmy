# Gradual Selling Speed — September 28, 2026

**Archived September 29:** deposits now sell instantly. Preserve this curve only for
restoration; see [the current contract](INSTANT_EGG_SALES.md).

The user rejected upgrades that repeatedly multiply total processing speed by
two or four. They requested Chicken Farm's small early additions that become
larger over time, while retaining exponential value/price growth. This task
interprets value as upgrade price; the separate Egg Value production track is
unchanged. This direction supersedes the September 27 opening tiers and pricing
in [UNBOUNDED_SELLING_SPEED.md](UNBOUNDED_SELLING_SPEED.md).

## Reference evidence and limits

Direct gameplay inspected, rather than treating fan-wiki descriptions as a formula:

- [Radex Tips, beginner guide, 1:15](https://www.youtube.com/watch?v=vKmP8yy30S0&t=75s): processor at 3 eggs/sec, next purchase +1 eggs/sec, $16.
- [LeoGameLab, progression video, 0:45](https://www.youtube.com/watch?v=9u5D2ahrGcU&t=45s): processor at 5 eggs/sec, next purchase +2 eggs/sec, $10.
- [Pumpkin Pie, money guide, 1:15](https://www.youtube.com/watch?v=qeLlzbiUzFA&t=75s): processor at 9.83M eggs/sec, next purchase +500.4K eggs/sec, $102.83M.

These observations establish the requested small-addition presentation and later
growth, not a complete formula. Versions, boosts and progression differ between
videos. No verified developer formula was found. The following parameters are
My Chicken Army tuning, **not a claimed exact Chicken Farm formula**. A request
for the user's specific reference link remained unanswered during implementation.

## Implemented curve

`src/shared/EggProcessorConfig.luau` remains the sole tuning owner. Base throughput
is 4 eggs/sec. At current level L, a purchase adds `round(1.10^L)` whole eggs/sec.
Each gain is rounded individually, so gains never shrink and every purchase adds
at least one. Price is `ceil(40 * 1.20^L)`, ignoring sub-coin floating-point noise.
Prices compound faster than the unrounded added capacity. Both curves replace the
old large opening purchases; no camp, rebirth or rank requirement is added.

| Current level | Eggs/sec | Next purchase |
| ---: | ---: | ---: |
| 0 | 4 | $40 for +1 |
| 1 | 5 | $48 for +1 |
| 2 | 6 | $58 for +1 |
| 3 | 7 | $70 for +1 |
| 4 | 8 | $83 for +1 |
| 5 | 9 | $100 for +2 |
| 10 | 19 | $248 |
| 20 | 61 | $1,534 |
| 30 | 168 | $9,496 |
| 50 | 1,166 | $364,018 |
| 100 | 137,798 | $3,312,718,981 |

There is no authored Selling Speed maximum. The first unrepresentable quote is
now current level 182, under the unchanged `CurrencyLimits.MaxCoins = 2^53 - 1`.
Every purchasable level is cached once when the config loads. Beyond that wallet
boundary, a quadratic continuation keeps unusually high legacy saved levels
finite and increasing, without running a loop or exponentiating their enormous
level on each tick. It is numerical fallback behavior, not a sold tier or speed
cap. The existing `Currency limit` unavailable-price caption remains accurate.

## Compatibility and scope

Saved level numbers remain unchanged and now resolve to the revised speeds.
This deliberately rebalances the benefit of existing levels; it does not preserve
the old 4× throughput at those levels. No level conversion, refund, schema change,
data wipe or live-profile migration was performed. Chickens, wallet balances,
queued/carried egg counts and their already-earned values, ready cash, fractional
progress and Finish Now credits remain intact. Double Egg Spawn still doubles
throughput. Offline capacity uses the same new rate; already-recorded offline
checkpoints retain their saved rate. Cash-pad behavior and other upgrade tracks
are unchanged. No UI art or Studio-owned geometry changed.

The initial $40 price replaces the prior $480 purchase because it now buys +1
egg/sec instead of +12. This is a pacing choice, not a price observed in Chicken
Farm. Small steps and compounding prices alone do not establish balanced pacing.

## Verification

All 13 isolated groups in `tests/EggProcessorContinuationChecks.luau` passed in
Studio Edit with fake sessions and services. They cover small whole-egg gains,
quotes and currency boundaries, repeated purchases, stale/invalid transactions,
saved levels including extreme values, queued-value conservation, Finish credits,
offline throughput and paid multipliers, high wallets and protected paid grants.
All 19 fixture dependency sources matched disk byte-for-byte. Same-named copies
encountered by the fixture were required to agree; no unrelated copy was edited.

Rojo synced the changed config into Pet Roll Test, place 96683186622050,
instance `9wo-7nm`, in Edit. Packaging and Git whitespace checks passed. Evidence:
`assets/gradual-selling-speed-20260928/check-results.json`. No Play/Stop, actual
player purchase, saved-profile change, Roblox save/publish or Git commit/push.
Fresh Play loads the new curve. Gameplay pacing has not been playtested.
