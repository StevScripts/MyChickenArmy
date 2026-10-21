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
| Roll camera: shuffle push-in, reveal pop, flash, speed lines, shake | `client/RollCamera.luau` | Knobs at the top (S20's calm pass): `PUSH_DEGREES` (11.5), the per-rarity `REVEAL` table (pop degrees, glide-back seconds, flash, speed lines, shake from Legendary up), `SNAP_SECONDS`, the easings and `AUTO_STRENGTH` (Auto Roll). TweenService only; the camera stays with the player (no orbit). `client/RollPresentationController.luau` decides when a roll counts. |
| Rolling shuffle, reveal and lever feel | `client/RollPresentationController.luau` | `BEATS`, visual timing and sound cues; `shared/Config.luau` supplies `RollRevealSeconds` |
| Auto Roll and Gold/Diamond/Prism rolls | `server/RollService.luau`, `shared/AutoRollRules.luau`, `client/AutoRollMenu.luau`, `shared/GoldRolls.luau`, `server/RollStation.luau` | `RollService:StepAuto` runs Auto Roll (a Gem Upgrade) from anywhere; saved stop rows, the panel and the hit banner; each machine's own pull count (`Config.GoldRolls`) and its "N Rolls Left" counter. [Contract](team/AUTO_ROLL.md) |
| Menu hover, press, open and pop animations | `client/UIMotion.luau` | Reusable tweens; start with `BindButton`, `Pop` and `Tween` |
| Game feel: reveals, count-ups, floats, flyers, confetti, glows; camera shake/flash/zoom; world bursts, rings, floating text | `client/UIMotion.luau` (bottom section), `client/ScreenFeel.luau` (`app.screenFeel`), `client/WorldFeel.luau` (`app.worldFeel`), `client/AudioController.luau` (`Has`, `PlayAt`, `pitchVariance`) | The October 21 shared vocabulary every screen and world system uses; budgets and reduced motion live in the helpers. Sound cues are named in the contract. [Contract](team/GAME_FEEL_20261021.md) |
| Sound asset IDs and audio playback | `SoundService.MyChickenArmyAudio`, `client/AudioController.luau` | Edit native SoundId properties in Studio; [audio folders and editing guide](AUDIO.md). Client handles playback, mute, spatial parents and cleanup. |
| UI palette and shared controls | `shared/UIColors.luau`, `client/UITheme.luau` | Colors, typography and reusable component styling |
| Edit menu sizes in Studio | `client/MenuLayout.luau`, `server/UIAuthoring/` | Saved Frames under `StarterGui.PetRollGui.MenuLayouts`, native Scale/aspect properties, manual previews, four-column Army and Index portrait sizing. [Editing controls](UI_EDITING.md). |
| Selling chickens (Sell screen); Fuse removed | `client/SellMenu.luau`, `server/ArmyService.luau` | My Army's Sell opens it (`AppController:OpenSell`): bulk-select the chickens the server marks `canSell`, confirm "Sell N Chickens?", then one `Sell {petIds, expectedTotal}` that `ArmyService.Sell` checks as a batch. Fuse's code is in `archive/fuse-20261020/`. [Contract](team/FUSE_REMOVAL_AND_SELL.md) |
| Old Giants and Colossals (retired) | `server/PlayerSession.luau`, `shared/GiantChicken.luau`, `shared/ChickenGrowth.luau` | A saved `giantSize` loads as `pet.retiredGiantSize` and saves back unused, so these play as ordinary chickens (no size, perks or Colossal limit). `GiantChicken` keeps `PityLimit`, size predicates and combat constants for older readers; `ChickenGrowth.Apply` ignores size. [Contract](team/FUSE_REMOVAL_AND_SELL.md) |
| My Army: the reference Pets grid | `client/ChickenBrowser.luau`, `client/MenuLayout.luau`, `server/ArmyService.luau`, `server/PlayerSession.luau` | One grid of every chicken (Army checked and first), hover tooltip, detail card (Equip/Unequip, Lock), Equip Best / Unequip All, lock and sell modes with a Confirm bar, two sorts, compact grid, search; sized from the owner's recording (960 x 557 units, `MenuLayouts.MyArmyGrid`). The Flock is always the best layers (`FlockIds`/`LayingIds`, no picks); `ArmyService.Favorite` locks in batches. [Contract](team/ARMY_GRID.md) |
| HUD and menu navigation | `client/HudController.luau`, `client/AppController.luau` | HUD rendering and page/controller coordination; [responsive layout and device checks](UI_RESPONSIVE.md); [Example hierarchy study](../assets/ui-layout-example-20260929/README.md) |
| Commander Cluck tutorial | `shared/TutorialGuide.luau`, `client/CommanderGuide.luau`, `client/GuideFocus.luau`, `client/GuideArrow.luau`, `server/TutorialService.luau` | Snapshot-derived objectives, native guide card, GUI pointers and world Beam/marker guidance without highlighting, saved skip/resume, server-confirmed milestones and sparse analytics. BaseController owns the local attachment-driven world Beam. [Tutorial contract](team/COMMANDER_TUTORIAL.md) |
| First-visit intro cutscene | `client/IntroCutscene.luau` | Wordless story for new starter-army profiles, hooked from `LoadingController` as the veil fades, and the Cluck Camp payoff. `server/TutorialService.luau` saves `introSeen`. [Intro contract](team/INTRO_CUTSCENE.md) |
| First-time Hill film and Hill VFX | `client/HillIntro.luau`, `server/HillService.luau` | The 10-second "The Hill is open!" film, once per player: `HillService.IntroDue` marks the round (`state.hill.intro`) and `server/TutorialService.luau` saves `tutorial.hillIntroSeen` as it starts. Round VFX come from the Studio-owned `ReplicatedStorage.PetRoll.Assets.HillVFX`. [Contract](team/KING_OF_THE_HILL.md) |
| Call Army / My Base commands | `server/ArmyCommandService.luau`, `server/BattleService.luau`, `server/PetActor.luau` | Selected squad following, encounter withdrawal and full home teleport; HUD sends server-validated commands. [Contract](team/ARMY_COMMANDS.md) |
| Smooth following motion | `shared/FollowMotion.luau`, `server/PetActor.luau` | Continuous server-owned steering, velocity matching, formation turns and arrival; [research, tuning and checks](team/SMOOTH_FOLLOWING.md). |
| Upgrades tree (tree v2) | `shared/UpgradeCatalog.luau`, `client/ResearchBrowser.luau`, `client/CashUpgradeNodes.luau`, `client/ResearchAssets.luau`, `server/UpgradeService.luau` | The catalog holds families, tiers, flat-top hex cells (`walk` steps) and per-tier names/icons (`labels`); ResearchBrowser draws the maps, card and input (`Browser.Grid`); CashUpgradeNodes gives next nodes and card lines (`NextId`, `Lines`); ResearchAssets maps each catalog `icon` key to an image (`Assets.upgrades`); UpgradeService sells instant `BuyUpgrade` tiers and owns prices and badges. Research is retired (`ResearchCatalog`/`ResearchService` only read old saves). [Screen](team/UPGRADES_SCREEN.md), [contract §4](team/OVERHAUL_CONTRACT_20261020.md) |
| What a saved tree tier means | `server/TreeMigrations.luau`, `server/PlayerSession.luau` | One step per change in meaning, run once on load by `upgradeTreeVersion`. Add a step and bump `Version` in the same commit; never edit a released step or bump `Config.DataRevision`. Revision ≤ 11 saves convert once in `server/EconomyMigration.luau`. [Contract §2](team/OVERHAUL_CONTRACT_20261020.md) |
| Rebirth and Gem Upgrades | `server/RebirthService.luau`, `server/GemUpgradeService.luau`, `shared/GemUpgradeCatalog.luau`, `server/RebirthChickens.luau`, `client/RebirthPanel.luau`, `client/GemUpgradeGrid.luau` | Rebirth quote, reset manifest, rewards (Gems, Time Skip, Rebirth chicken), Skip credits and Auto Rebirth; Gem Upgrade buys; the Rebirth screen and its Gem Upgrades grid (the only Gems readout). Costs are in `Config.Rebirth`. [Screen](team/REBIRTH_SCREEN.md), [contract §6–7](team/OVERHAUL_CONTRACT_20261020.md) |
| Research actions and Operations | `server/ArmyAbilities.luau`, `server/OperationService.luau`, `shared/OperationCatalog.luau`, `client/ResearchExtras.luau` | Rally, saved formations, finite challenge arenas and completion rewards. `ArmyService` retains formation selection authority. |
| Shop and Index | `client/ShopBrowser.luau`, `client/IndexBrowser.luau` | Shop cards and collection discovery; `shared/ShopCatalog.luau` defines commerce catalog |
| Starting flock, coins and squad limits | `shared/Config.luau` | `StarterFlock`, `StartingCoins`, `StartingSlots`. Upgrade prices are in `shared/UpgradeCatalog.luau`; Config's `SlotUnlocks`, `IncomePrices` and `LuckPrices` are the pre-October 20 tracks, kept for old saves |
| How Coins read (gold coin icon, "1,200 Coins", gold color) | `shared/CurrencyLimits.luau`, `client/UITheme.luau` | `Currency.Text/Rate/Icon`, `Theme.Coins/CompactCoins/CoinIcon/CoinAmount`, `UIColors.Coins`. [Gold Coins contract](team/GOLD_COINS.md) |
| Gold Rush and Friend Boost | `server/GoldRushService.luau`, `client/GoldRushController.luau`, `server/FriendBoostService.luau`, `client/FriendBoost.luau` | 2x Coins for 5 minutes every 20 on one wall clock, with the gold sky and chip; +10% Coins per friend in the server (max +50%). Both apply once in `PlayerSession:EarnedAmount`, never to steady income. [Contract](team/GOLD_RUSH_FRIEND_BOOST.md) |
| Chicken stats, recruit prices and odds | `shared/PetCatalog.luau`, `shared/Rules.luau` | Species definitions and shared calculations; `server/RollService.luau` creates and purchases offers |
| Moving Luck window | `shared/ChickenLuck.luau` through `shared/Rules.luau` | Fixed equivalent-stat band budgets, continuous upward probability movement, nonzero normal roster and monotone strength thresholds; shared cash/research/pass inputs. [Contract](team/LUCK_WINDOW.md) |
| Starter army and opening protection | `server/PlayerSession.luau`, `server/RollService.luau`, `shared/TutorialGuide.luau` | Fresh `starterArmy` profiles get three free level-1 Ducks and $2,400, then roll a guaranteed $600 fourth recruit. PlayerSession reserves the recruit cost plus $1,200 for Army Size 4; cash purchase paths honor each remaining earmark. ArmyService protects three birds before recruiting and four afterward until guide completion. The guide teaches one collect/sell pass, then expand/select/deploy. Existing saves and legacy `emptyStart` cohorts receive no new grants. [Contract](team/COMMANDER_TUTORIAL.md) |
| Camp progression and encounter rosters | `shared/Progression.luau` | Main camps, rank milestones and King access; does not gate cash upgrade purchases |
| Damage, capture phases and respawn timing | `server/Battle.luau` | Active encounter state and received-damage serials; timing/ranges are in `shared/Config.luau`. `client/BattleController.luau` owns the red TweenService hit highlight; `client/CombatEffects.luau` adds feathers, hit sparks, damage numbers, knockout poofs and fight sounds. [Hit feedback](team/CHICKEN_HIT_FEEDBACK.md) |
| Chicken and guard health bars | `shared/PetView.luau`, `shared/KingVisual.luau` | Shared outlined bar and current/max HP; King sizing. `server/LiveBattleActors.luau` supplies authoritative unit HP; `BattleController` retains fight-only visibility. [Health-bar contract](team/HEALTH_BARS.md) |
| Camp ownership and prerequisite routing | `server/BattleService.luau`, `shared/CampaignRoute.luau` | Which objective on which lane can be reached, occupied or released. [Any-lane attacks](team/ANY_LANE_ATTACKS.md) |
| Conquest meter, owned labels and unclaim | `server/Battle.luau`, `server/BattleService.luau`, `shared/ConquestPresentation.luau` | Continuous ordinary conquest (12/20/25s by route camp, 25s King) during combat, persistent claims and immediate explicit release. `BattleController` renders the four-section meter; `WorldBuilder`/`WorldService` own camp labels; `ActionFeedback` owns victory VFX; `BaseController` keeps native action prompts clear of combat. [Recording contract](team/CONQUEST_REFERENCE.md) |
| Marching and reinforcements | `shared/ArmyMarch.luau`, `server/ArmyReinforcements.luau` | Routes and lineup changes; `server/PetActor.luau` owns physical actor movement |
| Idle guards and Chicken King | `server/WorldService.luau`, `server/KingArena.luau` | Patrol lifecycle and transfer of existing guards into battle without repositioning; `server/IdlePatrol.luau` is the movement helper, `server/KingEncounter.luau` defines the encounter |
| Instant egg selling / archived processor | `server/EggService.luau`, `shared/EggProcessorConfig.luau` | Deposits pay immediately; `Enabled=false` suspends timed selling, board UI and new Finish Now purchases. [Archive and restoration](team/INSTANT_EGG_SALES.md) |
| Eggs: production, collection and deposits | `server/EggService.luau` | Authoritative egg state; frequency/radius in `shared/Config.luau`; collection visuals in `client/EggController.luau`, `client/EggView.luau`, `shared/EggMotion.luau` |
| Coin burst on egg sales | `client/CoinBurst.luau`, `client/ActionFeedback.luau`, `shared/CollectionFeel.luau` | Gold coins burst from the pad into the player and the HUD Coins count up per coin (`ActionFeedback:Deposit`); tune `CollectionFeel.CoinBurst`. Presentation only. [Tuning](COLLECTION_FEEL.md) |
| Egg Vacuum and Chicken Feed tools | `server/ToolService.luau`, `client/ToolController.luau`, `server/EggService.luau`, `shared/VacuumConfig.luau` | Real Tools in Roblox's native hotbar. ToolService keeps each Backpack to the owned tools and sells Feed levels (`FeedChicken`); ToolController keeps the hotbar on, draws the vacuum's egg bar between My Army and the hotbar, puts the Feed prompt on the nearest home chicken and gives the guide `hintAnchors` over each tool's slot. EggService runs the vacuum and click/tap claims (`CollectEggs`). The robot vacuum is in `archive/robot-vacuum-20261020/`. [Contract](team/COLLECTION_TOOLS.md) |
| Big chicken label and level-up banner | `client/ChickenLabel.luau`, `client/LevelUpBanner.luau` | One "LVL n · name · Coins/s" label on the nearest home chicken ("LVL n → n+1" with Feed in hand) and the gold "leveled up!" banner after a Feed (`QUIET_SUCCESS.FeedChicken` drops the notice). Presentation only. [Contract](team/CHICKEN_LABELS.md) |
| Admin commands | `server/AdminService.luau`, `server/AdminConfig.luau`, `shared/AdminCommands.luau`, `client/AdminPanel.luau` | Live owner/admin commands via `/a` chat and the F2 panel. [Guide](team/ADMIN_COMMANDS.md) |
| Kill rewards | `shared/CombatRewards.luau`, `server/BattleService.luau` | Reward calculation and server award boundary |
| Free Chicken gift (join group) | `server/FreeGiftService.luau`, `client/FreeGiftController.luau` | Group-checked one-time chicken; `Config.FreeGift`, saved `freeGiftClaimed`. [Contract](team/FREE_GIFT.md) |
| Chicken offers (Robux ladder 9→1,200) | `client/HudController.luau`, `server/ProductService.luau`, `shared/ShopCatalog.luau` | Six one-after-another chicken products in the free gift's HUD slot; saved `chickenOfferStep`. [Contract](team/CHICKEN_OFFERS.md) |
| Playtime Rewards | `server/PlaytimeService.luau`, `shared/PlaytimeRewards.luau`, `client/PlaytimePanel.luau` | Twelve tiles per visit (reset every join, never saved): `ClaimPlaytime {index}`, Coins in minutes of steady income, Luck/Coins boosts and 3 Free Rolls at lever Luck; the top-bar gift and its window. [Contract](team/PLAYTIME_REWARDS.md) |
| Top-right Coins/Luck readout and corner notices | `client/BoostReadout.luau`, `client/CornerNotice.luau` | Total Coins × and Luck × from `state.boosts` (`PlaytimeService.Boosts`); `app.cornerNotice:Show({title, body, icon, tag})` queues the slide-in notice. Display only. [Contract](team/PLAYTIME_REWARDS.md) |
| Offline cash and welcome-back receipt | `shared/OfflineCashConfig.luau`, `server/OfflineCash.luau`, `server/DataService.luau`, `client/OfflineCashController.luau` | [Rate, cap, persistence and verification](OFFLINE_CASH.md); the server saves cash before the client displays its receipt |
| Chicken appearance, portraits and animation | `shared/ChickenAppearanceAssets.luau`, `client/ChickenPortraits.luau`, `client/VoxelChickenAnimator.luau` | Asset references, menu images and clip playback; clip data lives in `animations/` |
| Native proximity prompts and attack highlight | `client/BaseController.luau`, `client/PromptStyleController.luau` | Local visibility/style; `shared/CampCommand.luau` supplies command rules |
| World bindings for the builder's map | `server/AuthoredMap.luau`, `server/AuthoredPlot.luau` | Bind Studio-owned geometry into runtime systems; these are not replacements for the authored map |
| World leaderboards (Strongest Army, Top Supporters) | `server/LeaderboardService.luau`, `client/LeaderboardBoards.luau`, `server/PlayerSession.luau` (`BestArmyPower`, `robuxSpent`) | See `docs/team/LEADERBOARDS.md` |

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

Fuse (three-chicken merging) was removed on October 20: its modules are in `archive/fuse-20261020/`, and `Config.Features.Merging` and `AutoMerging` stay `false` for older readers. See [FUSE_REMOVAL_AND_SELL.md](team/FUSE_REMOVAL_AND_SELL.md). A retained module is not proof that a feature is enabled. Crate and legacy UI helpers may likewise be dormant. Check where a module is required and which feature flag enables it before changing it.

Archived/editor/plugin scripts and optional tests are not normal startup code. The map, imported rigs, textures and other Studio-owned assets are intentionally outside this code map. See [EDITING.md](EDITING.md) for sync, save and Git workflows.
