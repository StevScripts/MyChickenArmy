# Example UI hierarchy study — September 29, 2026

User request: study every menu in `StarterGui.Example` and apply similar parenting and sizing to the game, preserving the game's current content and intended dimensions.

## Source inspected

Pet Roll Test, place **96683186622050**, Edit context. The reference is `StarterGui.Example.GUI`, with `HUD`, `FRAMES` and `OTHER` children. All 3,259 instance records, including the root, are captured in [example-hierarchy.json](example-hierarchy.json). This is a property snapshot, not an asset or script-source export. The reference instances remain unchanged.

The reference's HUD and OTHER fill the viewport. FRAMES is centered and only **0.065876156 × 0.120481931** of its parent; its menus use scale values above one. That proxy container has **no aspect constraint**. Those raw menu scale values are not percentages of the screen and cannot be pasted into a full-screen game container without resizing everything.

All 14 menu roots use anchor **(0.5, 0.5)**; several positions are offset from the center. Most have a FitWithinMaxSize aspect constraint with Width as the dominant axis. Repeated content uses native lists/grids, and content coordinates belong to a local Main/Holder rather than the entire screen. Text frequently uses TextScaled with caps. Clipping is deliberately mixed; for example the Index and Settings scrollers clip while the Shop scroller does not.

## Each menu

Sizes below are the menu's scale components relative to the small FRAMES proxy. All offsets in these outer sizes are zero.

| Menu | Outer scale X × Y | Outer aspect | Parenting and layout |
| --- | --- | --- | --- |
| DailyGifts | 6.00000 × 4.00000 | 1.50000 | Cover/header over Main.Holder; horizontal scrolling gifts (automatic X), relative 0.015 list gap. |
| UpgradesShop | 10.02249 × 3.83070 | 2.93000 | Header plus Main.Holder.Container; horizontal offer list with 0.04 gap and a separate button row inside each offer. |
| Rebirth | 7.03537 × 5.88610 | 1.20092 | Main.Holder vertical stack (0.032 gap), with horizontal title, reward and action rows. |
| OfflineEarnings | 5.01321 × 3.50000 | 1.39157 | Main.Holder vertical stack (0.015 gap); separate horizontal Buttons row (0.0785 gap). |
| Shop | 7.87778 × 5.95406 | 1.48170 | Header, Main.Holder scrolling sections (automatic Y), horizontal offer rows; ButtonsLeft stays outside the scroll. |
| Index | 7.79964 × 5.18671 | 1.48170 | Main.Index.Brainrots.Container owns the clipped collection scroller; progress strip and two side rails are separate siblings. |
| Settings | 6.25000 × 4.49200 | None on outer frame | Top header plus a clipped vertical ScrollingFrame, automatic Y and 0.04 list gap. |
| GiftFrame | 5.32368 × 4.28911 | 1.39000 | Top header and individually anchored native content; no list/grid at this menu level. |
| JoinGroupFrame | 9.79894 × 4.12901 | 1.65000 | Top header and relative content/action rectangles; no list/grid. |
| StarterPack | 6.75256 × 5.44031 | 1.39000 | Top header, Items holder and relative content/action rectangles; no list/grid. |
| TrollMenu | 7.95161 × 5.56551 | 1.60000 | Top header and CardsContainer grid: cells 0.47 × 0.46, gaps 0.03 × 0.04. |
| ToolsShop | 8.51205 × 6.43214 | 1.87000 | Main.Holder.Container scrolls horizontally (automatic X), 0.02 list gap; each offer owns its button row. |
| DailyRewardFrame | 10.57628 × 5.13144 | None on outer frame | Outer wrapper with full-size DailyRewardPanel; CardsHolder uses a horizontal list, 0.0075 gap. |
| TimedRewards | 7.97507 × 5.95406 | 1.50000 | Cover/header, GridHolder and BottomBar; grid cells 0.23 × 0.315, gaps 0.018 × 0.015. |

The full property snapshot also records all nested frames, anchors, sizes, text-size constraints, layout padding and scrolling settings. There are 505 aspect constraints, 51 list layouts and two grid layouts across the reference. Its nested ScreenGuis, prototype offsets and feature-specific content are observations, not requirements for this game.

## Applied to My Chicken Army

The main runtime tree is now organized as:

```text
PetRollGui / Shell
  HUD
    Navigation
    CollectionNavigation / UIListLayout / Shop, Index
    existing counters and status labels
  FRAMES
    Backdrop
    Panel (center anchor; existing safe-area bounds)
      StandardPage / Header, Main / Content or IndexBrowser
      ChickenBrowser / Header, Body
        Inventory / InventoryPanel / Search, InventorySort, ChickenInventory
        Inspector / Actions / UIListLayout / Equip, Sell
      ShopBrowser / SectionNavigation, Window / Header, Main
        ShopSections
        PurchaseDetails / Outcomes, Actions / UIListLayout / Back, Buy
      UpgradesBrowser / Header, Main / UpgradeCards
      MergeBrowser / Header, Main, Actions
        Main / ThreeChickenFlow, ChickenPicker, FusionResult, Processing
  OTHER / Notification
OfflineCashGui / FRAMES / Backdrop, OfflineCash
  Header
  Main / Content, Actions / Continue
```

Names in the tree describe their role where an internal compatibility name differs. Existing controller ownership and ScreenGui safe-area settings remain in place.

