# My Army: the reference Pets grid (October 21)

Owner request (Stevin, Oct 21): "make the my army UX 1:1 to this… add all the features
from the pet section… a tooltip as well and you can select your army, there's no
selection for when your army leaves it just picks the second best chickens and equips
them… make sure the sizing is same." The reference is his screen recording of a
simulator "Pets" window (`Screen Recording 2026-10-21 at 12.02.47 AM.mov`). UX is
copied 1:1; the art is the game's (black studded panels, chunky studded buttons,
rarity card art, black outlines).

Code: `src/client/ChickenBrowser.luau` (replaces the S10 Flock strip, storage and
inspector). Server: `ArmyService.Favorite` (batch lock), `FlockEquip/FlockUnequip`
(refused), `PlayerSession` (Flock picks dropped on load; Flock chickens sell).

## Sizing (measured, not guessed)

From the recording (game view 1728 × 1084 at half resolution), the window with its
side rail and overhanging buttons is **960 × 557**: 55.6% of the width, 51.4% of the
height, its body centred on screen. `MenuLayout.Defaults.Army` is
`size (0.5556, 0.5138)`, `position (0.479, 0.4875)`, `aspect 960/557`, in a new
saved control `MenuLayouts.MyArmyGrid`. The old `MyArmy` control now belongs to the
Sell screen, so the Sell screen keeps its previous size. Every element is placed in
those 960 × 557 units with Scale only (`W`, `H`, `BODY`, `GRID`, `DETAIL` at the top of
the file):

| Element | Units (x, y, w, h) |
| --- | --- |
| Top bar (shared `Theme.Header` "My Army" + red X close) | 100, 0, 830, 65 |
| Body | 100, 65, 830, 464 |
| Lock / Sell buttons (in the top bar) | 360 and 418, 7, 50, 50 |
| Counts pill (Army n/size +, Flock n/size +, in the top bar) | 478, 7, 380, 50 |
| Side rail (Army, Index) / Sort box | 0, 140, 89, 190 / 0, 454, 89, 78 |
| Grid (inside body) | 10, 10, 812, 420: 7 × 108 tiles 8 apart; compact 10 × 75, 6 apart |
| Detail card (inside body) | 537, 8, 275, 422 |
| Equip Best / Unequip All / Compact / Search | y 504, h 53: x 122 w 190 / 325 w 195 / 632 w 55 / 697 w 215 |
| Mode bar (Confirm / Cancel) | 349, 464, 332, 113 |
| Result line under the window | 180, 566, 600, 38 |
| Tooltip | 310 wide at the pointer's corner |

Grid cells take their width from Scale and stay square through a
`UIAspectRatioConstraint` on the `UIGridLayout` (Scale heights in a ScrollingFrame
follow the canvas). The row gap is the column gap in pixels, refreshed on resize.

Later October 21 (owner): "Make the my army menu bigger and add a topbar to it like
how the rest of the game UIs are." The window default grew about 26% to
`size (0.70, 0.66)` (same 960/557 aspect), and the floating title and close became the
shared studded top bar that Shop, Sell, Rebirth and the rest use.

## Behaviour (as in the reference)

- **One grid of every chicken.** Army chickens have a green check and come first;
  then the chosen sort. Tiles show the chicken, its power (bottom right), a padlock
  when locked, its egg when it is laying in the Flock, and its mutation tag.
- **Tooltip** on hover (gamepad: on selection): name, rarity and "1 in X", a divider,
  power, Coins per egg, then level, mutation, Colossal, "Laying eggs in your Flock",
  "Locked".
- **Click a chicken:** the detail card opens over the grid's right side: close X,
  name, tile, rarity · odds, mutation (or "Normal") · level, **Equip** / **Unequip**
  (red), and **Lock** / **Unlock** (gold; the reference's second button is Craft,
  which this game removed). A full Army turns Equip into **Replace…**: the bar asks
  "Replace which chicken?" and a checked chicken is swapped out. One Colossal per Army
  still applies.
- **Equip Best** = Select Best (automatic Army). **Unequip All** empties the Army.
- **Lock mode** (padlock): tap chickens, the bar reads "Lock N Chickens!" (or
  "Unlock N Chickens!" when all are locked), Confirm sends one `Favorite
  {petIds, locked}`. Locked chickens can't be sold.
- **Sell mode** (trash; the reference's delete): tap chickens (red X), "Sell N
  Chickens!", Confirm sends one `Sell {petIds, expectedTotal}`; the line under the
  window reads "N Chickens Sold! +X Coins". Army, away and locked chickens explain why
  they can't be picked. The lock and trash buttons turn green while their mode is on.
  While a mode bar shows, Unequip All and Compact hide under it.
- **Sort** box: power (default) or Coins per egg. **Compact** toggles the 10-wide grid.
  **Search** filters by name, rarity and mutation.
- **Counts:** Army `n/size` (+ opens the next Army Size tier, else the Shop) and
  Flock `laying/size` (+ opens the next Flock Size tier).
- Side rail: Army (this screen) and Index (opens the Chicken Index).
- Sell and lock results show under the window instead of a toast
  (`QUIET_SUCCESS.Sell/Favorite`).

## The Flock has no picks

The Flock is always the best egg layers (`flockSelection = nil`). When a Flock
chicken leaves with the Army, the next best layer at home lays in its place until it
returns (the existing fill-in). Saved picks from S10 are dropped on load;
`FlockEquip/FlockUnequip` from older clients are refused; `FlockBest` still clears.
Since the Flock refills itself, Flock chickens can be sold now; Army, away and locked
chickens can't.

## Checks

`tests/FlockChecks.luau` covers the refused picks, Flock sales, batch lock/unlock and
Army protection. Studio playtest (Oct 21): grid, detail card, lock → "Locked 2
chickens." → unlock, sell-mode marks and refusal, compact grid all verified;
selling was not confirmed on the owner's save. Hover tooltips need a real mouse
(Studio Flow can only click).
