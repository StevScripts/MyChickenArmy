# Research progression — October 2, 2026

Status: rebuilt against the user’s October 2, 1:17 PM recording and synced to
Pet Roll Test. The original Chicken Army artwork remains in use. Desktop and
landscape phone simulator checks cover the interactions listed below; no physical
device equivalence or pixel-perfect clone is claimed. Nothing has been published.

The later Slime RNG request added twelve rolling-focused nodes. The October 6
Call Army and Fuse Machine unlocks bring the current catalog to **62 paid nodes plus Start (63
total)**. See [rolling research](RESEARCH_ROLLING.md) for the complete rolling
reference review, adaptation choices and runtime contract.

Six existing cash-upgrade tracks form 91 individual purchase-tier hexes, branching
from Start among the research paths. Earned tiers stay green and reveal the next
purchase. The user rejected a separate cash island. These purchases apply
immediately and remain independent of research slots/prerequisites;
see [cash upgrades in the tree](CASH_UPGRADES_IN_TREE.md).

## Fuse Machine unlock — October 6

`FuseMachine` sits in the Rolling area at `(3, -4)`, next to Roll Speed, behind
**Lucky Feathers I → Roll Speed** (prerequisite `R1`; moved October 9 at the user's
request so it is an earned unlock beside the tree, not a far-off leaf off Start).
It costs **$5,000**, takes **120 base seconds**, and grants `fusion=1` on completion.
It uses the existing Merge artwork and leaves all other nodes/coordinates intact.
The combined map now contains **154 nodes** (63 research/Start plus 91 cash tiers).

This replaces the Cluck Camp unlock. Locked machine use produces the normal
Error notice and focuses its research node. Existing earned access migrates to
completed research without a charge or unrelated node grants. See
[the fusion contract](../MERGING.md) and
[focused checks](../../assets/fusion-research-20261006/README.md).

## Call Army unlock — October 6

`CallArmy` is an early Army research leaf directly off Start at `(q=-1, r=2)`.
It costs **$1,000** and takes **60 base seconds**, subject to the existing
research-speed quote. It has no camp/rank gate and does not alter any existing
research or cash-upgrade prerequisite. At the time of the Call Army addition the catalog had 62 nodes and the combined
map had 153. The later Fuse Machine addition above brings those to 63 and 154.

The permanent numeric effect is `callArmy=1` only after completion; its default
is `0`. An active job grants no access. Completion uses the existing
`research.completed.CallArmy` save entry, and cancellation uses the existing
exact refund transaction. Existing research saves remain valid with their
original completed IDs, jobs and values. Older profiles receive no automatic
Call Army grant.

The dimmed HUD control reads **Unlock Call Army** and opens the tree focused on
this node and its tooltip. Once researched it invokes the ordinary command.
The server rejects locked commands before cooldown, recall, Operation cleanup,
or actor changes. My Base and ordinary attack/deploy actions remain available
under their existing rules. See [army commands](ARMY_COMMANDS.md) for following,
recall and HUD behavior.

## Design authority

