# Tutorial fixes from the first live data (October 27, 2026)

Stevin: "suggest real changes in steps you will make to combat these issues then review
and see if these changes are actually good then ... make that plan right after".

Source: live build `1.25.0-eight-cards`, Oct 26–27 UTC, 1,220 tracked new players
(Onboarding funnel, `ob.*`), ~90 sampled journeys, plus a Studio playtest of a fresh
profile. Status (later October 27): A–D built in `1.26.0-first-minute`, not published.
Stevin kept Daily Rewards at completion, so E is not built. The lever reach is 13 studs
(the plan said 12) to leave room around the 11-stud spawn.

## What the data says

| Leak | Lost | What the journeys and playtest show |
|---|---|---|
| Loaded, never pulled (card 1) | 10.5% (140) | Most leave 2–10 s in, many before the client finished loading (platform "Unknown"). In the playtest the lever, a 2-stud handle 11 studs ahead, sits exactly behind the avatar at spawn, and its prompt only reaches 8 studs, so the first screen shows no lever and no "Pull lever" button. |
| Pulled, never took the chicken (card 2) | 5.8% (63) | 20 of 25 sampled left 1–10 s after the pull, during or just after the 4-second reveal. The card hides on purpose while the "Take Chicken" prompt shows. |
| Pulled again, never bought (card 7→8) | 12% (103) | Many sat in Upgrades after Flock Size I with 100–400 Coins; the tree hides the card and nothing pointed out of it. |
| Finished, no Vacuum (after card 8) | 14.6% (103) | 20 of 25 sampled left 5–20 s after finishing, right after the Daily popup (claim, open Daily, quit). At completion the card ends, every HUD piece appears at once, the Daily popup opens, and the next goal (the Vacuum tip) waits for 12 more hand eggs, about a minute later. |
| Cards 3–6 (eggs, sell, Start, expand) | 1.5–5.7% each | No clear cause; leave alone. |

Load time: 60% of players have control within 5 s, 16% wait more than 10 s.

## Changes, each reviewed

**A. Ring the Upgrades exit on a world card (built).** While a core card points at the
world and the tree is open, the screen dims and rings the tree's Exit.
Review: KEEP. It directly answers the biggest single leak, it is client-only, and a
playtest showed the ring, then card 7 back on screen after closing.

**B. Show the lever at spawn.** (1) `WorldService:SpawnFrame` faces the midpoint between
the lever and the first podium instead of the yard centre, so the lever stands left of the
avatar and the podium right of it (about 11° each side; the avatar covers about ±5°).
(2) Until the first pull of the tutorial, the lever prompt reaches 12 studs (now 8), so
"Pull lever" shows the moment the player spawns, like the held chicken's prompt does.
Review: KEEP, expect a modest gain. The hidden lever is confirmed, but most card-1
quitters leave within 10 s and many are still loading, which this cannot fix. It should
still cut the time to the first pull (median ~15 s) and make the first action one press.
Risk: the October 23 "face the yard" rule was for the egg card, which now has its own
camera turn (`TurnToEgg`); the new heading is ~10° off the yard, so the yard stays in view.

**C. A short first reveal.** The free first chicken (always the basic Chicken) reveals in
1.5 s instead of 4 s (`RollService:Roll` sets the duration; the client already reads the
station's `RollDuration`). Later pulls keep 4 s.
Review: KEEP. The first reveal has no suspense (the result is fixed) and it sits exactly
where card-2 quitters leave. Rejected alternative: taking the free chicken automatically;
it removes a card but players would never learn to take from the podium, which card 8
needs.

**D. A goal on screen the moment the tutorial ends.** The Vacuum tip chain starts at
completion with a counting card, "Collect 12 more eggs for an Egg Vacuum! (0/12)", then
"Claim your Egg Vacuum!" as today. Keeps Stevin's 12 eggs (October 26); only the
waiting becomes a visible goal.
Review: KEEP. Today there is a minute with no card right after the busiest screen of the
game, and that is where most finishers leave.

**E. Daily Rewards after the Vacuum, not at completion.** Day 1 pops once the Vacuum tip
chain is done (or 3 minutes after completion, whichever is first) instead of right at
completion.
Review: RECOMMENDED, NEEDS STEVIN'S OK. It reverses his October 21 reference-parity choice
("Day 1 pops right after the short core"). The evidence is strong but correlational:
every finisher sees the popup at that moment, so some of these players would have left
anyway. D alone may be enough; ship D first and E only if the post-tutorial leak stays
above ~10%.

**Not changing:** egg, sell, Start and expand cards; the 20-Coin second chicken (live,
working); the camera reveal on later pulls; Cluck Camp and Rebirth 0 timing.

## Implementation plan

1. **B: spawn and lever reach.** `src/server/WorldService.luau` (`SpawnFrame`: look at
   the RollStation's `LeverBase`/`Podium` midpoint, yard fallback unchanged) and
   `src/server/RollStation.luau` (`Sync` saves "tutorial, no roll yet"; `Step` uses reach
   12 for the lever then, 8 after). Check: fresh-profile playtest, screenshot at spawn shows
   the lever beside the avatar and the "Pull lever" prompt is enabled at 11 studs.
2. **C: short first reveal.** `src/shared/Config.luau` (`StarterRevealSeconds = 1.5`) and
   `src/server/RollService.luau` (`duration` uses it when `starter`). Check: the first pull
   lands in ~1.5 s, the second pull still takes 4 s, roll camera and sounds finish cleanly.
3. **D: vacuum progress card.** `src/shared/TutorialGuide.luau` (a `Count` card first in
   `VACUUM_CARDS`, shown from completion until `VacuumTipEggs` more eggs, with the count;
   the chain's `when` starts at completion) and `src/client/CommanderGuide.luau` only if
   the count needs live text. Update `tests/CommanderGuideChecks.luau` (the vacuum tip
   now shows at once, with "(0/12)"). Check: headless suite, then a playtest through
   completion.
4. **E (after Stevin's OK):** `src/server/DailyService.luau` (`TutorialDone` also waits
   for the vacuum chain or 3 minutes after completion). Check: the Daily popup does not
   open at completion; it opens after the vacuum sale.
5. **Version and docs.** `Config.Version = "1.26.0-first-minute"` so the ledger splits
   the build; note the changes in `docs/team/COMMANDER_TUTORIAL.md` and AGENTS.md's
   tutorial bullet (lever reach, short first reveal, vacuum progress card).
6. **Measure after publish** (a few hundred players): compare with this page's table:
   `ob.exit.02` (card 1), `ob.exit.03` (card 2), step 10→11 (A), 11→12 and `ob.exit.11`
   (D/E), and `ob.t.03` (time to first pull, now ~15 s median).

Not committed or published; Stevin publishes.
