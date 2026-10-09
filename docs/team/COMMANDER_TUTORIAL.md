# Commander Cluck tutorial — October 3, 2026

Implemented locally and synchronized into Pet Roll Test (place 96683186622050).
Original art was uploaded for this implementation. No experience release was
published, no Git commit/push was made, and no saved player profiles were reset.
Studio playtests used the existing PetRollPlaytestSessionOnly=true setting and
disposable Free profiles. The user's audio, research-tree, texture and VFX work
was preserved.

## Next goal after the guide: October 8

The strip no longer disappears for good. "Cluck Camp captured!" still shows for
eight seconds and sends the Finish signal; after that, and for players who
finished the guide earlier, the same one-line strip shows `Guide.NextGoal(state)`,
derived only from the client snapshot:

- army returning: "Collect eggs while your army returns"; no chickens: "Roll a
  chicken at your podium"; none selected: "My Army → Select Best";
- next unowned main-route camp, then the King: "Attack Fort Roost" or "Challenge
  the Chicken King", or "Roll or upgrade chickens for Fort Roost" when the odds
  band is Very tough (below 1.3x power, see `Guide.Difficulty`);
- after a saved King clear: "Research Operations in Upgrades", then "Win an
  Operation: Upgrades → Operations", then "Research the next Operations tier".

It hides during battles, menus, dialogue and toasts, and when the roll or E
prompt it refers to is on screen. No spotlight, dim or celebration pop. Reduced
motion skips the typewriter and entrance as before. Saved `guideSkipped` players
see no strip (Settings Resume is unchanged), but the world NEXT marker now uses
the same goal for everyone so marker and text agree. Analytics version is
unchanged; conquest funnel events are documented in `CONQUEST_REFERENCE.md`.
Local source only; not playtested.

## Plain buy step and completion pop — October 7 (egg run removed October 9)

- The recruit step reads **"Buy the chicken"** (the podium label and prompt already
  show the price).
- **Completion pop:** whenever a `Guide.Milestones` fact flips to true while the
  guide is active, `Commander:Celebrate` plays on the card: a green check pops
  beside the Commander, sparks burst, the bar flashes green, the card bumps, and the
  `SkillTreeResearchCompleted` chime plays. If the card is hidden at that moment
  (menu open, standing at a prompt) it plays when the card returns. Reduced motion
  keeps the check and flash without the scale and sparks.
- A "Collect 10 eggs" step between Roll and Recruit was added on October 7 and
  removed on October 9 at the user's request ("a bit extra"). Its counter, saved
  `rollEggCount` field and `Harvest` milestone are gone; saves that stored the field
  drop it on load. `Guide.Version` is back to `cluck-5-forty-eggs`.

## Collect 40 eggs and larger one-line instructions — latest October 6 correction

The initial Collect lesson requires 40 server-confirmed egg units and displays
`Collect 40 eggs (n/40)`. Stacked/rarer drops contribute their actual quantity.
Selling early, skipping/resuming or rejoining does not reset progress; the player
does not need to hold all 40 at once. A carried egg alone no longer advances a
new tutorial. Legacy earned collection milestones and completed guides remain
earned. Egg prices, rewards and ordinary gameplay actions are unchanged.

The Commander instruction now occupies most of the strip's usable space beside
the portrait. Native `TextScaled=true` and centered alignment keep the instruction large.
Roblox automatically enables wrapping with TextScaled, so a local
UITextSizeConstraint on the display layers caps the font at the largest measured
one-line fit. It updates only when the text or label size changes. The Skip
button remains absent.

All 27 isolated Studio Edit collection/persistence checks passed against the
final synced scripts, using disposable sessions with no player-data writes.
Nine text-fit cases passed across desktop and phone-sized frames. The four
tutorial scripts matched the canonical repository sources in Studio, and the
main Pet Roll Test place (96683186622050) was saved to Roblox on October 6.
Studio reported “Successfully saved!” and “Saved new changes in Pet Roll Test
to Roblox.” No experience publication or player-data change was performed.

## Eggs first — preceding October 6 correction

The starter-army guide now begins **Collect → Sell → Roll → Recruit**, then
prepares the four-chicken army and directs the player to conquer Cluck Camp.
The three free starter chickens provide eggs before the first purchase. A single
collected egg is enough for the first instant sale. Army Size 1 still brings the
fourth chicken into the deployed squad; Select appears only when the player has
not already selected four fighters.

Saved collection, sale and purchase milestones remain authoritative, so rejoining
or doing actions early does not reset progress. Legacy openings retain their
recruit-first route, and an empty flock always recruits an egg producer before
collection. Starting cash, reserves, prices, selection and combat rules are
unchanged. The analytics version is now `cluck-4-eggs-first`.