The accepted plan is
`/Users/stevin/Documents/ChatGPT/My Chicken Army/plans/2026-10-02-research-tree-plan.md`.
Figma: [full-screen research](https://www.figma.com/design/4lJjZOqNhR8K7rfMbVIjaK/my-chicken-army?node-id=497-1502).

The user's full-screen correction supersedes the shared popup recipe for this
screen. Research is an edge-to-edge black map with adjacent hexagons, offline
message at the top, researcher/cash values bottom-left, Exit bottom-center and a
compact pointer-following tooltip. There is no title bar, fixed inspector or job
toolbar. The supplied 1:17 PM recording and
`style-guide/mini-war-research-20261002/ANALYSIS.md` in the design workspace
supersede the earlier generated/Figma visual target. Generated prices and
sample unlock states are not authoritative. Exact unobserved Mini War mechanics
are not claimed. All research nodes and their tuning belong to Chicken Army.

`ResearchBrowser` uses a Frame-like TextButton under `PetRollGui.Shell.FRAMES`.
While open, it uses native `ScreenInsets.DeviceSafeInsets` and
`SafeAreaCompatibility.FullscreenExtension`: the black background fills the screen
while controls clear phone edges. Both properties restore on close. It does not add
a ScreenGui or UIScale. Scale properties and native aspect constraints preserve
the map's proportions. Mouse/touch pan and zoom change the
map transform, never the individual node layout.

## Owners

| Owner | Responsibility |
|---|---|
| `shared/ResearchCatalog` | Start plus 62 paid nodes, links, coordinates, prices, durations, effects |
| `shared/ResearchRules` | Highest-tier bonuses, quotes, statuses, deep copy, save validation |
| `server/ResearchService` | Non-yielding purchase/cancel/completion/pin transactions and snapshots |
| `server/PlayerSession`, `DataService` | Saved research and integration with existing earnings checkpoints |
| `server/ArmyAbilities` | Rally eligibility, saved cooldown, session-local active duration |
| `server/ArmyCommandService`, `client/HudController` | Call Army completion gate and locked HUD route to its research node |
| `server/ArmyService` | Save/apply formation through existing army selection validation |
| `shared/OperationCatalog` | Nine fixed encounters, first/replay rewards, banner tiers |
| `server/OperationService`, `OperationRewards` | Separate arenas, finite rosters, rewards, cleanup and earned scenery |
| `server/Battle`, `BattleService`, `LiveBattleActors` | Actual damage/health/armor/movement/recovery/capture effects |
| `server/EggService`, `OfflineCash`, `WorldService` | Future egg quantities/values, pickup, offline limits and player speed |
| `client/ResearchBrowser`, `ResearchAssets` | Full-screen tree, node states, tooltip, navigation and art references |
| `client/ResearchExtras` | Rally, pinned goal, formations and Operations menus |
| `client/ChickenBrowser` | Permanent research bonuses in displayed health and DPS |

## Save and transaction contract

The optional `research` object defaults safely for older profiles:

```text
completed: { Start=true, <known node ID>=true }
jobs: [{ id, nodeId, startedAt, finishAt, paid }]
revision: integer
pinned: optional known node ID
rallyReadyAt: Unix seconds
formations: { "1"/"2"/"3": { name, petIds } }
operationWins: { "1:1" through "3:3": true }
pendingOperationReward: already-multiplied integer cash, normally zero
eggValueRemainder: fraction in [0, 1)
```

Saved data is copied deeply. Unknown IDs, missing prerequisites, malformed or
duplicate jobs and invalid numbers reject the load; they are not silently erased.
Jobs use absolute server times. Start validates revision, prerequisite, cash,
quoted price/duration and a free researcher before one debit. Completion removes
the job once and recomputes effects. Later research-speed purchases never move an
existing deadline. Cancel returns the actual debit once, without Double Cash;
a full wallet retains the job until its refund can fit or it completes.

Offline research reconciles on load. Offline earnings still use the departure
checkpoint and its old rate/cap, so research finishing during absence cannot
retroactively increase the entire absence's cash.

## Effects and boundaries

Within each family, the highest completed bonus replaces lower tiers. No stat is
saved as an already-multiplied chicken base stat. Reapplying research is idempotent
and preserves the current health fraction. NPCs do not receive player bonuses.
Boss damage applies to NPC bosses, including eligible splash hits, not PvP units.

Capture retains the existing four seconds of neutralization. Only the following
four seconds receive the rate bonus: at +30%, total time is `4 + 4/1.3 ≈ 7.08s`.
Research does not accelerate enemy reclaim or create persistent camp ownership.
Recovery bonuses affect newly scheduled deadlines; existing recovery is not restarted.

Production changes future quantities of physically home chickens. Packing changes
future shared egg value, with a saved fractional remainder so individual rounding
cannot inflate earnings. Existing drops, carried bags and cash keep their values.
Instant egg deposits remain active. Selling Speed and Finish Now remain inactive.

Cash upgrades, recruit prices, physical podium/plot limits, fusion fees, earned
Giant sizes and the single-Colossal army rule retain their separate contracts.
Research never adds camp/rank prerequisites to those existing cash upgrades.

Rally adds 20% base damage for 8 or 12 seconds and has a saved 90-second cooldown.
It affects the current eligible deployed battle; it does not stack or heal units.
G / controller LT and a visible button invoke the same server action.

Formation research unlocks one to three saved selections, not extra deployed
slots. Saves require the current selected IDs and revision. Applying filters sold
birds and respects capacity and Colossal selection/replacement rules.

## Operations

Three sets each contain three fixed encounters. Unlocks use research; rosters do
not scale with wallet or player power. The chosen army is finite for the mission:
no reinforcements or respawns. Defeat all enemies and complete the existing
capture phase. Leaving, death or walking out ends the mission without a reward.
Unlocked Call Army and My Base also abandon the Operation through the same cleanup
path. A locked Call Army request is rejected before it can abandon an Operation.

Each player's arena clones the existing authored KingArena into a separate area.
It never reserves a public camp. Physical actors stay under the existing
`PetRollWorld.Battles.<battle ID>` hierarchy so normal animation, health and combat
effects bind correctly. A one-time camera orientation faces the fight; normal
camera control continues. Leaving restores actors and removes the arena.

One first-clear cash reward and a smaller replay reward use existing earned-cash
multipliers. Kills do not also pay ordinary camp bounty. If the wallet fills during
the fight, the exact earned payout is saved in `pendingOperationReward` and paid
automatically after cash is spent. New deployments wait until it is paid. Loading
or changing pass state cannot multiply that saved payout again.

Three distinct wins in a set earn its banner, cloned from the authored throne flag.
The Royal set also displays Royal Commander at home. These add no stat advantage.
Prices, rosters and times are initial tuning, not a measured player progression curve.

## Evidence and validation limits

October 6 Call Army checks are recorded in
[`assets/call-army-research-20261006/checks.json`](../../assets/call-army-research-20261006/checks.json).
All 12 army-command checks and all new Call Army research checks passed. The
research suite passed 28 of 29: the existing capture check still expects the old
`4 + 4/1.3` ordinary-camp timing. The current [October 6 conquest
contract](CONQUEST_REFERENCE.md) uses `25/1.3` and supersedes that assertion and
the older ordinary-camp timing paragraph above. This failure is unrelated to
Call Army. A live locked HUD click opened and focused the node, and its native
purchase successfully invoked `StartResearch`. A direct command during its timer
was rejected and the HUD stayed dimmed. Play ended before the completed HUD state
was inspected; isolated completion, cancellation and save/reload checks passed.

The following records describe the earlier research implementation:

- `tests/ResearchChecks.luau`: 27 isolated checks pass, including quotes, duplicate
  requests, refunds, old saves, offline completion, actual fractional egg production,
  actual boss/splash/armor damage, finite rosters, formation filtering and reward overflow.
- Rojo scripts-only packaging succeeds; Studio source compilation succeeds. Neither
  alone establishes runtime correctness.
- Disposable SessionOnly Play: full-screen entry and HUD hiding, node navigation,
  starting/cancelling research, a natural Veteran victory, its lower replay payout,
  leaving without reward, return/arena cleanup and Rally were exercised.
- All nine encounters are winnable in a deterministic combat-table simulation with
  developed sample armies. This is a reachability check, not production balance proof.
- After correcting the actor folder, all 25 Royal mission combat views bound in the
  live client and the arrival camera faced the fight.
- Courier Boots applies +15% after the world update: 36.8 speed at home and 51.75
  outside. Real server requests saved/renamed a ten-chicken formation and restored
  it after reducing selection to one.
- Disposable defeat/death fixtures returned the army with zero completion reward;
  disconnect removed the arena, combat actors and banner. Three Veteran completion
  fixtures created the authored five-part earned banner. These forced-outcome
  checks establish cleanup/reward behavior, not encounter balance.

Six generated utility icons and two plain hex images were imported through Asset
Manager under Kiru Experiences. `client/ResearchAssets` contains their real IDs;
`assets/research-20261002/README.md` records the mapping. ImageLabel load state and
live screenshots confirm the artwork renders. Initial string-only preload calls
reported failure even for existing artwork, so they were not used as render proof.

### Historical review before the supplied recording

These results describe the earlier generated/Figma target, not the current
recording-based revision or fidelity to Mini War.

The first independent Dream Loop visual review scored 8.2/10. Its material issues
were corrected: locked captions now fit within the hexes and have higher contrast.
The final pass also uses thinner label outlines, neutral white labels, a smaller
offline banner and a less prominent Exit inset. Cash/researchers sit slightly
inward so a landscape phone's rounded corner does not clip the icon.
The fresh final judge scored 8.8/10 with no material visual regressions. Remaining
minor differences are flatter hex shading/glow, a prominent phone tooltip border
and completion checks that overlap icons. That composition passed its earlier target. The user subsequently rejected the
match to Mini War; the recording-based correction below supersedes that judgment.

Final simulator evidence lives in `.dream-loop/research-desktop-final.png`,
`research-phone-final.png` and `research-phone-tooltip-final.png`. Phone touch
events were observed during real simulator taps and dragging; the map moved
without accidentally opening a node. A quick-drag release now consumes the final
input position even if the movement event arrives late. Desktop wheel zoom,
dragging, node selection, tooltip actions and keyboard navigation were exercised.
Two-finger pinch and a physical controller/phone were not exercised end-to-end;
virtual controller A/Y navigation was checked earlier, while the tool's B input
was intercepted by Roblox CoreGui.

With Research visible and Roblox's pause menu closed, ten-second RenderStepped
samples measured 60.001 FPS on the 1240×737 desktop viewport (p95 17.69 ms) and
60.003 FPS on the 749×361 landscape phone simulator (p95 17.63 ms). These measure
this Mac's simulator, not physical-device performance. Earlier samples ran near
15 FPS during an unresolved Studio focus/menu state; after restoring interaction,
the final samples above passed without changing engine rendering settings.

After the final source edit, Rojo packaging and `git diff --check` passed. A full
120-file source comparison after reconnecting found no local/Studio mismatches;
the final ResearchBrowser margin edit was read back and compiled in Studio.

Ten identical extra research ModuleScripts were preserved in
`ServerStorage.ResearchDuplicateArchive20261002`. One active copy of each remains
and matches current local source; check its Rojo updates when asset IDs are added.
Preexisting unrelated duplicate modules were left untouched.
The restored reference `GUI` also contains an unrelated FriendBoost handler
that errors, and EggDepositEffects is absent. These preexisting assets were preserved.
All checks above used disposable profiles; no saved flock, real purchase,
publication or Git push was performed. The UI-coherence chat subsequently finished
its separate menu work and released Studio for the refinement below.

## October 2 supplied-recording refinement

The user's 1:17 PM recording supersedes the earlier generated/Figma visual target.
Evidence and complete analysis:
`/Users/stevin/Documents/ChatGPT/My Chicken Army/style-guide/mini-war-research-20261002/ANALYSIS.md`.
The prior 8.8 review remains historical evidence against the previous target and
must not be described as fidelity to this recording.

ResearchBrowser now uses a compact pointer-following information card: name,
divider, gray benefit, cash-icon price or progress/time. Completed nodes omit the
footer. It scales independently of graph zoom through a native aspect constraint.
There is no default inspector artwork, state row, effect comparison, duration
breakdown, Research button, goal button or X.

Available hex activation sends the same validated StartResearch quote directly.
Completed formations/Operations nodes retain their existing navigation. Active
nodes show their timer; no unconfigured paid-skip product/control is added. Cancel
and pin remain available through a secondary menu: right-click, touch hold or
controller Y. Cancellation still requires a second confirmation and uses the
same revision/job validation and refund owner. Unknown cells do not expose their
future name or effect through hover. Explicit links to a distant node focus the
nearest known prerequisite.

Node states use soft layered halos around the existing original hex mask, green
completed faces and pale green rims, cyan active faces and embedded timer bars,
white available rims and cash-icon prices, faint known previews, and gray '?' cells.
Completion checks and Locked captions are removed. Only known nodes and their
next question-mark frontier render. Starting a parent reveals a dim child preview;
server prerequisites remain unchanged. The clip does not establish every reveal
trigger, so this is an explicit presentation choice.

Opening and newly visible nodes grow through short staggered TweenService tweens.
Busy/insufficient-cash/prerequisite feedback flashes the attempted hex and displays
a short red message without repositioning the graph. Completion displays a blue
message and a finite native-tween confetti burst. Reduced motion skips reveals
and particles. Close cancels the node tweens; destroy disconnects input/heartbeat.

Native Scale properties, UIAspectRatioConstraint, TextScaled and the original
ScreenGui root are retained. Tooltip/Exit rounding is limited to Research. Exit
uses the approved full-sheet stud texture. No reference artwork is shipped.

ResearchCatalog coordinate-only changes move Rally to (-3,1), Battle Cry to
(-4,1) and Research Team to (1,-2). All 49 cells are unique and every prerequisite
edge now spans one adjacent hex. IDs, prices, durations, prerequisites, bonuses,
saves, cash-upgrade rules and server transactions are unchanged.


AppController passes Research action results to ResearchBrowser. While the graph
is open, starts no longer trigger the large global success toast; errors and
secondary-action feedback stay within the compact Research feedback layer.
Other menus retain their existing notifications and scrolling fixes.

### Recording-refinement checks and limits

- Final local/Studio source lengths and rolling hashes match for ResearchBrowser,
  ResearchCatalog and AppController; all three compile in Studio. Scripts-only
  Rojo packaging succeeds.
- A real available-hex click started A1 with its cyan timer. Natural expiry changed
  it to green and advanced the frontier. Busy feedback left the map in place.
- A second click on an active job did not cancel it. Right-click exposed the
  secondary menu; two-step cancellation refunded the real session-only debit.
- Desktop drag did not accidentally start research. Mouse movement moved the
  tooltip; wheel zoom changed the graph while the tooltip size stayed constant.
- Landscape iPhone 13 simulator emitted Touch input. Tapping a completed node
  opened its compact details; holding it opened secondary controls. Native safe
  areas kept the wallet visible, with a black background across the display.
- Exit restored the HUD and the previous ScreenGui safe-area properties. Play is
  stopped, the simulator is off/default, the temporary probe is gone and Rojo
  remains connected.

Final captures: `.dream-loop/research-recording-refinement/desktop-final.jpg` and
`phone-final.jpg`. They use a disposable developed-progress fixture (granted
research prerequisites and cash); they do not show a real saved profile.
The screenshots use different pan/framing and include a naturally completed
Formation Book job, so progression states must be considered during comparison.

No physical phone/controller, two-finger pinch or paid skip was exercised in this
refinement. Paid skip remains unconfigured. Original icon silhouettes, text
wrapping and unknown source timing parameters differ; this is an implementation
of the observed presentation and interactions, not recovered Mini War source.
No server gameplay owner, prices, upgrade effects, saved data or other menu layout
was changed by this refinement. Existing unrelated restored-GUI/plugin errors
remain outside its scope.

## Saves survive tree changes: October 9, 2026

Moving FuseMachine under R1 made every save that already held FuseMachine (but not
R1) fail `ResearchRules.Read`, so those players were kicked with "This save needs
recovery" (their data was never overwritten). `Read` no longer re-checks
prerequisites for completed nodes or running jobs, and drops nodes that no longer
exist instead of rejecting the save. Prerequisites are enforced only when research
starts (`ResearchService.Start`). Rearranging or removing nodes is now safe for
existing saves; malformed research data still fails to load.
