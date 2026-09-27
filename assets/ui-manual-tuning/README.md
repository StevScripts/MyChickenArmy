# Manual Shop and Army layout tuning

Created September 25, 2026 in canonical Pet Roll Test 96683186622050, Studio Edit.
These are editable snapshots, not new production UI or a responsive-layout fix.
They use the actual ShopBrowser/ChickenBrowser constructors and shared Chicken Army artwork/theme. No gameplay modules were edited.

## Open a layout

In Explorer, expand **StarterGui**. Enable exactly one of these ScreenGuis:

- `MCA_Tune_Army_Desktop` — initially visible and Window selected.
- `MCA_Tune_Shop_Desktop`
- `MCA_Tune_Army_PhoneLandscape`
- `MCA_Tune_Shop_PhoneLandscape`
- `MCA_Tune_Army_PhonePortrait`
- `MCA_Tune_Shop_PhonePortrait`

Set the current one's **Enabled=false**, then the desired one's **Enabled=true**. Work while Studio is **stopped**, not in PlayerGui during Play. Buttons are inert; use Properties to show hidden states. Any sample chickens/counts are layout-only fixtures, not player inventory. Shop prices and checkout are disconnected and marked as previews.

**Disable all six preview ScreenGuis before Play or publishing.** Enabled StarterGui previews otherwise copy into PlayerGui and cover the real game UI. Do not delete your edits; these are the handoff targets.

## What to adjust

| Desired change | Where / property |
|---|---|
| Overall menu width/height and position | `Canvas.Window.Size` / `Position`; scale components are fractions of that artboard |
| Editor zoom only | `Canvas.Zoom.Scale`; 1 means 1:1 design pixels, not a runtime layout decision |
| Shop card size and gaps | `Window.ShopBrowser.Body.ShopSections.Passes.PassCards.UIGridLayout`: `CellSize`, `CellPadding`, `FillDirectionMaxCells` |
| Shop cash cards | `Window.ShopBrowser.Body.ShopSections.Cash.CashTiers.UIGridLayout`: same properties |
| Army card size and gaps | `Window.ChickenBrowser.ArmyContent.Inventory.ChickenInventory.UIGridLayout`: same properties |
| Title, label and button copy sizes | TextLabel/TextButton `TextSize`; nested `TextFace`, `TextShadow`, and `Caption` may need matching edits in these frozen copies |
| Internal panels, toolbar, inspector, artwork | Corresponding Frame/ImageLabel `Size`, `Position`, and `Visible` |
| Show more of scrolling content in Edit | ScrollingFrame `CanvasPosition`; `CanvasSize`/`AutomaticCanvasSize` controls scroll extent |
| Layout-controlled child won't move | Its parent's UIListLayout/UIGridLayout owns placement; edit padding/order/cell size there |
| Stud texture crop area | `StudClip.Size` / `Position`; keep its full-sheet image square |

Desktop artboards are 1440×900 logical pixels. Phone landscape/portrait artboards represent 749×368 and 389×762 safe content areas. `Canvas.Zoom` initially fits each artboard into the current Studio viewport; it is **authoring zoom**, not a proposed whole-screen runtime scale. Set it to 1 when judging actual text/control size if the viewport has room. These are fixed representative artboards, not proof of physical-device support or automatic breakpoint behavior.

No resize controllers remain attached to the copies. Enlarging a menu may therefore require moving/resizing its internal regions too; that is intentional so manual edits stay put. No colors, geometry or responsive choices will be copied back until the user finishes.

## Handoff

Tell Codex which copies you changed and when they are ready. Keep object names where possible. The next implementation pass should compare your edited instances with the baseline, translate sizes/spacing into the existing AppController/ShopBrowser/ChickenBrowser layout owners, and preserve native purchases, real data and the shared theme. Do not replace code wholesale with these fixture snapshots.

Baseline: `ServerStorage.MCA_ManualUILayoutBaseline_1790353457` contains all six restored originals. `create-previews.luau` records construction and refuses to overwrite any existing preview. Temporary constructor modules and connections were removed; no mapped Source writes, new Play session, purchase, cloud save or publish occurred. A Studio Edit screenshot confirmed the Army authoring preview was visible; mobile usability is not yet validated.

Recovery note: the first six previews and baseline disappeared after initial readback. The user was not interacting with Studio. No consulted task reported removing them; the exact cause remains unknown. A running session was subsequently detected via Studio Flow status, despite the Edit peer reporting IsRunning=false. After coordinating with the other active tasks, the session was stopped and stopped status / Edit-only discovery were confirmed before restoring these copies. Check both before future authoring operations; do not rely on the Edit peer's IsRunning alone.
