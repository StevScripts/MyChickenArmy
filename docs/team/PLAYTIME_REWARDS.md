# Playtime Rewards and the boosts readout (October 20, S16)

Session S16 of the October 20 overhaul, round 2, on branch `oct20/s16-playtime-boosts`.
The reference is Stevin's Drop a Fruit recording
(`~/Downloads/ScreenRecording_10-20-2026 20-54-22_1.MP4`): the Playtime Rewards window
at ~134 s, the "Free Reward Ready!" notice at ~139 s, and the coin/clover readout
throughout. Rule for the round: copy the UX 1:1, in My Chicken Army's art style.

## Owner decisions (Stevin, October 20)

- **Rewards and timers:** the reference 1:1 (table below). Coins tiles pay minutes of
  the player's steady income in the reference's ratios.
- **Reset:** every join. The clock starts when the save finishes loading; leaving
  resets the timers, the claims and any running boost. Nothing is saved.
- **Readout:** counts everything (see "Boosts readout").
- **Boost timer:** approved addition to the reference. While a Playtime Rewards boost
  runs, its ×N turns green with the time left underneath.

## The twelve tiles (`src/shared/PlaytimeRewards.luau`)

| # | Unlocks at | Reward | Tile |
|---|---|---|---|
| 1 | 1 min | Coins: 0.4 min of income | blue |
| 2 | 3 min | Coins: 0.6 min | blue |
| 3 | 5 min | Coins: 1 min | blue |
| 4 | 8 min | +100% Luck for 5 min | pink, clover |
| 5 | 12 min | Coins: 2 min | blue |
| 6 | 15 min | Coins: 2.4 min | green |
| 7 | 20 min | Coins: 3 min | blue |
| 8 | 25 min | +50% Coins for 10 min | gold, coin |
| 9 | 30 min | Coins: 5 min | blue |
| 10 | 40 min | +100% Luck for 10 min | pink, clover |
| 11 | 50 min | Coins: 7 min | green |
| 12 | 60 min | 3 Free Rolls | gold |

**October 21 (Stevin: "check if the playtime rewards money is unbalanced"):** one
reference unit is now 0.4 minutes of steady income (21.4 minutes over the hour) instead
of one minute (53.5 minutes): the 1:1 amounts were 20–27% of every Coin for an hour of
play and 29–31% for two 30-minute visits a day, and they were computed at claim time,
so saving tiles for the end of a visit paid 10–100x more. A Coins tile's amount is now
fixed when it unlocks. Ratios, unlock times, boosts and Free Rolls are unchanged. The
measurements: `docs/team/RARITY_PACING_20261021.md`.

The reference's timers (00:04, 02:04 … 57:04 at 2:56 played) give exactly these
unlock times. Its Coins amounts (3,762 … 65,849) give the 1 : 1.5 : 2.5 : 5 : 6 : 7.5 :
12.5 : 17.5 ratios. Its last tile is a fruit pack; ours is Free Rolls.

## Server (`src/server/PlaytimeService.luau`)

- **Visit:** `session.playtime = {startedAt, claimed}` and
  `session.playtimeBoosts = {[kind] = {bonus, endsAt}}`. Times are in server time
  (`workspace:GetServerTimeNow()`), so the client counts down without extra packets.
  `PlayerSession:Reset` clears both. They are never written by `ToData`.
