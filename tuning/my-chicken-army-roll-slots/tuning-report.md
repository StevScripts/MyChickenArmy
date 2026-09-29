# Eight podiums: active F2P pacing, September 29, 2026

The user wants all eight slots attainable in roughly 8–9 total active hours and
finds the former $600M sixth slot too expensive. The implemented shared catalog
keeps slots 2–5 at $1,200 / $4,800 / $120K / $6M, reduces slot 6 to $150M and adds
slots 7/8 at $300M/$500M. Total slot spending is $956,126,000. Prices are fixed;
there is no elapsed-time gate, paid prerequisite or camp restriction.

Configuration owner: `src/shared/UpgradeCatalog.luau`, `RollSlotPrices`.
The existing game configuration is updated directly; no second Settings module
is introduced. Engine/save/podium behavior is documented in
[`EIGHT_ROLL_PODIUMS.md`](../../docs/team/EIGHT_ROLL_PODIUMS.md).

## Model and limits

`assets/eight-roll-podiums-20260929/economy-inputs.json` exports current Luau
species, recruiting costs, normalized Luck odds, egg rates and upgrade costs.
Its old `slotPrices` field records the pre-tuning snapshot; each experiment
supplies its own seven-price ladder. `pacing.py` runs ten-second steps with seeded
rolls. It buys the initial discounted $600 chicken, fills available collection
capacity and replaces weak reserves only for at least 50% more base income.
Replacements receive the existing 50% resale value. It buys plot expansions,
compares marginal Egg Speed/Value payback and buys Luck when its growth budget
has at least three times the price. All modeled recruits stay level one.

A configurable share of each deposit is reserved for slots; the remainder funds
that reinvestment. This is an assumed spending policy, not a new game wallet.
Eligible egg production is collected in full at each modeled deposit. A fixed
home-production fraction approximates time away from the plot. Travel, bag/yard
pickup execution, player mistakes, merging, army upgrade spending and combat
rewards are not simulated. Paid benefits, cash packs and offline income are zero.
Results assume a plot with all eight anchors; the current Plot1 satisfies that,
while Plots2–6 each still have one.

## Results

All 48 seeds completed in each policy (144 total). These policies are sensitivity
examples, not measured cohorts or a probability distribution over real players.
The prices were selected against the reference policy, so its result is a fitted
estimate; variation across its seeds measures roll luck, not human uncertainty.

| Policy | Roll / deposit interval | Slot savings / home production | Median hours | 10th–90th percentile |
| --- | --- | --- | ---: | --- |
| Reference | 20s / 60s | 25% / 80% | 8.47 | 8.07–8.78 |
| Focused | 10s / 30s | 35% / 100% | 5.75 | 5.56–5.95 |
| Relaxed | 30s / 90s | 20% / 70% | 10.90 | 10.55–11.45 |

Reference median slot 5/6/7/8 milestones are 1.90 / 4.41 / 6.41 / 8.47 active hours.
The later costs spread slot spending across three milestones. After instant
selling, income upgrades and stronger flocks compound, so a late $500M purchase
can be more reachable than an earlier $600M purchase. This does not establish
that actual players earn the modeled income. Underinvestment, combat/fusion
spending or slower collection can move completion later; optimization and other
income can move it earlier. Real F2P sessions must calibrate this first pass.

Reproduce from the repository root:

```sh
python3 assets/eight-roll-podiums-20260929/pacing.py --seeds 48 --output assets/eight-roll-podiums-20260929/pacing-final.json
```

The result file stores prices, policies, seeds, milestones, spending and half-hour
snapshots. Eighteen isolated current upgrade checks passed, covering purchases,
replay/stale-price rejection, affordability, physical limits and save compatibility.
They do not validate human playtime. Rojo packaging also passed. No Play/Stop,
real-profile write or publish was performed. See the
[follow-up measurement plan](ab-test-plan.md); it has not been activated.
