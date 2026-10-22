# My Chicken Army — canonical editable scripts

This repository is the code source of truth starting with the September 24, 2026 Rojo migration. Read README.md and docs/CODE_MAP.md first. The legacy pet-roll-prototype tree under Documents/ChatGPT/RobloxGameIdeas is historical; do not copy its scripts over these files without comparing changes.

## Upgrade rule — never gate upgrades behind camps
October 4 starter-army opening supersedes the October 3 empty yard for fresh
profiles: start with three free level-1 `Duck` chickens, $2,400, three deployment
slots and no offer. The first free roll guarantees a level-1 fourth chicken for
$600. Reserve that recruit cost plus $1,200 for Army Size 4; each required
purchase may spend its own reserve in either order. Teach egg collection and
selling once, then expand/select four and deploy to Cluck Camp. Protect three
owned chickens before recruiting and four afterward until the guide completes.
Other upgrades use cash above the remaining reserve without camp/rank or
guide-step prerequisites. Skipping/rejoining does not release the reserve.
Existing profiles retain their flock, balance and saved tutorial cohort; legacy
`emptyStart` saves keep their earlier supported opening without bonus grants.
Contract: `docs/team/COMMANDER_TUTORIAL.md`.

All available cash upgrades are purchasable from the start when the player can afford them. Egg Speed, Egg Value, Plot Size, Army Size, Luck, Roll Slots and Selling Speed must not require visiting/conquering another camp, earning a rank, or reaching the King. This explicit September 25 user correction supersedes historical rank/camp gates in code, docs, tests and handoffs; never reintroduce them during UI work or balancing. Preserve configured track maxima, prices, server validation and physical plot/podium limits unless separately changed. Camp-route/King access and merge progression remain separate. Read `docs/UPGRADE_RULES.md` for the authoritative rule.

September 29 supersedes the seller requirements below: deposits pay immediately with the existing Money effect. Timed processing, Selling Speed and Finish Now are archived behind `EggProcessorConfig.Enabled=false`. All six boards and pre-change source copies live in `ServerStorage.EggProcessingArchive20260929`; local code backups are in `archive/egg-processing-20260929`. Preserve stored levels, finish credits and earned balances. Restore only on an explicit request; see `docs/team/INSTANT_EGG_SALES.md`. Other upgrade rules are unchanged.

September 27 exception: Selling Speed has no designed maximum level or processing speed. September 28 replaces the large opening tiers with small additive gains: start at 4 eggs/sec, add rounded 1.10^level per purchase, price at ceil(40 * 1.20^level). Use EggProcessorConfig.Rate/Price for every level. Saved level numbers remain unchanged and use the revised curve. Other upgrade maxima and physical limits are unchanged. Current contract: `docs/team/GRADUAL_SELLING_SPEED.md`; the September 27 curve is historical.

Later September 27 board review: Egg Speed and Egg Value have 25 purchases, Luck has 20 with smaller gains after level four, and Roll Slot prices rise steeply. Preserve their existing opening benefits and all owned slots. The approved smaller starter plot has 25 capacity and seven +5 purchases to 60. Revision 11 converts old plot levels 0–4 to 3–7 once, preserving existing capacity, footprint and next price; new profiles start at revision 11, level zero. See `docs/team/UPGRADE_BOARD_PROGRESSION.md`.

October 7 retune (user decision): cash Luck adds a flat +0.10 strength per level (the +0.35 opening levels are retired), and the rarity reset makes rarity follow the ten strength bands (rarer is always stronger; the basic Chicken leads fresh rolls at 28%). Catalog weights equal Luck-0 percent odds. October 8 owner decision: Egg Speed/Egg Value continuation growth is 1.6 (was 1.35) and chicken cash levels cost `ceil(recruit price × 0.75 × 2.5^(level−1))`, so cash tracks are no longer all maxed by day 3. The first four Speed/Value prices are unchanged. See `docs/team/UPGRADE_BOARD_PROGRESSION.md` and `docs/team/CHICKEN_CASH_UPGRADES.md`.

October 6 Luck replaces the flat Rare+ weight boost with a moving favored strength range. `shared/ChickenLuck.luau` owns fixed equivalent-stat band budgets, 10% baseline retention and continuous upward transport; `Rules` exposes odds/draw/window APIs. Cash levels/prices, research values and verified pass inputs remain. Every normal chicken stays possible; stronger-threshold odds must never decrease. Crate pools, forced starter/paid guarantees and Giant size odds remain separate. See `docs/team/LUCK_WINDOW.md` before changing Luck math or copy.

