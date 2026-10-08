# Chicken cash upgrades — September 29, 2026

The approved simplified Army inspector is implemented from [Figma frame
456:3625](https://www.figma.com/design/4lJjZOqNhR8K7rfMbVIjaK/my-chicken-army?node-id=456-3625).
It shows a plain name and rarity/level, the existing outlined portrait, one
DPS/eggs-per-second line, a cyan Upgrade button with the exact cash quote, and
Equip/Sell on one row. The shared approved stud sheet remains the only stud art.
Narrow screens retain the existing separate inspector/back-to-flock flow.

The user explicitly chose **Army UI + cash upgrades; keep current fusion for now**.
The conceptual level-10 Giant-chance hint and $12,500 sample were placeholders.
Runtime copy describes the available matching-triple fusion, or the cash upgrade
benefit when this chicken is above the current merge cap. No new Giant chance,
input consumption rule, machine fee or saved size change is introduced.

## Purchase contract

- Buy one level at a time, up to the existing level 10 maximum, with no camp,
  rank or King prerequisite. The owned chicken must be home and not an active
  defender. Equipped home chickens and favorites can be upgraded.
- October 8 price: `ceil(RecruitPrice(species, currentLevel) * 0.75 * 2.5^(currentLevel-1))`,
  i.e. `Config.Economy.ChickenUpgradeRecruitFraction` times
  `Rules.ChickenUpgradeGrowth` (2.5) in `Rules.ChickenUpgradePrice`. Each quote is
  5x the previous one. Common (Chicken): $1,800 / $9,000 / $45,000 / $225,000 ...
  9→10 $703M. Galaxy Overlord: $216,000 for 1→2, $84.4B for 9→10 (full 1→10
  investment about $105B, under the 1e12 saved-investment bound). Level 1→2 is
  unchanged; the September 29 flat quote (doubling per level) paid back in a
  constant 450 seconds at base egg value, about 10 seconds with upgrades, and ran
  away. Server quote and Army display both read `Rules.ChickenUpgradePrice`.
- Preserve the existing level rewards: egg production doubles and combat gains
  another 25% of base per level. Cash leveling does not grant or reroll Giant size.
- `UpgradeChicken` sends only the owned ID, expected current level and expected
  price. `GameServer` routes it to `ArmyService.UpgradeChicken`, which rechecks
  profile readiness, ownership, home/defense state, cap, quote, cash and saved
  investment bounds before a non-yielding deduction and level change.
- Stale/replayed requests cannot charge twice. The client waits for the result,
  disables purchases while pending or unaffordable, and refreshes from snapshots.
- Add the actual paid price to that chicken's saved investment. Existing 50%
  refund rules, zero-investment starter birds, favorites and earned sizes remain
  compatible. `Rules.UpgradePrice` remains frozen historical refund reconstruction;
  it is deliberately separate from today's purchase quote. No save schema changes.

## Checks completed

- Rojo packaging build and whitespace/diff check.
- Eight `ChickenCashUpgradeChecks` passed in Studio using disposable profiles:
  all nine purchases without conquest; stale/malformed/replayed quotes;
  insufficient cash and unsafe save state; away/defense eligibility; save roundtrip
  with Colossal size and favorites; actual investment/refunds and overflow;
  snapshot/stat changes; cash-upgraded matching-triple fusion.
- Live Army button click through the real remote upgraded a Common from level 1
  to 2, deducted $1,800, recorded $1,800 investment / $900 refund, doubled its egg
  rate and displayed the next $3,600 quote. Session status was `studio-session`.
- Desktop screenshot and compact portrait/landscape fixtures using the production
  browser constructor. Fixed the desktop breakpoint to follow AppController's
  fitted Army window, so scaled desktop footers remain visible.

The existing `PetRollPlaytestSessionOnly=true` flag protected saved player data.
No Roblox publication, asset upload, Git commit or push was performed.

Cash leveling and the separately added 100-chicken yard affect earning pace.
The earlier eight-podium timing model predates both and must be rerun before
claiming that the combined economy still reaches eight slots in 8–9 hours.

## October 8 progression model

A greedy free-player model ($TMPDIR economy script built from Config, UpgradeCatalog,
ChickenLuck bands, RecruitPrice/RecruitLevel and ResearchCatalog; 90 active minutes
on day 1, 60 per later day, 2% offline for 8 hours) gave:

| Milestone | Flat quote (before) | 2.5x growth (after) |
| --- | --- | --- |
| 1 hour | $607/s, three Chickens at level 6 | $350/s, 13 recruits at level 2 |
| Day 1 end | $20.8K/s, three level-10s | $14K/s, 50 chickens, best level 3 |
| Day 2 end | $712M/s, everything maxed | $59M/s, best level 7 |
| Day 3 end | $712M/s | $302M/s, no level 10 yet |
| Day 5 / 7 | $712M/s | $697M/s (44 level-10s) / $1.0B/s |
| All six cash tracks maxed | day 2, about 2.1 active hours | day 3, about 2.5–3.2 active hours |

The level price alone cannot hold cash-track maxing to day 4–7: recruits keep a
constant 600-second base payback that Egg Speed/Value divide by up to about 47x,
and the 16.6B of cash-track prices are small next to that income. Even with no
leveling at all the model maxes them on day 6. A model run with Egg Speed/Value
continuation growth raised from 1.35 to 1.6 (`Config.Economy.IncomePriceGrowth`,
applied October 8 with the owner's approval) plus this level price maxed them on day 5–6. Treat these as model
results, not measured play.

