# Auto Roll and Gold rolls (October 20 overhaul, S12 + S12b)

Owner decisions, October 20 (Stevin):

- **S12b, later the same evening:** copy Drop a Fruit's Auto Roll board 1:1 in My
  Chicken Army's art style, from his second recording
  (`~/Downloads/ScreenRecording_10-20-2026 20-54-22_1.MP4`: the board at 98–126 s,
  the banner at 124 s, the two machine counters at 6 s and 110 s).
- That replaces the typed "1 in X" stop (S12). Auto-recruit is dropped.
- When Auto Roll finds a chicken there is only the banner, exactly like theirs (no
  Recruit/Skip card).
- Diamond rolls come every 100 pulls and Prism rolls every 500.

## Auto Roll

- **Unlock:** the Auto Roll Gem Upgrade (`GemUpgradeCatalog.AutoRoll`, effect
  `autoRoll`). Locked requests reply "Unlock Auto Roll in Gem Upgrades."
- **Panel** (`AutoRollMenu`, a Frame under `PetRollGui`):
  - Later October 20 owner request: the HUD Auto Roll button itself turns Auto Roll
    on/off. A gear button just left of it pops this board out beside it (bottom edges
    level), with no blur; the gear, the X, Esc/B or a press anywhere outside closes it
    (that press still reaches the world or the HUD toggle). "Auto Roll settings" in
    Settings opens it too.
  - It is their board in our style: square shell, studded Army-green header with the
    Auto Roll icon (rbxassetid://83070773137079), a dark see-through body, Source
    Sans Bold. The power pill moved out of the header to the HUD button.
  - "Stop When Appear" is a scrolling list (four rows at a time) of rows with the
    name in its color and a red OFF / green ON pill.
  - A bottom "< Rarity >" switcher with blue arrows pages through:
    - **Rarity:** Secret, Mythic, Legendary, Epic, Rare, Uncommon, Common (rarest
      first, like theirs).
    - **Mutation:** Golden, Rainbow, Shadow, Cosmic, Normal (no mutation).
    - **New:** New Chicken (not in the Index yet), New Mutation (a mutation that
      chicken doesn't have among the chickens you own).
- **Rule:** any ON row stops Auto Roll. The recording stopped for a Rare with every
  mutation row OFF. Rebirth chickens always stop it.
- **Defaults** for a fresh save: Legendary, Mythic and Secret on, the four mutations
  on, New Chicken on.
- **Server** (`RollService:StepAuto`, every 0.25 s from `GameServer:Step`, from
  anywhere):
  - With the lever ready, it holds while a chicken worth keeping waits on a podium
    (the best one: Rebirth chickens first, then the rarest), else it pulls the lever.
  - The player ends a hold by recruiting the chicken at its podium, pulling the lever,
    or turning Auto Roll off and back on with the HUD button. Turning it back on rolls on
    past the chickens already on the podiums.
- **Hit banner:** "Auto Roll found a Rare chicken!" in big outlined blue across the
  top, with confetti, for 3 s, once per find.
  - Other lines: "…an Epic chicken!", "…a Golden chicken!", "…a new chicken!",
    "…a Rebirth chicken!".
  - Reduced motion keeps it still and skips the confetti.
  - The HUD button turns gold (PAUSED) while it holds.
- **HUD button** (`HudController`): "Auto Roll" over ON / OFF / PAUSED (green / red /
  gold), on the right edge under Rebirth, clear of the phone jump button. A press flips
  ON/OFF at once (PAUSED → OFF); the gear (`AutoRoll.Settings`) opens the board.
  The gear is hidden until the mouse is over the button or the gear (owner request);
  it also shows while either is gamepad-selected, while the board is open, and for 4 s
  after a touch press, since phones have no hover.
- **Saved `autoRoll`** (`AutoRollRules.Read`, lenient):
  - Shape: `{enabled, rarities={[rarity]=true}, mutations={[id or "Normal"]=true},
    newChicken, newMutation}`.
  - The save also writes the old `stopAt`/`mutationStop` fields so an older server
    reads something close.
  - Old saves convert: a "1 in X" (S12) or a rarity name (October 15) turns on the
    nearest rarity and every rarer one; Stop on mutations turns on the four mutation
    rows.
- **Request:** `SetAutoRoll {enabled?}`, `{rarity, on}`, `{mutation, on}`,
  `{newChicken}` or `{newMutation}`.
- **Snapshot** `state.autoRoll`:
  - `{enabled, unlocked, rarities, mutations, newChicken, newMutation, holding, held}`.
  - `held = {offerId, slot, species, mutation, reason, rarity, banner}`.
  - The roll camera's lighter Auto Roll mode still reads `enabled` and `unlocked`.

## Gold rolls

- **Tree nodes:** Gold Machine → Gold Rate I–II → Diamond Machine → Prism Machine
  (`goldMachine` 1/2/3 owns Gold, then also Diamond, then also Prism; `goldRate`).
- **Rule** (`GoldRolls.luau`, numbers in `Config.GoldRolls`):
  - Each machine counts lever pulls on its own (manual or Auto Roll): Gold every
    10th pull (8th / 6th with Gold Rate I / II), Diamond every 100th, Prism every
    500th.
  - A special pull rolls every podium with ×2 / ×5 / ×10 Luck. If two land on one
    pull, the bigger boost wins.
  - Mutation odds are unchanged.
  - Saved `goldRolls = {count (Gold), diamond, prism}`, reset by a Rebirth.
- **Machine counters** (`RollStation`):
  - One row per owned machine over the lever machine, Gold above Diamond above
    Prism, as in the recording: "6 Rolls Left", "98 Rolls Left", "1 Roll Left".
  - Each row shows its die (`GoldRolls.Icons`). Since October 21 the Upgrades tree's
    Gold/Diamond/Prism Machine nodes use the same dice, and Gold Rate is the gold die
    with the green Rate arrows (Stevin: dice, not the machine art).
- **Special pull** (`RollPresentationController`):
  - Every podium glows in the kind's color (Prism cycles the rainbow).
  - A "Gold roll · 2x Luck" tag shows until just after the reveal.
  - A notice appears when the player is too far away to see it.
- **Snapshot** `state.goldRolls = {counters={{kind, every, count, left, luck}, ...}}`.
- **Tooltips:** S9's tree tooltips read `Config.GoldRolls`. The Diamond and Prism
  nodes should read `KindEvery` ("Every 100 rolls: x5 Luck"), not "x2 → x5".

## Analytics (observation only)

- `autoroll.stop` (detail: rebirth, rarity, mutation, normal, newChicken,
  newMutation).
- `goldRoll.pull.<Kind>`.
- `rebirthChicken.offered` and `.bought`.
- S7's `autoRoll.recruit`, `.recruitHeld` and `.skip` counters stay registered but
  are no longer sent.

## Checks

`tests/AutoRollChecks.luau` (run in a Run-mode playtest:
`require(game.ServerStorage.PetRollTests.AutoRollChecks).Run()`). It covers:

- save conversion and the save round trip (rows and the three counts);
- the OR rules and banner lines;
- the three cadences, and the bigger boost winning a shared pull;
- the Diamond Luck boost;
- hold → recruit at the podium → off/on rolls on;
- New Chicken / New Mutation;
- Rebirth-chicken stops and request validation.

UI Lab stories: "Auto Roll panel" and "Auto Roll banner".

## History

- **October 20, S12 (superseded by S12b):**
  - A typed "1 in X" stop with −/+ presets, auto-recruit, Stop on mutations and
    Stop on Army upgrades.
  - A hit alert with Recruit (from anywhere) and Skip.
  - One Gold counter that Diamond and Prism upgraded.
- **October 15:** a research unlock; the stop cycled "Army upgrade", Rare+ … Secret.
