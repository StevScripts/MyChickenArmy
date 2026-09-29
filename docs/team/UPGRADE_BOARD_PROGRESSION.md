# Upgrade board progression — independent design review

**September 29 supersedes the Roll Slot and seller portions of this historical
review:** seven purchases now unlock eight slots, with slot 6/7/8 at
$150M/$300M/$500M. The target is roughly 8–9 active F2P hours; see the
[current eight-podium contract](EIGHT_ROLL_PODIUMS.md). There are now 91 capped
cash purchases across these tracks. Timed processing and Selling Speed are
[archived](INSTANT_EGG_SALES.md). Prices, counts, luxury-goal advice and seller
assumptions below describe the September 27 review, not the current contract.

Date: September 27, 2026. Status: reviewed stat/slot changes and the subsequently
approved smaller starter plot/save conversion implemented locally and synced to
Studio; 31 focused isolated checks passed. No live-data conversion or publishing.
Root owns integration and verification below.

## Decision and implemented limits

The approved capped progression has **89 capped cash purchases**, plus the separately uncapped Selling Speed track. Counts do not establish completion time or retention.

| Track | Purchases | Endpoint / rule |
| --- | ---: | --- |
| Egg Speed | 25 | 4.75× production; additive +0.15× per level, preserving the existing first four benefits. |
| Egg Value | 25 | Shared unit value $4 → $29, +$1 per level. |
| Luck | 20 | 4× Rare+ weights: preserve levels 1–4 at 1.35/1.70/2.05/2.40×, then sixteen +0.10× increments. |
| Plot Size | 7 | New profiles start at 25 capacity; +5 each purchase, maximum 60. |
| Army Size | 7 | Three → ten base deployment slots; retain the separate paid +5 entitlement. |
| Roll Slots | 5 | One → six offers, subject to physically authored podiums. Late slots are luxury goals. |

All available cash upgrades remain purchasable when affordable, without camp, conquest, rank, King or rebirth prerequisites. Preserve server authority, ownership/proximity checks, stale-quote validation and physical limits. See [UPGRADE_RULES.md](../UPGRADE_RULES.md).

## Verified primary evidence

Sources were read during this review; current database observations and dated release notes describe different snapshots.

