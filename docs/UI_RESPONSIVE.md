# Responsive HUD and menus

Implemented September 24–25, 2026 in Pet Roll Test, place 96683186622050.

The screen shell is no longer uniformly shrunk to a desktop canvas. HUD anchors
and popup outer bounds use scale within the device-safe area. Pixel padding,
text sizes, thumbnail authoring details, and minimum hit sizes are intentional;
converting those blindly to percentages would make phone controls too small.

- Shop/Index share a vertically centered screen anchor on desktop. Touch layouts
  reserve space for native movement controls. Cash/egg counters also avoid them.
- Army, Shop, Index, Upgrades, Settings and Odds use bounded popup placement and
  readable fixed headers. Close stays at 52 pixels. Contents scroll independently.
- Army and Index reflow their grids. Narrow Army screens open the flock first;
  selecting a chicken opens details with Back to flock. Short landscape Army
  layouts keep Equip/Sell visible, using the inventory thumbnail as the preview.
- Shop keeps its existing left icon rail and switches between one, two and three
  columns. Details text and outcomes scroll above fixed Back/Buy controls.
- Upgrades reflows its cards and reduces decorative height on short screens.
- The offline receipt reflows its content and keeps Continue at least 52 pixels
  in the tested short landscape viewport, including a large cash amount.
- Settings stays in its existing topbar location and hides while a popup is open
  so it cannot cover that popup's close button.

The existing UITheme fonts, colors, artwork and approved full-sheet stud image
remain in use. Prices, purchases, rankings, progression and server rules were
not changed. World-projected dialogue/labels and SurfaceGui layouts are outside
this screen-layout change. Dormant Merge UI remains disabled.

## Ownership

Eight edited client modules: AppController, HudController, UITheme,
ChickenBrowser, ShopBrowser, IndexBrowser, ProgressionBrowser and
OfflineCashController. AppController owns safe popup bounds; individual
browsers own content reflow. UIScale remains available for animation, not
shrinking the whole screen to fit a fixed desktop design.

## Checks actually performed

Studio Flow ran an isolated session-only Play session using the real client UI.
No purchases or saved profiles were used. Native mouse clicks exercised menu
opening/closing and Back; the disposable client probe then exercised the real
page entry points and collected rendered geometry. Temporary extra grid cells
checked populated Army layouts without creating pets or changing a profile.

| Simulator preset | Measured safe UI area | Main menus and secondary states |
| --- | --- | --- |
| Desktop 1920 × 1080 | 1918 × 1080 | Pass |
| Desktop 1280 × 720 | 1279 × 720 | Pass |
| iPad 1024 × 768 | 1022 × 767 | Pass |
| iPhone landscape 844 × 390 | 749 × 368 | Pass |
| iPhone portrait 390 × 844 | 389 × 762 | Pass |

Final measurements: 56 snapshots, zero failures for checked active hit targets
(minimum 48 pixels, allowing floating-point rounding), popup bounds, grid
wrapping, scroll widths and Settings overlap. Desktop Shop/Index pair center
measured exactly 50% of screen height. Additional receipt fixture: 448 × 286
panel, 392 × 52 Continue, large amount $1,234,567,890; presentation only.

Visual inspection covered HUDs, Shop, Index, Army, Upgrades and Shop details.
The phone Shop was scrolled to its final offer. Source readback confirmed exactly
one copy of each edited module, byte-for-byte equality with disk, and successful
Luau compilation. Rojo packaging and whitespace checks passed. Current-session
logs contained no game/client errors; an unrelated pre-existing plugin HTTP
permission warning remains.

These are Studio device-emulation checks, not physical-device tests. Gamepad,
software keyboard and a full touch-drag gameplay pass were not tested. Native
purchase dialogs and disabled/dormant features were not exercised.

## Evidence and recovery

- [Measured results](../assets/ui-responsive-20260924/layout-results.json)
- [Disposable live client probe](../assets/ui-responsive-20260924/layout-probe.luau)
- [Final source hashes/readback](../assets/ui-responsive-20260924/source-readback.json)
- [Original seven-module Studio export](../assets/ui-responsive-20260924/studio-before.json)
- [Desktop HUD](../assets/ui-responsive-20260924/desktop-hud.jpg)
- [Landscape phone HUD](../assets/ui-responsive-20260924/phone-landscape-hud.jpg)
- [Landscape Army](../assets/ui-responsive-20260924/phone-landscape-army.jpg)
- [Portrait Army](../assets/ui-responsive-20260924/phone-portrait-army.jpg)
- [Portrait Shop](../assets/ui-responsive-20260924/phone-portrait-shop.jpg)

A stale duplicate OfflineCashController was loading the old shrinking receipt.
Its exact before-source is retained locally and the original Studio instance was
moved intact to ServerStorage.UIResponsiveRecovery20260924.OfflineCashController.
The active copy is the Rojo-owned source. No mapped Source was written through
Studio MCP.

All changes are local and synced into canonical Studio. Play is stopped,
device simulation is off, temporary runtime fixtures are gone and Studio
controls are released. No native Roblox Save/Publish, Git commit/push or asset
upload was performed. Preserve the concurrent chicken-recovery and egg-processor
changes in this checkout.
