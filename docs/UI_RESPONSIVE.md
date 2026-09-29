# Responsive HUD and menus

Implemented September 24–25, 2026 in Pet Roll Test, place 96683186622050.

**Menu focus, September 29:** AppController now owns a client-only world blur
for Army, Shop, Index, Upgrades, Settings, Odds, Fuse and other main-panel pages,
plus the separate offline receipt. Blur size tweens between 0 and 18 over
0.24 seconds through UIMotion, reverses from its current value, and stays active
across menu handoffs. Full-screen input shields are transparent. The offline
receipt also removes its charcoal body, reflows without text-scale multipliers,
keeps Continue pinned, and uses fade/slide/scale entrance and exit tweens.
Reduced motion remains supported. No Play or visual validation was run for
this styling update; the device results below describe earlier implementations.

**Popup spacing, September 28:** main popup bounds use 87.3% of their original
desktop size when the available safe area is at least 900 × 550. Army and Fuse
retain their proportions; each browser retains its content reflow. Smaller
screens keep their existing bounds. `AppController.DESKTOP_POPUP_SIZE` is the
local sizing constant; no whole-screen UIScale is introduced. This styling
adjustment has not been playtested or visually verified.

The follow-up reduces the prior 90% popup setting by another 3%. On touch
devices, the bottom Call Army / My Army / My Base row uses 80% icon sizing,
widths and spacing, with smaller label/count rows and readable text floors.
Portrait movement-control clearance and the existing home-collapse tween remain.
This mobile styling adjustment has not been playtested or visually verified.

**Army follow-up, September 25:** the user requested the approved Figma window
proportions and larger chickens. Army now fits a 1474:976 window on desktop,
uses a single toolbar row and inline inspector, and places the name/DPS labels
one pixel apart. Phones keep the compact reflow below. Army's desktop header
and controls scale with that window, so the earlier fixed-52-pixel close claim
does not apply to this later Army design. Its Edit-only layout checks and
31 uploaded, verified outlined portraits are recorded in
[the Army change record](../assets/army-figma-20260925/README.md). The older
56-snapshot Play results below are historical evidence for the preceding
responsive pass, not proof of the later Army changes.

The screen shell is no longer uniformly shrunk to a desktop canvas. HUD anchors
and popup outer bounds use scale within the device-safe area. Pixel padding,
text sizes, thumbnail authoring details, and minimum hit sizes are intentional;
converting those blindly to percentages would make phone controls too small.

- Shop/Index share a vertically centered screen anchor on desktop. Touch layouts
  reserve space for native movement controls. Cash/egg counters also avoid them.
- Top HUD navigation now contains only the centered My Army button. Base and
  Upgrades shortcuts were removed at the user's request on September 25.
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
this screen-layout change. Merge was disabled during that responsive pass. A subsequent user-authorized purple merge implementation is documented in [MERGING.md](MERGING.md), including its own layout evidence.

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
