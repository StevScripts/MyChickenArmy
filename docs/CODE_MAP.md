# Where to edit

Start with the feature table below. The migration keeps the existing ModuleScripts and runtime hierarchy; it does not introduce a framework or rename the game's internal IDs.

All available cash upgrades are independent of camp/rank progress. [UPGRADE_RULES.md](UPGRADE_RULES.md) is the current eligibility contract; never reinstate historical conquest gates when editing offers or UI.

Egg rarity now scales quantity, with one upgrade-defined value for every new egg.
[EGG_ECONOMY.md](EGG_ECONOMY.md) owns the formulas, batching, seller tuning and
earned-balance compatibility contract; start in shared `Rules` and server `EggService`.

## Source → Studio

| Source folder/file | Studio destination |
|---|---|
| `src/server/*.luau` | `ServerStorage.PetRoll` ModuleScripts |
| `src/client/*.luau` | `StarterPlayer.StarterPlayerScripts.PetRoll` ModuleScripts |
| `src/shared/*.luau` | `ReplicatedStorage.PetRoll.Shared` ModuleScripts |
| `src/animations/*.luau` | `ReplicatedStorage.PetRoll.ChickenClips` ModuleScripts |
| `src/bootstraps/PetRollBootstrap.server.luau` | `ServerScriptService.PetRollBootstrap` |
| `src/bootstraps/PetRollClient.client.luau` | `StarterPlayer.StarterPlayerScripts.PetRollClient` |

Files ending in `.server.luau` become Scripts; `.client.luau` become LocalScripts; ordinary `.luau` files become ModuleScripts. The server bootstrap starts `GameServer`; the client bootstrap starts `AppController`.

## Find a feature

Paths below are relative to `src/`. Search for the named symbol in VS Code with **Cmd+P** for files or **Cmd+Shift+F** for code.

