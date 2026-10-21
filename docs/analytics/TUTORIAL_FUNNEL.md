# Tutorial funnel (analytics schema 11)

Owner request (later October 21, 2026, Stevin): "Add a complete rework of the funnels to the
tutorial. Be VERY detailed in the funnel descriptions." This is that funnel: one ordered,
24-step record of a brand-new player going from joining the game to their first Rebirth,
with every action of the Drop a Fruit–style guide (`docs/team/COMMANDER_TUTORIAL.md`)
as its own step. Latest October 21 (Stevin: "keep the tutorial as SHORT as possible"): the
tutorial is seven lessons — click eggs, sell, roll, take the chicken, claim the Egg Vacuum,
vacuum 20 eggs, sell them — and completes there. Nothing instructs the player after it (no Next goals).

Source of truth: `Schema.TutorialFunnel` in `src/server/AnalyticsSchema.luau` (this page is
generated from it; if they disagree, the schema wins). Tracking: `src/server/AnalyticsTutorial.luau`,
a part of `Analytics`. Checks: `tests/AnalyticsChecks.luau` (three "Tutorial funnel" checks).

## What changed from the earlier funnels

| Before | Now |
|---|---|
| Roblox **Onboarding** dashboard: 20 steps of the *old* guide (Grow, Expand, Select…), most of which no longer happen in that order. | Roblox **Onboarding** dashboard carries this 24-step Tutorial funnel. Since schema 12 the old 20 steps (`onb.*`) are not recorded at all; this is the only onboarding funnel, and it also sets the session stage (`Tut:<step id>` / `Post`) used by custom events and journeys. |
| A separate recurring Roblox funnel "Tutorial" (schema 9/10, 14 coarse steps, ledger `tut.*`). | Removed. Its job is done here in far more detail. Roblox now has 9 funnel slots used (Onboarding + 8; schema 12 swapped the dead Research dashboard for Upgrades). |
| Only lesson completions were counted. | Every click the tutorial asks for is a step: each egg, opening Upgrades, the Tools tab, equipping the vacuum, 10 and 20 vacuumed eggs, plus the completion screen and the first Daily reward. |
| One time per step (seconds since join). | Time since join **and** dwell since the previous step, first-session share, per-platform reaches, out-of-order reaches, steps passed over and where unfinished sessions stopped (step and on-screen lesson). |

## Who is counted

A player enters this funnel only if their save is **fresh** the first time this version
sees them (starter army, guide never started, no rolls, buys or camp wins —
`Analytics.FreshSave`). Their analytics profile then carries `profile.tf`, so the funnel
continues across sessions and servers. Older players are never counted, so rates are not
diluted by veterans.

Each step counts **once per player, ever** (never again in a later session).

## Step kinds

- **hard**: a saved fact from the save or the server snapshot (egg count, purchase, sale,
  win). Recorded the moment it is true, even if earlier steps are missing; the earlier gap
  is then counted as `tf.gap.NN` on the later step.
- **soft**: something the client reports while that lesson is on screen (a menu opened, a
  tab switched, a tool equipped), or a server reward that can lag (Daily Rewards). If a later
  step of the funnel happens first, the soft step is **passed over** (`tf.skip.NN`) rather
  than invented. Passed-over steps are *not* drop-offs: the player did the thing before the
  guide asked, or the report was lost. Read a soft step as "followed this exact instruction".

## Data recorded

Ledger (`PetRollAnalytics_v1`, per day and game version; Studio writes the `_Studio` twin):

| Key | Meaning |
|---|---|
| `tf.reach.NN` | players reaching step NN |
| `tf.reach.NN\|<platform>` | the same, split by platform (Phone, Tablet, PC, Console…) |
| `tf.t.NN` | histogram of total play seconds from first join to step NN |
| `tf.d.NN` | histogram of seconds since the previous reached step (dwell: how long *this* step took) |
| `tf.s1.NN` | reached during the player's first session |
| `tf.gap.NN` | reached while the step before it was still missing (out of order) |
| `tf.skip.NN` | soft step passed over |
| `tf.exit.NN` | a session ended before the tutorial completed (step 18) with NN as the furthest step (`00` = none); the Roblox custom event `TutorialExit` (schema 12) carries the same step, the lesson and S1/S2/S3+ |
| `tf.exitLesson.<id>` | the guide lesson on screen when that session ended (`TutorialGuide` step id) |
| `tf.robloxGapFill.NN` | a missing hard step Roblox was told to pass (see below) |
| cohort `x[firstDay] tf.NN` | players whose first day was `firstDay` who ever reached NN |