The updated shared guide is synchronized to Pet Roll Test and matches the local
source. Twenty-three isolated snapshot-routing checks passed in Studio Edit,
covering the normal route, early actions, resume, recovery and legacy profiles.
The existing starter-army fixture was updated for the new order but its broader
server suite was not rerun. No playtest, publication or player-data changes were
performed for this revision.

## No tutorial highlighting — latest October 6 correction

Tutorial guidance no longer dims the viewport, outlines controls/world targets,
or pulses a focus border. This supersedes every spotlight/cutout requirement
below. `GuideFocus` is now GUI-pointer-only; `CommanderGuide` keeps the existing
Expand/Select arrows and native-prompt handoff. World guidance uses the destination
marker and one attachment-driven Beam with normal scene lighting.

The Beam now uses the generated chunky white arrow with a black contour,
`rbxassetid://78163165437840`, at full opacity. It retains native texture scrolling
and becomes static for reduced motion. GUI pointers and destination markers keep
their existing image. Gameplay, tutorial progression and saved state are unchanged.
Source and art: [tutorial Beam arrow](../../assets/tutorial-beam-arrow-20261006/README.md).
No playtest or experience publication was performed for this change.

## No Skip button — latest October 6 correction

The tutorial has no Skip button. `CommanderGuide` no longer creates the control,
sends its Skip action or reserves space for it; the instruction uses the freed
width. This user correction supersedes historical Skip-button requirements
below. Objectives, automatic completion, existing saved skipped-state
compatibility and Settings Resume remain unchanged.

## Compact guide — October 6

The tutorial card now keeps the approved chicken portrait and one short
instruction. The commander-name header, secondary explanation, tappable Help layer
and timed help expansion are removed. The card is shorter with a transparent
near-black body; its existing entrance/salute tweens and reduced-motion behavior
remain. Example instructions are “Walk over an egg,” “Step on the green sell pad”
and “Upgrades → Army Size 1.” Recovery still shows the egg value needed.

`TutorialGuide` supplies one `text` field per step, also used by the existing HUD
fallback. Step IDs, world targets, completion, saved-state/resume, focus guidance and
all gameplay rules are unchanged. This local presentation edit did not run
tests, start a playtest, initiate synchronization or publish the game.

## Current starter army — October 4 approval, October 5 live observation

Fresh profiles now receive three free level-1 basic Chickens (internal `Duck`
IDs), $2,400, three deployment slots and no offer. The free lever guarantees a
$600 fourth recruit. The latest guide teaches collection and instant selling
first, then the roll and purchase, Army Size 1 for $1,200, four selected fighters
and Cluck Camp conquest. The new cohort does not need the former Grow/funding loop.

`tutorial.starterArmy` identifies this opening; old profiles receive no extra
chickens, cash or changed cohort. Legacy `emptyStart` saves retain their existing
recruit/recovery path. The original guide version was `cluck-3-starter-army`;
the October 6 egg-first route uses `cluck-4-eggs-first`.

PlayerSession reserves the $600 recruit and $1,200 expansion separately. Other
cash spending uses only the remainder. The corresponding server purchase can
consume its own earmark, including if the player expands before recruiting.
Effective paid capacity counts. While the mission is incomplete, sales and
fusion preserve three starter birds before recruiting and four afterward;
skipping the guide does not bypass protection. Completion releases it. Ordinary
roll odds, prices, upgrades and existing saved progress remain unchanged.

Validation: 87 disposable server/shared checks passed on October 4 after exact
source readback of all six changed modules. These cover purchase ordering,
replay, reserves across cash sinks, flock protection, skip/completion, save
round trips and legacy profiles. Egg milestones in that fixture are synthetic.
The implementation was synchronized to the user's approved recovery working
copy; on October 5, connected Pet Roll Test also contained the current sources.

A fresh session-only Free profile's live client reported the route
Roll → Recruit → Collect → Sell → Expand → Deploy → Battle → Complete, followed
by returning home. It had four selected chickens, one $260 sale and $860 after
the $600 recruit/$1,200 expansion, then $1,460 after victory. No Grow or recovery
step occurred. Inputs were not all agent controlled, so this is an observed
live route, not a fully automated replay or a novice usability study.
See [fixture](../../assets/tutorial-starter-army-20261004/check-starter-army.luau)
and [observed completion](../../assets/tutorial-starter-army-20261004/observed-completion-20261005.json).

## Egg recovery trips — preceding October 4 correction

Fixed locally in `shared/TutorialGuide.luau`. The previous recovery rule pointed
at the sell pad whenever the bag had any value, even if that sale could not fund
the recruit or army slot. Emptying that small bag immediately pointed back to
the yard. Recovery now keeps the yard objective until wallet cash plus the
server-quoted bag value covers the actual purchase price. Copy shows the value
still needed; one sufficient sale advances to the purchase. The first-sale
lesson still accepts one egg, and free rerolls remain available. Prices, income,
the four-chicken objective, player actions and saved progress are unchanged.

