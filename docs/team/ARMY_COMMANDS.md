# Army command HUD — September 28, 2026

The bottom command row is **Call Army · My Army · My Base**, with My Army exactly centered. Transparent chunky whistle, helmet-chicken squad and yellow/orange tent art use separate native labels. My Army retains its live selected/deployed count and opens the existing inventory. Once researched, Call Army follows the currently selected squad; reserves stay home. My Base returns both the player and all owned chickens to their own yard. The older Base page is not reopened by this shortcut.

## Call Army research unlock — October 6

Call Army now unlocks through the skill tree. The `CallArmy` node branches directly
from Start at `(q=-1, r=2)`, costs **$1,000**, and takes **60 base seconds**. Existing
research-speed bonuses adjust the quoted duration before purchase. The node has
no camp, rank, or other research prerequisite beyond Start. Its existing whistle
art is reused.

Only completed research grants the permanent numeric effect `callArmy=1`; the
default is `0`. Buying or running its timer does not grant access, and cancelling
uses the existing exact research refund. Completion saves under
`research.completed.CallArmy`. Older saves receive no grandfathered unlock;
their existing completed nodes, jobs, other research progress, chickens and cash
retain their current validation and values. No existing prerequisite changes.

Before unlocking, the contextual HUD shows a dimmed **Unlock Call Army** control.
Activating it opens the tree, centers Call Army, and shows its existing research
tooltip. After completion it becomes the normal Call Army command. Home/outside
visibility and the command-row animations retain their existing behavior.

`ArmyCommandService:CallArmy` checks the server-owned effect before cooldown,
recall, Operation cleanup, or actor changes. A locked request fails without those
side effects, even if sent directly. My Base, ordinary attack/deploy actions,
actor cleanup, and battle return paths remain independent of the unlock. Calling
the army after unlock has no per-call charge; its existing cooldown remains.

Validation is recorded in
[`assets/call-army-research-20261006/checks.json`](../../assets/call-army-research-20261006/checks.json):
all 12 command checks passed, including locked and pending denial, unchanged
actors, available attacks and My Base, and the existing following/recall cases.
All Call Army research checks passed within 28 of 29 research checks. The one
failure is an older capture expectation superseded by the October 6 conquest
contract, not this unlock. A live locked HUD click opened and focused the node,
and its native research purchase sent a successful `StartResearch` request.
The live session also rejected a direct Call Army request during the timer and
kept the dimmed HUD state. Play ended before the completed HUD state was inspected;
the isolated checks cover completion and save/reload persistence. The full local
place is saved as `assets/call-army-research-20261006/MyChickenArmy-Call-Army-Research-20261006.rbxl`.
No saved player profile was written and the place was not published.

## Contextual row refinement — later September 28

My Army now uses an illustration about 40% larger than the two side illustrations and remains fixed at bottom center. `HudController` listens to the character Humanoid's existing `OutsideHomeBase` attribute from `WorldService:UpdatePlayerSpeed`. This covers the entire owned Deck with the existing boundary hysteresis, independent of army deployment. Call Army and My Base collapse inward behind My Army while inside the base and expand outward on leaving. Each side uses a dedicated button scale plus position through UIMotion's ordinary 0.32-second Quad InOut tweens; the nested hover/press scale remains separate. Rapid reversals cancel previous tracks and resume from their current values. Side commands are noninteractive during the transition and hidden after collapsing. Character replacement rebinds the signal; HUD destruction disconnects it. Resizing and reduced motion apply the current destination immediately.

The next refinement adds a bottom-anchored My Army scale tween: 82% at home, 100% outside, sharing the side controls' 0.32-second easing. The collapsing side controls aim at the smaller home icon's center. All three icons sit 6 px lower on compact layouts / 8 px on desktop; labels and the army count move 8 / 12 px upward, with labels layered above the artwork for a slight overlap.

These follow-ups change HUD presentation only. The earlier functional and image validation below predates these animations; the new animations have not been playtested.

## Ownership and transitions

September 30 following order: regular chickens occupy the front rows and Giants
(including Colossals) occupy separate rear rows. A partial regular row stays
centered; Giants start in the next row. Each group retains its selected order,
and membership refreshes rebuild the formation when selection changes. This
changes following destinations only, not saved/manual slots, combat ordering,
actor ownership or Giant-aware spacing. All-Giant and all-regular squads retain
centered three-column rows. Ten focused command checks passed using disposable
Edit-mode sessions and actor stubs; no live visual walk was run for this change.
Evidence: `assets/giant-follow-order-20260930/checks.json`.