Latest September 29 Plot1 correction: start with a 30×30 square, extend a 30-stud-wide center, then open a wide back section into a T. After the user's deck enlargement, only stages 6–7 gain depth; maximum is a 30×49 stem plus 84×45 back section. Anchor the yard to its authored starter square so resizing the deck does not shift early stages. Both the yard and outer fence expand with purchases; the editor shows the square starter. Use the real T interior for roaming, eggs and vacuum routes, not its enclosing rectangle. Flock capacity now follows 25/30/35/40/45/50/75/100, superseding the historical 60 maximum above. Other plots retain existing footprints but share the new capacities. Preserve all seven prices, saved levels, deployed army limits and stationary props. See `docs/team/SQUARE_TO_T_PLOT_EXPANSION.md`.

September 29 Roll Slots supersede the old six-slot luxury ladder: support eight physically authored podiums, with prices $1,200 / $4,800 / $120,000 / $6M / $150M / $300M / $500M. The user's target is all eight after roughly 8–9 active F2P hours; this is initial model-based tuning, not a time gate or verified player duration. Fresh profiles start with one, missing-field legacy saves retain six, and all owned slots remain intact. See `docs/team/EIGHT_ROLL_PODIUMS.md`.

September 29 individual chicken upgrades: the simplified Army inspector buys levels with cash through level 10, without camp/rank prerequisites (`Config.Features.ChickenCashUpgrades=true`). Initial quote is 75% of the current-level recruit price. Preserve saved levels, real investment/refunds and earned sizes. Giant odds follow the October 14 Giants rule below. October 15: the owner briefly made Fuse the only leveling, then restored cash upgrades the same day with the old Rebirth costs (the simulation showed $1T+ Rebirths are unreachable without them); keep the switch on. Kept from that change: Fuse reaches Lv 10 without a camp-rank cap, roll offers come one level below the player's best of that species up to Lv 9, and the inspector's hint shows "Ready! Fuse 3…" when three match. See `docs/team/CHICKEN_CASH_UPGRADES.md` and `docs/MERGING.md`.

Edit code in this repository and sync with Rojo. Do not simultaneously write mapped scripts through Studio MCP; Rojo can overwrite those edits. Use Studio Flow for readback and asset work. Canonical Pet Roll Test place ID: 96683186622050. Check its identity and Edit state before connecting. Do not publish or push to a GitHub remote without user authorization.

September 29 single-screen-root correction: `StarterGui.PetRollGui` is the sole game ScreenGui template. The client reuses its PlayerGui clone and places HUD, menus, Settings, offline earnings, dialogue and drag previews under ordinary Frame containers. Do not create separate authoring/device preview ScreenGuis in StarterGui or additional runtime ScreenGuis. The seven old previews are preserved in `ServerStorage.UIAuthoringArchive20260929`. This template is Studio-owned; scripts-only Rojo builds do not include it. See `assets/ui-layout-example-20260929/README.md`.

September 30 native UI correction: preserve `PetRollGui.MenuLayouts` and its eight saved menu Frames. The restored `StarterGui.GUI.FRAMES` is the user's layout reference. All current menus/HUD/dialogue use Scale Size/Position, native UIAspectRatioConstraint and TextScaled, with native lists/scrolling for repeated content. This supersedes the fixed 1274×876 UIScale canvas, CompactSize/SizeLimits, per-device breakpoint and separate phone inspector rules. Army keeps four columns and an inline inspector; Fuse keeps three inputs. Matching menus use the reference proportions while preserving current game content/art/actions. MenuLayout copies the saved native properties; do not add scripted viewport sizing. Only generated Preview children may be rebuilt. See `docs/UI_EDITING.md`.

The map, rigs, assets, world settings, saved profiles and builder geometry remain Studio-owned. The default Rojo project owns only the existing named code containers and two bootstraps. Preserve `$ignoreUnknownInstances` and the place-ID allowlist. Do not load a scripts-only build over the existing place or treat it as a map backup.

Preserve the current relative module paths, internal PetRoll/Duck IDs and save compatibility. Server modules own state, money and transactions; client modules own input/presentation. No unrelated framework, file reshuffle or formatting pass. The user prefers quick PC iteration and small relevant checks over extensive suites.

