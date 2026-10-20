# Flock, storage and My Army (October 20 overhaul, S10)

Decisions: [OVERHAUL_PLAN_20261020.md](OVERHAUL_PLAN_20261020.md) › Flock and storage.
Shared ids and saved keys: [OVERHAUL_CONTRACT_20261020.md](OVERHAUL_CONTRACT_20261020.md).

## Rules

- **Only the Flock lays eggs**, online and offline. Every other chicken waits in
  storage and lays nothing.
- **Flock Size** (Upgrades tree, effect `flockSize`, 3 with no tier bought) is how
  many chickens lay at once.
- **Automatic by default** (`flockSelection = nil`): the Flock is the best egg
  layers (most eggs per second, then the stronger chicken).
- **Manual picks** (`flockSelection = {petId}`) are kept exactly. Removing one
  leaves an open slot.
  - Equip Best (`FlockBest`) goes back to automatic.
  - When Flock Size grows, the new slots fill with the best layers.
  - When it shrinks (Rebirth), picks past the new size drop, first picks kept.
  - Picks that were sold drop out. An empty pick list returns to automatic.
- **Fill-ins:** a Flock chicken away with the Army (marching, fighting, following)
  leaves its slot to the next best chicken at home until it returns.
- **The Army** is separate (Select Best = most powerful). A chicken can be in both.
- **Selling:** Flock chickens are protected like Army chickens ("Remove it from
  your Flock first"). The last Flock chicken can't be removed.
- **Storage:** no visible cap. The hidden safety cap is `Config.StorageLimit`
  (1,000), set up by the economy core.

## Server

- `PlayerSession` (selection/production block):
  - `FlockIds()`: the Flock in slot order (picks, or the automatic best),
    counting every chicken as home.
  - `LayingIds()`: who lays right now (Flock chickens at home plus fill-ins).
  - `FlockSlots()`: Flock Size.
  - `BestLayerIds(count, skip, steady)`: the best layers.
  - `RefreshFlock()`: keeps picks valid; EggService runs it every step.
  - `Income(laying?)`: sums only the chickens laying. The HUD income, Daily
    reward and Time Skip minutes, and Coin pack sizes follow it.
  - `SaleContext()` and `SaleEligibility(id, context?)`: pass one context when
    checking many chickens (bulk sell).
- `ArmyService.FlockEquip(session, petId, replaceId?)`, `FlockUnequip`, `FlockBest`
  are routed from `GameServer` requests of the same names.
- `EggService:Produce` lays eggs only for `LayingIds()`. A chicken that leaves the
  Flock at home still lays the eggs it had started.
- `OfflineCash.Rate` counts `FlockIds()`; quitting mid-battle never drops a Flock
  chicken from the offline rate.
  - Offline Coins (`researchEffects.offlineEfficiency`) is added to the base
    efficiency.
  - The checkpoint saves its own `bonus`, and `Reward` pays today's base plus
    that bonus.
  - Gold Rush and Friend Boost stay out (`EarnedAmount(..., true)`).
- `WorldService` shows the chickens laying plus the Army at home. Call Army and
  deployments take their rigs from the yard. Storage chickens have no rig; a
  storage chicken that is recruited does not walk into the yard.
  - The yard stage still follows `session.plotSizeLevel`, which the economy core
    derives from the Flock tier, so builds are instant.

## Snapshot

- `state.flock = {size, mode = "Auto" | "Manual", ids, laying, eggsPerSecond}`.
  `ids` is the Flock in slot order; `laying` is who lays right now.
- Each chicken in `state.pets` adds `flock` (in the Flock) and `laying` (laying
  now). `nextIncome` and `upgradeLocked` were unused and are gone.
- `state.petsVersion`: the chicken list is rebuilt and resent only when a shown
  value changes.
  - `GameServer:Send` leaves `pets` out of a packet whose version the player
    already has; a Sync reply always carries it.
  - `AppController:Receive` keeps the last list, so client code always sees
    `state.pets`.

## My Army

- Toolbar:
  - FLOCK `n/size`; the + opens Upgrades at the next Flock Size tier.
  - ARMY `n/size`; the + opens the next Army Size tier, or the Bigger Army pass
    page when Army Size is maxed.
  - Select Best.
- Flock strip on top: "LAYING EGGS", eggs per second, Equip Best, then one card
  per slot.
  - Away chickens are dimmed with "AWAY". Open slots take the inspected chicken.
  - The strip scrolls sideways when Flock Size outgrows the panel.
- Storage below: four columns, built 48 cards at a time ("Show more", also loaded
  on scroll). Search shows the storage count; Sell opens the Sell screen; Sort
  cycles Best first / Most eggs / Name A-Z.
  - A storage chicken laying as a fill-in shows its own egg in the corner.
- Inspector:
  - Status line: Laying / In your Flock · away / Filling in / In storage.
  - Add to Flock / Remove from Flock / Swap into Flock… (then tap a Flock chicken).
  - Add to Army / Remove / Replace…, and Sell (`AppController:OpenSell`).
- Dragging: a storage card onto the strip equips (onto a Flock card swaps); a
  strip card dragged into storage leaves the Flock. The Army drags are unchanged.
- The Coins level-up button stays until the snapshot carries `state.tools`
  (Chicken Feed). After that a status line points to Chicken Feed. The
  "Ready! Fuse 3" hint and the inline sale panel are gone.
- HUD bottom-right: "Flock n/size".

## Checks

`tests/FlockChecks.luau` (isolated sessions, Studio Edit):
`require(game.ServerStorage.PetRollTests.FlockChecks).Run()`. It covers the best
layers, storage laying nothing, exact picks and swaps, fill-ins, Flock Size growth
and shrink, sale protection, offline rate and Offline Coins, and the chicken-list
version.
