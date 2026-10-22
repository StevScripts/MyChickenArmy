# October 20 overhaul: shared contract (S7)

Owner: session S7 "Economy core (server)", branch `oct20/s7-economy-core`.
Decisions: [OVERHAUL_PLAN_20261020.md](OVERHAUL_PLAN_20261020.md). Stevin confirmed
S7's plan and the old-save mapping (section 9) on October 20, 2026.
Checks for sections 4–9: `tests/RebirthV2Checks.luau`
(`require(game.ServerStorage.PetRollTests.RebirthV2Checks).Run()`).

S8–S13 build against this file. Ids, request names, saved keys and snapshot keys
below are fixed. **Numbers are drafts** until the P0 cost fit lands (section 10):
always read prices, values and odds from the shared catalogs or the snapshot,
never from this page or hard-coded copies.

Rules for everyone:
- The server decides prices, balances and effects. Clients never compute a price;
  they show `state.upgradeTree.nodes[id].price`, `state.gemUpgrades.items[id].price`
  and `state.rebirth.*`. Static text, icons and layout come from the shared catalogs.
- S7 owns the save schema (`PlayerSession:ToData`/`LoadData`, `DataService`). Other
  sessions read and write the **in-memory** fields named in section 2; S7 persists
  them. Need a new saved key? Message S7 (or the lead after S7 hands off).
- `session.researchEffects` keeps its name. It is now the one effect table for the
  Upgrades tree and Gem Upgrades together (section 5). Read keys from it; never
  write to it. S7 recomputes it after every purchase, load and Rebirth.
- A key marked "S10 fills", "S11 fills" or "S12 fills" is reserved here; that
  session owns the producing code and may add fields inside its own table.

## 1. Modules

| Module | Owner | What it holds |
|---|---|---|
| `src/shared/UpgradeCatalog.luau` | S7 | The tree: families, tiers, nodes, layout, `ValueText`, `Effects` |
| `src/shared/GemUpgradeCatalog.luau` (new) | S7 | The 14 Gem Upgrades |
| `src/shared/PetCatalog.luau` | S7 (Rebirth chickens block) | `Veteran1`…`Veteran30`, `Catalog.RebirthOrder` |
| `src/shared/MutationCatalog.luau` | S7 | Unlock ranks 0/1/5/10; `Roll(rng, rank, chanceMultiplier?)` |
| `src/server/UpgradeService.luau` | S7 | Instant tree buys |
| `src/server/GemUpgradeService.luau` (new) | S7 | Gem buys, Auto Rebirth toggle, Gem snapshot |
| `src/server/RebirthService.luau` | S7 | Quote, reset manifest, rewards, Skip credits, Auto Rebirth, enemy scale |
| `src/server/RebirthChickens.luau` (new) | S7 | Grants, credits, `MaybeReplace` podium hook |
| `src/server/EconomyMigration.luau` (new) | S7 | One-time conversion of revision ≤ 11 saves |
| `ResearchCatalog` / `ResearchRules` / `ResearchService` | S7 | Kept only to read old saves (and `research.operationWins`, `rallyReadyAt`, formations). No new research. |

## 2. Saved fields (DataRevision 12)

`Config.DataRevision` goes 11 → 12. A revision ≤ 11 save is converted once on load
(section 9); an old server refuses a revision-12 save instead of overwriting it.
Every field is lenient: missing means the default, bad values are clamped or
dropped, and nothing here can fail a load.

| Saved key = in-memory `session.<key>` | Type, default | Writer | Resets on Rebirth |
|---|---|---|---|
| `upgradeTree` | `{[family]: tier}`, `{}` | S7 | Yes (Keep Upgrades keeps up to N tiers of EggSpeed, EggValue, Luck) |
| `gems` | integer ≥ 0, `0` | S7 | No |
| `gemsEarned` | integer, lifetime Gems | S7 | No |
| `gemUpgrades` | `{[upgradeId]: level}`, `{}` | S7 | No |
| `autoRebirth` | boolean, `true` | S7 (toggle) | No |
| `rebirthSkips` | integer Skip credits, `0` | S7 | Spent by a Skip Rebirth |
| `rebirthChickenCredits` | `{speciesId}` waiting for storage room, `{}` | S7 | No |
| `passGemGifts` | `{[passKey]: true}`, `{}` | S7 | No |
| `missionTierLegacy` | 0–3, `0` | S7 (migration) | No |
| `flockSelection` | `nil` = automatic, or `{petId}` manual layers | **S10** | No (filtered to Flock Size) |
| `eggVacuum` | boolean, `false` | Legacy grant only (S14, Oct 20): a `true` from the conversion or an earlier revision-12 save becomes that run's `EggVacuum` tree node on load, then saves `false`. The vacuum itself is bought (§4) | – |
| `vacuumCargo` | `{count, value}`, `{count=0,value=0}` | **S11** | Yes |
| `autoRoll` | `{enabled, stopAt, recruitAt?, mutationStop}` | **S12** (`recruitAt`, `mutationStop` are new; S12 may change `Config.AutoRollStops`) | No |
| `goldRolls` | `{count}` lever pulls toward the next special pull, `{count=0}` | **S12** | Yes |
| `upgradeTreeVersion` | integer, missing = 0; written as `TreeMigrations.Version` | S7c | – |
| `mutationKeep` | 0–4 mutations kept from the Rebirth rank; `nil` until S9c's `Mutation` family exists | S7c (derivation), S9c (reads it; floors the tree after a Rebirth) | No |
| `timeSkipPending` | `{coins, rank}` Time Skip Coins waiting for `ClaimTimeSkip`, `nil` (October 21, P4; anything but coins ≥ 1 and a whole rank reads as nil) | P4 (`RebirthService`: every non-Skip Rebirth adds to it; the claim clears it) | No (a Rebirth adds to it) |