Seventeen isolated routing checks passed, including 124 successive partial-bag
snapshots, exact/over-target sales, changed offers, other income, first sale and
skip. [Check source](../../assets/tutorial-egg-recovery-20261004/check-recovery.luau)
and [results](../../assets/tutorial-egg-recovery-20261004/validation.json).
This correction remains relevant to legacy profiles and unusual insufficient-
cash states. Its earlier pending sync was completed with the starter-army
revision above; the empty opening described below is historical.

## Selective spotlight — latest October 3 correction

Do not dim every tutorial task. World spotlights are limited to the initial
**Roll** and **Recruit** steps, and only while a relevant native roll-station
prompt is in reach. Walking toward these items uses the white Beam alone.
Collect, Sell, Grow, recovery, return and deployment steps keep normal world
lighting with Beam/marker guidance. Opening an unrelated menu does not add a
spotlight to its Exit button.

GUI spotlights remain for learning Army Size (Expand) and choosing the army
(Select), including the tree Exit handoff between those two steps. The shared
0.5-transparency spotlight rendering and projection support below is unchanged.
This is a targeted presentation policy change; no new playtest sweep was run.

## Projected world spotlight capability — preceding October 3 follow-up

The same single transparent `ClearTarget` frame and enormous outer black
UIStroke at **0.5 transparency** now also surround the tutorial's world items.
`GuideWorldBounds` projects their corners with `Camera:WorldToScreenPoint`,
then `GuideFocus` converts them into its native GUI coordinate space. The real
lever includes base, arm and handle; a recruit includes its podium and revealed
chicken; eggs use their visible, moving billboard bounds. Other world parts and
models use their native geometry/bounding box.

One render listener tracks the active world target and camera. This is projection
tracking, not a replacement animation loop. The existing outline pulse and fades
still use TweenService; reduced motion keeps those static. The white Beam and
native destination marker retain world direction, without another GUI arrow.

Off-screen, behind-camera and near-plane-crossing targets clear the mask;
returning targets restore it. Destroyed targets and world/menu/skip handoffs
release tracking. The overlay never captures input. This user request supersedes
the earlier instruction to keep walking steps undimmed.

Seventeen world projection/lifecycle cases passed on desktop and iPhone 13
landscape emulation; all 19 existing GUI spotlight cases passed on desktop.
The actual roll lever was visually inspected in both views. No performance or
physical-phone claim is made. [Source, results and API references](../../assets/tutorial-world-focus-20261003/README.md).

## Current white Beam route — October 3 follow-up

World guidance now uses one client-local `CommanderGuideBeam`. An attachment
on the player's root and an attachment on the current destination let Roblox
follow both endpoints natively. The old ten chevron Parts, their positioning
raycasts and transparency tweens are removed. The existing objective poll only
chooses the target, distance visibility and reduced-motion state.

