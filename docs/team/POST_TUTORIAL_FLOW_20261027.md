# Post-tutorial flow: goal ladder, HUD reveal, popup order (October 27, 2026)

Contract for WS5 of the retention package (`docs/team/RETENTION_PLAN_20261027.md`; research
and numbers in `docs/team/retention-20261027/WS5-post-tutorial-flow.md`). It covers what a
new player sees from the end of the eighth tutorial card to Rebirth 1.

Why: 88% of tutorial finishers left with no actionable card on screen. The timed "Next up"
card had gone, the Vacuum chain had ended with nothing after it, or Rebirth 0 had passed.
36.8% left within 120 s of completing the tutorial.

Every piece has a switch in `Config.Guide` (Wave 0). Each one set to `false` restores the
1.26 behaviour on its own.

| Switch | On | Off |
|---|---|---|
| `Goals` | GOAL cards until `GoalUntilRank` (1) | no GOAL cards |
| `ArmyTips` | the Camp tip's wait is shown ("Roll a chicken for your Army! (2/3)", the settle count) | Oct 24 card alone, once the Army holds 3 and is settled; Oct 24 chain order |
| `Rebuild` | re-claim the vacuum / Flock Size I after a Rebirth that took them | no card |
| `Grow` | "Buy Egg Speed I!" etc. after Rebirth 0, as each is affordable | no card |
| `HudReveal` | the HUD comes in piece by piece, all by `RevealAllSeconds` (480) | everything at completion (Oct 25) |
| `DailyAtCore` | Day 1 granted on the next server step after completion | the 10 s Daily cadence |
| `ModalQueue` | Daily and corner notices wait for an open menu or film | as before |

## 1. The goal ladder (`TutorialGuide`)

One card at a time. Chains are checked in priority order and the first match wins:

1. **Rebirth**: Rebirth 0 once affordable, then the Gem card (unchanged).
2. **Vacuum**: the count, claim, equip, use and sell cards (unchanged).
3. **Rebuild** (new): after any Rebirth that left the Egg Vacuum or Flock Size I unowned.
   With `Config.Rebirth.Intro.KeepTree` (WS2) that never happens after Rebirth 0. It does
   happen after Rebirth 1 and up, and after Rebirth 0 when KeepTree is off.
4. **Attack** (extended, "TIP • n/3"):
   - 1: fewer than 3 chickens in the Army: the lever (with the count), the buy, or the earn
     steps for its Coins. With 3 owned but fewer in the Army: "Equip Best in My Army!".
   - 2: the settle wait (Oct 24: 20 vacuumed or 60 by hand) as a count, "(12/20)".
   - 3: the attack.
5. **Camp**: WS1's `CampGuide` when that module is in the place
   (`script.Parent:FindFirstChild("CampGuide")`, nil-safe). It shows the readiness card or
   the cheapest power step, persistent, keeps its own tag ("NEXT: FORT ROOST") and its
   `progress`. The client draws `progress` as the "ARMY 38 / 84" bar. Without the module,
   or with `Config.CampLadder.ReadinessTip` off, the October 26 timed "Next up" card stays.
   The odds bands follow `CampGuide.EvenRatio` / `ReadyRatio` when it is present.
