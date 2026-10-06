# Manual chicken merging

## October 5 machine unlock

New profiles unlock the Fuse Machine on their first Cluck Camp capture. Before
that, the owned machine's native prompt reads **Fuse Machine · Locked** /
**Capture Cluck Camp**. Activating it explains the requirement without opening
Fuse. The Army inspector shows the same requirement; the first live victory
notification appends **Fuse Machine unlocked!** when access changes.

`PlayerSession:MergeAccess()` owns eligibility. `firstWins[1]` grants access;
the additive saved boolean `fusionUnlocked` retains earned access. Fresh saves
explicitly store false. Valid older saves lacking this field retain their
previous access, including profiles from the earlier starter-army cohort.
Save loading validates the field before committing any profile changes.

GameServer checks access for OpenMerge, Merge and MergeAll. ArmyService also
checks it before either transaction and returns no recipes while locked. The
client guards menu entry and closes a stale locked menu. The prompt stays visible
to explain the requirement and retains owner/range/reveal checks. This changes
fusion access only: cash upgrades remain independent of camps, and all existing
fusion fees, matching rules, Giant sizes, protected birds and limits remain.

The user requested an unlock; Cluck Camp was chosen as the implementation default
to follow the introductory battle. It is not a measured retention result.

All 53 focused unlock/persistence/prompt checks and 87 starter-army checks passed
in disposable Studio objects. A session-only live client rejected locked menu
entry and opened the real menu after test camp progress was granted. All seven
changed modules matched Studio before testing; packaging passed. Studio was
returned to Edit. [Scope and results](../assets/fusion-unlock-20261005/README.md).

September 29: individual cash leveling is also available in My Army. The user explicitly kept this existing fusion contract for now; cash levels do not introduce a Giant-chance machine. See [cash upgrades](team/CHICKEN_CASH_UPGRADES.md).

Implemented September 25, 2026 at the user's explicit request. This supersedes older statements that merging is disabled. `Config.Features.Merging = true`; `AutoMerging = false`. Enabling the manual feature does not enable the paid Auto Merge listing or automatic consumption.

September 28: every successful fusion now guarantees a **Giant**, sized **4–27.5
studs**, with fresh Common Giants limited to 4–6 studs and larger rarity bands
up to Mythic 15–27.5 studs. Fusion costs 25% of one matching input's normal
recruit price, rounded up. Input catalog rarity weights the size roll; re-fusion preserves at least
the largest input's size. The optional saved `giantSize` field follows the chicken
through home, army, battle and recovery. Giant size adds no stat bonus beyond the
existing next-level reward. See [the current Giant contract](team/GIANT_CHICKEN_DESIGN.md)
for distribution, bounds, persistence and validation.

Latest September 28 clarification: **Colossal = 20+ saved studs**, with only one
selected/deployed per player's army. Smaller Giants have no special army limit.
Fresh Legendary inputs have a 1% Colossal chance; Mythic inputs have 3%, biased
toward 20 studs within that rare tail. Lower rarities cannot freshly roll 20+.
Existing sizes remain valid and inherited, even on older low-rarity birds.
Inventory offers **Replace Colossal**; server validation, Select Best, saved
lineups and battle handoffs enforce the same rule. Owning multiple is allowed.

## Player flow