October 15 "1 in X" rarity (owner decision): every rollable chicken shows its zero-Luck odds ("1 in 19,000") next to its rarity, and its price, income and power follow its own odds (`PetCatalog` RarityPrice/oneIn; Luck bands now live in `PetCatalog.LuckBands`, matched by `luckSignature`). Rarer chickens never earn less than their old tier value. A new **Secret** rarity covers 1 in 200,000 or rarer. The 11 original tier species keep their exact stats because enemies use them. See `docs/team/ONE_IN_X_RARITY.md`.

October 16 timed yard builds (owner decision "Option A"): Flock Size 25→30→35 stays instant; from Flock 40 up each expansion is paid up front and finishes after `UpgradeCatalog.PlotBuildSeconds` (2, 5, 10, 25, 60 min), one at a time, counting offline. Plot prices are unchanged. Saved `plotBuild` is additive and lenient. This is a build time, not a camp/rank gate. See `docs/team/TIMED_PLOT_BUILDS.md`.

## October 20 overhaul (supersedes older rules)
Details: `docs/team/OVERHAUL_PLAN_20261020.md` and `docs/team/OVERHAUL_CONTRACT_20261020.md`.
- **Upgrades tree:** instant Coins tiers (no camp/rank/King gate) replace the cash tracks and
  research, ending the Sep 27, Oct 7–8 and Oct 14 track lengths and prices, and the Sep 29
  Roll Slot prices (eight podiums stay). The Oct 6 Luck window math stays.
- **Rebirth** resets Coins to 0 (not 2,400; Time Skip then pays), Feed levels and the tree,
  except Keep Upgrades tiers and `mutationKeep`. Gems and Gem Upgrades never reset.
  Mutations (Golden, Rainbow, Shadow, Cosmic) are bought in the tree, not unlocked by rank.
  Oct 21 ladder (Stevin, after the pacing simulation: "more, not harder"): 50 ranks;
  Rebirth 1–20 unchanged, 21–30 grow x1.2 a rank (R30 51T, was 340T), 31–50 x1.12 a
  rank (R50 496T); enemy scale caps at rank 30 (x8); six Gem cards gained levels as the
  sink for ranks 26–50 (Coin Boost and Keep Upgrades unchanged). Never make the late
  ladder steeper again without re-running the login-model simulation:
  `docs/team/REBIRTH_PACING_20261021.md`. Later Oct 21 (P5, reference parity, fitted on
  the rarity retune): Rebirth 2 costs 1M like the reference (50K, 1M, 20M, 400M, 8B … 4.7T
  at 10, 384T at 30, 3.13e15 at 50) because in-run growth is tamed instead (Feed x1.6 eggs
  a level with x4 quotes, Egg Speed/Value III–IV and Flock 7–15 priced 25K–2B) and the egg
  multiplier gains x1.7 a rank on ranks 5–10 and x1.06 a rank after (x266 at 10, never
  below the old 1 + rank), see "reference-shaped ladder" in that doc.