Roblox: `LogOnboardingFunnelStepEvent(player, NN, "NN <label>", {game version, platform})`.
Roblox fills earlier steps itself when a later one arrives, so steps go out **strictly in
order**: soft steps that were passed over are skipped; a missing hard step is released once
`Schema.RobloxGapRelease` (3) later steps have happened. The ledger always records what
really happened; Roblox's dashboard is the quick view.

Read it: `AnalyticsReport.Summary({days = 7}).tutorialFunnel` in Studio Edit (each row has
`reached`, `ofJoined`, `ofPrevious`, `timeToStep`, `dwell`, `firstSession`, `outOfOrder`,
`passedOver`, `exitsHere` and the descriptions below), `tutorialExitLessons`, and
`tools/analytics/pull_ledger.py` (`tutorialFunnel`). See `docs/analytics/AGENT_GUIDE.md`.

## The steps


### Arrival (before the tutorial)


#### 01 Joined the game  
`Joined` · hard

- **On screen:** Loading screen; the player's yard is assigned.
- **Counts when:** PlayerAdded on a server (Analytics:Join).
- **What it tells you:** Every tracked fresh player starts here. 100% by definition; every other rate is read against it.


#### 02 Save loaded  
`Loaded` · hard

- **On screen:** Still loading; the starter save (3 Ducks, 2,400 Coins) is ready.
- **Counts when:** DataService loaded the profile and Analytics resolved the ledger profile (Analytics:Loaded).
- **What it tells you:** A drop from Joined is players leaving or failing before their save loads: DataStore errors, slow devices or instant quits. Compare with data.loadFail and load.serverSeconds.


#### 03 Intro film done  
`IntroDone` · hard

- **On screen:** The first-visit film plays (or not, with reduced motion), then the yard.
- **Counts when:** Client TutorialSignal IntroFinished or IntroSkipped (also sent when no film plays).
- **What it tells you:** A drop here is quitting during the film. Read with intro.skipped vs intro.finished: many skips mean the film is too long.


#### 04 Player has control  
`Control` · hard

- **On screen:** Loading veil gone, character standing in the yard, the guide card about to show.
- **Counts when:** Client TutorialSignal Ready (CommanderGuide, once the character exists and nothing blocks the screen).
- **What it tells you:** The real start of play. Join-to-here time (tf.t) is the loading cost; a big drop from IntroDone means the client failed to finish loading.


### The tutorial: "TUTORIAL • n/7"


#### 05 1st egg clicked  
`Egg1` · hard

- **On screen:** TUTORIAL 1/7 'Click your eggs to collect them! (0/3)': one egg glows gold and a white hand taps it.
- **Counts when:** tutorial.collectedEggCount >= 1 (EggService pays a clicked egg).
- **What it tells you:** Did the player understand the very first instruction? A drop from Control means they never clicked an egg: the glowing egg or hand is not obvious, or the egg is off screen. tf.d.05 is how long the first click took.


#### 06 2nd egg clicked  
`Egg2` · hard

- **On screen:** Same lesson, counter 1/3; the glow moves to the next nearest egg.
- **Counts when:** tutorial.collectedEggCount >= 2.
- **What it tells you:** Repeating the action. Almost everyone who clicks one egg should click a second; a drop means the glow did not move clearly or no egg was ready (each chicken lays every 3 s).


#### 07 3rd egg clicked (1/7)  
`Egg3` · hard

- **On screen:** Counter reaches 3/3; the green check pops and the card moves on.
- **Counts when:** tutorial.collectedEggCount >= TutorialGuide.EggGoal (3).
- **What it tells you:** Lesson 1 of 7 done: collecting. Time from Control to here (tf.d.05 + .06 + .07) is how long collecting takes.