September 28 following refinement: continuous server-owned steering now replaces
the five-Hz catch-up/stop loop while Following. Membership still refreshes at
five Hz. See [smooth-following research and checks](SMOOTH_FOLLOWING.md).

`ArmyCommandService` owns physical actors only during Following. It transfers the existing selected actors from `WorldService`, and selection changes swap actors without cloning them. `BestPetIds` remains authoritative, including the one-Colossal selection rule. Existing Humanoid/path movement drives a three-column formation with Giant-aware spacing; distant or blocked followers use the existing actor recovery support. Death returns the following squad home, and departure destroys its transient actors.

Call Army withdraws an active outgoing encounter through `BattleService:ReturnHome`, then transfers its actors before removing its return encounter. Shared territory defense can create a separate return encounter; only that owner's actors transfer. Earned kill rewards retain the existing rule, and recall grants no conquest. A currently defending home army cannot be withdrawn. Starting a camp attack releases the follower actors at their current positions for battle ownership; rejected attacks resume following.

My Base cancels the player's outgoing encounter, restores all their actors, positions them at server-owned home destinations, then moves their character to their own spawn. Commands require a living character and the existing loaded/writable session guard. Call Army uses a 0.75-second cooldown, My Base 2 seconds, plus the existing remote request limit. Clients never choose destinations or ownership IDs. The October 6 Call Army research adds its one-time cash cost and completion ID through the existing research save object; the commands add no per-use price or Robux feature.

### Following attack prompt correction — September 28

`BaseController:CommandFor` now accepts Following and uses the selected chicken count, as it does at Home. Previously the client omitted Following from its allowed states, so eligible targets never showed the attack prompt even though the server already supported the transition. Traveling, Fighting and Deployed still use the deployed count. Returning, Recovering and Defending remain blocked; target availability, lane ownership and server proximity validation are unchanged.

Four focused client checks passed in a fresh session-only Studio Play using `tests/FollowerAttackPromptChecks.luau`: Following attacks at eligible camp/outpost/King/income targets with zero deployed chickens; empty selections, unavailable targets, foreign lanes and protected bases; blocked army states; and existing Home/deployed counts. The fixture used disposable snapshots and a temporary unparented target, sent no requests and changed no player data. The two-line client change was read back from Studio and compiled successfully. The test Play was stopped afterward.

## Source and assets

Mapped scripts are edited locally and synced by Rojo. Artwork is imported through the existing Studio session. Prompts and generated source PNGs are under `assets/army-commands-20260928/`; the earlier helmet chickens are under `assets/army-hud-20260927/`. Final asset IDs live in `UITheme.Assets`.

## Validation and completed art hookup

Seven focused Studio checks passed in `tests/ArmyCommandChecks.luau`: selected actor transfers/repeat calls/cooldown, Colossal selection swaps and empty selections, all-chicken base return, accepted/rejected attacks, dead/empty squads, outgoing battle recall, and shared territory defense preservation. A session-only Play test then verified actual HUD clicks: Call Army returned success, My Army opened the existing ChickenBrowser, and My Base returned success with all three owned chickens home. After walking, all three followers were within 7.9–10.1 studs. One blocked chicken used the existing PetActor rig recovery and retained its inventory ID. Recovery may replace an unhealthy model; normal ownership transfers reuse actors. Receipts are in `assets/army-commands-20260928/validation.json`. Rojo packaging and `git diff --check` passed.

All three images are imported under Kiru Experiences and connected in `UITheme.Assets`: CallArmy `125964672530167`, ArmyHud `107457338807219`, MyBase `76117843071069`. The user completed the soldier import and supplied the three IDs when computer control could not read the Uploads list. MarketplaceService independently confirmed each asset's name, Image type and group creator before assignment. A fresh session-only Play test confirmed all three ImageLabels report `IsLoaded=true` and visually show the correct artwork with native labels. Screenshot: `assets/army-commands-20260928/command-hud-in-studio.jpg`. Do not re-upload these assets.

The final readback found two identical Rojo-synced ArmyCommandService instances. One was preserved outside the runtime tree at `ServerStorage.ArmyCommandDuplicateBackup20260928.ArmyCommandService`; one remains active. Other changed modules each have one matching, parsable copy. The final image references were read back from the Rojo-synced UITheme before Play. The Play test was stopped. No saved player profile writes, place publication, Git commit or push occurred. Generated PNGs, screenshot and mapped code are preserved locally; the current code is synced through Rojo.
