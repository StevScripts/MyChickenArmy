# Tutorial funnel (analytics schema 11)

Owner request (later October 21, 2026, Stevin): "Add a complete rework of the funnels to the
tutorial. Be VERY detailed in the funnel descriptions." This is that funnel: one ordered,
31-step record of a brand-new player going from joining the game to their first Rebirth,
with every action of the Drop a Fruit–style guide (`docs/team/COMMANDER_TUTORIAL.md`)
as its own step.

Source of truth: `Schema.TutorialFunnel` in `src/server/AnalyticsSchema.luau` (this page is
generated from it; if they disagree, the schema wins). Tracking: `src/server/AnalyticsTutorial.luau`,
a part of `Analytics`. Checks: `tests/AnalyticsChecks.luau` (three "Tutorial funnel" checks).

## What changed from the earlier funnels

| Before | Now |
|---|---|
| Roblox **Onboarding** dashboard: 20 steps of the *old* guide (Grow, Expand, Select…), most of which no longer happen in that order. | Roblox **Onboarding** dashboard carries this 31-step Tutorial funnel. The old 20 steps keep filling the ledger only (`onb.*`), so earlier days stay comparable. |
| A separate recurring Roblox funnel "Tutorial" (schema 9/10, 14 coarse steps, ledger `tut.*`). | Removed. Its job is done here in far more detail. Roblox now has 10 funnel slots used (Onboarding + 9). |
| Only lesson completions were counted. | Every click the guide asks for is a step: each egg, opening each menu, the Tools tab, equipping the vacuum, opening My Army, plus the payoff screens and the first Daily reward. |
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
| `tf.exit.NN` | a session ended before Cluck Camp with NN as the furthest step |
| `tf.exitLesson.<id>` | the guide lesson on screen when that session ended (`TutorialGuide` step id) |
| `tf.skipGuide.NN` | the player hid the guide in Settings with NN as the furthest step |
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


### Arrival (before the guide)


#### 01 Joined the game  
`Joined` · hard

- **On screen:** Loading screen; the player's yard is assigned.
- **Counts when:** PlayerAdded on a server (Analytics:Join).
- **What it tells you:** Every tracked fresh player starts here. 100% by definition; all other rates are read against it.


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

- **On screen:** Loading veil gone, character standing in the yard, guide card about to show.
- **Counts when:** Client TutorialSignal Ready (CommanderGuide, once the character exists and nothing blocks the screen).
- **What it tells you:** The real start of play. Join-to-here time (tf.t) is the loading cost; a big drop from IntroDone means the client failed to finish loading.


### Core: "TUTORIAL • n/5"


#### 05 1st egg clicked (1/3)  
`Egg1` · hard

- **On screen:** TUTORIAL 1/5 'Click your eggs to collect them! (0/3)': one egg glows gold and a white hand taps it.
- **Counts when:** tutorial.collectedEggCount >= 1 (EggService pays a clicked egg).
- **What it tells you:** Did the player understand the very first instruction? A drop from Control means they never clicked an egg: the glowing egg or hand is not obvious, or the egg is off screen. tf.d.05 is how long the first click took.


#### 06 2nd egg clicked (2/3)  
`Egg2` · hard

- **On screen:** Same lesson, counter 1/3; the glow moves to the next nearest egg.
- **Counts when:** tutorial.collectedEggCount >= 2.
- **What it tells you:** Repeating the action. Almost everyone who clicks one egg should click a second; a drop means the glow did not move clearly or no egg was ready (laying is 3 s per chicken).


#### 07 3rd egg clicked (lesson 1 done)  
`Egg3` · hard

- **On screen:** Counter reaches 3/3; the green check pops and the card moves on.
- **Counts when:** tutorial.collectedEggCount >= TutorialGuide.EggGoal (3).
- **What it tells you:** TUTORIAL 1/5 complete. Time from Control to here (tf.d.05 + .06 + .07) is how long collecting takes.


#### 08 Sold eggs on the pad (2/5)  
`Sold` · hard

- **On screen:** TUTORIAL 2/5 'Sell your eggs on the green pad!' with the ground beam to the pad; coins fly to the player.
- **Counts when:** tutorial.soldEggs (first pad deposit).
- **What it tells you:** The first payoff: Coins go up. A drop means the beam or pad is hard to find; dwell (tf.d.08) is the walk to the pad.


#### 09 Opened Upgrades (Flock)  
`UpgradesOpen` · soft

- **On screen:** TUTORIAL 3/5 'Spend your Coins in Upgrades!': screen darkened, gold ring and arrow on the Upgrades button.
- **Counts when:** TutorialSignal TreeOpen while Flock Size I is not bought yet.
- **What it tells you:** Does the dark screen plus ring get the first menu open? A drop from Sold to here is the clearest UI-comprehension failure in the guide.


