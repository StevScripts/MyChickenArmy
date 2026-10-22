# Collection and tools (October 20 overhaul, S11)

Owner decisions: [OVERHAUL_PLAN_20261020.md](OVERHAUL_PLAN_20261020.md) › Collection.
Shared names: [OVERHAUL_CONTRACT_20261020.md](OVERHAUL_CONTRACT_20261020.md) §2, §3, §5, §8.
Tuning lives in `src/shared/VacuumConfig.luau`.

## Clicking eggs

- Click or tap an egg, or press R2 on a gamepad, to collect it. Holding R2 keeps
  grabbing the nearest egg; holding the left mouse button keeps grabbing the egg
  under the pointer (October 21, P6). Walking over eggs no longer collects them.
- Each egg that arrives (clicked or vacuumed) plays one bright chime rising across a
  streak and floats its own "+N" coin value over the player
  ([COLLECTION_FEEL.md](../COLLECTION_FEEL.md) › Reference parity).
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
- A click doesn't need to hit the egg exactly: the egg drawn nearest the pointer
  counts within 6.5% of the screen height (at least 44 px; taps get 8%, 48 px).
- Hover (mouse only, Stevin October 20): the egg a click would take shows the
  white-glove hand cursor and pops out 18% bigger and slightly higher with one
  shared Back-out tween. When the pointer leaves, it settles back. Reduced motion
  skips the animation and keeps the pop static.
- The hand is `rbxassetid://74062853444480` (source and prompt in
  `assets/egg-hover-cursor-20261021/`). Roblox centres a cursor image on the
  pointer, so the fingertip sits at the image centre. Don't switch back to
  `rbxasset://SystemCursors/PointingHand`: it doesn't load in a game
  (AssetFetchStatus.Failure, October 21).

## Egg Vacuum (held tool)

- Bought in Upgrades > Tools (the `EggVacuum` node, 500 Coins) and reset on
  Rebirth like Chicken Feed (Stevin, October 20, in S14; this replaced the free
  gift when the guide ended). `ToolService.Owns` reads `researchEffects.eggVacuum`.
  Saves converted from before October 20 that finished or skipped the guide own
  the node for their current run (`EconomyMigration`, then `PlayerSession:LoadData`).
- While it is in hand, `EggService:Vacuum` pulls the nearest ready eggs within
  **Range** (10 studs, plus `vacuumRange`), up to 8 stacks per step, until it is
  full.
- **Capacity** is a fixed egg count: `VacuumConfig.Capacity` (20) +
  `vacuumCapacity`, which adds the Tools tiers (+10/25/50/100 eggs at 1.5K, 25K,
  3M and 100M Coins, for 30/45/70/120) and the Gem Upgrade (+5 eggs a level).
  October 21 (Stevin: "too large very easily, not enough of a challenge"): it was
  30–120 s of the Flock's current laying, which held two full yards before any
  upgrade and grew with every Flock Size and Egg Speed tier. Each tier now costs
  what the Flock tier whose yard it fits costs (a yard holds
  `Config.EggsPerChicken` 5 eggs per laying chicken), so a full yard takes about
  one trip to the pad. Saved tiers keep their number.
- **Range** tiers are +3/+6/+10 studs at 2.5K, 40K and 1.5M (13/16/20 studs;
  were +4/+8/+12 by 75K, and 18 studs reached the whole starter yard from its
  middle).
- A stack bigger than the room left is split (`EggService:Split`). The claimed
  part takes its share of the Coins, rounded down, and the eggs left behind keep
  the rest.
- Cargo is saved as `vacuumCargo`. Claims already in flight finish into it,
  even if the vacuum is put away or the player leaves. Rebirth clears it after
  `EggService:Release` settles it.
- Pulled eggs fly into the nozzle attachment of the held model. The meter shows
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

## Tools and the hotbar

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
- The tools live in Roblox's own hotbar (Stevin, October 20; the custom
  `ToolDock` is retired). Roblox handles the slot keys, tapping and the gamepad,
  and shows each Tool's `TextureId` icon. `ToolController` keeps
  `CoreGuiType.Backpack` switched on.
- Roblox draws the hotbar on the whole screen (BackpackScript):
  - 60 px slots with 5 px gaps (100 px slots on consoles), 70 px tall;
  - only filled slots show, centred;
  - a new tool takes the lowest free slot;
  - a 30 px backpack arrow sits centred 80–110 px up whenever tools show.
- My Army (with Call Army and My Base) sits centred 116 px above the bottom of
  the safe area, clear of the hotbar and that arrow. It is 20% smaller than
  before (Navigation 0.248 × 0.204 of the screen), with one layout for every
  device.
- While the vacuum is in hand, its egg bar sits in the gap between the My Army row
  and the hotbar (Stevin, October 20, S14). It is thin (a quarter of a slot), about
  as wide as the My Army row, and fills gold with `carried / capacity` on it. When
  full it turns red and reads "Full! Sell on the pad".
- For the Commander guide, `app.tools.hintAnchors.EggVacuum` and
  `.ChickenFeed` are invisible, non-interactive Frames over each owned tool's
  slot. They follow Roblox's slot order and centring, and are nil while a tool
  isn't in the hotbar.
- Icons: `rbxassetid://130089766443010` (Egg Vacuum) and `rbxassetid://122007287446526`
  (Chicken Feed), from `assets/upgrade-icons-20261020/upload-receipts.json`.

## Retired

- The Auto Collect pass is off sale (S7 gives owners Gems). October 21: its robot is
  back as the **Auto Vacuum** Tools upgrade, unlocked by owning the Egg Vacuum and vacuuming 5,000 eggs
  ([AUTO_VACUUM.md](AUTO_VACUUM.md)); `EggRover`, `VacuumClips` and the robot
  presentation (`AutoVacuumController`) were restored from the archive below.
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
