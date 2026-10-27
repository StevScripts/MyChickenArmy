# WS5: post-tutorial flow and system overload (plan, October 27, 2026)

Scope: what the player sees from the end of the eighth tutorial card (median 1:03 of play)
to about minute 15. This covers the HUD staging after completion, the tip/goal chain, popup
sequencing (Daily, Playtime, Free Gift, corner notices) and the late-session analytics.

Out of scope here:
- Camp balance and the Fort Roost wall (WS1).
- Prices (WS2).
- The Robux prompt (WS3).
- Roll odds (WS4).
- Performance (WS6).
- Social (WS7).

Status: research and plan only. No repo file was edited. Baseline: HEAD `c6153d1` contains
the unpublished `1.26.0-first-minute` (A–D). The data comes from live `1.25.0-eight-cards`.

Data used:
- `quit/journeys27.json`: 847 new-player onboarding journeys.
- `quit/summary125.json`: aggregate report.
- `quit/raw125.json`: ledger counters for Oct 26–27.

All numbers below were computed with `python3 -I` on those files.

---

## 1. Problem and evidence

### 1.1 Where finishers leave

Of 847 new players, 496 finished the tutorial (`mx >= 11`). 484 have a `TutorialDone` time.
The tutorial completes at play 0:50 / 1:03 / 1:27 (p25 / p50 / p75).

Seconds from completion until the session ended (cumulative share of 484 finishers):

| ≤15 s | ≤30 s | ≤60 s | ≤120 s | ≤180 s | ≤300 s | ≤600 s | ≤1200 s |
|---|---|---|---|---|---|---|---|
| 6.0% | 11.6% | 21.5% | 36.8% | 48.8% | 62.4% | 84.9% | 94.8% |

Half of all finishers are gone within 3 minutes of completion. These are the session's minutes
2–4, matching the brief's "33% of new sessions end at 1–3 min".

Furthest step reached (`mx`), with exit counts:
- 11 (done, no vacuum): 78.
- 12 (vacuum): 100.
- 13 (Rebirth 0, no Cluck): 37.
- 14 (Cluck Camp won): 281.

Session length p50 by group: 95 s, 134 s, 242 s and 458 s.

### 1.2 The real cause: no goal on screen

`ex` in the journeys is the server's resolved guide step at leave (`Analytics:Observe` reads
`TutorialService.records[*].step`). The server resolves `Guide.Resolve(state)` without the
client's `tipSkip`. Two consequences:
- **TipNextCamp2 is not on screen when those players leave.** The client shows it for only
  `NextCampTipSeconds` (10 s, `TutorialGuide.luau:362`), then skips it
  (`CommanderGuide.luau:392-396`). The server keeps reporting it until Fort Roost is won.
- "Complete" means the client shows nothing: `completeShown` → `current=nil`
  (`CommanderGuide.luau:406-411`).

So the brief's "74% of Cluck winners exited with TipNextCamp2 on screen" really means: they
exited 10+ s after that card left, with no card at all. The only goal left was the world
"NEXT: FORT ROOST" marker over a camp most of them cannot beat (WS1).

Finishers whose exit step was Complete, TipNextCamp* or TipGems (a timed 20 s card), meaning
no actionable card was visible: **438 of 496 (88%)**.

**Goal-less gaps** in untruncated trails: intervals after completion where the server step
was Complete or TipNextCamp, grouped by the card before them.

| Gap after… | gaps | ended in the gap | median gap | what came next |
|---|---|---|---|---|
| Tutorial complete (card 8) | 373 | **73 (20%)** | 26 s | TipVacuum 219, TipVacuumUse 51 |
| Vacuum chain done ("Vacuum learned!") | 196 | **50 (26%)** | 37.5 s | TipAttack 83, TipRebirth 47 |
| Cluck Camp won (after its 10 s card) | 43* | 7 | 11 s | Complete 19, TipRebirth 10 |

*After Cluck Camp, 269 of 281 trails are cut by the 60-event cap.

1.26's change D (vacuum counting card) closes the first gap. **The second gap is untouched in
1.26**, and so is everything after Cluck Camp and Rebirth 0.

### 1.3 Cluck Camp winners (`mx` = 14, n = 281)

Medians: done 62 s, vacuum 87 s, Cluck Camp 159 s, Rebirth 0 238 s (214 of 281 did Rebirth 0;
173 of 214 won Cluck Camp first).

| Group | n | time from Cluck win to leave (p25 / p50 / p75) | at leave |
|---|---|---|---|
| With Rebirth 0 | 214 | 188 / 339 / 584 s | coins p50 976, chickens p50 5 |
| Without Rebirth 0 | 67 | 23 / **60** / 133 s | coins p50 783, chickens p50 3 |

The typical winner does Rebirth 0 at 4:00 and leaves around 8:00. For those 4 minutes the
screen shows no card after the 20 s Gem card. The goals that exist (Rebirth 1 = 50K Coins plus
finding an Ironbeak Chicken, Fort Roost) are never named.

### 1.4 Rebirth 0 silently removes the Egg Vacuum

`RebirthService.RebirthIntro` (`RebirthService.luau:490`) calls `session.upgradeTree =
keptTree(session)`. That resets the whole tree:
- the Egg Vacuum;
- Flock Size I, so 3 chickens lay instead of 4.

The Vacuum chain is already `done` (`vacuumSold`), and `EggHint` is off (`vacuumUsed`), so
nothing re-teaches the free re-claim.

Ledger for Oct 26–27:
- `upgrade.buy.EggVacuum` 1,104 against 724 first claims (`ob.reach.12`) leaves about 380
  re-claims.
- Rebirths: 485 Rebirth 0 plus 105 others, about 590.
- Roughly a third of rebirthing players never re-claimed. This is an upper bound, because
  veteran rebirths are mixed in.

The diagnosis memory (Oct 23) also found that 78% of sessions end with one roll slot and no
upgrade bought.

### 1.5 The completion screen is crowded, but that is secondary

At completion (`Hud:SetTutorialStage(nil)`, `HudController.luau:631-685`), everything parked
in `TutorialHold` returns in the same frame (section 2.2).

Menu opens in the 2 minutes after completion show that players do not hop menus:

| Menu | left ≤180 s after completion (n=237) | stayed >180 s (n=247) |
|---|---|---|
| Daily | 94% | 99% |
| Upgrades | 61% | 82% |
| Army | 25% | 37% |
| ClaimPlaytime | 13% | 14% |
| Index | 7% | 10% |
| Rebirth | 6% | 8% |
| Shop | 0–1% | 0–1% |

The difference between leavers and stayers is whether they progressed into the Upgrades /
vacuum chain. Side menus are not the problem.

So the crowded completion screen is a cost of visual load and attention (one-emphasis rule,
WS6 tween load). It is not the main leak. **Priority: goals (P0) > popup sequencing (P1) >
progressive HUD reveal (P1, flagged).**

### 1.6 The Daily popup lands on top of the first tip

`GameServer` checks Daily every `DAILY_CHECK_SECONDS = 10` (`GameServer.luau:47,708-712`). The
client waits out the 4 s payoff (`DailyRewardController:Blocked`, `CommanderGuide.CORE_SECONDS`).
So the popup opens at completion +7 / 13 / 19 s (p10 / 50 / 90). That is a random moment, right
after the TIP card typed itself, and it covers it (`CommanderGuide` blocked).

- 67 of 469 finishers (14%) left within 30 s of the Daily opening; 38 (8%) within 15 s.
- This is correlational, since everyone sees it. Stevin kept Daily at completion (change E was
  declined), so this plan only makes its timing deterministic. See section 3.3.

`Daily:Show` calls `CloseOtherMenus("daily")` (`DailyRewardController.luau:349-350`). That
closes the Upgrades tree or My Army if the player has it open (for example, mid vacuum claim on
a fast player).

### 1.7 The data cap hides the end of long sessions

