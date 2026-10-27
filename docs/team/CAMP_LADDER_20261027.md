# Camp ladder and readiness card (October 27, 2026)

Retention package, workstream WS1. Research and numbers: `retention-20261027/WS1-camp-progression-wall.md`;
integration decisions: `RETENTION_PLAN_20261027.md` (§3 C2, §4: Fort Roost 0.60, Army Size II
stays 6,000).

## Why

Live 1.25.0 (Oct 26–27): 24% of Cluck Camp winners ever won Fort Roost; 73% of Fort Roost
attacks started below even odds and won 1 in 1,215. No three-slot Army of the chickens a new
player rolls in the first 15 minutes reaches Fort Roost's 106 (three Commons are 57). After
Cluck Camp the only goal was a 10-second "Next up: conquer Fort Roost!" and a NEXT marker over
a camp the Army could not take.

## The ladder

`Config.CampLadder.Strength = {1, 0.6, 0.55}` multiplies each main-route camp garrison's hp
and damage, and the power shown for it (`Progression.Strength`, `Progression.CampPower`,
`BattleService` `campScale` = Rebirth enemy scale x strength, on every lane alike).

| Camp | Garrison (unchanged) | Stats power | Strength | Shown and fought | Should win at (x1.3) |
|---|---|---|---|---|---|
| Cluck Camp | 1 basic Chicken | 12 | 1 | 12 | 16 |
| Fort Roost | Warden, Archer, 2 Recruits | 106 | 0.60 | **64** | **84** |
| Ironbeak HQ | 2 Grunts Lv 2, Sapper Lv 2, Major | 192 | 0.55 | **105** | **137** |
| King | `KingEncounter` | 497 | – | 497 | 647 |

Guard species, stats, models, names and Kill Coins are unchanged (Kill Coins follow species
and level). Power is summed before rounding (`Progression.ScaledPower`): 106.7 x 0.6 = 64.
No saved field, no map change.

## Odds bands

`CampGuide.EvenRatio = 1.0`, `CampGuide.ReadyRatio = 1.3` (were 1.3 and 2.0): Very tough
below 1.0x, Close fight 1.0–1.3x, Should win from 1.3x. Live: 1.0–1.3x won about half,
1.3–2x 84%. `CampGuide.Difficulty` is used by the camp and Mission prompts; WS5 points
`TutorialGuide.CloseFightRatio/ShouldWinRatio` at the same constants.

## Readiness card (`src/shared/CampGuide.luau`)

Pure and snapshot-only (same answer in `TutorialService` and on the client). WS5's Camp chain
(priority 5 in `TutorialGuide`) calls `CampGuide.When(state, facts)` and
`CampGuide.Card(state, facts)`; the card is
`{id, text, target, node?, outside?, wrongTab?, index = 1, total = 1, tag = "NEXT: FORT ROOST", camp, progress = {value, goal, label = "ARMY 38 / 84"}}`.

- **When:** the tutorial is done, Cluck Camp is won, a later camp is not, and
  `Config.CampLadder.ReadinessTip`. Persistent; hidden while the Army is away.
- **Ready** (power ≥ `Goal` = ceil(camp power x 1.3)): `TipNextCamp2` "Your Army can take
  Fort Roost! Attack!" (`TipNextCamp3` for Ironbeak HQ), target `Camp<n>`.
- **Otherwise** the best power per Coin (`CampGuide.Advice`, ties → cheaper), read from the
  live quotes in the snapshot (podium offer prices incl. WS2's starter price, `nextSlot`, the
  Upgrades node offers, `upgradePrice`):

| Step | When | Card (affordable) |
|---|---|---|
| Equip | a manual Army leaves a stronger chicken home | `TipCampEquip` "Equip Best in My Army!" (no target) |
| Recruit | a podium offer with `improvesArmy` | `TipCampRecruit` "Buy the chicken on your podium!" → `RollStation` |
| Army Size | the next tier; new slots take the best spare or a basic Chicken | `TipCampArmySize` "Buy Army Size I for more Army slots!" → `Upgrades`, node `ArmySize<n>` |
| Feed | Chicken Feed owned, an Army chicken can level | `TipCampFeed` "Feed your Army chickens to level them up!" → `FeedTool` |
| Get Feed | Feed not owned (its price + the first level) | `TipCampFeedGet` "Get Chicken Feed to level up your Army!" → `Upgrades`, node `ChickenFeed` |
| Roll | an empty automatic slot with nothing on the podium, or nothing else | `TipCampRoll` "Roll a stronger chicken for your Army!" → `RollStation` |

  Short of the step's price: `TipCampSell` "Sell your eggs for Army Size I!" (`EggDeposit`)
  when the bag covers the rest, else `TipCampCollect` "Collect eggs: 1,200 more Coins for Army
  Size I!" (`Yard`; "for the chicken" / "for Chicken Feed" / "for Feed"). A purchase card shows
  only when affordable, so it never walks a short player into a Coins shortfall prompt.