September 27 replaces the old two-column merge browser with the chicken-specific
[image-led Figma fuse flow](https://www.figma.com/design/4lJjZOqNhR8K7rfMbVIjaK/my-chicken-army?node-id=437-2024).
Approach your own Fuse Machine's button and press E. Fill three Add slots; each
tap in **Choose Chicken** stages one actual owned chicken. The initial picker
shows only species/star/level groups with at least three eligible copies. Once
one is staged, only the same group remains. Counts exclude staged copies, so a
three-copy group remains selectable as ×2 then ×1. Search filters chicken names.
Remove reverses staging. It does not consume or change inventory.

The result card previews the same chicken as a Giant at its next level. **Fuse** submits
exactly the three staged IDs, retaining server priority for an equipped survivor.
The server consumes two IDs and advances the survivor one level (three inputs,
one output); other copies remain. The Fuse button shows the cash fee. The server requires a matching price quote
and sufficient cash before charging and consuming together. No mandatory
confirmation dialog.
September 28 popup behavior: after server-confirmed success, the fuse GUI closes
through the normal popup exit/focus cleanup. It does not play the popup fusion
animation or automatically open a result screen. The authored machine charges
with its door closed, then opens to reveal one upgraded chicken coming out onto
the platform. The actual owned result then walks into its yard; there is no
fade-out copy or replacement spawning at home. No input chickens enter from
outside. The resulting chicken's
level, size and stats remain available in inventory. Rejected requests keep the
popup open with the error; closing or switching pages before a late result does
not reopen Fuse or close another page. The [quantity economy](EGG_ECONOMY.md)
retains the saved merge tradeoff below.

Pending requests cannot submit again. A 12-second timeout keeps the UI in a
checking state and requests Sync; only its acknowledged response resolves the
inventory outcome. An uncorrelated snapshot cannot clear the request. Reopening
a checking request asks for Sync again. Closing cancels presentation, not an
accepted server transaction. Reopening while a request is still pending follows
that same request. Stale eligibility clears unavailable inputs and requires a new
deliberate selection. No speculative rewards or automatic resubmission.

The user explicitly chose to keep the saved balance: income follows the existing 2^(level−1) formula, and combat gains 25% of base HP/damage per level. Three level-1 inputs therefore become one chicken with 2× individual income and 1.25× individual combat stats. Total flock income and total combined DPS decrease; power per occupied slot increases. This implementation does not claim the feature is economy-neutral or newly balanced.

Existing merge progression caps are retained from `Progression.Get(session.promotion).levelCap` (3/5/7/10). This is the old merge-specific rule, separate from cash upgrades. Cash upgrades remain available from the start whenever affordable; never introduce camp gates for them. No alternate star tier, output species lottery or new currency was added. The September 28 fusion fee is separate from other shop prices. Giant fusion adds an optional saved size field; old profiles remain compatible without a revision migration.

Favorites, away/deployed chickens, selected defenders during an incoming battle and chickens at the merge cap are excluded. Home reserves can merge while the army is away. Manual merging may include selected home chickens, retaining an existing squad ID first. Consumed IDs are removed from manual selection, their investment values accumulate on the survivor, and refresh/save uses existing ownership paths.

## Ownership and integration

- `ArmyService`: server grouping, exact triple validation and non-yielding consumption. Same species, stars and level required. Validates the whole optional batch before any mutations; old pair payloads cannot consume chickens.
- `GiantChicken` / `ChickenGrowth`: size distribution and validation; uniform Giant art scaling with ordinary walking collision/navigation dimensions. `PlayerSession` owns the optional saved size.
- `GameServer`: loaded/save ownership checks, rate limit, same-plot and distance validation, result snapshots. Uses `firstId`, `secondId`, `thirdId`, `level`, `expectedPrice` and `stationIndex`; legacy internal batch route takes `triples`.
- `MergeStand` / `WorldService`: the builder-owned standalone `Workspace.Fuse_Machine` remains unchanged in Edit. During Play it is retained in ServerStorage and cloned at its Plot 1-relative placement into each runtime plot. A machine already nested in an authored plot takes precedence. Existing Button/ProximityPrompt is reused; `MergeGate` retracts sectional door copies inward beneath the header. Obsolete merge stalls are removed only from runtime copies. Missing machine/anchor has a safe prompt fallback.
- `MergeBrowser`: three input slots, chicken picker, result/recovery states, pending request lifecycle and responsive layout. `MergeSelection` owns reversible local staging against server-issued eligible IDs. Neither determines inventory or rewards.
- `MergePresentation`: pending-request UI presentation; the old popup success reveal is retained but no longer invoked. Confirmed success closes the GUI so the world's single output chicken is visible. `MergeStand` temporarily controls the actual owned actor during the reveal; `WorldService` resumes its home walk with the same rig.

Gate animation uses ordinary TweenService tweens: four sections rise, bend inward through a quarter-turn and disappear beneath the roof. Runtime copies split only the tall plain backing panel; authored trim and hinges ride their nearest section. No whole-door lift above the machine. The closed machine charges first; opening runs from 0.65–1.2 seconds. The actual upgraded chicken moves from inside the chamber onto the outside platform from 1.2–1.8 seconds, facing outward. A purple burst accompanies its exit. It fits the doorway during exit and grows to its saved Giant size outside from 1.85–2.4 seconds. The door closes behind it from 2–2.5 seconds. At 2.6 seconds its temporary anchor and size controls are released and the same actor walks to its home position using the existing Humanoid/pathfinding owner. It does not fade, get destroyed or respawn in the yard. Original door settings restore after completion or interruption. TweenService owns the reveal's easing; normal chicken walking owns the route home.

During the reveal, `WorldService` pauses that actor's roaming and snapshot visual
updates; the machine temporarily rejects another fuse. `TakeActor` releases the
reveal before an army handoff, and `RestoreActor` releases it while preserving an
explicit home teleport destination. Destroyed/sold birds are not recreated by a
delayed reveal callback. Existing home navigation handles blocked routes and
physical recovery; this change does not alter fusion rewards, charges or saves.

## Visual contract

September 28 walk-out verification: all five focused checks in
`tests/FusionWalkChecks.luau` passed using disposable actors on the unused second
plot. A 4.5-stud Giant walked 20.42 studs and a 27.5-stud Colossal walked 12.09
studs toward their home targets, retaining the same model and root with no
recovery teleport. Mid-reveal army handoff, home teleport and deletion also
passed. Evidence: `assets/giant-fusion-20260928/walk-out-checks.json`. Both changed
sources compile and match their single Studio copy. Fixtures were removed;
Play stopped and the original session-only flag stayed true. No profile edits
or publication. This is a focused physical movement check, not a multiplayer soak.

Current Figma page **434:885**, ready **437:2024**, picker **437:2135**, result **437:2481**.
The user rejected the earlier September 27 page 419:885/ready 421:1194 visual design.
The September 25 two-column dialog is also historical. Purple studded header, generated
three-chicken icon, red close, square geometry, opaque black-purple `#0D0913`,
three Add/Remove cards with purple connections to one centered result, and Fuse.
The picker replaces the content in the same popup: three desktop columns, two
compact columns, rarity strip, remaining count plus name/level. Native chicken portraits throughout.
Primary action stays pinned; short screens scroll content without shrinking touch
targets below 44 px. Sparse copy, no Merge All, no extra confirmation chain.

The 13 current editable Figma frames include empty, one/two/three selected, initial
and compatible-only pickers, no eligible trio, no search result, fusing, completion,
changed inventory and delayed status. Main actions are linked as a prototype.
The generated six-state sheet is included on the page as the visual target; controls
and text in the implementation frames are separately editable. Actual Steal an Egg
screenshots informed the compact three-input/pipe/result structure. Its full picker
and every recovery state were not available as direct references, so those use the
game's existing inventory and request contract. No borrowed creature artwork,
random eggs, reference-game fee or luck formula is used. The image generator's
sample names/rarities were corrected to the real catalog in Figma and code.

Use `UITheme.Studs` and the approved full-sheet image `rbxassetid://93331178043153`. Never rebuild individual studs. Merge icon `rbxassetid://122096168414414`; source, prompt, upload receipt and Studio screenshot are under `assets/merge-ui-20260925/`. Runtime portraits use the current shared ChickenPreview/ChickenPortraits assets rather than invented mockup chickens.

## Validation

The eight checks in `tests/MergeStandChecks.luau` pass in an isolated Studio runtime: exact triple and investment/save roundtrip, replay/legacy rejection, malformed/mismatched inputs, protected/away/capped birds, deployed-squad reserves, eligible grouping/extra copies/preview stats, atomic batch failure and disabled automation. Additional actual client/server checks verified same-plot/proximity enforcement, a 27→25 flock transaction retaining the upgraded ID, search and empty states, duplicate-click suppression, eight visible desktop cards in a 4×2 grid, and gate motion (21 parts, 3 cosmetic birds, full reset).

Five layout fixtures covered desktop, narrow portrait and short landscape sizes; grid sizes remained positive and the action stayed inside its panel. These are focused Studio checks, not a physical-device or multiplayer-network soak test. No publish, purchase, or saved-profile mutation. Local session-only test progress is discarded on Stop.


## September 27 verification

Six selection checks and all eight existing server transaction checks pass.
Seven disposable Roblox UI fixture checks cover remaining counts, search,
Remove, stale eligibility, duplicate taps, authoritative result values,
close/reopen, rejection, a real 12-second timeout followed by acknowledged Sync,
and five layout sizes (1000×870, 723×629, 390×720, 320×568, 700×320).
Fixtures create temporary UI under ServerStorage and remove it afterward; they
are not physical-device or network-soak tests.

An actual Studio session used the existing session-only test flag. The authored
prompt opened Fuse Chickens. Live server fusion consumed the exact staged trio,
retained the expected level-2 ID and reduced inventory by two. A second full flow
reached the result screen with Camo Chick, Lv. 2, 8→16 eggs/s and 10→12.5 DPS.
Search/ready/result screens were inspected; medium-window clipping was corrected.
Native gate animation is retained. Play stopped; Studio is back in Edit.

Source edits use Rojo. A duplicate, byte-identical MergeSelection created during
sync was preserved in ServerStorage.FuseFlowDuplicateRecovery20260927; one active
module remains. Six changed runtime modules compile and match local source.
Evidence: `assets/fuse-flow-20260927/`. No publish, purchase, real profile change,
egg-economy rebalance, camp gate or save schema change.

## Image-led visual revision verification

The final September 27 revision changes only `MergeBrowser` presentation and
Merge-specific `AppController` panel proportions. The saved transaction, selection
module, world gate and `MergePresentation` timing remain unchanged. Result labels
now show the resulting chicken's values, without repeating the before/after copy.

Six disposable UI checks pass: filtered counts/search/removal, stale eligibility,
duplicate taps and actual result values, close/reopen/rejection, plus layouts at
900×850, 746×705, 390×720, 320×568 and 700×320. Primary and slot controls retain
44-pixel minimum targets, with scrolling for short content. Both changed sources
compile and match Rojo's Studio Edit copy. Packaging build passes. Figma ready,
picker and result screenshots were inspected against the generated sheet.

Evidence: `assets/fuse-ui-image-first-20260927/`. The initial visual pass left the
user's separate Play session running. The follow-up implementation check started
fresh disposable sessions from Edit and exercised the actual authored prompt,
eligible picker, three staged inputs and authoritative fusion. Inventory went
6→4; the first staged Camo ID survived at level 2, the other two were consumed,
and the result showed 16 eggs/s and 12.5 DPS. Immediate repeat submission was
suppressed. `studio-result.jpg` records the completed flow; `studio-ready.jpg`
records the final portrait-spacing correction in a subsequent fresh session.
Final MergeBrowser source compiles and matches Studio through Rojo (26,976 bytes,
polynomial hash 4233590291). Test sessions were stopped; Studio is back in Edit.
No physical-device/network-soak test, persistent profile change, publication,
purchase or new Roblox asset upload was performed.

## Sectional garage animation verification

September 27 follow-up: `MergeGate` and `MergeStand` compile and match Studio through Rojo. The actual runtime machine has four moving sections (24 temporary pieces from 21 original parts); live samples confirm inward travel, 90-degree rotation and full concealment. Three cosmetic chickens entered, and the completion glow pulsed. Full-cycle, interrupted and repeated-celebration checks restored all original CFrames, transparency, collision, query and touch settings and removed temporary pieces/birds. Studio screenshots show the turn, fully open doorway and chickens entering. Evidence: `assets/fuse-garage-animation-20260927/`. The turning screenshot uses a slower diagnostic playback; the full cycle was checked at production timing. No new inventory transaction was needed for this presentation change. Play stopped; Studio is in Edit. Authored geometry and saved merge mechanics are unchanged.

The user then corrected the world sequence: the three inputs are already inside; only the resulting chicken should emerge. That correction supersedes the incoming-bird sequence above. Live checks confirm closed-door charging, one correctly leveled output, inward-to-outward travel (local Z 1.65→−1.75), level-10 doorway fit, full reset, interruption and repeated-fusion cleanup. `result-exiting.jpg` and `result-exit-checks.json` record this revision. MergeStand is 8,305 bytes, polynomial hash 3089724103, compiled and matched to Studio. The session was stopped; Studio is in Edit.
