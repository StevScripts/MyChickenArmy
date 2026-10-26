# Onboarding funnel (analytics schema 15, October 24, 2026)

Stevin: "completely revamp the funnels section for the onboarding especially pls rn the
data is super messy just redo it all for here and record the new data only only go into
detail for a step when it matters I just need to see where players are leaving."

This funnel replaces the 29-step Tutorial funnel of schema 11–14 (`TUTORIAL_FUNNEL.md`,
not recorded since 15): fifteen hard steps in the order they happen to a new player,
four ledger keys, one printed table. Nothing else is recorded for it: no dwell, no
first-session share, no gap/skip counters, no exit lesson, no cohort step keys, and the
`TutorialExit` custom event is no longer sent.

Source of truth: `Schema.Onboarding` in `src/server/AnalyticsSchema.luau` (if this page
and the schema disagree, the schema wins). Recorded by `src/server/AnalyticsTutorial.luau`
(the file keeps its schema 11 name). Report: `AnalyticsReport.OnboardingText` /
`Summary().onboarding`. Checks: `tests/AnalyticsChecks.luau` (the "Onboarding" checks).

## Who is counted

Fresh empty-start profiles only: the save was fresh the first time this version saw the
player (`Analytics.FreshSave`: guide never started, nothing rolled, bought or won) **and**
carries `introRebirth` (every save made since the October 23 empty start). The analytics
profile then holds `ob`, so the funnel follows the player across sessions and servers.
Each step counts **once per player, ever**. Older players never enter it, so rates are not
diluted by veterans. Rebirths do not un-reach a step (a vacuum bought before Rebirth 0 stays
counted; one bought only afterwards counts then).

## Steps

| NN | Step (Roblox label) | Counts when |
|---|---|---|
| 01 | Joined the game | PlayerAdded (`Analytics:Join`) |
| 02 | Save loaded | the profile loaded (`Analytics:Loaded`) |
| 03 | Card 1: pulled the lever (1/8) | `TutorialGuide.RollCount(tutorial) >= 1` (`rollCount`, or the old `rolled` flag) |
| 04 | Card 2: took the chicken (2/8) | `tutorial.bought` |
| 05 | Card 3: 1st egg clicked | `tutorial.collectedEggCount >= 1` |
| 06 | Card 3: 3 eggs clicked (3/8) | `tutorial.collectedEggCount >= TutorialGuide.EggGoal` (3) |
| 07 | Card 4: sold eggs (4/8) | `tutorial.soldEggs` |
| 08 | Card 5: claimed Start (5/8) | `tutorial.startClaimed` |
| 09 | Card 6: expanded the plot (6/8) | Upgrades tree `Flock` tier ≥ 1 (Flock Size I) |
| 10 | Card 7: pulled the lever again (7/8) | `TutorialGuide.RollCount(tutorial) >= 2` |
| 11 | Card 8: TUTORIAL DONE (8/8) | `tutorial.coreDone` or `guideCompleted` (card 8 buys the second chicken) |
| 12 | After: got the Egg Vacuum | Upgrades tree `EggVacuum` tier ≥ 1 (the first tip) |
| 13 | After: Rebirth 0 done | `session.introRebirth == "done"` (350 Coins) |
| 14 | After: won Cluck Camp | `firstWins[1]` |
| 15 | After: Rebirth 1 | `session.rebirths >= 1` |

