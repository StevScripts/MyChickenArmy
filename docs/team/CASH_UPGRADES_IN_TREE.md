# Cash upgrades moved into the tree — October 2, 2026

## One hex per track — October 14 (user decision; supersedes the tier hexes below)

Buying a cash upgrade no longer reveals a new hex further out. Each of the six
tracks is a single gold hex in its root cell beside Start. The hex stays put and
updates in place: `LV n/max` shows the owned count, the body shows the live
current → next value and the price is the live server quote. When the track is
full the hex turns green with a `MAX` badge and tapping it only inspects. The
tooltip title names the next tier ("Luck 7/20", "Flock Size → 100").

Node IDs are now `Cash<Key>` (e.g. `CashLuck`); `CashUpgradeNodes.Shown` returns
the presented tier. Prices, maxima, saved levels, server validation, research
positions and the `CashUpgrade` request are unchanged. The older sections below
describe the retired per-tier layout.

The user asked to move the six physical-board upgrades into the full-screen tree
and remove the board. This changes their location, not their economy or unlock rules.

## One connected tree with individual purchase tiers

The later October 2 correction explicitly rejects the detached cash-upgrade island.
Each existing purchase is now its own hex on one of six branches around Start.
For example, the roll branch is **2 Roll Slots → 3 Roll Slots → … → 8 Roll Slots**;
one slot is already owned at the beginning. The existing 91 cash purchases and
60 research purchases share one 152-node map, including Start.

Earned tiers remain green. The next tier displays the live server quote and
current→next benefit. The following tier is a question-mark frontier; later
tiers stay hidden until progression reveals them. Clicking a completed tier only
inspects its earned benefit; it cannot buy the next tier. Each first cash tier is
available from the start. Cash purchases apply immediately and never require a
research job, free researcher, camp, rank or King milestone.

Related research is interleaved between the cash branches. This is a client-only
composition change: no research prerequisite, duration, effect or saved ID changes.
There is no separate cash heading, group switch or cash-focused opening view.
The HUD Upgrades shortcut, U and R all open the same Start view. The former
three-card upgrade popup is no longer an active navigation destination.

| Track | Existing saved owner | Retained limit |
|---|---|---|
| Egg Laying Speed | `eggSpeedLevel` | 25 purchases |
| Egg Value | `incomeLevel` | 25 purchases |
| Luck | `luck` | 20 purchases |
| Plot Capacity | `plotSizeLevel` | Seven purchases, subject to authored plot support |
| Army Size | `capacity` | Existing configured deployment ladder; paid bonus retained |
| Roll Slots | `rollSlotsUnlocked` | Eight owned slots, bounded by authored podium count |

All configured prices, real benefits and saved levels remain unchanged. Research
bonuses still combine with those cash tracks. Egg Speed's next-value preview now
includes the existing research production bonus, matching its current value.
Instant egg deposits and the Giant/Colossal contracts remain untouched.

## Luck progress and odds — October 6

Cash Luck hexes show `Luck 1/20` through `Luck 20/20`, a Cash label, and MAX on
the final purchased tier. The next tier's tooltip states the owned count. Owned
nodes retain their historical base benefit; they never advertise a later tier's
reward as their own. The cap, prices, saved levels and purchase validation remain
unchanged.

The later October 6 [moving-window change](LUCK_WINDOW.md) uses
`epicPlusChance`/`nextEpicPlusChance` for the visible before/after probabilities.
`UpgradeService.Offers` also supplies `maxLevel`, current/next `window` records
and `windowText`, and retains the Rare+ fields for compatibility. Odds use the
same `Rules.Odds` as recruitment, including research and eligible paid Luck.
Percentages are per chicken in normal rolls; forced tutorial/guarantee results
and fixed crates are separate. Hexes use one decimal and tooltips two. Tooltips
describe the favored bands and full normal availability. No next chance or price
is offered at the cap, and loading never fabricates a zero-percent value.
If Epic+ rounds to the same percentage before/after, the next node uses `Top`
with `topBandChance`/`nextTopBandChance`; the tooltip calls these the strongest
chickens. This keeps late Luck gains visible after Epic+ has reached its plateau.

The six timed luck research nodes retain their names, IDs, prices and durations.
A Research label and tooltip identify their separate bonus, which combines with
cash Luck and replaces the previous research tier instead of adding all tiers.

Validation used a disposable Studio session: server/client startup succeeded;
24 isolated combinations covered levels 0/7/19/20, eligible paid Luck on/off and
research bonuses 0/0.35/1. Cap rejection preserved fixture cash, level and revision.
Client fixtures checked loading, next-tier odds, historical owned benefits, 19→20,
MAX with no price/action, and the Research label. No purchase requests were sent.
A desktop capture was inspected at Luck 7→8. Player saves were not modified;
phone layout and a complete live purchasing sequence were not exercised.

## Code contract

### Compact branch layout — October 6

The later spacing correction folds the long Luck, Egg Value and Egg Speed paths
into adjacent rows around the existing research. Individual tier hexes, their
purchase order, the six roots beside Start and normal node sizes remain intact.
This replaces the long straight rays; it does not shorten the upgrade ladders.
Coordinates belong to `CashUpgradeNodes` only. Research prerequisites, live quotes,
saved levels, the Luck 20/20 MAX state and odds previews are unchanged.

The follow-up applies the same compact layout rule to the remaining cash and
timed-research branches. Army Size, Plot Capacity, Roll Slots, timed Luck and Roll
Speed turn back into nearby rows instead of continuing as isolated straight tails.
Outer research and egg-upgrade nodes are brought into the same cluster. All
positions remain client-only; no saved research ID or prerequisite is rewritten.
All 153 current nodes now fit within eight axial hex steps of Start at the
existing node size. The cash paths and timed rolling paths retain adjacent
successive tiers; existing army/economy/command research positions are preserved.