- **Request:** `ClaimPlaytime {index}`. It refuses a bad index, a claimed tile, or a tile
  that is still locked ("Keep playing! This reward unlocks in 04:12.").
  - **Coins:** minutes of `DailyService.Income` (October 21: fixed by `lockedCoins`
    the first time Snapshot or Claim sees the tile unlocked, kept in
    `session.playtime.locked[index]`), credited as source `playtime`. The steady
    income includes 2x Coins, Rebirth and Coin Boost, but never Gold Rush, Friend
    Boost or a Playtime Coins boost. The amount is capped by the wallet's room at
    claim time. A full wallet leaves the tile ready.
  - **Luck boost:** `PlayerSession:RollLuckBonus()` = (1 + Extra Luck) × (1 + bonus) − 1,
    the same way a Gold roll multiplies Luck. `RollService:Roll` and the session's
    `odds` use it. Hill rolls and the Upgrades tooltips keep the plain value.
  - **Coins boost:** a live factor in `PlayerSession:EarnedAmount`, next to Gold Rush and
    Friend Boost. It applies to earned Coins (eggs, battles, Missions) when they are
    paid. It never applies offline, to daily Coins, to playtime Coins or to Robux packs.
  - **Boost stacking:** claiming a boost of the same kind while one runs adds its
    minutes; the bonus never drops.
  - **Free Rolls** (Stevin, later October 20, S16b): three chickens drawn at once, like
    a lever pull. They use the Luck tier, 2x Luck, Extra Luck and a running Playtime
    Luck boost (`RollLuckBonus`). There is no Hill-roll bonus (Daily's Free Rolls keep
    theirs) and no Gold-roll count. Each chicken is level 1 with no refund value.
    All or nothing: without room for all three, the tile stays ready ("Sell a few, then
    claim your 3 Free Rolls."). In the first build they used Hill-roll Luck and gave
    Legendaries and Mythics every play-hour.
- **Snapshot:** `state.playtime = {enabled, startedAt, tiles = {{index, kind, at, unlockAt,
  claimed, coins?}}}`. `coins` is what a Coins tile pays: the fixed amount once it has unlocked, a projection
  of today's income while it is still locked.
- **Snapshot:** `state.boosts = {coins, luck, running = {[kind] = {bonus, endsAt}}}`.

## Boosts readout (`src/client/BoostReadout.luau`)

- The coin "x9.2" and the clover "x4.5" are a very small icon pair in the bottom-right
  corner (HudController `BoostSlot`, `BoostReadout.Position/Size/Aspect`). Each number
  is a tilted badge over its icon's top-right corner, like Stevin's reference image
  (later October 21; before that they sat under Friend Boost, and first top-right under
  the Settings gear). A running boost's time left shows over the foot of its icon. The
  Gold Rush chip rests just above them. The corner notice took the old top-right spot
  (Y 0.094).
- **Coins ×** is what one egg sells for, compared with no upgrades or boosts: the Egg
  Value tier × 2x Coins × Rebirth × Coin Boost × Gold Rush × Friend Boost × the Playtime
  Coins boost × a held outpost's egg bonus.
- **Luck ×** is `Rules.LuckWindow(...).multiplier`: the Luck tier × 2x Luck × Extra Luck ×
  the Playtime Luck boost. One-pull Gold rolls are not counted.
- A rise pops the number. Display only.

## Client

- **`PlaytimePanel`** (the top-bar gift and the window):
  - The gift is a round dark button in the top bar's safe area (`TopbarSafeInsets`), in
    slot 0. Its size is 0.76 of the bar height, and one slot is 1.19 diameters.
  - It carries the game's red count badge. The reference's badge is white.
  - The window has a purple studded header and a 4 × 3 grid of square tiles. A tile shows
    its countdown (mm:ss), then "Claim!" in green, then a check with "Claimed!".
  - Locked tiles do nothing when tapped, as in the reference.
  - The window slides down from the top and leaves upward, over the menu blur.
  - Claim feedback: a Coins claim plays the Daily reward's coin effect while the HUD
    counts up; a boost or Free Rolls claim shows the server's message.
  - `MenuLayouts.PlaytimeRewards` may override the window's size in Studio.
  - **When Quests ship:** a Quests calendar button takes slot 0 (the reference shows it
    first) and the gift moves to slot 1. S17 agreed this rule.
- **`CornerNotice`** (shared with a later Quests session, API agreed with S17):
  - `app.cornerNotice:Show({title, body?, icon, tag?})`. Notices queue and show one at a
    time.
  - Motion: it slides in from the right inside a clipped strip (0.45 s). A dark sunburst
    spins behind the icon, and the icon pops in tilted −20° and settles (0.6 s). It holds
    7.5 s, then slides out (0.25 s).
  - It sits just under the readout's icons and covers the foot of their numbers for
    those seconds, as in the reference.
  - Playtime sends "Free Reward Ready!" / "Open the gift at the top to claim it!" with
    the tile's icon. The reference says "Tap…"; our glossary avoids device words.

## Checks

- `tests/PlaytimeChecks.luau`: 11 checks covering the tiles, timers, claims, both boosts,
  the readout totals, Free Rolls, the snapshot and the reset.
- Run it in Studio with `require(game.ServerStorage.PetRollTests.PlaytimeChecks).Run()`.
- Analytics schema 8 adds the `playtime` Coins source and
  `playtimeReward.claim.<1..12>`.