- **Time Skip (Oct 22, Stevin: the Rebirth bonus "easily unlocks everything"):** it pays
  its minutes of the income the player has right after the Rebirth (no tree tiers past
  Keep Upgrades, no Feed levels, next rank's multiplier), never the end-of-run income.
  See "Time Skip" in `docs/team/REBIRTH_PACING_20261021.md`.
- **Flock** = chickens laying in the yard (only they lay, also offline), not the Sep 29
  25–100 capacity. Storage holds the rest (hidden cap 1,000); the **Army** is its own pick.
  Yard builds are instant (ends Oct 16 timed builds).
- **Tools:** the Egg Vacuum and Chicken Feed are bought in Upgrades > Tools and live in
  Roblox's native hotbar. Chicken levels need Feed, not the Sep 29/Oct 15 inspector
  button; Feed Max Level I–III lifts the cap to 20, +25% eggs per level past 10.
- **Fuse is removed** (ends Sep 25 merging, Sep 28 Colossals, Oct 6 Fuse research and
  Oct 14 Giants). Old Giants are ordinary chickens (saved size kept). Sell has its own menu.
- **Rolls:** Gold, Diamond and Prism rolls each count on their own; Rate I–IV halve the
  counts (10→5, 100→50, 500→250). Auto Roll and Auto Rebirth are Gem Upgrades.
- **Boosts:** Gold Rush (5 min every 20) and Friend Boost never apply to steady income
  (offline, daily, Playtime Coins). Playtime Rewards reset every join; their Free Rolls
  use lever Luck, Daily's use Hill-roll Luck.
- **Saves:** tier-meaning changes go through `TreeMigrations` (`upgradeTreeVersion`).
  Never bump `DataRevision`: older live servers reject newer revisions. Every publish
  uses "Migrate To Latest Update" (restart servers).
- **Tutorial (Oct 21, Stevin: Drop a Fruit style, "as SHORT as possible"):** eight
  lessons "TUTORIAL • n/8", only the essentials: click 3 eggs, sell, pull the lever,
  take the chicken (0 Coins), claim the Egg Vacuum (0 Coins), vacuum 20 eggs, sell them,
  then (later Oct 21, from his reference recording) go to Cluck Camp and send the Army:
  a short letterboxed march film (`MarchFilm`, SKIP) plays and the first camp win
  completes the guide. Flock Size I and Army Size I are not lessons
  and nothing instructs the player after the tutorial: no Next goals, no NEXT marker,
  no automatic Mission hints (only a Mission picked with GUIDE). No "FREE" wording anywhere. Menu lessons
  darken the screen around their control with a gold ring, and the egg lesson lights
  one egg with a tapping hand. This overrides the Oct 6 no-dimming/no-highlight rule
  for the guide; don't remove them. Contract: `docs/team/COMMANDER_TUTORIAL.md`.
- **Stevin:** "dont ask me for permission no more just do it". Agents decide and build
  without a confirm step, but still never publish or push unless asked.

## One egg is one egg (October 21, owner decision)
Each chicken lays one real egg every `Config.EggLaySeconds` (Egg Speed shortens it,
floor `EggMinLaySeconds`); the egg carries all the Coins earned since its last.
Stronger chickens lay more valuable eggs, never more eggs: every drop is stack 1,
and a full yard adds Coins to a waiting egg instead of a new one. Coins/sec are
unchanged. Never show stacked egg counts in the millions. See
`docs/team/ONE_EGG_VALUE.md` (supersedes the September 26 quantity economy).

## Voxel chickens only (October 21, owner decision)
Every chicken in the game is a voxel model from `ChickenAssets`. Never ship a chicken
that renders as the old round part-built `PetView` recipe (that is only the
scripts-only fallback). The October 20 "Veteran Corps" Rebirth chickens were
placeholders without models, so they are retired: no Rebirth grants, podium swaps or
Index entries, and the Rebirth Chicken Odds Gem Upgrade is refunded. Saved Veterans
load as the chicken whose stats they copied (`PetCatalog.RetiredSpecies`). A
chicken without its own template wears its `baseSpecies` voxel model
(`BlenderPetView`). New chickens need a voxel model before they enter the game.

## Auto Vacuum (October 21, owner request)
The retired Auto Collect robot is a Tools upgrade again: Auto Vacuum (20K Coins) opens
once the Egg Vacuum is owned (each run) and 5,000 eggs were vacuumed with it (saved
lifetime `vacuumedEggs`; later Oct 21, was 1,000),
then Auto Capacity/Range/Speed tiers. It sweeps the yard until its tank is full and
sells on the pad itself; its cargo goes to the bag whenever it goes away. This usage
unlock is the owner's explicit exception to "no gates"; check it on purchase only,
never on load. See `docs/team/AUTO_VACUUM.md`.

## Egg Vacuum capacity in eggs (October 21, owner request)
Stevin: the vacuum got "too large very easily" and was no challenge. It holds a fixed
`VacuumConfig.Capacity` (25 eggs; Oct 22, was 20) plus Vacuum Capacity tiers
(+15/35/65/125 at 1.5K, 25K, 3M, 100M, for 40/60/90/150) and the Gem card (+5 a level), never seconds of the Flock's laying, so
Flock Size and Egg Speed don't grow it. Range tiers are +3/+6/+10 studs (2.5K, 40K,
1.5M). The Auto Vacuum tank keeps its seconds model. See `docs/team/COLLECTION_TOOLS.md`.

