# Upgrades screen (October 20 overhaul, S9)

The full-screen Upgrades tree, rebuilt like Drop a Fruit's tree (reference:
`~/Documents/ChatGPT/My Chicken Army/output/2026-10-20-systems-guide/`,
`screenshots/c2-006.png` and `details/c2-012.png`). Decisions are in
[OVERHAUL_PLAN_20261020.md](OVERHAUL_PLAN_20261020.md); data shapes are in
[OVERHAUL_CONTRACT_20261020.md](OVERHAUL_CONTRACT_20261020.md) §4 and §8.

## Files

| File | Owns |
|---|---|
| `src/client/ResearchBrowser.luau` | The screen: maps, hexes, card, input, purchases |
| `src/client/CashUpgradeNodes.luau` | Data helpers over `UpgradeCatalog`: next node of a family, tier number, value text, legacy keys |
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
- All maps share one coordinate space and the established hex geometry; drag, wheel
  and pinch pan/zoom the open map.

## Hexes

| State | Look |
|---|---|
| Owned / maxed, and the free Egg Vacuum | Bright Army green (#A3FF00 → #00D300) |
| Buyable now | Dark hex, gold price, red "!" badge |
| Not affordable (or held by the starter reserve) | Dark hex, red price |
| Locked, next to a visible hex | Grey "?" |
| Locked further out | Hidden |
| Start / Open / Back | Cyan / orange / red |

Each upgrade hex shows its icon, its name ("Egg Speed II") and a big tier number
over the icon (live text, never part of the art). Open hexes carry a red count of
the upgrades inside that can be bought now (`badges[category]`). The HUD Upgrades
button shows `badges.total`. Prices on hexes are compact (1.2K); the card shows the
exact amount.

Links are drawn only where a prerequisite is not an adjacent hex (today:
`RollSpeed1` from Start, `CaptureSpeed1` from Army's Back).

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
normal chickens remain possible." and any limited event's podium chance. The Gold
Machine, Gold Rate, Diamond Machine and Prism Machine read S12's `Config.GoldRolls`
("Every 10 rolls: x2 Luck", "Every 10 → 8 rolls", "x2 → x5 Luck"); without it they
show only their description.

## Icons

`ResearchAssets.upgrades` maps every catalog `icon` key to an image: S6's approved
set, uploaded October 20 (ids in `assets/upgrade-icons-20261020/upload-receipts.json`),
with the receipts' reused in-game art for Egg Speed, Egg Value, Luck, Flock Size,
Army Size, Roll Slot, Chicken Feed, March Speed, Health and Recovery. The top
machine is `prismMachine` in the catalog and `RainbowMachine` in S6's set. Start has
no S6 icon and keeps the Index art.

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