- [BIG Games upgrade database](https://db.biggames.io/wiki/upgrades): Luck has seven tiers totaling +50%, Coins eight totaling +54%, and Pet Damage seven totaling +55%. Supports finite purchasable stat tracks, but does not validate our exact caps, prices or much larger power gains.
- [Pet Simulator 99 Update 6 — February 24, 2024](https://www.biggames.io/post/pet-simulator-99-update-6): introduced five Mastery skills capped at level 99, separately from four new area upgrades and rank-based egg/pet slots. Its gated progression is a comparator, not permission to add gates here.
- [Update 7](https://www.biggames.io/post/pet-simulator-99-update-7): explicitly describes Mastery XP earned through fishing, fruit use and pet activities. XP levels are not equivalent to cash purchases or elapsed playtime.
- [Update 43 — January 18, 2025](https://www.biggames.io/post/pet-simulator-99-update-43): introduced rebirth without losing progress. Reset/prestige progression is a separate design choice; the name “rebirth” alone does not establish reset behavior or justify adding resets here.

These sources support the structural comparison only. They provide no evidence that 89 purchases create a particular number of hours or improve retention in My Chicken Army.

## Capacity, footprint and existing players

The approved start is 25 rather than 20 capacity to retain more room for matching merge inputs while adding three opening purchases. The user's smaller-plot direction includes the footprint.

Implemented eight horizontal scales:

`[0.8, 0.87, 0.94, 1, 1.05, 1.1, 1.15, 1.2]`

Existing plot levels 0/1/2/3/4 map to 3/4/5/6/7 once on load. Old capacity `40 + 5L` equals new capacity `25 + 5(L + 3)`, and the inserted scales preserve every existing footprint exactly. New profiles begin at level zero, 25 capacity and 0.8 scale. The maximum remains 60 capacity and 1.2 scale. Scale applies to both horizontal dimensions, not directly to area or capacity.

Read-only source inspection found:

- `PlayerSession.CollectionLimit` derives collection capacity from the plot level; saved `capacity` and `legacyCapacityGrant` concern deployed army capacity and must not be repurposed.
- `dataRevision` is now 11. Older revisions validate the old plot domain (0–4), then convert local values by +3. Only a fully valid profile commits/stamps revision 11. Fresh profiles receive revision 11 immediately; wallet size, flock size and zero upgrades never identify fresh players. Field layout and outer `schemaVersion=1` are unchanged. Existing DataService persists the converted snapshot through its normal locked load path.
- Preserve saved `rollSlotsUnlocked`, including the existing legacy fallback to six when the field is absent. Higher prices apply only to future purchases; do not revoke or recharge earned slots.
- `PlotUpgradeService` scales runtime yard art and updates movement/egg bounds. Smaller footprints need runtime checks for retained fixtures, movement and collection interactions.

Relevant implementation references: `src/server/PlayerSession.luau`, `src/server/DataService.luau`, `src/server/PlotUpgradeService.luau`, `src/shared/UpgradeCatalog.luau`, and `src/shared/Config.luau`. Studio source readback and isolated checks are recorded below; no live profiles were inspected or modified.

## Economy guardrails and risks

- Preserve early purchased benefits. In particular, uniformly changing Luck's current +0.35 weight increment to +0.15 would nerf existing levels. Four times Rare+ weights is not four times normalized probability; retain normalization and existing paid-benefit handling.
- Speed, Value and access to stronger producers compound. Seller congestion can hide that power temporarily; later Selling Speed purchases can expose it. Price against spendable earnings and competing purchases, not level count alone. The separate quantitative flock model is outside this review.
- Maintain existing earned egg/bag/queue values and paid entitlements. Newly purchased Egg Value levels must not reprice already-earned eggs. Follow [EGG_ECONOMY.md](../EGG_ECONOMY.md).
- Roll Slots should have sharply increasing late prices, while ordinary progression remains practical with fewer slots. Slot six offers only 20% more simultaneous offers than slot five, so an extreme price is a luxury objective, not a justified mandatory progression wall.
- Implemented prototype slot 2–6 prices: $1,200 / $4,800 / $120,000 / $6,000,000 / $600,000,000, with successive ratios 4× / 25× / 50× / 100×. These are locally chosen tuning values, not comparator-derived or gameplay-validated numbers.
- Preserve the independently approved uncapped Selling Speed contract in [UNBOUNDED_SELLING_SPEED.md](UNBOUNDED_SELLING_SPEED.md). More levels are not automatically more content; if pacing fails, consider adjusted prices or smaller later benefits before expanding multiplier ceilings.
- Migration is idempotent in isolated checks. Before publishing, retire old server versions: they may reject revision 11 or converted levels. A rollback to old code also needs revision-aware handling. This task does not publish, restart live servers or migrate live data.

## Quantitative review and implemented scope

Three agents reviewed progression design, economy arithmetic and code/save
compatibility. Verdict: proceed as prototype tuning, not validated session pacing.
Root retained the simpler +0.10 Luck extension instead of the economy agent's
optional quadratic taper: both reach 4×, but the linear continuation is easier to
understand and tune. All early purchased bonuses are preserved.

Implemented now (89 purchases, including seven plot purchases):

- Egg Speed / Egg Value: 25 purchases each. First four prices remain
  $2,880 / $63,000 / $725,760 / $3,628,800. Later purchase `n` costs
  `1000 * ceil(3628800 * 1.35^(n - 4) / 1000)`.
- Luck: 20 purchases. First four prices remain
  $1,920 / $42,000 / $483,840 / $2,419,200. Later purchase `n` costs
  `1000 * ceil(2419200 * 1.25^(n - 4) / 1000)`.
- Roll Slots: $1,200 / $4,800 / $120,000 / $6,000,000 / $600,000,000.
  Existing slots remain owned. Ratios are 4× / 25× / 50× / 100×.
- Army, physical maxima, receipts, paid benefits and Selling Speed are unchanged.
- Board plot preview now shows actual capacity instead of an abstract level.
  Army Info invalidates its cached view when home egg production changes.
- New plots start at 25 capacity / 0.8 scale. Seven purchases reach 60 / 1.2;
  old levels gain three credited opening levels through the revision-11 conversion.

| Purchase | Speed or Value, each | Luck |
| ---: | ---: | ---: |
| 5 | $4,899,000 | $3,024,000 |
| 10 | $21,967,000 | $9,229,000 |
| 15 | $98,500,000 | $28,164,000 |
| 20 | $441,676,000 | $85,948,000 |
| 25 | $1,980,488,000 | MAX |

Model assumptions: every chicken is home, no paid benefits, frequent collection,
deposit and cash claims, enough seller capacity, and no concurrent spending.
These are illustrative flocks, not measured player cohorts or predicted sessions.

| Example flock | Speed / Value level | Eggs/s | Sustainable cash/s | Seller level needed |
| --- | ---: | ---: | ---: | ---: |
| Starter flock | 0 / 0 | 4 | $16 | 0 |
| 25 level-1 Robo-Clucks | 4 / 4 | 280 | $2,240 | 4 |
| 40 level-3 Magma Chickens | 10 / 10 | 9,600 | $134,400 | 7 |
| 60 level-5 Shadow Stalkers | 25 / 25 | 182,400 | $5,289,600 | 17 |

At maximum Speed/Value, the same flock has 10.76× the production value of the
old maximum. With the other stat already at the target level and seller headroom,
purchase 10's incremental payback is approximately 45.4 minutes (Speed) or 38.1
minutes (Value) for the mid example. Purchase 25 takes approximately 3.29 / 3.02
hours to repay its marginal cost for the late example. Payback is not purchase
wait time. If processing is saturated, extra Speed adds backlog rather than
sustainable spendable cash; Value benefits arrive as newly valued eggs clear.

The sixth slot costs 74.4 minutes of mid-example earnings but only 1.89 minutes
of late-example earnings. It is not an everlasting cash sink. At the theoretical
60 maximum-level Galaxy flock, seller affordability and the pre-existing 1e12
bag/queue-value limits become separate concerns; no precision/queue overhaul was
silently included in this task.

Implemented first three plot prices are $480 / $1,200 / $2,400, followed by the
existing four. This preserves existing next quotes after a +3 level conversion.
Those three purchases total $4,080: with the starting $2,400 wallet and $16/s,
only 105 seconds of extra income is needed if all cash is directed there. Smaller
starting capacity creates more expansion choices, not guaranteed long playtime.
The user subsequently approved this conversion and it is implemented.

## Integration and checks

**Pending before a production release:** old-server rollout coordination and actual
gameplay/spatial/device observation. No live-profile or old-server rollout is included.

The design agent wrote only the initial report. Root implemented Config,
UpgradeCatalog, Rules, UpgradeService and a one-line ChickenBrowser refresh fix,
then Config/UpgradeCatalog/PlayerSession for the approved plot conversion.
The existing Rojo connection synced mapped sources; no mapped source was written
through Studio MCP. Readback matches all source hashes in the scoped inventory;
the five original and three plot-conversion runtime modules compiled in their
respective verification passes. Rojo packaging and Git whitespace
checks pass. These checks do not establish gameplay, device or pacing correctness.

An old 2,659-byte PlotUpgradeService duplicate was moved intact to
`ServerStorage.UpgradeBoardRecovery20260927.PlotUpgradeService`; its disk copy is
`assets/upgrade-board-progression-20260927/stale-PlotUpgradeService.luau`.
The duplicate reappeared after the earlier pass, with the recovery folder absent;
the cause was not established. It was moved intact again in the reconnected Edit
instance. Repeated readback found one active 3,888-byte source matching disk and no
source divergence. Nothing was deleted, and the backup is recoverable. No authored
map geometry was changed; scaling happens on disposable runtime yards.

All 18 groups in `tests/UpgradeBoardProgressionChecks.luau` passed with fake
sessions and services: opening benefits/prices, capped purchases, no-camp offers,
readiness/access/affordability/stale-quote/replay rejection, authored slot limits,
legacy menu owners, normalized Luck/actual draws/display agreement, verified paid
benefits, maximum save roundtrips, invalid levels, retained earned egg values,
exact continuation prices, and legacy missing-field compatibility. Five added groups
cover new 25→60 purchases, old revisions 6–10 at all five old plot levels including
60 owned chickens, idempotent conversion, invalid/late-failure atomic rejection,
the actual DataService load path with an in-memory store, and detached synthetic
yard scaling/bounds without cumulative shrink. The test does
not exercise real world proximity or rendered UI. The unchanged processor fixture
also passed all 13 groups; no real commerce endpoints or profiles were involved.
Original results: `assets/upgrade-board-progression-20260927/check-results.json`.
Post-conversion results: `assets/upgrade-board-progression-20260927/plot-migration-check-results.json`.

The existing runtime source/table and server-validation patterns were retained;
the data-safety workflow kept the conversion within the existing save owner and
validated the complete payload before committing. It was implemented only after
the user's explicit go-ahead.
The UI guide informed the small capacity-caption/cache updates without restyling
the board or modifying shared art. The review does not establish the duration of
the full acquisition/merge loop or performance at the theoretical maximum flock.

No real profiles, purchases, Play/Stop, Roblox save/publish or Git commit/push.