October 25 (Stevin: "make it simpler to understand where players are dropping off
exactly"; reordered before the first publish): one step per tutorial card, labelled with
its card, so a drop between two bars is one card. Steps 01–11 happen in this order by
construction (each card needs the one before). 12–15 usually come in that order but can
come in any order: the ledger counts each the moment it is true, and Roblox is sent a
step only once **every earlier step is truly reached** (a Rebirth 0 before the vacuum
waits for the vacuum). Each dashboard bar therefore means "did this and everything
before"; nothing is filled in. If the guide's card count changes, update the (n/8) labels
(a check in `tests/AnalyticsChecks.luau` fails until they match).

On the Roblox dashboard the old 29-step Tutorial funnel (schemas 11–14) and this one share
the same Onboarding funnel slot by step number. After the publish, read it with a date
range that starts after the publish, or filter custom field 1 (game version).

## Data

Ledger `PetRollAnalytics_v1` (Studio: `_Studio`), per UTC day and game version:

| Key | Meaning |
|---|---|
| `ob.reach.NN` | players reaching step NN |
| `ob.reach.NN\|<platform>` | the same split by platform (Desktop, Mobile, Tablet, Console, VR, Unknown) |
| `ob.t.NN` | histogram (seconds buckets): play seconds from first join to step NN |
| `ob.exit.NN` | a session ended with NN as the player's furthest step (`00` = none); counted only while step 15 is not reached |

Profile `p/<userId>`: `ob[NN]` = play seconds when the step was first reached, `obRbx` =
last step sent to Roblox. Session stage (custom events, Robux and economy splits,
journeys): `Ob:<furthest step id>` before step 15, `Post` after, `Untracked` for everyone
else. Journeys keep every session of a tracked player before step 15 (`stage`, `mx` =
furthest step, `st[NN]` = session second it was reached, trail codes `ob:<StepId>`);
`Report.Journeys({day, onlyOnboarding = true})` returns them.
Roblox Creator Dashboard, Onboarding funnel: the 15 steps as "NN <label>", custom field
1 = game version, field 2 = platform.

## Reading it: where players leave

From Studio Edit (fresh loader in `AGENT_GUIDE.md` §3):

```lua
return Report.OnboardingText({days = 7, env = "live"})
```

One line per step: `reached`, `%join` (of step 01), `%prev` (of the step before), `exits`
(sessions whose furthest step this was; a player can appear once per session) and `p50s`
(median play seconds to the step, an upper bucket edge). The last line, also `flags`
(area `onboarding`, 20+ joined), names the adjacent pair that lost the most players and
how many sessions ended there. That line is the answer to "where are players leaving".

Rules of thumb: do not judge a step on fewer than ~30 players at the step before it; late
steps of a young range are still converting, so compare ranges of equal length or split
by `version`; `%prev` above 100 is possible (a sale with one or two eggs reaches 07 before
06) and means nothing is wrong. Then read 10–20 journeys of players whose `mx` is the
step before the drop.

## Steps where leaving matters

**05 Egg1 / 06 Eggs3.** Card 3 "Tap your eggs to collect them! (n/3)": every ready egg
wears a click badge, the nearest lit egg keeps the hand and gold highlight, the camera
turns to it once if it is off screen, and eggs lay every second during the tutorial. A drop
04→05 means the player never clicked an egg (badge or hand not seen, egg off screen); a
drop 05→06 means one click, then nothing. `ob.t.05` is how long the first click took;
compare `ob.reach.05|Mobile` with `|Desktop`, and `guide.dwell.Collect` for the lesson's
own time.

**08 StartClaimed.** Card 5 "Open Upgrades!" → "Claim Start!": the first menu of the game.
While Start is claimable the tree shows only the Start hex, a red "!" badge and "Claim" in
green. A drop 07→08 means the Upgrades button or the hex was not found (the player had the
Coins: Start is free). Read with `ui.menu.open.Upgrades` and the platform split; this is the
clearest UI-comprehension step.

**10 RolledAgain / 11 TutorialDone.** Card 7 "Roll another chicken!" and card 8, buying
that chicken (the arrow goes to the eggs and the pad while the Coins are short).
`ob.reach.11 / ob.reach.01` is the tutorial completion rate, the headline number. A drop
09→10 means the player did not walk back to the lever after the plot grew; a drop 10→11
means the earning loop for the second chicken lost them.

**13 Rebirth0.** The Rebirth tip once Coins reach 350, about two minutes in by the
simulation: +30 Gems and x1.5 Coins. Exits at 11–12 are players who finished the tutorial
and left before the first reset paid off. `ob.t.13` against `ob.t.11` is how long the 350
Coins take; if it stretches, the egg income or the tip timing is the lever.

The other steps are context: 01→02 is loading (read `data.loadFail`, `load.serverSeconds`);
03/04 should hold nearly everyone (the lever is the first card, the chicken is free; in
the schema 14 build 04 lost 12% because the lever's prompt hid the chicken's, fixed
October 25 in `RollStation`); 07 is the first payoff; 12 is the first tip; 14 shows whether
the Army loop is found (the Attack tip waits for three chickens); 15 is the long-term marker.

## Rules

Analytics names are append-only: new steps go at the end with a `Schema.Version` bump;
never rename or reorder these 15 once published, never bring back the dropped keys under
the `ob.` prefix without a new name. Analytics never changes gameplay.