**Live since October 20, 22:07: migrate, never bump.** Every change to what a saved
value means needs a lenient one-time load step. Servers on an older build refuse a
newer `DataRevision` ("This save needs recovery"), so new meanings use version keys
instead:
- **Upgrades tree tiers:** add a step to `TreeMigrations.Steps` and bump
  `TreeMigrations.Version` in the same commit; never edit or reorder a released
  step. Saves carry `upgradeTreeVersion`, steps run once on load for older saves,
  and new profiles and revision ≤ 11 conversions start current. Step 1 (S9c): Gold
  Rate keeps its every-N count from the frozen live table {10, 8, 6} (II → III under
  {10, 8, 7, 6, 5}); `RebirthV2Checks` fails if that table changes while the version
  is 0.
- **`mutationKeep`:** set once at a save's first load under S9c's `Mutation` family,
  from the live rank unlocks: Rebirth 10+ → 4, 5+ → 3, 1+ → 2, else 1 (Golden). New
  profiles under the family start at 0; the load floors `upgradeTree.Mutation` to it.
- Older servers drop saved keys they don't know when they save, so publish with
  "Migrate To Latest Update" (or restart servers).

Kept as they are: `coins`, `pets` (with `cashLevels` = levels bought with Chicken
Feed), `discovered`, `rebirths`, `eggCarry` (the unlimited click bag), `research`
(legacy record only), `armySelection`, `tutorial`, `daily`, Hill fields,
`firstWins`/`frontierWins`/`laneCamps`/`kingCleared`, `giantPity`, `fusionUnlocked`.
`eggSpeedLevel`, `incomeLevel`, `luck`, `capacity`, `rollSlotsUnlocked` and
`plotSizeLevel` stay as **derived** in-memory fields (section 4) so existing readers
keep working; S7 writes them for reference but reads only `upgradeTree`.

Storage: `Config.StorageLimit = 1000` (hidden safety cap). `session:CollectionLimit()`
returns it; loads accept up to it. Timed yard builds are retired (`plotBuild` is
always nil; a saved build in progress completes during conversion).