## Game feel (October 21, owner request)
Stevin: every interaction, UI and world, is animated with VFX and sound, and
everything stays responsive on every device. Use the shared vocabulary, never a
private one: `UIMotion` (reveals, count-ups, floats, flyers, confetti, glows, bobs),
`ScreenFeel` (shake, flash, FOV punch; the camera stays with the player) and
`WorldFeel` (bursts, rings, poofs, sparkles, highlights, floating text, positioned
sounds), all budgeted and reduced-motion aware. Sound cues are named in the contract
and authored in `SoundService.MyChickenArmyAudio`; a missing cue is silent. One
emphasis per event; Scale geometry only; hover feedback always has a tap twin.
Contract: `docs/team/GAME_FEEL_20261021.md`.

## Rarity pacing (October 21, tester feedback through Stevin)
"Rare chickens way too fast; Luck maxed from the start; check the Playtime money." Luck
strength moves the favored range `ChickenLuck.ShiftPerDecade` (2.25) bands per x10 of
Luck (x3 = 1.07 bands, Legendary 3.7% a podium; x10 = 2.25, Legendary 8.6%), never the
old `9 (M − 1)/(M + 2)` curve that put Legendaries on 22% of podiums at Luck IV. Super
Luck is priced for Rebirth 2–5 (5M–2B) and Mega Luck for Rebirth 5–11 (10B–400B; x10
Luck at about 3.8 h nonstop or day 4–5 at 45 min a day on the P5 ladder).
Playtime Coins tiles pay 0.4 minutes of income per reference unit (21.4 min an hour, was
53.5) and are fixed when the tile unlocks. Base "1 in X" odds, chicken prices and the
free 4-second lever were left alone (the levers if ownership must slow too). Re-run
`tools/sim/rarity_probe.luau` and `odds_table.luau` before touching any of these:
`docs/team/RARITY_PACING_20261021.md`.

## Simple animations — use TweenService
When a simple animation can be expressed with a normal Roblox TweenService tween, use a tween. Use TweenInfo repeat/reverse settings for looping or back-and-forth motion. Do not build custom frame-by-frame interpolation, timing loops, springs, or animation frameworks for these cases. Keep cancellation and cleanup small. Use a more complex approach only when the requested behavior genuinely cannot be achieved with a tween, and explain why before expanding the implementation.

## Chicken icons — black stroke
For new illustrated icons, use the built-in image generator with
`/Users/stevin/.codex/skills/chunky-simulator-icons/SKILL.md` whenever applicable.
Tutorial arrows and destination text are white; generated pointer artwork has a
black outline. World routes use one attachment-driven Beam with native texture
scrolling, not repositioned arrow Parts. Latest October 6 direction removes all
tutorial highlighting: no viewport dimming, spotlight cutouts, pulsing target
borders or projected world overlays. Keep GUI pointers, destination markers,
native prompts and normal scene lighting. The Beam uses generated image
`rbxassetid://78163165437840`; reduced motion keeps it static. This supersedes the
earlier Roll/Recruit and Expand/Select spotlight requirements.

All chicken UI icons and portraits require a visible black stroke around the chicken silhouette, including new traits and rendered previews used as icons. Keep it consistent and unclipped; a card border is not a substitute. Follow the design workspace's DESIGN.md illustration contract. This is the user's September 27 reminder.

## Stud texture — mandatory image reuse
October 15 owner decision (supersedes the September full-sheet image): ALWAYS use the stud tile from the owner's `StarterGui.GUI.FRAMES` reference, uploaded Roblox image `rbxassetid://85697657610499` (a 4×4 block of beveled studs), for My Chicken Army stud patterns in Roblox UI and authored GUI art. Reuse `UITheme.Studs` (it tiles the image across one square ImageLabel inside a clipping `StudClip`, at the previous density of 24 studs per sheet, 80% transparent on surfaces and 88% on buttons, as the reference does). Never create or clone individual studs, per-stud Frames/Parts/vectors/rectangles/highlights or procedural stud grids. Keep labels and controls separately editable. If the image is unavailable, report the missing asset rather than recreating studs. The old sheet (`assets/ui/studs/stud-sheet.png`, `rbxassetid://93331178043153`) is retired; Figma screens still use it until updated. See `assets/ui/studs/README.md`.