| Change | Start here | What it owns |
|---|---|---|
| Roll zoom strength, duration and easing | `client/RollPresentationController.luau` | `ROLL_ZOOM_*` constants, `StartCameraZoom`, `ReturnCameraZoom`; presentation only |
| Rolling shuffle, reveal and lever feel | `client/RollPresentationController.luau` | `BEATS`, visual timing and sound cues; `shared/Config.luau` supplies `RollRevealSeconds` |
| Menu hover, press, open and pop animations | `client/UIMotion.luau` | Reusable tweens; start with `BindButton`, `Pop` and `Tween` |
| Sound asset IDs and audio playback | `SoundService.MyChickenArmyAudio`, `client/AudioController.luau` | Edit native SoundId properties in Studio; [audio folders and editing guide](AUDIO.md). Client handles playback, mute, spatial parents and cleanup. |
| UI palette and shared controls | `shared/UIColors.luau`, `client/UITheme.luau` | Colors, typography and reusable component styling |
| Edit menu sizes in Studio | `client/MenuLayout.luau`, `server/UIAuthoring/` | Saved Frames under `StarterGui.PetRollGui.MenuLayouts`, native Scale/aspect properties, manual previews, four-column Army and Index portrait sizing. [Editing controls](UI_EDITING.md). |
| Chicken fusion | `client/MergeBrowser.luau`, `client/MergeSelection.luau` | Three-slot staging, chicken picker and result; `server/ArmyService.luau` validates exact triples and cash; `shared/Rules.luau` owns MergePrice, `server/MergeStand.luau` binds the authored machine and `server/MergeGate.luau` owns its sectional garage animation. [Current fuse contract](MERGING.md) |
| Giant chicken sizes | `shared/GiantChicken.luau`, `shared/ChickenGrowth.luau` | Guaranteed fusion Giants, 4–27.5-stud rarity bands; fresh 20+ Colossal chance 1% Legendary / 3% Mythic. Uniform art scale with ordinary walking collision; `server/PlayerSession.luau` saves the size. [Giant contract](team/GIANT_CHICKEN_DESIGN.md) |
| One Colossal per army | `server/PlayerSession.luau`, `server/ArmyService.luau`, `server/ArmyReinforcements.luau` | Filters automatic/saved lineups, validates manual selections, waits for the retiring Colossal before a replacement deploys; `client/ChickenBrowser.luau` offers Replace Colossal. Smaller Giants use normal slots. |
| Army inventory, cash leveling and chicken selling | `client/ChickenBrowser.luau` | Cards, selection, Upgrade button and sale confirmation; `server/ArmyService.luau` validates transactions, `shared/Rules.luau` owns ChickenUpgradePrice. [Cash upgrade contract](team/CHICKEN_CASH_UPGRADES.md) |
| HUD and menu navigation | `client/HudController.luau`, `client/AppController.luau` | HUD rendering and page/controller coordination; [responsive layout and device checks](UI_RESPONSIVE.md); [Example hierarchy study](../assets/ui-layout-example-20260929/README.md) |
| Call Army / My Base commands | `server/ArmyCommandService.luau`, `server/BattleService.luau`, `server/PetActor.luau` | Selected squad following, encounter withdrawal and full home teleport; HUD sends server-validated commands. [Contract](team/ARMY_COMMANDS.md) |
| Smooth following motion | `shared/FollowMotion.luau`, `server/PetActor.luau` | Continuous server-owned steering, velocity matching, formation turns and arrival; [research, tuning and checks](team/SMOOTH_FOLLOWING.md). |
| Cash upgrades in the full-screen tree | `client/CashUpgradeNodes.luau`, `client/ResearchBrowser.luau`, `server/UpgradeService.luau` | Six branches with 91 individual cash purchase tiers, interleaved with research. U/R open the same Start. Physical board archived; `ProgressionBrowser` is historical. [Contract](team/CASH_UPGRADES_IN_TREE.md). |
| Full-screen research tree | `shared/ResearchCatalog.luau`, `server/ResearchService.luau`, `client/ResearchBrowser.luau` | Timed research, saved completion and native full-screen hex map; [contracts and current validation status](team/RESEARCH.md). |
| Research actions and Operations | `server/ArmyAbilities.luau`, `server/OperationService.luau`, `shared/OperationCatalog.luau`, `client/ResearchExtras.luau` | Rally, saved formations, finite challenge arenas and completion rewards. `ArmyService` retains formation selection authority. |
| Shop and Index | `client/ShopBrowser.luau`, `client/IndexBrowser.luau` | Shop cards and collection discovery; `shared/ShopCatalog.luau` defines commerce catalog |
| Starting coins, squad limits, upgrade prices | `shared/Config.luau` | `StartingCoins`, `StartingSlots`, `SlotUnlocks`, `IncomePrices`, `LuckPrices` |
| Chicken stats, recruit prices and odds | `shared/PetCatalog.luau`, `shared/Rules.luau` | Species definitions and shared calculations; `server/RollService.luau` creates and purchases offers |
| Camp progression and encounter rosters | `shared/Progression.luau` | Main camps, rank milestones and King access; does not gate cash upgrade purchases |
| Damage, capture phases and respawn timing | `server/Battle.luau` | Active encounter state; timing/ranges are in `shared/Config.luau` |
| Camp ownership and prerequisite routing | `server/BattleService.luau`, `shared/CampaignRoute.luau` | Which objective can be reached, occupied or released |
| Marching and reinforcements | `shared/ArmyMarch.luau`, `server/ArmyReinforcements.luau` | Routes and lineup changes; `server/PetActor.luau` owns physical actor movement |
| Idle guards and Chicken King | `server/WorldService.luau`, `server/KingArena.luau` | Patrol lifecycle; `server/IdlePatrol.luau` is the movement helper, `server/KingEncounter.luau` defines the encounter |
| Instant egg selling / archived processor | `server/EggService.luau`, `shared/EggProcessorConfig.luau` | Deposits pay immediately; `Enabled=false` suspends timed selling, board UI and new Finish Now purchases. [Archive and restoration](team/INSTANT_EGG_SALES.md) |
| Eggs: production, collection and deposits | `server/EggService.luau` | Authoritative egg state; frequency/radius in `shared/Config.luau`; collection visuals in `client/EggController.luau`, `client/EggView.luau`, `shared/EggMotion.luau` |
| Egg vacuum: sweep, cargo and animation | `server/EggRover.luau`, `shared/VacuumConfig.luau`, `client/VacuumController.luau` | [Vacuum tuning and Blender workflow](VACUUM.md); exported motion in `shared/VacuumClips.luau` |
| Kill rewards | `shared/CombatRewards.luau`, `server/BattleService.luau` | Reward calculation and server award boundary |
| Offline cash and welcome-back receipt | `shared/OfflineCashConfig.luau`, `server/OfflineCash.luau`, `server/DataService.luau`, `client/OfflineCashController.luau` | [Rate, cap, persistence and verification](OFFLINE_CASH.md); the server saves cash before the client displays its receipt |
| Chicken appearance, portraits and animation | `shared/ChickenAppearanceAssets.luau`, `client/ChickenPortraits.luau`, `client/VoxelChickenAnimator.luau` | Asset references, menu images and clip playback; clip data lives in `animations/` |
| Native proximity prompts and attack highlight | `client/BaseController.luau`, `client/PromptStyleController.luau` | Local visibility/style; `shared/CampCommand.luau` supplies command rules |
| World bindings for the builder's map | `server/AuthoredMap.luau`, `server/AuthoredPlot.luau` | Bind Studio-owned geometry into runtime systems; these are not replacements for the authored map |

## The short architecture

```text
Client input / menu
    → GameServer request validation
    → RollService / ArmyService / BattleService / EggService
    → PlayerSession authoritative state
    → snapshots back to client controllers
```

The server decides coins, ownership, purchases and combat results. Client controllers handle input, animation and display. Shared modules supply definitions, calculations and rendering helpers; being in `shared/` does not make a client result authoritative.

`PlayerSession` owns the in-memory profile and snapshot. `DataService` owns persistent loading/saving and session ownership. `ProductService` owns developer-product receipts; `CommerceService` verifies purchase eligibility and pass benefits. Keep these boundaries when adding features.

## Code retained for later

Manual three-chicken merging is enabled in `ArmyService`, `MergeStand`, `MergeBrowser` and `MergePresentation` through `Config.Features.Merging`; the separately gated paid `AutoMerging` feature remains off. See `MERGING.md`. A retained module is not proof that a feature is enabled. Crate and legacy UI helpers may likewise be dormant. Check where a module is required and which feature flag enables it before changing it.

Archived/editor/plugin scripts and optional tests are not normal startup code. The map, imported rigs, textures and other Studio-owned assets are intentionally outside this code map. See [EDITING.md](EDITING.md) for sync, save and Git workflows.