#### 10 Bought Flock Size I (3/5)  
`FlockBought` · hard

- **On screen:** Inside Upgrades: 'Buy Flock Size I!' with the hex ringed (300 Coins).
- **Counts when:** Flock Size >= 4 (TutorialGuide.Facts Flock).
- **What it tells you:** First purchase. A drop between UpgradesOpen and here means the tree confused them (closed it, clicked other hexes). Read with ui.TreeClose and feature.first.Upgrades.


#### 11 Pulled the lever (4/5)  
`LeverPulled` · hard

- **On screen:** TUTORIAL 4/5 'Pull the lever for a chicken!' with the beam to the lever.
- **Counts when:** tutorial.rolled (RollService:Roll).
- **What it tells you:** Getting the player out of the menu and to the roll machine. A drop here often means they stayed in Upgrades or could not find the lever prompt.


#### 12 Took the chicken (5/5)  
`ChickenTaken` · hard

- **On screen:** TUTORIAL 5/5 'Grab your chicken!': the rolled Duck on the podium costs 0 Coins.
- **Counts when:** tutorial.bought (first recruit).
- **What it tells you:** Last core action. Should be close to 100% of LeverPulled; a drop means the reveal hid the podium prompt.


#### 13 TUTORIAL COMPLETE shown  
`CoreDone` · hard

- **On screen:** 'TUTORIAL COMPLETE! Your Flock is laying!' with confetti for 4 s; My Army appears.
- **Counts when:** tutorial.coreDone saved (TutorialService, all core facts true).
- **What it tells you:** The short core is finished. The share of Joined reaching this is the headline completion rate of the tutorial; tf.t.13 is how long the whole core took (target under a minute after Control).


### Between core and tips


#### 14 Daily Rewards Day 1  
`DailyDay1` · soft

- **On screen:** Daily Rewards popup opens with Day 1 claimed (Coins).
- **Counts when:** session.daily.lastDay > 0 (DailyService grants within 10 s of CoreDone).
- **What it tells you:** The return hook. Soft because a server can lag; passed over (tf.skip.14) if the player moves on first. Compare later with D1 retention per cohort.


### Tips: "TIP • n/7" — Egg Vacuum


#### 15 Opened Upgrades (vacuum tip)  
`VacUpgradesOpen` · soft

- **On screen:** TIP 1/7 'Open Upgrades for an Egg Vacuum!' with the dark screen and ring on Upgrades.
- **Counts when:** TutorialSignal TreeOpen after CoreDone while the Egg Vacuum is not owned.
- **What it tells you:** Do players keep following after the core payoff? A big drop from CoreDone means the tips feel optional or the Daily popup broke the flow.


#### 16 Opened the Tools category  
`ToolsOpen` · soft

- **On screen:** Inside Upgrades: 'Open the Tools category!' with the ring on the Tools hex.
- **Counts when:** TutorialSignal ToolsOpen (the Upgrades map switched to Tools) while the Egg Vacuum is not owned.
- **What it tells you:** The second level of menu navigation. A drop between VacUpgradesOpen and here means the Open hexes are not recognised as buttons.


#### 17 Claimed the Egg Vacuum (1/7)  
`VacuumClaimed` · hard

- **On screen:** 'Claim your Egg Vacuum!' on the ringed Egg Vacuum hex (0 Coins during the guide).
- **Counts when:** The Egg Vacuum is owned (state.tools.eggVacuum) or was used (tutorial.vacuumUsed).
- **What it tells you:** TIP 1/7 done.


#### 18 Equipped the vacuum  
`VacuumEquipped` · soft

- **On screen:** 'Equip your Egg Vacuum!' with the hotbar slot darkened and ringed.
- **Counts when:** TutorialSignal VacuumEquip (the vacuum tool is in the character) before 20 eggs are vacuumed.
- **What it tells you:** Roblox's hotbar is unfamiliar to many new players. A drop here means they never pressed the slot (or the number key).


#### 19 Vacuumed 10 eggs  
`Vacuum10` · hard

- **On screen:** 'Walk near eggs to vacuum them up! (10/20)'.
- **Counts when:** tutorial.vacuumEggCount >= 10.
- **What it tells you:** Halfway. The vacuum only works while held and near eggs; a drop between Equipped and here means they put it away or stood still.


#### 20 Vacuumed 20 eggs (2/7)  
`Vacuum20` · hard

- **On screen:** Counter reaches 20/20.
- **Counts when:** tutorial.vacuumEggCount >= TutorialGuide.VacuumGoal (20).
- **What it tells you:** TIP 2/7 done. tf.d.19 + tf.d.20 is how long filling takes (about 15 s with four chickens if eggs were waiting).


#### 21 Sold the vacuum eggs (3/7)  
`VacuumSold` · hard