#### 08 Sold eggs on the pad (2/7)  
`Sold` · hard

- **On screen:** TUTORIAL 2/7 'Sell your eggs on the green pad!' with the ground beam to the pad; coins fly to the player.
- **Counts when:** tutorial.soldEggs (first pad deposit).
- **What it tells you:** Lesson 2: the first payoff, Coins go up. A drop means the beam or pad is hard to find; dwell (tf.d.08) is the walk to the pad.


#### 09 Pulled the lever (3/7)  
`LeverPulled` · hard

- **On screen:** TUTORIAL 3/7 'Pull the lever for a chicken!' with the beam to the lever; its prompt reads 'Pull lever'.
- **Counts when:** tutorial.rolled (RollService:Roll).
- **What it tells you:** Lesson 3: rolling, the game's main hook. A drop means the lever or its prompt is hard to find, or the roll animation confused them.


#### 10 Took the chicken (4/7)  
`ChickenTaken` · hard

- **On screen:** TUTORIAL 4/7 'Grab your chicken!': the rolled Duck stands on the podium; it costs 0 Coins.
- **Counts when:** tutorial.bought (first recruit).
- **What it tells you:** Lesson 4. Should be close to 100% of LeverPulled; a drop means the reveal hid the podium prompt or they walked away mid-reveal.


#### 11 Opened Upgrades (vacuum)  
`UpgradesOpen` · soft

- **On screen:** TUTORIAL 5/7 'Open Upgrades for an Egg Vacuum!': screen darkened, gold ring and arrow on the Upgrades button.
- **Counts when:** TutorialSignal TreeOpen after the chicken is taken while the Egg Vacuum is not owned.
- **What it tells you:** The first menu of the game. Does the dark screen plus ring get it opened? A drop from ChickenTaken to here is the clearest UI-comprehension failure in the tutorial.


#### 12 Opened the Tools category  
`ToolsOpen` · soft

- **On screen:** Inside Upgrades: 'Open the Tools category!' with the ring on the Tools hex.
- **Counts when:** TutorialSignal ToolsOpen (the Upgrades map switched to Tools) while the Egg Vacuum is not owned.
- **What it tells you:** Second level of menu navigation. A drop between UpgradesOpen and here means the Open hexes are not recognised as buttons.


#### 13 Claimed the Egg Vacuum (5/7)  
`VacuumClaimed` · hard

- **On screen:** 'Claim your Egg Vacuum!' on the ringed Egg Vacuum hex (0 Coins during the tutorial).
- **Counts when:** The Egg Vacuum is owned (state.tools.eggVacuum) or was used (tutorial.vacuumUsed), after the chicken is taken.
- **What it tells you:** Lesson 5: the Upgrades menu and the first tool.


#### 14 Equipped the vacuum  
`VacuumEquipped` · soft

- **On screen:** TUTORIAL 6/7 'Equip your Egg Vacuum!' with the hotbar slot darkened and ringed.
- **Counts when:** TutorialSignal VacuumEquip (the vacuum tool is in the character) before 20 eggs are vacuumed.
- **What it tells you:** Roblox's hotbar is unfamiliar to many new players. A drop here means they never pressed the slot (or the number key).


#### 15 Vacuumed 10 eggs  
`Vacuum10` · hard

- **On screen:** 'Walk near eggs to vacuum them up! (10/20)'.
- **Counts when:** tutorial.vacuumEggCount >= 10.
- **What it tells you:** Halfway. The vacuum only works while held and near eggs; a drop between VacuumEquipped and here means they put it away or stood still.


#### 16 Vacuumed 20 eggs (6/7)  
`Vacuum20` · hard

- **On screen:** Counter reaches 20/20.
- **Counts when:** tutorial.vacuumEggCount >= TutorialGuide.VacuumGoal (20).
- **What it tells you:** Lesson 6. tf.d.15 + tf.d.16 is how long filling takes (seconds when eggs are waiting; up to about 15 s with four chickens laying).


#### 17 Sold the vacuum eggs (7/7)  
`VacuumSold` · hard