Manual three-matching-chicken merging was explicitly enabled by the user on September 25; see `docs/MERGING.md`. The user rejected the earlier September 27 Figma visual execution (page 419:885, ready 421:1194); do not treat it as approved. The replacement follows the image-generated sheet under the design workspace's `assets/fuse-ui-image-first-20260927/`, with editable Figma page 434:885, ready 437:2024. Use compact input cards, substantial purple connectors, the native chicken picker and sparse copy. Preserve purple/full-sheet studs, black-purple body, server validation and saved merge stats. Do not infer new economy mechanics from reference screenshots. Paid Auto Merge remains separately disabled. Do not enable other dormant features merely because code is present. `tests/` is optional historical checks; `archive/` contains exported backup/library/plugin code and previous-local variants. Neither is in default sync.

October 14 Giants (owner decision; supersedes the September 28 "every fusion guarantees a Giant" and "size adds no bonus" rules): every fusion of three matching chickens is a +1-level merge, and has a `Giant.Chance(level)` chance to become a Giant, guaranteed after `Giant.PityLimit` fusions in a row without one (saved additive `giantPity`). A Giant input keeps the result a Giant; three Giants roll `ColossalFromGiantsChance` for a Colossal, otherwise a Giant. Later October 14 owner retune ("huge chickens must not be easy"): 3% + 0.5% per input level, pity 30, Colossal 10% (was 10% + 2%, pity 8, 25%). Same day: Golden mutation 1/250 (Rainbow 1/800, Shadow 1/3000, Cosmic 1/12000) with the Golden Emperor's glitter VFX, and Luck levels 5–20 use accelerating prices (Config `extendAcceleratingPrices`: ×1.57 rising to ×2.62 per level; L10 ≈ $67M, L20 ≈ $274B) so the early game stays easy and the top gets exponentially harder. Giants fight with ×2 health, ×1.5 damage and stomp splash (`Rules.Stats` giantSize argument); a standing Colossal adds +10% damage to its whole side. Existing saved Giants keep their size and the new perks. Fusion still costs 25% of one input's recruit price with the server quote; rarity still sets the visual size band; do not connect Giant odds to the cash Luck upgrade. See `docs/team/GIANT_CHICKEN_DESIGN.md` and `src/shared/GiantChicken.luau`.

Latest September 28 clarification: only chickens with saved `giantSize >= 20` are **Colossal**. Allow at most one Colossal per player's selected/deployed army; smaller Giants use ordinary slots without a special cap. Since October 14, Colossals come only from fusing three Giants (25%, biased toward 20 studs); single fusions never roll 20+. Preserve earned sizes and owned chickens, including old large low-rarity birds; re-fusion with a Colossal input retains it. Enforce the slot in server selection, Select Best, saved lineups and battle replacements, not only UI. The inventory offers Replace Colossal; a deployed replacement waits for the retiring Colossal to return.

October 6 Fuse Machine research replaces the October 5 Cluck Camp unlock. New
access requires completed `FuseMachine` research ($5,000, 120 base seconds,
Lucky Feathers I (`R1`) prerequisite since October 9, Army branch). Locked use shows the normal Error notice:
"Unlock the Fuse Machine in Upgrades first." Preserve earned access through
`fusionUnlocked` and versioned save migration (`fusionUnlockVersion=2`); mark its
research complete for legacy owners without charging. New camp wins must not
grant fusion, even after rejoin. Cash upgrades remain independent. See
`docs/MERGING.md`.

One writer per file. For parallel tasks, assign explicit files and contracts. Workers do not control canonical Studio, Blender, Git history or further agents; the root integrates. Keep changes scoped and preserve user work.

Before editing or syncing, inspect Git and compare any unsynced Studio changes. Record local commits, Roblox saves/publishes and player-data changes separately. A Rojo build verifies packaging, not Luau runtime correctness. Do not claim checks that were not run.

## Player-facing words (October 14)
Use one name per concept in every player-facing string: Army, Flock, chickens, Camp
(home is "base"), Coins, Fuse, Upgrades (the tree screen), Missions (October 14, replaced Invasions), "Rebirth N", and
Should win / Close fight / Very tough. Never pets, cash/"$", merge, squad/troops,
Operations or device-specific "Press E"/"Tap". Internal ids stay. Menus open through
`AppController:CloseOtherMenus` so only one shows at a time. See
`docs/team/UX_AUDIT_FIXES_20261014.md`.

