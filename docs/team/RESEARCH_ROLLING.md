# Slime RNG-inspired research — October 2, 2026

The user supplied the complete Slime RNG tree image and
[May 16 tree viewer](https://wtfmedium.github.io/slime-rng/16_05_2026.html), asking to
use upgrades that better fit Chicken Army's collecting loop. The Mini War-derived
full-screen presentation and existing research timers remain in place.

## Reference coverage and choices

The linked page contains 165 entries: 104 main-tree upgrades, two navigation
nodes, 38 Loot upgrades and 21 Player upgrades. The evidence inventory covers all
of them, including the two secondary trees omitted from the supplied screenshot:
`/Users/stevin/Documents/ChatGPT/My Chicken Army/style-guide/slime-rng-research-20261002/`.
The source gives names, descriptions, costs and screen positions. It does not
provide a prerequisite graph, probability formula, stacking rules or game code.
Its Golden Rolls description says "every 0th roll" and its Speed Rolls price uses
"rolls" instead of dice; neither ambiguity is used as a game specification.

| Reference family | Chicken Army treatment |
|---|---|
| Ordinary/Super/Ultra luck | New six-tier Rare+ recruitment-luck research path |
| Roll Speed through Lightning Rolls | New six-tier podium-speed research path |
| Coin Income, offline loot, pickup magnet | Existing egg value, egg production, offline allowance and egg magnet branches already supply the relevant benefits |
| Walk speed, companion range, target rewards | Existing player/army movement and NPC bounty research retained; range changes omitted because current combat targeting is a separate mechanic |
| Equipped slime capacity, extra roll columns | Existing cash Army Size and physically authored Roll Slots remain available without research gates |
| Backpack, teleport, auto roll | Inventory and My Base remain freely accessible; no new gate on them. Auto Roll is not an existing feature and is not silently introduced |
| Periodic Golden/Diamond/Void/Galaxy rolls, bonus rolls/clovers | Deferred: need a separate cadence/queue and truthful outcome-odds design, independent of the verified paid guaranteed-offer schedule |
| Shiny/big/huge/inverted units and enemies | No new roll mutation or Giant chance. Guaranteed triple fusion and Colossal limits stay authoritative |
| Enemy counts/spawn speed, player weapons, marked targets, food/boost loot, goop/rebirth | Not transplanted: these require different encounter, drop, combat or rebirth systems |
| Friend cap/friend luck | No friendship-dependent progression gate or added social multiplier |

These are selected ideas with Chicken Army tuning, not Slime RNG's economy or
unverified formulas. No reference artwork is imported.

## Added progression

Twelve new paid research nodes bring the tree to **60 paid nodes plus Start**.
L1 begins directly at Start. R1 branches from L1. Each later tier follows the
previous tier in its own family. All 60 prerequisite links join adjacent axial
cells; the map keeps its existing pan, zoom and local reveal rules.

| ID | Upgrade | Total research bonus | Cash | Base time |
|---|---|---:|---:|---:|
| L1 | Lucky Feathers I | +10% Rare+ roll luck | 750 | 30s |
| L2 | Lucky Feathers II | +20% | 7,500 | 2m |
| L3 | Lucky Feathers III | +35% | 75,000 | 10m |
| L4 | Super Luck I | +50% | 750,000 | 30m |
| L5 | Super Luck II | +75% | 7,500,000 | 2h |
| L6 | Super Luck III | +100% | 50,000,000 | 8h |
| R1 | Roll Speed | +10% podium roll speed | 1,500 | 1m |
| R2 | Faster Rolls | +20% | 15,000 | 3m |
| R3 | Rapid Rolls | +30% | 150,000 | 15m |
| R4 | Quick Rolls | +40% | 1,500,000 | 1h |
| R5 | Speed Rolls | +50% | 15,000,000 | 4h |
| R6 | Lightning Rolls | +60% | 75,000,000 | 12h |

The highest completed tier replaces earlier tiers in the same family. Existing
research-speed bonuses shorten new research jobs, as before. Prices/times are
initial tuning, not a claim about measured player progression hours.

## Authoritative behavior

`rollingLuck` multiplies Rare+ roll weights by `1 + bonus` alongside existing cash
Luck and eligible paid luck. Normalization still occurs across the complete
roster. A +100% weight bonus does not promise twice the normalized probability.
The Odds view, shop comparison and cash-upgrade current/next display use the same
research bonus as actual rolls. Already-generated offers retain their odds.

`rollingSpeed` multiplies roll frequency by `1 + bonus`. A roll freezes its reveal
and cooldown duration when accepted: `2.4 / (1 + bonus)` seconds. At the final tier
that is 1.5 seconds. Research finishing during an animation never changes that
roll's deadline. The server rejects another roll and an early recruit until the
same reveal deadline. Station timing, camera tween and cosmetic beats use the
frozen duration, including for other players watching the podium.

A roll remains a free lever pull producing one cash offer per unlocked physical
podium; it does not award chickens or increase the podium count. Recruit prices,
paid entitlements, guaranteed-offer schedule and debug treatment are retained.

All existing research IDs, prerequisites, prices, effects and saved completions
remain intact. Existing military upgrades are a separate optional path; nothing
already earned is repurposed into another benefit. The new IDs use the existing
optional research structure, with zero default bonuses and no DataStore schema
migration. Cash upgrade maxima, board prices, slots, instant egg sales and all
fusion/Colossal rules remain unchanged.

## Implementation owners

- `ResearchCatalog`, `ResearchRules`: new nodes, coordinates and default bonuses.
- `Rules`, `RollService`: normalized random odds and authoritative frozen rolls.
- `PlayerSession`, `CommerceService`, `UpgradeService`: truthful odds/multiplier snapshots.
- `RollStation`, `RollPresentationController`: replicated frozen duration and presentation.
- `ResearchAssets`: reuse the approved Luck illustration and existing speed icon.

## Verification and evidence

- Nine isolated rolling checks passed: every-tier normalized odds/draw agreement,
  snapshot/shop/board consistency, fixed accepted timing, early-buy/cooldown
  rejection, replicated station duration, paid guarantee/debug behavior and
  unchanged default timing/physical slots.
- All 27 existing research regression checks passed with the expanded catalog,
  including save compatibility, quotes/refunds, offline jobs, farming, combat,
  formations, Operations and Colossal filtering.
- A real mouse click started Lucky Feathers I. Its 30-second timer completed
  naturally, applied +10% rollingLuck, and made R1 available while correctly
  marking unaffordable L2.
- A disposable developed-progress fixture completed L6/R6. A real GameServer Roll
  request near the authored lever produced a 1.5-second deadline. Client station,
  shuffle preview and camera all reported the same accepted duration and settled
  after reveal. A narrow duration-replication camera retarget fix was included.
- All changed runtime modules compile in Studio and match local sources. Rojo
  scripts-only packaging and scoped whitespace checks passed.

Evidence: `.dream-loop/slime-research-20261002/checks.json`, `fresh-tree.jpg` and
`rolling-branch.jpg`. The developed screenshot uses granted research/cash in a
SessionOnly fixture, not earned live progress. No purchase, publication, save
migration or persistent player-data mutation was performed. Studio is stopped in
Edit mode; the temporary runtime probes disappeared with the Play session.

The new effects were checked on desktop. The previous phone-safe Research layout
is unchanged, but this pass did not repeat physical-device/controller or phone
simulator checks. No measured multi-hour balance claim is made. Existing unrelated
plugin errors and missing EggDepositEffects warning remain outside this change.