- **On screen:** TUTORIAL 7/7 'Sell your vacuumed eggs on the green pad!' with the beam to the pad.
- **Counts when:** tutorial.vacuumSold (a pad sale carrying vacuum eggs once the 20 were in).
- **What it tells you:** Lesson 7, the last one: the vacuum loop closes. A drop means they kept collecting instead of selling; if the vacuum filled first the card says 'Vacuum full!'.


#### 18 TUTORIAL COMPLETE shown  
`TutorialComplete` · hard

- **On screen:** 'TUTORIAL COMPLETE! Keep collecting eggs and rolling chickens!' with confetti for 4 s; the My Army button appears.
- **Counts when:** tutorial.guideCompleted (TutorialService: all seven lessons done, or a camp win).
- **What it tells you:** The headline number: this share of Joined finished the tutorial. tf.t.18 minus tf.t.04 is how long the tutorial took after the player got control (target: about a minute).


### Right after


#### 19 Daily Rewards Day 1  
`DailyDay1` · soft

- **On screen:** Daily Rewards popup opens with Day 1 claimed (Coins).
- **Counts when:** session.daily.lastDay > 0 after the tutorial (DailyService grants within 10 s of completion).
- **What it tells you:** The return hook. Soft because a server can lag; passed over (tf.skip.19) if a later step happens first. Compare with D1 retention per cohort.


### After the tutorial (no instructions)


#### 20 Captured Cluck Camp  
`CluckCampWon` · hard

- **On screen:** Nothing on screen guides the player any more; they find Cluck Camp on their own (camp signs show Should win / Close fight / Very tough).
- **Counts when:** First camp win (firstWins, campsWon or tutorial.wonCamp).
- **What it tells you:** First fight, found without any instructions (Stevin removed all post-tutorial guidance). A drop from TutorialComplete is players who never fought or lost; read with the Camp funnel (Deployed, Won). If this is low, fighting needs its own discovery hook.


#### 21 Won Fort Roost  
`FortRoostWon` · hard

- **On screen:** No guidance; the camp sign shows the fight estimate.
- **Counts when:** firstWins[2].
- **What it tells you:** The October 20 funnel review found next-day return is about 20% for players who win Fort Roost on day 1 and 2% for those who don't. The most important post-tutorial step; read by cohort.


#### 22 Won Ironbeak HQ  
`IronbeakWon` · hard

- **On screen:** No guidance.
- **Counts when:** firstWins[3].
- **What it tells you:** Mid-route progress, usually in a later session (tf.s1 is low here).


#### 23 Beat the Chicken King  
`KingCleared` · hard

- **On screen:** No guidance.
- **Counts when:** session.kingCleared.
- **What it tells you:** End of the main route.


#### 24 First Rebirth  
`Rebirth1` · hard

- **On screen:** Rebirth screen.
- **Counts when:** session.rebirths >= 1.
- **What it tells you:** Long-term retention marker: the player understood the reset loop.

## Reading the funnel

1. **Headline completion:** `TutorialComplete` (18) as a share of `Joined` (01) is the tutorial's
   completion rate; `CluckCampWon` (20) shows whether players find the first fight on their own.
2. **Where people leave:** the largest drop in `ofPrevious`, then `tf.exit.NN` and
   `tutorialExitLessons` for the exact lesson on screen. Compare `dwell` there with its
   neighbours: a long dwell before a drop means confusion, a short one means quitting.
3. **Menu comprehension:** the soft steps 11 (Upgrades), 12 (Tools tab) and 14 (equip). A low reach with a
   high `passedOver` is fine (players were ahead of the guide). A low reach with a high
   `exitsHere` means the dark screen and ring did not get the menu opened.
4. **Devices:** compare `tf.reach.NN|Phone` with `|PC` at each step; phones usually lose
   players at menu steps first.
5. **Retention link:** join cohorts (`x[day] tf.NN`) with `ret.d1`: the October 20 review found
   players who win Fort Roost (21) on day 1 return about 10× as often.

## Rules

Analytics names are append-only: new steps go at the end with a schema version bump; never
rename or reorder these 24 once published. Analytics never changes gameplay.