Tutorial flags: to save a new `tutorial.<flag>`, add it to the `TUTORIAL_KEYS` list
in `PlayerSession` (one line) and list it in your hand-off. S14 added `vacuumUsed`
(the vacuum's first egg; ends the "Equip your Egg Vacuum" Next goal).

## 3. Requests (`RequestAction`)

| Action | Fields | Owner | Notes |
|---|---|---|---|
| `BuyUpgrade` | `nodeId`, `expectedPrice` | S7 | Instant tree purchase; fails on a stale price |
| `BuyGemUpgrade` | `upgradeId`, `expectedLevel`, `expectedPrice` | S7 | |
| `SetAutoRebirth` | `enabled` | S7 | Needs the Auto Rebirth Gem Upgrade |
| `Rebirth` | `expectedRank`, `useSkip?` | S7 | `useSkip=true` spends one Skip credit |
| `PreparePurchase` | `key="RebirthSkip"` | S7 | Server picks the rank band's product; returns `purchase={key, kind="Product", id}` |
| `CashUpgrade` / `BoardUpgrade` | old six keys | S7 | Kept until S9 lands: maps EggSpeed, EggValue, Luck, ArmySize, RollSlots, PlotSize (= Flock) to the family's next node |
| `Expand`, `Income`, `Luck` | – | S7 | Old shortcuts; each buys that family's next tree tier at today's quote |
| `StartResearch`, `CancelResearch`, `SkipResearch`, `PinResearch`, `AcknowledgeResearch` | – | S7 | Retired: reply "Research is now instant in Upgrades." |
| `FlockEquip` / `FlockUnequip` | `petId` | S10 | |
| `FlockBest` | – | S10 | Back to automatic best layers |
| `CollectEggs` | `ids` | S11 | Click/tap/gamepad claim with a server range check |
| `UnloadVacuum` | – | S11 | Deposits through the existing instant-sale path |
| `FeedChicken` | `petId`, `expectedLevel`, `expectedPrice` | S11 | Range check, then `ArmyService.UpgradeChicken`. S11 retires the inspector `UpgradeChicken` action when it ships |
| `SetAutoRoll` | `enabled`, `stopAt`, `recruitAt`, `mutationStop` | S12 | Extends today's request |
| `RecruitHeld` | `offerId` | S12 | Recruit an Auto Roll hit from the menu |
| `Sell` | `petIds`, `expectedTotal` | S13 | Today's bulk endpoint; S13 may extend it |
| `ClaimTimeSkip` | – | P4 (Oct 21) | Pays `timeSkipPending` once through `Credit(…, "rebirth")` (analytics TimeSkip), capped at the Coins limit; quiet success; a second claim is refused with an empty message |

Call Army is free: `CallArmy` no longer checks research.

## 4. The Upgrades tree (`UpgradeCatalog`)

Categories: `Main`, `Tools`, `Player`, `Army`. Every node is an instant Coins
purchase, resets on Rebirth, and has no camp, rank or King gate (Sep 25 rule).

Shapes (frozen tables):

```lua
UpgradeCatalog.Categories = {"Main", "Tools", "Player", "Army"}
UpgradeCatalog.FamilyOrder = {...}            -- every family id
UpgradeCatalog.Families[family] = {
	id, name,            -- "EggSpeed", "Egg Speed"
	category,            -- "Main" | "Tools" | "Player" | "Army"
	icon,                -- S6 family icon key (tiers reuse it with a numeral)
	effect,              -- effect key (section 5) or a derived field (below)
	base,                -- value with no tier bought
	tiers = {{value, price, yardStage?}, ...},   -- value is cumulative, not added
	format,              -- ValueText style: "multiplier" | "percent" | "count" | "studs" | "hours" | "unlock" | "tier"
}
UpgradeCatalog.Nodes[nodeId] = {
	id, kind,            -- "start" | "open" | "back" | "tool" | "upgrade"
	category, q, r,      -- axial hex position inside its category's map
	family?, tier?,      -- upgrade nodes only
	name,                -- "Egg Speed II"
	prerequisite?,       -- node id; "start", "back" and "tool" nodes always count as owned
	opens?,              -- "open" nodes: the category they open
	icon,
}
UpgradeCatalog.Order[category] = {nodeId, ...}    -- draw order
UpgradeCatalog.ValueText(family, tier) -> string  -- "x1.50", "+10%", "6 layers", "12 h"...
UpgradeCatalog.Effects(tree, gemLevels) -> effects  -- pure; used by the server and for previews
UpgradeCatalog.NodeId(family, tier) -> string
```

Node ids: `<Family><tier>` (`EggSpeed1`…`EggSpeed4`); a one-tier family uses its bare
family id (`ChickenFeed`). Special nodes: `Start`, `OpenTools`, `OpenPlayer`,
`OpenArmy`, `ToolsBack`, `PlayerBack`, `ArmyBack`. `EggVacuum` is an ordinary one-tier
upgrade since S14 (Stevin, Oct 20: bought in Tools, resets on Rebirth).

| Category | Family id (name) | Tiers | Value per tier (draft) | Effect or derived field |
|---|---|---|---|---|
| Main | `EggSpeed` (Egg Speed) | 4 | x1.25, x1.5, x2, x3 | `session.eggSpeedLevel` = tier |
| Main | `EggValue` (Egg Value) | 4 | x1.5, x2, x3, x5 | `session.incomeLevel` = tier |
| Main | `Luck` (Luck) | 4 | x1.25, x1.5, x2, x3 | `session.luck` = tier |
| Main | `Flock` (Flock Size) | 8 | 4, 5, 6, 7, 8, 10, 12, 15 layers (base 3) | `flockSize`; `session.plotSizeLevel` = tier's `yardStage` |
| Main | `ArmySize` (Army Size) | 4 | 4, 6, 8, 10 slots (base 3) | `session.capacity`. Tier 1 is the tutorial's protected 1,200-Coin Army Size 4 |
| Main | `RollSlot` (Roll Slot) | 7 | 2…8 podiums (base 1) | `session.rollSlotsUnlocked` |
| Main | `RollSpeed` (Roll Speed) | 3 | +20%, +40%, +60% | `rollingSpeed` |
| Main | `GoldMachine` | 1 | unlock | `goldMachine` = 1 |
| Main | `GoldRate` (Gold Rate) | 2 | 1, 2 | `goldRate` |
| Main | `DiamondMachine` | 1 | unlock | `goldMachine` = 2 |
| Main | `PrismMachine` (placeholder name; S12/Stevin may rename) | 1 | unlock | `goldMachine` = 3 |
| Tools | `EggVacuum` (Egg Vacuum) | 1 | unlock, 500 Coins (S14) | `eggVacuum` = 1; `ToolService.Owns` reads it |
| Tools | `VacuumCapacity` (Vacuum Capacity) | 4 | +15, +35, +65, +125 eggs (40/60/90/150 with the 25-egg base; Oct 22, was +10/25/50/100 on 20; Oct 21, was seconds of laying) | `vacuumCapacity` |
| Tools | `VacuumRange` (Vacuum Range) | 2 | bonus studs | `vacuumRange` |
| Tools | `ChickenFeed` (Chicken Feed) | 1 | unlock | `chickenFeed` = 1 |
| Player | `WalkSpeed` (Walk Speed) | 3 | +5%, +10%, +15% | `walk` |
| Player | `ClickRange` (Click Range) | 3 | +1.5, +3, +4.5 studs | `pickupStuds` |
| Player | `OfflineTime` (Offline Time) | 3 | 9, 10, 12 h | `offlineHours` |
| Army | `Damage` | 3 | +5%, +10%, +25% | `damage` |
| Army | `Health` | 3 | +5%, +10%, +25% | `health` |
| Army | `MarchSpeed` (March Speed) | 3 | +5%, +10%, +20% | `march` |
| Army | `Armor` | 2 | 5%, 10% less damage taken | `armor` |
| Army | `Recovery` | 2 | 10%, 20% faster | `recovery` |
| Army | `BossDamage` (Boss Damage) | 1 | +15% vs bosses | `bossDamage` |
| Army | `Bounty` | 3 | +5%, +10%, +20% kill Coins | `bounty` |
| Army | `CaptureSpeed` (Capture Speed) | 3 | +10%, +20%, +30% | `capture` |

Prerequisites: tier n needs tier n−1; tier 1 needs its category root (`Start` or the
subtree's Back), except `GoldMachine` (needs `RollSlot1`), `GoldRate1` (needs
`GoldMachine`), `DiamondMachine` (needs `GoldRate2`), `PrismMachine` (needs
`DiamondMachine`), `BossDamage` (needs `Damage3`), and `VacuumCapacity1` /
`VacuumRange1` (need the bought `EggVacuum`; S14). Hex positions ship in the catalog;
S9 may ask S7 to move them. Ids never change.

Prices may scale with Rebirth rank (P0 decides). That is why prices only come
from the snapshot.

## 5. Effects (`session.researchEffects`, client copy `state.effects`)

`UpgradeCatalog.Effects(tree, gemLevels)`: defaults, plus each owned family's
tier value (tiers are cumulative, so the highest owned tier counts), plus Gem
Upgrade levels. Where a key has both, they add.

| Key | Default | Upgrades tree | Gem Upgrade | Read by |
|---|---|---|---|---|
| `damage`, `health` | 0 | Damage, Health | Army Power +0.05/level each | `Battle:ApplyResearch` (unchanged) |
| `march`, `armor`, `recovery`, `bossDamage`, `capture` | 0 | Army families | – | Battle (unchanged) |
| `bounty` | 0 | Bounty | – | BattleService (unchanged) |
| `walk` | 0 | Walk Speed | – | WorldService (unchanged) |
| `pickupStuds` | 0 | Click Range | – | S11: click range bonus |
| `offlineHours` | 8 | Offline Time | – | OfflineCash checkpoint (unchanged) |
| `offlineEfficiency` | 0 | – | Offline Coins +0.05/level | OfflineCash: added to `OfflineCashConfig.Efficiency` |
| `rollingSpeed` | 0 | Roll Speed | Roll Speed +0.10/level | RollService (unchanged) |
| `rollingLuck` | 0 | – | Extra Luck +0.10/level | ChickenLuck's research bonus (unchanged call sites) |
| `autoRoll` | 0 | – | Auto Roll = 1 | RollService, `SetAutoRoll` (S12) |
| `rallySeconds` | 0 | – | Rally: 8 s, then 12 s | ArmyAbilities (unchanged) |
| `callArmy` | 1 | – | – | Always 1 (free) |
| `flockSize` | 3 | Flock | +1 Flock Slot +1/level (S7b) | S10 (`session:FlockSize()`); the yard follows the tree's Flock tier only |
| `armySlots` | 0 | – | +1 Army Slot +1/level (S7b) | `PlayerSession:RefreshEffects`: `capacity` = Army Size value + this |
| `feedMaxLevel` | 0 | S9c: Feed Max Level I–III (extra levels) | – | `Rules.LevelCap`: Chicken Feed cap = `Config.MaxPetLevel` (10) + this, at most `Config.PetLevelLimit` (20) |
| `eggVacuum` | 0 | Egg Vacuum = 1 (S14) | – | ToolService (the held tool), EggService (pulls eggs) |
| `vacuumCapacity` | 0 | Vacuum Capacity (bonus eggs) | Vacuum Capacity +5 eggs/level | Capacity = 25 eggs (`VacuumConfig.Capacity`, Oct 22; was 20) + this (Oct 21; was seconds × the Flock's eggs/s) |
| `vacuumRange` | 0 | Vacuum Range | – | S11 |
| `chickenFeed` | 0 | Chicken Feed = 1 | – | S11; `ArmyService.UpgradeChicken` requires it (S7 gate) |
| `goldMachine` | 0 | Gold 1, Diamond 2, Prism 3 | – | S12 |
| `goldRate` | 0 | Gold Rate | – | S12 |
| `coinBoost` | 0 | – | Coin Boost +0.10/level | `PlayerSession:EarnedAmount` for eggs (S7 adds it there) |
| `gemBonus` | 0 | – | More Gems +0.10/level | RebirthService |
| `timeSkipMinutes` | 5 | – | Time Skip: 5 min per level, starts at level 1 | RebirthService |
| `keepTiers` | 0 | – | Keep Upgrades 1–3 | RebirthService |
| `mutationLuck` | 0 | – | Mutation Luck +0.10/level | S12 passes `1 + mutationLuck` to `MutationCatalog.Roll` |
| `rebirthChickenChance` | 0.01 | – | Rebirth Chicken Odds +0.002/level | `RebirthChickens.MaybeReplace` |
| `autoRebirth` | 0 | – | Auto Rebirth = 1 | RebirthService |

Legacy keys stay at neutral values so old readers never break: `production=0`,
`eggValue=0`, `operations=0`, `formations=0`, `fusion=0`, `speed=0`, `slots=1`,
`holdCap=0`.

Session helpers (S7): `session:RefreshEffects()` after any change to
`upgradeTree`/`gemUpgrades`; `session:FlockSize()`; `session:TreeTier(family)`;
`session:GemLevel(upgradeId)`; `session:LevelCap()` (S7b).

Hooks other owners add (one call each):
- **S12, `RollService:Roll`:** `species = RebirthChickens.MaybeReplace(session, species, rng, slot)`
  right after `EventService.MaybeReplace`. Pass
  `1 + session.researchEffects.mutationLuck` as `MutationCatalog.Roll`'s third
  argument. Update the `SetAutoRoll` lock message to "Unlock Auto Roll in Gem Upgrades."
- **S10:** Flock-only laying online and offline. `OfflineCash.Rate` counts Flock
  layers only. OfflineCash belongs to S4 in wave 1; the lead assigns the edit.
  The same edit applies `offlineEfficiency`.
- **S11:** click range = base + `pickupStuds`; vacuum capacity is sized in seconds of the
  Flock's laying and shown in eggs (carried / capacity), range as above;
  Feed calls `ArmyService.UpgradeChicken`.
- **S4 (already in flight):** Gold Rush and Friend Boost live in `EarnedAmount` next
  to S7's Coin Boost line. The lead merges the two edits.

### Rule changes other sessions build on (S7, landed on the branch)

- `Rules.RecruitLevel` ignores Chicken Feed levels: a species' roll offers come one
  level below the best level that chicken was rolled (or fused) at. Without this,
  one fed chicken would buy permanent high-level rolls (P0 found it). Affects S12
  and S11.
- `ArmyService.UpgradeChicken` (Chicken Feed) now needs the `ChickenFeed` node
  (`PlayerSession:ChickenUpgradeEligibility`): "Buy Chicken Feed in Upgrades > Tools first."
- `ArmyService.Expand`, `ArmyService.UpgradeIncome` and `RollService:UpgradeLuck` are
  no longer called (GameServer routes those requests to the tree). Owners (S10, S12)
  may delete them; until then, they would bypass the tree if called.
- `PlayerSession:CollectionLimit()` returns `Config.StorageLimit` (1000).
  `CompletePlotBuild` is a no-op; `plotBuild` is always nil.
- `session.plotSizeLevel` (the yard stage) follows the Flock tier's `yardStage` (0–7),
  so `WorldService`/`PlotUpgradeService` keep growing the yard. `UpgradeCatalog`
  keeps `PlotPrices`/`PlotScales`/`PlotCapacity`/`EggSpeedPrices`/`RollSlotPrices` as
  compatibility views for those readers and the old cash hexes; S9/S10 may drop them.
- Time Skip pays `timeSkipMinutes` × the egg income the player will have right after
  the Rebirth (October 22, Stevin: the old end-of-run measure "easily unlocks
  everything"): the best Flock-size chickens (tree Flock tiers reset, Gem slots stay)
  at the tiers Keep Upgrades leaves, without Chicken Feed levels, at the next rank's
  multiplier, with Coin Boost, 2x Coins and 2x Egg Spawn. A Skip Rebirth keeps the
  tree and Feed levels, so it measures those. It is steady (no Gold Rush or Friend
  Boost) and floored at `DailyService.MinIncome`. It is credited after the reset
  through `Credit(..., "rebirth")` (analytics source `TimeSkip`), and
  `state.rebirth.timeSkipCoins` previews that exact amount. October 21 (P4): a
  non-Skip Rebirth saves it in `timeSkipPending` instead and `ClaimTimeSkip` credits
  it, so the balance reads 0 after a Rebirth; a Skip Rebirth credits it at once. P0 had
  chosen the pre-reset income (the post-reset one pays a few millionths of a rank's
  cost); October 22 reverses that: Time Skip is a head start, not a share of the rank.
- `BuyUpgrade` counts like `CashUpgrade` in `TutorialService:Action`, `AnalyticsFunnels`
  (Upgrades FirstBuy; a `Flock*` node counts as Plot Expanded) and `AnalyticsPlayer`.
- Admin (lead-approved): `upgrade <target> <all|node>` (replaces `research`), `army`
  (tree sizes 3/4/6/8/10), `gems`, `setrebirth`, `gemupgrade <all|id> [level]`,
  `skip [count]`.

### Chicken levels 11–20 and Gem slots (S7b, Stevin Oct 20)

- **One effect sets the Feed cap.** `researchEffects.feedMaxLevel` = extra Chicken Feed
  levels above `Config.MaxPetLevel` (10), summed from any source. S9c's Feed Max Level
  I–III tree family sets it (`effect = "feedMaxLevel"`, values = extra levels). The cap
  is `Rules.LevelCap(effects)` = 10 + that, at most `Config.PetLevelLimit` (20); with
  no source it stays 10.
- **Server checks the cap.** `ChickenUpgradeEligibility` says "Max level reached." at
  the player's cap. Each chicken in `state.pets` carries `levelCap` (the player's cap)
  and no `upgradePrice` at it. `progression.levelCap` is the same number. Clients show
  "Max level" from `pet.levelCap` (ChickenBrowser, ToolController, ChickenLabel).
- **Levels past 10:** +25% eggs each, compounding (`Rules.EggGrowthPastCap`), instead
  of 2x; Lv 20 lays about 9.3x a Lv 10. HP and damage keep +25% of base per level.
  Feed quotes (`Rules.ChickenUpgradePrice`) run to Lv 20: Lv 10→11 costs 1.25x the
  Lv 9→10 quote, then 3.125x per level (each level 2.5x slower to pay back, as in 1–10).
  Draft until the post-S9c re-fit.
- **Unchanged:** roll offers stay at most Lv 9 (`Rules.RecruitLevel`); the historical
  refund curve (`Rules.UpgradePrice`) still stops at 10. Levels past 10 are Feed
  levels (`cashLevels`), so a Rebirth takes them back.
- **Saves:** levels 1–20 load; a higher saved level reads as 20. A chicken's saved
  investment and a Feed purchase may reach `CurrencyLimits.MaxCoins` (was 1e12, which
  already stopped Galaxy Overlord at Lv 7→8).
- **Gem slots:** `capacity` (and `NextSlot`) add `armySlots`; `Config.MaxSlots` is 12
  (the tree's 10 + 2), 17 with Bigger Army. Time Skip counts Gem Flock slots.
- **Admin:** `chicken <target> <species> [level]` accepts up to Lv 20; levels past 10
  count as Feed levels.

## 6. Gem Upgrades (`GemUpgradeCatalog`)

```lua
GemUpgradeCatalog.Order = {16 ids, row by row}
GemUpgradeCatalog.Upgrades[id] = {
	id, name, row, column,  -- column 1 or 2 in the two-column grid
	unlockRank,             -- 0 = open from the start
	maxLevel, startLevel,   -- startLevel 0, except TimeSkip = 1
	prices = {...},         -- Gems for each level after startLevel
	effect, perLevel,       -- effect key (section 5), amount per level
	text,                   -- card line for the next level, e.g. "+10% faster rolls"
	icon,                   -- S6 icon key
}
```

Order (S7b, Stevin Oct 20): Drop a Fruit's shop order in rows of two, with +1 Flock
Slot and +1 Army Slot at Rebirth 1 (its "+1 Fruit Slot"). Ranks and prices are drafts
until the post-S9c re-fit.

| Row | Opens at | Id | Name | Max | Card text (next level) | Gem prices (draft) |
|---|---|---|---|---|---|---|
| 1 | start | `RollSpeed` | Roll Speed | 8 (was 5) | +10% faster rolls | 5, 10, 20, 35, 60, 100, 160, 250 |
| 1 | start | `ExtraLuck` | Extra Luck | 8 (was 5) | +10% roll luck | 5, 10, 20, 35, 60, 100, 160, 250 |
| 2 | start | `VacuumCapacity` | Vacuum Capacity | 5 (was 3) | +5 eggs in your vacuum (Oct 21, was +15 s) | 10, 25, 50, 100, 175 |
| 2 | start | `AutoRoll` | Auto Roll | 1 | Unlocks Auto Roll | 15 |
| 3 | Rebirth 1 | `FlockSlot` | +1 Flock Slot | 2 | +1 chicken laying eggs in your Flock | 20, 60 |
| 3 | Rebirth 1 | `ArmySlot` | +1 Army Slot | 2 | +1 chicken in your Army | 25, 75 |
| 4 | Rebirth 2 | `CoinBoost` | Coin Boost | 10 | +10% Coins from eggs | 10, 15, 25, 40, 60, 90, 135, 200, 300, 450 |
| 4 | Rebirth 2 | `AutoRebirth` | Auto Rebirth | 1 | Rebirths for you when you have enough Coins | 25 |
| 5 | Rebirth 3 | `TimeSkip` | Time Skip | 9 (starts at 1; was 6) | +5 min of Coins when you rebirth | 20, 40, 70, 110, 160, 230, 320, 430 |
| 5 | Rebirth 3 | `MoreGems` | More Gems | 5 | +10% Gems from every rebirth | 25, 50, 90, 140, 200 |
| 6 | Rebirth 5 | `KeepUpgrades` | Keep Upgrades | 3 | Keep 1 tier of Egg Speed, Egg Value and Luck | 40, 90, 160 |
| 6 | Rebirth 5 | `Rally` | Rally | 2 | Rally: +20% army damage for 8 s, then 12 s | 30, 80 |
| 7 | Rebirth 8 | `MutationLuck` | Mutation Luck | 5 | +10% mutation chance | 40, 80, 130, 190, 260 |
| 7 | Rebirth 8 | `OfflineCoins` | Offline Coins | 8 (was 4) | Earn 5% more while away | 30, 60, 100, 150, 210, 280, 360, 450 |
| 8 | Rebirth 12 | `ArmyPower` | Army Power | 10 (was 5) | +5% army damage and health | 50, 100, 175, 275, 400, 550, 725, 925, 1150, 1400 |
| 8 | Rebirth 12 | `RebirthChickenOdds` | Rebirth Chicken Odds | 5 | Rebirth chickens show up 20% more | 30, 60, 100, 150, 220 |

Saved levels never change with a row move: a level bought before keeps its effect.

October 21 (the 50-rank ladder, `docs/team/REBIRTH_PACING_20261021.md`): the board was
complete by about Rebirth 25, so the six cards marked "was" gained levels as a Gem sink
for ranks 26–50 (about 7,300 more Gems; the board now totals about 12,500). Coin Boost
and Keep Upgrades were left alone because more of them would speed every run.

Gem Upgrades are never reset, cost Gems only, and are not Coins upgrades, so the
"no rank gates on Coins upgrades" rule does not apply to their row locks.

## 7. Rebirth v2 (`RebirthService`, `Config.Rebirth`)

- **Requirement:** Coins on hand only (no camps, no King). Army home and no Mission
  running. 50 ranks, from 50K Coins to 496T: ranks 1–20 are the §10 fit, 21–30 grow
  x1.2 a rank (R30 51.4T) and 31–50 x1.12 a rank (October 21 reshape, Stevin: "more,
  not harder"; `docs/team/REBIRTH_PACING_20261021.md`). Enemy scale is capped at rank
  30 (x8), so ranks 31–50 add no enemy strength.
- **Rewards:**
  - Egg Coins x(1 + rank).
  - Gems = (40 + 10 × rank) × (1 + `gemBonus`), floored.
  - Time Skip: `timeSkipMinutes` of the egg income right after the reset (October 22;
    exact rule in "Rule changes" under §5).
  - That rank's Rebirth chicken, Lv 1, free. Above `StorageLimit` it waits in
    `rebirthChickenCredits`.
  - Mutation unlocks: Rainbow at Rebirth 1, Shadow at 5, Cosmic at 10.
- **Resets:**
  - Coins go to 0 (October 20, Stevin: "When you rebirth your money resets to
    zero") and stay 0: Time Skip waits as a claim (`timeSkipPending`,
    `ClaimTimeSkip`; October 21, P4).
  - The whole `upgradeTree` resets, so derived fields return to base: 3 slots,
    1 podium, Flock 3. Keep Upgrades keeps up to N tiers of Egg Speed, Egg Value
    and Luck.
  - Chicken Feed levels (`pet.cashLevels`) come off.
  - `eggCarry`, `vacuumCargo` and yard eggs are cleared, after the existing
    settle step.
  - `goldRolls` resets.
  - Camp and King flags are released.
- **Keeps:** chickens (rolled and Fuse levels, Giants, mutations), Index, rank,
  Gems, Gem Upgrades, passes, daily streak, Hill wins, **camp and King progress**
  (`firstWins`, `frontierWins`, `laneCamps`, `kingCleared`, `kingBountyPaid`), the
  tutorial, Auto Roll settings, selections (filtered to the new sizes). The Egg Vacuum
  is a tree node since S14, so it resets with the tree.
- **Enemy scale:** x1 through Rebirth 2, then +0.25 per rank (x3 at Rebirth 10, x8 at 30).
  Camps scale by the **attacker's** rank. The `BattleService` call-site change is
  cleared with the lead.
- **Missions** (`OperationService.Tier`):
  - Veteran: King clear or Rebirth 5.
  - Elite: Rebirth 10.
  - Royal: Rebirth 15.
  - `missionTierLegacy` keeps earlier access.
- **Skip:** a saved credit (`rebirthSkips`). The purchase adds 1 in `DataService:CommitPurchase`.
  `Rebirth{useSkip=true}` spends it; the server also spends a waiting credit by
  itself as soon as the army is home. A Skip Rebirth resets nothing and still
  pays every reward. Products are by next-rank band: `RebirthSkip1` (Rebirth 1–5,
  49 R$), `RebirthSkip2` (6–15, 99 R$), `RebirthSkip3` (16–30, 199 R$). They are
  paid-random (Gems buy luck), so they are hidden where paid random items are
  restricted. Product ids arrive after Stevin approves the live creation (dry runs:
  `tools/monetization.py create-product --name "Skip Rebirth 1-5" --price 49 …`);
  until then `ShopCatalog.ProductOnSale` is false and `rebirth.skip.onSale` is false.
- **Auto Rebirth:** when owned and `autoRebirth` is on, the server rebirths as
  soon as the quote is eligible.
- **Rebirth chickens:** `PetCatalog.Veteran1`…`Veteran30` (placeholder names from
  plan v2: Private Peck … The Eternal Rooster). Each has `rebirthRank = N`,
  `weight = 0` (never in normal rolls), its stat band's economy key and a
  `baseSpecies` fallback look. `PetCatalog.RebirthOrder` lists them by rank. The
  Index shows locked ones as silhouettes with "Rebirth N" (S8). Podium offers:
  `rebirthChickenChance` per offer, unlocked ranks only, and only ever replacing
  a weaker offer.

`state.rebirth` (S8 builds the screen from it):

```lua
rebirth = {
	version = 2, enabled, rank, maxRank, nextRank, title, nextTitle,
	cost, coins, eligible, reason,        -- reason text for a grey button
	armyHome, missionRunning,
	multiplierNow, multiplierNext,        -- egg Coins multipliers
	gemsNext,                             -- Gems the next Rebirth pays
	timeSkipMinutes, timeSkipCoins,       -- Time Skip tile
	timeSkipPending = {coins, rank} | nil, -- Oct 21 (P4): the claim waiting for ClaimTimeSkip
	nextChicken = {species, name, rarity} | nil,
	unlockNext = {name, multiplier} | nil,  -- mutation unlocked at the next rank
	enemyScaleNext,
	keepTiers,                            -- Keep Upgrades level
	resets = {string}, keeps = {string},  -- the manifest, for the warning
	skip = {credits, productKey, onSale, restricted},
	autoRebirth = {owned, enabled},
}
```

## 8. Snapshot fields (`StateChanged` state)

| Key | Filled by | Shape |
|---|---|---|
| `gems`, `gemsEarned` | S7 | numbers |
| `gemUpgrades` | S7 | `{order, items={[id]={id, level, maxLevel, price?, status, row, column, unlockRank, text}}, autoRebirth={owned, enabled}}`; status `Locked` / `Available` / `Unaffordable` / `Maxed` |
| `upgradeTree` | S7 | `{families={[family]=tier}, nodes={[nodeId]={status, price?, spendReason?}}, badges={Main, Tools, Player, Army, total}}`; status `Owned` / `Available` / `Unaffordable` / `Locked` (prerequisite missing); special nodes report their kind. `Available` respects the starter reserve; badges count `Available` per category and in total |
| `effects` | S7 | copy of `researchEffects` |
| `pets[i].levelCap`, `progression.levelCap` | S7b | the player's Chicken Feed cap (`Rules.LevelCap`, 10–20); a chicken at it has no `upgradePrice` |
| `upgradeTree.luck` | S7 | Luck tooltip (S9): `{multiplier, windowText, rarePlusChance, epicPlusChance, topBandChance, nextMultiplier?, nextWindowText?, nextRarePlusChance?, nextEpicPlusChance?, nextTopBandChance?}`; bonuses included, next = the next Luck tier |
| `rally` | S7 | `{readyAt, activeUntil}` in server epoch seconds (S9's Rally button); `rallySeconds` is in `effects` |
| `rebirth` | S7 | section 7 |
| `research`, `boardUpgrades` | S7 | **Legacy, until S9 merges.** The old screen keeps working on S7's branch; S9 stops reading them and the lead removes them |
| `flock` | S10 | at least `{size, ids, mode}` |
| `tools` | S11 | at least `{eggVacuum, chickenFeed, vacuum={count, value, capacity}}` |
| `autoRoll` | S12 | today's `{enabled, stopAt, unlocked, holding}` plus S12's fields; `unlocked` = Gem Auto Roll |
| `goldRolls` | S12 | S12 defines |

## 9. Converting existing saves (revision ≤ 11, once)

Stevin confirmed this mapping on October 20. "Nearest" compares the old total
bonus with the new tier values; ties round up.

| Old | New |
|---|---|
| Egg Speed level and Feed research (E1–E3) | Egg Speed tier nearest to the old egg-speed multiplier |
| Egg Value level and Packing research (E4–E6) | Egg Value tier nearest to the old egg value |
| Luck level and Lucky Feathers / Super Luck research (L1–L6) | Luck tier nearest to the old Luck strength |
| Yard size | Flock tier nearest to the number of chickens owned (all laid before), capped at the top tier; a build in progress completes first |
| Army Size 3–10 | Army Size tier nearest by slots |
| Roll podiums 1–8 | Roll Slot tier = podiums − 1 (exact) |
| Roll Speed research R1–R6 | Roll Speed tier nearest by bonus |
| A1–A3, A4–A6, A7–A9, A10–A11, A12–A13, A16, E10–E12, S6–S8 | Damage, Health, March Speed, Armor, Recovery, Boss Damage, Bounty, Capture Speed: same tier, one for one |
| S9–S11, E7–E9, E13–E15 | Walk Speed, Click Range, Offline Time: same tier |
| Auto Roll research; Rally (A14) / Battle Cry (A15) | Gem Upgrades Auto Roll 1; Rally 1 or 2, free |
| S15 / S16 / S17 Mission research; any Rebirth rank | `missionTierLegacy` 1 / 2 / 3; rank ≥ 1 keeps Veteran |
| S1–S5, S12–S14, Fuse Machine, Call Army, H1–H2 | Dropped, no refund (Call Army is free for all) |
| Running research jobs | Count as finished |
| Unused paid research-skip time (`research.skipCredit`) | Gems: 1 per 5 minutes, rounded up |
| Rebirth 1 / Rebirth 2 holders | Keep rank and multiplier; 100 / 220 Gems; their Rebirth chickens |
| Finished or skipped Commander guide (or a pre-starter-army cohort) | `EggVacuum` node owned for this run (S14; via the `eggVacuum` flag) |
| Anyone who ever bought a chicken level (`cashLevels`) | `ChickenFeed` node owned for this run |
| Coins, chickens and their levels, Index, passes, receipts | Unchanged |

Off-sale passes: `AutoCollectEggs`, `EggMagnet`, `DoubleBounty`, `CommanderBanner`
leave the Shop. Owners get 100 / 25 / 125 / 50 Gems once (`passGemGifts`) when
ownership is verified. Their benefits end, except the Commander Banner cosmetic.
Research skip products leave the game; a late receipt for one pays Gems at the
1-per-5-minutes rate.

## 10. Rebirth cost fit (P0 October 20; re-fit October 21)

**How.** `tests/ProgressionSimulation.luau` models the economy with the real modules
(its header lists every assumption). It still runs from the Studio command bar. S7
runs it outside Studio with Lune 0.10.5 and a small Roblox shim (not committed),
several seeds in parallel (`firstSeed`).

**October 21 re-fit** (after S7b's Gem slots and levels 11–20, S8's Coins reset to 0,
S9c's tree v2 with Coins mutations and Gold/Diamond/Prism rates, and S16's Playtime
Rewards). The simulation gained:
- Feed Max Level, bought with the level it unlocks;
- Mutations and the Gold/Diamond/Prism hexes in the utility budget (rolls go through
  RollService, so Gold rolls, mutation tiers, Mutation Luck and Rebirth-chicken offers
  apply);
- Playtime Rewards per play visit (fast 120 min, casual 60 min), all twelve tiles
  each visit, boosts on the simulation clock.

Each round moved every cost by the ratio of plan v2's gap to the measured gap, damped
(exponent 0.8) and averaged over neighbouring ranks; unreached ranks got cheaper; costs
rise at least 1.1x per rank. Five rounds of 3 seeds, then checks on fresh seeds (4–8,
9–13), one correction from those 10 seeds pooled, and a final check on 8 new seeds
(14–21). Targets (fast player): Rebirth 1 ≈ 10 min, 2 ≈ 18 min, 5 ≈ 54 min, 10 ≈
2.9 h, 15 ≈ 6.4 h, 20 ≈ 11.6 h, 30 ≈ 34 h.

**Costs** (`Config.Rebirth.Costs`, Coins):

| Rebirth | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Cost | 50K | 62M | 1B | 8.6B | 36B | 56B | 120B | 260B | 600B | 1.1T |

| Rebirth | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
|---|---|---|---|---|---|---|---|---|---|---|
| Cost | 1.2T | 2.2T | 2.9T | 3.8T | 4.5T | 5T | 5.5T | 6.3T | 7.3T | 8.3T |

| Rebirth | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 | 30 |
|---|---|---|---|---|---|---|---|---|---|---|
| Cost | 11T | 17T | 30T | 38T | 55T | 72T | 120T | 150T | 210T | 340T |

**Results with these costs** (median minutes of play):

| Rebirth | 1 | 5 | 10 | 15 | 20 | 25 | 30 |
|---|---|---|---|---|---|---|---|
| Fast, 8 fresh seeds | 9 | 50 | 170 | 390 | 760 | 1183 | 2114 |
| Fast, Playtime off (4 of those seeds) | 10 | 64 | 218 | 471 | 1031 | 1766 | > 40 h |
| Casual (60-min visits), 3 seeds | 10 | 50 | 149 | 334 | 542 | 853 | 1350 |
| Plan v2 target | 10 | 54 | 174 | 384 | 696 | 1192 | 2040 |

- Seeds spread widely: half the fast seeds reach Rebirth 30 in 21–35 h, the rest end
  at Rebirth 25–28 after 40 h (rolls, mythics and mutations).
- **Playtime Rewards are the biggest new lever.** The clock and the claims restart every
  join, so how often a player rejoins sets their income: about +21% of egg Coins with
  2-hour visits (the fit), +41% with 1-hour visits (the casual rows, which beat the
  targets), and by the tile table about +100% when rejoining every 5–30 minutes.
  Without them the fast player is 20–30% behind.
- Time Skip pays 11% (fast) to 17% (casual) as many Coins as eggs over a game (before
  October 22; it now measures the post-Rebirth income and pays far less).
- Feed Max Level: Flock chickens reach Lv 8–9 before each Rebirth through Rebirth 10,
  so levels past 10 matter only in the late game.
- The Gem board completes at about Rebirth 25–27 for fast seeds.

**What drives a run.** Each run rebuys the tree within minutes. Chicken Feed levels do
most of the work: each level doubles a Flock chicken's eggs and costs x5 the last
(the October 8 curve). Flock Size adds more layers. The Rebirth multiplier, the
permanent chickens and the Gem Upgrades carry over. Rebirth costs are the pacing knob.

**Held as drafts** (the fit did not move them): tree tier values and prices, Gem
prices and row ranks, Feed prices (including past Lv 10), Playtime Rewards.

**Not modelled:** offline time, the Hill, passes, Friend Boost, Mission replays, daily
rewards. Real players took 1.5–1.8x the fast simulation's time at launch (before
Playtime Rewards).

**History:** the October 20 P0 fit (before tree v2, Coins reset and Playtime Rewards)
ended at 50K … 180T and measured fast Rebirth 10 at 157 min, 20 at 636 min and 30
at 1935 min.

Anything numeric may change. Ids, keys, shapes and request names will not change
without a message to the affected session and the lead.

## 11. Analytics (S7, append only)

`AnalyticsSchema.Version` 6 → 7.

New LaunchCounters:
- `rebirth2.rank.N`, `rebirth2.skip`, `rebirth2.auto`
- `gems.earned`, `gems.spent.<id>`, `gemUpgrade.buy.<id>`
- `upgrade.buy.<nodeId>`
- `rebirthChicken.granted`, `.offered`, `.bought`
- `passGems.<passKey>`
- `migration.economy2`
- For S12: `goldRoll.pull.<Gold|Diamond|Prism>`, `autoRoll.recruit`,
  `autoRoll.recruitHeld`, `autoRoll.skip`

Also new:
- Histogram `rebirth2.playSeconds.N`.
- Coins source `rebirth` (sku `TimeSkip`); sink `BuyUpgrade` (sku `Upgrade:<nodeId>`);
  features `BuyUpgrade`, `BuyGemUpgrade`, `SetAutoRebirth`.
- Gems as a second currency: `Analytics:Gems(session, "Source"|"Sink", amount, sku)`
  writes ledger `gems.source.*` / `gems.sink.*` and Roblox "Gems" economy events.
- Funnels: `BuyUpgrade` counts for Upgrades FirstBuy and Plot Expanded (`Flock*`
  nodes). Plot `Max` is retired; Plot `FlockMax` is appended (top Flock tier). The
  AutoRoll funnel's Available step reads `effects.autoRoll`.
