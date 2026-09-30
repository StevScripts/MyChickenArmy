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
- Initial tuning: `ceil(RecruitPrice(species, currentLevel) * 0.75)`, controlled
  by `Config.Economy.ChickenUpgradeRecruitFraction` and
  `Rules.ChickenUpgradePrice`. Level-1 Common costs $1,800; Crystal costs $25,200.
  Quotes double each level with the existing recruit-price curve. This is an
  initial implementation balance, not a measured 8–9-hour progression result.
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
