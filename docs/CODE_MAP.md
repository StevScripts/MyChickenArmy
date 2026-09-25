# Where to edit

Start with the feature table below. The migration keeps the existing ModuleScripts and runtime hierarchy; it does not introduce a framework or rename the game's internal IDs.

All available cash upgrades are independent of camp/rank progress. [UPGRADE_RULES.md](UPGRADE_RULES.md) is the current eligibility contract; never reinstate historical conquest gates when editing offers or UI.

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
| UI palette and shared controls | `shared/UIColors.luau`, `client/UITheme.luau` | Colors, typography and reusable component styling |
| Army inventory and chicken selling | `client/ChickenBrowser.luau` | Cards, selection and confirmation; `server/ArmyService.luau` validates transactions |
| HUD and menu navigation | `client/HudController.luau`, `client/AppController.luau` | HUD rendering and page/controller coordination; [responsive layout and device checks](UI_RESPONSIVE.md) |
| Upgrades menu | `client/ProgressionBrowser.luau` | Presentation of server-provided upgrade prices and eligibility |
| Shop and Index | `client/ShopBrowser.luau`, `client/IndexBrowser.luau` | Shop cards and collection discovery; `shared/ShopCatalog.luau` defines commerce catalog |
| Starting coins, squad limits, upgrade prices | `shared/Config.luau` | `StartingCoins`, `StartingSlots`, `SlotUnlocks`, `IncomePrices`, `LuckPrices` |
| Chicken stats, recruit prices and odds | `shared/PetCatalog.luau`, `shared/Rules.luau` | Species definitions and shared calculations; `server/RollService.luau` creates and purchases offers |
| Camp progression and encounter rosters | `shared/Progression.luau` | Main camps, rank milestones and King access; does not gate cash upgrade purchases |
| Damage, capture phases and respawn timing | `server/Battle.luau` | Active encounter state; timing/ranges are in `shared/Config.luau` |
| Camp ownership and prerequisite routing | `server/BattleService.luau`, `shared/CampaignRoute.luau` | Which objective can be reached, occupied or released |
| Marching and reinforcements | `shared/ArmyMarch.luau`, `server/ArmyReinforcements.luau` | Routes and lineup changes; `server/PetActor.luau` owns physical actor movement |
| Idle guards and Chicken King | `server/WorldService.luau`, `server/KingArena.luau` | Patrol lifecycle; `server/IdlePatrol.luau` is the movement helper, `server/KingEncounter.luau` defines the encounter |
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

Merging remains in `ArmyService`, `MergeStand`, `MergeBrowser` and `MergePresentation`, but release availability is gated by `Config.Features.Merging`. A retained module is not proof that a feature is enabled. Crate and legacy UI helpers may likewise be dormant. Check where a module is required and which feature flag enables it before changing it.

Archived/editor/plugin scripts and optional tests are not normal startup code. The map, imported rigs, textures and other Studio-owned assets are intentionally outside this code map. See [EDITING.md](EDITING.md) for sync, save and Git workflows.