October 20 owner decision (supersedes "Cash" above): the earned currency is gold
**Coins**. Show the gold coin image beside a number where it fits (HUD, shop, research
costs, podium tags, receipts, pop-ups) and "1,200 Coins" in words elsewhere; never "$".
Use `CurrencyLimits.Text/Rate` on the server and `UITheme.Coins/CompactCoins/CoinAmount`
on the client. Coin amounts are gold (`UIColors.Coins`). Saved `coins`, prices, product
IDs, analytics names and internal `Cash*` ids are unchanged; "cash" in older rules and
docs means Coins. Robux stays "R$". See `docs/team/GOLD_COINS.md`.

## Mission territories (October 15, owner decision)
Mission sites last 15 minutes and are guarded only by their own enemy-only Loyalist
chickens (`PetCatalog.Loyalists`, never rollable/ownable/indexed). A win stations the
army under a flag; other players may take it. Leaving early lowers the flag and the
guards return; after 15 minutes a site leaves as soon as no player holds it. Conquest
pays once per player per site; holding adds a small egg-value percentage
(`Config.Territories.MissionBonus`). See `docs/team/MISSION_TERRITORIES.md`.
Later October 15 owner decision (supersedes the stationing above): a won site
disappears at once, like before, and the army walks home. No flag, holding,
contests or hold bonus; Loyalist guards and the 15-minute life remain.

## My Army grid (October 21, owner)
My Army copies the owner's reference "Pets" window 1:1 (art in our style): one grid,
Army checked and first, hover tooltip, click detail card, Equip Best / Unequip All,
lock and sell modes with Confirm, two sorts, compact, search. Its size was measured
from his recording (960 x 557 units = 55.6% x 51.4% of the screen,
`MenuLayouts.MyArmyGrid`); keep elements in those units with Scale only. The Flock is
never picked: it is always the best egg layers and a layer away with the Army is
filled by the next best at home. See `docs/team/ARMY_GRID.md`.

## Chicken UI Lab (October 15)
The owner tweaks UI in the Studio plugin (`tools/ui-lab`, guide `docs/UI_LAB.md`) and
saves change lists to `ServerStorage.UILab.Tweaks`. "Apply my UI Lab tweaks" means:
read records with `Status=new`, carry each change into the source that builds it,
re-render the story, then set `Status=applied`. Add a story in
`src/server/UIAuthoring/LabStories.luau` when a new screen ships.
October 15 owner rule: ONE UI layout for every device. Do not branch positions or
sizes on PreferredInput/TouchEnabled (input-specific hint text such as "Tap"/"Press"
is fine). An owner tweak made on any device applies to all of them.

## Voxel eggs (October 20, owner request)
Every ownable chicken lays its own real 3D voxel egg (owner rejected the image pass):
`EggView` clones the Studio-owned MeshPart template
`ReplicatedStorage.PetRoll.Assets.EggMeshes[species]` (Duck fallback; a child `Glow`
Neon part and Legendary+ `Sparkle` emitter ride along). Mesh origin = egg bottom
centre. Keep one or two parts per egg: no welds, lights, Highlights or per-egg tweens.
The baked images in `src/shared/EggArt.luau` are only the scripts-only fallback.
New chickens need a recipe in `assets/voxel-eggs-20261020/` and a mesh build; save the
place after rebuilding templates. See `docs/team/VOXEL_EGGS.md`.

## Reference vault (October 13)
UI references, games studied, idea notes and the dev journal live in the Obsidian vault `~/Documents/ObsidianVaults/Roblox-Journal/` (read its `AGENTS.md`). Before UI work, check `UI References/` for the matching `screen:`. Vault notes are inspiration only; this repo's rules win.

## Analytics (October 9) — observation only
Funnels, economy, retention and health go to Roblox AnalyticsService (live only) and an agent ledger in DataStores (`PetRollAnalytics_v1`, Studio uses `_Studio`). Names live in `src/server/AnalyticsSchema.luau`; append only, never rename/reorder, bump `Schema.Version`. For any stats question read `docs/analytics/AGENT_GUIDE.md` and run `AnalyticsReport` from Studio Edit. Analytics must never change gameplay.

## Save compatibility: never invalidate earned progress (October 9)
Changing catalogs (research prerequisites, removed nodes or species) must never make an existing save fail to load; enforce new rules when the player acts, not in `LoadData`/`*.Read`. A rejected load kicks the player ("This save needs recovery"). See `docs/team/RESEARCH.md`.
