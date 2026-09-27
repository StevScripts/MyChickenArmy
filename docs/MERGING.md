# Manual chicken merging

Implemented September 25, 2026 at the user's explicit request. This supersedes older statements that merging is disabled. `Config.Features.Merging = true`; `AutoMerging = false`. Enabling the manual feature does not enable the paid Auto Merge listing or automatic consumption.

## Player flow

Approach your own Fuse Machine's button and press E. The purple menu shows one group per species, star tier and level, only when at least three eligible copies exist. Search filters names. Select a group to preview its next level, per-chicken DPS and eggs per second, then press **Merge 3 → 1**. Exactly three original IDs are used: the first survives one level higher; two are removed; other copies remain. No cash fee or separate confirmation dialog. The left preview shows per-chicken values, not the three inputs' combined production. The September 26 [quantity economy](EGG_ECONOMY.md) moves the existing income multiplier into egg quantity, retaining the merge tradeoff below.

The user explicitly chose to keep the saved balance: income follows the existing 2^(level−1) formula, and combat gains 25% of base HP/damage per level. Three level-1 inputs therefore become one chicken with 2× individual income and 1.25× individual combat stats. Total flock income and total combined DPS decrease; power per occupied slot increases. This implementation does not claim the feature is economy-neutral or newly balanced.

Existing merge progression caps are retained from `Progression.Get(session.promotion).levelCap` (3/5/7/10). This is the old merge-specific rule, separate from cash upgrades. Cash upgrades remain available from the start whenever affordable; never introduce camp gates for them. No alternate star tier, output species lottery, currency, price rebalance, or save schema migration was added.

Favorites, away/deployed chickens, selected defenders during an incoming battle and chickens at the merge cap are excluded. Home reserves can merge while the army is away. Manual merging may include selected home chickens, retaining an existing squad ID first. Consumed IDs are removed from manual selection, their investment values accumulate on the survivor, and refresh/save uses existing ownership paths.

## Ownership and integration

- `ArmyService`: server grouping, exact triple validation and non-yielding consumption. Same species, stars and level required. Validates the whole optional batch before any mutations; old pair payloads cannot consume chickens.
- `GameServer`: loaded/save ownership checks, rate limit, same-plot and distance validation, result snapshots. Uses `firstId`, `secondId`, `thirdId`, `level` and `stationIndex`; legacy internal batch route takes `triples`.
- `MergeStand` / `WorldService`: the builder-owned standalone `Workspace.Fuse_Machine` remains unchanged in Edit. During Play it is retained in ServerStorage and cloned at its Plot 1-relative placement into each runtime plot. A machine already nested in an authored plot takes precedence. Existing Button/ProximityPrompt is reused; Gate parts tween vertically. Obsolete merge stalls are removed only from runtime copies. Missing machine/anchor has a safe prompt fallback.
- `MergeBrowser`: approved Figma dialog, server-issued options, selected triple, request tracking, search, mobile reflow, close/reopen cancellation. Only server success begins the reveal; timeout refreshes state without automatically resubmitting.
- `MergePresentation`: three-input UI reveal using existing TweenService-backed motion and reduced-motion behavior. World input birds are temporary cosmetic models, not inventory instances.

Gate animation uses ordinary TweenService tweens: open, three cosmetic birds enter, close, short purple sparkle. The gate and temporary birds reset when interrupted, cleared or destroyed. No custom per-frame interpolation or changed chicken walking physics.

## Visual contract

Approved Figma [408:818](https://www.figma.com/design/4lJjZOqNhR8K7rfMbVIjaK/my-chicken-army?node-id=408-818), dialog 410:839. Purple studded header, generated merge icon, red close, square geometry, opaque black-purple `#0D0913`, unboxed portraits, selected purple outline/check and a single purple Merge button. Desktop uses four columns; narrow screens reflow. No Merge All control or repetitive selection summaries.

Use `UITheme.Studs` and the approved full-sheet image `rbxassetid://93331178043153`. Never rebuild individual studs. Merge icon `rbxassetid://122096168414414`; source, prompt, upload receipt and Studio screenshot are under `assets/merge-ui-20260925/`. Runtime portraits use the current shared ChickenPreview/ChickenPortraits assets rather than invented mockup chickens.

## Validation

The eight checks in `tests/MergeStandChecks.luau` pass in an isolated Studio runtime: exact triple and investment/save roundtrip, replay/legacy rejection, malformed/mismatched inputs, protected/away/capped birds, deployed-squad reserves, eligible grouping/extra copies/preview stats, atomic batch failure and disabled automation. Additional actual client/server checks verified same-plot/proximity enforcement, a 27→25 flock transaction retaining the upgraded ID, search and empty states, duplicate-click suppression, eight visible desktop cards in a 4×2 grid, and gate motion (21 parts, 3 cosmetic birds, full reset).

Five layout fixtures covered desktop, narrow portrait and short landscape sizes; grid sizes remained positive and the action stayed inside its panel. These are focused Studio checks, not a physical-device or multiplayer-network soak test. No publish, purchase, or saved-profile mutation. Local session-only test progress is discarded on Stop.
