# Fuse removal, retired Giants and the Sell screen (October 20, 2026)

Owner decisions from the October 20 overhaul (session S13, branch
`oct20/s13-fuse-sell`; plan: [OVERHAUL_PLAN_20261020.md](OVERHAUL_PLAN_20261020.md)).
This supersedes the Sep 25 merging, Oct 6 Fuse research, Oct 14 Giants and Sep 28
Colossal rules ([MERGING.md](../MERGING.md),
[GIANT_CHICKEN_DESIGN.md](GIANT_CHICKEN_DESIGN.md), which stay as history).

## Fuse is removed

- Gone: the Fuse menu (`MergeBrowser`, `MergeSelection`, `MergePresentation`), the
  machine binding (`MergeStand`, `MergeGate`), the server fusion endpoints
  (`ArmyService.MergeOptions/Merge/MergeAll/AutoMerge`), the Auto Fuse loop and
  `PlayerSession:MergeAccess()`. Copies live in `archive/fuse-20261020/`.
- `Config.Features.Merging` and `AutoMerging` stay `false` for older readers.
- Older clients sending `OpenMerge`, `Merge` or `MergeAll` get "Fuse has been removed."
- The snapshot no longer has `mergeOptions` or `mergeRequirement`; `mergeUnlocked`
  is always `false` until its last readers (the old My Army hint, the guide's Fuse
  goal) are gone.
- Play hides any authored `Fuse_Machine`, `MergePrompt` or `Shops.Merge` at runtime
  (`WorldService`); the lead deletes the six machines from the place in Studio.
- Save fields `fusionUnlocked`, `fusionUnlockVersion` and `giantPity` still load and
  save unchanged; nothing reads them for gameplay.

## Old Giants are ordinary chickens

Stevin: "We're getting rid of old giants, yea they're becoming ordinary chickens."

- `PlayerSession:LoadData` reads a saved `giantSize` into `pet.retiredGiantSize`
  (an invalid value is dropped instead of failing the load) and `ToData` writes it back
  as `giantSize`. In memory `pet.giantSize` is always nil, so stats, power, the
  one-Colossal limit, the Colossal aura, follow spacing, names and model size all treat
  these chickens as ordinary. Nothing is lost: restoring Giants means loading the field
  as `giantSize` again.
- `GiantChicken` keeps only `PityLimit`, the size predicates and the combat constants
  that older readers still call. `ChickenGrowth.Apply` ignores its size argument;
  every chicken grows by level.
- Studio test tools: "Old Giants" adds a saved Bucket Giant and a Storm Colossal that
  should look and fight like ordinary chickens.

## Sell screen

Stevin's reference is Drop a Fruit's Fruits menu switching into **Sell Fruits** mode,
copied 1:1. The only change: it opens from the **Sell** buttons in My Army (S10 calls
`AppController:OpenSell(petId?)`; a sellable petId starts selected).

- Module: `src/client/SellMenu.luau`, page `"Sell"` in `AppController`, sharing My
  Army's saved MenuLayouts frame (`MenuLayout.Shared`). UI Lab stories: "Sell
  Chickens" and "Sell Chickens · confirm".
- Header "Sell Chickens" with the storage count (`12/1000`) and the close button.
- "N Selected - [coin] X" totals the chosen chickens' sale values.
- Grid: only chickens the server marks sellable (`canSell`): never Army, Flock,
  favorites or chickens that are away. Cards are My Army's cards (rarity art, name,
  DPS); one per chicken, 48 at a time with "Show more". A click toggles a chicken:
  a chosen card turns into a dark cell under the red trash can (`Art.Trash`, S6's
  approved `SellTrash` icon, rbxassetid://111469244237912).
- Hover (mouse) or gamepad selection shows the reference's tooltip: name, rarity,
  "1 in X", earnings ("Per Second", the reference's "Per Drop") and level.
- Bottom bar in the reference order: Search, **Back** (to My Army), **Sort: Value /
  Name**, **Sell (N)**.
- Sell (N) opens the gold **"Sell N Chickens?"** card over the screen (no dimming):
  "YOU WILL GET:", the Pocket Coins pile with "+X", then **Sell!** and **Cancel**.
  Cancel keeps the selection. Sell! sends one request; the screen stays open with
  the selection cleared and the toast reads "Sold N chickens for X Coins".
- Not shown in the recording, so kept minimal: Sell (0) only gives the button's
  small "no" shake.

### Server

`Sell {petIds, expectedTotal}` (unchanged shape) validates the whole batch before
changing anything: ownership, no duplicates, `SaleEligibility` (one `SaleContext`
per batch when S10's session provides it), the exact total, the starter-flock
minimum and the coin cap. A batch may hold the whole storage
(`max(LegacyCollectionLimit, CollectionLimit())`). Sale value is unchanged: half of
what was spent on the chicken (`Rules.SellValue`), never boosted.