320 of 847 journeys hit `Schema.JourneyEventCap = 60` (about the first 3 minutes). For 269 of
281 Cluck Camp winners we cannot see the last 30 s. Section 5 adds a tail ring buffer and
client-visible card tracking.

---

## 2. Root cause in code: the screen at completion, in order

### 2.1 Completion (play ≈ 1:03, median)

1. **T+0.** Card 8 recruit. `TutorialService:Observe` (`TutorialService.luau:177-190`) sets
   `coreDone`, `guideCompleted` and `eggsAtComplete`. `PlayerSession:LaySeconds` drops back from
   `TutorialEggLaySeconds = 1` to 3 s, so eggs come in at a third of the rate.
2. **T+0, client** (`CommanderGuide:Update`):
   - `facts.Core` flips, so `CelebrateCore`: "TUTORIAL COMPLETE! Your yard is up and running.
     Keep collecting!" holds 4 s, with 40 confetti pieces and a chime (`CommanderGuide.luau:225-241`).
   - In the same Update, `hud:SetTutorialStage(nil)` releases `TutorialHold`. Popping or
     starting their idle loops in that frame:
     - My Army (`SetArmyHidden(false)`, pop);
     - Shop and Index (PopScale);
     - Rebirth button with its "%" tag toward 1,700;
     - Free Gift: Breathe, plus a sunburst spinning 10 s/rev;
     - Settings gear;
     - Playtime gift: red badge, Wobble and gold Glow once the 1-minute tile is ready, which
       it almost always is at T+0;
     - Friend Boost row "Friend Boost: +0%" with its "+";
     - boost readout;
     - Gold Rush chip: "Gold Rush in mm:ss" countdown;
     - Upgrades red badge with its gold Glow;
     - empty tool hotbar;
     - corner notice layer: a "Free Reward Ready!" queued during the hold can slide in.
     - Every icon also starts `Sway` (`Hud:StartIdleMotion`).
3. **T+4 s.** Payoff ends. 1.26 shows "TIP • 1/7 Collect eggs for an Egg Vacuum! (0/12)" with a
   typewriter.
4. **T+7–19 s.** Server Daily check grants Day 1. The Daily modal opens: blur plus seven tiles.
   The TIP card is hidden while it is open. Tapping Day 1 claims it (coins fly to the HUD,
   banner), and the window stays until X (`Collect(false)`).
5. **About T+25 s** (12 eggs at about 0.67 eggs/s with 2 chickens, plus walking):
   1. "Open Upgrades for an Egg Vacuum!" (2/7, dim plus ring on HUD Upgrades)
   2. "Open the Tools category!" (3/7)
   3. "Claim your Egg Vacuum!" (4/7)
   4. "Equip your Egg Vacuum!" (5/7, ring on the hotbar slot)
   5. "Walk near eggs to vacuum them up! (n/10)" (6/7)
   6. "Sell your eggs on the green pad!" (7/7)
   7. "TIP • COMPLETE! Vacuum learned!" (4 s)

   Vacuum bought at p50 87 s of play. The chain ends at about 2:00–2:30.
6. **Gap A, the post-vacuum void.** The Attack tip needs an Army of 3
   (`TutorialGuide.luau:399-409`) and "settled" (20 vacuumed or 60 by hand). 72% of mx=12
   leavers own 2 chickens. Nothing tells them to get a third, and the vacuum chain sold only 10
   vacuumed eggs.
   - Rebirth tip only at 1,700 Coins.
   - Meanwhile: Playtime "Free Reward Ready!" corner notices at 3:00 and 5:00 of visit time,
     Gold Rush toasts, the Rebirth "%" climbing.
7. **Attack.** "Send your Army to attack Cluck Camp!" (TIP 1/1, beam), march film, win (p50
   2:39).
   - Then "TIP • COMPLETE! Camp captured!".
   - Then "Next up: conquer Fort Roost!" for 10 s.
   - Then nothing: **gap B**, while the world keeps "NEXT: FORT ROOST" (`BaseController.luau:632-651`).
8. **Rebirth** (p50 3:58) at 1,700 Coins:
   1. "Rebirth is ready! Open it…"
   2. "Tap Rebirth!…"
   3. Gem card for 20 s
   4. "Rebirth learned!"

   Then nothing: **gap C**. The tree reset also took the vacuum and Flock Size I (section 1.4).
9. **About 4:00–8:00.** No card. Exit.

### 2.2 Code facts the design builds on

- `TutorialGuide.Tips` (`TutorialGuide.luau:383-452`) is a priority list of chains
  `{id, payoff, total, cards, when, done, card, quietEnd}`.
  - `tip()` returns the first chain where `not done and when`.
  - `resolve()` falls back to `step("Complete")` when there is no tip.
  - Only `guideStarted` profiles get tips (`TutorialGuide.luau:476`).
- `CommanderGuide` already has a typewriter, a payoff hold, timed cards (`seconds`), a menu ring
  (dim only for Upgrades/VacuumTool/Rebirth/Gems targets, `CommanderGuide.luau:571`), a world
  beam through `BaseController.OpeningGuidance`, and `tipSkip`.
- `TutorialHold` parks every hudLayer child except `CashReadout` and `CollectionNavigation`
  (named, `HudController.luau:636-646`).
  - Children by name: `Navigation`, `Topbar` (Settings), `PlaytimeTopbar`, `GoldRushChip`,
    `BoostSlot`, `CornerNotice`, `ToolHotbar`, `Rally`, `OperationsShortcut`, `RebirthCorner`,
    `FreeGiftCorner`, `ChickenOfferCorner`, `AutoRoll`, `HillEvent`, `OpeningObjective`,
    `SaveStatus`.
  - Friend Boost is a row inside `CashReadout` (`FriendBoostSlot`).
- Auto-opening popups for a new player: **Daily only**. Free Gift and Playtime open only on tap.
  Offline appears for returning players only. Rebirth opens on tap.
- `CornerNotice` queues up to 6 strips, 7.5 s each, ignoring other UI.
- The `tutorial.goalsHidden` saved flag and the `HideGoals`/`ShowGoals` signals still exist
  (`TutorialService.luau:241-243`). The Settings row was removed on Oct 21.
- `CommerceController.COINS_PROMPT_EARNED = 2000` uses `state.passiveEarned + state.battleEarned`.

---

## 3. Options and recommended design

### 3.1 Options considered

| Option | Verdict |
|---|---|
| A. Loosen the Attack tip (drop "settled") | Rejected: reverses Stevin's Oct 24 call, and most gap-A players own 2 chickens anyway. Make the wait visible instead (the D pattern he accepted). |
| B. Make NextCamp persistent | Not alone: it points at a camp most cannot win (WS1). Persistent only when WS1's gate says ready. |
| C. Generic "Keep collecting" filler | Rejected: not actionable. Every card names the next concrete action or a number. |
| D. New HUD quest widget | Rejected: a HUD restructure ("HUD not copied"). Reuse the Commander card. |
| E. Goal ladder in the existing tip framework, plus progress GOAL cards | **Recommended (P0).** |
| F. Move Daily after the Vacuum | Declined by Stevin. Only make its timing deterministic and stop it closing menus (P1). |
| G. Auto-close Daily after the Day-1 claim | Rejected: the Daily popup is a 1:1 reference copy ("Reference UX 1:1"). |
| H. Progressive HUD reveal | **Recommended (P1, flag).** Visibility timing only, same positions. Extends Stevin's own Oct 21/25 staging pattern. |
| I. Hide the Rebirth button until Rebirth 0 is affordable | Rejected: Oct 23 owner rule ("icon shows from the start"), and its % tag is the long-term bar. |

### 3.2 Recommended: the goal ladder (never empty until Rebirth 1)

One card at a time, resolved from the snapshot each packet. Chain priority (TIPS order, first
match wins):

