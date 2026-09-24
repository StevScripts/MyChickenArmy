# Authored upgrade board

The Studio-owned `UpgradesStand.Screen.SurfaceGui.UpgradesBoard` is the visual
source. Do not regenerate it. `UpgradeBoardController` clones that SurfaceGui
into the local PlayerGui, keeping its Adornee, artwork, scale, positions, fonts
and colors. It updates only `CurrentValue`, the existing price label, and button
interaction. The editor's original board is unchanged.

## Ownership

- `shared/UpgradeCatalog.luau`: the three new tracks' tuning and board keys.
- `server/UpgradeService.luau`: offers, board proximity and atomic purchases.
- `server/PlayerSession.luau`: levels, benefits and additive save fields.
- `server/PlotUpgradeService.luau`: runtime yard scaling and movement bounds.
- `client/UpgradeBoardController.luau`: authored button bindings and live text.
- Existing ArmyService and RollService still own army, income and luck upgrades.

## Benefits

- EggSpeed: production rates 1 / 1.15 / 1.30 / 1.45 / 1.60. Stacks with the
  existing DoubleEggSpawn pass. Existing eggs keep their already-produced value.
- PlotSize: yard widths 100 / 105 / 110 / 115 / 120 percent; flock capacity
  40 / 45 / 50 / 55 / 60. Resizes only runtime chicken-yard art, not the board,
  plot deck, buildings, or source map. Egg placement and roaming share the bounds.
- EggValue: existing income upgrade. The board shows the value multiplier, since
  different chickens produce eggs of different cash values.
- ArmySize: existing deployment capacity and rank requirements; BiggerArmy kept.
- Luck: existing luck upgrade and RNG formula, unchanged by this feature.
- RollSlots: new profiles begin with one active podium and can unlock up to six,
  capped by the number of physically authored displays. Applies on the next roll.

New speed and size tracks use the existing income upgrade prices/rank gates.
Roll-slot prices and rank gates are in UpgradeCatalog. They are tuning defaults,
not the old Figma preview prices.

Existing profiles without the additive fields receive zero speed/size upgrades
and retain their previously available six roll slots. No balances, birds, existing
upgrades or purchases are reset. The current save envelope and lease remain with
DataService. A shared stand upgrades the interacting player's profile; a stand
inside a plot can only be used by that plot's owner.

No tests or playtests were run as part of this implementation.