- **On screen:** TIP 3/7 'Sell your vacuumed eggs on the green pad!', then 'TIP • COMPLETE! Egg Vacuum learned!'.
- **Counts when:** tutorial.vacuumSold (a pad sale carrying vacuum eggs once the 20 were in).
- **What it tells you:** The vacuum loop closes. A drop means they kept collecting instead of selling; check whether the vacuum filled up (the guide then says 'Vacuum full!').


### Tips: "TIP • n/7" — Army and Cluck Camp


#### 22 Opened Upgrades (Army tip)  
`ArmyUpgradesOpen` · soft

- **On screen:** TIP 4/7 'Open Upgrades for more Army slots!' with the ring on Upgrades.
- **Counts when:** TutorialSignal TreeOpen after VacuumSold while Army Size I is not bought.
- **What it tells you:** Third trip into Upgrades; should be quick by now. A drop means the battle half of the tips is losing players.


#### 23 Bought Army Size I (4/7)  
`ArmySizeBought` · hard

- **On screen:** 'Buy Army Size I!' on the ringed hex (1,200 Coins, held in reserve since the start).
- **Counts when:** Army capacity >= 4.
- **What it tells you:** TIP 4/7 done.


#### 24 Opened My Army  
`MyArmyOpen` · soft

- **On screen:** TIP 5/7 'Open My Army!' with the ring on the My Army button.
- **Counts when:** TutorialSignal ArmyOpen after Army Size I while fewer than four chickens are picked.
- **What it tells you:** Often passed over: the automatic Army fills the new slot by itself, so Select can be true right after Army Size I.


#### 25 Four chickens in the Army (5/7)  
`ArmyPicked` · hard

- **On screen:** 'Press Equip Best!' inside My Army.
- **Counts when:** Four or more chickens selected for the Army.
- **What it tells you:** TIP 5/7 done.


#### 26 Sent the Army to Cluck Camp (6/7)  
`ArmySent` · hard

- **On screen:** TIP 6/7 'Send your Army to Cluck Camp!' with the beam to the camp's command prompt.
- **Counts when:** tutorial.guideDeployed (an Attack on a main-route camp).
- **What it tells you:** The first fight starts. A drop here means the camp prompt is hard to find or the player is afraid to lose chickens.


#### 27 Captured Cluck Camp (7/7)  
`CluckCampWon` · hard

- **On screen:** The battle, then 'Cluck Camp captured!' and GUIDE COMPLETE.
- **Counts when:** First camp win (firstWins, campsWon or tutorial.wonCamp).
- **What it tells you:** The whole guide is done. ArmySent minus this is lost fights or quits during the battle.


### After the guide (no card, quiet Next goals)


#### 28 Won Fort Roost  
`FortRoostWon` · hard

- **On screen:** No guide card; quiet Next goals point at Fort Roost and name the power gap.
- **Counts when:** firstWins[2].
- **What it tells you:** The October 20 funnel review found next-day return is about 20% for players who win Fort Roost on day 1 and 2% for those who don't. The most important post-guide step; read by cohort.


#### 29 Won Ironbeak HQ  
`IronbeakWon` · hard

- **On screen:** Next goals.
- **Counts when:** firstWins[3].
- **What it tells you:** Mid-route progress, usually a later session (tf.s1 is low here).


#### 30 Beat the Chicken King  
`KingCleared` · hard

- **On screen:** Next goals.
- **Counts when:** session.kingCleared.
- **What it tells you:** End of the main route.


#### 31 First Rebirth  
`Rebirth1` · hard

- **On screen:** Rebirth screen.
- **Counts when:** session.rebirths >= 1.
- **What it tells you:** Long-term retention marker: the player understood the reset loop.


## Reading the funnel

1. **Headline completion:** `CoreDone` (13) as a share of `Joined` (01) is the tutorial's
   completion rate; `CluckCampWon` (27) is the whole guide's.
2. **Where people leave:** the largest drop in `ofPrevious`, then `tf.exit.NN` and
   `tutorialExitLessons` for the exact lesson on screen. Compare `dwell` there with its
   neighbours: a long dwell before a drop means confusion, a short one means quitting.
3. **Menu comprehension:** the soft steps 09, 15, 16, 18, 22 and 24. A low reach with a
   high `passedOver` is fine (players were ahead of the guide). A low reach with a high
   `exitsHere` means the dark screen and ring did not get the menu opened.
4. **Devices:** compare `tf.reach.NN|Phone` with `|PC` at each step; phones usually lose
   players at menu steps first.
5. **Retention link:** join cohorts (`x[day] tf.NN`) with `ret.d1`: the October 20 review found
   players who win Fort Roost (28) on day 1 return about 10× as often.

## Rules

Analytics names are append-only: new steps go at the end with a schema version bump; never
rename or reorder these 31. Analytics never changes gameplay.
