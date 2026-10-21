# Upgrades screen (October 20 overhaul, S9; tree v2 S9c)

The full-screen Upgrades tree, rebuilt like Drop a Fruit's tree (references:
`~/Documents/ChatGPT/My Chicken Army/output/2026-10-20-systems-guide/`
`screenshots/c2-006.png` and `details/c2-012.png`; tree v2 from Stevin's three Desktop
screenshots `Screenshot 2026-10-20 at 10.02.57 PM`, `10.03.21 PM` and `10.04.17 PM`,
each with a U+202F before "PM"). Decisions are in
[OVERHAUL_PLAN_20261020.md](OVERHAUL_PLAN_20261020.md); data shapes are in
[OVERHAUL_CONTRACT_20261020.md](OVERHAUL_CONTRACT_20261020.md) §4 and §8.

October 21 reference parity (P3, [REFERENCE_PARITY_20261021.md](REFERENCE_PARITY_20261021.md)
§2.3): the presentation now copies Stevin's third Drop a Fruit recording 1:1
(`~/Documents/ChatGPT/My Chicken Army/output/2026-10-21-recording-3/frames/` t9, t11,
t13, t15, t17, t23/t27). Positions, the catalog, prerequisites, prices and the server
are unchanged. Where this file and an older note disagree, the sections below win.

## Files

| File | Owns |
|---|---|
| `src/shared/UpgradeCatalog.luau` | The tree: families, tiers, hex cells (`walk` steps), per-tier names/icons/numbers (`labels`) |
| `src/client/ResearchBrowser.luau` | The screen: maps, hexes, card, input, purchases; `Browser.Grid` |
| `src/client/CashUpgradeNodes.luau` | Data helpers over `UpgradeCatalog`: next node of a family, tier number, value text, special card lines, legacy keys; `PreviewTree()` (UI Lab fixture only) |
| `src/client/ResearchAssets.luau` | `Assets.upgrades[iconKey]`: one image per catalog `icon` key |
| `src/client/HudController.luau` | The red count on the HUD Upgrades button (`UpdateUpgradesBadge`) |
| `src/client/ResearchExtras.luau` | Rally (now a Gem Upgrade) and the older Formations/Missions pages |

The server owns every status, price and badge. The screen reads
`state.upgradeTree = {families, nodes={[id]={status, price?, spendReason?}}, badges, luck}`
and buys with `BuyUpgrade{nodeId, expectedPrice}`. Layout, names, icons and value
text come from `UpgradeCatalog`; the client never computes a price. The one
exception is `CashUpgradeNodes.PreviewTree()`: when the app is the UI Lab's display stub
(`app.editPreview`) and its fixture has no `upgradeTree`, the screen shows a made-up
snapshot (about half of each family owned, every third family's next tier too
expensive, base catalog prices) so the Edit-mode "Upgrades" story renders every hex
state. A live client never reaches it.

## Screen (October 21 reference parity)

- **Backdrop:** the blurred world (`AppController:SetMenuBlur("research", true)` on
  Open, released on Close) under a black tint at 35% transparency. This supersedes the
  October 20 "solid black" decision; Stevin found black hard to read and asked for the
  reference. No title and no dark top/bottom bands: the map runs edge to edge.
- **Bottom centre:** a wide red **Close** button on Main, renamed **Back** in a subtree
  (the reference's). Its rectangle is screen-height relative (0.23 x 0.064 of the
  height); the hit area grows to about 48 px on a phone (844 x 390), mostly upward,
  without moving the art. Back plays the map-change cue, Close the tree's close cue (no
  extra Click). The top-right red **X** stays (it closes from any map) for the phone pads.
- **Upper left (the `Wallet` column):** the Gold / Diamond / Prism "N Rolls Left" rows
  with their dice (`state.goldRolls.counters`, `GoldRolls.Icons/Colors/Text`; only the
  machines the player owns), then the Coins pill (coin + gold amount; counts up on
  gains, drops at once on spends). A count that changes while the tree is open (Auto
  Roll keeps rolling) punches its row. One column in screen-height units, the same on
  every device.
- **A buy:** a red "-2,850,000" pops beside the Coins pill, holds 1.1 s and fades
  (reduced motion: shows, then hides). No line of text for an ordinary tier (the hex's
  flash, ripple, confetti and link sparks are the payoff); unlocks (Egg Vacuum, Chicken
  Feed, the machines) keep the server's how-to line in the tree, since it says what to
  do next.