The Beam repeats white directional arrows using Roblox's
[documented tutorial texture](https://create.roblox.com/docs/education/build-it-play-it-mansion-of-wonder/connect-the-beam)
(`rbxassetid://5886559421`), with native `TextureSpeed=1`; reduced motion sets
speed to zero. This beam-ready texture points along the route. Existing generated
white GUI and destination-pointer artwork remains unchanged. Attachments owned
by the controller are cleaned up on replacement/destruction; egg target
attachments are borrowed without taking their cleanup ownership.

The route hides near the destination, during menus/dialogue, on missing targets,
and when the guide no longer has a world step. The spotlight remains 0.5.

Thirteen focused Studio checks passed for native endpoint movement, target
replacement, attachment reuse, reduced motion, hiding and cleanup. The live
opening route loaded the white texture and pointed toward the free roll lever;
zero old chevron Parts remained. Local and running client source hashes matched.
[Beam validation](../../assets/tutorial-stroke-20261003/beam-validation.json).
The normal camera was restored and Play was left running, matching the task's
initial state. No release or saved-profile change was made.

## White arrows and stroke spotlight — preceding October 3 follow-up

The latest user correction replaces gold tutorial arrows, ground chevrons and
destination text with white. GUI and world pointers share original generated
chunky-simulator-icons artwork with a black silhouette outline
(`rbxassetid://101313283357577`). The earlier gold generation is retained as a
backup and is not used in runtime.

The spotlight uses the user's exact method: one transparent frame around the
real control, with an enormous **outer black UIStroke at 0.5 transparency**.
Thickness is at least 10,000 pixels. The four rectangular masks are removed.
The thin Army-green focus outline, TweenService pulse/bounce/fades, target
tracking, cleanup and static reduced-motion behavior remain.

At the earlier 0.8 spotlight transparency, nineteen focused checks passed on
desktop, landscape phone and portrait phone emulation. Pixel sampling confirmed even shading at all four screen corners,
clear target padding and an undimmed button. Native input successfully closed
the real research tree through its highlighted Exit control. The final white
image loaded in both GUI and world arrows; chevrons and destination text are
white. [Assets, prompts, screenshots and results](../../assets/tutorial-stroke-20261003/README.md).
Studio is in Edit with the default device; no experience release was published.

## Historical empty-yard start — October 3, superseded for fresh profiles

New profiles start with $2,400, three army slots, **zero chickens** and no podium
offer. The player must pull the normal free lever. Until the first chicken is
bought, that opening roll gives one guaranteed level-1 Chicken for the existing
$600 starter price. Free rerolls retain that offer price. Normal species odds,
recruit prices and owned podium count resume after the purchase; the opening
roll does not advance the paid guarantee schedule.

The server reserves $600 from other spending while this new profile has no
chicken and has never bought one. Upgrades and research can spend the remainder;
there are no camp/rank prerequisites. The upgrade tree explains the reserve.
Buying the chicken consumes the reserve and releases normal spending. While the
opening mission is incomplete, single and batch chicken sales must leave at
least one egg producer, including after manual deselection or skipping the guide.
This safeguard ends on first mission completion. Existing saves do not opt in.

`tutorial.emptyStart` is an additive boolean in the existing save envelope.
Absent means false. Loading existing profiles preserves cash, chickens and
upgrades. Rejoining before the purchase keeps the reserve and restarts at the
free lever because unbought offers are not saved. The guide teaches the first
egg sale before recruiting the remaining flock, then teaches expansion once
four chickens are owned. No ordinary recruit/upgrade prices were retuned.

Analytics version is `cluck-2-empty-start`, adding separate Roll and Grow
milestones. The existing server-confirmed purchase, egg-sale and camp milestones
remain. The longer time to build four chickens under current normal prices is
not a validated onboarding duration; first-loop timing and Grow stalls need
real-player evidence before economy changes.

Validation: 59 disposable server-fixture checks cover reserve boundaries for all
six cash tracks, direct legacy purchase actions, research, skip/rejoin, first-roll
repeats, early/duplicate purchases, last-flock sale batches, saved-profile
compatibility and guide progression. See
[the check source](../../assets/tutorial-empty-start-20261003/check-starter.luau).
The live Free-profile run confirmed an empty yard, native E lever/podium
interaction, $2,400 → $1,800 on the starter purchase, and normal walking pickup
of 33 eggs followed by an immediate $132 sale ($1,932 balance). The guide
advanced Roll → Recruit → Collect → Sell → Grow. A direct Luck request and a
real tree click were rejected with the reserve explanation; balance stayed
$2,400 and Luck stayed zero. The tooltip text fitted the desktop view.
[Results and synced source hashes](../../assets/tutorial-empty-start-20261003/validation.json).
Studio is back in Edit. No real profiles, publication or Git history changed.
The previous arrow/device/performance results below describe those earlier
presentation revisions; they are not new performance measurements.

## Arrows and spotlight — preceding October 3 follow-up

The user's follow-up adds pulsing ground chevrons, a bobbing gold destination
arrow, and a dark viewport overlay with a clear padded opening over the actual
next GUI control. The GUI arrow bounces toward the target and the green outline
pulses. All decorative motion uses TweenService; reduced motion is static.
The commander settles in with a small portrait salute and the Help body tweens
open beneath its stationary title. No new gameplay gates or purchases were added.

The overlay follows moving controls and clears when targets are hidden,
off-screen, destroyed, skipped or completed. Its masks do not capture input.
During a live disposable-profile run, the highlighted Upgrades control opened
the tree; the real Army Size 1 purchase changed capacity 3 → 4 and deducted
$1,200 ($2,028 → $828), then the spotlight handed off to Exit. The phone
emulator showed the same Exit cutout. No saved player balances were changed.

The focused spotlight fixture passes 19 checks on desktop, landscape iPhone 7
and portrait iPhone 7. The 14 motion/layout checks also passed at those sizes;
the desktop motion run preceded the final glyph-to-geometry arrow replacement.
Fifteen world-trail checks cover the five chevrons, non-interactive parts,
normal/reduced motion and hiding. Native Studio inspection confirmed the
downward destination arrow, which the Studio Flow viewport screenshot omits.
The initial Unicode arrow was replaced after it rendered as a missing glyph.

The fresh performance samples stayed at a 15 FPS Studio cadence; they do not
establish foreground or physical-phone performance for this revision. The
previous 60 FPS results below belong to the earlier compact-only revision.
Play is stopped, default device restored, session-only settings retained.
No release, asset upload, Git commit or push occurred in this follow-up.

- [Desktop spotlight](../../assets/tutorial-arrows-20261003/spotlight-desktop.jpg)
- [Actual upgrade target](../../assets/tutorial-arrows-20261003/spotlight-upgrade.jpg)
- [Phone Exit handoff after purchase](../../assets/tutorial-arrows-20261003/spotlight-phone.jpg)
- [Validation record](../../assets/tutorial-arrows-20261003/validation.json)

## Earlier compact-only polish status

The October 3 compact/motion revision is complete locally and synchronized into
Studio. The latest independent live visual review passed at **8.5/10**, after
7.8 on the first iteration. The final layout passes 14 focused checks on desktop,
landscape phone and portrait phone, plus the 18-state client suite.

The performance blocker is resolved. Activating the existing Studio window
through Finder's Applications → RobloxStudio → Open changed its background
15 FPS cadence to **60.04 FPS desktop** and **60.10 FPS in phone emulation**.
No game code, global graphics preferences or frame-cap settings were changed to
obtain those results. The motion suite passed again in the foreground. Studio
has been restored to Edit with the default device. Nothing was published.

## Review

- [Editable Figma flow and components](https://www.figma.com/design/4lJjZOqNhR8K7rfMbVIjaK?node-id=541-885)
- [Figma desktop and landscape-phone placement](https://www.figma.com/design/4lJjZOqNhR8K7rfMbVIjaK?node-id=546-965)
- [Final compact desktop](../../assets/tutorial-20261003/commander-polished-desktop.jpg)
- [Final compact landscape phone](../../assets/tutorial-20261003/commander-polished-phone.jpg)
- [Final layout and state results](../../assets/tutorial-20261003/polish-round2-results.json)
- [Research and watchable reference videos](</Users/stevin/Documents/ChatGPT/My Chicken Army/research/tutorial-2026-10-03/RESEARCH.md>)
- [Tizzy evidence with timestamps](</Users/stevin/Documents/ChatGPT/My Chicken Army/research/tutorial-2026-10-03/tizzy-evidence.md>)

## What the player gets

Commander Cluck is an original, transparent PNG of a saluting boxy chicken with
a green helmet, gold chevron and visible black silhouette outline. The guide
uses the approved Army green, SourceSans-based text, square geometry, near-black
transparent body, and approved full-sheet stud texture. Labels and controls
remain native/editable in both Roblox and Figma.

The card gives one immediate action. Tapping the commander opens contextual
help; on the upgrade/army steps it opens the relevant existing menu. Extra help
also appears after 20 seconds on a visible unresolved step. Tap CLOSE to fold
it; it will not reopen automatically during that step. It highlights the
actual next control with the animated arrow, dark cutout and TweenService pulse;
reduced motion makes the guidance static. A world arrow and local ground trail
point at the podium, a real available egg,
the sell pad, or the first camp. When the relevant native podium/camp prompt
appears, the card steps aside so the action stays accessible. It also yields
to notifications, Army/settings dialogs and the full-screen research tree.

The compact card uses native aspect fitting inside an 88%-width / 17.2%-height
envelope, so available height bounds the landscape layout and available width
bounds portrait. There are no device breakpoints, UIScale, UISizeConstraint or
UITextSizeConstraint. The quiet Skip target is separate from Help. A 180 ms
Quad Out TweenService entrance moves only 0.8% of safe height; repeated state
updates do not restart it, interruptions cancel it, and reduced motion settles
immediately. Contextual help grows the body below a stationary title. The last
visual refinement raises the strip, darkens its body, extends the approved
stud-sheet header to the right inset, and slightly overlaps the portrait.

| Step | Instruction and consequence | Completion evidence |
|---|---|---|
| Collect | Walk close to an egg to put it in the bag | Existing server collection fact or carried eggs |
| Sell | Walk onto the green pad for immediate cash | Server-confirmed instant sale |
| Roll | Pull the free lever after the first egg sale | Server-confirmed roll |
| Recruit | Buy the $600 fourth chicken | Committed purchase; free starter birds do not satisfy this lesson |
| Grow (legacy/recovery only) | Recruit toward four chickens if the existing profile has fewer | Four owned chickens; fresh cohort satisfies this after Recruit |
| Expand | Open Upgrades and buy Army Size 1 | Available army capacity reaches four |
| Select | Use Select Best or choose a squad | Four selected chickens; auto-selected squads already satisfy this |
| Deploy | Follow the marker and use Move Troops Here at Cluck Camp | Accepted server camp command |
| Battle / complete | Chickens fight automatically; after capture choose another recruit, upgrade or camp | Existing server camp-victory fact |

The guide observes gameplay rather than imposing prerequisites. Cash upgrades
remain accessible when affordable above the temporary recruit/army-slot reserves.
Existing progress and paid capacity
count; early victories end the guide without inventing missing milestones.
Unaffordable purchases route back to collecting/selling, and the recruit help
explains the free reroll. Defense, returning armies and recovery have appropriate
directions. It does not teach fusion, research branches, every shop product or
all camps in the opening sequence.

Skip saves the preference and can be resumed from Settings. Resume uses current
facts, rather than resetting progress. The victory message lasts eight seconds;
saved completion does not replay on the next visit. Completed legacy players
are not forced through a new tutorial.

## Evidence applied

Tizzy's examples are practitioner evidence, not universal benchmarks. The local
evidence packet preserves the original transcripts and claim limits.

- T01/T13: actions have a visible reason and consequence. This sequence links
  chicken → eggs → cash → more army capacity → captured camp.
- T05/T10: teach a single mechanic at a time, with extra complexity deferred.
  The guide adds no opening purchase modal.
- T07: track the upgrade menu opening, attempted purchase, confirmed result,
  and closing separately.
- T08/T16: check a small touch layout directly and segment production reporting
  by platform rather than trusting an overall completion percentage.
- T06/T14/T18: completion is only a diagnostic. Independent continuation, new
  player observation and mature D1 retention remain the outcome checks.

No controlled player study or retention improvement is claimed. The desktop
test visit took about 208 seconds to capture the camp, including tool pauses
and inspections; that is not a human completion-time benchmark.

## Code ownership

- shared/TutorialGuide: snapshot-only facts and objective resolution.
- client/CommanderGuide: presentation, help/skip controls, menu observations,
  target selection and cleanup. GuideFocus owns the clear cutout and GUI arrow;
  GuideArrow displays the shared generated white arrow image. These create
  ordinary Frames inside the existing
  PetRollGui ScreenGui and uses native Scale/aspect/TextScaled.
- server/TutorialService: sparse per-visit analytics, confirmed milestones,
  skip/resume state, and a bounded Studio diagnostics ring.
- BaseController retains world-marker and local ground-trail ownership. The
  trail points directly toward the goal; it is not obstacle-aware pathfinding.
  AppController creates and
  destroys the guide and adds the Settings resume control. HudController
  suppresses the superseded opening text line.
- GameServer observes augmented snapshots and committed actions. PlayerSession
  preserves optional booleans in its existing tutorial data:
  starterArmy, emptyStart, guideStarted, guideSkipped, guideDeployed and guideCompleted. Missing fields
  load false. There is no new profile schema or DataStore.

Guide code does not award cash, change prices, execute purchases, or authorize
deployment. UI reports cannot assert gameplay completion. Signals use the
existing remote's rate limit plus a per-signal cooldown and bounded allowlist.
Analytics failures do not reverse transactions.

## Analytics contract: cluck-4-eggs-first

Production events are server-side AnalyticsService calls. Studio collects a
bounded local ring instead of sending production analytics. Actual charts
therefore require a separately authorized published release and subsequent
event inspection.

Three custom fields are used:
1. tutorial version/cohort, such as cluck-4-eggs-first/FirstGuide or cluck-4-eggs-first/ReturningGuide;
2. stable step ID;
3. a bounded outcome, action, input class or time bucket.

FirstGuide means first exposure to this guide version's persisted start flag,
not proof of a brand-new Roblox account or first-ever game join. ReturningGuide
covers resumed/incomplete visits. Existing victorious veterans are excluded.
Use native platform filters for device reporting. No player IDs, GUIDs or
free-text error messages are custom dimensions.

| Event | Value / meaning |
|---|---|
| FTUEEntered | One eligible guide visit; cohort fixed at entry |
| FTUEEntryFailure | Seconds until departure without a ready profile; eligibility is unknown for a failed load |
| FTUEReadySeconds | Join-to-ready acknowledgement; detail Keyboard/Touch/Gamepad/Unknown |
| FTUEFirstActionSeconds | Join-to-first accepted core action or player egg pickup/sale |
| FTUEControlToActionSeconds | Ready-to-first-action when the ready acknowledgement preceded it |
| FTUEStepEntered | Active instruction, including recovery states |
| FTUEMilestone | A fact actually became true this visit; value seconds since entry |
| FTUEStepCompletedSeconds | Seconds since that step first became active; detail Under10 / 10To29 / 30To59 / 60To119 / 120Plus |
| FTUEStepStalled | A step remains unresolved for 30 seconds; once per activation |
| FTUEInteraction | Tree/Army open/close, node inspection, or bounded cash-upgrade attempt |
| FTUEActionRejected | Rejected action type, deduplicated per visit; this is not a success or detailed backend error taxonomy |
| FTUEHintShown | Extra help was requested/displayed; does not prove it was read |
| FTUEFirstPayoffSeconds | First sale or first win, distinguished by step |
| FTUEOutcome | Completed, EarlyVictory, SkippedVictory, Skipped, Resumed or Interrupted |
| FTUEGuidanceEnded | Completion card finished displaying |
| FTUEIndependentAction | First qualifying accepted action within 120 seconds after completion display or skip |
| FTUEFollowupWindow | Continued / NoAction after 120 seconds, or Continued / Exited if the visit ends earlier |
| FTUESurvival | Separate T30 / T60 / T180 / T300 / T600 categories for the same eligible visit |

Automatic vacuum receipts do not count as meaningful player input. An unchanged
Select Best/selection submission does not count either. Economy events record
committed Cash sinks and egg-sale sources with the actual ending balance;
picking an egg into the bag is not a currency source. Economy scope is eligible
tutorial visits, not a claim of complete game-wide economy instrumentation.

Native ordered funnels are deliberately not used: Roblox auto-fills missing
earlier steps when a later step is logged, which would misrepresent optional
and out-of-order play. Custom milestones retain the actual path. A skip never
logs final success. An early victory is reported separately.

### How to read the dashboard

Use unique users as well as event counts, hold the version/cohort and date
window constant, and show the denominator. Re-entering a step can emit another
step-entry event. Separate first-guide from returning-guide visits.

- Entry → ready → first action diagnoses loading and initial confusion.
- Step reach, actual milestones, dwell buckets, stalls and rejected actions
  diagnose the specific interaction.
- For upgrades, compare TreeOpen → AttemptCashUpgrade → Expand milestone →
  TreeClose. An inspection is UI evidence, not purchase proof.
- Compare T30/T60/etc. survival against eligible entries within mature windows.
  Also inspect Roblox's native new-user first-session retention curve; these
  custom cohort checkpoints do not replace the platform metric.
- Compare Completed, EarlyVictory, SkippedVictory and Skipped separately.
- Independent action is a continuation proxy, not proof of understanding or a
  completed second loop. Follow-up windows ending early are not silently counted
  as observed two-minute failures.
- Use Roblox's mature D1/D7 retention cohorts and deployment dates/platform
  breakdowns. No custom D1 event or A/B allocation system was added. A later
  experiment needs stable assignment, sample sizing and a predefined finish rule.

The numeric custom values support averages/min/max in Explore. The five dwell
buckets support rough distributions, not exact p50/p90. Non-completers must be
reported alongside successful durations. Production event delivery is best
effort; a disconnect or shutdown may prevent its final report.

Official API/reporting references:
[custom events](https://create.roblox.com/docs/production/analytics/custom-events),
[custom fields](https://create.roblox.com/docs/production/analytics/custom-fields),
[funnel behavior](https://create.roblox.com/docs/production/analytics/funnel-events),
[economy events](https://create.roblox.com/docs/production/analytics/economy-events),
[retention](https://create.roblox.com/docs/production/analytics/retention).

## Art and Figma

Original: assets/tutorial-20261003/commander-cluck.png, 1254×1254 RGBA.
Roblox ingestion: commander-cluck-roblox.png, uniformly reduced to 1024×1024.
Roblox image ID: 122076338993517, uploaded under community 778575811.
Upload receipt: ServerStorage.CommanderCluckArt20261003.
The original has an unclipped black silhouette stroke and transparent background.

Figma uses the original PNG and approved full-sheet studs as its only raster
ingredients. Page 541:885 contains the nine-state flow, three reusable component
variants, and desktop/landscape-phone placement examples. Component text
properties remain editable. It does not embed a flattened UI screenshot.

## Validation

- Full disposable Free desktop route: bought a chicken via the native prompt,
  walked to an egg, sold on the pad, clicked the real Army Size 1 node, deployed
  four fighters through the held camp prompt, won Cluck Camp and saw guidance
  end. Call Army 23.53 seconds later registered independent continuation.
- 34 isolated server/shared checks passed, including recovery routes, out-of-order
  facts, skip/resume, automatic collection, rejected actions, no-op selection,
  lifecycle cleanup, survival categories, duration buckets and save round trip.
- 18 client checks passed on Studio's iPhone 7 landscape preset (reported
  viewport 666×374): every main/help state fits; completion dismissal, reduced
  motion, saved-completion suppression and cleanup work.
- Actual Skip and Settings Resume controls were clicked in the phone simulator.
  The final tighter layout passes the 48-pixel minimum Skip target assertion
  on desktop, landscape and portrait; its Help and Skip hit areas do not overlap.
  The existing Settings Resume control is about 250×45 logical pixels.
- Generated art loaded in the Roblox client. Native podium prompts correctly
  hide the card and the next objective brings it back.
- Rojo packaging and git diff --check passed. Final source readback compares all
  nine modules with local source and checks that only one active copy exists.
  Identical duplicate new modules found during final inspection were preserved
  outside the runtime tree in ServerStorage.CommanderGuideDuplicateBackup20261003.

Evidence and rerunnable isolated checks are in assets/tutorial-20261003.
These were Studio tests, not physical phone/controller sessions or unfamiliar
player usability sessions. Production analytics delivery and retention are
unverified until an authorized release.

Unrelated existing warnings observed: the egg-deposit visual effect asks for
ReplicatedStorage.EggDepositEffects, which was absent; cash payout still worked.
Studio also reported plugin settings/HTTP warnings and a Rojo precommit-hook
warning during duplicate cleanup. Final module readback and fresh runtime checks
are the synchronization evidence. No tutorial runtime errors were observed.

## Final compact revision checks

The current code passes 14 focused checks at each viewport below. These cover
text fit, 48 px Skip targets, nonoverlapping hit areas, stationary title placement,
help closure, menu/notification handoffs, snapshot tween stability, reduced
motion and cleanup. The 18-state phone suite also passes against this revision.
Temporary fixtures were removed, without changing gameplay or profiles.

| Studio viewport | Card bounding size | Normal card / viewport area |
|---|---|---|
| Desktop 1238×587 | 491.34×90.99 | 6.15% |
| Landscape phone 666×374 | 293.50×54.35 | 6.40% |
| Portrait phone 373×666 | 328.24×60.79 | 8.03% |

These percentages measure the normal card rectangle; the decorative portrait
extends slightly outside it, and expanded help occupies more space.

The first independent visual review scored 7.8/10. Its requested smaller/higher
card, full-width green header, overlapping portrait and darker body are now
implemented in code and Figma. The fresh second review scored 8.5/10:
composition 2.5/3, palette 2.8/3, materials 2.4/3 and details 0.8/1. Remaining
differences from the generated target are nonblocking: a slightly smaller
portrait, centered placement, denser studs and darker body. The smaller portrait
and centered native composition preserve screen space across aspect ratios.
The current approved texture and palette preserve the game's existing style.

### Foreground performance sign-off

| 180-frame Studio sample | Median FPS | p95 frame time | Render CPU at sample end |
|---|---|---|---|
| Desktop 1238×587 | 60.04 | 17.66 ms | 2.93 ms |
| Landscape phone emulation 666×374 | 60.10 | 17.68 ms | 3.07 ms |

Opening RobloxStudio through Finder activated the existing window. The same
running scene then went from about 15 FPS to 60 FPS, establishing the earlier
background cadence as the cause of the failed performance samples. The game UI
on/off comparison had already shown about 15 FPS in both conditions. No tutorial
code or global settings were changed for this result. The final desktop motion
suite passed all 14 checks in the foreground, and actual Help closure was clicked
and captured. These are short Studio samples on this Mac; physical-phone
performance and production-load performance remain unmeasured.

Evidence: `foreground-final-results.json`, latest `commander-polished-desktop.jpg`,
and the updated Figma placement board. The earlier recheck and partial
MicroProfiler files are retained as historical diagnostics, not the final result.
A fresh audit confirmed all nine current local modules still match the reviewed
hashes and their one active Studio copy. No functional code changed after the
full gameplay and isolated analytics checks. Packaging and whitespace checks pass.

## Completion audit

| Requirement | Current evidence |
|---|---|
| Current Chicken Command style and original commander | Black-outlined transparent art, approved stud sheet, Army green, SourceSans, square geometry; reviewed live screenshot and editable Figma |
| Small screen footprint | Final 6.15% / 6.40% / 8.03% normal card rectangles across desktop / landscape / portrait; 48 px targets and text-fit checks |
| Clear, unobstructive guide | One action, contextual help, native prompt/menu handoff, skip/resume and saved completion; 18 client states and real gameplay route |
| Motion quality | 180 ms TweenService entrance; snapshots do not restart it; interruption cancels it; reduced motion settles; 14 foreground checks and ~60 FPS samples |
| Tutorial correctness and tracking | Full recruit-to-camp route; 34 isolated server/shared checks; Tizzy mapping and analytics interpretation above |
| Complete editable handoff | Nine-state Figma flow, reusable variants, device placement board, original PNG, synchronized local/Studio modules, research/video links |
| Preserve game and user work | Existing economy and authority retained; session-only test profiles; default device/Edit restored; no release, commits or unrelated edits |

The dream-loop exit gates (visual score ≥8 and acceptable target FPS) are met.
This completes implementation and Studio validation, not a claim of a measured
retention improvement or a universal best tutorial. Later unfamiliar-player
observation and production analytics remain the appropriate evaluation of learning.

## Next observation pass

Watch unfamiliar players start on touch, mouse and controller without coaching.
Record when the objective becomes obvious, the first interesting consequence,
where they stall, and what they choose after capture. Compare these observations
with first-session survival and mature D1 cohorts. Refine the timing/copy from
that evidence rather than treating this first implementation as a proven optimum.