1. **Rebirth** (existing, unchanged): affordable Rebirth, then the Gem card.
2. **Vacuum** (existing, 1.26): count card, claim, equip, use, sell.
3. **Rebuild** (NEW, after Rebirth 0 only): re-claim the vacuum, Flock Size I.
4. **Attack** (EXTENDED): 3rd chicken, then (if not settled) a visible settle count, then attack
   Cluck Camp.
5. **Camp** (WS1 provider): next camp, only when WS1's odds gate says Should win / Close fight;
   else WS1's power step. Until WS1 lands, the existing timed NextCamp card.
6. **Grow** (NEW, after Rebirth 0): up to three starter Upgrades nudges, as each becomes
   affordable.
7. **Goal** (NEW, tag "GOAL"): the long bar. Rebirth 0 progress, then the Rebirth 1 find, then
   Rebirth 1 Coins.

**Invariant.** For an empty-start profile (`introRebirth ~= nil`) with `guideCompleted`,
`rebirth.rank < Config.Guide.GoalUntilRank` (1) and `goalsHidden ~= true`, `Guide.Resolve`
never returns nil or "Complete". The only exception is the payoff hold.

**Visibility.** TIP cards (actions) persist as today. GOAL cards (progress) persist during the
first `GoalAlwaysSeconds` (900) of the visit. After that they "peek": shown for
`GoalPeekSeconds` (10) when they first appear, when progress crosses 25/50/75/100%, or after
`GoalIdleSeconds` (25) with no meaningful action. This meets "always a current goal in the first
15 minutes" without nagging long sessions.

**Settings.** The "Goal hints" ON/OFF row returns, reusing `goalsHidden` and
`HideGoals`/`ShowGoals`. OFF hides chains 3, 6 and 7 only; Stevin's own tips stay.

### 3.3 Recommended: popup and beat sequencing

- **Daily at completion, deterministic** (keeps his choice). The server grants Day 1 the moment
  `coreDone` flips (`session.dailyCheckDue`), so the popup opens exactly when the 4 s payoff
  ends. The first TIP card then types itself when Daily closes, not before. The order on screen
  is payoff → Daily → first tip, never tip → Daily covering it.
- **Daily never closes the player's menu.** `Blocked()` also waits while the player is in a menu
  or a film (`app:ModalBusy()`), up to `DailyWaitMaxSeconds` (45). After that it opens as
  today.
- **One emphasis at a time** (GAME_FEEL rule):
  - `CommanderGuide` gets a small beat queue: payoff → HUD reveal(s), at least 1.5 s apart →
    next card. The queue is shared with other feature moments through `app:Beat(name, seconds)`
    and `app:BeatBusy()`.
  - `CornerNotice:Next` holds while `app:ModalBusy()` or `commander:Celebrating()`, so "Free
    Reward Ready!" never slides in over Daily, a payoff or the Rebirth screen.
  - WS3's checkout and WS7's invite prompt also check `app:ModalBusy()`.
  - WS7: no Daily or Playtime reveal within 5 s of the Rebirth-0 invite. The invite's open
    state is part of `ModalBusy`.

### 3.4 Recommended: progressive HUD reveal (flag `Config.Guide.HudReveal`)

Same positions, sizes and art. Only when each piece leaves `TutorialHold`. Predicates are pure
(`TutorialGuide.HudReveal`) and read the snapshot plus `sinceCore` (client seconds since
completion was seen this visit).

