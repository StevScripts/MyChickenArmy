# Auto Roll and Gold rolls (October 20 overhaul, S12)

Owner decisions, October 20 (Stevin, session S12). Stevin had no HUD reference, so
the HUD follows the common Roblox RNG-game pattern he approved: Sol's RNG's Roll
button with an Auto Roll toggle and typed "rarer than" values, and Slime RNG's
Golden and Diamond rolls. He picked "stop at a value, like 1 in 20,000". This
replaces the October 15 research version (history at the end).

## Auto Roll

- **Unlock:** the Auto Roll Gem Upgrade (`GemUpgradeCatalog.AutoRoll`, effect
  `autoRoll`). Locked requests reply "Unlock Auto Roll in Gem Upgrades." Old
  research owners got the Gem Upgrade in S7's save conversion.
- **Runs on the server, from anywhere.** `RollService:StepAuto` runs every 0.25 s
  from `GameServer:Step` once the lever is ready. It does these in order:
  1. **Auto-recruit:** buy each podium offer whose zero-Luck odds are `recruitAt`
     or rarer, if the player can afford it (`CanSpendCash`, starter reserve,
     storage cap). Each recruit gets the normal Buy analytics, walks home and
     shows the usual recruit notice.
  2. **Hold:** if an offer is worth keeping, stop rolling and keep it on its
     podium. A hold lasts until the player recruits it, skips, changes a setting
     or pulls the lever.
  3. **Roll:** otherwise pull the lever (it counts toward Gold rolls).
- **Worth keeping** (`RollService.Keeper`):
  - Rebirth chickens, always (plan v2).
  - Any mutation, with **Stop on mutations** on (default on).
  - Odds of 1 in `stopAt` or rarer (default 1 in 1,000).
  - With **Stop on Army upgrades** on (default on), a chicken stronger than the
    weakest chicken in the Army the player picked. October 20 fix: the old rule
    read the automatic best list, so after a hand-picked Army it stopped for
    chickens that would not join. An empty slot counts only while the Army is
    automatic.
- The alert shows the best keeper: Rebirth chickens first, then the rarest.
- **Settings** (saved `autoRoll`, read by `AutoRollRules.Read`, lenient):
  `{enabled, stopAt, recruitAt?, mutationStop, upgradeStop}`.
  - Values are whole "1 in N" numbers from 2 to 10,000,000. `recruitAt = nil`
    means auto-recruit is off.
  - Old saves convert: "Upgrade" turns on Stop on Army upgrades with 1 in 1,000;
    a rarity name becomes that rarity's most common member's odds.
  - Limited (event) chickens have no catalog odds, so they compare by their
    offer chance.
- **Requests:**
  - `SetAutoRoll {enabled?, stopAt?, recruitAt? (number, or false for off), mutationStop?, upgradeStop?, skip?}`.
    `skip=true` rolls on past the current podiums.
  - `RecruitHeld {offerId}` recruits from the alert without walking over; it is
    reported as a Buy.
- **Snapshot** `state.autoRoll`:
  - `{enabled, unlocked, stopAt, recruitAt, mutationStop, upgradeStop, holding, held}`.
  - `held = {offerId, slot, species, level, price, mutation, oneIn, reason,
    rebirthChicken, canAfford, storageFull, special}`.
  - The roll camera's lighter Auto Roll mode still reads `enabled` and `unlocked`.

### HUD

- **Button** (`HudController`): the October 16 text toggle (green ON, red OFF,
  gold PAUSED).
  - It moved up the right edge, under Rebirth, so it clears the phone jump button.
  - A gear on its left opens the settings, and "Stops at 1 in 1,000" sits
    underneath.
  - While Auto Roll holds a chicken, pressing it brings back the alert.
  - The Gold Rush chip still sits above it.
- **Settings popup** (`AutoRollMenu`, also "Auto Roll settings" in Settings):
  - Auto Roll ON/OFF.
  - Stop at: −, "1 in [typed value]", +. The −/+ step through
    `Config.AutoRoll.Presets`. A line says what the value covers, like
    "Stops for 9 chickens (Mythic and up)".
  - Auto-recruit ON/OFF with its own value.
  - Stop on mutations, Stop on Army upgrades.
  - A footer with the Rebirth-chicken rule and the Gold Machine count.
  - The header icon is the uploaded Auto Roll icon (rbxassetid://83070773137079).
- **Hit alert:** a top-center card.
  - It shows "1 in 23,400!" (or "Rebirth chicken!") in the rarity color, the
    chicken portrait, name, rarity, any mutation, the reason, and the price with
    the gold coin.
  - Recruit works from anywhere ("Need N Coins" when short); Skip rolls on.
  - The X hides it and keeps the hold.
  - It waits while a menu, popup, dialogue or the intro film is up.
- UI Lab stories: "Auto Roll settings" and "Auto Roll hit alert".

## Gold rolls

- **Tree nodes:** Gold Machine → Gold Rate I–II → Diamond Machine → Prism Machine
  (effects `goldMachine` 1/2/3 and `goldRate`; S7's tree; the name "Prism Machine"
  was confirmed by Stevin).
- **Rule** (`GoldRolls.luau`, numbers in `Config.GoldRolls`):
  - With the Gold Machine, every Nth lever pull (manual or Auto Roll) is special:
    N = 10 / 8 / 6 for Gold Rate 0 / I / II.
  - On a special pull every podium rolls with ×2 (Gold), ×5 (Diamond) or ×10
    (Prism) Luck. That multiplies the Luck term, so every rarer chicken becomes
    likelier.
  - Mutation odds are unchanged.
  - The count is saved in `goldRolls.count`, resets on Rebirth, and is not counted
    without the machine.
- **Machine counter** (`RollStation`): the machine icon and "N Rolls Left" over the
  roll machine, then "Next roll is Gold!" in the kind's color.
  - The client pulses it while ready.
  - Icons: GoldMachine 75354767460656, DiamondMachine 113120386630417, Prism
    (the RainbowMachine art) 90010215769789.
- **Special pull** (`RollPresentationController`):
  - Every podium glows in the kind's color (Prism cycles the rainbow).
  - A "Gold roll · 2x Luck" tag shows until just after the reveal.
  - A notice appears when the player is too far away to see it.
- **Snapshot** `state.goldRolls = {machine, kind, every, count, left, luck, ready}`.

## Analytics (observation only)

- `autoroll.stop` (detail: rebirth, mutation, rarity or upgrade).
- `rebirthChicken.offered` and `.bought`.
- The new LaunchCount names below are ignored until S7 appends them to
  `AnalyticsSchema.LaunchCounters`: `goldRoll.pull.<Kind>`, `autoRoll.recruit`,
  `autoRoll.recruitHeld`, `autoRoll.skip`.

## Checks

`tests/AutoRollChecks.luau` (isolated sessions; run in a Run-mode playtest:
`require(game.ServerStorage.PetRollTests.AutoRollChecks).Run()`). It covers:

- save conversion and the save round trip;
- −/+ steps and the "1 in X" text;
- Gold roll cadence and the Luck boost;
- hold, remote recruit and Skip;
- auto-recruit affordability;
- the Army upgrade fix, Rebirth-chicken stops and request validation.

## History

October 15 (superseded): a free research unlock with stop-on-good only. The stop
setting cycled "Army upgrade", Rare+ … Secret in Settings; the button sat at the
bottom right; holds showed only a banner.
