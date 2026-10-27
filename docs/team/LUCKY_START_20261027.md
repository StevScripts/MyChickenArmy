# Lucky Start and roll discovery (October 27, 2026)

Retention package WS4 (plan: `docs/team/retention-20261027/WS4-roll-discovery.md`,
integration: `docs/team/RETENTION_PLAN_20261027.md`). Stevin: "dont ask me for permission
no more just do it".

## Why

Live 1.25.0: the median new player gets about five post-tutorial pulls. Their first
Uncommon came at post-tutorial pull 13 (reached by 14% of finishers) and the first Rare at
pull 87. Five favoured basic Chickens covered the whole session, the podium never said how
chickens differ, and finding a new chicken looked like buying the fifth basic Chicken.

## What players see

| Where | Text |
|---|---|
| Lever counter (top row, Luck clover, rarity colour) | "Uncommon in 2 Rolls", "Uncommon next Roll!", "Rare in 6 Rolls", "Rare next Roll!" |
| Podium tag during a forced pull (podium 1) | "Lucky roll · Uncommon!", "Lucky roll · Rare!" |
| Podium rarity line | "NEW!  Common · 1 in 17" (NEW! in gold) while the chicken is missing from the Index |
| Podium advice line (4th line) | "+18 Coins/s in your Flock", "Fills an Army slot", "Makes your Army stronger" (green); "Lays 6 Coins/s" (muted) |
| Manual pull past a kept offer | "Robo-Cluck (Rare) is still on your podium! Pull again to roll past it." |
| Recruit toast for a first find | "NEW CHICKEN! Bee Chicken · Index 4/83" over the usual Army line, Jingle, gold pulse |
| Reveal on your own podium | a gold "NEW!" float and the Badge cue for a chicken missing from the Index; a Rare plays RollRare; the first Rare ever adds the ScreenFeel celebration (Epic+ already had it) |

## Rules (server)

`src/server/LuckyStart.luau`, saved additive field `luckyStart = {pulls, nextU, nextR,
firesU, firesR}` (missing or malformed reads fresh; `DataRevision` unchanged).

- **Who:** empty-start profiles (`introRebirth ~= nil`) after a completed tutorial
  (`guideCompleted` or `coreDone`, not `guideSkipped`), for post-tutorial lever pulls
  1..`Window` (40). Manual and Auto Roll pulls count; the free starter roll and Playtime /
  Daily free rolls do not.
- **Uncommon:** on pull `k >= nextU` (starts at `UncommonAt` = 2) while no Uncommon+ is in the
  Index and fewer than `MaxForced` (2) were forced, podium 1 shows an Uncommon drawn by
  today's odds inside the Uncommon rarity (Luck applies inside it).
- **Rare:** the same with `RareAt` = 8, checked first; one forced podium per pull.
- **Push-back:** any Uncommon+ (Rare+) offer on any podium, natural or forced, moves the
  next one to `k + UncommonAgain` (5) / `k + RareAgain` (10).
- **Precedence on podium 1:** `debugNext > StarterLadder > paid 2x Luck guarantee > Lucky
  Start > FavoredRolls > normal draw`. A paid guarantee taking the pull makes Lucky Start
  wait one pull. Forced offers are never event/Rebirth-chicken replaced; `chance = 1`.
- **Counter honesty:** the counter shows only a guarantee that will still fire inside the
  window; nothing is shown once both rarities are owned, capped or past pull 40.
- **Guard** (`Guard = true`): a manual lever pull while a podium holds a Lucky Start offer,
  any Rare+ during Lucky Start, or the next Rebirth's find (`RebirthChickens.Wanted`, every
  profile) is refused once per offer; the next pull rolls. Auto Roll is never guarded.
  `rollPastWarned` is live only.
- **FavoredRolls** is 3 pulls x 50% (retention plan C1); Lucky Start wins over it.

## Offers, receipts and snapshot (interfaces)

- Offers carry `new = true` (missing from the Index when rolled) and `lucky = "Uncommon" |
  "Rare"` (podium 1 of a forced pull). WS2's starter quote: `price`, and `listPrice` when the
  quote is below the catalog price.
- `RollService:Buy` receipt: `firstFind = true` (species missing from the Index before this
  recruit), `found`, `total` (`IndexProgress.Count`), and `offer = {species, mutation,
  event, rebirthChicken, special, lucky, new, firstFind, rarity, price, listPrice}`.
- `state.luckyStart = {kind, left}` or nil; `state.offers[i].advice/improvesArmy`.
- `src/shared/IndexProgress.luau`: `Count(discoveredOrSession, eventOn?) -> (found, total)`
  and `Visible(species, everFound, eventOn?)`; the Index menu uses the same rule.
- RollStation attribute `RollLucky` on the station model during a forced pull.

## Analytics (schema 16)

`luckyStart.forced.<Uncommon|Rare><n>` (n = 1 or 2; one suffix, as launch names allow),
`luckyStart.bought.<kind>`, `luckyStart.guard.shown|rolledPast`, `roll.new.offer|bought`,
`index.first.<rarity>` (once per player) with `index.firstSeconds.<rarity>` (play seconds).
Roll funnel steps `UncommonOrBetter`, `Found5`, `LuckyRareSeen`.

## Numbers (`tools/sim/discovery_probe.luau`, real modules, 1 podium, Luck 0)

| Variant | Median first Uncommon / Rare pull | New species by pull 5 / 10 | Rare share, 40 / 300 pulls |
|---|---|---|---|
| Before (no Lucky Start, FavoredRolls 5 x 60%) | 13 / 86 | 1.37 / 4.08 | 0.69% / 0.77% |
| Live config, never buys | 2 / 8 | 2.95 / 6.32 | 5.68% / 1.42% |
| Live config, buys the first Uncommon+ and Rare+ seen | 2 / 8 | 2.94 / 5.99 | 3.11% / 1.07% |

Epic and up, the Luck window, LuckBands and every "1 in X" are unchanged; at most two
Uncommons and two Rares are ever forced per profile. `rarity_probe.luau` (fast, 1 h, 3
seeds) shows the same offer shares per rarity as before.

## Switches (rollback)

`Config.LuckyStart.Enabled = false` (no forcing, counter, Lucky tag or guard; saved counts
kept), `Config.LuckyStart.Guard = false`, `Config.Discovery.NewTag / Advice = false`,
`Config.Economy.FavoredRolls = {rolls = 5, chance = 0.6, species = "Duck"}`.

## Checks

`tests/LuckyStartChecks.luau` (headless: `runsuite.luau LuckyStartChecks`) and
`tools/sim/discovery_probe.luau trials=6000 pulls=40` (`pulls=300` for the share check).
