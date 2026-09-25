# Authored upgrade board

The Studio-owned `UpgradesStand.Screen.SurfaceGui.UpgradesBoard` is the visual
source. Do not regenerate it. `UpgradeBoardController` clones that SurfaceGui
into the local PlayerGui, keeping its Adornee, artwork, scale, positions, fonts
and affordable colors. It updates `CurrentValue`, the existing price label, and
button interaction. The editor's original board is unchanged.

Purchase buttons use the same UIMotion hover, press and shine as the egg board
and menu purchase buttons. Their border and background move with the visual
layer while the hit target stays fixed. Only the live face gradient turns grey
when cash is below the server-provided price; earning enough restores the exact
authored gradient. Unaffordable clicks retain the explanatory toast.

## Ownership

- `shared/UpgradeCatalog.luau`: the three new tracks' tuning and board keys.
- `server/UpgradeService.luau`: offers, board proximity and atomic purchases.
- `server/PlayerSession.luau`: levels, benefits and additive save fields.
- `server/PlotUpgradeService.luau`: runtime yard scaling and movement bounds.
- `client/UpgradeBoardController.luau`: authored button bindings and live text.
- Existing ArmyService and RollService still own army, income and luck upgrades.

## Benefits

All available upgrades are purchasable regardless of camp visits, wins or rank. See [UPGRADE_RULES.md](UPGRADE_RULES.md). The configured maximum levels and authored-space limits still apply.

- EggSpeed: production rates 1 / 1.15 / 1.30 / 1.45 / 1.60. Stacks with the
  existing DoubleEggSpawn pass. Existing eggs keep their already-produced value.
- PlotSize: yard widths 100 / 105 / 110 / 115 / 120 percent; flock capacity
  40 / 45 / 50 / 55 / 60. Resizes only runtime chicken-yard art, not the board,
  plot deck, buildings, or source map. Egg placement and roaming share the bounds.
- EggValue: existing income upgrade. The board shows the value multiplier, since
  different chickens produce eggs of different cash values.
- ArmySize: cash purchases up to the configured deployment maximum from the start; no rank requirement. BiggerArmy kept.
- Luck: existing luck upgrade and RNG formula, unchanged by this feature.
- RollSlots: new profiles begin with one active podium and can unlock up to six,
  capped by the number of physically authored displays. Applies on the next roll.

Speed and size tracks use the existing income upgrade prices, without rank gates.
Roll-slot prices are in UpgradeCatalog; its obsolete RollSlotRanks table is removed.
Price tuning uses fixed benchmark income bands, not eligibility requirements or the old Figma preview prices.

Existing profiles without the additive fields receive zero speed/size upgrades
and retain their previously available six roll slots. No balances, birds, existing
upgrades or purchases are reset. The current save envelope and lease remain with
DataService. A shared stand upgrades the interacting player's profile; a stand
inside a plot can only be used by that plot's owner.

The September 25 presentation follow-up passed focused Studio checks for cash
below/at/above price, repeated color restoration, pending/MAX states, fixed hit
targets and shared interaction feedback. All 24 runtime purchase buttons had
shared motion bindings. Evidence: `assets/purchase-buttons-20260925/`.
