# Upgrades screen (October 20 overhaul, S9; tree v2 S9c)

The full-screen Upgrades tree, rebuilt like Drop a Fruit's tree (references:
`~/Documents/ChatGPT/My Chicken Army/output/2026-10-20-systems-guide/`
`screenshots/c2-006.png` and `details/c2-012.png`; tree v2 from Stevin's three Desktop
screenshots `Screenshot 2026-10-20 at 10.02.57 PM`, `10.03.21 PM` and `10.04.17 PM`,
each with a U+202F before "PM"). Decisions are in
[OVERHAUL_PLAN_20261020.md](OVERHAUL_PLAN_20261020.md); data shapes are in
[OVERHAUL_CONTRACT_20261020.md](OVERHAUL_CONTRACT_20261020.md) §4 and §8.

## Files

| File | Owns |
|---|---|
| `src/shared/UpgradeCatalog.luau` | The tree: families, tiers, hex cells (`walk` steps), per-tier names/icons/numbers (`labels`) |
| `src/client/ResearchBrowser.luau` | The screen: maps, hexes, card, input, purchases; `Browser.Grid` |
| `src/client/CashUpgradeNodes.luau` | Data helpers over `UpgradeCatalog`: next node of a family, tier number, value text, special card lines, legacy keys |
| `src/client/ResearchAssets.luau` | `Assets.upgrades[iconKey]`: one image per catalog `icon` key |
| `src/client/HudController.luau` | The red count on the HUD Upgrades button (`UpdateUpgradesBadge`) |
| `src/client/ResearchExtras.luau` | Rally (now a Gem Upgrade) and the older Formations/Missions pages |

The server owns every status, price and badge. The screen reads
`state.upgradeTree = {families, nodes={[id]={status, price?, spendReason?}}, badges, luck}`
and buys with `BuyUpgrade{nodeId, expectedPrice}`. Layout, names, icons and value
text come from `UpgradeCatalog`; the client never computes a price.

## Maps

- **Main** opens around Start. The orange **Tools**, **Player** and **Army** hexes
  say "Open" and lead to their subtrees; a red **Back** hex sits in each subtree's
  middle with the category name under it.
- Every visit starts on Main. Back returns to Main where the player left it; Close
  (X), Escape or gamepad B on Main returns to play. Gamepad B in a subtree goes Back.
- All maps share one coordinate space; drag, wheel and pinch pan/zoom the open map.

## Layout (tree v2, Stevin October 20)

- Flat-topped hexes (164 x 144) in axial cells, like the reference: Tools (Open) sits
  directly on top of Start and Player (Open) directly under it. The pointy-top hex art
  is turned a quarter, so no new upload was needed. `Browser.Grid = {step=133.4,
  row=154, width=164, height=144, flat=true}`; `Browser.Grid.Offset({q,r})` is a cell's
  centre offset in the same units (S14's guide arrow uses it).
- Every hex touches the hex it needs; `UpgradeCatalog` asserts this and that no two
  hexes share a cell, so the screen draws no link lines. A few chains open from a
  neighbour, as in the reference: Roll Speed I needs Roll Slot I, Luck I needs Roll
  Speed I, Golden needs Luck I, Diamond Machine needs Gold Rate I, Prism Machine needs
  Diamond Rate I, Capture Speed I needs March Speed I. Flock and Army Size open from
  Start (the Commander guide), Egg Value from Tools (Open) and Gold Machine from
  Player (Open); Open hexes count as owned.
- Main: Flock Size up-left, Egg Value straight up above Tools, Egg Speed up-right,
  Army (Open) beside Tools, Army Size to the left, Roll Slots I–VII zig-zagging down
  under Player, Roll Speed I–V diagonally down-right, Luck I–IV → Super Luck I–IV →
  Mega Luck I–IV arcing round the right (one family, 12 tiers, each chain its own
  clover and numbered 1–4), Golden → Rainbow → Shadow → Cosmic inside that arc, and
  the Gold, Diamond and Prism Machines stepping out to the lower left with their
  Rate I–IV chains hanging below.
- Tools: Back in the middle, Egg Vacuum down-left (Vacuum Capacity I–IV, Vacuum Range
  I–III), Chicken Feed down-right (Max Level I–III). Player and Army: chains around
  Back.

## Hexes

| State | Look |
|---|---|
| Owned / maxed | Bright Army green (#A3FF00 → #00D300) |
| Buyable now | Dark hex, gold price, red "!" badge |
| Not affordable (or held by the starter reserve) | Dark hex, red price |
| Locked, next to a visible hex | Grey "?" |
| Locked further out | Hidden |
| Start / Open / Back | Cyan / orange / red |

Each upgrade hex shows its icon, its name ("Egg Speed II") and a big tier number
over the icon (live text, never part of the art; the catalog's `numeral`, which
restarts at 1 for each Luck chain and is absent on mutations and single hexes). Open hexes carry a red count of
the upgrades inside that can be bought now (`badges[category]`). The HUD Upgrades
button shows `badges.total`. Prices on hexes are compact (1.2K); the card shows the
exact amount.


## Input (October 20 owner decisions)

- **Mouse:** hovering shows the card; a click buys at once.
- **Touch:** a tap buys at once and **no card is shown**, not even when another menu
  opens a node (the hex pulses instead). Dragging the map never buys.
- **Gamepad:** focus shows the card; A buys; the D-pad moves; X recenters; L1/R1 zoom.
- The backdrop stays **solid black**.

Tapping a hex you can't buy gives a short red message instead (the server's
reason, "Not enough Coins" or "Buy Egg Speed I first"). A purchase shows
"Egg Speed II: x1.25 → x1.5" (unlocks: "Chicken Feed bought!"), pulses the hex and
reveals the next hexes.

## Card

Name, the family description, current → next value in green, the price beside the
gold coin, and "Resets on Rebirth". Luck shows the server's Epic+ (or strongest
band) odds now → next from `upgradeTree.luck` (docs/team/LUCK_WINDOW.md), "All
normal chickens remain possible." and any limited event's podium chance.