| HUD piece (hudLayer child) | Revealed when | Why |
|---|---|---|
| CashReadout coins, Upgrades | already during the tutorial | unchanged |
| My Army (`Navigation`) | at completion | owner Oct 21 rule; needed for the Army chain |
| Rebirth (`RebirthCorner`) | at completion | owner Oct 23 ("from the start"); its % is the bar |
| Settings (`Topbar`), `ToolHotbar`, `Rally`, `OperationsShortcut`, `AutoRoll`, `HillEvent`, `SaveStatus`, `OpeningObjective` | at completion | utility, or gated by their own code |
| Playtime (`PlaytimeTopbar`) | `vacuumSold` or `sinceCore ≥ 150` | turns gap A into a reward beat: the gift pops with its ready count |
| Index (shortcut) | 2+ species in `discovered`, or Cluck Camp won, or `sinceCore ≥ 300` | appears with the first new chicken ("NEW!") |
| Free Gift + Robux chicken offer (`FreeGiftCorner`, `ChickenOfferCorner`) | visit ≥ 300 s (its own 5-minute row) or Rebirth 0 done | nothing to claim before 5 minutes |
| Shop (shortcut) | `passiveEarned + battleEarned ≥ Config.Guide.ShopRevealEarned` (2,000, the same constant as WS3's prompt gate) or Rebirth 0 done or `sinceCore ≥ 360` | Robux appears once Coins make sense; matches WS3 |
| Gold Rush chip, `BoostSlot` | Rebirth 0 done, a boost active, or `sinceCore ≥ 360` | a countdown with nothing to boost is noise |
| Friend Boost row | Cluck Camp won, friend boost > 0, or `sinceCore ≥ 360` (WS7 may supply its own predicate) | social beat after the first win |
| `CornerNotice` | at completion, gated by `ModalBusy` | sequencing, not hiding |
| Anything unnamed | at completion | safe default |
| **Everything** | `sinceCore ≥ Config.Guide.RevealAllSeconds` (480) or the tutorial completed before this visit | cap; returning players see the full HUD |

**Reveal feel.** `Hud:Reveal(key)`:
- `Theme.Motion:PopScale(visual, 0.6, 0.3)`.
- A small yellow "NEW!" tag (CornerNotice tag colour `255,221,46`, black stroke) at the icon's
  top-left. It pings with `Motion:Ping(tag, 1.6)` until the first `Activated`, or for 30 s.
- One "Badge" cue.
- Reveals go through the beat queue, at least 1.5 s apart, never while a menu or modal is open.
- Reduced motion: the tag shows without pulsing.

### 3.5 The minutes 2.5–15 timeline (median player, after the plan)

| Play | On screen (card) | HUD / popup beat |
|---|---|---|
| 1:03 | TUTORIAL COMPLETE! (4 s, confetti) | My Army and Settings appear (pop); Rebirth button with "0%" |
| 1:07 | (hidden under Daily) | Daily Day 1 opens at once |
| ~1:12 | TIP • 1/7 Collect eggs for an Egg Vacuum! (n/12) | — |
| 1:30–2:20 | TIP 2–7/7 vacuum chain (unchanged) | hotbar ring at "Equip" |
| ~2:20 | TIP • COMPLETE! Vacuum learned! (4 s) | then **Playtime gift reveal** (NEW!, badge 1–2, corner notice "Free Reward Ready!") |
| ~2:25 | **TIP • 1/3 Roll a chicken for your Army! (2/3)** | beam to the lever |
| ~2:30 | TIP • 1/3 Buy the chicken! / Collect eggs worth N more Coins / Sell your eggs on the green pad! | the favoured basic Chicken (60%) |
| ~2:30 | (if the roll is a new species) | **Index reveal** (NEW!) |
| ~3:10 | TIP • 2/3 Vacuum eggs to get ready for battle! (n/20) — only if not settled | — |
| ~3:15 | TIP • 3/3 Send your Army to attack Cluck Camp! | march film on the first order |
| ~3:40 | TIP • COMPLETE! Camp captured! | **Friend Boost row reveal** |
| ~3:45 | WS1: "Next up: conquer Fort Roost!" when Should win / Close fight, else WS1's power step; or GOAL "Reach 1,700 Coins for Rebirth 0! (976/1,700)" | NEXT marker as WS1 decides |
| ~4:00 | TIP • 1/3 Rebirth is ready! … → 2/3 Tap Rebirth! → 3/3 Gem card (20 s) → Rebirth learned! | WS7 invite prompt (WS7 timing) |
| ~4:30 | **TIP • 1/2 Claim your Egg Vacuum again!** (Upgrades ring → Tools → Claim) | **Shop, Gold Rush chip, boosts reveal** (one at a time) |
| ~4:45 | TIP • 2/2 Expand your plot again! (Flock Size I) | — |
| ~5:00 | — | **Free Gift reveal** (NEW!) |
| 5–15 min | Grow nudges as affordable: Buy Egg Speed I! → Buy Egg Value I! → Buy Army Size I! (WS2 confirms the list); WS1 camp cards when ready | upgrades badge already counts them |
| fallback | GOAL • Find an Ironbeak Chicken for Rebirth 1! (lever), then GOAL • Reach 50,000 Coins for Rebirth 1! (12%) | Rebirth % tag |

---

## 4. Implementation steps

Single writer per file. WS5 owns `TutorialGuide.luau`, `CommanderGuide.luau`,
`HudController.luau` (WS3 adds `HintShop`, coordinated), `DailyRewardController.luau`,
`CornerNotice.luau` and `PlaytimePanel.luau`.

### 4.1 `src/shared/Config.luau`

Add one block next to `Economy`:

```lua
-- October 27 (WS5, docs/team/POST_TUTORIAL_FLOW_20261027.md): post-tutorial goal ladder,
-- HUD reveal and popup sequencing. Every flag off restores 1.26 behaviour.
Guide = {Goals = true, ArmyTips = true, Rebuild = true, Grow = true, HudReveal = true,
	DailyAtCore = true, ModalQueue = true,
	GoalUntilRank = 1, GoalAlwaysSeconds = 900, GoalPeekSeconds = 10, GoalIdleSeconds = 25,
	RevealAllSeconds = 480, ShopRevealEarned = 2000, DailyWaitMaxSeconds = 45,
	GrowNodes = {"EggSpeed1", "EggValue1", "ArmySize1"}, -- WS2 confirms
	BeatGapSeconds = 1.5},
```

- `Version = "1.27.0-goals"`, or whatever the integrated build label is (lead's call).
- `CommerceController.COINS_PROMPT_EARNED` reads `Config.Guide.ShopRevealEarned` (WS3 makes
  that edit).

### 4.2 `src/shared/TutorialGuide.luau` (WS5)

**1. New constants.**
- `Guide.ArmyGoal = Guide.ArmyTipSize` (3).
- `Guide.SettleGoal = Guide.VacuumGoal` (20, the existing "settled").
- `Guide.GoalTag = "GOAL"`.

**2. Helpers.**
- `local function goalsOn(state)`: `Config.Guide.Goals and state.introRebirth ~= nil and
  (state.tutorial or {}).goalsHidden ~= true and rank(state) < Config.Guide.GoalUntilRank`.
- `rank(state)` reads `state.rebirth.rank`.
- `Guide.CoinsEarned(state)` = `passiveEarned + battleEarned`.

**3. Extend `ATTACK_CARDS` and the Attack chain** (`total = 3`, gated on `Config.Guide.ArmyTips`).
Cards:
- `TipArmyRoll` (index 1): "Roll a chicken for your Army! (n/3)", target `RollStation`.
- `TipArmyBuy` (index 1): "Buy the chicken!", target `RollStation`.
- Earn steps reuse `earn(state, offer.price)`, re-tagged index 1 of the chain.
  - Ids stay `RecoverCollect` / `RecoverSell`, so the egg hint, beam and camera code keep working.
  - Copy stays "Collect eggs worth N more Coins" / "Sell your eggs on the green pad!", worded
    like WS3's toast.
- `TipArmyReady` (index 2): "Vacuum eggs to get ready for battle! (n/20)", target `Yard`.
  - When the vacuum is not in hand: `outside = "Equip your Egg Vacuum!"`, target `VacuumTool`.
  - The count is `max(VacuumEggCount, floor(EggsCollected*20/60))`, clamped to 20.
- `TipAttack` (index 3): text unchanged.

`when`: `guideCompleted and not f.Win and (vacuumSold or EggsCollected ≥ ArmyTipEggs or not
VacuumChainAvailable)`. The chain starts as soon as the Vacuum chain has paid off. While
`ArmyTips` is off, keep the old `when` (army ≥ 3 and settled).

`card`, in order:
1. `selectedCount < 3`: if there is no offer, `TipArmyRoll`; if offer price > coins, `earn()`;
   else `TipArmyBuy`.
2. Not settled: `TipArmyReady`.
3. Otherwise: `TipAttack`.

`done`: unchanged (`f.Win`).

**4. New `REBUILD_CARDS` and the Rebuild chain** (inserted after Vacuum; `Config.Guide.Rebuild`):
- `TipRebuildVacuum` (index 1): "Claim your Egg Vacuum again!", target `Upgrades`, node
  `EggVacuum`, outside "Open Upgrades for an Egg Vacuum!", wrongTab "Open the Tools category!".
- `TipRebuildFlock` (index 2): "Expand your plot again!", target `Upgrades`, node `Flock1`,
  outside "Open Upgrades!", wrongTab `MAIN_TAB`. Short of its price: `earn()`.
- `when`: `introRebirth == "done" and t.vacuumSold and rank == 0 and (EggVacuum offer Available
  or Flock1 not owned)`.
- `done`: `tools.eggVacuum == true and Flock tier ≥ 1`.
- payoff: "Yard rebuilt!".
- This chain only shows after Rebirth 0, because `vacuumSold` is true and Rebirth 0 is done.

**5. Camp chain (WS1 interface).**
- Replace the body of the existing `NextCamp` chain with a provider lookup:
  `local CampGuide = script.Parent:FindFirstChild("CampGuide")`, required under `pcall`.
- If WS1's module exists, `when = CampGuide.When(state, f)` and `card = CampGuide.Card(state, f)`.
  The card must have the `tipCard` shape `{id, text, target, index, total?, seconds?}`.
- Else the current timed NextCamp cards.
- `id` stays `"NextCamp"`, so analytics continues.

**6. `GROW_CARDS` and the Grow chain** (`Config.Guide.Grow`):
- For each id in `Config.Guide.GrowNodes`, one card "Buy <node label>!" (for example "Buy Egg
  Speed I!").
  - Label from `Tree.Nodes[id]` / `CashNodes` (shared label table).
  - target `Upgrades`, node id, outside "Open Upgrades!", wrongTab `MAIN_TAB` (or the node's
    category tab).
- `when`: `introRebirth == "done"`, Rebuild done, `goalsOn`, and some listed node has status
  `Available` with price ≤ coins.
- `card`: the first such node.
- `done`: all listed nodes Owned, or `t.growSeen ≥ #list`.
  - `growSeen` is not saved; the client counts per visit through `tipSkip`.
  - A node the player skips past (buys something else) stays offered until owned. The chain
    simply re-evaluates.
- payoff: "Upgrades learned!".

**7. GOAL cards (the `Goal` chain, last; `goalsOn` only).** `quietEnd = true`, tag `GOAL`, no
index.

| Condition | Card |
|---|---|
| `introRebirth == "pending"` and coins < cost | `GoalRebirth0`: "Reach 1,700 Coins for Rebirth 0! (976/1,700)" (`Currency.Grouped`), target nil |
| rank-1 find not in `state.discovered` (`PetCatalog.RebirthFinds[1]`, only while rank < `Config.Rebirth.FindRanks`) | `GoalFind`: "Find an Ironbeak Chicken for Rebirth 1!" (name from `PetCatalog[species].name`), target `RollStation` |
| else | `GoalRebirthCoins`: "Reach 50,000 Coins for Rebirth 1! (12%)" (cost from `state.rebirth.cost`), target nil |

`done`: never while `goalsOn`. `when`: `goalsOn and guideCompleted`.

**8. `Guide.Resolve`** keeps its order. `tip()` now nearly always returns a card, so
`step("Complete")` remains only as the post-payoff fallback for old saves. The tag for GOAL
cards: `card.tag = "GOAL"`; `card.total = nil`. `CommanderGuide` renders the tag line as
"GOAL" only.

**9. `Guide.CardIds`.** An exported set of every id `Resolve` can return (Core ids, every tip
card id, `RecoverCollect`, `RecoverSell`, `Complete`, `Defend`, `Return`, `Battle`, the GOAL
ids, `"NextCamp"`, plus `CampGuide.Ids` if present). Analytics validates against it.

**10. `Guide.HudReveal(state, facts, sinceCore: number, visitSeconds: number): {[string]: boolean}`**
- A pure table keyed by `Army`, `Rebirth`, `Settings`, `Playtime`, `Index`, `FreeGift`,
  `Shop`, `GoldRush`, `Boosts`, `FriendBoost`, following section 3.4.
- Returns all true when `Config.Guide.HudReveal` is false or `sinceCore ≥ RevealAllSeconds`.
- `Guide.HudReveal` is also where WS7 may plug its `FriendBoost` predicate
  (`Guide.RevealHooks.FriendBoost = fn`).

### 4.3 `src/client/CommanderGuide.luau` (WS5)

**1. Beat queue.**
- `self.beats = {}`. `Commander:Beat(name, seconds, fn)` appends.
- `Commander:BeatBusy()` is true during the payoff hold or the active beat.
- Each `Update` runs the next beat when not `BeatBusy()` and not `app:ModalBusy()`.
- `CelebrateCore` and `Payoff` become beats. The next card's typewriter starts only after the
  queue drains.
- Expose `app:Beat` and `app:BeatBusy` (AppController delegates) for WS4/WS7.

**2. HUD reveal driver.**
- Track `self.coreSeenAt` (os.clock when `facts.Core` first true this visit) and
  `self.visitStart`.
- Each Update: `reveal = Guide.HudReveal(state, facts, os.clock() - coreSeenAt, os.clock() - visitStart)`.
- For each key newly true: `self:Beat("reveal:" .. key, BeatGapSeconds, function() hud:Reveal(key) end)`.
- `hudStage` stays as today during the tutorial. After completion, call
  `hud:SetTutorialStage("post", reveal)` instead of `nil`, until every key is revealed. Then
  call `nil`.
- `completedBeforeVisit` keeps `nil`, so returning players see everything.

**3. GOAL visibility.**
- `current.tag == "GOAL"`: visible if the visit is under `GoalAlwaysSeconds`, or if within
  `GoalPeekSeconds` of first show, a quarter crossing, or idle.
- Idle = no `meaningful` action. The client tracks `lastActionAt` from `AppController:Receive`
  results with `ok` and an action in {Roll, Buy, BuyUpgrade, Attack, Sell, CollectEggs, deposit}.
- Otherwise hide the card but keep `current` (the beam stays off for GOAL cards: target nil
  except `GoalFind`).

**4. Tag rendering.**
- `current.tag == "GOAL"` gives `self.tag.Text = "GOAL"`.
- No dim and no ring for GOAL cards. The world beam is only for `GoalFind` (RollStation),
  through the existing `OpeningGuidance`.

**5. Card signal.**
- When the visible card id changes (including to `"None"` when hidden or empty), send
  `app:Request("TutorialSignal", {signal = "Card", card = id})`.
- Throttled to one per second. The last change is sent after the throttle (`task.delay`).
- The Daily/menu hide counts as `"Hidden"`.

**6. Reveal signal.** `app:Request("TutorialSignal", {signal = "Reveal", card = key})` when a
reveal plays.

**7. `SetArmyHidden`** is unchanged (Army reveals at completion).

**8. Rebuild/Grow menu targets** reuse `UpgradeTarget` (Open hexes on the way, ring and dim as
for Start/Expand). The tree centres the node except Flock1, which keeps the Oct 25 no-pan rule.

### 4.4 `src/client/HudController.luau` (WS5; WS3 adds `HintShop`)

**1. `SetTutorialStage(stage, reveal)`.** Add stage `"post"`:
- `quiet = false`.
- The hold stays, and `park(child)` parks only names mapped to keys whose `reveal[key]` is
  false. The table is `HOLD_KEYS = {Topbar="Settings", PlaytimeTopbar="Playtime",
  GoldRushChip="GoldRush", BoostSlot="Boosts", FreeGiftCorner="FreeGift",
  ChickenOfferCorner="FreeGift"}`.
- Children not in the table are released.
- Shortcuts: `shown.Shop = reveal.Shop`, `shown.Index = reveal.Index`.
- `friendBoostSlot.Visible = reveal.FriendBoost`.
- `self.revealed = reveal`.

**2. `Hud:Revealed(key): boolean`** returns `self.tutorialStage == nil or (self.revealed or {})[key] == true`.

Replace the `self.quiet` reads with `not self:Revealed(...)`:
- `UpdateFreeGift` → `Revealed("FreeGift")`;
- `UpdateChickenOffer` → `Revealed("FreeGift")`;
- `UpdateRebirth` → `Revealed("Rebirth")`, which is true at completion;
- `UpdateUpgradesBadge` → keeps `quiet`.

**3. `Hud:Reveal(key)`.**
- Un-park the mapped children and set visibility.
- `Theme.Motion:PopScale` on its `Visual` (or the frame).
- Add the "NEW!" tag (`Theme.Display(visual, "NewTag", "NEW!", 22, Color3.fromRGB(255,221,46))`,
  black stroke, `AnchorPoint (0,0)`, position `(0,-0.05)`, size `(0.6,0.24)`, ZIndex 9).
- `Theme.Motion:Ping(tag, 1.6)`.
- Remove the tag on the button's first `Activated` or after 30 s.
- `app:Cue("Badge", "Pop")`.
- Scale only. No position changes.

**4. `Hud:HintShop(seconds)`** (WS3's method). Return false unless `Revealed("Shop")`.

**5. `app:TutorialComplete()`** (WS7 asked for it). AppController returns
`state.tutorial.guideCompleted == true`. It is documented in HudController's stage comment.

### 4.5 `src/client/AppController.luau` (shared: WS3, WS7 add their hunks)

**1. `AppController:ModalBusy(): boolean`** is true if any of these hold:
- `panel.Visible`;
- `research.root.Visible`;
- `rebirthPanel.gui`;
- `dailyReward.gui`;
- `freeGift.gui`;
- `playtimePanel.gui`;
- `autoRollMenu.gui`;
- `offlineCash.gui`;
- `dialogueActive`;
- `commerce.cratePresenting`;
- `marchFilm.playing`;
- `intro:Pending()`;
- the roll camera zoom (`base.roller.rollCamera.zoom`);
- `friendBoost.invitePromptOpen` (WS7 sets it).

**2. Beat delegates.**
- `AppController:Beat(...)` → `self.commander:Beat(...)`.
- `AppController:BeatBusy()` → `commander:BeatBusy()`.
- If the commander is missing, run at once.

**3.** `AppController:TutorialComplete()`.

**4. Settings row "Goal hints".**
- `self:SettingRow("ToggleGoals", "Goal hints", "Show your next goal at the top", on/off pill, …)`.
- It sends `TutorialSignal` `HideGoals` / `ShowGoals`; `TutorialService` saves `goalsHidden`.
- Name `ToggleGoals` is already mapped in `AnalyticsUiObserver.SETTINGS`.

### 4.6 `src/client/DailyRewardController.luau` (WS5)

**1. `Blocked()`** adds:
- `if Config.Guide.ModalQueue and app.ModalBusy and app:ModalBusy() and os.clock() - (self.pendingAt or 0) < Config.Guide.DailyWaitMaxSeconds then return true end`.
- `self.pendingAt` is set in `Render` when `pending` arrives.
- Also `app:BeatBusy()` replaces the `commander:Celebrating()` check.

**2. `Show`** still calls `CloseOtherMenus("daily")`. It is rarely needed now, because it
waited for menus to close. At the cap, it behaves as today.

### 4.7 `src/server/TutorialService.luau` and `src/server/GameServer.luau` (shared with WS1/WS3/WS7)

**1. TutorialService.**
- Where `coreDone` flips (`:177-179`), add `if Config.Guide.DailyAtCore then session.dailyCheckDue = true end`.
- Accept signals `Card` and `Reveal` in the `signals` set, but return early. They are
  analytics-only, and `Tutorial:Signal` ignores them.
- `HideGoals` / `ShowGoals` already save.

**2. GameServer.**
- In the heartbeat (`:708`), before the 10 s cadence:
  `for _, s in self.sessions do if s.dailyCheckDue and s.dailyReady and s.loaded and not s.closing and not s.saveLost then s.dailyCheckDue = nil; DailyService.Check(s, wallTime, self) end end`.
- `TutorialSignal` (`:222`): `self.analytics:Signal(session, request.signal, request.card)`.

### 4.8 `src/client/CornerNotice.luau` (WS5)

`Next()`: if `app.ModalBusy and (app:ModalBusy() or app:BeatBusy())`, retry in 0.5 s, keeping
the spec at the queue head. This applies to the Show path too.

### 4.9 `src/client/PlaytimePanel.luau` (WS5)

- `Step()`: while `not app.hud:Revealed("Playtime")`, do not mark tiles `seen` and do not
  `Announce`.
- On reveal (`Hud:Reveal("Playtime")` calls `app.playtimePanel:Revealed()`), announce once:
  "Free Reward Ready!" with the count of ready tiles.

### 4.10 `src/client/GoldRushController.luau`, `src/client/BoostReadout.luau` (WS5, one line each)

- GoldRush `Place()` quiet test: `not hud:Revealed("GoldRush")`.
- BoostReadout `Render` visibility: `hud:Revealed("Boosts")`.

### 4.11 `src/client/BaseController.luau` (owned by WS1 for the NEXT marker)

- WS5 needs no edit. `OpeningGuidance` already follows `Guide.Resolve` with `tipSkip`.
- `GoalFind` gives target `RollStation` and caption "ROLL" automatically.
- `GoalRebirth0` and `GoalRebirthCoins` give target nil, so no beam.
- Note for WS1: "Rebirth"/"Gems" targets return nil there already.

### 4.12 Docs

- New `docs/team/POST_TUTORIAL_FLOW_20261027.md`: the contract, with the section 3.5 timeline,
  every card's copy, the reveal table, flags and rollback.
- `docs/team/COMMANDER_TUTORIAL.md`: a dated top section.
- AGENTS.md tutorial bullet: one paragraph, "Goals after the tutorial (Oct 27)".
- `docs/analytics/ONBOARDING_FUNNEL.md`: a "Post-tutorial" section (section 5).

### 4.13 Copy (every new player-facing string)

| Id | Tag | Text |
|---|---|---|
| TipArmyRoll | TIP • 1/3 | Roll a chicken for your Army! (2/3) |
| TipArmyBuy | TIP • 1/3 | Buy the chicken! |
| RecoverCollect (in chain) | TIP • 1/3 | Collect eggs worth 40 more Coins |
| RecoverSell (in chain) | TIP • 1/3 | Sell your eggs on the green pad! |
| TipArmyReady | TIP • 2/3 | Vacuum eggs to get ready for battle! (12/20) |
| TipArmyReady (outside) | TIP • 2/3 | Equip your Egg Vacuum! |
| TipAttack | TIP • 3/3 | Send your Army to attack Cluck Camp! |
| TipRebuildVacuum | TIP • 1/2 | Claim your Egg Vacuum again! |
| (outside / wrongTab) | TIP • 1/2 | Open Upgrades for an Egg Vacuum! / Open the Tools category! |
| TipRebuildFlock | TIP • 2/2 | Expand your plot again! |
| (outside / wrongTab) | TIP • 2/2 | Open Upgrades! / Open the Main category! |
| Rebuild payoff | TIP • COMPLETE! | Yard rebuilt! |
| TipGrow<id> | TIP • n/3 | Buy Egg Speed I! / Buy Egg Value I! / Buy Army Size I! |
| (outside / wrongTab) | TIP • n/3 | Open Upgrades! / Open the Main category! |
| Grow payoff | TIP • COMPLETE! | Upgrades learned! |
| GoalRebirth0 | GOAL | Reach 1,700 Coins for Rebirth 0! (976/1,700) |
| GoalFind | GOAL | Find an Ironbeak Chicken for Rebirth 1! |
| GoalRebirthCoins | GOAL | Reach 50,000 Coins for Rebirth 1! (12%) |
| NEW tag | — | NEW! |
| Playtime reveal notice | (CornerNotice) | Free Reward Ready! / Open the gift at the top to claim it! (existing) |
| Settings row | — | Goal hints · Show your next goal at the top · ON/OFF |

Word check: Army, chickens, Coins, Upgrades, "Rebirth N", Camp names. No "pets", "cash", "$",
"merge", or "Press"/"Tap". "GOAL" and "NEW!" are new tags; they are not concept names.

### 4.14 Saved fields

None are needed. All gates derive from existing saved facts:
- `vacuumSold`, `introRebirth`, `firstWins`, `discovered`, tree tiers;
- `passiveEarned` / `battleEarned`;
- `goalsHidden`, which already exists in `TUTORIAL_KEYS`.

`dailyCheckDue` is session-only (not saved). There is no `DataRevision` bump and no
TreeMigrations step.

---

## 5. Analytics (append-only; `Schema.Version = 16`)

### 5.1 Seeing past the 60-event cap: the tail ring buffer

- `Schema.JourneyTailCap = 15`.
- `Analytics:_Trail` always also pushes `{sec, code}` into `st.tail`, a ring of 15.
- `Analytics:Leave` adds `tl = st.tail` (oldest first) to the journey.
- The trail is unchanged, so old readers are unaffected.
- Each journey grows by about 0.4 KB. Check `Ledger:Journey` against the 4 MB key limit with
  `JourneyCapPerKey = 60` (60 × ~2 KB ≈ 120 KB per key, well under).

### 5.2 What the player actually saw: the visible card

- `Analytics:Signal(session, signal, card)`: for `signal == "Card"`, validate `card` (string ≤
  32, in `TutorialGuide.CardIds` or "None"/"Hidden", else "Other").
- Then:
  - `ledger:Hist("post.card.dwell." .. old, "seconds", now - st.cardAt)` for the previous card;
  - `ledger:Count("post.card.enter." .. card)`;
  - `_Trail(st, "card:" .. card)`;
  - `st.card, st.cardAt = card, now`;
  - if card is None, also `st.noneAt = now`.
- No `ui.<signal>` count for Card/Reveal (avoid key spam).
- At `Leave`, for players with `guideCompleted` in the Ob or Post stage:
  - `ledger:Count("post.exit." .. (st.card or "Unknown"))`;
  - when the card is None or Hidden, `ledger:Hist("post.exit.gap", "seconds", now - st.noneAt)`;
  - journey fields `cv = st.card` and `cs = now - st.cardAt`.
- Also `ledger:Hist("post.sessionAfterCore", "seconds", now - st.coreAt)`, where `st.coreAt` is
  set when the Onboarding step 11 is reached this session.

### 5.3 HUD reveals

- `signal == "Reveal"`: `ledger:Count("hud.reveal." .. key)` (key in the `HudReveal` key set),
  `st.revealAt[key] = now`, and `_Trail(st, "reveal:" .. key)`.
- For `ui.click` events "Hud/<Button>" (existing client event), map Button → key
  (`Shop→Shop`, `Index→Index`, `PlaytimeRewards→Playtime`, `FreeGift→FreeGift`). On the first
  click after a reveal: `ledger:Hist("hud.firstClick." .. key, "seconds", now - st.revealAt[key])`.
- Journey field `hr`: the revealed keys as a short string (for example "P,I,S").

### 5.4 Report

- `AnalyticsReport.PostText({days, env})` prints:
  - `post.exit.*` sorted (where finishers leave, by the card they saw);
  - `post.exit.gap` p50/p90;
  - `post.card.enter.*` and dwell p50;
  - `hud.reveal.*` with `hud.firstClick.*` p50.
- Add it to `Summary().post` and a flag rule: area "post", for the card with the most exits per
  enter.
- `Report.Journeys` passes `tl`/`cv`/`cs`/`hr` through.

### 5.5 Success metrics (compare build 1.27 against 1.25 / 1.26 by `version`, equal-length ranges)

| Metric | 1.25 baseline | Target |
|---|---|---|
| Finishers leaving ≤120 s after completion | 36.8% | ≤ 28% |
| Finishers leaving ≤300 s after completion | 62.4% | ≤ 52% |
| Exits with no visible card (`post.exit.None` + `Hidden` / finisher exits) | ~88% (proxy) | ≤ 25% |
| Vacuum-chain finishers who leave before the next card (gap A) | 26% | ≤ 8% |
| Survival 5 min / 10 min (all new sessions) | 36% / 21% | 41% / 25% |
| `ob.reach.14` / `ob.reach.12` (Cluck Camp after vacuum) | 554/724 = 77% | ≥ 82% |
| Vacuum re-claimed after Rebirth 0 (`upgrade.buy.EggVacuum` − `ob.reach.12`) / Rebirths | ~64% | ≥ 90% |

Guardrails (must not drop):
- tutorial completion `ob.reach.11/ob.reach.01` (63%);
- Daily claim rate;
- `playtimeReward.claim.1–3`;
- Robux conversion (WS3 owns it).

---

## 6. Verification

### 6.1 Headless (Lune, `tools/sim/harness.luau … runsuite.luau <Suite>`)

Baseline at HEAD on Oct 27: CommanderGuideChecks 14/14, DailyChecks 10/10, PlaytimeChecks
12/12, AnalyticsChecks 15/15 (run headless with the scratchpad `lune-bin/lune`).

New tests in `tests/CommanderGuideChecks.luau`, on the `afterGuide()` fixture with
`introRebirth`:

1. **"A goal is always on screen from completion until Rebirth 1."**
   - Walk the states: completion → vacuum stages → `vacuumSold` with 2 chickens → offer short
     / offer affordable → 3 chickens unsettled → settled → Cluck Camp won → coins 900 / 1,700 →
     Rebirth 0 done with gems unspent → spent → vacuum reset → rebuilt → Grow nodes affordable
     / owned → find missing → find owned.
   - Assert that each `Resolve` is non-nil, not `Complete`, and its id is in `Guide.CardIds`.
2. **"Army chain."** `TipArmyRoll` "(2/3)" index 1/3, `TipArmyBuy`, earn steps as index 1,
   `TipArmyReady` "(12/20)" index 2/3, `TipAttack` index 3/3, payoff "Camp captured!".
3. **"Rebuild after Rebirth 0."** It shows only with `introRebirth = "done"` and the vacuum not
   owned. Vacuum, then Flock I. Done when both are owned. It never shows before Rebirth 0.
4. **"Grow nudges."** They wait for Rebirth 0 and affordability, follow the `GrowNodes` order,
   skip Owned nodes, and use the menu lines outside/wrongTab.
5. **"GOAL cards."** Rebirth 0 progress text with grouped numbers. Then the find (name from
   `PetCatalog`). Then 50K % (floor, 0–99, or 100).
6. **"Priority."** Rebirth preempts everything; Vacuum before Rebuild before Attack before Camp
   before Grow before Goal.
7. **"Opt-outs."**
   - `goalsHidden` turns off Goal/Grow/Rebuild/Army extras; the old Attack `when` applies.
   - Saves without `introRebirth` get no GOAL cards.
   - `Config.Guide.Goals = false` restores the 1.26 resolution exactly. Compare `Resolve` over
     the walk against a frozen 1.26 expectation list.
8. **"HudReveal."** Each predicate. All true at `RevealAllSeconds`. All true with the flag off.
   Shop at 2,000 earned, matching `Config.Guide.ShopRevealEarned`.

Also:
- `tests/AnalyticsChecks.luau`:
  - tail ring keeps the last 15 after the 60-entry cap;
  - Card signal validation ("Other" for unknown);
  - `post.exit.<card>` counted at Leave;
  - `Schema.Version == 16`;
  - the journey carries `tl`/`cv`/`cs`.
- `tests/DailyChecks.luau`: `coreDone` sets `dailyCheckDue`; one heartbeat grants Day 1; a
  legacy completed save is unaffected.
- `tests/PlaytimeChecks.luau`: no announce before the reveal; one announce on reveal.

### 6.2 Studio playtest script (Pet Roll Test, Edit check per AGENTS, disposable profile)

1. Settings → "Test as a New Player". Drive through `RequestAction` (memory recipe: Roll/Buy
   with `stationIndex`/`offerId`, CollectEggs `ids`, BuyUpgrade `nodeId`/`expectedPrice`) to
   card 8.
2. At completion: `Shell/HUD` shows Navigation, Rebirth and Settings; PlaytimeTopbar, Shop,
   Index, FreeGiftCorner and GoldRushChip are still parked in `TutorialHold`. Screenshot.
3. Daily opens within completion +4.0–5.5 s (once the payoff ends). After X, the card reads
   "TIP • 1/7 … (0/12)".
4. Open Upgrades before the payoff ends: Daily waits until the tree closes, and does not close
   it.
5. Finish the vacuum chain. "Vacuum learned!" is followed by the Playtime gift pop with "NEW!"
   and a corner notice, then "TIP • 1/3 Roll a chicken for your Army! (2/3)". Screenshots.
6. Buy the 3rd chicken, attack and win Cluck Camp. The card is never empty: sample
   `CommanderGuide.Card.Objective.Text` every 0.5 s, and empty is allowed only while a modal is
   open.
7. Grant Coins to 1,700 (DebugService), then Rebirth 0. Then "Claim your Egg Vacuum again!".
   Shop, Gold Rush and boosts reveal one at a time, ≥1.5 s apart.
8. Phone viewport (749×381 touch emulation): the NEW tag is unclipped, nothing overlaps, and the
   one layout is unchanged.
9. Toggle Settings → Goal hints OFF: GOAL/Grow cards disappear and Stevin's tips remain.
10. Reduced motion: no pings; tags static.

---

## 7. Risks, owner-rule conflicts, rollback

| Item | Assessment |
|---|---|
| Oct 21 "no instructions after the Daily reward" | Already superseded by Oct 23 tips. GOAL/Grow/Rebuild extend tips beyond his three chains. **Flag to Stevin as an extension.** Mitigations: Settings "Goal hints" OFF, peek-only after 15 min, ends at Rebirth 1. |
| Oct 25 "everything else once the tutorial is over" (HUD) | Progressive reveal changes timing only. **Flag as a partial reversal**, with a hard cap at 8 min after completion and `Config.Guide.HudReveal = false` to restore. Evidence is weaker (section 1.5), so it ships behind its own flag and can be turned off without touching goals. |
| Oct 24 "Camp tip once settled" | Kept (20 vacuumed / 60 by hand). Only the wait is visible, which is the D pattern he accepted. |
| Oct 26 NextCamp timed card | Kept as the default; WS1 decides when a camp card persists. |
| Daily at completion (E declined) | Kept. Only timing (immediate grant) and no menu stomping. Not a reversal. |
| Reference 1:1 popups | Daily and Playtime UIs are unchanged. |
| HUD not copied / ONE layout / Scale only | No moves. The NEW tag is a small overlay like the red badges; Scale only. |
| One emphasis per event | The beat queue enforces it. Risk: a slow queue delays cards by a few seconds. Cap: a beat waits at most 3 s for `ModalBusy`, then drops reveals (not cards). |
| Arrows white, dimming only in menu cards | GOAL cards never dim. Grow/Rebuild use the existing menu ring. |
| Over-guidance annoyance | GOAL cards peek after 15 min; Settings opt-out; Grow capped at 3 nodes; tips are one line. |
| Rebirth 0 economics | Grow waits for Rebirth 0, so no Coins are spent into the reset. Rebuild restores what the reset removed. Flag WS2: Flock I at 10 Coins after the reset is trivially cheap (keeps the yard moving). |
| Card-signal traffic | ≤1 per second, a few per minute. Rides the existing `RequestAction` remote throttle. |
| Analytics growth | New key families `post.*` and `hud.*` (about 60 keys a day). Journey +0.4 KB. |

**Rollback.** Each `Config.Guide` flag independently:
- `Goals`, `ArmyTips`, `Rebuild` and `Grow` restore the 1.26 tip chains;
- `HudReveal` restores the 1.26 "all at completion";
- `DailyAtCore` restores the 10 s cadence;
- `ModalQueue` restores Daily/CornerNotice as today.

Analytics additions stay (append-only).

---

## 8. Files touched and interfaces

### 8.1 FILES TOUCHED (WS5 writer unless marked)

- `/Users/stevin/Documents/Projects/MyChickenArmy/src/shared/TutorialGuide.luau`: chains,
  GOAL cards, `CardIds`, `HudReveal`, CampGuide hook.
- `/Users/stevin/Documents/Projects/MyChickenArmy/src/client/CommanderGuide.luau`: beat queue,
  reveal driver, GOAL visibility/tag, Card/Reveal signals.
- `/Users/stevin/Documents/Projects/MyChickenArmy/src/client/HudController.luau`: `"post"`
  stage, `Revealed`, `Reveal`, NEW tag. WS3 adds `HintShop` in the same file, coordinated
  through WS5.
- `/Users/stevin/Documents/Projects/MyChickenArmy/src/client/AppController.luau`: SHARED with
  WS3/WS7. WS5 adds `ModalBusy`, `Beat`/`BeatBusy`, `TutorialComplete` and the Goal hints row.
- `/Users/stevin/Documents/Projects/MyChickenArmy/src/client/DailyRewardController.luau`:
  `Blocked`/`pendingAt`.
- `/Users/stevin/Documents/Projects/MyChickenArmy/src/client/CornerNotice.luau`: `Next` gate.
- `/Users/stevin/Documents/Projects/MyChickenArmy/src/client/PlaytimePanel.luau`: announce on
  reveal.
- `/Users/stevin/Documents/Projects/MyChickenArmy/src/client/GoldRushController.luau`: one line.
- `/Users/stevin/Documents/Projects/MyChickenArmy/src/client/BoostReadout.luau`: one line.
- `/Users/stevin/Documents/Projects/MyChickenArmy/src/server/TutorialService.luau`:
  `dailyCheckDue`, accept Card/Reveal.
- `/Users/stevin/Documents/Projects/MyChickenArmy/src/server/GameServer.luau`: SHARED with
  WS1/WS3/WS7. WS5 adds the `dailyCheckDue` heartbeat hunk and passes `request.card` to
  `analytics:Signal`.
- `/Users/stevin/Documents/Projects/MyChickenArmy/src/server/Analytics.luau`: tail ring,
  Card/Reveal handling, `post.*` at Leave, journey fields.
- `/Users/stevin/Documents/Projects/MyChickenArmy/src/server/AnalyticsSchema.luau`: Version
  16, `JourneyTailCap`, comment block. SHARED if other WS also bump: one combined bump by the
  lead.
- `/Users/stevin/Documents/Projects/MyChickenArmy/src/server/AnalyticsReport.luau`:
  `PostText`, `Summary().post`, Journeys passthrough.
- `/Users/stevin/Documents/Projects/MyChickenArmy/src/shared/Config.luau`: SHARED. WS5 adds the
  `Guide` block and the Version label (the lead picks the final label).
- `/Users/stevin/Documents/Projects/MyChickenArmy/tests/CommanderGuideChecks.luau`,
  `/Users/stevin/Documents/Projects/MyChickenArmy/tests/AnalyticsChecks.luau`,
  `/Users/stevin/Documents/Projects/MyChickenArmy/tests/DailyChecks.luau`,
  `/Users/stevin/Documents/Projects/MyChickenArmy/tests/PlaytimeChecks.luau`.
- Docs:
  - `/Users/stevin/Documents/Projects/MyChickenArmy/docs/team/POST_TUTORIAL_FLOW_20261027.md`
    (new);
  - `/Users/stevin/Documents/Projects/MyChickenArmy/docs/team/COMMANDER_TUTORIAL.md`;
  - `/Users/stevin/Documents/Projects/MyChickenArmy/docs/analytics/ONBOARDING_FUNNEL.md`;
  - `/Users/stevin/Documents/Projects/MyChickenArmy/AGENTS.md` (one paragraph).

### 8.2 Interfaces

**WS1 (camps).** WS1 owns a new `src/shared/CampGuide.luau`. WS5 never edits it.
- `CampGuide.When(state, facts): boolean` and `CampGuide.Card(state, facts): card?`, where the
  card is `{id: string, text: string, target: "Camp<n>" | "Upgrades" | "RollStation" | nil,
  node: string?, index: number, total: number, seconds: number?, outside: string?}`.
- `CampGuide.Ids: {string}` for analytics.
- Example: "Next up: conquer Fort Roost!" only at Should win / Close fight, persistent; else a
  power step such as "Grow your Army for Fort Roost: buy Army Size I!".
- WS5 owns the chain slot (priority 5), the framework, payoffs and rendering.
- `BaseController`'s NEXT marker stays WS1's.
- `TutorialGuide.NextCamp`, `Difficulty` and the NextCamp cards stay in TutorialGuide as the
  fallback. WS1 asks WS5 for any edit there.

**WS2 (economy).**
- Confirm `Config.Guide.GrowNodes` (default EggSpeed1 400, EggValue1 600, ArmySize1 1,200) and
  the Rebirth 0 cost.
- Flag: after Rebirth 0, Flock I is 10 Coins, so the Rebuild card is instant. That is fine, or
  WS2 may reprice.
- The `earn()` copy uses live prices.

**WS3 (Robux prompt).**
- `Hud:HintShop(seconds)` is implemented in HudController by WS5 (or WS3's hunk), and returns
  false until `Revealed("Shop")`.
- Shop reveal and the prompt gate share `Config.Guide.ShopRevealEarned`.
- WS3's `BuyCoins` checks `app:ModalBusy()` / `app:BeatBusy()` before opening a checkout.
- WS3's held-back toast keeps the `earn()` wording.

**WS4 (roll variety and rarity moments).**
- Big reveal moments call `app:Beat("rare", seconds)`, so cards and reveals wait.
- The first non-basic species flips `discovered`, which reveals Index (WS5).
- If WS4 changes the Rebirth find ladder, `GoalFind` reads `PetCatalog.RebirthFinds`
  automatically.

**WS6 (performance).**
- The progressive reveal staggers the about 10 idle loops (Sway/Breathe/Glow/Wobble/spin) that
  start together at completion. WS6 may measure the completion frame.
- The NEW tag uses one Ping loop per revealed button, removed after the first click or 30 s.

**WS7 (social).**
- `app:TutorialComplete()` (WS5).
- `friendBoost.invitePromptOpen` feeds `ModalBusy`.
- No Daily or reveal within 5 s of the Rebirth-0 invite (the beat queue respects `ModalBusy`).
- The FriendBoost row reveal predicate may be replaced through `Guide.RevealHooks.FriendBoost`.

**Lead / integration.**
- One combined `Schema.Version` bump and `Config.Version` label.
- Merge order: WS5's `TutorialGuide` / `CommanderGuide` first, then WS1's `CampGuide` (the
  hook tolerates its absence).
- `tests/CommanderGuideChecks.luau` is WS5's. WS1 adds its CampGuide tests in its own suite file.