- **A refused buy** (the reference's t23): the shared red top banner (`app:Notify(text,
  false)`), the hex's rim flashes red and wiggles, and one soft Locked cue (it shares
  the banner's voice key, so the banner's Error does not double it). The text is
  "You need 3,096,960 more Coins!" from the server's price and balance; a starter
  reserve hold shows the server's reason ("Keep 600 Coins for Army Size I in
  Upgrades."); a locked hex says "Buy Egg Speed I first". A server refusal with its
  plain "Not enough coins." is shown as the same shortfall line.

## Maps

- **Main** opens around Start. The orange **Tools**, **Player** and **Army** hexes
  say "Open" and lead to their subtrees; a red **Back** hex sits in each subtree's
  middle with the category name under it.
- Every visit starts on Main. Back returns to Main where the player left it; Close
  (X), Escape or gamepad B on Main returns to play. Gamepad B in a subtree goes Back.
- All maps share one coordinate space; drag, wheel and pinch pan/zoom the open map.

## Layout (tree v2, Stevin October 20)

- Flat-topped hexes (164 x 144) in axial cells, like the reference. October 21
  (Stevin): the three Open hexes touch Start and alternate with green ones: Tools
  (Open) upper left, Player (Open) upper right, Army (Open) below. The pointy-top hex art
  is turned a quarter, so no new upload was needed. `Browser.Grid = {step=133.4,
  row=154, width=164, height=144, flat=true}`; `Browser.Grid.Offset({q,r})` is a cell's
  centre offset in the same units (S14's guide arrow uses it).
- Every hex touches the hex it needs; `UpgradeCatalog` asserts this and that no two
  hexes share a cell, so the screen draws no link lines. A few chains open from a
  neighbour, as in the reference: Roll Speed I needs Roll Slot I, Luck I needs Roll
  Speed I, Golden needs Luck I, Diamond Machine needs Gold Rate I, Prism Machine needs
  Diamond Rate I, Capture Speed I needs March Speed I. Flock, Egg Speed and Roll Slot
  open from Start, Army Size from Army (Open), Egg Value from Tools (Open) and Gold
  Machine from Player (Open); Open hexes count as owned.
- Main (October 21, Stevin: "not a straight line", then "I really hate the
  crampedness", put things where they make sense; supersedes the tight bands and the
  round cluster): each topic has its own side, and every chain is a zig-zag lane with
  an empty row between lanes, so chains only touch where one opens from another.
  - Eggs, left: Egg Value from Tools, Flock Size I–VIII below it, Egg Speed up from
    Start.
  - Army, lower left: Army Size from Army (Open).
  - Rolls, right: Roll Slots I–VII, then Roll Speed I–V, then Luck I–IV → Super Luck
    I–IV, with Mega Luck I–IV turning back under Super Luck (one family, 12 tiers,
    each chain numbered 1–4). Golden → Rainbow → Shadow → Cosmic go down-left from
    Luck I.
  - Special rolls, upper right: from Player (Open), three lanes stacked like a ladder:
    Gold Machine + Gold Rate I–IV, Diamond Machine + Diamond Rate I–IV, Prism Machine
    + Prism Rate I–IV, each machine at the left end of its lane.
- Tools: Back in the middle, Egg Vacuum down-left (Vacuum Capacity I–IV, Vacuum Range
  I–III), Chicken Feed down-right (Max Level I–III). Player and Army: chains around
  Back. Every chain in every map zig-zags; none runs in a straight line.

## Hexes

| State | Look |
|---|---|
| Owned / maxed | Bright Army green (#A3FF00 → #00D300); no price (art decision: the reference's are blue) |
| Buyable now | Dark hex, red "!" badge at its top right, GREEN coin price |
| Not affordable (or held by the starter reserve) | Dark hex, RED coin price, no badge |
| Locked, next to a visible hex | See-through grey ghost with a dark "?" |
| Locked further out | Hidden |
| Start / Open / Back | Cyan / orange with the red count badge / red |

Hex layout (reference t9, t11, t15): the icon fills the hex's upper middle; the name
("Egg Speed II") runs across the hex over the icon in one white stroked line (it may
pass the hex's edges; TextScaled shrinks long names); the tier numeral (`node.numeral`,
the catalog's: Luck's Super/Mega chains restart at 1) sits big in the icon's
bottom-right corner, as in the reference (this reverses the October 21 morning "no
number over the icon" note at Stevin's request for the reference 1:1); the coin and
compact price (1.2K) sit on the hex's bottom edge. Every label carries a black outline
so it reads over any hex and any world behind the tint. A hovered or focused hex grows
to 1.12x and draws over its neighbours. Open hexes carry a red count of the upgrades
inside that can be bought now (`badges[category]`); the HUD Upgrades button shows
`badges.total`. A "!" that appears while the tree is open (a price turned green as
Coins came in) or a hub count that rises punches the badge with one Badge chime (not
on a purchase render, which has its own payoff).


## Input (October 20 owner decisions)

- **Mouse:** hovering shows the card beside the hex; a click buys at once.
- **Touch:** a tap buys at once and **no card is shown**, not even when another menu
  opens a node (the hex pulses instead). Dragging the map never buys.
- **Gamepad:** focus shows the card; A buys; the D-pad moves; X recenters; L1/R1 zoom.
- Close (bottom button or X), Escape or gamepad B on Main returns to play; the
  bottom button and gamepad B in a subtree go Back.

Tapping a hex you can't buy shows the red banner (see Screen above). A purchase
pulses the hex, flashes it in its lane colour, shows the red spend beside the Coins
and reveals the next hexes.

## Card

Reference t15/t17: a dark translucent slate (#1A2028 at 8%) with a 2 px dark stroke
and square corners, beside the hex (right of it, or left when there is no room; its
top near the hex's top; never under the bottom button). The name; one effect sentence
in light grey with the changing value in green (the family description, then
"x1.25 → x1.5", "Every 10 → 8 rolls", or what an owned tier gives), RichText; a
divider; the gold coin and exact price on a faint gold strip (gold, red when too
expensive or held); and "Resets on Rebirth". Every line is stroked. Luck shows the server's Epic+ (or strongest
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