- Example: three basic Chickens, 3 slots, 0 Coins → "Collect eggs: 1,200 more Coins for Army
  Size I!" with "ARMY 38 / 84".

## Prompt, warning, marker (`src/client/BaseController.luau`)

- Send Army ObjectText: `"<band> · Army 38/84 · 160–520 Coins/kill"` (was "· 4 defenders ·").
  Missions the same.
- Below 1.0x (`Config.CampLadder.AttackWarning`): the first Send Army only warns —
  "Fort Roost is too strong for your Army (38/84). Send Army again to attack anyway."
  (warning notice) — and the prompt reads "Attack anyway" for `CampGuide.ConfirmSeconds` (5 s);
  a second press attacks. Client signals `AttackWarned` / `AttackAnyway` (ledger
  `ui.AttackWarned` / `ui.AttackAnyway`). The world heading reads "⚔ VERY TOUGH" in gold
  instead of red "⚔ ATTACK". The server is unchanged: the player can always attack.
- The NEXT marker over the next camp shows only once the Army reads Should win there (or with
  `ReadinessTip` off); otherwise the card's own target carries it. The `TipCampRoll` card
  marks the lever, not the podium.

## Losing

A lost or drawn first try at an own-lane camp (`BattleService:Finish`, `ReadinessTip` on):
"Fort Roost held! +440 Coins from the fight. Get your Army to 84 power, then attack again."
(`CampGuide.DefeatText`; the Coins part only when Kill Coins were paid). No consolation Coins.

## Hooks

`BattleService.onFirstWin(attacker, campIndex, isKing)`: set by GameServer (WS7 social
moments), called once per player per own-lane camp first win (and the first King clear,
`campIndex` nil), after the result is applied; nil-safe, wrapped in `pcall`.

## Analytics (schema 16, ledger only)

- `camp.CampN.ready` / `camp.CampN.ready.play` (seconds of total play): the first time in a
  session the Army reads Should win at unbeaten camp 2 or 3 (`Analytics:Observe`).
- `camp.CampN.firstWin.play` (total play at the first win), `camp.CampN.firstWin.firstSession`.
- `ui.AttackWarned`, `ui.AttackAnyway`. `AnalyticsReport` camps rows gain `ready`, `readyPlay`,
  `firstWinPlay`, `firstSession`; `campWarnings = {warned, anyway}`.
- Targets (vs 1.25.0): Fort Roost / Cluck Camp first wins 24% → ≥55%; Fort Roost attacks below
  1.0x 73% → ≤20%; median play at the first Fort Roost win 8–12 min. Live rule: before minute
  8 move Fort Roost to 0.70; after minute 13 to 0.50.

## Checks

- `tests/CampGuideChecks.luau` (bands, goals, every card, copy, a real BattleService showing
  and fighting 64, the defeat line and `onFirstWin`); `tests/FoundationChecks` keeps
  12 / 106 / 192 for the guards and adds 12 / 64 / 105 for the ladder.
- `tools/sim/camp_probe.luau mode=fights` (real `Battle.luau` at Fort Roost x0.60: three
  Commons 0%, four Commons 92%, three Commons + an Uncommon 100%) and `mode=early`
  (guided by `CampGuide.Advice`; on the Wave 0 base without WS2's prices, Should win at
  p50 13.5 min with collection 0.6, 10.2 min at 0.85; unguided never by 30 min).

## Rollback

`Config.CampLadder.Strength = {1, 1, 1}` (ladder), `ReadinessTip = false` (timed card, old
marker, old defeat line), `AttackWarning = false` (prompt sends at once, red ATTACK heading).
The bands are the two `CampGuide` constants.