6. **Grow** (new, after Rebirth 0): `Config.Guide.GrowNodes` in order, each as soon as it is
   affordable (status `Available`). A node the Camp card already points at is skipped
   (WS1's Army Size step). Payoff "Upgrades learned!" once all are owned.
7. **GOAL** (new, tag "GOAL", no count, no dim, no ring):
   - Rebirth 0 Coins.
   - Then the chicken to find for the next Rebirth: `state.rebirth.find`, else
     `PetCatalog.RebirthFinds`. Target RollStation.
   - Then the Coins for it, as a percentage.
   - "Rebirth N is ready!" once eligible.

Profiles without the empty start (`introRebirth == nil`) get none of the extras.
`tutorial.goalsHidden` turns off the extras too: the Army count cards, Rebuild, Grow and
GOAL. Stevin's own tips stay.

**Invariant.** For an empty-start profile with the tutorial completed, rank < 1 and Goal
hints on, `Guide.Resolve` never returns nil or "Complete" while the Army is home. This is
checked in `tests/CommanderGuideChecks.luau`, "Goal ladder: a card is always on screen".

### Copy

| Id | Tag | Text |
|---|---|---|
| TipArmyRoll | TIP • 1/3 | Roll a chicken for your Army! (2/3) |
| TipArmyBuy | TIP • 1/3 | Buy the chicken! |
| RecoverCollect / RecoverSell (in the chain) | TIP • 1/3 | Collect eggs worth N more Coins / Sell your eggs on the green pad! |
| TipArmyEquip | TIP • 1/3 | Equip Best in My Army! |
| TipArmyReady | TIP • 2/3 | Vacuum eggs to get ready for battle! (12/20); outside "Equip your Egg Vacuum!"; full "Vacuum full! Sell your eggs on the green pad!"; no vacuum "Collect eggs to get ready for battle! (n/20)" |
| TipAttack | TIP • 3/3 | Send your Army to attack Cluck Camp! |
| TipRebuildVacuum | TIP • 1/2 | Claim your Egg Vacuum again! (Open Upgrades for an Egg Vacuum! / Open the Tools category!) |
| TipRebuildFlock | TIP • 2/2 | Expand your plot again! (Open Upgrades! / Open the Main category!) |
| Rebuild payoff | TIP • COMPLETE! | Yard rebuilt! |
| TipGrow&lt;node&gt; | TIP • n/3 | Buy Egg Speed I! / Buy Egg Value I! / Buy Army Size I! |
| Grow payoff | TIP • COMPLETE! | Upgrades learned! |
| GoalRebirth0 | GOAL | Reach 1,700 Coins for Rebirth 0! (976/1,700) |
| GoalFind | GOAL | Find an Ironbeak Chicken for Rebirth 1! |
| GoalRebirthCoins | GOAL | Reach 50,000 Coins for Rebirth 1! (12%) |
| GoalRebirthReady | GOAL | Rebirth 1 is ready! Open Rebirth! |
| HUD tag | — | NEW! |
| Settings row | — | Goal hints · Show your next goal at the top · ON/OFF |

## 2. What the client shows (`CommanderGuide`)

- **GOAL visibility.** A GOAL card stays on screen for the first `GoalAlwaysSeconds` (900)
  of a visit. After that it peeks for `GoalPeekSeconds` (10) at these moments:
  - when it first appears;
  - when its Coins progress crosses a quarter;
  - once after `GoalIdleSeconds` (25) with no progress (Coins, chickens, eggs or pulls
    changing).
- **Beat queue.** One emphasis at a time:
  - The tutorial payoff and each "TIP • COMPLETE!" count as beats.
  - Each HUD reveal is a queued beat, `BeatGapSeconds` (1.5) long. It runs only while
    nothing modal is open.
  - Another feature's big moment calls `app:Beat(kind, seconds)` (no function) and holds
    the stage.
  - A new card types only once the running beat ends.
  - `app:BeatBusy()` exposes the state.
- **Popup order.** The order is payoff (4 s), then Daily, then the first tip:
  - `TutorialService` marks `session.dailyCheckDue` when `coreDone` flips.
  - `GameServer` grants Day 1 on the next step.
  - The Daily popup waits out the payoff (`BeatBusy`).
  - While Daily is due (`DailyRewardController:Due()`), the next card waits.
  - Daily never closes the player's menu: it waits while `app:ModalBusy()` is true, for up
    to `DailyWaitMaxSeconds` (45), then opens as before.
- **Corner notices** ("Free Reward Ready!") wait while `ModalBusy` or `BeatBusy` is true.
- **Analytics.** The visible card goes to the server as a `Card` signal: its id, "Hidden"
  or "None". The signal is throttled to one a second and sent once the tutorial is done.
  Each reveal sends a `Reveal` signal.

`app:ModalBusy()` covers these cases:
- the main panel;
- the Upgrades tree;
- the Rebirth, Daily, Free Gift, Playtime, Auto Roll and offline popups;
- dialogue;
- a crate presentation;
- the march film;
- the intro;
- the roll camera zoom;
- WS7's `friendBoost.invitePromptOpen`.

`app:TutorialComplete()` is true once `tutorial.guideCompleted` is set.

## 3. Progressive HUD reveal (`TutorialGuide.HudReveal`, `Hud` stage "post")

Same positions, sizes and art; only the timing changes. `sinceCore` is the client's
seconds since it saw the tutorial complete in this visit.

| Key (hudLayer children) | Revealed when |
|---|---|
| Army (`Navigation`), Rebirth (`RebirthCorner`), Settings (`Topbar`) | at completion, with the payoff |
| Playtime (`PlaytimeTopbar`) | `vacuumSold`, or `sinceCore` ≥ 150; one "Free Reward Ready!" covers the tiles already ready |
| Index (shortcut) | 2+ species in `discovered`, a Camp won, or `sinceCore` ≥ 300 |
| Free Gift / chicken offer (`FreeGiftCorner`, `ChickenOfferCorner`) | visit ≥ 300 s or Rebirth 0 done |
| Shop (shortcut) | Coins earned ≥ `ShopRevealEarned` (2,000), Rebirth 0 done, or `sinceCore` ≥ 360. Only the button: the Robux gate is WS3's `Config.CoinsPrompt` |
| Gold Rush (`GoldRushChip`), boosts (`BoostSlot`) | Rebirth 0 done, a boost running, or `sinceCore` ≥ 360 |
| Friend Boost row | a Camp won, a friend boost, or `sinceCore` ≥ 360 (`Guide.RevealHooks.FriendBoost` for WS7) |
| anything else (Rally, Auto Roll, hotbar, CornerNotice …) | at completion |
| everything | `sinceCore` ≥ `RevealAllSeconds` (480), or the tutorial was completed before this visit, or the save has no empty start |

`Hud:Reveal(key)` does three things:
- `PopScale` and one Badge cue;
- for buttons, a yellow "NEW!" tag (Display text, black outline) on the top-left that pings
  until the first press or 30 s;
- under reduced motion, the tag shows still.

`Hud:Revealed(key)` answers per piece. Free Gift, the offer, Rebirth, Gold Rush and the
boost readout read it instead of `quiet`. `Hud:HintShop(seconds)` (WS3) returns false until
the Shop is revealed.

## 4. Analytics (schema 16)

| What | Where |
|---|---|
| Journey `tl` | the last 15 trail entries, also past the 60-entry cap |
| `post.card.enter.<id>`, `post.card.dwell.<id>` | the card the player saw; unknown ids read "Other" |
| `post.exit.<card>` | finishers' exits by the card on screen; `post.exit.gap` = seconds without one |
| `post.sessionAfterCore` | seconds played after completing in this session |
| `hud.reveal.<key>`, `hud.firstClick.<key>` | reveals and the time to the first press |
| Journey `cv`, `cs`, `hr` | card at leave, seconds on it, reveal codes ("P,I,S") |

Read it with `AnalyticsReport.PostText({days = 2, env = "live"})`, or `Summary().post`. A
flag rule names the card with the most exits per entry.

Targets (compare 1.27 against 1.25 by `version`):

| Metric | Baseline | Target |
|---|---|---|
| Finishers leaving ≤120 s after completion | 36.8% | ≤ 28% |
| Exits with no card | ~88% | ≤ 25% |
| Leaving in the post-vacuum gap | 26% | ≤ 8% |

## 5. Rollback

Flip the matching `Config.Guide` switch (table at the top). Analytics names stay
(append-only).
