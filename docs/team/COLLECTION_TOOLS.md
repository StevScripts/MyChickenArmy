# Collection and tools (October 20 overhaul, S11)

Owner decisions: [OVERHAUL_PLAN_20261020.md](OVERHAUL_PLAN_20261020.md) › Collection.
Shared names: [OVERHAUL_CONTRACT_20261020.md](OVERHAUL_CONTRACT_20261020.md) §2, §3, §5, §8.
Tuning lives in `src/shared/VacuumConfig.luau`.

## Clicking eggs

- Click or tap an egg, or press R2 on a gamepad, to collect it. Holding R2 keeps
  grabbing the nearest egg. Walking over eggs no longer collects them.
- Reach is **Click Range**: `VacuumConfig.ClickRange` (12 studs, flat) plus the
  Click Range tiers (`researchEffects.pickupStuds`). The ring under the player
  shows it on their own yard.
- The egg flies to the player at once (`EggController`), and the client batches
  the ids into `CollectEggs {ids}` at most every `ClickRequestSeconds`.
  `EggService:CollectClicked` claims each ready stack within reach. The server allows
  `ClickSlack` more for a running player's latency. An egg the server never claims
  drops back after 1.2 s.
- `CollectEggs` has its own rate gate in `GameServer` (burst 8, 6 per second), so
  clicking never uses the gameplay action tokens. It never sends a notice.
- Clicked eggs go into the unlimited bag (`eggCarry`; `CarryLimit` is only a
  save backstop).
- Eggs are clickable because each voxel egg's MeshPart has `CanQuery` on. They
  add no extra parts, and they still never collide or touch. The Glow part stays
  out of the ray. A click that lands on one of your own chickens keeps the
  existing Army shortcut.

## Egg Vacuum (held tool)

- Bought in Upgrades > Tools (the `EggVacuum` node, 500 Coins) and reset on
  Rebirth like Chicken Feed (Stevin, October 20, in S14; this replaced the free
  gift when the guide ended). `ToolService.Owns` reads `researchEffects.eggVacuum`.
  Saves converted from before October 20 that finished or skipped the guide own
  the node for their current run (`EconomyMigration`, then `PlayerSession:LoadData`).
- While it is in hand, `EggService:Vacuum` pulls the nearest ready eggs within
  **Range** (10 studs, plus `vacuumRange`), up to 8 stacks per step, until it is
  full.
- **Capacity** is in eggs but sized in seconds of the Flock's current laying:
  `(Seconds 30 + vacuumCapacity) × EggService:LayingRate`, never below
  `MinCapacity` (10). `vacuumCapacity` is in seconds and adds the Tools tiers
  (+15/30/60/90, for totals of 45/60/90/120 s) and the Gem Upgrade (+15 s per
  level). Capacity is recounted at most once a second.
- A stack bigger than the room left is split (`EggService:Split`). The claimed
  part takes its share of the Coins, rounded down, and the eggs left behind keep
  the rest.
- Cargo is saved as `vacuumCargo`. Claims already in flight finish into it,
  even if the vacuum is put away or the player leaves. Rebirth clears it after
  `EggService:Release` settles it.
- Pulled eggs fly into the nozzle attachment of the held model. The dock shows
  `carried / capacity`, which counts eggs still in flight. When it is full it
  turns red and reads "Full! Sell on the pad".

## Selling

The green pad sells the bag and the vacuum together as one sale, through the
existing instant-sale path (`AcceptDeposit`). A sale that included vacuum eggs
is recorded with collector `"vacuum"`, otherwise `"player"`. Both get S3's coin
burst; only the retired `"rover"` never did. No `UnloadVacuum` request is needed.

`state.eggs.carriedCount` and `carriedValue` cover everything the pad will sell
(bag + vacuum). `bagCount` is the bag alone, and `vacuum` holds
`{count, stored, value, capacity, range}`.

## Chicken Feed

- Owned while the Upgrades tree has the `ChickenFeed` node (`chickenFeed ≥ 1`).
  A Rebirth takes it back.
- With Feed in hand, one native prompt rides on the nearest of your chickens at
  home: "Duck · Lv 3 → 4" over "Feed · 9,000 Coins" (at the max level it reads
  "Max level").
- `FeedChicken {petId, expectedLevel, expectedPrice}` checks that Feed is held
  and the chicken is within `FeedRange` + `FeedSlack` (14 studs). It then calls
  `ArmyService.UpgradeChicken` with the server quote, and the starter reserve
  still applies.
- The reply reads "Duck leveled up! Lv 3 → 4". The chicken flashes gold.
- Analytics and the tutorial still count it as `UpgradeChicken`, the same
  purchase.
- The old inspector action `UpgradeChicken` now replies "Equip Chicken Feed and
  walk up to your chicken to level it up." `state.tools` being present tells
  `ChickenBrowser` to hide its Coins Upgrade button.

## Tools and the dock

- `ToolService` keeps each Backpack holding exactly the owned tools. It re-syncs
  every 0.5 s, so tools come back after a respawn and both go away after a
  Rebirth until they are bought again.
- Tools are server-made, so a Tool created on a client never counts.
- Each Tool has an invisible Handle at the hand, with the visible parts welded
  to it. They are Massless and never collide, touch or block clicks.
- The vacuum model comes from the Claude Design canvas "Egg Vacuum Model"
  (https://claude.ai/artifact/MmMV4VPQBL5YG3eZmdxxvc): a red body, a steel nozzle,
  and a gold-capped glass tank holding three Duck voxel eggs.
- The feed is an open sack with a green band, from the S6 icon.
- A Studio Tool named `EggVacuum` or `ChickenFeed` in
  `ReplicatedStorage.PetRoll.Assets.Tools` replaces the parts-built model.
- `state.tools = {eggVacuum, chickenFeed, order, vacuum, clickRange, feedRange}`.
- `ToolDock` sits just above My Army, with one layout for every device: one
  square slot per owned tool with its key number, and the equipped slot
  outlined in white.
- Keys 1 and 2, or tapping a slot, equip a tool or put it away. Gamepad L1/R1
  step through the tools and then empty hands. On a gamepad an R2 "Collect" hint
  shows next to the dock.
- Roblox's own hotbar stays hidden. `ToolController` re-hides it after a
  cutscene restores the CoreGui.
- Icons: `rbxassetid://130089766443010` (Egg Vacuum) and `rbxassetid://122007287446526`
  (Chicken Feed), from `assets/upgrade-icons-20261020/upload-receipts.json`.

## Retired

- The robot vacuum and the Auto Collect pass are off sale (S7 gives owners
  Gems).
- `EggRover`, the robot's `VacuumClips`, and the old `VacuumController`,
  `VacuumConfig` and stand controller are in `archive/robot-vacuum-20261020/`.
- `AutoCollectStandController` now only hides each stand's price billboard and
  glow until the stands leave the six plots in Studio.
- The Egg Magnet radius no longer exists (walk-over pickup is gone).

## Checks

- `tests/PlotEggDepositChecks.luau`: stack split value, vacuum cargo, and the
  combined pad sale.
- Playtest checklist for the lead:
  - click and tap reach and drop-back;
  - gamepad R2;
  - the vacuum filling, splitting and showing Full;
  - selling bag and vacuum with the coin burst;
  - Feed prompt, quote and level;
  - tools after respawn and after Rebirth;
  - the vacuum's grip orientation.