- `UITheme` owns transparent Container, optional Aspect, and RelativeRect helpers. The popup styling traversal understands the new local window/body parents.
- Army and Fuse keep their existing desktop ratios, **1474:976** and **900:850**, with native aspect constraints. Other menus retain content-dependent heights and phone reflow. The desktop popup factor remains **0.873**.
- Army's desktop body, inventory, search, sort, grid and inspector use their parent's relative coordinate space. Parent changes subtract the old parent's origin so the intended content rectangles stay in the same place.
- Equip/Sell, Shop Back/Buy, and HUD Shop/Index use native list layout rather than separate sibling positions.
- Settings/Odds/Index and Upgrades scrolling content belong to their actual body frames. Shop has a dedicated window beside its navigation rail.
- Fuse owns separate Main and bottom-anchored Actions containers. The offline receipt similarly groups its scrolling content and pinned Continue action.
- Pixel insets, text caps, scrollbars and minimum touch sizes remain intentional. The reference's smaller parent proxy, aspect ratios, fonts and artwork are not substituted for the game's established design.

## Scope, recovery and evidence limits

Nine client modules changed: AppController, HudController, ChickenBrowser, ShopBrowser, IndexBrowser, ProgressionBrowser, MergeBrowser, OfflineCashController and UITheme. No gameplay, prices, player data or server authority changed in this layout pass. Existing cash-upgrade work was preserved.

[before.json](before.json) contains the ten inspected client sources before this pass, including unchanged UIMotion. Restore selectively: it is not permission to overwrite later work.

This pass studies Edit-mode properties and changes source layout. **No Play session, device simulation, runtime compilation, automated tests or visual validation was run for these changes.** Earlier UI/cash-upgrade test results do not validate this pass. Source readback, if recorded alongside this file, establishes only Rojo sync. No save/publish, commit/push or asset upload was performed.


## Single ScreenGui correction — same-day user follow-up

The user showed seven old `CountryUIStylePreview` / `MCA_Tune_*` previews in
StarterGui and requested exactly one GUI. All seven originals were moved intact
to `ServerStorage.UIAuthoringArchive20260929`; no preview was deleted. The empty
`StarterGui.ScreenGui` was renamed/configured as `PetRollGui`, with an empty
Shell / HUD / FRAMES / OTHER skeleton. This is the sole ScreenGui remaining in
StarterGui. The earlier Example reference was already absent at this follow-up;
its previous property snapshot above remains available.

AppController now reuses the native PlayerGui clone of this Studio-owned
ScreenGui template and builds its current content into the Shell. Topbar Settings,
offline earnings, the retained merchant dialogue, and drag previews use Frames
inside the same GUI. `UITheme.InsetContainer` keeps each overlay's coordinate
region through [GuiService.GetInsetArea](https://create.roblox.com/docs/reference/engine/classes/GuiService#GetInsetArea).
The previous standalone OfflineCashGui entry in the tree above is superseded:
its content is now `PetRollGui.Shell.OTHER.OfflineEarnings`.

The template remains Studio-owned, outside the scripts-only Rojo mapping.
Save the full Studio place to retain the template and archive. Code stays in
Rojo-owned modules. No native Save/Publish was performed by this change.

[Archive manifest](single-gui-archive.json) records original paths and descendant
counts. [Pre-correction client sources](single-gui-before.json) preserve the six
affected modules. Restore selectively only on request; restoring all preview
roots to StarterGui would reintroduce the issue. Runtime, Play and visual/device
validation were not run. Source readback records sync only.

## Menu-opening repair and authorized runtime check — September 29

The user's subsequent report that menus did not open authorized this runtime
check. Pressing B reproduced an exception in `AppController:OpenPage`: it still
referenced `panel.Body` after Body moved to `StandardPage.Main`. The opener now
uses the stored `self.panelBody` reference. `UITheme.InsetContainer` also now
uses the shared Core UI coordinate origin directly; subtracting the viewport
origin a second time had shifted inset overlays down by 58 pixels.

In the canonical place's session-only Play mode at a 1291 × 611 viewport:

- Army, Shop, Index, Upgrades, Settings and Odds opened with populated content
  and closed successfully through the real controller.
- B and actual HUD/close callbacks were exercised with native input. Army,
  Index and Settings buttons passed, together with Shop/Index/Settings close.
- Fuse's window, picker and return state passed using a temporary client-only
  stand-eligibility presentation fixture. A direct open away from the stand
  correctly auto-closed; no proximity guard or fusion transaction was changed.
- A display-only offline receipt mounted under the one game root and dismissed.
  Its safe region, the topbar and a temporary drag container matched GetInsetArea.
- Both repaired modules read back byte-for-byte from Studio. StarterGui still
  contains only PetRollGui; Roblox-generated Freecam/ProximityPrompts appeared
  separately during Play. Temporary probes and input selection were removed.

No menu script errors appeared after the repair. Logs still contain unrelated
egg-effect asset and plugin HTTP permission warnings, and one warning from
selecting a hidden control during input testing. This is a PC menu smoke check,
not a new mobile layout sweep or purchase/fusion transaction test. The existing
session-only flag remained enabled; these checks did not mutate saved profiles.
The active Play session was left running. No Save/Publish, commit/push or upload.

Evidence: [results and logs](menu-repair-results.json),
[source readback](menu-repair-readback.json),
[before sources](menu-repair-before.json),
[menu probe](menu-repair-probe.luau),
[overlay/Fuse probe](menu-repair-extended-probe.luau),
and [Army screenshot](menu-repair-army.jpg).
