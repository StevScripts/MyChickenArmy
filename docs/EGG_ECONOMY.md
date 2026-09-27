# Egg quantity and shared value

Current user direction, September 26, 2026: stronger chickens produce **more
eggs**, never a more valuable species of egg. This supersedes the earlier
equal-cadence, variable-value economy and its rarity-colored egg feedback.

## Production

`Rules.EggRate` converts the established catalog cash/sec balance into eggs/sec
by dividing by the shared $4 base value. Existing level and star multipliers
apply to quantity. Egg Speed and Double Egg Spawn multiply quantity; Egg Value
does not. Only physically home chickens produce eggs.

| Example | Eggs/sec, level 1, no speed upgrades | Base value of each egg |
| --- | ---: | ---: |
| Chicken | 1 | $4 |
| Brown Chicken | 2 | $4 |
| Robo-Cluck | 7 | $4 |
| Magma Chicken | 24 | $4 |
| Golden Emperor | 67 | $4 |
| Galaxy Overlord | 120 | $4 |

A level-2 Galaxy produces 240 eggs/sec before speed benefits. Egg Value levels
0–4 set every newly completed egg to $4/$5/$6/$7/$8. The existing Double Cash
pass remains a separate payout multiplier applied once, not a species-specific
egg value. Current cash production potential is unchanged across all 32 species,
ten levels and five Egg Value levels. Actual wallet earnings remain limited by
collection, selling and cash collection.

The approved merge rule remains three matching inputs into one next-level bird.
The output produces twice one input's eggs, so the combined flock loses one-third
of those three birds' production. Combat, merge caps, prices and investments are
unchanged. Merge comparisons show **per-chicken Eggs/s**, not flock totals.

## Quantity and visuals

The server accumulates fractional egg progress, completes whole eggs and stores
their exact count and value. Slow frames catch up arithmetically; no loop or
Instance is created per logical egg. Speed changes and time away preserve partial
egg progress without multiplying earlier production.

Each on-ground sprite represents a counted stack. Visual batches are emitted no
more often than every 0.25 seconds per chicken, with the existing five-stack
per-chicken and 80-drop per-yard limits. Full yards add quantity/value to an
unclaimed stack. If all stacks are in flight, completed eggs wait in the layer.
Claims freeze the stack, and player/vacuum receipts carry the full quantity.

Every sprite uses the same approved egg image and neutral color; nearby captions
show egg counts. Bag/pickup worth still means the total stack's earned value.
Recruit messages, the army home-flock footer and merge preview show eggs/sec.
Egg Speed offers show a production multiplier; Egg Value offers show unit cash.

Roblox's [performance guidance](https://create.roblox.com/docs/performance-optimization/improve)
advises limiting excessive object density and unnecessary replication, and keeping
cosmetic visuals local. Counted stacks follow that approach. The 80-visual cap
is an implementation bound, not a measured mobile frame-rate guarantee.

## Selling and offline cash

Initial quantity-economy seller tiers: **4 / 16 / 64 / 256 / 1,024 eggs/sec**.
The four existing prices remain **480 / 2,400 / 9,600 / 28,800**. Double Egg Spawn
continues doubling seller throughput. No cash upgrade requires camp progress.
The starter flock produces 4/sec; one unupgraded Galaxy fits tier 3 (256/sec).

Large merged flocks can still exceed the final seller tier. For example, ten
level-1 Galaxies produce 1,200/sec before speed upgrades. This is an explicit
remaining balance constraint, not lost production: excess eggs queue. A final
seller progression curve needs gameplay observation rather than being inferred
from the old egg counts. Plots without an authored seller board retain their
existing instant-sale behavior, another existing economy asymmetry.

Offline cash now uses `min(total owned eggs/sec, seller eggs/sec) × unit value`,
then the existing payout benefit and 2% efficiency. Eight-hour and wallet caps
are unchanged. Offline state does not create eggs or process saved queues.

## Earned balances and compatibility

Previously laid, carried and queued eggs retain their already-earned value,
including old high-value eggs and eggs completed before an Egg Value purchase.
They are never repriced on upgrade, deposit or load. This is a deliberate legacy
balance exception; all new eggs at the same upgrade level share one unit value.
Mixed deposit batches may contain eggs earned at different times.

No schema change, data wipe or live-profile migration is required. Existing
`{count,value}` bags and bounded seller batches remain readable. Ready cash,
Finish Now receipt handling and deferred finish credits are preserved. A saved
offline checkpoint pays its already-recorded rate once; subsequent checkpoints
use the new quantity-based calculation.

## Evidence

Fourteen isolated Edit check groups passed using the actual sources and fake
sessions/worlds. They cover the balance matrix, uniform values, slow frames,
60 maximum-level birds with exact millions of eggs and at most 80 visuals,
away/speed changes, old value retention, claimed stacks, manual/vacuum transfer,
seller conservation/compaction/finish credits, one-time paid payout, profile
roundtrip, offline throughput, merge/snapshot rates and ungated upgrade previews.

All 22 fixture dependencies/changed sources compiled; Rojo packaging and Git
whitespace checks passed. This is not a visual gameplay or device performance
test. Source, fixtures and results: `assets/egg-quantity-20260926/`.
Studio source integration and duplicate recovery: [task record](team/EGG_QUANTITY.md).