No new gameplay or device playtest was run for this coordinate-only adjustment.

`UpgradeService` remains the sole owner of these offers and transactions. The
existing `state.boardUpgrades` snapshot field remains for compatibility; it is now
the tree's cash-offer source. `CashUpgrade` sends upgradeKey, expectedLevel and
expectedPrice to the same transaction as the legacy BoardUpgrade action.

The server no longer scans world boards or requires board proximity. It still
validates the loaded/non-closing/non-save-lost session, key whitelist, current
level/price quote, affordability, configured maximum and physical plot/podium
support. Transactions do not yield. Stale/duplicate requests cannot buy an
unexpected later level.

Cash hex definitions and research position overrides are presentation only,
separate from ResearchCatalog and its saved completion/job IDs. Existing saves
need no migration: Army tier completion is `offer.level - StartingSlots`, Roll
Slots is `offer.level - 1`, and other tracks use `offer.level`. Paid army bonuses
and physically active podium counts do not change which tiers are owned.
Physical unavailability dims an unowned next tier; it never marks it completed.
Pin and cancel are research actions and do not appear on cash hexes. Pending cash
purchases match their request ID; production receipt bookkeeping stays intact
without a duplicate large toast while the tree owns feedback.

The original board images are reused by asset ID. The client board binder is no
longer constructed, started or connected. Its source and the old upgrade menu
remain available as historical components; neither is an active purchase surface.

## Authored board archive

The exact source board is
`Workspace.MyChickenArmyMap.03_HomePlots.Model.UpgradesStand` (14 physical Parts,
including Screen). No additional UpgradesStand or UpgradesBoard SurfaceGui was
found in other authored plots or the fallback AuthoredHomePlot.

The board is moved intact to `ServerStorage.UpgradeBoardArchive20261002`, retaining
all original geometry, UI and properties. Its OriginalParentPath attribute records
the former parent. This removes it from Edit and from subsequent runtime map
clones. Other stations, the egg-deposit board, plots, fences and podiums remain.
Restoration requires moving the archived folder back and intentionally restoring
its old client binder; do not silently rebuild the retired board.

## Initial migration validation (before the connected-tier correction)

Verified in Pet Roll Test (`96683186622050`) through Studio Flow, using a disposable
`studio-session` with `PetRollPlaytestSessionOnly=true`:

- Nine `CashUpgradeChecks` groups passed: six portable transactions, both action
  aliases, stale/duplicate quotes, readiness/affordability, configured maxima,
  physical limits, full research queue, production preview and saved-field preservation.
- Real UI clicks bought all six upgrades. A temporary purchase-boundary ledger
  confirmed exact quoted debits for all six and no cash-created research jobs.
  The surrounding live balance can also increase from automatic egg deposits.
- Desktop and iPhone 13 landscape layouts inspected; all original icons loaded.
  Phone input purchased Egg Speed and Egg Value, started Field Notes research,
  switched back to cash and bought Plot Capacity with the sole researcher busy.
- Cash heading no longer overlaps nodes. Opening either group centers its own
  nodes; U, R and the focus control switch within the same full-screen map.
- Eight changed runtime modules compiled in Studio and matched local source hashes.
  Scripts-only Rojo packaging passed. No tree/upgrade runtime errors were observed;
  unrelated plugin settings errors and missing egg-deposit-effect warnings remain.
- Archived board retained all 14 physical parts. Both Edit and fresh Play had zero
  live UpgradesStand/UpgradesBoard objects. Other authored stations were preserved.

Studio was returned to Edit with device simulation off and temporary probes gone.
No publishing, asset uploads, persistent player-data changes or Git push occurred.

## Connected-tier correction validation

Fresh runtime confirmed 152 unique graph positions and all 91 cash tier mappings.
Real clicks bought two successive Roll Slot tiers and the first tier of each other
cash track. Every purchase turned its own hex green and revealed its successor.
Clicks on the future Roll Slot node and the already-owned node caused no purchase;
the two actual slot purchases debited the existing $1,200 and $4,800 quotes.
The original nine server transaction checks remain applicable: the backend was
not changed by this presentation correction.

Final desktop and iPhone 13 landscape captures show a shared Start, six immediate
cash roots and interleaved research. All 152 positions are unique. Fifteen subdued
links bridge deliberate research gaps; every graph edge spans at most two cells.
The phone's Roll Slot target measured approximately 57×65 UI pixels; tapping it
bought the tier, made it green and revealed 3 Roll Slots. The separate heading and
group-switch controls are absent. All three changed modules compiled and matched
their Rojo-synced sources; scripts-only packaging passed. No new tree errors were
observed. Existing unrelated plugin and egg-deposit-effect warnings remain.
Studio is back in Edit with device simulation off; no persistent profile or
published place was changed by the checks.

## Tile kinds read at a glance — October 7

Cash tiers stay instant (91 cash tiers against one researcher slot would stall
spending). Timed research hexes carry a cyan rim and a clock badge with the
duration. Cash hexes carry a gold rim and a level badge: `LV 2/7` on the tier you
can buy, a green `LV n` once earned, and `MAX` on a track's last tier. Hexes show
the track name ("Army Size", "Flock Size"); tooltips and feedback keep the tier
name. Only tiles you can act on now (affordable, and for research a free
researcher) glow at full strength; the rest show a dimmed rim. Frontier "?" hexes
are smaller and half transparent.
