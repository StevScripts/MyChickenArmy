# Big chicken label and level-up banner (October 20 overhaul, S18)

Round 2 of the overhaul ([OVERHAUL_PLAN_20261020.md](OVERHAUL_PLAN_20261020.md) ›
Round 2). Reference: Stevin's Drop a Fruit recording
`~/Downloads/ScreenRecording_10-20-2026 20-54-22_1.MP4`, at 0–6 s (label), 24–46 s
(label with the watering can) and 37–42 s (banner). The rule is the reference's UX 1:1,
drawn in the game's style: Source Sans Bold, black outlines, rarity colours and gold
Coins.

Stevin's choices (October 20, S18):
- The third line shows **Coins per second**. Every egg is worth the same, so this is
  the number that differs per chicken and doubles with each Feed level.
- **Only the nearest chicken** gets the big label. The reference labels all three of
  its fruits; our yards hold up to about 25 chickens.

## The label (`src/client/ChickenLabel.luau`)

- It goes on your chicken at home that is nearest to you, within 24 studs (flat). Only
  one label shows at a time. A neighbour takes it over only once it is 1.5 studs
  nearer, so it never flickers. While Chicken Feed is in hand, the plain nearest
  chicken gets it, the same rule as the Feed prompt.
- There are three centred rows:
  - `LVL 3`, in white.
  - The name, in its rarity colour (`Theme.Rarities`).
  - The gold coin and `12/s` (the snapshot's `pet.income`, `Theme.Number`).
- An Army chicken at home that is not in the Flock lays nothing. Its third row reads
  "Not laying" in grey, with no coin.
- The label is sized in studs (7.5 × 3.4), so it grows as you walk up, like the
  reference. It is drawn on top of the world, hidden past 80 studs from the camera,
  and hidden while the camera is scripted (cutscenes and roll reveals).
- It stands where the small nameplate (`PetView` "Tag") is and follows it as the
  chicken grows. The labelled chicken's small nameplate hides meanwhile. Only the
  nameplate's text transparency changes, because the server and `BattleController`
  own its `Enabled` and `Visible`. Every other chicken keeps its small nameplate.
- With Chicken Feed in hand and the chicken within `VacuumConfig.FeedRange`, the top
  row reads `LVL 3 → LVL 4`, as the reference does while the watering can is out. At
  the max level it stays `LVL 10`.
- It costs one BillboardGui, polled 10 times a second. Text is only rewritten when it
  changes.

## A Feed level

When the server's `FeedChicken` reply is ok:
- The label pops (TweenService) with the new level and Coins.
- A gold "Level up!" pops over the chicken, rises and fades in about 1.2 s.
- The banner shows (`src/client/LevelUpBanner.luau`): `Duck leveled up! LVL 3 → 4` in
  gold lettering with no panel.
  - It sits at the top centre, 22% down the screen like the reference (S12b's Auto
    Roll banner uses the same height). It moves lower when the notice's slot moves
    down for the Commander card or the Hill title. A notice showing at the same time
    pushes it just below that notice.
  - It pops in, holds 4.3 s, then shrinks up and fades (the reference shows it for
    about 4.6 s). A second level while it shows only bumps it.
  - The numbers come from ToolService's reply ("Lv 3 → 4"), else from the snapshot.
- The green ✓ notice no longer shows for a successful feed
  (`AppController` QUIET_SUCCESS). A failed feed still shows its notice.
- ToolController's own feedback is unchanged: the gold flash on the chicken and the
  purchase sound.
- Reduced motion: no pops and no "Level up!". The banner just appears and goes.

## Files

- New: `src/client/ChickenLabel.luau`, `src/client/LevelUpBanner.luau`.
- `src/client/AppController.luau`, additive: the two requires, the start and destroy
  lines, the Receive hand-off, and `QUIET_SUCCESS.FeedChicken`.
- Not changed: the server, `PetView`, `ToolController` and `ToolDock` (S11b owns them),
  and Studio.

## Not the same as the reference

- One big label instead of one on every fruit (Stevin's choice, above).
- "Not laying" for Army chickens outside the Flock. The reference has no fruit that
  makes nothing.
- The label says `LVL`, like the reference. The Feed prompt (S11's ToolController)
  still says `Lv 3 → 4`, and the reference's prompt says "Upgrade" over the price.
  That is a follow-up for S11b if Stevin wants the prompt 1:1 too.

## Playtest

- Walk among your chickens. The label moves to the nearest one, its small nameplate
  hides, and the rest keep theirs. Leave the yard and the label goes.
- Long names (Veteran chickens) fit on one line. Check the rarity colours, and the
  Coins per second against My Army's numbers.
- An Army chicken that is not in the Flock reads "Not laying".
- Hold Chicken Feed next to a chicken: `LVL n → LVL n+1`. Feed it and check the pop,
  "Level up!", the banner and its timing, and that the green notice is gone. Feed
  twice quickly. Try one at the max level.
- With a notice already showing (for example an error), the banner sits below it.
  With the Commander card or the Hill title up, it sits below them.
- An Auto Roll stop banner and a Feed level at the same moment share that height.
  This is rare; check that it reads acceptably.
- Phone (landscape) and PC, and reduced motion on and off. The intro and Hill
  cutscenes and roll reveals show no label.