`CashUpgradeNodes.Lines` gives some cards a clearer change line:
- Gold, Diamond and Prism Rate I–IV read `Config.GoldRolls` per tier ("Every 10 → 8
  rolls"; Gold 10/8/7/6/5, Diamond 100/85/70/60/50, Prism 500/425/350/300/250), and
  their machines "Every 100 rolls: x5 Luck" (owned "Owned: Every 100 rolls").
- Roll Speed shows the real roll time (Stevin): "4.0 s → 3.3 s", from
  `Config.RollRevealSeconds / (1 + rollingSpeed)` with any Gem Roll Speed included.
- Mutations: "1 in 250 rolls · x1.5 eggs" (Mutation Luck included).
- Max Level reads "Lv 10 → Lv 13" (`Config.MaxPetLevel` + feedMaxLevel).

## Mutations (tree v2)

Golden, Rainbow, Shadow and Cosmic are the four tiers of the `Mutation` family
(effect `mutations` = how many of `MutationCatalog.Order` can roll). They reset on
Rebirth like the rest of the tree (Stevin OK'd it). This replaces plan v2's rank
unlocks. `PlayerSession.mutationKeep` (S7) keeps what a live save already had: existing
saves keep Golden, plus Rainbow/Shadow/Cosmic by rank (1/5/10); RebirthService puts
the kept tiers back after each reset and RollService honours them.

## Icons

`ResearchAssets.upgrades` maps every catalog `icon` key to an image: S6's approved
set, uploaded October 20 (ids in `assets/upgrade-icons-20261020/upload-receipts.json`),
with the receipts' reused in-game art for Egg Speed, Egg Value, Luck, Flock Size,
Army Size, Roll Slot, Chicken Feed, March Speed, Health and Recovery. The top
machine is `prismMachine` in the catalog and `RainbowMachine` in S6's set. Start has
no S6 icon and keeps the Index art. Tree v2's new keys (`superLuck`, `megaLuck`,
`diamondRate`, `prismRate`, `feedMaxLevel`, `mutationGolden/Rainbow/Shadow/Cosmic`)
use S6c's icons (uploaded October 20, same receipts).

## For older callers

These keep working: `app.research:Open()`, `:Close()`, `:OpenNode(id)`,
`:OpenCash(key)` (a family id or an old board key such as `PlotSize` or `ArmySize`,
opening that family's next hex), `:Center(id)` (switches to the node's map),
`:Select(id, true)`, `.nodes[id].button`, `.selected`, `.root`, `:Now()` (server
clock) and `CashUpgradeNodes.NextId(key, state.upgradeTree)`. Unknown ids (old
research nodes such as `FuseMachine`) just open the tree.

Removed: research timers, researchers, Finish now (Robux), Pin goal, Cancel, the
"Your research works offline!" line, timed yard-build bars and the client-only
research position overrides (which caused the Auto Roll / Lucky Feathers II
overlap; the catalog now asserts one hex per cell).
