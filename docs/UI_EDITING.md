# Edit UI size in Studio

All menu topbars share `UITheme.Header`, `HeaderClose` and `BelowHeader`.
The header's native aspect is 1474:116, about 40% taller than the initial
shared header. Titles, icons and the X grow with it. Edit the shared
component for header/title/icon/X changes; do not add menu-specific overrides.
Menu colors and icons remain screen-specific. Offline Earnings' X and Continue
both dismiss the already-paid receipt.

Stop Play and open **StarterGui → PetRollGui → MenuLayouts**.

1. Set **PreviewMenu** to `MyArmy`, `Shop`, `Index`, `Upgrades`, `Settings`,
   `Odds`, `Fuse`, or `OfflineEarnings`.
2. Select that menu Frame. Edit **Size → X/Y → Scale** and **Position**.
   Leave offsets at zero.
3. Its **UIAspectRatioConstraint → AspectRatio** keeps the intended shape.
   Content uses native Scale geometry, aspect constraints and TextScaled.
   There is no UIScale, SizeLimits, CompactSize or device breakpoint system.
4. Index's **PortraitScale** still adjusts its chicken artwork independently.
5. Save the Roblox place to retain Studio property edits. Play-mode edits
   to PlayerGui are temporary.

The September 30 user correction copies the restored **GUI → FRAMES** layout
method across the current UI. Shop, Index, Upgrades, Settings and Offline
Earnings use their matching reference proportions. Army retains four columns
and its inline inspector; Fuse retains its three-input composition. HUD and
merchant dialogue use the same native sizing method. Native lists and scrolling
hold repeated content; all screen sizes keep the same composition.

## Reopen previews

After restarting Studio, run this in **View → Command Bar**:

```lua
require(game.ServerStorage.PetRoll.UIAuthoring.Open)()
```

The helper renders display-only fixtures into each menu's **Preview** child.
Native properties handle resizing without running this again. Only regenerate
when source changes; the menu Frame's saved settings remain authoritative.
Generated Preview children are replaced on regeneration.

`client/MenuLayout.luau` copies the saved Size, Position, AnchorPoint and aspect
into runtime menus. Rojo owns scripts; Studio owns these menu Frames. The old
`GUI` remains a reference, with its contents preserved.

## Evidence

Three agents inspected all 14 reference frames, HUD and OTHER. All eight current
menus passed proportional geometry and scrolling checks at five simulated
viewport sizes, with no UIScale, UISizeConstraint, UITextSizeConstraint or
position/size offsets in their generated trees. HUD home/outside states were
checked in an Edit-mode fixture. These are editor/layout checks, not a physical
device or live gameplay test. See `assets/ui-aspect-layout-20260930/`.
